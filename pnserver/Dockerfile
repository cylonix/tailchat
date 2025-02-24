FROM golang:1.23-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o /pnserver

FROM alpine:3.18
COPY --from=builder /pnserver /pnserver

# Create directory for APN key
RUN mkdir -p /etc/apn && chmod 700 /etc/apn

ENTRYPOINT ["/pnserver"]