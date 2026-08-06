# 🚀 Docker Desktop Local Kubernetes 部署與驗證指南

本指南說明如何在本地環境透過 **Docker Desktop** 建立 Kubernetes 叢集，並逐步部署與驗證本專案的 Spring Boot 應用程式。

---

## 🛠️ 第一部分：啟用 Docker Desktop Kubernetes 叢集

Docker Desktop 內置了單節點的 Kubernetes 叢集，啟用步驟如下：

1. **開啟 Docker Desktop** 應用程式。
2. 點擊右上角的 **齒輪圖示 (Settings)** 進入設定頁面。
3. 在左側選單中，點擊 **Kubernetes**。
4. 勾選 **Enable Kubernetes**。
5. 點擊右下角的 **Apply & restart** 按鈕。
6. 於彈出視窗中點擊 **Install**，系統會自動下載所需的 K8s 映像檔並啟動 Control Plane。
7. **等待數分鐘**，當 Docker Desktop 視窗左下角的 Kubernetes 圖示燈號**變為綠色**（顯示 *Kubernetes is running*）時，即代表地端叢集已順利建立完成。

---

## 🚀 第二部分：逐步部署與驗證

請開啟您的本機終端機（Terminal）並切換至專案根目錄，依序執行以下步驟：

### 步驟 1：確認並切換 K8s 連線上下文 (Context)
確保您的 `kubectl` 指令發送到 Docker Desktop 叢集：
```bash
# 1. 列出目前所有的連線 Context
kubectl config get-contexts

# 2. 切換連線至 Docker Desktop 專用叢集
kubectl config use-context docker-desktop
```

### 步驟 2：驗證節點狀態
確認地端單節點叢集是否處於準備就緒（Ready）狀態：
```bash
kubectl get nodes
```
* **驗證指標**：節點 `docker-desktop` 的 `STATUS` 欄位必須為 `Ready`。

### 步驟 3：部署至地端 K8s
使用專案根目錄下的 [deployment.yaml](deployment.yaml) 進行套用部署：
```bash
kubectl apply -f deployment.yaml
```
* **預期輸出**：
  ```text
  deployment.apps/spring-boot-demo created
  service/spring-boot-demo-service created
  ```

### 步驟 4：監控部署發布狀態
檢查 Deployment 滾動更新進度，確認 Pod 是否已全數正常部署：
```bash
kubectl rollout status deployment/spring-boot-demo
```
* **預期輸出**：當顯示 `deployment "spring-boot-demo" successfully rolled out` 時即代表部署完成。

### 步驟 5：檢查 Pod 與容器狀態
確認實體運行的 Pod 是否正常且已通過 Readiness Probe 健康檢查：
```bash
kubectl get pods
```
* **驗證指標**：
  * **READY** 欄位必須顯示為 `1/1`（代表容器已準備就緒，可開始接收外部請求）。
  * **STATUS** 必須顯示為 `Running`。

### 步驟 6：檢查 Service 對外暴露狀態
確認 Service 是否已成功將地端連接埠暴露在您本機的 `localhost` 上：
```bash
kubectl get svc spring-boot-demo-service
```
* **驗證指標**：
  * `EXTERNAL-IP` 必須顯示為 `localhost`。
  * `PORT(S)` 欄位必須顯示 `8080:XXXXX/TCP`。

### 步驟 7：連線與功能驗證
最後，您可以使用瀏覽器或終端機發送測試請求：

* **使用瀏覽器**：開啟 [http://localhost:8080](http://localhost:8080)
* **使用 curl 指令**：
  ```bash
  curl -I http://localhost:8080
  ```
  *(若回傳狀態碼為 `200 OK`，代表請求已成功穿透 K8s Service，並透過負載平衡分配給您的 Spring Boot 容器處理)*

### 步驟 8：開放外部人員連線存取 (外網穿透)
如果您需要讓外部的人員（如不在同個 Wi-Fi 下的同事或客戶）存取您本地 K8s 部署的網站，可以使用免註冊的 Pinggy (SSH 隧道) 工具將您本地的 `127.0.0.1:8080` 對外安全發布（使用 port 443 避開電信商或防火牆封鎖）：

```bash
ssh -p 443 -R 80:127.0.0.1:8080 free.pinggy.io
```
* **使用說明**：
  1. 執行指令後，終端機會顯示一個臨時主面板，並在最上方提供綠色的 `http://...` 或 `https://...` 公開網址。
  2. 複製該網址給外部人員，對方即可從世界任何地方進行連線存取。
  3. **注意事項**：必須保持該連線終端機視窗開啟；若關閉視窗或按 `Ctrl + C` 中斷，連線隧道將關閉且網址會立即失效。
