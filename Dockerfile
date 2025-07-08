# ==== 构建阶段 ====
FROM --platform=linux/amd64 gradle:8.5-jdk17-alpine AS build

# 将项目源代码复制到容器
COPY --chown=gradle:gradle . /home/gradle/src
WORKDIR /home/gradle/src

# 使用 Gradle 构建可执行 JAR（跳过测试以缩短镜像构建时间）
RUN gradle clean build -x test --no-daemon

# ==== 运行阶段 ====
FROM --platform=linux/amd64 eclipse-temurin:17-jre-alpine

# 拷贝构建的 JAR 到运行镜像
COPY --from=build /home/gradle/src/build/libs/*.jar app.jar

# 暴露应用端口
EXPOSE 8080

# 运行 Spring Boot 应用
ENTRYPOINT ["java","-jar","/app.jar"]
