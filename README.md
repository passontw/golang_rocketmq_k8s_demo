# RocketMQ Kubernetes 示範專案

此專案展示如何在 Kubernetes 上部署 RocketMQ 消息中間件，並使用 Go 客戶端進行訊息生產和消費。

## 前置需求

- Kubernetes 集群 (v1.18+)
- kubectl 命令行工具
- 基本的 Kubernetes 和消息隊列概念理解

## 系統架構

本示範包含以下組件：

- **RocketMQ NameServer**: 註冊中心，管理 Broker 及其 Topic 信息
- **RocketMQ Broker**: 消息存儲和轉發服務器
- **Go 消息生產者**: 每3秒生成並發送一條消息
- **Go 消息消費者**: 接收並處理消息

## 部署步驟

### 1. 克隆專案 (可選)

```bash
git clone https://github.com/yourusername/rocketmq-k8s-demo.git
cd rocketmq-k8s-demo
```

### 2. 創建 RocketMQ 命名空間

```bash
kubectl apply -f kubernetes/rocketmq-namespace.yaml
```

### 3. 部署網絡測試容器 (用於診斷)

```bash
kubectl apply -f kubernetes/network-test-pod.yaml
```

### 4. 創建 RocketMQ 配置

```bash
kubectl apply -f kubernetes/rocketmq-configmap.yaml
```

### 5. 部署 RocketMQ NameServer

```bash
kubectl apply -f kubernetes/rocketmq-namesrv.yaml
```

等待 NameServer Pod 變為 Running 狀態:

```bash
kubectl get pods -n rocketmq
```

### 6. 部署 RocketMQ Broker

```bash
kubectl apply -f kubernetes/rocketmq-broker.yaml
```

等待 Broker Pod 變為 Running 狀態:

```bash
kubectl get pods -n rocketmq
```

### 7. 創建消息主題

這是關鍵步驟，必須手動創建 test-topic 主題:

```bash
# 找到 Broker Pod 名稱
kubectl get pods -n rocketmq | grep broker

# 執行命令創建主題 (替換 {BROKER_POD_NAME} 為實際的 Pod 名稱)
kubectl exec -it -n rocketmq {BROKER_POD_NAME} -- sh -c '/home/rocketmq/rocketmq-5.1.4/bin/mqadmin updateTopic -n rocketmq-namesrv.rocketmq.svc.cluster.local:9876 -c DefaultCluster -t test-topic'
```

應該看到類似以下的輸出，表示主題創建成功:

```
create topic to 10.244.X.X:10911 success.
TopicConfig [topicName=test-topic, readQueueNums=8, writeQueueNums=8, perm=RW-, topicFilterType=SINGLE_TAG, topicSysFlag=0, order=false, attributes={}]
```

### 8. 部署消息生產者和消費者

```bash
kubectl apply -f kubernetes/rocketmq-producer-deployment.yaml
kubectl apply -f kubernetes/rocketmq-consumer-deployment.yaml
```

### 9. 驗證系統運行

檢查所有 Pod 是否正常運行:

```bash
kubectl get pods -n rocketmq
```

所有 Pod 應該處於 Running 狀態，並且 READY 欄位應該顯示所有容器都已就緒。

### 10. 檢查消息生產和消費

查看生產者日誌:

```bash
# 找到生產者 Pod 名稱
kubectl get pods -n rocketmq | grep producer

# 查看日誌 (替換 {PRODUCER_POD_NAME} 為實際的 Pod 名稱)
kubectl logs -n rocketmq {PRODUCER_POD_NAME} -c rocketmq-producer
```

您應該能看到類似以下的輸出，表示消息成功發送:

```
2025/05/09 06:07:36 消息發送成功: Hello World! 這是第 6 條訊息 - 時間: 2025-05-09T06:07:36Z, 消息ID: 0AF4005F0001000000002a836c400005
```

查看消費者日誌:

```bash
# 找到消費者 Pod 名稱
kubectl get pods -n rocketmq | grep consumer

# 查看日誌 (替換 {CONSUMER_POD_NAME} 為實際的 Pod 名稱)
kubectl logs -n rocketmq {CONSUMER_POD_NAME} -c rocketmq-consumer
```

