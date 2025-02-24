package main

import (
	"context"
	"flag"
	"log"
	"net/http"
	"os"
	"os/signal"
	"syscall"

	"github.com/go-redis/redis/v8"
	"github.com/sideshow/apns2"
	"github.com/sideshow/apns2/token"
)

func main() {
    port := flag.Int("port", 9000, "Port number to listen on")
    flag.Parse()

	// Setup Redis client
	rdb := redis.NewClient(&redis.Options{
		Addr:     os.Getenv("REDIS_HOST") + ":" + os.Getenv("REDIS_PORT"),
		Password: os.Getenv("REDIS_PASSWORD"),
		DB:       0,
	})

	// Setup APN client
	authKey, err := token.AuthKeyFromFile(os.Getenv("APN_KEY_PATH"))
	if err != nil {
		log.Fatalf("Failed to load APN key: %v", err)
	}

	token := &token.Token{
		AuthKey: authKey,
		KeyID:   os.Getenv("APN_KEY_ID"),
		TeamID:  os.Getenv("APN_TEAM_ID"),
	}

	client := apns2.NewTokenClient(token)
	if os.Getenv("APN_DEVELOPMENT") == "true" {
		client = client.Development()
	} else {
		client = client.Production()
	}

	server := &PNServer{
		redis:       rdb,
		apnClient:   client,
		apnBundleID: os.Getenv("APN_BUNDLE_ID"),
		logger:      log.New(os.Stdout, "[PNServer] ", log.LstdFlags|log.Lshortfile),
	}

	// Setup context with cancellation
	ctx, cancel := context.WithCancel(context.Background())
	defer cancel()

	// Handle shutdown signals
	sigChan := make(chan os.Signal, 1)
	signal.Notify(sigChan, syscall.SIGINT, syscall.SIGTERM)
	go func() {
		<-sigChan
		cancel()
	}()

	log.Printf("Starting APN server on :%v", port)
	if err := server.Start(ctx, *port); err != nil && err != http.ErrServerClosed {
		log.Fatalf("Server error: %v", err)
	}
}
