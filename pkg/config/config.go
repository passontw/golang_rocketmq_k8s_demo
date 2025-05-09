package config

import (
	"os"
)

// RocketMQConfig 包含 RocketMQ 的配置
type RocketMQConfig struct {
	NameServerAddress string
	Topic             string
	Group             string
}

// NewRocketMQConfig 創建新的 RocketMQ 配置
func NewRocketMQConfig() *RocketMQConfig {
	// 優先從環境變數獲取配置，若無則使用預設值
	nameServer := getEnv("ROCKETMQ_NAMESERVER", "172.26.0.2:9876")
	topic := getEnv("ROCKETMQ_TOPIC", "test-topic")
	group := getEnv("ROCKETMQ_GROUP", "test-group")

	return &RocketMQConfig{
		NameServerAddress: nameServer,
		Topic:             topic,
		Group:             group,
	}
}

// 從環境變數獲取值，如果沒有則返回預設值
func getEnv(key, defaultValue string) string {
	value := os.Getenv(key)
	if value == "" {
		return defaultValue
	}
	return value
}