您應該能看到類似以下的輸出，表示消息成功接收:

```
2025/05/09 06:07:36 收到消息: Hello World! 這是第 6 條訊息 - 時間: 2025-05-09T06:07:36Z
```

## RocketMQ Go 客戶端的 DNS 解析問題

### 問題描述

RocketMQ Go 客戶端在使用域名連接 NameServer 時，可能會出現以下錯誤:

```
new Namesrv failed.: IP addr error
```

這是因為 Go 客戶端在解析域名時存在限制，無法直接處理純域名格式。

### 官方 GitHub Issue

此問題在 RocketMQ Go 客戶端的 GitHub 倉庫中有相關討論:

- **Issue #920**: [使用阿里云RocketMQ时无法使用域名,报错: new Namesrv failed.: IP addr error](https://github.com/apache/rocketmq-client-go/issues/920)

### 解決方案

根據 Issue #920 的討論，有以下解決方案:

#### 1. 添加 `http://` 前綴 (推薦方法)

在 NameServer 地址前添加 `http://` 前綴:

```yaml
env:
- name: ROCKETMQ_NAMESERVER
  value: "http://rocketmq-namesrv.rocketmq.svc.cluster.local:9876"
```

此解決方案已在 `rocketmq-producer-deployment.yaml` 和 `rocketmq-consumer-deployment.yaml` 中實施。

#### 2. 使用 IP 地址替代域名

如無法使用上述方法，可直接使用 IP 地址:

```yaml
env:
- name: ROCKETMQ_NAMESERVER
  value: "10.96.X.X:9876"  # 替換為實際 NameServer 的 IP
```

但請注意，Kubernetes 中的 Service IP 可能會變化，此方法不如使用前綴穩定。

## Istio 詳細解說與解決 Golang RocketMQ 域名連接問題

### Istio 服務網格概述

Istio 是一個功能強大的開源服務網格平台，專為微服務架構設計，提供以下核心功能:

- **流量管理**: 智能路由、負載均衡、故障恢復
- **安全性**: 自動 mTLS 加密、身份驗證、授權
- **可觀察性**: 分散式追蹤、監控、日誌收集

### Istio 核心架構

Istio 的架構由兩個主要部分組成:

1. **控制平面 (Control Plane)**
   - **Istiod**: 統一控制平面組件，包含:
     - Pilot: 服務發現和流量管理
     - Citadel: 憑證管理和身份驗證
     - Galley: 配置驗證和分發

2. **數據平面 (Data Plane)**
   - **Envoy Proxy**: 部署為 sidecar 容器，攔截和管理服務間通信

### Istio 在 RocketMQ 部署中的應用

在本專案中，我們利用 Istio 為 RocketMQ 系統提供以下增強功能:

1. **服務間加密通信**
   - Broker、Producer 和 Consumer 之間的通信自動啟用 mTLS 加密
   - 防止未授權訪問和竊聽

2. **流量可視化**
   - 全面監控 RocketMQ 組件間的通信模式
   - 識別性能瓶頸和通信問題

3. **進階流量控制**
   - 可實施細粒度流量策略
   - 支持流量遷移和 A/B 測試

### 解決 Golang RocketMQ 域名連接問題的 Istio 配置

雖然 Istio 無法直接修復 RocketMQ Go 客戶端的 DNS 解析邏輯，但我們可以結合 Istio 配置和應用層解決方案:

#### 1. 為 NameServer 創建 DestinationRule

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: rocketmq-namesrv
  namespace: rocketmq
spec:
  host: rocketmq-namesrv.rocketmq.svc.cluster.local
  trafficPolicy:
    tls:
      mode: DISABLE  # 如果 RocketMQ 未啟用 TLS，禁用 Istio 的 mTLS
