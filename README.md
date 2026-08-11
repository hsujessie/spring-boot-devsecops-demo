# ☕️ Spring Boot DevSecOps & Observability 專案架構說明

## 📝 簡介 (Introduction)
本專案是一個導入 **DevSecOps** 縱深安全防禦（包含 SAST、雙軌 SCA、容器安全加固、GitOps 自動更新）與 **雲原生可觀測性監控體系（Prometheus + Grafana）** 的 Spring Boot 專案。

---

## 📂 專案目錄結構 (Project Structure)

```text
spring-boot-demo/
│
├── .github/
│   └── workflows/
│       └── security.yml      # GitHub Actions CI/CD 自動化安全與 GitOps 流水線
│
├── charts/spring-boot-demo/  # Kubernetes Helm Chart 部署套件
│   ├── Chart.yaml            # Helm Chart 基本定義說明
│   ├── values.yaml           # 全域部署參數（映像檔倉庫、Tag、Port、複製數等）
│   └── templates/
│       ├── deployment.yaml   # Spring Boot 主程式 Deployment（整合 Tunnel 側車容器）
│       ├── service.yaml      # Spring Boot 外部 Service（LoadBalancer 埠口映射）
│       ├── redis.yaml        # Redis 專屬 Deployment 與內部 Service (ClusterIP 對外隔離)
│       └── servicemonitor.yaml # Prometheus Operator 跨空間指標採集規則
│
├── src/                      # Java 26 原始碼與設定
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── DemoApplication.java        # Spring Boot 應用程式入口
│   │   │   ├── ServletInitializer.java     # 外置 Servlet 容器初始化類別
│   │   │   └── rest/
│   │   │       └── FunRestController.java  # REST Controller (整合 Redis 計數器)
│   │   └── resources/
│   │       └── application.properties      # 應用程式配置 (Redis 與 Actuator 端點)
│   └── test/                 # 測試案例目錄
│
├── Dockerfile                # 容器化定義檔 (Multi-stage Build & Non-root 權限加固)
├── local_deploy.sh           # 地端一鍵拉取、自動部署與外網網址輸出腳本 (Unix LF)
├── pom.xml                   # Maven 專案設定檔 (宣告依賴套件與 Java 26)
├── DOCKER_K8S_GUIDE.md       # Docker、K8s 與 Helm 容器化部署架構
└── MONITORING_GUIDE.md       # Prometheus 與 Grafana 監控指南
```

---

## 🏗️ 全系統運行架構與 GitOps 總覽 (System & GitOps Architecture)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                  🛡️ 全系統架構與 GitOps 自動化部署總覽 (Overview)                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   [開發者] ──(1. Git Push)──► [GitHub Actions CI/CD 流水線]                    │
│                                           │                                  │
│               ┌───────────────────────────┴───────────────────────────┐      │
│               │ (2. SAST 靜態分析 + 雙軌 SCA 漏洞掃描 + Docker 映像打包)  │      │
│               ▼                                                       ▼      │
│       [Docker Hub 倉庫]                                    [GitOps 自動寫回]  │
│   (儲存最新 Commit Tag 映像檔)                             (更新 values.yaml)  │
│               │                                                       │      │
│               └───────────────────────────┬───────────────────────────┘      │
│                                           │                                  │
│                                           ▼ (3. local_deploy.sh / Helm 同步) │
│   ┌────────────────────── Kubernetes 叢集 (Docker Desktop) ──────────────┐   │
│   │                                                                      │   │
│   │  【應用程式命名空間: default】              【監控命名空間: monitoring】   │   │
│   │   ├── [Spring Boot 應用 (Java 26)]        ├── [Prometheus TSDB 時序庫] │   │
│   │   ├── [Redis 快取 (計數器 6379)]           └── [Grafana 平台 (Port 3000)]│  │
│   │   └── [Tunnel 側車 (SSH 反向隧道)]                                     │   │
│   │                 │                                                    │   │
│   └─────────────────┼────────────────────────────────────────────────────┘   │
│                     │ (4. 自動外網安全穿透)                                    │
│                     ▼                                                        │
│              [Pinggy 公開網址] ◄─── (瀏覽器存取驗證) ─── [外部用戶]              │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 🔄 從代碼提交到外網存取的自動化流程 (End-to-End Workflow)

