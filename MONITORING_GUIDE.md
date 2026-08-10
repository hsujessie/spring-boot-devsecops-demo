# 📊 Prometheus 與 Grafana 監控架構與整合指南

本指南詳細說明如何在 Spring Boot (Java 26)、Redis、Kubernetes (Helm) 專案中整合 **Prometheus** 與 **Grafana** 建立完整的雲原生可觀測性體系（Observability Stack）。

---

## 🏗️ 一、 系統監控運行架構圖

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│   [Spring Boot Pod] ──(1. 暴露 JVM 指標)──► http://<Pod-IP>:8080/actuator/prometheus│
│          ▲                                                 │                     │
│          │ (快取連線)                                      ▼ (2. 每15秒主動抓取) │
│   [Redis 快取服務]                                   [Prometheus 監控資料庫]     │
│                                                            │                     │
│                                                            ▼ (3. PromQL 查詢數據)│
│   [瀏覽器用戶] ◄────────(4. 視覺化動態圖表)─────────── [Grafana 儀表板平台]      │
│   (http://localhost:3000)                                                        │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 二、 核心元件職責與分工

| 元件名稱 | 角色定位 | 在本專案中的具體職責 |
| :--- | :--- | :--- |
| **Spring Boot Actuator** | **指標生產者** | 收集 Spring Boot 內部運作數據（HTTP 請求次數、回應時間、Tomcat 連線池、系統健康度）。 |
| **Micrometer Prometheus** | **格式轉換器** | 將 Java 與 Actuator 的內部數據轉換為 Prometheus 看得懂的標準格式（OpenMetrics 格式）。 |
| **Prometheus** | **收集器與時序資料庫 (TSDB)** | 透過 K8s 內部網路定時輪詢（Pull）Spring Boot 的 `/actuator/prometheus`，並將帶有時間戳記的指標存入記憶體與磁碟。 |
| **Grafana** | **數據視覺化平台** | 連接 Prometheus 作為 Data Source，透過 PromQL 查詢語言渲染即時折線圖、儀表盤、長條圖等。 |

---

## 🛠️ 三、 實作設定詳解

### 1. Spring Boot 端配置
*   **Maven 依賴 (`pom.xml`)**：
    ```xml
    <dependency>
        <groupId>org.springframework.boot</groupId>
        <artifactId>spring-boot-starter-actuator</artifactId>
    </dependency>
    <dependency>
        <groupId>io.micrometer</groupId>
        <artifactId>micrometer-registry-prometheus</artifactId>
    </dependency>
    ```
*   **配置參數 (`application.properties`)**：
    ```properties
    # 開放監控端點
    management.endpoints.web.exposure.include=health,info,prometheus
    management.endpoint.prometheus.enabled=true
    # 增加監控指標的常用標籤
    management.metrics.tags.application=spring-boot-demo
    ```

---

### 2. Kubernetes / Helm 端配置
*   **Prometheus 服務 (`templates/prometheus.yaml`)**：
    *   運行 `prom/prometheus:latest` 映像檔。
    *   透過 ConfigMap 設定 `scrape_configs`，目標指向 `spring-boot-demo-service:8080`，抓取路徑為 `/actuator/prometheus`。
    *   透過內部 Service 暴露 `9090` Port。
*   **Grafana 服務 (`templates/grafana.yaml`)**：
    *   運行 `grafana/grafana:latest` 映像檔。
    *   透過 Provisioning ConfigMap 自動載入 `http://spring-boot-demo-prometheus-service:9090` 為預設資料來源。
    *   以 `type: LoadBalancer` 暴露 Port `3000`，使本地瀏覽器可直接開啟 `http://localhost:3000`。

---

## 📈 四、 常用 PromQL 查詢與熱門 Dashboard

### 1. 常見 PromQL 查詢範例
當您在 Prometheus 或 Grafana 查詢時，可使用以下 PromQL 語法：
*   **JVM 堆積記憶體使用率**：
    `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100`
*   **系統 CPU 使用率**：
    `system_cpu_usage * 100`
*   **每秒 HTTP 請求量 (RPS)**：
    `rate(http_server_requests_seconds_count[1m])`

### 2. 推薦匯入的 Grafana 儀表板
登入 Grafana 後，點選 **Dashboards -> New -> Import**，輸入以下熱門 Dashboard ID 即可一鍵載入官方社群精心設計的 Spring Boot 監控大盤：
*   ⭐ **Dashboard ID: `11378`** —— *JVM (Micrometer / Spring Boot)*（最推薦，涵蓋 JVM Heap/Non-Heap、GC 時間、執行緒 Threads、CPU、Tomcat Session）
*   ⭐ **Dashboard ID: `4701`** —— *JVM (Micrometer)*
