# ─── 階段一：Build 階段 (Multi-stage Build) ───
# 使用輕量級 Alpine 鏡像進行編譯，減少最終產物體積
FROM maven:3-eclipse-temurin-26 AS builder

WORKDIR /app
COPY pom.xml .
COPY src ./src

# 執行 Maven 打包
RUN mvn clean package -DskipTests

# ─── 階段二：運行階段 (最小化攻擊面 Runtime) ───
# 使用 JRE Alpine 輕量版，不包含開發工具，降低被入侵後的危害
FROM eclipse-temurin:26-jre-alpine

WORKDIR /app

# 資安最佳實踐 1：建立並使用非 root 專用帳號 (Non-root user)
# 使用明確的 UID 1000 與 GID 1000，以便在 K8s SecurityContext 中精確控管
RUN addgroup -g 1000 -S appgroup && adduser -u 1000 -S appuser -G appgroup

# 從 builder 階段只複製產出的 jar 包
COPY --from=builder /app/target/*.jar app.jar

# 將檔案擁有權交給非 root 用戶
RUN chown -R appuser:appgroup /app

# 切換為非 root 用戶執行
USER appuser

EXPOSE 8080

# 使用 exec 形式啟動 Java，讓容器能正確接收 SIGTERM 訊號
ENTRYPOINT ["java", "-jar", "app.jar"]