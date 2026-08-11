# ☕️ Spring Boot DevSecOps & Observability

* ☕ **應用架構**：Java 26 + Spring Boot + Redis 快取計數器。
* 🛡️ **DevSecOps**：Semgrep SAST 靜態掃描、Trivy 雙軌 SCA 依賴審計與容器加固。
* 🔄 **GitOps CI/CD**：GitHub Actions 自動構建與 Helm `values.yaml` 自動版本寫回。
* 📊 **可觀測性**：Prometheus 指標採集與 Grafana 視覺化監控。

---

## 📂 專案目錄結構

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
│       ├── deployment.yaml   # Spring Boot 應用程式 Deployment（整合 Tunnel 側車容器）
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

## 🏗️ 系統架構與 GitOps

```text
┌──────────────────────────────────────────────────────────────────────────────┐
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

## 📦 專案模組與端點

### 1. ⚙️ 核心原始碼
* **[FunRestController.java](src/main/java/com/example/demo/rest/FunRestController.java)**：首頁 REST API，整合 Redis 快取實作瀏覽計數器。
* **[DemoApplication.java](src/main/java/com/example/demo/DemoApplication.java)** / **[ServletInitializer.java](src/main/java/com/example/demo/ServletInitializer.java)**：Spring Boot 啟動進入點與外置 Servlet 初始化。
* **[application.properties](src/main/resources/application.properties)**：Redis 連線配置與 `/actuator/prometheus` 監控端點開放。

### 2. 🛡️ DevSecOps 與 CI/CD
* **[security.yml](.github/workflows/security.yml)**：整合 **Semgrep SAST**、**Trivy 雙軌 SCA**（原始碼 + JAR 實體二進位深層審計）、**容器映像安全掃描**、Docker Hub 自動發布與 **GitOps 映像 Tag 自動寫回**。

### 3. ☸️ Docker 與 Helm 配置
* **[Dockerfile](Dockerfile)**：多階段建置、非 root 權限加固（專屬 `appuser` UID `1000`）與最小化 Temurin 26 Alpine 映像檔。
* **[Helm Templates](charts/spring-boot-demo/templates/)**：宣告 Spring Boot 與 Tunnel 雙容器 Pod、獨立 Redis 快取與 Prometheus ServiceMonitor。

### 4. 🌐 核心端點
| 端點路徑 | HTTP 方法 | 功能說明 | 備註 |
| :--- | :--- | :--- | :--- |
| `/` | `GET` | 首頁，自動累加 Redis 瀏覽計數並回傳次數 | 業務邏輯與快取連線驗證 |
| `/actuator/health` | `GET` | 應用程式健康狀態檢查 (`UP` / `DOWN`) | K8s Liveness/Readiness 探針 |
| `/actuator/prometheus` | `GET` | Prometheus 格式度量指標數據 | Prometheus 抓取與 Grafana 呈現 |
| `/actuator/info` | `GET` | 應用程式基礎資訊 | Actuator 內建端點 |

---

## 🚀 快速開始
* 確認本機已啟動 **Docker Desktop**（並啟用 Kubernetes 叢集）。
* 於專案根目錄切換 Java 環境並執行部署：
  ```bash
  sdk use java 26.0.2-oracle
  ./local_deploy.sh
  ```

<table>
  <thead>
    <tr>
      <th colspan="3" align="center">🚀 <code>local_deploy.sh</code> 腳本部署流程</th>
    </tr>
    <tr>
      <th align="left">階段</th>
      <th align="left">指令 / 機制</th>
      <th align="left">說明</th>
    </tr>
  </thead>
  <tbody>
    <tr>
      <td><b>1. 同步映像標籤</b></td>
      <td><code>git pull</code></td>
      <td>拉取 GitOps 自動寫回的最新 <code>values.yaml</code>。</td>
    </tr>
    <tr>
      <td><b>2. 發布 Helm Chart</b></td>
      <td><code>helm upgrade --install</code></td>
      <td>發布或更新本地 K8s 叢集部署。</td>
    </tr>
    <tr>
      <td><b>3. 等待滾動就緒</b></td>
      <td><code>kubectl rollout status</code></td>
      <td>同步等待所有 Pod 健康檢查通過。</td>
    </tr>
    <tr>
      <td><b>4. 輸出外網網址</b></td>
      <td>讀取 Sidecar 日誌</td>
      <td>取得 Pinggy 產生的 HTTPS 外網公開存取網址。</td>
    </tr>
    <tr>
      <td><b>5. 提示監控平台</b></td>
      <td>輸出 Grafana 連線</td>
      <td>提供儀表板網址 (<code>localhost:3000</code>) 與帳密 (<code>admin</code>/<code>admin</code>)。</td>
    </tr>
  </tbody>
</table>
