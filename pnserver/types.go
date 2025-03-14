package main

import (
	"log"
	"strconv"
	"time"

	"github.com/go-redis/redis/v8"
	"github.com/sideshow/apns2"
)

type Platform string

const (
	PlatformApple   Platform = "apple"
	PlatformAndroid Platform = "android"
)

type TokenInfo struct {
	Token        string
	Platform     Platform
	LastUpdate   int64
	LastPushSent int64
	SentCount    int
}

type TokenUpdate struct {
	ID       string   `json:"id"`
	Token    string   `json:"token"`
	Platform Platform `json:"platform"`
}

type PNServer struct {
	redis       *redis.Client
	apnClient   *apns2.Client
	apnBundleID string
	logger      *log.Logger
}

type PushRequest struct {
	Sender         string `json:"sender"`          // For push notification display. Never stored.
	Receiver       string `json:"receiver"`        // For push notification display. Never stored.
	SenderHostname string `json:"sender_hostname"` // For push notification display. Never stored.
	SenderID       string `json:"sender_id"`
	ReceiverID     string `json:"receiver_id"`
	MessageType    string `json:"message_type"`
	Message        string `json:"message"` // For push notification display. Never stored.
}

const (
	tokenUpdateInterval = 15 * time.Minute
	pushRateLimit       = 30 // seconds
	fasterRateLimit     = 5  // seconds
)

func parseInt(s string) int {
	n, err := strconv.Atoi(s)
	if err != nil {
		return 0
	}
	return n
}

func parseInt64(s string) int64 {
	n, err := strconv.ParseInt(s, 10, 64)
	if err != nil {
		return 0
	}
	return n
}
