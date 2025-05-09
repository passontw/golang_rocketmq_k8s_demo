.PHONY: build-producer build-consumer docker-build-producer docker-build-consumer k8s-deploy k8s-delete

# 變數
REGISTRY ?= your-registry
TAG ?= latest
PRODUCER_IMAGE = $(REGISTRY)/rocketmq-producer:$(TAG)
CONSUMER_IMAGE = $(REGISTRY)/rocketmq-consumer:$(TAG)

# 編譯應用
build-producer:
	go build -o bin/producer ./cmd/producer

build-consumer:
	go build -o bin/consumer ./cmd/consumer

# 構建 Docker 映像
docker-build-producer:
	docker build -t $(PRODUCER_IMAGE) -f build/producer/Dockerfile .

docker-build-consumer:
	docker build -t $(CONSUMER_IMAGE) -f build/consumer/Dockerfile .

# 推送 Docker 映像
docker-push:
	docker push $(PRODUCER_IMAGE)
	docker push $(CONSUMER_IMAGE)

# Kubernetes 部署
k8s-deploy:
	kubectl apply -f kubernetes/rocketmq-namespace.yaml
	kubectl apply -f kubernetes/rocketmq-configmap.yaml
	kubectl apply -f kubernetes/rocketmq-namesrv.yaml
	kubectl apply -f kubernetes/rocketmq-broker.yaml
	@echo "等待 RocketMQ 服務啟動..."
	sleep 10
	sed "s|\$${YOUR_REGISTRY}|$(REGISTRY)|g" kubernetes/rocketmq-producer-deployment.yaml | kubectl apply -f -
	sed "s|\$${YOUR_REGISTRY}|$(REGISTRY)|g" kubernetes/rocketmq-consumer-deployment.yaml | kubectl apply -f -

# 刪除 Kubernetes 部署
k8s-delete:
	kubectl delete -f kubernetes/rocketmq-consumer-deployment.yaml || true
	kubectl delete -f kubernetes/rocketmq-producer-deployment.yaml || true
	kubectl delete -f kubernetes/rocketmq-broker.yaml || true
	kubectl delete -f kubernetes/rocketmq-namesrv.yaml || true
	kubectl delete -f kubernetes/rocketmq-configmap.yaml || true
	kubectl delete -f kubernetes/rocketmq-namespace.yaml || true

# 顯示日誌
logs-producer:
	kubectl -n rocketmq logs -f deployment/rocketmq-producer

logs-consumer:
	kubectl -n rocketmq logs -f deployment/rocketmq-consumer

# 檢查 RocketMQ 狀態
check-rocketmq:
	kubectl -n rocketmq get pods 