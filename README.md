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