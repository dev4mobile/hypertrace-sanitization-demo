# ==== 构建阶段 ====
FROM amazoncorretto:17-alpine AS build

# 安装必要的工具
RUN apk add --no-cache bash

# 设置工作目录
WORKDIR /app

# 首先复制 Gradle Wrapper 相关文件（这些文件变化较少，可以利用 Docker 层缓存）
COPY gradle/ gradle/
COPY gradlew .

# 给 gradlew 执行权限
RUN chmod +x gradlew

# 复制构建配置文件（这些文件变化相对较少）
COPY build.gradle.kts .
COPY settings.gradle.kts ./

# 下载依赖（这一步会被缓存，除非 build.gradle.kts 发生变化）
# 使用 --refresh-dependencies 确保获取最新依赖，但通常这步会被缓存
RUN ./gradlew dependencies --no-daemon

# 最后复制源代码（源代码变化最频繁，放在最后以最大化缓存利用）
COPY src/ src/

# 构建应用（跳过测试以缩短镜像构建时间）
RUN ./gradlew clean build -x test --no-daemon

# ==== 运行阶段 ====
FROM amazoncorretto:17-alpine

# 创建应用目录
RUN mkdir -p /opt/app /opt/hypertrace

# 拷贝构建的 JAR 到运行镜像
COPY --from=build /app/build/libs/*.jar /opt/app/app.jar

# 创建 hypertrace agent 目录（agent 将通过 volume 挂载）
VOLUME ["/opt/hypertrace"]

# 暴露应用端口
EXPOSE 8080

# 设置工作目录
WORKDIR /opt/app

# 设置默认的 Spring Profile
ENV SPRING_PROFILES_ACTIVE=docker

# 运行 Spring Boot 应用，支持 Hypertrace Agent
ENTRYPOINT ["sh", "-c", "java ${JAVA_OPTS} -jar app.jar"]
