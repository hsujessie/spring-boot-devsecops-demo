## 📂 專案架構與 DevSecOps 配置 (Project Structure)

本專案導入 DevSecOps 自動化安全防禦機制，包含 **SAST（靜態程式碼分析）**、**SCA（第三方套件掃描）** 與 **Container Security（容器安全）**：

```text
spring-boot-demo/
│
├── .github/
│   └── workflows/
│       └── security.yml      # GitHub Actions CI/CD 流水線 (整合 Semgrep & Trivy)
│
├── src/                      # Java 原始碼 (Semgrep SAST 靜態掃描對象)
│   └── main/java/...
│
├── Dockerfile                # 容器化定義檔 (Multi-stage Build & Non-root 資安加固)
├── deployment.yaml           # K8s 部署設定 (配置 SecurityContext 與權限鎖定)
├── pom.xml                   # Maven 依賴設定檔 (Trivy SCA 套件漏洞掃描對象)
├── .gitattributes            # Git 屬性與換行字元設定
├── .gitignore                # Git 排除追蹤檔案設定
└── README.md                 # 專案說明文件
```

## 🛡️ CI/CD 資安檢測流程

* **SAST (Static Application Security Testing)**：透過 Semgrep 自動掃描 `src/` 目錄下的 Java 程式碼邏輯與 Hardcoded Secrets。
* **SCA (Software Composition Analysis)**：透過 Trivy 掃描 `pom.xml`，比對第三方套件的已知 CVE 高風險漏洞。
* **Container Security (容器安全)**：
  * **Dockerfile**：採用最小化輕量基底鏡像（Alpine）、多階段構建（Multi-stage Build），並建立 `appuser` 非 root 帳號執行。
  * **deployment.yaml**：套用 Kubernetes `SecurityContext`（`runAsNonRoot: true`、`readOnlyRootFilesystem: true`、`allowPrivilegeEscalation: false`），實踐縱深防禦。