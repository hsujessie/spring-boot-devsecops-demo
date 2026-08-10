# 🛡️ Spring Boot DevSecOps, GitOps & Observability 示範專案

本專案是一個導入業界標準 **DevSecOps** 縱深安全防禦（SAST、雙軌 SCA、容器安全加固）、**GitOps 自動化部署** 與 **Prometheus + Grafana 雲原生可觀測性** 的 Spring Boot 示範專案。專案已相容 **Java 26**、整合 **Redis 極速快取**，並實作 Kubernetes 自動化外網反向穿透。

---

## 📚 專案核心文件導航 (Documentation Hub)

為了方便開發者與維運團隊查閱，專案將深度的技術實作與維運手冊模組化為以下兩份專門指南：

| 指南名稱 | 核心內容與範疇 |
| :--- | :--- |
| **[DOCKER_K8S_GUIDE.md](DOCKER_K8S_GUIDE.md)** | **DevSecOps、Docker 與 Kubernetes 容器架構指南**<br>• Dockerfile 多階段安全加固與 Non-root 權限設定。<br>• K8s Pod 內部 Sidecar Pattern 反向穿透與 Localhost 網路機制。<br>• Helm Chart 變數模板與 GitOps 寫回工作流。 |
| **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** | **Prometheus & Grafana 雲原生可觀測性與資安隔離指南**<br>• 獨立 `monitoring` 命名空間與 `kube-prometheus-stack` 部署。<br>• `ServiceMonitor` 跨空間指標採集規則。<br>• 30+ 官方預載大盤與 JVM `11378` 儀表板清單。<br>• 遙測數據的網路隔離邊界（Network Isolation Boundary）。 |

---

## 📂 專案目錄結構 (Project Structure)

```text
spring-boot-demo/
│
├── .github/workflows/
│   └── security.yml          # GitHub Actions CI/CD 自動化安全掃描與 GitOps 寫回流水線
│
├── charts/spring-boot-demo/  # Kubernetes Helm Chart 部署套件
│   ├── Chart.yaml            # Helm Chart 基本定義說明
│   ├── values.yaml           # 全域部署參數（映像檔倉庫、Tag、Port、副本數等）
│   └── templates/
│       ├── deployment.yaml   # Spring Boot 主程式 Deployment（整合 Pinggy SSH 側車容器）
│       ├── service.yaml      # Spring Boot 外部 Service（LoadBalancer 埠口映射）
│       ├── redis.yaml        # Redis 專屬 Deployment 與內部 Service (ClusterIP 對外隔離)
│       └── servicemonitor.yaml # Prometheus Operator 跨空間指標採集規則
│
├── src/                      # Java 26 原始碼 (整合 Redis 快取與 Actuator 監控)
│   └── main/java/com/example/demo/
│       ├── DemoApplication.java    # Spring Boot 主程式啟動進入點
│       ├── ServletInitializer.java # 外置 Servlet 容器初始化配置
│       └── rest/
│           └── FunRestController.java # REST 控制器（整合 Redis 連線並實作造訪累加計數器）
│
├── Dockerfile                # 容器化定義檔 (Multi-stage Build & Non-root 權限加固)
├── local_deploy.sh           # 地端一鍵自動拉取、Helm 部署與外網網址輸出腳本 (Unix LF)
├── pom.xml                   # Maven 專案設定檔 (宣告依賴套件、Actuator 與 Java 26)
├── DOCKER_K8S_GUIDE.md       # Docker、Kubernetes 與 Helm 的整合部署運作指南
└── MONITORING_GUIDE.md       # Prometheus 與 Grafana 雲原生可觀測性主手冊
```

---

