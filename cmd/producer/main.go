package main

import (
	"context"
	"fmt"
	"log"
	"time"

	"rocketmq-k8s-demo/pkg/config"

	"github.com/apache/rocketmq-client-go/v2"
	"github.com/apache/rocketmq-client-go/v2/primitive"
	"github.com/apache/rocketmq-client-go/v2/producer"
)

func main() {
	// 載入配置
	cfg := config.NewRocketMQConfig()
	log.Printf("RocketMQ 生產者啟動中... 連接到 NameServer: %s, Topic: %s, Group: %s\n",
		cfg.NameServerAddress, cfg.Topic, cfg.Group)

	// 創建生產者
	p, err := rocketmq.NewProducer(
		producer.WithNameServer([]string{cfg.NameServerAddress}),
		producer.WithRetry(2),
		producer.WithGroupName(cfg.Group),
	)
	if err != nil {
		log.Fatalf("創建生產者失敗: %s", err.Error())
	}

	// 啟動生產者
	err = p.Start()
	if err != nil {
		log.Fatalf("啟動生產者失敗: %s", err.Error())
	}
	defer p.Shutdown()
	log.Println("RocketMQ 生產者已啟動")

	// 每3秒發送一條消息
	counter := 0
	for {
		counter++
		msg := fmt.Sprintf("Hello World! 這是第 %d 條訊息 - 時間: %s", counter, time.Now().Format(time.RFC3339))

		// 創建消息
		message := &primitive.Message{
			Topic: cfg.Topic,
			Body:  []byte(msg),
		}

		// 添加自定義標籤
		message.WithTag("TagA")

		// 發送消息
		res, err := p.SendSync(context.Background(), message)
		if err != nil {
			log.Printf("發送消息失敗: %s", err.Error())
		} else {
			log.Printf("消息發送成功: %s, 消息ID: %s", msg, res.MsgID)
		}

		time.Sleep(3 * time.Second)
	}
}
