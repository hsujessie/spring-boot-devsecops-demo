# 🐳 Docker 與 Kubernetes (K8s) 架構整合與自動化部署

---

## 🏗️ 專案架構分層說明 (Helm 整合)
1. **[Dockerfile](Dockerfile)**：採用多階段構建，包裝為安全且唯讀的 Docker 映像檔。
2. **`charts/spring-boot-demo/` (Helm Chart)**：
   * **[Chart.yaml](charts/spring-boot-demo/Chart.yaml)**：定義 Chart 的基本描述與版本資訊。
   * **[values.yaml](charts/spring-boot-demo/values.yaml)**：全域變數設定檔，預設映像檔倉庫已設定為 `j9686/spring-boot-demo-app`。
   * **[templates/deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)**：K8s 部署配置，已整合 **Tunnel 側車容器 (Sidecar)**，並注入連線至 Redis Service 的 `REDIS_HOST` 環境變數。
   * **[templates/service.yaml](charts/spring-boot-demo/templates/service.yaml)**：K8s Service 配置，定義 `LoadBalancer` 服務以供本地直接連線。
   * **[templates/redis.yaml](charts/spring-boot-demo/templates/redis.yaml)**：K8s Redis 部署配置，包含獨立的 Redis Deployment 與內部 `ClusterIP` Service，僅限叢集內部連通，防止外網直接存取。

---

## 🤝 Docker、K8s 與 Helm 之間的關係與職責

我們可以使用經典的**「集裝箱貨運物流」**來理解三者的分工與角色：

| 技術 | 實體比喻 | 在本專案中的職責 |
| :--- | :--- | :--- |
| **Docker** | **集裝箱（貨櫃）** | 負責**「包裝與隔離」**。將您的 Spring Boot 程式（`.jar`）與運行環境（JRE）封裝成一個標準化、唯讀的安全貨櫃（Docker 映像檔）。不論在何處運行，行為皆完全一致。 |
| **Kubernetes (K8s)** | **物流港口與貨輪** | 負責**「調度與編排」**。K8s 不製造貨櫃，而是看著說明書決定啟動幾個 Pod（貨櫃實例）、執行健康檢查確保貨櫃沒壞、並建立 Service 網路分流，管理整個港口的貨櫃生命週期。 |
| **Helm** | **裝箱清單與自動安裝手冊** | 負責**「簡化部署與模板化」**。K8s 需要很多 YAML 檔，手動改寫很麻煩。Helm 把這些設定檔包裝成一個 **Chart** 套件，允許我們將變數（如 `values.yaml` 中的 tag）抽出。您只要在指令中帶入參數，Helm 就會自動生成對應的 YAML 並一鍵套用到 K8s 叢集。 |

---

## 🔄 完整閉環：從「代碼提交」到「外部人員連線」的自動化流程

本專案實作了一套兼顧安全（針對公開儲存庫）與高度自動化的部署及外網存取鏈條，具體流程如下：

```text
[ 開發人員 Push 程式 ] 
         │
         ▼
 1. GitHub 雲端沙盒 (ubuntu-latest) 執行 SAST/SCA 安全檢測
         │
         ▼
 2. 雲端沙盒呼叫 Docker 編譯映像檔並 Push 至 Docker Hub 倉庫
         │
         ▼
 3. 雲端沙盒自動修改 `values.yaml` 中的 tag 欄位 (寫入最新 Commit SHA)
         │
         ▼ (Git Push 寫回 GitHub Repo，Commit 標記為 [skip ci])
 4. 本地 Mac 執行 `./local_deploy.sh` 腳本 (一鍵拉取最新 Tag 並利用 Helm 部署)
         │
         ▼
 5. 本地 K8s 自動拉取 Image，部署 Spring Boot 主程式、Redis 資料庫並啟動 Tunnel 側車容器
         │
         ▼ (Tunnel 容器自動連線至 Pinggy 建立隧道)
 6. 腳本自動從 Tunnel 日誌中過濾並輸出外網公開存取網址 (URL)
         │
         ▼
[ 外部人員成功存取網頁 ]
```

### 1. 代碼變更與安全流水線 (GitHub CI)
當您提交程式碼至 GitHub `main` 分支時，GitHub Actions 的雲端伺服器（`ubuntu-latest`）會自動啟動，執行 [security.yml](.github/workflows/security.yml) 安全檢測：
*   **SAST 掃描**：使用 Semgrep 靜態分析代碼是否有漏洞或寫死的密鑰。
*   **SCA 掃描**：使用 Trivy 針對 `pom.xml` 與解包後的二進位 `BOOT-INF/lib/*.jar` 進行依賴套件漏洞掃描。

### 2. 映像檔打包與上傳
當所有安全防線皆確認通過後，工作流會以 Docker 自動打包 Image（標籤為最新的 Commit SHA 與 `latest`），並自動將其推送至 Docker Hub 映像檔儲存庫中。

### 3. GitOps 部署設定自動更新
映像檔上傳完成後，工作流會以 `sed` 指令自動將 `charts/spring-boot-demo/values.yaml` 中的 `tag:` 欄位更新為最新的映像檔 Tag（最新的 Commit SHA），並自動 Git commit / push 回您的公開儲存庫，實現部署設定的版本控制。

### 4. Kubernetes 本地一鍵部署 (Helm)
當您看到 Actions 綠燈通過後，您只需在本地執行 `./local_deploy.sh` 腳本：
*   該腳本會先執行 `git pull` 將最新的代碼與已被 Actions 修改的 `values.yaml` 同步回本機。
*   執行 `helm upgrade --install` 指令，Helm 會自動讀取最新變數，並更新本地 Docker Desktop 的 K8s 叢集。
*   地端 K8s 叢集拉取 Docker Hub 的最新映像檔，並運行 2 個 Pod 副本。

### 5. 側車容器 (Sidecar)、Redis 快取與自動外網穿透
每個 Pod 內部共享同一個網路空間，其中包含兩個容器，且與內部的 Redis 進行連線：
*   **`spring-boot-demo`**：運行您的 Java 應用程式（監聽 `8080` 埠），已整合 `StringRedisTemplate`，啟動時會透過環境變數 `REDIS_HOST` 連線至對應的 K8s 內部 Redis 服務。
*   **`redis` (獨立服務)**：由 `redis.yaml` 啟動，獨立運行於叢集中，透過 `ClusterIP` 提供 `6379` 埠服務，為 Spring Boot 程式提供瀏覽計數快取，不對外網公開以確保資安。
*   **`tunnel` (Sidecar)**：採用 Alpine Git（內置 SSH），啟動時自動透過 443 埠連線至 `free.pinggy.io` 建立反向 SSH 隧道，將流量直接引導至同一個 Pod 內部的 `127.0.0.1:8080`。
*   部署腳本最後會自動抓取 Pod 的 Sidecar 日誌，將 Pinggy 配發的隨機 HTTPS 公開網址（例如 `https://xxxx.free.pinggy.link`）直接輸出於您的終端機上，外部人員即可直接透過此 URL 進行存取驗證！
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