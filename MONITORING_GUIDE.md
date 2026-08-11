# 📊 Prometheus 與 Grafana 監控指南

---

## 🏗️ 監控架構

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

| 元件名稱 | 角色定位 | 專案職責 |
| :--- | :--- | :--- |
| **Spring Boot Actuator** | 指標生產者 | 收集應用內部指標（HTTP 請求、回應延遲、Tomcat 連線池、健康度）。 |
| **Micrometer Prometheus** | 格式轉換器 | 將 Actuator 內部度量轉換為 Prometheus 標準格式（OpenMetrics）。 |
| **Prometheus Operator** | 收集器與 TSDB | 跨 Namespace 定時抓取 `/actuator/prometheus` 並儲存時序資料。 |
| **Grafana** | 視覺化平台 | 查詢 Prometheus 數據並渲染即時儀表板與圖表。 |

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

* **外網公開 (Public)**：僅 Spring Boot 首頁透過 Pinggy 安全隧道提供訪客存取。
* **內網隔離 (Internal Only)**：
  * **Redis 快取**：以 `ClusterIP` 封閉在內部網段，外網無法掃描探測。
  * **Prometheus 指標採集**：透過 `ServiceMonitor` 走內部網路輪詢，不開放任何外網通訊埠。
  * **Grafana 儀表板**：僅綁定本地（`localhost:3000`），防止內部拓撲與負載資訊外洩。

---

## 🛠️ 應用端監控整合

* **Maven 依賴**：在 [pom.xml](pom.xml) 引入 `spring-boot-starter-actuator` 與 `micrometer-registry-prometheus`。
* **參數配置**：在 [application.properties](src/main/resources/application.properties) 開放 `/actuator/prometheus` 端點並標記應用名稱。
* **CRD 宣告**：在 [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml) 定義 Prometheus 每 15 秒跨 Namespace 抓取規則。

---

## 🏢 監控平台部署 (Helm)

部署於獨立的 `monitoring` 命名空間：
```bash
# 1. 新增社群 Helm 倉庫
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 2. 建立命名空間並安裝 kube-prometheus-stack
kubectl create namespace monitoring || true

helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set grafana.service.port=3000 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

---

## 📂 Grafana 常用儀表板

| 監控維度 | 推薦儀表板 / ID | 核心監控指標 |
| :--- | :--- | :--- |
| **K8s 叢集與節點** | 內建 `Compute Resources` & `Node Exporter` | 叢集 CPU/記憶體配額、Pod 狀態、主機 I/O 負載。 |
| **Spring Boot / JVM** | ⭐ 社群 **`11378`** (*JVM Micrometer*) | JVM Heap、GC 暫停、HTTP 請求量 (RPS) 與 Tomcat 連線數。 |

---

## 📈 常用 PromQL 與流量驗證

* **JVM Heap 記憶體使用率**：
  `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100`
* **系統 CPU 使用率**：
  `system_cpu_usage * 100`
* **每秒 HTTP 請求量 (RPS)**：
  `rate(http_server_requests_seconds_count[1m])`

**流量模擬測試**（發送 30 次請求以觀察 Grafana 即時波形）：
```bash
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done
```
