# 部署指南

## 概述

脱敏配置服务是一个纯前端应用，使用Docker Compose进行容器化部署。本文档提供了完整的Docker Compose部署方案。

## 前置要求

- Docker 20.10+
- Docker Compose 2.0+

## Docker Compose 部署

### 项目结构

部署需要以下文件：

```
sanitization-config-service/
├── docker-compose.yml     # Docker Compose配置
├── Dockerfile            # Docker镜像构建文件
├── nginx.conf           # Nginx配置文件
├── package.json         # 项目依赖
├── src/                # 源代码
└── public/             # 静态资源
```

### 创建部署文件

#### 1. Dockerfile

创建 `Dockerfile`：

```dockerfile
# 多阶段构建
FROM node:22-alpine as build

# 设置工作目录
WORKDIR /app

# 复制package文件
COPY package*.json ./

# 安装依赖
RUN npm ci --only=production

# 复制源代码
COPY . .

# 构建应用
RUN npm run build

# 生产阶段
FROM nginx:alpine

# 复制构建文件到nginx目录
COPY --from=build /app/build /usr/share/nginx/html

# 复制nginx配置
COPY nginx.conf /etc/nginx/conf.d/default.conf

# 暴露端口
EXPOSE 80

# 启动nginx
CMD ["nginx", "-g", "daemon off;"]
```

#### 2. nginx.conf

创建 `nginx.conf`：

```nginx
server {
    listen 80;
    server_name localhost;
    root /usr/share/nginx/html;
    index index.html;

    # 支持 SPA 路由
    location / {
        try_files $uri $uri/ /index.html;
    }

    # 静态资源缓存
    location /static/ {
        expires 1y;
        add_header Cache-Control "public, immutable";
    }

    # 安全头
    add_header X-Frame-Options "SAMEORIGIN" always;
    add_header X-Content-Type-Options "nosniff" always;
    add_header X-XSS-Protection "1; mode=block" always;
    add_header Referrer-Policy "no-referrer-when-downgrade" always;

    # Gzip 压缩
    gzip on;
    gzip_vary on;
    gzip_min_length 1024;
    gzip_types
        text/plain
        text/css
        text/xml
        text/javascript
        application/javascript
        application/xml+rss
        application/json;
}
```

#### 3. docker-compose.yml

创建 `docker-compose.yml`：

```yaml
version: '3.8'

services:
  sanitization-config-service:
    build:
      context: .
      dockerfile: Dockerfile
    container_name: sanitization-config-service
    ports:
      - "3000:80"
    restart: unless-stopped
    environment:
      - NODE_ENV=production
    networks:
      - sanitization-network
    labels:
      - "traefik.enable=true"
      - "traefik.http.routers.sanitization.rule=Host(`sanitization.localhost`)"
      - "traefik.http.services.sanitization.loadbalancer.server.port=80"

  # 可选：添加反向代理
  nginx-proxy:
    image: nginx:alpine
    container_name: sanitization-nginx-proxy
    ports:
      - "80:80"
      - "443:443"
    volumes:
      - ./nginx-proxy.conf:/etc/nginx/conf.d/default.conf:ro
      - ./ssl:/etc/nginx/ssl:ro
    depends_on:
      - sanitization-config-service
    restart: unless-stopped
    networks:
      - sanitization-network

networks:
  sanitization-network:
    driver: bridge

volumes:
  sanitization-data:
    driver: local
```

### 部署步骤

#### 1. 准备部署文件

确保项目根目录包含以下文件：
- `Dockerfile`
- `docker-compose.yml`
- `nginx.conf`

#### 2. 构建和启动服务

```bash
# 克隆项目（如果还没有）
git clone <your-repository-url>
cd sanitization-config-service

# 使用 Docker Compose 构建和启动
docker-compose up -d --build

# 查看服务状态
docker-compose ps

# 查看日志
docker-compose logs -f sanitization-config-service
```

#### 3. 验证部署