```text
[ 開發人員 Push 程式 ] 
         │
         ▼
 1. GitHub Actions (ubuntu-latest) 執行 SAST/SCA 安全檢測
         │
         ▼
 2. GitHub Actions 呼叫 Docker 編譯映像檔並 Push 至 Docker Hub 倉庫
         │
         ▼
 3. GitHub Actions 自動修改 `values.yaml` 中的 tag 欄位 (寫入最新 Commit SHA)
         │
         ▼ (GitOps 自動寫回 GitHub Repo，Commit 標記為 [skip ci])
 4. 本地執行 `./local_deploy.sh` 腳本 (一鍵拉取最新 Tag 並利用 Helm 部署)
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

---

## 📂 專案模組與端點說明 (Modules & Endpoints)

### 1. ⚙️ 核心原始碼與設定
*   **Java 程式碼管理**
    *   [DemoApplication.java](src/main/java/com/example/demo/DemoApplication.java)：Spring Boot 應用程式的啟動進入點。
    *   [ServletInitializer.java](src/main/java/com/example/demo/ServletInitializer.java)：外置 Servlet 容器初始化類別。
    *   [FunRestController.java](src/main/java/com/example/demo/rest/FunRestController.java)：Web REST API 控制器，整合 Redis 快取並實作造訪累加計數器。
*   **資源配置檔**
    *   [application.properties](src/main/resources/application.properties)：配置 Redis 連線主機與 Port，並開放 `/actuator/prometheus` 監控端點。

### 2. 🛡️ DevSecOps 與 CI/CD 流水線
*   **[.github/workflows/security.yml](.github/workflows/security.yml)**：
    *   **SAST 靜態程式碼分析**：使用 Semgrep 掃描原始碼中的邏輯漏洞與 Hardcoded Secrets。
    *   **Fast SCA 快速分析**：使用 Trivy 掃描 `pom.xml` 的已知 CVE 漏洞。
    *   **Deep SCA 二進位審計**：解包編譯後的 JAR 檔，以 `rootfs` 模式深層掃描實體套件 `BOOT-INF/lib/*.jar`。
    *   **Container 容器映像檔掃描**：以 Trivy 掃描 OS 基礎層漏洞。
    *   **Docker Hub 推送**：自動發布帶有 Commit SHA 與 `latest` 標籤的映像檔。
    *   **GitOps 自動寫回**：自動將最新 Commit SHA 更新至 Helm `values.yaml` 並推回儲存庫。

### 3. ☸️ 容器化與 Kubernetes Helm Chart
*   **[Dockerfile](Dockerfile)**：
    *   **多階段建置 (Multi-stage Build)**：分開編譯環境與運行環境。
    *   **最小化運行環境**：採用 JRE Alpine 輕量基底，以非 root 用戶（`appuser`）執行 Java，降低受攻擊面。
*   **[charts/spring-boot-demo/](charts/spring-boot-demo/)**：
    *   [deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)：宣告 Spring Boot 主應用與 Pinggy SSH 反向隧道側車容器。
    *   [service.yaml](charts/spring-boot-demo/templates/service.yaml)：定義 `LoadBalancer` 服務映射 `8080` 埠。
    *   [redis.yaml](charts/spring-boot-demo/templates/redis.yaml)：宣告獨立運行的 Redis 資料庫與 `ClusterIP` 內部服務。
    *   [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml)：定義 Prometheus Operator 的 `ServiceMonitor` 跨空間指標抓取規則。

### 4. 🌐 核心端點與驗證路由 (Endpoints)
| 端點路徑 (Path) | HTTP 方法 | 功能說明 | 備註 |
| :--- | :--- | :--- | :--- |
| `/` | `GET` | 首頁，自動累加 Redis `page_views` 計數並回傳累計次數 | 驗證 Redis 快取連線與業務邏輯 |
| `/actuator/health` | `GET` | 應用程式健康狀態檢查 (`UP` / `DOWN`) | 供 Kubernetes Liveness/Readiness 探針使用 |
| `/actuator/prometheus` | `GET` | Prometheus 格式的度量指標數據 | 供 Prometheus Operator 抓取並於 Grafana 呈現 |
| `/actuator/info` | `GET` | 應用程式基礎資訊 | Actuator 內建端點 |

---

## 🚀 本地端部署與驗證 (Local Deployment)
### 1. 前置準備
*   確保本地已啟動 **Docker Desktop**，且已打勾開啟 **Kubernetes** 叢集。
*   在終端機進入專案根目錄，切換 Java 環境：
    ```bash
    sdk use java 26.0.2-oracle
    ```

### 2. 執行一鍵部署
```bash
./local_deploy.sh
```

### 3. 腳本自動運作流程：
1.  執行 `git pull` 從 GitHub 同步最新被 GitOps 寫回的映像檔標籤（Values.yaml）。
2.  執行 `helm upgrade --install` 發布/更新本地部署至 K8s 叢集。
3.  以 `kubectl rollout status` 暫停並同步等待 K8s 滾動更新順利完成。
4.  自動抓取 Pod 的 Sidecar 日誌，在螢幕上輸出 Pinggy 產生的 **HTTPS 外網公開網址**。
5.  輸出 Grafana 儀表板存取網址（`http://localhost:3000`），帳號/密碼為 `admin` / `admin`。

---

## 🛡️ 安全性分析 (Security Analysis)
### 1. SAST (靜態程式碼分析)
*   **工具**：Semgrep
*   **掃描目標**：檢查原始碼中的邏輯漏洞、錯誤配置和硬編碼敏感資訊。
*   **位置**：`.github/workflows/security.yml` -> `semgrep-scan`

### 2. SCA (軟體成分分析) - 雙軌制
*   **快速掃描 (Fast SCA)**：
    *   **工具**：Trivy (pom.xml)
    *   **目的**：快速掃描 `pom.xml` 檔案中的已知 CVE 漏洞。
    *   **位置**：`.github/workflows/security.yml` -> `trivy-scan-fast`
*   **深度掃描 (Deep SCA)**：
    *   **工具**：Trivy (Rootfs mode)
    *   **目的**：解壓縮 JAR 檔，對 `BOOT-INF/lib/*.jar` 中的依賴套件進行深度漏洞掃描。
    *   **位置**：`.github/workflows/security.yml` -> `trivy-scan-deep`

### 3. 容器安全加固 (Container Security)
*   **Dockerfile 最佳實踐**：
    *   **多階段建置 (Multi-stage Build)**：有效減少最終映像檔大小。
    *   **非 Root 權限**：以 `appuser` 執行 Java 應用，降低容器內部的攻擊風險。
    *   **最小化 Base Image**：使用 `eclipse-temurin:26-jre-alpine`，大幅減少潛在漏洞的攻擊面。