```

#### 2. 配置 VirtualService 處理超時和重試

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: VirtualService
metadata:
  name: rocketmq-namesrv-vs
  namespace: rocketmq
spec:
  hosts:
  - rocketmq-namesrv.rocketmq.svc.cluster.local
  tcp:
  - route:
    - destination:
        host: rocketmq-namesrv.rocketmq.svc.cluster.local
        port:
          number: 9876
      weight: 100
    timeout: 30s
```

#### 3. 結合應用層解決方案

同時，我們仍需在應用配置中使用 `http://` 前綴:

```yaml
env:
- name: ROCKETMQ_NAMESERVER
  value: "http://rocketmq-namesrv.rocketmq.svc.cluster.local:9876"
```

這種組合方法解決了 DNS 解析問題，同時利用 Istio 實現更高級的網絡功能。

### 最佳實踐建議

1. **監控與告警**
   - 配置 Istio Prometheus 和 Grafana 監控 RocketMQ 服務
   - 設置流量異常和延遲告警

2. **資源限制**
   - 適當配置 Sidecar 資源，防止影響應用性能
   ```yaml
   annotations:
     sidecar.istio.io/proxyCPU: "100m"
     sidecar.istio.io/proxyMemory: "128Mi"
   ```

3. **合理使用 Istio 功能**
   - 只配置真正需要的流量規則，避免過度複雜
   - 利用 `DestinationRule` 配置適當的連接池和超時

## Istio Ambient Mesh 與傳統 Sidecar 模式功能比較

Istio 提供兩種部署模式:傳統的 Sidecar 模式和較新的 Ambient 模式。以下是它們的詳細比較:

### 架構差異

#### 傳統 Sidecar 模式
- 每個應用 Pod 都注入一個 Envoy Proxy 容器
- Proxy 與應用容器共享相同的網絡命名空間
- 所有進出流量都通過 sidecar 代理

#### Ambient 模式
- 使用節點級組件 (ztunnel) 處理 L4 流量
- 可選使用 waypoint proxy 處理 L7 流量
- 無需修改或重啟應用 Pod
- 分層安全模型，將 L4 和 L7 功能分離

### 功能對比詳解

| 功能 | Sidecar 模式 | Ambient 模式 | 備註 |
|------|-------------|-------------|------|
| **部署和資源** |
| 工作負載侵入性 | ❓ 高 (每個 Pod 添加容器) | ✅ 低 (無需修改 Pod) | Ambient 可在不重啟應用的情況下啟用 |
| 資源使用 | ❓ 每個 Pod 分別消耗資源 | ✅ 節點級共享資源 | Ambient 總體資源效率更高 |
| 升級複雜度 | ❓ 需重啟應用 Pod | ✅ 獨立升級 | Ambient 降低了維護難度 |
| **流量管理** |
| 基本路由 | ✅ 完全支援 | ✅ 支援 | 兩種模式都支援 |
| 高級路由 (協議感知) | ✅ 完全支援 | ⚠️ 需使用 waypoint | Ambient 需額外配置 waypoint |
| 流量分割/金絲雀發布 | ✅ 完全支援 | ✅ 支援 (waypoint) | 兩種模式功能類似 |
| **安全功能** |
| mTLS 加密 | ✅ 完全支援 | ✅ 完全支援 | 兩種模式都支援 |
| 身份驗證 | ✅ 完全支援 | ✅ 支援 | 兩種模式都支援 |
| 授權策略 | ✅ 完全支援 | ✅ 分層實施 | Ambient 在 L4 和 L7 分別實施 |
| **可觀察性** |
| 基本指標 | ✅ 完全支援 | ✅ 支援 | 兩種模式都收集關鍵指標 |
| 分散式追蹤 | ✅ 完全支援 | ⚠️ 部分支援 | Ambient 模式下部分追蹤可能受限 |
| 詳細日誌 | ✅ 完全支援 | ⚠️ 分層收集 | L7 日誌需要 waypoint |
| **擴展性** |
| WebAssembly 擴展 | ✅ 完全支援 | ⚠️ 部分支援 | Ambient 的擴展功能仍在發展中 |
| 自定義協議 | ✅ 支援 | ⚠️ 有限支援 | Sidecar 模式提供更多協議擴展支援 |

