# 📊 Prometheus 與 Grafana 監控指南

---

## 🏗️ 系統監控架構圖

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│  【應用程式命名空間: default】                                                      │
│   ├── [Spring Boot Pod 副本] (Java 26) ──► 暴露 /actuator/prometheus             │
│   ├── [Redis Pod] (快取資料庫)                                                    │
│   └── [ServiceMonitor] (宣告式跨空間指標採集規則 CRD)                              │
│                                                                                  │
│                                 ▲ (跨 Namespace 指標採集)                         │
│                                 │                                                │
│  【監控命名空間: monitoring】 (kube-prometheus-stack)                             │
│   ├── [Prometheus Operator] (時序資料庫 TSDB)                                    │
│   ├── [Node Exporter] (主機 CPU / 記憶體 / 磁碟監控)                              │
│   ├── [Kube-State-Metrics] (K8s Pod 狀態與重啟次數)                               │
│   └── [Grafana 平台] ──► localhost:3000 (視覺化儀表板)                            │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔍 核心元件職責

| 元件名稱 | 角色定位 | 具體職責 |
| :--- | :--- | :--- |
| **Spring Boot Actuator** | 指標生產者 | 收集應用內部指標（HTTP 請求、回應延遲、Tomcat 連線池、健康度）。 |
| **Micrometer Prometheus** | 格式轉換器 | 將 Actuator 內部度量轉換為 Prometheus 標準格式（OpenMetrics）。 |
| **Prometheus Operator** | 收集器與 TSDB | 跨 Namespace 定時抓取 `/actuator/prometheus` 並儲存時序資料。 |
| **Grafana** | 視覺化平台 | 查詢 Prometheus 數據並渲染即時儀表板與圖表。 |

---

## 🏢 獨立 Monitoring 命名空間部署

將監控系統部署於獨立的 `monitoring` 命名空間：

### 1. 新增社群 Helm 倉庫
```bash
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update
```

### 2. 建立 `monitoring` 命名空間
```bash
kubectl create namespace monitoring || true
```

### 3. 安裝 `kube-prometheus-stack`
```bash
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set grafana.service.port=3000 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

---

## 🛠️ 應用端配置與 ServiceMonitor 宣告

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
management.metrics.tags.application=spring-boot-demo
```

### 3. ServiceMonitor 定義 (`templates/servicemonitor.yaml`)
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

## 📂 Grafana 常用儀表板清單

`kube-prometheus-stack` 內建常用官方儀表板：

### 1. 叢集與計算資源
* **`Kubernetes / Compute Resources / Cluster`**：叢集總體 CPU、記憶體與容器配額。
* **`Kubernetes / Compute Resources / Namespace (Pods)`**：按命名空間分析 Pod 資源消耗。
* **`Kubernetes / Compute Resources / Workload`**：Deployment 資源限制與分配（Limits / Requests）。
* **`Kubernetes / Compute Resources / Pod`**：單一 Pod 內各容器資源明細（診斷 OOMKilled / CPU 飆高）。

### 2. 節點與硬體狀態
* **`Kubernetes / Compute Resources / Node (Pods)`**：本機系統負載 (Load Average 1m/5m/15m)。
* **`Node Exporter / Nodes`**：磁碟 I/O 讀寫速率、剩餘空間、網路流量與 TCP 連線數。

### 3. 網路與核心服務
* **`Kubernetes / Networking / Cluster`**：跨 Pod 網路吞吐量與丟包統計。
* **`CoreDNS`**：內部 DNS 查詢 QPS、延遲與解析錯誤率。

### 4. 應用程式與 JVM 大盤
* ⭐ **Dashboard ID: `11378`** —— *JVM (Micrometer / Spring Boot)*（推薦）
  * **JVM Memory**：Heap (Eden / Survivor / Tenured) 與 Metaspace。
  * **Garbage Collection**：GC 次數與 GC Pause 暫停時間。
  * **Threads**：Live Threads、Peak Threads、Daemon Threads。
  * **HTTP Requests**：每秒請求量 (RPS)、HTTP 4xx / 5xx 錯誤率與平均延遲。
  * **Tomcat**：Active Sessions 與執行緒池連線數。
* ⭐ **Dashboard ID: `4701`** —— *JVM (Micrometer)* 簡潔版。

---

## 🛡️ 網路隔離與資安邊界

```text
┌──────────────────────── 外部網際網路 (Public Internet) ────────────────────────┐
│                                                                                │
│   外部用戶 ──(僅限存取)──► [Pinggy HTTPS 隧道] ──► [Spring Boot (8080 首頁)]     │
│                                                                                │
├──────────────────────── 內部隔離區 (K8s Private Network) ──────────────────────┤
│                                                                                │
│   [Spring Boot] ───(ClusterIP:6379 內網)───► [Redis 快取資料庫] (外網隔離)     │
│         │                                                                      │
│         └───(ServiceMonitor 內網輪詢)──────► [Prometheus TSDB] (外網隔離)      │
│                                                     │                          │
│                                                     ▼ (內部 PromQL 查詢)       │
│                                                [Grafana 平台] (僅限本地 3000)   │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

1. **外網公開 (Public)**：僅 Spring Boot 首頁透過 Pinggy 安全隧道提供訪客存取。
2. **內網隔離 (Internal Only)**：
   * **Redis 快取**：以 `ClusterIP` 封閉在內部網段，外網無法掃描探測。
   * **Prometheus 指標採集**：透過 `ServiceMonitor` 走內部網路輪詢，不開放任何外網通訊埠。
   * **Grafana 儀表板**：僅綁定本地（`localhost:3000`），防止內部拓撲與系統負載機密外洩。

---

## 📈 常用 PromQL 查詢與流量模擬

### 1. 常用 PromQL
* **JVM Heap 記憶體使用率**：
  `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100`
* **系統 CPU 使用率**：
  `system_cpu_usage * 100`
* **每秒 HTTP 請求量 (RPS)**：
  `rate(http_server_requests_seconds_count[1m])`

### 2. 流量模擬測試
在終端機執行快速請求以觀察即時波形變化：
```bash
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done
```
