.PHONY: build run docker-build docker-compose-up

build:
	go build -o pnserver

run: build
	./pnserver

docker:
	docker build -t cylonix/tailchat-pnserver .

docker-up:
	docker compose up -d

docker-down:
	docker compose down
