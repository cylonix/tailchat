package main

import (
	"context"
	"encoding/json"
	"fmt"
	"net/http"
	"strings"
	"time"

	"github.com/google/uuid"
	"github.com/sideshow/apns2"
)

func isValidUUID(id string) bool {
	_, err := uuid.Parse(id)
	return err == nil
}

func (s *PNServer) validateAppleToken(_ context.Context, token string) error {
	notification := &apns2.Notification{
		DeviceToken: token,
		Topic:       s.apnBundleID,
		Payload: map[string]interface{}{
			"aps": map[string]interface{}{
				"content-available": 1,
			},
		},
		Priority: apns2.PriorityLow,
		PushType: "background",
	}

	res, err := s.apnClient.Push(notification)
	if err != nil {
		return fmt.Errorf("token validation failed: %w", err)
	}

	switch res.StatusCode {
	case http.StatusOK:
		return nil
	case http.StatusGone: // 410
		return fmt.Errorf("token expired")
	case http.StatusBadRequest: // 400
		if res.Reason == apns2.ReasonBadDeviceToken ||
			res.Reason == apns2.ReasonDeviceTokenNotForTopic {
			return fmt.Errorf("invalid token: %s", res.Reason)
		}
		return fmt.Errorf("validation failed: %s", res.Reason)
	default:
		return fmt.Errorf("unexpected status: %d", res.StatusCode)
	}
}

func (s *PNServer) updateToken(ctx context.Context, id, token string, platform Platform) error {
	now := time.Now().Unix()

	// Validate id format
	if !isValidUUID(id) {
		return fmt.Errorf("invalid id format: must be a valid UUID")
	}

	// Check last update time
	val, err := s.redis.Get(ctx, id).Result()
	if err == nil {
		parts := strings.Split(val, ":")
		if len(parts) != 5 {
			return fmt.Errorf("invalid token info format")
		}
		lastUpdate := parseInt64(parts[2])
		if now-lastUpdate < int64(tokenUpdateInterval.Seconds()) {
			return fmt.Errorf("token update too frequent")
		}
	}

	// Validate token based on platform
	switch platform {
	case PlatformApple:
		if err := s.validateAppleToken(ctx, token); err != nil {
			return fmt.Errorf("apple token validation failed: %w", err)
		}
	case PlatformAndroid:
		// Future Android token validation
		return fmt.Errorf("android token validation not implemented yet")
	default:
		return fmt.Errorf("unsupported platform: %s", platform)
	}

	// Store new token info with platform
	// Format: <token>:<platform>:<last_update>:<last_push>:<sent_count>
	tokenInfo := fmt.Sprintf("%s:%s:%d:0:0", token, platform, now)
	return s.redis.Set(ctx, id, tokenInfo, 0).Err()
}

func (s *PNServer) getTokenInfo(ctx context.Context, id string) (*TokenInfo, error) {
	val, err := s.redis.Get(ctx, id).Result()
	if err != nil {
		return nil, fmt.Errorf("no token found for id %s", id)
	}

	parts := strings.Split(val, ":")
	if len(parts) != 5 {
		return nil, fmt.Errorf("invalid token info format")
	}

	return &TokenInfo{
		Token:        parts[0],
		Platform:     Platform(parts[1]),
		LastUpdate:   parseInt64(parts[2]),
		LastPushSent: parseInt64(parts[3]),
		SentCount:    parseInt(parts[4]),
	}, nil
}

func (s *PNServer) updatePushStats(ctx context.Context, id string, timestamp int64) error {
	info, err := s.getTokenInfo(ctx, id)
	if err != nil {
		return err
	}

	// Update last push time and increment count
	tokenInfo := fmt.Sprintf("%s:%s:%d:%d:%d",
		info.Token,
		info.Platform,
		info.LastUpdate,
		timestamp,
		info.SentCount+1,
	)

	return s.redis.Set(ctx, id, tokenInfo, 0).Err()
}

func (s *PNServer) sendPush(ctx context.Context, req *PushRequest, receiverInfo *TokenInfo) error {
	switch receiverInfo.Platform {
	case PlatformApple:
		return s.sendApplePush(ctx, req, receiverInfo)
	case PlatformAndroid:
		return s.sendAndroidPush(ctx, req, receiverInfo)
	default:
		return fmt.Errorf("unsupported platform: %s", receiverInfo.Platform)
	}
}

