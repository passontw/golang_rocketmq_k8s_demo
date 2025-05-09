package main

import (
	"context"
	"log"
	"os"
	"os/signal"
	"syscall"

	"rocketmq-k8s-demo/pkg/config"

	"github.com/apache/rocketmq-client-go/v2"
	"github.com/apache/rocketmq-client-go/v2/consumer"
	"github.com/apache/rocketmq-client-go/v2/primitive"
)

func main() {
	// 載入配置
	cfg := config.NewRocketMQConfig()
	log.Printf("RocketMQ 消費者啟動中... 連接到 NameServer: %s, Topic: %s, Group: %s\n",
		cfg.NameServerAddress, cfg.Topic, cfg.Group)

	// 創建消費者
	c, err := rocketmq.NewPushConsumer(
		consumer.WithNameServer([]string{cfg.NameServerAddress}),
		consumer.WithGroupName(cfg.Group),
	)
	if err != nil {
		log.Fatalf("創建消費者失敗: %s", err.Error())
	}

	// 訂閱主題
	err = c.Subscribe(cfg.Topic, consumer.MessageSelector{}, func(ctx context.Context,
		msgs ...*primitive.MessageExt) (consumer.ConsumeResult, error) {
		for i := range msgs {
			log.Printf("收到消息: %s", string(msgs[i].Body))
		}
		return consumer.ConsumeSuccess, nil
	})
	if err != nil {
		log.Fatalf("訂閱主題失敗: %s", err.Error())
	}

	// 啟動消費者
	err = c.Start()
	if err != nil {
		log.Fatalf("啟動消費者失敗: %s", err.Error())
	}
	log.Println("RocketMQ 消費者已啟動")

	// 等待結束信號
	sig := make(chan os.Signal, 1)
	signal.Notify(sig, syscall.SIGINT, syscall.SIGTERM)
	<-sig

	// 關閉消費者
	err = c.Shutdown()
	if err != nil {
		log.Printf("關閉消費者時發生錯誤: %s", err.Error())
	}
	log.Println("RocketMQ 消費者已關閉")
}
