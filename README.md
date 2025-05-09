# RocketMQ Kubernetes 示範

本專案展示如何在 Kubernetes 中部署 RocketMQ，並使用 Golang 開發生產者和消費者應用程式。

## 專案結構

```
.
├── build                   # Docker 構建相關文件
│   ├── consumer            # 消費者 Docker 相關文件
│   └── producer            # 生產者 Docker 相關文件
├── cmd                     # 應用程式代碼
│   ├── consumer            # 消費者程式
│   └── producer            # 生產者程式
├── kubernetes              # Kubernetes 部署文件
│   ├── rocketmq-namespace.yaml
│   ├── rocketmq-configmap.yaml
│   ├── rocketmq-namesrv.yaml
│   ├── rocketmq-broker.yaml
│   ├── rocketmq-producer-deployment.yaml
│   └── rocketmq-consumer-deployment.yaml
├── pkg                     # 共用套件
│   └── config              # 配置相關代碼
├── go.mod                  # Go 模組文件
├── go.sum                  # Go 模組依賴校驗
├── Makefile                # 構建和部署腳本
└── README.md               # 專案說明
```

## 運行環境要求

- Kubernetes 集群（v1.18+）
- Docker
- kubectl 命令行工具
- Golang 1.22 或更高版本

## 快速入門

### 1. 克隆專案

```bash
git clone https://github.com/yourusername/rocketmq-k8s-demo.git
cd rocketmq-k8s-demo
```

### 2. 構建 Docker 映像

首先修改 Makefile 中的 `REGISTRY` 變數為您自己的 Docker 映像倉庫：

```bash
# 構建生產者映像
make docker-build-producer

# 構建消費者映像
make docker-build-consumer

# 推送映像到倉庫
make docker-push
```

### 3. 部署 RocketMQ 到 Kubernetes

```bash
make k8s-deploy
```

### 4. 檢查部署狀態

```bash
make check-rocketmq
```

### 5. 查看生產者和消費者日誌

```bash
# 查看生產者日誌
make logs-producer

# 查看消費者日誌
make logs-consumer
```

### 6. 清理資源

```bash
make k8s-delete
```

## 應用說明

- **生產者**：每隔 3 秒發送一條包含時間戳的 "Hello World" 消息到 `test-topic` 主題。
- **消費者**：訂閱 `test-topic` 主題並接收消息，收到消息時輸出到日誌。

## 配置選項

通過環境變數可以自定義應用程式行為：

- `ROCKETMQ_NAMESERVER`：RocketMQ 名稱服務器地址，預設為 `rocketmq-namesrv:9876`
- `ROCKETMQ_TOPIC`：消息主題，預設為 `test-topic`
- `ROCKETMQ_GROUP`：消費者/生產者群組，預設分別為 `consumer-group` 和 `producer-group`

## 問題排查

### 常見問題

1. **無法連接到 RocketMQ 名稱服務器**
   確認 RocketMQ 名稱服務器 Pod 是否正常運行：
   ```bash
   kubectl -n rocketmq get pods -l app=rocketmq-namesrv
   ```

2. **消息發送失敗**
   檢查 Broker 狀態：
   ```bash
   kubectl -n rocketmq get pods -l app=rocketmq-broker
   ```

3. **Docker 映像推送失敗**
   確認您已登入 Docker 映像倉庫：
   ```bash
   docker login your-registry
   ``` 