```bash
# 检查服务是否正常运行
curl http://localhost:3000

# 或在浏览器中访问
# http://localhost:3000
```

#### 4. 停止服务

```bash
# 停止服务
docker-compose down

# 停止并删除数据卷
docker-compose down -v
```

## 高级配置

### 环境变量

可以通过环境变量自定义配置：

```yaml
# docker-compose.yml 中的环境变量
services:
  sanitization-config-service:
    environment:
      - NODE_ENV=production
      - REACT_APP_VERSION=1.0.0
      - REACT_APP_BUILD_DATE=${BUILD_DATE:-$(date)}
```

### 自定义域名

如果需要使用自定义域名，可以配置反向代理：

```yaml
# docker-compose.yml 添加域名配置
services:
  nginx-proxy:
    environment:
      - VIRTUAL_HOST=your-domain.com
      - LETSENCRYPT_HOST=your-domain.com
      - LETSENCRYPT_EMAIL=your-email@domain.com
```

### SSL/HTTPS 配置

创建 `nginx-proxy.conf` 用于HTTPS：

```nginx
server {
    listen 80;
    server_name your-domain.com;
    return 301 https://$server_name$request_uri;
}

server {
    listen 443 ssl http2;
    server_name your-domain.com;

    ssl_certificate /etc/nginx/ssl/cert.pem;
    ssl_certificate_key /etc/nginx/ssl/key.pem;

    location / {
        proxy_pass http://sanitization-config-service:80;
        proxy_set_header Host $host;
        proxy_set_header X-Real-IP $remote_addr;
        proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
        proxy_set_header X-Forwarded-Proto $scheme;
    }
}
```

## 监控和日志

### 查看容器日志

```bash
# 查看实时日志
docker-compose logs -f sanitization-config-service

# 查看最近的日志
docker-compose logs --tail=100 sanitization-config-service

# 查看所有服务日志
docker-compose logs
```

### 容器健康检查

```bash
# 检查容器状态
docker-compose ps

# 检查容器资源使用
docker stats $(docker-compose ps -q)

# 进入容器调试
docker-compose exec sanitization-config-service sh
```

## 维护操作

### 更新应用

```bash
# 拉取最新代码
git pull origin main

# 重新构建和部署
docker-compose up -d --build

# 清理旧镜像
docker image prune -f
```

### 备份和恢复

```bash
# 备份配置文件
tar -czf sanitization-backup-$(date +%Y%m%d).tar.gz \
  docker-compose.yml Dockerfile nginx.conf

# 恢复时解压并重新部署
tar -xzf sanitization-backup-20250118.tar.gz
docker-compose up -d --build
```

## 故障排除

### 常见问题

1. **容器启动失败**
   ```bash
   # 检查日志
   docker-compose logs sanitization-config-service

   # 检查端口占用
   netstat -tlnp | grep :3000
   ```

2. **构建失败**
   ```bash
   # 清理构建缓存
   docker-compose build --no-cache

   # 检查Dockerfile语法
   docker build -t test .
   ```

3. **访问问题**
   ```bash
   # 检查防火墙
   sudo ufw status

   # 检查端口映射
   docker port $(docker-compose ps -q sanitization-config-service)
   ```

### 性能优化

1. **启用生产模式**
   ```yaml
   environment:
     - NODE_ENV=production
   ```

2. **资源限制**
   ```yaml
   deploy:
     resources:
       limits:
         memory: 512M
         cpus: '0.5'
   ```

3. **健康检查**
   ```yaml
   healthcheck:
     test: ["CMD", "curl", "-f", "http://localhost:80"]
     interval: 30s
     timeout: 10s
     retries: 3
   ```

## 安全建议

- 定期更新基础镜像
- 使用非root用户运行容器
- 配置防火墙规则
- 启用HTTPS（生产环境）
- 定期备份配置文件

---

通过Docker Compose部署，您可以轻松管理脱敏配置服务的完整生命周期，包括构建、部署、监控和维护。
