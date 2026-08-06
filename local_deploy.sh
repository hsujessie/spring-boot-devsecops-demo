#!/bin/bash
# 確保任何指令出錯時立即停止執行
set -e

echo "=================================================="
echo " 📥 1. 正在從 GitHub 拉取最新代碼與 K8s 設定檔"
echo "=================================================="
git pull origin main

echo ""
echo "=================================================="
echo " ☸️ 2. 正在透過 Helm 將最新版本部署至地端 K8s"
echo "=================================================="
helm upgrade --install spring-boot-demo ./charts/spring-boot-demo

# helm：呼叫 Helm 工具主程式。
# upgrade --install：
#    如果 K8s 中已經有這個應用，就對它進行升級 (Upgrade)。
#    如果 K8s 中還沒有這個應用，就進行安裝 (Install)。
#    這能確保每次執行腳本時，不論是首次安裝還是後續更新，指令都能正常工作。
# spring-boot-demo：指定這次部署的Release名稱（也就是 {{ .Release.Name }} 的來源）。
# ./charts/spring-boot-demo：告訴 Helm 我們的設定檔與模板（Chart）存放在本地的哪一個資料夾路徑。

echo ""
echo "=================================================="
echo " ⏳ 3. 正在等待 K8s Pod 滾動更新完成"
echo "=================================================="
kubectl rollout status deployment/spring-boot-demo

# kubectl： CLI we use to change our Kubernetes cluster.
# 滾動更新：指的是在背景下載新映像檔、啟動新容器、執行健康檢查、並刪除舊容器。
# kubectl rollout status：會讓腳本在這一行暫停，並持續監控新容器的啟動狀態（例如螢幕會顯示：Waiting for deployment...）。
# 直到 K8s 回報「所有新容器都已啟動成功且健康，舊容器已完全關閉」後，它才會放行，讓腳本繼續往下執行第 4 步。

echo ""
echo "=================================================="
echo " 🌐 4. 正在從 Tunnel 容器日誌中取得外網公開網址"
echo "=================================================="
# 等待數秒以確保 SSH 連線建立完成
sleep 5
echo "以下為 Pinggy 自動配發的公開網址："
echo "--------------------------------------------------"
kubectl logs -l app=spring-boot-demo -c tunnel | grep -i "pinggy" || kubectl logs -l app=spring-boot-demo -c tunnel
echo "--------------------------------------------------"
echo "提示：您可以隨時透過執行 'kubectl logs -l app=spring-boot-demo -c tunnel' 重新取得網址。"
