# 🐳 Docker 與 Kubernetes (K8s) 架構整合與自動化部署指南 (公開儲存庫安全版)

本專案是一個公開（Public）的 GitHub 儲存庫。本指南詳細說明在此安全模型下，如何設計**兼顧資安與高度自動化**的部署流程，並說明專案的架構分層、Docker 與 K8s 之間的職責。

---

## 🔒 重要安全提醒：為何不能在公開儲存庫使用 Self-hosted Runner？

> [!CAUTION]
> **對於公開 (Public) 儲存庫，在您個人電腦（Mac）上運行 Self-hosted Runner 是極高風險的資安漏洞！**
> * **風險原因**：公開儲存庫允許世界上的任何人 Fork 本專案並發送 **Pull Request (PR)**。如果惡意使用者在 PR 中修改了流水線或測試指令，GitHub 會將這些指令派送到您本地的 Mac 執行，這會讓對方可以直接在您的 Mac 執行任意代碼、存取您的私密檔案，甚至安裝惡意軟體。
> * **安全方案**：我們必須將所有建置與安全檢測工作移回 GitHub 託管的雲端沙盒伺服器（`runs-on: ubuntu-latest`），與您的本地 Mac 徹底隔離，並採用 **GitOps 寫回** 與 **本地腳本一鍵部署** 進行對接。

---

## 🏗️ 專案架構分層說明 (Helm 整合)

本專案將部署配置交由 **Helm Chart** 結構進行模板化管理：

1. **[pom.xml](pom.xml)**：定義 Java 建置與套件依賴。
2. **[Dockerfile](Dockerfile)**：採用多階段構建，包裝為安全且唯讀的 Docker 映像檔。
3. **`charts/spring-boot-demo/` (Helm Chart)**：
   * **[Chart.yaml](charts/spring-boot-demo/Chart.yaml)**：定義 Chart 的基本描述與版本資訊。
   * **[values.yaml](charts/spring-boot-demo/values.yaml)**：全域變數設定檔，預設映像檔倉庫已設定為 `j9686/spring-boot-demo-app`。
   * **[templates/deployment.yaml](charts/spring-boot-demo/templates/deployment.yaml)**：K8s 部署配置，已整合 **Tunnel 側車容器 (Sidecar)**。
   * **[templates/service.yaml](charts/spring-boot-demo/templates/service.yaml)**：K8s Service 配置，定義 `LoadBalancer` 服務。

---

## 🤝 Docker 與 Kubernetes (K8s) 之間的關係

*   **Docker（貨櫃）**：負責**「包裝」**。把您的 Java 程式與運行環境（JRE）打包為一個獨立運作的標準貨櫃（Docker 映像檔）。
*   **Kubernetes (港口管理系統)**：負責**「編排與調度」**。根據 Helm 指令，在本地 K8s 叢集中調度運行 2 個 Pod 副本、執行健康檢查、並建立外部流量分流。

---

## 🔄 安全自動化部署閉環流程

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
 5. 本地 K8s 自動拉取 Image，並在同個 Pod 內啟動 Spring Boot 與 Tunnel 容器
         │
         ▼ (Tunnel 容器自動連線至 Pinggy 建立隧道)
 6. 腳本自動從 Tunnel 日誌中過濾並輸出外網公開存取網址 (URL)
         │
         ▼
[ 外部人員成功存取網頁 ]
```

---

## 🚀 本地一鍵部署與驗證步驟 (一鍵自動化)

由於採用安全隔離架構，您不需在 Mac 運行背景代理程式。每當 GitHub 上的 Actions 流水線執行完畢後，您只需在本地終端機執行一個腳本即可完成同步部署：

1. **執行本地部署腳本**：
   在您 Mac 專案根目錄執行：
   ```bash
   ./local_deploy.sh
   ```
2. **自動化運作項目**：
   該腳本會全自動替您執行：
   * `git pull` 從 GitHub 同步最新被寫回的 `values.yaml`（含最新影像標籤）。
   * `helm upgrade --install` 發布部署到您 Docker Desktop 的 K8s。
   * 自動等待 Pod 滾動更新至 Ready 狀態。
   * **自動取得公開 URL**：等待 5 秒後，腳本會自動抓取 Pod 的 Sidecar 日誌，過濾並直接在螢幕上輸出 Pinggy 產生的 `https://xxxx.free.pinggy.link` 網址！
3. **複製網址**：複製螢幕上顯示的網址給外部人員測試即可，完全免去手動輸入穿透指令的繁瑣步驟！
