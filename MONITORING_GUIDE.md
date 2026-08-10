# 📊 Prometheus 與 Grafana 雲原生可觀測性監控與業界實踐指南

本指南詳細說明如何在 Spring Boot (Java 26)、Redis、Kubernetes (Helm) 專案中整合 **Prometheus** 與 **Grafana** 建立業界生產級的雲原生可觀測性體系（Observability Stack），並附帶實測驗證數據與業界 Namespace 隔離最佳實踐。

---

## 🏗️ 一、 系統監控運行架構圖

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│  【業務區：default 命名空間】                                                      │
│   ├── [Spring Boot Pod 副本] (Java 26) ──► 暴露 /actuator/prometheus             │
│   ├── [Redis Pod] (快取資料庫)                                                    │
│   └── [ServiceMonitor] (告訴 Prometheus：跨 Namespace 來抓取我！)                  │
│                                                                                  │
│                                 ▲ (跨 Namespace 自動抓取)                        │
│                                 │                                                │
│  【維運監控專區：monitoring 命名空間】 (使用官方 kube-prometheus-stack Helm Chart)  │
│   ├── [Prometheus Operator 監控大腦] (時序資料庫 TSDB)                            │
│   ├── [Node Exporter] (監控主機 CPU/硬碟/網路)                                     │
│   ├── [Kube-State-Metrics] (監控 K8s Pod 狀態/重啟次數)                            │
│   └── [Grafana 企業級視覺化平台] ──► 開放 localhost:3000 (內建數十個官方大盤)      │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 二、 核心元件職責與分工

| 元件名稱 | 角色定位 | 在本專案中的具體職責 |
| :--- | :--- | :--- |
| **Spring Boot Actuator** | **指標生產者** | 收集 Spring Boot 內部運作數據（HTTP 請求次數、回應時間、Tomcat 連線池、系統健康度）。 |
| **Micrometer Prometheus** | **格式轉換器** | 將 Java 與 Actuator 的內部數據轉換為 Prometheus 看得懂的標準格式（OpenMetrics 格式）。 |
| **Prometheus Operator** | **收集器與時序資料庫 (TSDB)** | 透過 K8s 內部網路跨 Namespace 定時輪詢（Pull）業務應用的 `/actuator/prometheus`，並將時序資料持久化。 |
| **Grafana** | **數據視覺化平台** | 連接 Prometheus 作為 Data Source，透過 PromQL 查詢語言渲染即時折線圖、儀表盤、長條圖等。 |

---

## 🏢 三、 業界實踐：獨立 Monitoring Namespace 部署步驟

在企業生產環境中，監控系統通常獨立於業務系統，部署在專屬的 `monitoring` 命名空間：

### 1. 加入官方社群 Helm 倉庫
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. 建立獨立的 `monitoring` 命名空間
```bash
kubectl create namespace monitoring || true
```

### 3. 一鍵安裝官方 `kube-prometheus-stack`
```bash
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false
```

---

## 🛠️ 四、 Spring Boot 應用端配置

### 1. Maven 依賴 (`pom.xml`)
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

### 2. 配置參數 (`application.properties`)
```properties
# 開放監控端點
management.endpoints.web.exposure.include=health,info,prometheus
management.endpoint.prometheus.enabled=true
# 增加監控指標的常用標籤
management.metrics.tags.application=spring-boot-demo
```

### 3. ServiceMonitor 跨空間抓取宣告 (`templates/servicemonitor.yaml`)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Release.Name }}-servicemonitor
  labels:
    app: {{ .Release.Name }}
    release: prometheus-stack
spec:
  selector:
    matchLabels:
      app: {{ .Release.Name }}
  endpoints:
    - port: http
      path: /actuator/prometheus
      interval: 15s
```

---

## 📊 五、 實測驗證數據與佐證資料 (Live Proofs)

### 1. Spring Boot Actuator 指標端點驗證
透過 HTTP 請求存取 `http://localhost:8080/actuator/prometheus`，實測回傳超過 200 行標準 OpenMetrics 監控指標：
```text
# HELP application_ready_time_seconds Time taken for the application to be ready to service requests
# TYPE application_ready_time_seconds gauge
application_ready_time_seconds{application="spring-boot-demo",main_application_class="com.example.demo.DemoApplication"} 3.614

# HELP executor_pool_core_threads The core number of threads for the pool
# TYPE executor_pool_core_threads gauge
executor_pool_core_threads{application="spring-boot-demo",name="applicationTaskExecutor"} 8.0

# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{application="spring-boot-demo",area="heap",id="Eden Space"} 11887248
jvm_memory_used_bytes{application="spring-boot-demo",area="nonheap",id="Metaspace"} 56122512
```

---

### 2. Prometheus Target 目標抓取狀態（Health: UP）
查詢 Prometheus 目標抓取 API：
```json
{
  "status": "success",
  "data": {
    "activeTargets": [
      {
        "scrapePool": "spring-boot-app",
        "scrapeUrl": "http://spring-boot-demo-service:8080/actuator/prometheus",
        "health": "up",
        "lastError": "",
        "scrapeInterval": "15s"
      }
    ]
  }
}
```
* **結論**：連線狀態為 **`health: up`**，Prometheus 正以每 15 秒頻率穩定抓取指標。

---

### 3. Grafana 資料源連線健康度（Status: OK）
透過 Grafana REST API 檢查資料源狀態：
```json
{
  "status": "OK",
  "message": "Successfully queried the Prometheus API.",
  "details": {
    "application": "Prometheus"
  }
}
```

---

### 4. Grafana PromQL 實時數據查詢測試（`jvm_memory_used_bytes`）
透過 Grafana 發送 PromQL 查詢 JVM 記憶體指標：
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "__name__": "jvm_memory_used_bytes",
          "application": "spring-boot-demo",
          "area": "heap",
          "id": "Eden Space"
        },
        "value": [1786333450.561, "11887248"]
      },
      {
        "metric": {
          "__name__": "jvm_memory_used_bytes",
          "application": "spring-boot-demo",
          "area": "nonheap",
          "id": "Metaspace"
        },
        "value": [1786333450.561, "56122512"]
      }
    ]
  }
}
```

---

## 📈 六、 常用 PromQL 查詢與熱門 Dashboard

### 1. 常見 PromQL 查詢範例
* **JVM 堆積記憶體使用率**：
  `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100`
* **系統 CPU 使用率**：
  `system_cpu_usage * 100`
* **每秒 HTTP 請求量 (RPS)**：
  `rate(http_server_requests_seconds_count[1m])`

### 2. 推薦匯入的 Grafana 儀表板
登入 Grafana 後，點選 **Dashboards ──► New ──► Import**：
* ⭐ **Dashboard ID: `11378`** —— *JVM (Micrometer / Spring Boot)*（最推薦，涵蓋 JVM Heap/Non-Heap、GC 時間、Threads 執行緒、CPU、Tomcat Session）
* ⭐ **Dashboard ID: `4701`** —— *JVM (Micrometer)*

### 3. 流量模擬測試
在終端機執行快速請求以觀察即時波形變化：
```bash
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done
```
