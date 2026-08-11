# 🐳 Docker、K8s 與 Helm 容器化部署架構

---

## 🛠️ Docker 與 Helm 配置

| 項目 | 檔案 | 說明 |
| :--- | :--- | :--- |
| **映像建置** | [Dockerfile](Dockerfile) | 多階段建置與非 root 唯讀映像檔。 |
| **Chart 定義** | [Chart.yaml](charts/spring-boot-demo/Chart.yaml) | Helm Chart 描述與版本資訊。 |
| **全域參數** | [values.yaml](charts/spring-boot-demo/values.yaml) | 全域部署參數（映像檔倉庫、Tag 與副本數）。 |
| **應用部署** | [deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml) | Spring Boot 應用程式與 Tunnel 側車容器（Pinggy SSH 反向隧道，注入 `REDIS_HOST`）。 |
| **負載平衡** | [service.yaml](charts/spring-boot-demo/templates/service.yaml) | LoadBalancer 服務，映射 8080 埠。 |
| **內部快取** | [redis.yaml](charts/spring-boot-demo/templates/redis.yaml) | Redis 快取部署與內部服務（ClusterIP 外網隔離）。 |
| **指標採集** | [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml) | Prometheus 跨命名空間指標採集規則（CRD）。 |

---

## 🤝 核心技術分工

| 技術 | 角色 | 功能 |
| :--- | :--- | :--- |
| **Docker** | 集裝箱（貨櫃） | **包裝與隔離**。將 Spring Boot 應用程式與 JRE 封裝為不可變映像檔，確保各環境運行一致。 |
| **Kubernetes (K8s)** | 物流港口與貨輪 | **調度與編排**。管理 Pod 生命週期、健康檢查、負載平衡並維持指定副本數。 |
| **Helm** | 裝箱清單與安裝手冊 | **套件管理與模板化**。將 K8s YAML 封裝為 Chart 並抽離可變參數（如 `values.yaml` 中的 `tag`），實現參數化一鍵部署。 |

---

## 🏗️ 容器與網路架構

Pod 內部雙容器共享 Localhost 網路空間，並透過內網連線至獨立的 Redis 快取服務：
```text
┌─────────────────────────────────────────────────────────────────────────────┐
│                   【Kubernetes 叢集 (Docker Desktop)】                    │
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