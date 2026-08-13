# ☕️ Spring Boot DevSecOps & Observability

* ☕ **應用架構**：Java 26 + Spring Boot + Redis 快取計數器。
* 🛡️ **DevSecOps**：Semgrep SAST 靜態掃描、Trivy 雙軌 SCA 依賴套件掃描與容器加固。
* 🔄 **GitOps CI/CD**：GitHub Actions 自動建置與 Helm `values.yaml` 自動版本寫回。
* 📊 **可觀測性**：Prometheus 指標採集與 Grafana 視覺化監控。

---

## 📂 專案目錄結構

```text
spring-boot-demo/
│
├── .github/
│   └── workflows/
│       └── security.yml        # GitHub Actions CI/CD & GitOps
│
├── charts/spring-boot-demo/
│   ├── Chart.yaml              # Helm Chart 定義檔
│   ├── values.yaml             # 全域部署參數檔（映像檔倉庫、標籤 Tag 與副本數）
│   └── templates/
│       ├── deployment.yaml     # Spring Boot 主程式與 Tunnel 側車容器 (SSH 反向隧道) 部署
│       ├── service.yaml        # 外部存取服務（LoadBalancer 映射 8080）
│       ├── redis.yaml          # Redis 快取部署與內部服務（ClusterIP 外網隔離）
│       └── servicemonitor.yaml # CRD 跨命名空間指標採集規則
│
├── src/
│   ├── main/
│   │   ├── java/com/example/demo/
│   │   │   ├── DemoApplication.java        # Spring Boot 主程式進入點
│   │   │   ├── ServletInitializer.java     # Servlet 容器初始化類別
│   │   │   └── rest/
│   │   │       └── FunRestController.java  # 首頁 REST API（整合 Redis 計數器）
│   │   └── resources/
│   │       └── application.properties      # 應用配置（Redis 連線與 Actuator 監控端點）
│   └── test/ 
│
├── Dockerfile                # 容器化定義檔（多階段建置 & 非 root 權限加固）
├── local_deploy.sh           # 本地一鍵同步、部署與外網網址輸出腳本
├── pom.xml                   # Maven 專案設定檔（宣告依賴套件與 Java 26）
├── DOCKER_K8S_GUIDE.md       # Docker、K8s 與 Helm 容器化部署架構
└── MONITORING_GUIDE.md       # Prometheus 與 Grafana 監控指南
```

---

## 🏗️ 系統架構與 GitOps

```text
┌────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                        │
│     [開發者] ──(1. Git Push)──► [GitHub Actions CI/CD]                                  │
│                                           │                                            │
│              ┌────────────────────────────┴────────────────────────────┐               │
│              │ (2. SAST 靜態分析 + 雙軌 SCA 依賴套件掃描 + 映像檔建置)      │               │
│              └────────┬───────────────────────────────────────┬────────┘               │
│                       ▼                                       ▼                        │
│               [Docker Hub 倉庫]                       [GitOps 自動寫回]                  │
│               (儲存最新映像檔)                        (更新 values.yaml)                  │
│                       │                                       │                        │
│                       └───────────────────┬───────────────────┘                        │
│                                           │                                            │
│                                           ▼ (3. local_deploy.sh / Helm 同步)           │
│   ┌───────────────────────── Kubernetes 叢集 (Docker Desktop) ────────────────────┐    │
│   │                                                                               │   │
│   │ 【應用程式命名空間: default】           【監控命名空間: monitoring】               │   │
│   │  ├── [Spring Boot] (主程式)             ├── [Prometheus] (TSDB 時序庫)          │   │
│   │  ├── [Redis] (快取資料庫)               ├── [Node Exporter] (主機硬體指標)       │   │
│   │  ├── [Tunnel] (SSH 反向隧道)            ├── [Kube-State-Metrics] (Pod 狀態指標) │   │
│   │  └── [ServiceMonitor] (CRD 採集規則)    └── [Grafana] (視覺化平台)               │   │
│   │                │                                                               │   │
│   └────────────────┼───────────────────────────────────────────────────────────────┘   │
│                    │ (4. SSH 反向隧道安全穿透)                                           │
│                    ▼                                                                   │
│           [Pinggy 公開 HTTPS 網址] ◄─── (瀏覽器存取驗證) ─── [外部用戶]                    │
│                                                                                        │
└────────────────────────────────────────────────────────────────────────────────────────┘
```

---

## 🌐 核心端點
| 端點路徑 | HTTP 方法 | 功能說明 | 備註 |
| :--- | :--- | :--- | :--- |
| `/` | `GET` | 首頁，累加 Redis 造訪計數並回傳結果 | 業務邏輯與快取連線驗證 |
| `/actuator/health` | `GET` | 應用程式健康狀態檢查 (`UP` / `DOWN`) | K8s Liveness/Readiness 探針 |
| `/actuator/prometheus` | `GET` | Prometheus 格式度量指標數據 | Prometheus 採集與 Grafana 呈現 |
| `/actuator/info` | `GET` | 應用程式基礎資訊 | Actuator 內建端點 |

---

## 🚀 快速開始

### 1. 前置準備
* 確認本地已啟動 **Docker Desktop**（並啟用 Kubernetes 叢集）。

<div id="init-monitoring"></div>

### 2. 初始化監控平台
* 僅在全新搭建環境或重置 K8s 叢集時，**執行 1 次**。（日常程式碼發布只需執行 `./local_deploy.sh`）<br>詳細說明可參閱 [MONITORING_GUIDE.md - 監控平台部署](MONITORING_GUIDE.md#helm-deploy)
```bash
# 新增並更新 Helm 監控倉庫
helm repo add prometheus-community https://prometheus-community.github.io/helm-charts
helm repo update

# 建立命名空間
kubectl create namespace monitoring || true

# 安裝/升級 kube-prometheus-stack 套件（自動啟用 ServiceMonitor 跨命名空間採集）
helm upgrade --install prometheus-stack prometheus-community/kube-prometheus-stack \
  --namespace monitoring \
  --set grafana.service.type=LoadBalancer \
  --set grafana.service.port=3000 \
  --set prometheus.prometheusSpec.serviceMonitorSelectorNilUsesHelmValues=false \
  --set grafana.adminPassword=admin
```

### 3. 應用程式部署與運行
* 於專案根目錄切換 Java 環境並執行一鍵部署腳本：
```bash
sdk use java 26.0.2-oracle
./local_deploy.sh
```

| 執行階段<br>(<code>local_deploy.sh</code>) | 指令 / 機制 | 說明 |
| :--- | :--- | :--- |
| 1. **同步映像標籤** | `git pull` | 拉取 GitOps 自動寫回的最新 `values.yaml`。 |
| 2. **發布 Helm Chart** | `helm upgrade --install` | 發布或更新本地 K8s 叢集部署。 |
| 3. **等待滾動就緒** | `kubectl rollout status` | 同步等待所有 Pod 健康檢查通過。 |
| 4. **輸出外網網址** | 讀取側車容器 Sidecar 日誌 | 取得 Pinggy 產生的公開 HTTPS 網址。 |
| 5. **提示監控平台** | 輸出 Grafana 網址 | 提供監控視覺化平台網址 (`localhost:3000`) 與帳密 (`admin`/`admin`)。 |