### Ambient 模式在 RocketMQ 部署中的應用

如果選擇使用 Ambient 模式部署 RocketMQ，需要考慮:

1. **優勢**
   - 無侵入式部署: 不需要重啟或修改 RocketMQ 容器
   - 資源效率: 節省總體資源消耗
   - 簡化操作: 降低網格管理複雜度

2. **潛在問題**
   - **Go 客戶端 DNS 問題仍需解決**: Ambient 不能解決應用層的 DNS 解析邏輯
   - **L7 功能需要 waypoint**: 若需要高級路由和協議感知能力

3. **部署步驟**

   安裝 Ambient 控制平面:
   ```bash
   istioctl install --set profile=ambient
   ```

   標記命名空間使用 Ambient:
   ```bash
   kubectl label namespace rocketmq istio.io/dataplane-mode=ambient
   ```

   部署 waypoint (如需 L7 功能):
   ```yaml
   apiVersion: gateway.networking.k8s.io/v1alpha2
   kind: Gateway
   metadata:
     name: rocketmq-waypoint
     namespace: rocketmq
     annotations:
       istio.io/service-account: rocketmq-sa
   spec:
     gatewayClassName: istio-waypoint
     listeners:
     - name: mesh
       port: 15008
       protocol: HBONE
   ```

4. **最佳實踐**
   - 對 RocketMQ 組件使用基礎 L4 mTLS 加密
   - 使用 CNI 插件以獲得最佳性能
   - 監控 ztunnel 組件狀態和性能

### 模式選擇建議

1. **新部署**: 如果剛開始部署 RocketMQ，Ambient 模式更簡單，資源消耗更低
2. **現有部署**: 如已使用 Sidecar 模式，評估遷移價值
3. **關鍵需求**:
   - 注重性能和資源效率: 優先考慮 Ambient
   - 需要豐富的 L7 特性: 可能 Sidecar 更成熟

無論選擇哪種模式，**解決 Go 客戶端的 DNS 問題仍需使用 `http://` 前綴方法**。

## 多 NameServer 架構的負載平衡解決方案

在生產環境中，部署多個 NameServer 實例以提高可用性是常見做法。以下是幾種在 Kubernetes 環境中實現 RocketMQ NameServer 負載均衡的方法：

### 1. 客戶端層面的負載平衡

RocketMQ Go 客戶端支持使用逗號分隔多個 NameServer 地址：

```yaml
env:
- name: ROCKETMQ_NAMESERVER
  value: "http://rocketmq-namesrv-0.rocketmq-namesrv.rocketmq.svc.cluster.local:9876,http://rocketmq-namesrv-1.rocketmq-namesrv.rocketmq.svc.cluster.local:9876"
```

客戶端會隨機選擇一個進行連接，並在連接失敗時自動嘗試下一個地址。

**注意**: 每個地址都需要添加 `http://` 前綴以解決 DNS 解析問題。

### 2. 使用 StatefulSet 和 Headless Service

將 NameServer 部署改為 StatefulSet 以獲得穩定的網絡標識：

```yaml
apiVersion: v1
kind: Service
metadata:
  name: rocketmq-namesrv
  namespace: rocketmq
spec:
  clusterIP: None  # Headless Service
  ports:
  - port: 9876
    targetPort: 9876
  selector:
    app: rocketmq-namesrv
---
apiVersion: apps/v1
kind: StatefulSet
metadata:
  name: rocketmq-namesrv
  namespace: rocketmq
spec:
  serviceName: "rocketmq-namesrv"
  replicas: 3
  selector:
    matchLabels:
      app: rocketmq-namesrv
  template:
    # ... 容器配置
```

然後客戶端可以使用服務名稱連接：

```yaml
env:
- name: ROCKETMQ_NAMESERVER
  value: "http://rocketmq-namesrv.rocketmq.svc.cluster.local:9876"
```

Kubernetes 會自動將請求分發到不同的 Pod。

### 3. 使用 Istio 實現高級負載均衡

