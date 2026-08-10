# 📊 Prometheus 與 Grafana 雲原生可觀測性監控指南 (Observability & Monitoring Guide)

本指南詳細說明如何在 Spring Boot (Java 26)、Redis、Kubernetes (Helm) 專案中整合 **Prometheus** 與 **Grafana** 建立業界生產級的雲原生可觀測性體系（Observability Stack），並整合業界 Namespace 隔離最佳實踐與官方儀表板清單。

---

## 🏗️ 一、 系統監控運行架構圖

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│  【業務區：default 命名空間】                                                      │
│   ├── [Spring Boot Pod 副本] (Java 26) ──► 暴露 /actuator/prometheus             │
│   ├── [Redis Pod] (快取資料庫)                                                    │
│   └── [ServiceMonitor] (宣告式服務發現與跨空間指標採集規則 CRD)                    │
│                                                                                  │
│                                 ▲ (跨 Namespace 宣告式指標採集)                  │
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
  --set grafana.service.port=3000 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

---

## 🛠️ 四、 應用端配置與 ServiceMonitor 宣告

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

### 3. ServiceMonitor 宣告式跨空間指標採集定義 (`templates/servicemonitor.yaml`)
```yaml
apiVersion: monitoring.coreos.com/v1
kind: ServiceMonitor
metadata:
  name: {{ .Release.Name }}-servicemonitor
  labels:
    app: {{ .Release.Name }}
    release: prometheus-stack # 關聯至 kube-prometheus-stack Release
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

## 📂 五、 Grafana 內建 30+ 官方大盤分類與功能清單

當部署 `kube-prometheus-stack` 後，Prometheus Operator 會透過 ConfigMap Sidecar 自動掛載業界經過生產驗證的專業儀表板：

### 1. 叢集計算資源 (Compute Resources)
* **`Kubernetes / Compute Resources / Cluster`**：監控整個 K8s 叢集總體 CPU、記憶體、硬碟使用率與容器配額。
* **`Kubernetes / Compute Resources / Namespace (Pods)`**：按命名空間（`default` 業務區 vs `monitoring` 維運區）分析個別 Pod 資源消耗。
* **`Kubernetes / Compute Resources / Workload`**：觀察 Deployment 與 StatefulSet 的資源分配與限制（Limits vs Requests）。
* **`Kubernetes / Compute Resources / Pod`**：單一 Pod 內各容器（Spring Boot 主應用 vs Tunnel 側車）資源明細，用於診斷 OOMKilled 或 CPU 飆高。

### 2. 節點硬體狀態 (Node Exporter)
* **`Kubernetes / Compute Resources / Node (Pods)`**：讀取宿主機（您的 Mac 實體機）系統負載 (Load Average 1m/5m/15m)。
* **`Node Exporter / Nodes`**：實體磁碟 I/O 讀寫速率、檔案系統剩餘空間（Disk Free %）、TCP 連線狀態數。

### 3. 叢集網路與核心服務 (Networking & CoreDNS)
* **`Kubernetes / Networking / Cluster`**：跨 Pod 網路封包吞吐量（Throughput）與封包丟失數（Drops）。
* **`CoreDNS`**：K8s 內部 DNS 請求 QPS、查詢延遲時間（Latency）、解析錯誤率。

### 4. 業務應用與 JVM 大盤 (Spring Boot & Redis)
* ⭐ **Dashboard ID: `11378`** —— *JVM (Micrometer / Spring Boot)*（最推薦）
  * **JVM Memory**：Heap (Eden / Survivor / Tenured)、Non-Heap (Metaspace)。
  * **Garbage Collection**：GC 次數、GC Pause 暫停時間。
  * **Threads**：Live Threads、Peak Threads、Daemon Threads。
  * **HTTP Requests**：每秒請求量 (RPS)、HTTP 4xx / 5xx 錯誤率、請求平均延遲。
  * **Tomcat**：Active Sessions、執行緒池連線數。
* ⭐ **Dashboard ID: `4701`** —— *JVM (Micrometer)* 簡潔版。

---

## 🛡️ 六、 資安架構：監控數據的網路隔離邊界 (Network Isolation Boundary)

在 DevSecOps 架構中，**「監控遙測數據僅限內網傳輸」**是縱深防禦（Defense-in-Depth）的核心準則：

```text
┌──────────────────────── 外部網際網路 (Public Internet) ────────────────────────┐
│                                                                                │
│   外部用戶 ──(僅能存取)──► [Pinggy HTTPS 隧道] ──► [Spring Boot 8080 業務首頁]   │
│                                                                                │
├──────────────────────── 內部隔離區 (K8s Private Network) ──────────────────────┤
│                                                                                │
│   [Spring Boot] ───(ClusterIP 6379 內網)────► [Redis 快取資料庫] (外網不可見)  │
│         │                                                                      │
│         └───(ServiceMonitor 內網輪詢)───────► [Prometheus TSDB] (外網不可見)   │
│                                                     │                          │
│                                                     ▼ (內部 PromQL 查詢)       │
│                                                [Grafana 平台] (僅限本機/內網)   │
│                                                                                │
└────────────────────────────────────────────────────────────────────────────────┘
```

1. **業務對外開放 (Public-Facing)**：僅 Spring Boot 首頁透過 Pinggy 安全隧道提供訪客存取。
2. **資料與遙測對內封閉 (Internal-Only)**：
   * **Redis 快取**：以 `ClusterIP` 封閉在 K8s 內部網段，外網無法掃描探測。
   * **Prometheus 指標採集**：透過 `ServiceMonitor` 走 K8s 內部虛擬網路輪詢，不開放任何外網通訊埠。
   * **Grafana 儀表板**：僅綁定在本地端（`localhost:3000`）或企業內部 VPN，防止伺服器規格、內部 IP 拓撲與系統負載機密外洩。

---

## 📈 七、 常用 PromQL 查詢與流量模擬

### 1. 常用 PromQL 語法
* **JVM 堆積記憶體使用率**：
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
