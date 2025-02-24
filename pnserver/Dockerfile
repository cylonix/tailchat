FROM golang:1.21-alpine AS builder

WORKDIR /app
COPY . .
RUN go mod download
RUN CGO_ENABLED=0 GOOS=linux go build -o /pnserver

FROM alpine:3.18
COPY --from=builder /pnserver /pnserver
COPY apn_key.p8 /apn_key.p8

ENTRYPOINT ["/pnserver"]