配置 DestinationRule 可以提供更智能的負載均衡策略：

```yaml
apiVersion: networking.istio.io/v1alpha3
kind: DestinationRule
metadata:
  name: rocketmq-namesrv
  namespace: rocketmq
spec:
  host: rocketmq-namesrv.rocketmq.svc.cluster.local
  trafficPolicy:
    loadBalancer:
      simple: ROUND_ROBIN
    connectionPool:
      tcp:
        maxConnections: 100
    outlierDetection:
      consecutive5xxErrors: 5
      interval: 30s
      baseEjectionTime: 30s
```

### 4. Broker 配置相應調整

Broker 也需要連接到所有 NameServer：

```yaml
command: ["sh", "-c", "/home/rocketmq/rocketmq-5.1.4/bin/mqbroker -n http://rocketmq-namesrv-0.rocketmq-namesrv.rocketmq.svc.cluster.local:9876,http://rocketmq-namesrv-1.rocketmq-namesrv.rocketmq.svc.cluster.local:9876 -c /etc/rocketmq/broker.conf"]
```

或使用服務名稱:

```yaml
command: ["sh", "-c", "/home/rocketmq/rocketmq-5.1.4/bin/mqbroker -n http://rocketmq-namesrv.rocketmq.svc.cluster.local:9876 -c /etc/rocketmq/broker.conf"]
```

### 生產環境最佳實踐

1. **部署至少 3 個 NameServer 副本**
2. **使用節點親和性規則確保跨節點分佈**
3. **實施監控和告警機制**
4. **確保每個地址都添加 `http://` 前綴**

## 配置文件說明

### rocketmq-namespace.yaml

創建專用的 `rocketmq` 命名空間，並啟用 Istio 側車注入。

### rocketmq-configmap.yaml

包含 RocketMQ Broker 的配置信息，如 Broker 名稱和存儲路徑等。

### rocketmq-namesrv.yaml

部署 RocketMQ NameServer 服務，包括:
- Deployment: 1個副本的 NameServer
- Service: 暴露 9876 端口

### rocketmq-broker.yaml

部署 RocketMQ Broker 服務，包括:
- Deployment: 1個副本的 Broker
- Service: 暴露 10909 和 10911 端口
- 掛載 ConfigMap 作為配置文件

### rocketmq-producer-deployment.yaml

部署消息生產者服務，每3秒生成一條消息，連接到 NameServer。**重要**: NameServer 地址前必須加 `http://` 前綴。

### rocketmq-consumer-deployment.yaml

部署消息消費者服務，接收並處理來自指定主題的消息。**重要**: NameServer 地址前必須加 `http://` 前綴。

## Istio 集成

本專案已啟用 Istio 服務網格，通過以下方式配置:

1. 命名空間標籤啟用側車注入:
```yaml
metadata:
  labels:
    istio-injection: enabled
```

2. 明確側車注入註解:
```yaml
annotations:
  sidecar.istio.io/inject: "true"
```

Istio 提供了以下好處:
- 服務間 mTLS 自動加密
- 流量監控和可觀察性
- 高級流量管理功能

## 故障排除

### 1. DNS 解析問題

如果生產者或消費者無法連接 NameServer，請確認：
- NameServer 地址前有 `http://` 前綴 (RocketMQ Go 客戶端的特殊要求)
- 使用完整的服務地址: `rocketmq-namesrv.rocketmq.svc.cluster.local:9876`

### 2. Topic 不存在錯誤

如果日誌中顯示 "topic not exist" 錯誤，請確認已執行步驟 7 創建主題。

### 3. Pod 啟動問題

如果任何 Pod 無法正常啟動：
- 檢查資源限制是否合適
- 確認容器鏡像是否可訪問
- 查看 Pod 事件和日誌: `kubectl describe pod <pod-name> -n rocketmq` 

### 4. 消息無法發送或接收

如果系統組件似乎正常但消息無法傳遞：
- 確認主題已正確創建
- 驗證生產者和消費者使用相同的主題名稱
- 檢查網絡策略是否允許 Pod 之間通信

