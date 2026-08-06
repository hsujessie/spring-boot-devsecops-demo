# 🐳 Docker 與 Kubernetes (K8s) 架構整合說明指南

本指南詳細說明本專案的系統架構分層、**Docker 與 Kubernetes (K8s) 之間的關係與職責**，以及從「代碼提交」到「外部人員成功連線」的完整自動化運作流程。

---

## 📂 一、 專案架構分層說明

本專案是一個整合了安全掃描、容器封裝與叢集編排的 DevSecOps 應用專案，架構主要分為以下四層：

1. **程式碼與建置層**：
   * **Java 原始碼 ([src/](src))**：提供 Web REST API 服務的核心商務邏輯。
   * **專案依賴與建置設定 ([pom.xml](pom.xml))**：定義 Maven 套件依賴（如 Spring Boot Web 模組）與編譯設定（使用 JDK 26）。
2. **自動化流水線層 (CI/CD)**：
   * **GitHub Actions 工作流 ([security.yml](.github/workflows/security.yml))**：自動執行 SAST 代碼掃描、SCA 套件安全性漏洞掃描、二進位 `.jar` 檔解包掃描、構建映像檔，並自動將新影像標籤寫回 K8s 部署設定。
3. **容器與運行層**：
   * **[Dockerfile](Dockerfile)**：採用多階段構建（Multi-stage Build），在編譯安全通過後將應用程式與 JRE 運行環境封裝成一個唯讀、非 root 執行的安全 Docker 映像檔。
4. **叢集編排與部署層**：
   * **[deployment.yaml](deployment.yaml)**：設定 K8s Pod 副本數（`replicas: 2`）、健康檢查探針、以及容器資源上限；並宣告 `LoadBalancer` 服務將 K8s 內部的 `8080` 埠映射到主機的 `8080` 埠。

---

## 🤝 二、 Docker 與 Kubernetes (K8s) 之間的關係

我們可以使用經典的**「集裝箱貨運物流」**來比喻兩者的分工：

| 角色 | 實體比喻 | 在本專案中的職責 |
| :--- | :--- | :--- |
| **Docker** | **集裝箱（貨櫃）** | 負責**「包裝與隔離」**。將編譯後的 Spring Boot 程式、Java 執行環境（JRE）與啟動指令打包成一個獨立的貨櫃（Docker 映像檔）。只要包裝完成，該貨櫃便可在任何支援 Docker 的環境下以完全相同的方式運行。 |
| **Kubernetes (K8s)** | **物流港口管理系統 / 貨輪** | 負責**「調度、網路與編排」**。K8s 不製造貨櫃，而是負責管理大量貨櫃。它會根據 [deployment.yaml](deployment.yaml) 進行港口排程：<br>1. 啟動並維持指定數量的貨櫃運行（2 個 Pod 副本）。<br>2. 監控貨櫃狀態，當貨櫃損毀時自動替換（自我修復）。<br>3. 建立連外道路並管理流量分配（Service 負載平衡器）。 |

* **關係總結**：Docker 負責**容器化**（把應用做成貨櫃）；Kubernetes 負責**編排**（調度與管理這些貨櫃的運行、網路與可用性）。

---

## 🔄 三、 完整閉環：從「代碼提交」到「外部人員連線」

本專案實作了一套完整的自動化與外網存取鏈條，具體運作流程如下：

```text
[ 開發人員 Push 程式 ] 
         │
         ▼
 1. GitHub Actions (CI) 執行安全檢測 ──► 2. 使用 Docker 編譯並封裝 Image
                                                             │
                                                             ▼
 4. 自動修改 deployment.yaml 寫回 ◄── 3. 將 Image 推送至 Docker Hub 倉庫
    (將影像 Tag 改為最新 Commit SHA)
         │
         ▼
 5. 地端執行 `kubectl apply -f deployment.yaml`
    (K8s 下載 Docker Hub 最新 Image，並啟動 2 個 Pod)
         │
         ▼
 6. K8s Service (LoadBalancer) 自動將流量從本機網卡導向 Pod
    (本機可用 http://127.0.0.1:8080 存取)
         │
         ▼
 7. 啟動 Pinggy 外網穿透隧道 (`ssh -p 443 -R 80:127.0.0.1:8080 ...`)
    (Pinggy 提供一組公開的 HTTPS 網址給外部人，並將流量穿透回您本地的 8080 埠)
         │
         ▼
[ 外部人員成功開啟網頁 ] 
```

### 1. 代碼變更與安全流水線 (GitHub CI)
當您提交程式碼至 GitHub `main` 分支時，GitHub Actions 會自動執行 [security.yml](.github/workflows/security.yml) 的任務：
* 使用 Semgrep 靜態分析代碼中的潛在風險。
* 使用 Trivy 針對 `pom.xml` 與解包後的二進位 `BOOT-INF/lib/*.jar` 進行相依套件漏洞掃描。

### 2. 映像檔打包與上傳
當所有安全防線皆確認通過後，工作流將自動引導 Docker 建置符合命名規範的鏡像（例如 `j9686/spring-boot-demo-app:<commit-sha>`），並將其推送至 Docker Hub 映像檔儲存庫。

### 3. GitOps 部署設定自動更新
映像檔上傳完成後，工作流會以 `sed` 指令自動將 `deployment.yaml` 中的 `image:` 欄位更新為最新的映像檔 Tag（最新的 Commit SHA），並自動 Git commit / push 回您的儲存庫。

### 4. Kubernetes 部署與流量映射
* 當您在地端執行 `kubectl apply -f deployment.yaml` 時，地端 K8s 叢集會拉取上傳至 Docker Hub 的最新映像檔，並運行 2 個 Pod 副本。
* K8s 中的 `Service` 類型設定為 `LoadBalancer`，其內部網路控制器會直接將本機的 `127.0.0.1:8080` 流量對應進這兩個 Pod，進行負載平衡分發。

### 5. 外部人員存取 (外網穿透)
由於地端 K8s 運行於本地沙盒，外部人員無法直接連線。藉由執行外網穿透指令：
```bash
ssh -p 443 -R 80:127.0.0.1:8080 free.pinggy.io
```
Pinggy 伺服器會提供一組公開網址（例如 `https://xxxx.free.pinggy.net`），將網際網路流量穿透傳送回您本地的 `127.0.0.1:8080` 埠口，外部人員即可流暢且安全地存取您部署在地端 K8s 叢集上的專案網站！
