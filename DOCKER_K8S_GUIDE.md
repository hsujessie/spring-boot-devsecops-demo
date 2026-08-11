# 🐳 Docker、K8s 與 Helm 容器化部署架構

---

## 🏗️ Docker 與 Helm 配置
* **[Dockerfile](Dockerfile)**：多階段建置，產出非 root 唯讀映像檔。
* **[Chart.yaml](charts/spring-boot-demo/Chart.yaml)**：Helm Chart 描述與版本資訊。
* **[values.yaml](charts/spring-boot-demo/values.yaml)**：全域部署參數（映像檔倉庫、Tag 與副本數）。
* **[deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)**：Spring Boot 應用程式與 Tunnel 側車容器（注入 `REDIS_HOST`）。
* **[service.yaml](charts/spring-boot-demo/templates/service.yaml)**：LoadBalancer 服務，映射 8080 埠。
* **[redis.yaml](charts/spring-boot-demo/templates/redis.yaml)**：Redis Deployment 與內部 ClusterIP 服務（外網隔離）。
* **[servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml)**：Prometheus Operator 跨命名空間指標採集規則。

---

## 🤝 Docker、K8s 與 Helm 核心職責

| 技術 | 實體比喻 | 在本專案中的職責 |
| :--- | :--- | :--- |
| **Docker** | **集裝箱（貨櫃）** | **包裝與隔離**。將 Spring Boot 應用與 JRE 封裝為不可變映像檔，確保各環境運行一致。 |
| **Kubernetes (K8s)** | **物流港口與貨輪** | **調度與編排**。管理 Pod 生命週期、健康檢查、負載平衡並維持指定副本數。 |
| **Helm** | **裝箱清單與自動安裝手冊** | **套件管理與模板化**。將 K8s YAML 封裝為 Chart 並抽離可變參數（如 `values.yaml` 中的 tag），實現參數化一鍵部署。 |

---

## 🌐 側車容器 (Sidecar)、Redis 與網路架構
Pod 內部共享 Localhost 網路空間（含 Spring Boot 與 Tunnel 雙容器），並連線至內部 Redis：
* **`spring-boot-demo`**：Spring Boot 應用程式容器（Port 8080），透過 `REDIS_HOST` 連線至內部 Redis 進行瀏覽計數。
* **`redis`**：獨立服務（Port 6379），透過 ClusterIP 供內部讀寫，不對外公開以確保安全。
* **`tunnel` (Sidecar)**：反向 SSH 隧道容器，連線至 Pinggy 將外網流量轉發至 `127.0.0.1:8080`，由 `local_deploy.sh` 自動抓取日誌輸出存取網址。
```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                 ☸️ Kubernetes (Helm) 部署架構與 Sidecar 網路機制詳解           │
├─────────────────────────────────────────────────────────────────────────────┤
│                                                                             │
│  【Kubernetes 叢集 (Docker Desktop)】                                        │
│                                                                             │
│   ┌──【應用程式命名空間: default】───────────────────────────────────────────┐   │
│   │                                                                      │   │
│   │   ┌── Pod (共運行 2 個副本 ── 每個 Pod 內部雙容器共享 Localhost) ───────┐   │   │
│   │   │                                                              │   │   │
│   │   │  [spring-boot-demo 主容器] (Java 26 / 監聽 8080 埠)          │   │   │
│   │   │        ▲                                                     │   │   │
│   │   │        │ (1. 本地轉發流量: 127.0.0.1:8080)                    │   │   │
│   │   │        │                                                     │   │   │
│   │   │  [tunnel 側車容器 (Sidecar)] (Alpine / SSH 客戶端)           │   │   │
│   │   │        ▲                                                     │   │   │
│   │   └────────┼─────────────────────────────────────────────────────┘   │   │
│   │            │                                                         │   │
│   │            │ (2. 內網讀寫瀏覽計數: REDIS_HOST:6379)                  │   │
│   │            ▼                                                         │   │
│   │   ┌────────────────────────┐             ┌───────────────────────┐   │   │
│   │   │ [Redis ClusterIP 服務] │ ──────────► │ [Redis 快取 Pod]      │   │   │
│   │   │ (內部 Service: 6379)   │ (流量導向)   │ (獨立運行 / 外網隔離) │   │   │
│   │   └────────────────────────┘             └───────────────────────┘   │   │
│   │                                                                      │   │
│   │   ┌──────────────────────────────────────────────────────────────┐   │   │
│   │   │ [ServiceMonitor CRD] (跨 Namespace 宣告式指標抓取端點)       │   │   │
│   │   └──────────────────────────────────────────────────────────────┘   │   │
│   └──────────────────────────────────────┬───────────────────────────────┘   │
│                                          │                                   │
│                                          │ (3. 建立 SSH 反向隧道連線: 443 埠) │
│                                          ▼                                   │
│              [Pinggy 公開 HTTPS 網址] ◄─── (瀏覽器存取) ─── [外部用戶]         │
│                                                                             │
└─────────────────────────────────────────────────────────────────────────────┘
```