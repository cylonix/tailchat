# Tailchat Push Notification Server

A secure, privacy-focused push notification server for Tailchat.

## Overview

The Push Notification Server (PNServer) is responsible for delivering push notifications to iOS and Android devices while maintaining user privacy and security.

## Features

- End-to-end message privacy
- No message content storage
- Minimal data collection
- Token-based authentication
- Rate limiting protection

## Privacy Protection

### Message Content
- Messages are never stored on the server
- Only device tokens and minimal metadata are kept
- No access to message content
- No logging of message contents

### Device Registration
- Uses token-based authentication
- Tokens are stored securely
- Old tokens are automatically invalidated

### Rate Limiting
- Prevents abuse through rate limiting
- 30-second delay between pushes for unverified senders
- Shorter delays for verified senders

## Known Issues

### Android is not supported yet.

Plan to be done when there is indeed a good demand for it.

### APNs Client Package Security

We are currently waiting for upstream fixes in the APNs client package to resolve security vulnerabilities. The issues are:

1. Dependency chain security updates needed
2. Certificate validation improvements pending
3. HTTP/2 connection handling fixes

Once these issues are resolved upstream, we will update our implementation accordingly.

## Technical Details

### Push Flow
1. Client sends push request
2. Server validates tokens
3. Rate limiting check
4. Push notification sent to Apple/Google services
5. No message content retained

### Configuration
- Environment-based settings
- Configurable rate limits
- Token validation rules
- Logging levels

## Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| APN_AUTH_TYPE | Authentication type for APNs | token |
| APN_KEY_PATH | Path to .p8 key file | ./aps.p8 |
| APN_KEY_ID | Key ID from Apple Developer portal | required |
| APN_TEAM_ID | Apple Developer Team ID | required |
| APN_BUNDLE_ID | App Bundle ID | required |
| APN_DEVELOPMENT | Use sandbox environment | true |
| REDIS_PASSWORD | Redis password | required |
| PORT | Server port | 9000 |

## Building and Running

### Prerequisites
- Docker and Docker Compose
- Apple Developer Account (for iOS notifications)
- Firebase project (for Android notifications)

### Environment Setup

1. Copy the example environment file:
```bash
cp .env.example .env
```

2. Edit `.env` with your configuration:
```bash
# Apple Push Notification Settings
export APN_AUTH_TYPE=token              # Use 'token' for JWT-based auth
export APN_KEY_PATH=./aps.p8            # Path to your .p8 key file
export APN_KEY_ID=your_key_id           # Key ID from Apple Developer portal
export APN_TEAM_ID=your_team_id         # Your Apple Developer Team ID
export APN_BUNDLE_ID=your.app.bundle.id # Your app's bundle ID
export APN_DEVELOPMENT=true             # Use sandbox environment

# Redis Settings
export REDIS_PASSWORD=your_secure_password

# Server Settings
export PORT=9000
```

### Running with Docker Compose

1. Create or modify your `docker-compose.yml`:
```yaml
services:
  pnserver:
    build:
      context: .
      dockerfile: Dockerfile
    ports:
      - "9000:9000"
    environment:
      - APN_AUTH_TYPE=${APN_AUTH_TYPE}
      - APN_KEY_PATH=${APN_KEY_PATH}
      - APN_KEY_ID=${APN_KEY_ID}
      - APN_TEAM_ID=${APN_TEAM_ID}
      - APN_BUNDLE_ID=${APN_BUNDLE_ID}
      - APN_DEVELOPMENT=${APN_DEVELOPMENT}
      - REDIS_PASSWORD=${REDIS_PASSWORD}
      - PORT=${PORT}
    volumes:
      - ./aps.p8:/app/aps.p8:ro
    depends_on:
      - redis

  redis:
    image: redis:alpine
    command: redis-server --requirepass ${REDIS_PASSWORD}
    ports:
      - "6379:6379"
    volumes:
      - redis_data:/data

volumes:
  redis_data:
```

3. Start the services:
```bash
docker compose up -d
```

4. Check logs:
```bash
docker compose logs -f pnserver
```

### Development Mode

For local development without Docker:

1. Source the environment variables:
```bash
source .env
```

2. Run Redis (if not already running):
```bash
docker run -d \
  -p 6379:6379 \
  --name redis \
  redis:alpine \
  redis-server --requirepass "${REDIS_PASSWORD}"
```

3. Run the server:
```bash
go run main.go
```

## Future Improvements

- Enhanced token rotation
- Additional rate limiting strategies
- Improved error handling
- Better metrics and monitoring

## Contributing

Please read our [Contributing Guidelines](../CONTRIBUTING.md) before submitting changes.

## License

BSD 3-Clause License. See [LICENSE](../LICENSE) for details.