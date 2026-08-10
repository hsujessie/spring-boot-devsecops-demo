# 📊 Grafana 內建儀表板清單與監控指標詳解 (Grafana Dashboards Catalog)

本手冊詳細解析透過 **`kube-prometheus-stack`** 安裝後，Grafana 內建自動載入的 **30+ 個 Kubernetes 官方生產級儀表板** 之分類、用途與核心指標。

---

## 🔍 一、 儀表板來源與機制

當我們在 `monitoring` 命名空間部署 `kube-prometheus-stack` 時，Prometheus Operator 透過 **ConfigMap Sidecar 機制**，將 Kubernetes 官方社群精心維護的 Grafana JSON 儀表板自動掛載進 Grafana 容器中，實現**開箱即用（Out-of-the-Box）**的完整可觀測性。

---

## 📂 二、 內建儀表板分類與功能清單

```text
Grafana 儀表板分類體系
│
├── 1. 叢集計算資源 (Compute Resources) ──► 監控 CPU / 記憶體 / 磁碟容量
├── 2. 節點硬體狀態 (Node Exporter)     ──► 監控 Mac 實體主機 OS / 檔案系統 / I/O
├── 3. 叢集網路與服務 (Networking)       ──► 監控 Pod 網路頻寬 / CoreDNS 解析效能
├── 4. 監控系統自我觀測 (Self-Monitoring)──► 監控 Prometheus 抓取效率 / Alertmanager 警報
└── 5. 業務應用與 JVM (Application/JVM)  ──► 監控 Spring Boot (Java 26) / Redis / HTTP 流量
```

---

### 1. 叢集計算資源 (Compute Resources)

| 儀表板名稱 (Dashboard Name) | 核心監控指標 | 適用排查場景 |
| :--- | :--- | :--- |
| **`Kubernetes / Compute Resources / Cluster`** | 叢集總體 CPU 使用率、記憶體消耗、硬碟使用量、Pod 容量上限百分比。 | 評估整個 K8s 叢集資源是否充足，是否需要擴充硬體。 |
| **`Kubernetes / Compute Resources / Namespace (Pods)`** | 各命名空間（`default`、`monitoring`、`kube-system`）佔用的 CPU 與 Memory。 | 排查「哪一個 Namespace 佔用了最多叢集資源」。 |
| **`Kubernetes / Compute Resources / Workload`** | 特定 Deployment、StatefulSet 或 DaemonSet 的資源使用狀況。 | 觀察 `spring-boot-demo` 部署版本的資源分配與限制（Limits vs Requests）。 |
| **`Kubernetes / Compute Resources / Pod`** | 單一 Pod 內各個容器（例如：Spring Boot 容器 vs Tunnel 側車容器）的資源明細。 | 診斷單一 Pod 記憶體洩漏（OOMKilled）或 CPU 飆高問題。 |

---

### 2. 節點底層硬體狀態 (Node Exporter)

數據來源為運行在節點上的 `prometheus-node-exporter`，直接讀取宿主機（您的 Mac）底層系統數據：

| 儀表板名稱 (Dashboard Name) | 核心監控指標 | 適用排查場景 |
| :--- | :--- | :--- |
| **`Kubernetes / Compute Resources / Node (Pods)`** | 節點上運行的所有 Pod 資源佔比、系統負載 (Load Average 1m/5m/15m)。 | 檢查實體主機是否過載。 |
| **`Node Exporter / Nodes`** | 實體磁碟 I/O 讀寫速率、檔案系統剩餘空間（Disk Free %）、TCP 連線狀態數。 | 排查實體硬碟空間不足或磁碟 I/O 瓶頸。 |
| **`Node Exporter / USE Method / Cluster`** | 系統使用率 (Utilization)、飽和度 (Saturation) 與錯誤 (Errors) 的 USE 監控模型。 | 系統架構師快速評估硬體健康狀態。 |

---

### 3. 叢集網路與核心服務 (Networking & CoreDNS)