func (s *PNServer) sendAndroidPush(_ context.Context, _ *PushRequest, _ *TokenInfo) error {
	// Future Android push notification implementation
	return fmt.Errorf("android push not implemented yet")
}
func (s *PNServer) sendApplePush(ctx context.Context, req *PushRequest, receiverToken *TokenInfo) error {
	if req.MessageType != "connection_request" {
		return fmt.Errorf("unsupported message type: %s", req.MessageType)
	}
	body := fmt.Sprintf("%s@%s wants to connect", req.Sender, req.SenderHostname)
	notification := &apns2.Notification{
		DeviceToken: receiverToken.Token,
		Topic:       s.apnBundleID,
		Priority:    apns2.PriorityHigh, // Set high priority
		Payload: map[string]interface{}{
			"aps": map[string]interface{}{
				"alert": map[string]interface{}{
					"title": "Tailchat Connection Request",
					"body":  body,
				},
                "sound": map[string]interface{}{
                    "critical": 1,
                    "name": "default",
                    "volume": 1.0,
                },
				"interruption-level": "time-sensitive", // Make it time sensitive
				"relevance-score":    1.0,              // Highest relevance
				"critical":           1,                // Mark as critical
			},
			// Custom data
			"sender_hostname": req.SenderHostname,
			"type":            "connection_request",
			"message":         req.Message,
		},
	}

	res, err := s.apnClient.Push(notification)
	if err != nil {
		return fmt.Errorf("push failed: %w", err)
	}

	// Check for specific APNs status codes
	switch res.StatusCode {
	case http.StatusGone: // 410 - Token is no longer valid
		// Clear both tokens from Redis
		if err := s.redis.Del(ctx, req.SenderHostname, req.ReceiverHostname).Err(); err != nil {
			s.logger.Printf("Failed to delete invalid tokens: %v", err)
		}
		return fmt.Errorf("device token is no longer valid")

	case http.StatusBadRequest: // 400 - Bad request
		if res.Reason == apns2.ReasonBadDeviceToken || res.Reason == apns2.ReasonDeviceTokenNotForTopic {
			// Clear both tokens from Redis
			if err := s.redis.Del(ctx, req.SenderHostname, req.ReceiverHostname).Err(); err != nil {
				s.logger.Printf("Failed to delete invalid tokens: %v", err)
			}
			return fmt.Errorf("invalid device token: %s", res.Reason)
		}
		return fmt.Errorf("push failed with reason: %s", res.Reason)

	case http.StatusOK:
		// Update last push time and count
		now := time.Now().Unix()
		return s.updatePushStats(ctx, req.ReceiverID, now)

	default:
		return fmt.Errorf("unexpected status code: %d, reason: %s", res.StatusCode, res.Reason)
	}
}

func (s *PNServer) setupRoutes() *http.ServeMux {
	mux := http.NewServeMux()

	mux.HandleFunc("/apn/tailchat", func(w http.ResponseWriter, r *http.Request) {
		switch r.Method {
		case http.MethodPut:
			s.handleTokenUpdate(w, r)
		case http.MethodDelete:
			s.handleTokenDelete(w, r)
		case http.MethodPost:
			s.handlePushRequest(w, r)
		default:
			http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		}
	})

	return mux
}

func (s *PNServer) Start(ctx context.Context, port int) error {
	server := &http.Server{
		Addr:    ":" + fmt.Sprint(port),
		Handler: s.setupRoutes(),
	}

	go func() {
		<-ctx.Done()
		shutdownCtx, cancel := context.WithTimeout(context.Background(), 5*time.Second)
		defer cancel()
		server.Shutdown(shutdownCtx)
	}()

	return server.ListenAndServe()
}

func (s *PNServer) validateTokens(ctx context.Context, req *PushRequest) (receiverInfo *TokenInfo, senderValid bool, retErr error) {
	_, err := s.getTokenInfo(ctx, req.SenderID)
	if err == nil {
		senderValid = true
	}

	receiverInfo, retErr = s.getTokenInfo(ctx, req.ReceiverID)
	if retErr != nil {
		retErr = fmt.Errorf("receiver validation failed: %w", retErr)
		return
	}

	return
}

func (s *PNServer) handleTokenUpdate(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPut {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var update TokenUpdate
	if err := json.NewDecoder(r.Body).Decode(&update); err != nil {
		http.Error(w, err.Error(), http.StatusBadRequest)
		return
	}

	if err := s.updateToken(r.Context(), update.ID, update.Token, update.Platform); err != nil {
		http.Error(w, err.Error(), http.StatusTooManyRequests)
		return
	}

	w.WriteHeader(http.StatusOK)
}

func (s *PNServer) handleTokenDelete(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodDelete {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	id := r.URL.Query().Get("id")
	if id == "" || !isValidUUID(id) {
		http.Error(w, "id required", http.StatusBadRequest)
		return
	}

	token := r.URL.Query().Get("token")
	tokenInfo, err := s.getTokenInfo(r.Context(), id)
	if err == nil {
		if token != tokenInfo.Token {
			http.Error(w, "invalid token", http.StatusBadRequest)
			return
		}
		if err := s.redis.Del(r.Context(), id).Err(); err != nil {
			http.Error(w, err.Error(), http.StatusInternalServerError)
			return
		}
	}

	w.WriteHeader(http.StatusOK)
}

func (s *PNServer) handlePushRequest(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "Method not allowed", http.StatusMethodNotAllowed)
		return
	}

	var req PushRequest
	if err := json.NewDecoder(r.Body).Decode(&req); err != nil {
		http.Error(w, fmt.Sprintf("Invalid request body: %v", err), http.StatusBadRequest)
		return
	}

	// Validate required fields
	if req.SenderHostname == "" || req.ReceiverHostname == "" {
		http.Error(w, "Missing required fields", http.StatusBadRequest)
		return
	}

	// Validate tokens match stored values
	tokenInfo, senderValid, err := s.validateTokens(r.Context(), &req)
	if err != nil {
		http.Error(w, fmt.Sprintf("Token validation failed: %v", err), http.StatusUnauthorized)
		return
	}

	// Rate limit check (10 seconds between pushes. Shorter if sender is valid)
	now := time.Now().Unix()
	limit := 10
	if senderValid {
		limit = 3
	}
	if int(now-tokenInfo.LastPushSent) < limit {
		http.Error(w, "Rate limit exceeded", http.StatusTooManyRequests)
		return
	}

	// Send push notification
	if err := s.sendPush(r.Context(), &req, tokenInfo); err != nil {
		statusCode := http.StatusInternalServerError
		if strings.Contains(err.Error(), "token is no longer valid") ||
			strings.Contains(err.Error(), "invalid device token") {
			statusCode = http.StatusBadRequest
		}
		http.Error(w, fmt.Sprintf("Failed to send push: %v", err), statusCode)
		return
	}

	w.WriteHeader(http.StatusOK)
}
