# 🛡️ Spring Boot DevSecOps, GitOps & Observability 專案

本專案是一個導入業界標準 **DevSecOps** 安全防護機制（SAST、雙軌 SCA、容器安全加固）、**GitOps 自動化部署** 與 **Prometheus + Grafana 雲原生可觀測性** 的 Spring Boot 示範專案。專案已整合 **Java 26、Redis 快取**，以及 K8s 自動化外網穿透測試。

---

## 📚 專案核心文件導航 (Documentation Hub)

為了方便開發者與維運團隊查閱，本專案將完整架構與操作手冊模組化為以下 4 份核心文件：

| 文件名稱 | 說明與主要內容 |
| :--- | :--- |
| **[README.md](README.md)** | **專案總覽入口**：專案簡介、目錄結構、雙軌 SCA 防護對比表與快速一鍵部署。 |
| **[ARCHITECTURE.md](ARCHITECTURE.md)** | **系統架構說明書**：全系統運行架構圖、模組職責劃分與 DevSecOps 流水線設計。 |
| **[DOCKER_K8S_GUIDE.md](DOCKER_K8S_GUIDE.md)** | **容器化與 K8s 部署指南**：Dockerfile 安全加固、K8s 資源宣告、Helm Chart 與 Sidecar 穿透。 |
| **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)** | **可觀測性與監控指南**：Prometheus、Grafana、ServiceMonitor、30+ 官方大盤與網路隔離邊界。 |

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
├── src/                      # Java 26 原始碼 (整合 Redis 快取與 Actuator 監控)
│   └── main/java/com/example/demo/rest/FunRestController.java
│
├── Dockerfile                # 容器化定義檔 (Multi-stage Build & Non-root 權限加固)
├── local_deploy.sh           # 地端一鍵拉取、自動部署與外網網址輸出腳本 (Unix LF)
├── pom.xml                   # Maven 專案設定檔 (宣告依賴套件與 Java 26)
├── ARCHITECTURE.md           # 詳細系統元件架構設計說明書
├── DOCKER_K8S_GUIDE.md       # Docker、Kubernetes 與 Helm 的整合部署運作指南
└── MONITORING_GUIDE.md       # Prometheus 與 Grafana 雲原生可觀測性監控指南
```

---

## 🏗️ 全系統運行架構與 GitOps 總覽 (System & GitOps Architecture)

```text
┌──────────────────────────────────────────────────────────────────────────────┐
│                  🛡️ 全系統架構與 GitOps 自動化部署總覽 (Overview)                 │
├──────────────────────────────────────────────────────────────────────────────┤
│                                                                              │
│   [開發者 (您)] ──(1. Git Push)──► [GitHub Actions 雲端 CI/CD]                 │
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

## 🛡️ CI/CD DevSecOps 安全檢測防線

工作流設定於 [.github/workflows/security.yml](.github/workflows/security.yml)，當代碼推送至 `main` 或 `develop` 時，會觸發以下安全防禦措施：

1.  **SAST (靜態應用程式安全測試)**：使用 **Semgrep** 靜態掃描 Java 原始碼，及早發現邏輯漏洞、OWASP Top 10 風險與寫死的機密資訊（Hardcoded Secrets）。
2.  **雙軌 SCA (軟體組成分析)**：比對第三方套件的已知 CVE 漏洞。
    *   **（Fast SCA）**：透過 **Trivy** 直接掃描 `pom.xml`，以最快速度提供依賴宣告分析。
    *   **（Deep SCA）**：執行 Maven 打包成 `.jar`，解鎖並深入 `BOOT-INF/lib/*.jar` 的二進位實體包，防止間接相依性產生的漏網之魚。
3.  **容器安全與映像檔防護**：
    *   採用 **Dockerfile 多階段建置**，運行環境使用 Alpine Minimal JRE，並建立 `appuser` 非 root 帳戶，防止容器逃逸。
    *   以 **Trivy Container Scan** 掃描作業系統層級漏洞。
4.  **GitOps 自動寫回**：
    *   映像檔安全發布至 Docker Hub 後，CI/CD 會自動以最新 Commit SHA 更新 `charts/spring-boot-demo/values.yaml` 中的映像檔 Tag，並自動合併（Pull Rebase）後推回 GitHub 倉庫。

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