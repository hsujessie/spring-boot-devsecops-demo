# 📊 Prometheus 與 Grafana 監控指南

---

## 🛠️ 應用端監控配置

| 項目 | 檔案 | 說明 |
| :--- | :--- | :--- |
| **Maven 依賴** | [pom.xml](pom.xml) | 引入 `spring-boot-starter-actuator` 與 `micrometer-registry-prometheus`。 |
| **參數配置** | [application.properties](src/main/resources/application.properties) | 開放 `/actuator/prometheus` 監控端點並標記應用名稱。 |
| **CRD 宣告** | [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml) | 定義 Prometheus 每 15 秒跨命名空間採集（Scrape）規則。 |

---

## 🤝 監控元件分工

| 元件 | 角色 | 功能 |
| :--- | :--- | :--- |
| **Spring Boot Actuator** | 指標生產者 | 收集應用內部指標（HTTP 請求、回應延遲、Tomcat 連線池、健康度）。 |
| **Micrometer Prometheus** | 格式轉換器 | 將 Actuator 內部度量轉換為 Prometheus 標準格式（OpenMetrics）。 |
| **Prometheus** | 收集器與 TSDB | 跨命名空間定時採集 `/actuator/prometheus` 並儲存時序資料。 |
| **Grafana** | 視覺化平台 | 查詢 Prometheus 數據並渲染即時儀表板與圖表。 |

---

## 🏗️ 監控架構

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│  【應用程式命名空間: default】                                                   │
│   ├── [Spring Boot] (主程式) ──► 暴露 /actuator/prometheus                       │
│   ├── [Redis] (快取資料庫)                                                       │
│   ├── [Tunnel] (SSH 反向隧道)                                                    │
│   └── [ServiceMonitor] (CRD 跨命名空間指標採集規則)                              │
│                                                                                  │
│                                 ▲ (跨命名空間指標採集)                           │
│                                 │                                                │
│  【監控命名空間: monitoring】                                                    │
│   ├── [Prometheus] (TSDB 時序庫)                                                 │
│   ├── [Node Exporter] (主機 CPU / 記憶體 / 磁碟監控)                             │
│   ├── [Kube-State-Metrics] (K8s Pod 狀態與重啟次數)                              │
│   └── [Grafana] (視覺化平台) ──► localhost:3000                                  │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🛡️ 網路隔離與資安邊界

```text
┌──────────────────────── 外部網際網路 (Public Internet) ──────────────────────────┐
│                                                                                  │
│   外部用戶 ──(僅限存取)──► [Pinggy 公開 HTTPS 網址] ──► [Spring Boot 主程式]     │
│                                                                                  │
├──────────────────────── 內部隔離區 (K8s Private Network) ────────────────────────┤
│                                                                                  │
│   [Spring Boot 主程式] ──(ClusterIP:6379 內網)──► [Redis 快取資料庫] (外網隔離)  │
│         │                                                                        │
│         └───(ServiceMonitor 內網採集)──────► [Prometheus] (外網隔離)             │
│                                                     │                            │
│                                                     ▼ (內部 PromQL 查詢)         │
│                                                [Grafana 視覺化平台]              │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
```

| 項目 | 傳輸路徑 (起點 ➔ 終點) | 安全防護機制 |
| :--- | :--- | :--- |
| **外部存取** | 外部用戶 ➔ Spring Boot (`:8080`) | 透過 Pinggy HTTPS 反向隧道安全穿透，隱藏真實主機 IP。 |
| **Redis 快取** | Spring Boot ➔ Redis (`:6379`) | 走 `ClusterIP` 內網專用通訊，外網隔離無法直接存取。 |
| **指標採集** | Prometheus ➔ Spring Boot (`:8080`) | 透過 `ServiceMonitor` 跨命名空間內網採集，無對外公開通訊埠。 |
| **儀表板查詢** | Grafana ➔ Prometheus (`TSDB`) | 執行內部 PromQL 查詢，服務僅限本地 `localhost:3000` 存取。 |

---

<div id="helm-deploy"></div>

## 🏢 監控平台部署 (Helm)

> 💡 **快速安裝指引**：具體 Helm 部署指令已整合於 [README.md 的快速開始](README.md#init-monitoring)。

* 🎯 **核心作用**：在獨立的 `monitoring` 命名空間建立常駐的 Prometheus 與 Grafana 平台，並啟用自定義資源控制器 (CRD)，使 K8s 能正確解析 [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml) 執行跨命名空間指標採集。

### 關鍵參數說明
| 參數設定 | 作用與設計考量 |
| :--- | :--- |
| `--namespace monitoring` | 將監控組件與業務應用程式（`default`）實體隔離。 |
| `--set grafana.service.type=LoadBalancer`<br>`--set grafana.service.port=3000` | 自動綁定本地 `3000` 埠，瀏覽器可直接透過 `http://localhost:3000` 存取。 |
| `--set prometheus...serviceMonitorSelectorNilUsesHelmValues=false` | **關鍵設定**。允許 Prometheus 自動跨命名空間採集 `default` 下的 Spring Boot Actuator 指標。 |
| `--set grafana.adminPassword=admin` | 指定 Grafana 管理員密碼為 `admin`，方便本地開發與展示快速登入。 |

---

## 📂 Grafana 常用儀表板

| 監控項目 | 儀表板 / ID | 核心指標 |
| :--- | :--- | :--- |
| **K8s 叢集與節點** | 內建 `Compute Resources` & `Node Exporter` | 叢集 CPU/記憶體配額、Pod 狀態、主機 I/O 負載。 |
| **Spring Boot / JVM** | Dashboard ID **`11378`** (*JVM Micrometer*) | JVM Heap、GC 暫停、HTTP 請求量 (RPS) 與 Tomcat 連線數。 |

---

## 📈 常用 PromQL 與流量驗證

| 監控指標 | PromQL 查詢語法 | 說明 |
| :--- | :--- | :--- |
| **JVM Heap 記憶體** | `jvm_memory_used_bytes{area="heap"} / jvm_memory_max_bytes{area="heap"} * 100` | 計算堆積記憶體使用百分比 (%)。 |
| **系統 CPU 使用率** | `system_cpu_usage * 100` | 監控主機/容器整體 CPU 負載 (%)。 |
| **每秒請求量 (RPS)** | `rate(http_server_requests_seconds_count[1m])` | 統計最近 1 分鐘 HTTP 吞吐率。 |

**流量模擬測試**（發送 30 次請求以觀察 Grafana 即時波形）：
```bash
for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done
```
