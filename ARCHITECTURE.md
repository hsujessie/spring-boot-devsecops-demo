# 📂 Spring Boot Demo 專案架構與說明

本專案是一個導入了 **DevSecOps** 安全防護機制（包含 SAST、SCA、容器安全）的 Spring Boot 專案。以下為專案整體的架構與各檔案的角色說明：

---

### 1. 📂 核心原始碼與設定 (`src/` 目錄)
*   **Java 程式碼管理**
    *   [DemoApplication.java](src/main/java/com/example/demo/DemoApplication.java)：Spring Boot 應用程式的啟動進入點（Entry Point）。
    *   [ServletInitializer.java](src/main/java/com/example/demo/ServletInitializer.java)：設定外置 Servlet 容器（如 Tomcat）的初始化類別（本專案預設打包為 JAR，但保留了 WAR 部署的彈性結構）。
    *   [FunRestController.java](src/main/java/com/example/demo/rest/FunRestController.java)：定義 Web REST API 路由與商務邏輯的控制器（Controller）。
*   **資源配置檔**
    *   [application.properties](src/main/resources/application.properties)：Spring Boot 應用程式的參數配置檔（如連接埠、資料庫連線等設定）。

---

### 2. 🛡️ DevSecOps 與部署設定 (根目錄核心檔案)
*   **[.github/workflows/security.yml](.github/workflows/security.yml)**：**GitHub Actions 自動化安全流水線**
    *   **SAST 掃描**：使用 Semgrep 靜態分析 Java 原始碼中的安全漏洞與 Hardcoded Secrets。
    *   **Fast SCA 掃描**：使用 Trivy 掃描 `pom.xml`，第一時間阻擋有 CVE 漏洞的套件宣告。
    *   **Deep SCA 二進位審計**：將編譯產出的 JAR 包解開，透過 Trivy 以 `rootfs` 模式深層掃描實體套件 `BOOT-INF/lib/*.jar`。
    *   **Container 掃描**：以 Trivy 掃描 Container OS 的基礎漏洞。
    *   **Docker Hub 推送**：安全檢測全數通過後，自動登入 Docker Hub 並推送含有 Commit SHA 與 latest 雙標籤的 Docker 映像檔。
    *   **本地 K8s 自動部署**：藉由地端 Mac Self-hosted Runner 自動執行 `helm upgrade`，將最新的映像檔自動發布至本地 Kubernetes 叢集。
*   **[Dockerfile](Dockerfile)**：**容器化配置（安全性加固）**
    *   **多階段構建 (Multi-stage Build)**：分開編譯環境與運行環境，縮減映像檔體積。
    *   **最小化運行環境**：採用 JRE Alpine 輕量基底，並建立非 root 用戶（`appuser`）執行 Java，降低被入侵後的危害防禦面。
*   **[charts/spring-boot-demo/](charts/spring-boot-demo/)**：**Kubernetes Helm Chart 部署設定（資安鎖定與自動穿透）**
    *   **Pod/Container SecurityContext**：啟用 `runAsNonRoot: true`、`readOnlyRootFilesystem: true`（唯讀系統）並丟棄所有 Linux 特權（`drop: ALL`），嚴格遵守最小權限原則。
    *   **K8s Service**：定義 `LoadBalancer` 服務，將容器內部的 `8080` 對應到外部的 `8080` 連接埠，方便本地直接存取。
    *   **Tunnel Sidecar**：在 Pod 中加入自動穿透側車容器，啟動時自動與 Pinggy 建立 SSH 隧道並配發對外公開測試 URL。

---

### 3. ⚙️ 專案建置與依賴管理
*   **[pom.xml](pom.xml)**：Maven 專案的靈魂設定檔，宣告專案依賴（如 Spring Boot Starter Web）、Java 版本（JDK 26）、打包格式（JAR），以及編譯用外掛程式。
*   **`mvnw` / `mvnw.cmd` / `.mvn/`**：Maven Wrapper 腳本，用來鎖定 Maven 編譯工具的版本，確保所有開發者與 CI/CD 機台使用的是相同的 Maven 建置環境。

---

### 4. 📝 輔助與版本控制檔案
*   **[README.md](README.md)**：專案說明文件，詳細列出 CI/CD 資安防禦架構與 Fast / Deep SCA 的比較表。
*   **[local_k8s_setup.md](local_k8s_setup.md)**：本地 Docker Desktop Kubernetes 部署與驗證指南。
*   **[DOCKER_K8S_GUIDE.md](DOCKER_K8S_GUIDE.md)**：Docker 與 Kubernetes 架構整合說明指南（包含兩者關係與完整自動化流程）。
*   **`.gitignore`**：排除不需納入 Git 版本控管的暫存檔案（如 `target/` 目錄、`.idea`、`.vscode` 等編輯器設定檔）。
*   **`.gitattributes`**：定義跨平台開發時，Git 如何處理換行字元（LF / CRLF），預防腳本在不同作業系統執行時損毀。
