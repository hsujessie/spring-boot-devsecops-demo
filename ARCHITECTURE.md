# 📂 Spring Boot DevSecOps & Observability 專案架構說明

本專案是一個導入 **DevSecOps** 縱深安全防禦（包含 SAST、雙軌 SCA、容器安全加固、GitOps 自動更新）與 **雲原生可觀測性監控體系（Prometheus + Grafana）** 的 Spring Boot 專案。

---

## 🏗️ 系統運行整體架構

```text
┌──────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────────┐
│                                                                                  │
│  【業務區：default 命名空間】                                                      │
│   ├── [Spring Boot Pod] (Java 26 / Actuator) ──(Redis 快取)──► [Redis Pod] (6379) │
│   │         ▲                                                                    │
│   │         └── [Tunnel 側車容器 (SSH)] ──► [Pinggy HTTPS 外網網址] ──► [外部用戶] │
│   │                                                                              │
│   └── [ServiceMonitor] (宣告式服務發現與跨空間指標採集規則 CRD)                    │
│                                                                                  │
│                                 ▲ (跨 Namespace 宣告式指標採集)                  │
│                                 │                                                │
│  【維運監控專區：monitoring 命名空間】 (使用官方 kube-prometheus-stack Helm Chart)  │
│   ├── [Prometheus Operator 監控大腦] (時序資料庫 TSDB)                            │
│   ├── [Node Exporter] (監控主機 CPU/硬碟/網路)                                     │
│   ├── [Kube-State-Metrics] (監控 K8s Pod 狀態/重啟次數)                            │
│   └── [Grafana 企業級視覺化平台] ──► 開放 localhost:3000 (內建數十個官方大盤)      │
│                                                                                  │
└──────────────────────────────────────────────────────────────────────────────────┘
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

### 4. 📝 說明文件與指南清單 (Documentation)
*   **[README.md](README.md)**：專案首頁、快速開始、一鍵部署與雙軌 SCA 比較表。
*   **[ARCHITECTURE.md](ARCHITECTURE.md)**：本文件，全系統架構與模組職責說明書。
*   **[DOCKER_K8S_GUIDE.md](DOCKER_K8S_GUIDE.md)**：Docker、Kubernetes 與 Helm 的整合部署運行詳細指南。
*   **[MONITORING_GUIDE.md](MONITORING_GUIDE.md)**：Prometheus、Grafana、Actuator、Micrometer 與 30+ 官方大盤全方位指南。