## 🏗️ 全系統運行架構與 GitOps 總覽 (System & GitOps Architecture)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                  🛡️ 全系統架構與 GitOps 自動化部署總覽 (Overview)                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   [開發者] ──(1. Git Push)──► [GitHub Actions 雲端 CI/CD]                    │
│                                           │                                  │
│               ┌───────────────────────────┴───────────────────────────┐      │
│               │ (2. SAST 靜態分析 + 雙軌 SCA 漏洞掃描 + Docker 映像打包)    │      │
│               ▼                                                       ▼      │
│       [Docker Hub 倉庫]                                    [GitOps 自動寫回]  │
│   (儲存最新 Commit Tag 映像檔)                             (更新 values.yaml)│
│               │                                                       │      │
│               └───────────────────────────┬───────────────────────────┘      │
│                                           │                                  │
│                                           ▼ (3. local_deploy.sh / Helm 同步) │
│   ┌────────────────────── Kubernetes 叢集 (Docker Desktop) ──────────────┐   │
│   │                                                                      │   │
│   │  【業務命名空間: default】                【監控命名空間: monitoring】  │   │
│   │   ├── [Spring Boot 應用 (Java 26)]         ├── [Prometheus TSDB 時序庫] │   │
│   │   ├── [Redis 快取 (計數器 6379)]           └── [Grafana 平台 (Port 3000)]│  │
│   │   └── [Tunnel 側車 (SSH 反向隧道)]                                    │   │
│   │                 │                                                    │   │
│   └─────────────────┼────────────────────────────────────────────────────┘   │
│                     │ (4. 自動外網安全穿透)                                   │
│                     ▼                                                        │
│              [Pinggy 公開網址] ◄─── (瀏覽器存取驗證) ─── [外部用戶]            │
│                                                                              │
└──────────────────────────────────────────────────────────────────────────────┘
```

---

## 📂 專案模組與檔案角色劃分

### 1. 📂 核心原始碼與設定 (`src/` 目錄)
*   **Java 程式碼管理**
    *   [DemoApplication.java](src/main/java/com/example/demo/DemoApplication.java)：Spring Boot 應用程式的啟動進入點。
    *   [ServletInitializer.java](src/main/java/com/example/demo/ServletInitializer.java)：外置 Servlet 容器初始化類別。
    *   [FunRestController.java](src/main/java/com/example/demo/rest/FunRestController.java)：Web REST API 控制器，整合 Redis 快取並實作造訪累加計數器。
*   **資源配置檔**
    *   [application.properties](src/main/resources/application.properties)：配置 Redis 連線主機與 Port，並開放 `/actuator/prometheus` 監控端點。

---

### 2. 🛡️ DevSecOps 與 CI/CD 流水線 (`.github/workflows/`)
*   **[.github/workflows/security.yml](.github/workflows/security.yml)**：
    *   **SAST 靜態程式碼分析**：使用 Semgrep 掃描原始碼中的邏輯漏洞與 Hardcoded Secrets。
    *   **Fast SCA 快速分析**：使用 Trivy 掃描 `pom.xml` 的已知 CVE 漏洞。
    *   **Deep SCA 二進位審計**：解包編譯後的 JAR 檔，以 `rootfs` 模式深層掃描實體套件 `BOOT-INF/lib/*.jar`。
    *   **Container 容器映像檔掃描**：以 Trivy 掃描 OS 基礎層漏洞。
    *   **Docker Hub 推送**：自動發布帶有 Commit SHA 與 `latest` 標籤的映像檔。
    *   **GitOps 自動寫回**：自動將最新 Commit SHA 更新至 Helm `values.yaml` 並推回儲存庫。

---

### 3. ☸️ 容器化與 Kubernetes Helm Chart
*   **[Dockerfile](Dockerfile)**：
    *   **多階段建置 (Multi-stage Build)**：分開編譯環境與運行環境。
    *   **最小化運行環境**：採用 JRE Alpine 輕量基底，以非 root 用戶（`appuser`）執行 Java，降低受攻擊面。
*   **[charts/spring-boot-demo/](charts/spring-boot-demo/)**：
    *   [deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)：宣告 Spring Boot 主應用與 Pinggy SSH 反向隧道側車容器。
    *   [service.yaml](charts/spring-boot-demo/templates/service.yaml)：定義 `LoadBalancer` 服務映射 `8080` 埠。
    *   [redis.yaml](charts/spring-boot-demo/templates/redis.yaml)：宣告獨立運行的 Redis 資料庫與 `ClusterIP` 內部服務。
    *   [servicemonitor.yaml](charts/spring-boot-demo/templates/servicemonitor.yaml)：定義 Prometheus Operator 的 `ServiceMonitor` 跨空間指標抓取規則。

---

## 📊 雙軌 SCA 掃描對比表

| 比較維度 | 掃描 `pom.xml` (原始碼宣告檔) | 掃描 `BOOT-INF/lib/*.jar` (編譯產物二進位檔) |
| :--- | :--- | :--- |
| **資安定位** | 開發移左防線 (Shift-Left) | 最終交付物檢測 (Deliverable / Binary Audit) |
| **掃描機制** | **文字解析**：讀取 XML 結構中宣告的 `<groupId>` 與 `<artifactId>`。 | **指紋比對 (Hash Matching)**：計算每一個實體 `.jar` 的 SHA-1 雜湊值，比對全球 CVE 資料庫。 |
| **防禦價值** | 快速攔截，在 PR 階段第一時間防堵已知不安全元件。 | 防堵間接相依性 (Transient Dependency) 與編譯期遭竄改的依賴包。 |

---

## 🚀 地端一鍵部署與驗證

本專案將複雜的 K8s 同步與部署完全封裝在 `./local_deploy.sh` 腳本中，讓本地測試如同呼吸般自然：

### 1. 前置準備
* 確保本地已啟動 **Docker Desktop**，且已打勾開啟 **Kubernetes** 叢集。
* 在終端機進入專案根目錄，切換 Java 環境：
  ```bash
  sdk use java 26.0.2-oracle
  ```

### 2. 執行一鍵部署
```bash
./local_deploy.sh
```

### 3. 腳本自動運作流程：
1. 執行 `git pull` 從 GitHub 同步最新被 GitOps 寫回的映像檔標籤（Values.yaml）。
2. 執行 `helm upgrade --install` 發布/更新本地部署至 K8s 叢集。
3. 以 `kubectl rollout status` 暫停並同步等待 K8s 滾動更新順利完成。
4. 自動抓取 Pod 的 Sidecar 日誌，在螢幕上輸出 Pinggy 產生的 **HTTPS 外網公開網址**。
5. 輸出 Grafana 儀表板存取網址（`http://localhost:3000`），帳號/密碼為 `admin` / `admin`。