## 常見問題解答 (FAQ)

### Q: 為什麼需要在 NameServer 地址前添加 `http://` 前綴?
A: RocketMQ Go 客戶端在處理域名時有特殊要求。當使用純域名格式時，客戶端會認為它是 IP 地址並嘗試驗證，導致錯誤。添加前綴使客戶端將其視為 URL，繞過了這一限制。詳見 [GitHub Issue #920](https://github.com/apache/rocketmq-client-go/issues/920)。

### Q: 為什麼我的 Pod 處於 CrashLoopBackOff 狀態?
A: 最常見的原因是 NameServer 連接問題或主題不存在。確保:
1. NameServer 已正確部署且運行中
2. 連接字串使用了 `http://` 前綴 
3. 已創建 `test-topic` 主題

### Q: 是否可以不使用 Istio?
A: 是的，可以移除與 Istio 相關的標籤和註解。但請注意，這會失去 Istio 提供的安全和監控功能。

### Q: 如何監控 RocketMQ 系統?
A: 可以使用:
1. Istio 的 Prometheus 和 Grafana 監控網格流量
2. RocketMQ Dashboard (需額外部署)
3. Kubernetes 原生監控工具

### Q: Istio Ambient 模式可以解決 Go 客戶端的 DNS 問題嗎?
A: 不能直接解決。Ambient 模式改變了服務網格的部署和管理方式，但應用層的 DNS 解析邏輯仍需通過添加 `http://` 前綴解決。

### Q: 如何選擇 Istio 的 Sidecar 或 Ambient 模式?
A: 根據需求選擇:
- 如果優先考慮非侵入式部署和資源效率，選擇 Ambient
- 如果需要全面且成熟的 L7 功能，選擇 Sidecar
- 在任何模式下，RocketMQ Go 客戶端都需要使用 `http://` 前綴解決 DNS 問題

## 清理資源

要刪除所有部署的資源，執行:

```bash
kubectl delete namespace rocketmq
```

## 注意事項

1. **持久性存儲**: 此示範使用 `emptyDir` 臨時存儲。在生產環境中，應使用 PersistentVolume 保存數據。

2. **副本數量**: 生產環境中應增加 NameServer 和 Broker 的副本數以提高可用性。

3. **資源限制**: 根據工作負載調整容器的資源請求和限制。

4. **安全性**: 生產環境中應加入適當的認證和授權機制。

5. **網絡隔離**: 考慮使用 NetworkPolicy 限制 Pod 間通信。

## 主要組件版本

- RocketMQ: 5.1.4
- Go 客戶端: 2.1.1
- Kubernetes: 兼容 1.18+

## 專案結構

```
.
├── build                   # Docker 構建文件
├── cmd                     # Go 程序入口
│   ├── consumer            # 消費者代碼
│   └── producer            # 生產者代碼
├── conf                    # 配置文件
├── kubernetes              # Kubernetes 部署文件
│   ├── rocketmq-broker.yaml
│   ├── rocketmq-configmap.yaml
│   ├── rocketmq-consumer-deployment.yaml
│   ├── rocketmq-namespace.yaml
│   ├── rocketmq-namesrv.yaml
│   ├── rocketmq-producer-deployment.yaml
│   └── network-test-pod.yaml
└── pkg                     # 共享代碼庫
    └── config              # 配置處理
```

## 參考資料

- [RocketMQ 官方文檔](https://rocketmq.apache.org/docs/quick-start/)
- [RocketMQ Go 客戶端](https://github.com/apache/rocketmq-client-go)
- [RocketMQ Go 客戶端 Issue #920](https://github.com/apache/rocketmq-client-go/issues/920)
- [Kubernetes 官方文檔](https://kubernetes.io/docs/home/)
- [Istio 服務網格](https://istio.io/latest/docs/)
- [Istio Ambient Mesh](https://istio.io/latest/docs/ops/ambient/)

---

*本文檔基於 RocketMQ 5.1.4 和 Kubernetes 1.18+ 撰寫，可能需要針對不同版本進行調整。* 