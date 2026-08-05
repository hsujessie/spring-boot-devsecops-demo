spring-boot-demo/
│
├── .github/
│   └── workflows/
│       └── security.yml      # GitHub Actions CI/CD 流水線設定檔
│
├── src/                      # Java 原始碼 (Semgrep SAST 掃描對象)
│   └── main/java/...
│
├── Dockerfile                # 步驟 1：定義如何把 app 打包成 Docker Image
├── deployment.yaml           # 步驟 2：定義 K8s 如何運行 Image & 套用 SecurityContext
├── pom.xml                   # Maven 依賴檔 (Trivy SCA 掃描對象)
├── .gitattributes
├── .gitignore
└── README.md