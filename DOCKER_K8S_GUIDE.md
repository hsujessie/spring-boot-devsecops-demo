# 🐳 Docker 與 Kubernetes (K8s) 架構整合與自動化部署指南

本指南詳細說明本專案的系統架構分層、**Docker 與 Kubernetes (K8s) 之間的關係與職責**，以及從「代碼提交」到「外部人員連線成功」的**完全零手動指令**自動化運作流程。

---

## 🖥️ 第一部分：設定本地 Mac GitHub Self-hosted Runner (關鍵前置)

由於您的 Kubernetes 運行在本地 Mac 電腦（Docker Desktop）的私有網路內，雲端的 GitHub Actions 無法直接連接。
我們採用**「自託管執行器（Self-hosted Runner）」**，讓 GitHub Actions 將部署指令直接派送到您的 Mac 本地執行。

### 註冊與啟動步驟（僅需設定一次）：

1. **前往 GitHub 專案儲存庫頁面**。
2. 依次點擊 **Settings** ──► **Actions** ──► **Runners**。
3. 點擊右上角的 **New self-hosted runner**。
4. 選擇您的系統平台為 **macOS**，架構選擇 **ARM64**（若是 Apple Silicon M1/M2/M3 晶片）或 **x64**（Intel 晶片）。
5. 依照 GitHub 頁面上出現的指令，在您 Mac 的**終端機 (Terminal)** 中依序執行：
   * **下載安裝包**（執行下載與解壓指令）。
   * **配置連線設定**（執行 `./config.sh --url ... --token ...`，設定時按 Enter 採用預設值即可）。
   * **啟動運行**（執行 `./run.sh`）。
6. 當您看到終端機顯示 `Listening for Jobs` 時，代表您的 Mac 已成功與 GitHub 連線，可以開始接收自動化部署任務了！

---

## 📂 第二部分：專案架構分層說明 (Helm 整合)

本專案將靜態的 K8s 設定檔轉換為動態的 **Helm Chart** 結構：

1. **[pom.xml](pom.xml)**：專案依賴（如 Spring Boot Starter Web）與建置參數。
2. **[Dockerfile](Dockerfile)**：將專案編譯包裝為唯讀、安全的 Docker 映像檔。
3. **`charts/spring-boot-demo/` (Helm Chart)**：
   * **[Chart.yaml](charts/spring-boot-demo/Chart.yaml)**：定義 Chart 元數據（名稱與版本）。
   * **[values.yaml](charts/spring-boot-demo/values.yaml)**：定義全域變數，如 Image 倉庫、副本數與通訊埠。
   * **[templates/deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)**：K8s Deployment 模板，並整合了 **Tunnel 側車容器 (Sidecar)**。
   * **[templates/service.yaml](charts/spring-boot-demo/templates/service.yaml)**：K8s Service 模板，定義 `LoadBalancer` 服務。

---

## 🤝 第三部分：Docker 與 Kubernetes (K8s) 之間的關係

我們可以用**「貨運物流」**來理解兩者的分工：

*   **Docker（集裝箱/貨櫃）**：負責**「隔離與包裝」**。把您的 Java 程式和執行環境（JRE）包裝進一個標準的貨櫃（Docker 映像檔）。只要包裝完成，該映像檔不論在您的 Mac 還是雲端，運行行為皆完全相同。
*   **Kubernetes (K8s)（港口管理系統）**：負責**「調度與編排」**。K8s 本身不製造貨櫃，而是看著 Helm 部署說明，決定啟動幾個 Pod（貨櫃副本）、健康檢查是否通過、並指派 Service 將外部請求分流。

---

## 🔄 第四部分：自動化閉環：從「代碼提交」到「外網連線」

```text
[ 開發人員 Push 程式 ] 
         │
         ▼
 1. GitHub 雲端派送任務 ──► 2. 本地 Mac Runner 接手並執行安全檢測
                                             │
                                             ▼
 4. 自動執行 Helm 部署 ◄── 3. 使用 Docker 編譯映像檔並 Push 至 Docker Hub
    (helm upgrade --install)
         │
         ▼
 5. 本地 K8s (Docker Desktop) 自動啟動新 Pod 運作
    (Pod 包含 Spring Boot 與 Tunnel Sidecar 兩個容器)
         │
         ▼
 6. Tunnel 容器在背景自動建立 SSH 隧道連線至 Pinggy
    (自動配發 HTTPS 公開網址，並將外部流量導向 Spring Boot 容器)
         │
         ▼
[ 外部人員成功存取網頁 ] 
```

### 1. 代碼變更與檢測
您推送代碼至 `main` 分支時，GitHub 派送任務給您的地端 Mac Runner。地端 Runner 自動拉取程式碼並執行 Semgrep (SAST) 與 Trivy (SCA) 安全檢測。

### 2. 打包與發布
通過檢測後，地端 Runner 調用本地 Docker 引擎打包 Image（標籤為最新的 Commit SHA），並自動 Push 至您的 Docker Hub 倉庫。

### 3. Helm 自動化零指令部署
地端 Runner 執行：
```bash
helm upgrade --install spring-boot-demo ./charts/spring-boot-demo \
  --set image.repository=${{ secrets.DOCKERHUB_USERNAME }}/spring-boot-demo-app \
  --set image.tag=${{ github.sha }}
```
這會直接更新您 Mac 本地的 K8s 叢集。K8s 會下載最新 Image 並重啟 Pod，完全不需要您手動下指令。

### 4. 側車容器 (Sidecar) 自動外網穿透
Pod 內包含兩個共享網路的容器：
*   **`spring-boot-demo`**：運行您的 Java 應用程式（監聽 `8080` 埠）。
*   **`tunnel` (Sidecar)**：啟動時自動連線至 `free.pinggy.io`，建立反向 SSH 隧道，將流量直接引導至同 Pod 內的 `127.0.0.1:8080`。

### 5. 外部人員存取驗證
部署完成後，您完全不用手動執行任何穿透指令！只需在 Mac 終端機輸入以下指令查看日誌：
```bash
kubectl logs -l app=spring-boot-demo -c tunnel
```
在日誌最上方會直接看到自動生成的綠色 `https://xxxx.free.pinggy.link` 網址。將此網址提供給外部人員，即可直接進行存取測試！