| 儀表板名稱 (Dashboard Name) | 核心監控指標 | 適用排查場景 |
| :--- | :--- | :--- |
| **`Kubernetes / Networking / Cluster`** | 跨 Pod、跨 Service 的網路封包吞吐量（Receive/Transmit Bandwidth）、封包丟失數（Drops）。 | 診斷微服務之間連線緩慢或網路擁塞。 |
| **`CoreDNS`** | K8s 內部 DNS 請求 QPS、查詢延遲時間（99th Percentile Latency）、NXDOMAIN 錯誤率。 | 排查 `spring-boot-demo-redis-service` 等內部域名解析異常或延遲問題。 |

---

### 4. 監控系統自我觀測 (Prometheus & Alertmanager)

| 儀表板名稱 (Dashboard Name) | 核心監控指標 | 適用排查場景 |
| :--- | :--- | :--- |
| **`Prometheus / Overview`** | Prometheus 抓取樣本速率（Samples Scraped/sec）、抓取耗時（Scrape Duration）、TSDB 時序資料庫大小。 | 確保 Prometheus 自身穩定運作，未發生抓取逾時。 |
| **`Alertmanager / Overview`** | 目前觸發中的告警規則數量、通知發送成功/失敗次數。 | 查看系統當前是否有任何元件發出警報。 |

---

### 5. 業務應用與 JVM 監控大盤 (Spring Boot & Redis)

除了上述 K8s 系統級儀表板外，針對我們的 Java 業務應用，推薦匯入社群標準大盤：

| 儀表板名稱 | 匯入 ID | 核心監控指標 |
| :--- | :--- | :--- |
| **JVM (Micrometer / Spring Boot)** | **`11378`** | • **JVM Memory**：Heap (Eden / Survivor / Tenured)、Non-Heap (Metaspace)<br>• **Garbage Collection**：GC 次數、GC Pause 暫停時間<br>• **Threads**：Live Threads、Peak Threads、Daemon Threads<br>• **HTTP Requests**：每秒請求量 (RPS)、HTTP 4xx / 5xx 錯誤率、請求平均延遲<br>• **Tomcat**：Active Sessions、執行緒池連線數 |
| **JVM (Micrometer)** | **`4701`** | 專注於 Java 核心指標的簡潔版 JVM 監控面板。 |

---

## 🎯 三、 Grafana 儀表板使用與導航技巧

1. **快速搜尋大盤**：
   * 進入 Grafana 點擊左側 **Dashboards**，在上方搜尋框輸入關鍵字（例如 `Node`、`Cluster`、`Pod`、`JVM`）即可秒速定位。
2. **善用頂部變數篩選器 (Variables Filter)**：
   * 許多大盤頂部提供 **`namespace`** 與 **`pod`** 下拉選單。
   * 切換至 `default` 即可聚焦觀察 `spring-boot-demo` 與 `redis`；切換至 `monitoring` 可查看 Prometheus 本身。
3. **時間範圍與自動重新整理**：
   * 右上角時間範圍建議設定為 **`Last 5 minutes`** 或 **`Last 15 minutes`**。
   * 點擊右上角重新整理按鈕旁的下拉箭頭，可開啟 **`Auto-refresh: 5s`**（每 5 秒自動跳動更新數據）。

---

## 🛡️ 四、 資安架構：監控與數據的網路隔離邊界 (Network Isolation Boundary)

在雲原生與 DevSecOps 架構中，**「監控資訊僅限內網傳輸」**是業界縱深防禦（Defense-in-Depth）的核心準則：

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

### 🔒 邊界隔離三大設計原則：
1. **業務對外開放 (Public-Facing)**：
   * 僅有 Spring Boot 的對外網頁透過 Pinggy 安全隧道提供給一般訪客存取。
2. **資料與遙測數據對內封閉 (Internal-Only)**：
   * **Redis 快取**：以 `ClusterIP` 封閉在 K8s 內部網段，外網無法掃描與探測。
   * **Prometheus 指標採集**：透過 `ServiceMonitor` 走 K8s 內部虛擬網路輪詢，不開放任何外網通訊埠。
   * **Grafana 儀表板**：僅綁定在本地端（`localhost:3000`）或企業內部 VPN，防止伺服器規格、內部 IP 拓撲與系統負載機密外洩。
