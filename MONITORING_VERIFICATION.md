# 📊 Prometheus 與 Grafana 監控系統驗證報告 (Monitoring Verification Report)

本報告記錄了專案在 **`develop`** 分支上，成功整合 **Spring Boot (Java 26)、Redis、Prometheus 與 Grafana** 四合一可觀測性監控架構的完整實測與驗證數據。

---

## 📋 一、 驗證摘要 (Executive Summary)

* **測試環境**：Mac (Docker Desktop Kubernetes 叢集)
* **測試分支**：`develop` (Commit: `d298d84`)
* **驗證項目**：Actuator 指標生成、Prometheus 定期輪詢、Grafana 自動資料源綁定、PromQL 實時數據查詢。
* **驗證結果**：**全數通過（100% 綠燈）**。

---

## 🔍 二、 各項功能實測數據與佐證

### 1. Spring Boot Actuator 指標端點驗證
透過 HTTP 請求存取 Spring Boot 的 Prometheus 端點：
```bash
curl -s http://localhost:8080/actuator/prometheus
```

#### 實測輸出（節錄）：
```text
# HELP application_ready_time_seconds Time taken for the application to be ready to service requests
# TYPE application_ready_time_seconds gauge
application_ready_time_seconds{application="spring-boot-demo",main_application_class="com.example.demo.DemoApplication"} 3.614

# HELP executor_pool_core_threads The core number of threads for the pool
# TYPE executor_pool_core_threads gauge
executor_pool_core_threads{application="spring-boot-demo",name="applicationTaskExecutor"} 8.0

# HELP jvm_memory_used_bytes The amount of used memory
# TYPE jvm_memory_used_bytes gauge
jvm_memory_used_bytes{application="spring-boot-demo",area="heap",id="Eden Space"} 11887248
jvm_memory_used_bytes{application="spring-boot-demo",area="nonheap",id="Metaspace"} 56122512
...
[成功輸出超過 200 行標準 OpenMetrics 監控指標]
```

---

### 2. Prometheus Target 目標抓取狀態驗證
查詢 Prometheus 內部的目標抓取狀態 API：
```bash
kubectl exec deployment/spring-boot-demo-prometheus -- wget -qO- http://localhost:9090/api/v1/targets
```

#### 實測 API 回傳：
```json
{
  "status": "success",
  "data": {
    "activeTargets": [
      {
        "scrapePool": "spring-boot-app",
        "scrapeUrl": "http://spring-boot-demo-service:8080/actuator/prometheus",
        "health": "up",
        "lastError": "",
        "scrapeInterval": "15s"
      }
    ]
  }
}
```
* **結論**：連線狀態為 **`health: up`**，錯誤訊息為空，Prometheus 正以每 15 秒的頻率穩定抓取指標。

---

### 3. Grafana 資料源自動綁定與健康度驗證
透過 Grafana REST API 檢查預載資料源連線狀態：
```bash
curl -s -u admin:admin http://localhost:3000/api/datasources/uid/PBFA97CFB590B2093/health
```

#### 實測 API 回傳：
```json
{
  "status": "OK",
  "message": "Successfully queried the Prometheus API.",
  "details": {
    "application": "Prometheus"
  }
}
```
* **結論**：Grafana 成功透過 K8s 內部 DNS（`http://spring-boot-demo-prometheus-service:9090`）與 Prometheus 連線完畢。

---

### 4. Grafana 實時 PromQL 數據查詢測試
透過 Grafana Proxy 發送 PromQL 查詢 JVM 記憶體使用量：
```bash
curl -s -u admin:admin "http://localhost:3000/api/datasources/proxy/uid/PBFA97CFB590B2093/api/v1/query?query=jvm_memory_used_bytes"
```

#### 實測查詢結果：
```json
{
  "status": "success",
  "data": {
    "resultType": "vector",
    "result": [
      {
        "metric": {
          "__name__": "jvm_memory_used_bytes",
          "application": "spring-boot-demo",
          "area": "heap",
          "id": "Eden Space"
        },
        "value": [1786333450.561, "11887248"]
      },
      {
        "metric": {
          "__name__": "jvm_memory_used_bytes",
          "application": "spring-boot-demo",
          "area": "nonheap",
          "id": "Metaspace"
        },
        "value": [1786333450.561, "56122512"]
      }
    ]
  }
}
```
* **結論**：Prometheus 成功回傳即時浮點數與字串指標向量，Grafana 可正常將其繪製成時間序列曲線圖。

---

### 5. Kubernetes 叢集 Pod 運作狀態
執行 `kubectl get pods` 確認所有副本皆處於 `Running` 狀態：

| Pod 名稱 | 副本數/就緒數 | 狀態 (Status) | 角色職責 |
| :--- | :--- | :--- | :--- |
| **`spring-boot-demo-*`** | 2/2 | **Running** | Spring Boot Java 26 主應用 + Pinggy SSH 反向隧道側車 |
| **`spring-boot-demo-redis-*`** | 1/1 | **Running** | Redis 快取資料庫 (ClusterIP 內部連通) |
| **`spring-boot-demo-prometheus-*`** | 1/1 | **Running** | Prometheus 指標收集器與時序資料庫 |
| **`spring-boot-demo-grafana-*`** | 1/1 | **Running** | Grafana 儀表板平台 (LoadBalancer 暴露 Port 3000) |

---

## 🖥️ 三、 Grafana 儀表板實戰操作步驟

1. **開啟儀表板**：在瀏覽器中前往 👉 **`http://localhost:3000`**
2. **登入帳密**：
   * **帳號 (Username)**：`admin`
   * **密碼 (Password)**：`admin`
3. **一鍵匯入 JVM 監控大盤**：
   * 點選左側選單 **Dashboards ──► New ──► Import**。
   * 在文字輸入框輸入官方熱門看板 ID **`11378`** 並點擊 **Load**。
   * 下拉選單選取 **Prometheus** 資料來源，點擊 **Import**。
4. **模擬流量產生動態波形**：
   在終端機執行以下指令模擬使用者快速點閱網頁：
   ```bash
   for i in {1..30}; do curl -s http://localhost:8080/ > /dev/null; done
   ```
5. **觀察數據**：
   將 Grafana 右上角的時間範圍切換為 **`Last 5 minutes`**，即可看見即時飆升的 HTTP RPS 請求曲線、JVM 堆積記憶體（Heap Memory）配置、垃圾回收（GC）次數與 CPU 使用率！
