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

echo ""
echo "=================================================="
echo " ⏳ 3. 正在等待 K8s Pod 滾動更新完成"
echo "=================================================="
kubectl rollout status deployment/spring-boot-demo

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
