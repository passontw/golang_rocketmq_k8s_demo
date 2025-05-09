#!/bin/bash

set -e

# 顏色設置
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}===== RocketMQ 簡易測試環境 =====${NC}"

# 檢查必要命令
for cmd in docker docker-compose; do
  if ! command -v $cmd &> /dev/null; then
    echo -e "${YELLOW}錯誤: 未找到 $cmd 命令, 請先安裝它${NC}"
    exit 1
  fi
done

# 創建臨時 docker-compose 文件
cat > docker-compose.tmp.yml << EOF
version: '3'
services:
  namesrv:
    image: apache/rocketmq:5.1.4
    container_name: rocketmq-namesrv
    command: sh mqnamesrv
    ports:
      - "9876:9876"
    environment:
      - JAVA_OPT=-Duser.home=/opt

  broker:
    image: apache/rocketmq:5.1.4
    container_name: rocketmq-broker
    command: sh mqbroker -n namesrv:9876 -c /opt/broker.conf
    ports:
      - "10909:10909"
      - "10911:10911"
    environment:
      - JAVA_OPT=-Duser.home=/opt
    volumes:
      - ./kubernetes/rocketmq-configmap.yaml:/opt/broker.conf
    depends_on:
      - namesrv
EOF

echo -e "${GREEN}啟動本地 RocketMQ...${NC}"
docker-compose -f docker-compose.tmp.yml up -d

echo -e "${GREEN}等待 RocketMQ 服務啟動...${NC}"
sleep 10

# 建立目錄
mkdir -p bin

echo -e "${GREEN}編譯生產者...${NC}"
go build -o bin/producer ./cmd/producer

echo -e "${GREEN}編譯消費者...${NC}"
go build -o bin/consumer ./cmd/consumer

echo -e "${GREEN}啟動消費者...${NC}"
export ROCKETMQ_NAMESERVER="localhost:9876"
export ROCKETMQ_TOPIC="test-topic"
export ROCKETMQ_GROUP="test-group"

echo -e "${YELLOW}消費者已啟動，等待消息接收...${NC}"
echo -e "${YELLOW}在新的終端視窗中執行以下命令啟動生產者:${NC}"
echo -e "${GREEN}export ROCKETMQ_NAMESERVER=localhost:9876; export ROCKETMQ_TOPIC=test-topic; export ROCKETMQ_GROUP=test-group; ./bin/producer${NC}"

./bin/consumer

# 清理
echo -e "${GREEN}清理臨時文件...${NC}"
rm -f docker-compose.tmp.yml 