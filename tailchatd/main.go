// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

package main

import (
	"bufio"
	"bytes"
	"encoding/json"
	"flag"
	"fmt"
	"io"
	"log"
	"net"
	"net/http"
	_ "net/http/pprof"
	"runtime/pprof"

	"os"
	"os/signal"
	"path/filepath"
	"strconv"
	"strings"
	"sync"
	"time"

	"github.com/joho/godotenv"
)

const (
	ackInterval    = time.Millisecond * 500
	fileBufferSize = 1024 * 64
)

var (
	enableProfiling = flag.Bool("profile", false, "Enable profiling on :6060")
	port            = flag.Int("port", 50311, "Port to listen on")
	subscriberPort  = flag.Int("subscriber_port", 50312, "Port to listen for subscriber")
	bufferMutex     = &sync.Mutex{}
	logger          = log.New(os.Stdout, "tailchat: ", log.LstdFlags)
	subscribers     = make(map[net.Conn](chan struct{}))
	subscriberMutex = &sync.RWMutex{}
	cacheDir        string
	bufferFilePath  string
	networkMonitor  *NetworkMonitor
)

// Message passed among functions are without the trailing '\n'

func main() {
	godotenv.Load()
	flag.Parse()
	logger.Println("Starting the service")

    if *enableProfiling {
        go func() {
            logger.Println("Starting profiling server on :6060")
            logger.Println(http.ListenAndServe("localhost:6060", nil))
        }()
    }

	interrupt := make(chan os.Signal, 1)
	signal.Notify(interrupt, os.Interrupt)
	cacheDir = filepath.Join("/var", "lib", "tailchat", "tailchat")
	logger.Println("Cache dir is", cacheDir)
	if _, err := os.Stat(cacheDir); os.IsNotExist(err) {
		if err := os.MkdirAll(cacheDir, 0755); err != nil {
			logger.Println("Error creating cache directory: ", err)
			return
		}
	}
	bufferFilePath = filepath.Join(cacheDir, ".tailchat_buffer.json")

	listener, err := net.Listen("tcp", fmt.Sprintf(":%d", *port))
	if err != nil {
		logger.Fatalf("Error starting server: %v \n", err)
	}

	go func() {
		logger.Printf("Starting Server on port: %d \n", *port)
		for {
			conn, err := listener.Accept()
			if err != nil {
				logger.Printf("Error accepting connection %v \n", err)
				continue
			}
			go handleConnection(conn)
		}
	}()

	monitor, err := NewNetworkMonitor(func(info []NetworkInfo) {
		v, err := json.Marshal(info)
		if err != nil {
			logger.Println("Failed to marshal network info", err)
			return
		}
		message := fmt.Sprintf("NETWORK:%s", string(v))
		broadcastMessage(message)
	})
	if err != nil {
		logger.Fatalf("Warning: Failed to create network monitor: %v", err)
	} else {
		networkMonitor = monitor
		monitor.Start()
		defer monitor.Stop()
	}

	subscriberListener, err := net.Listen("tcp", fmt.Sprintf(":%d", *subscriberPort))
	if err != nil {
		logger.Fatalf("Error starting subscriber server: %v \n", err)
	}
	go func() {
		logger.Printf("Starting Subscriber Server on port: %d \n", *subscriberPort)
		for {
			conn, err := subscriberListener.Accept()
			if err != nil {
				logger.Printf("Error accepting subscriber connection %v \n", err)
				continue
			}
			go handleSubscriberConnection(conn)
		}
	}()

	<-interrupt
	logger.Println("Shutting down server...")
	if err := listener.Close(); err != nil {
		logger.Fatalf("Server Shutdown Failed:%+v", err)
	}
	if err := subscriberListener.Close(); err != nil {
		logger.Fatalf("Subscriber Server Shutdown Failed:%+v", err)
	}
	logger.Println("Server shutdown gracefully")

}

func handleConnection(conn net.Conn) {
	defer conn.Close()
	remote := conn.RemoteAddr()
	logger.Println("New client connected", remote)

	input := bufio.NewReaderSize(conn, fileBufferSize)
	output := bufio.NewWriter(conn)

	var err error
	var fullBuffer []byte
	readBuffer := make([]byte, fileBufferSize)
	logger.Println("Starting to message loop for connection", remote)
	for {
		m := bytes.IndexAny(fullBuffer, "\n")
		if m >= 0 {
			// Got one message. Handle the message.
			message := string(fullBuffer[:m])
			fullBuffer = fullBuffer[m+1:] // Skip the '\n'
			logger.Printf("m=%v len(fullBuffer)=%v\n", m, len(fullBuffer))
			parts := strings.Split(message, ":")
			if len(parts) < 2 {
				logger.Println("Invalid message format:", message)
				break
			}

			id := parts[1]
			fullBuffer, err = handleMessage(input, output, message, fullBuffer)
			if err != nil {
				logger.Println("Error handling message:", err)
				break
			}
			logger.Println("DONE handling one message:", message)
			if _, err := output.Write([]byte("ACK:" + id + ":DONE\n")); err != nil {
				logger.Println("Failed to write ACK:", err)
				break
			}
			output.Flush()
			continue
		}
		logger.Println("Reading from remote", remote, "...")
		n, err := input.Read(readBuffer)
		if err != nil {
			if err != io.EOF {
				logger.Printf("Error reading message: err=%v", err)
			} else {
				logger.Printf("EOF received. This is unexpected. err=%v", err)
			}
			break
		}
		if n <= 0 {
			// No error but no bytes read? Not expected.
			logger.Println("Empty read without error. Unexpected. Close.")
			break
		}
		fullBuffer = append(fullBuffer, readBuffer[:n]...)
	}
	logger.Printf("Done with client %v\n", remote)
}

func deleteSubscriber(conn net.Conn) {
	logger.Println("Deleting subscriber from", conn.RemoteAddr())
	subscriberMutex.Lock()
	delete(subscribers, conn)
	subscriberMutex.Unlock()
}

func handleSubscriberConnection(conn net.Conn) {
	defer conn.Close()
	remote := conn.RemoteAddr()
	logger.Println("New subscriber connected:", remote)

	if networkMonitor != nil {
		info := networkMonitor.GetCurrentInfo()
		v, err := json.Marshal(info)
		if err != nil {
			logger.Println("Failed to marshal network info", err)
			return
		}
		message := fmt.Sprintf("NETWORK:%s\n", string(v))
		if _, err := conn.Write([]byte(message)); err != nil {
			logger.Println("Error sending network info to new subscriber:", err)
			return
		}
	}

	if err := sendBufferedMessages(conn); err != nil {
		logger.Println("Closing subscriber connection", remote, "due to err:", err)
		return
	}

	stopCh := make(chan struct{})
	subscriberMutex.Lock()
	subscribers[conn] = stopCh
	subscriberMutex.Unlock()
	defer deleteSubscriber(conn)
	for {
		select {
		case <-stopCh:
			logger.Println("Stopping signal received. Closing", remote)
			return
		default:
			// Read from the connection with a timeout
			conn.SetReadDeadline(time.Now().Add(time.Second)) // Set a timeout to prevent blocking
			buf := make([]byte, 4096)
			n, err := conn.Read(buf)
			if err != nil {
				if neterr, ok := err.(net.Error); ok && neterr.Timeout() {
					continue // Timeout occurred, continue reading
				}
				logger.Printf("Error reading from subscriber %v: %v\n", remote, err)
				return
			}
			if n > 0 {
				logger.Printf("Received from %v: '%v'\n", remote, string(buf[:n]))
			}
		}
	}
}

const (
	fileStartPrefix = "FILE_START:"
)

func handleMessage(input *bufio.Reader, output *bufio.Writer, message string, fullBuffer []byte) ([]byte, error) {
	message = strings.TrimSuffix(message, "\n")
	logger.Println("Received message:", message)
	switch {
	case strings.HasPrefix(message, "TEXT:") || strings.HasPrefix(message, "CTRL:"):
		broadcastOrBufferMessage(message)
	case strings.HasPrefix(message, fileStartPrefix):
		return handleFileTransfer(input, output, message[len(fileStartPrefix):], fullBuffer)
	case strings.HasPrefix(message, "PING"):
		logger.Println("Got ping message")
		// TODO: respond with Pong
	default:
		logger.Printf("Unrecognized message type: '%v'\n", message)
	}
	return fullBuffer, nil
}

func handleFileTransfer(input *bufio.Reader, output *bufio.Writer, startMessage string, fullBuffer []byte) ([]byte, error) {
    if *enableProfiling {
        f, err := os.Create(filepath.Join(cacheDir, "cpu.prof"))
        if err != nil {
            logger.Printf("Could not create CPU profile: %v", err)
        } else {
            defer f.Close()
            if err := pprof.StartCPUProfile(f); err != nil {
                logger.Printf("Could not start CPU profile: %v", err)
            }
            defer pprof.StopCPUProfile()
        }
    }

	parts := strings.Split(startMessage, ":")
	if len(parts) != 3 {
		return nil, fmt.Errorf("invalid file start message format: %v", startMessage)
	}

	id := parts[0]
	fileName := parts[1]
	fileSize, err := strconv.ParseInt(parts[2], 10, 64)
	if err != nil {
		return nil, fmt.Errorf("invalid file size %v: %w", fileSize, err)
	}
	logger.Printf("File transfer name: %s size: %d \n", fileName, fileSize)

	filePath := filepath.Join(cacheDir, fileName)
	file, err := os.Create(filePath)
	if err != nil {
		return nil, fmt.Errorf("failed to create file %v: %w", filePath, err)
	}
	defer file.Close()

	var (
		extra    []byte
		received int64 = 0
		buffer         = make([]byte, fileBufferSize)
		writer = bufio.NewWriterSize(file, fileBufferSize)
	)
	defer writer.Flush()

	logger.Println("File created. Starting receiving file.")
	now := time.Now()
	start := now
	alreadyRead := len(fullBuffer)
	if int64(alreadyRead) >= fileSize {
		_, err = writer.Write(fullBuffer[:fileSize])
		if err != nil {
			return nil, fmt.Errorf("failed to write to file: %w", err)
		}
		return fullBuffer[int(fileSize):], nil
	}
	if alreadyRead > 0 {
		_, err = writer.Write(fullBuffer)
		if err != nil {
			return nil, fmt.Errorf("failed to write to file %w", err)
		}
		fullBuffer = nil
		received = int64(alreadyRead)
	}

	ack := time.Now().Add(ackInterval)
	for received < fileSize {
		//logger.Printf("Received=%v filesize=%v\n", received, fileSize)
		n, err := input.Read(buffer)
		if err != nil {
			if neterr, ok := err.(net.Error); ok && neterr.Timeout() {
				continue // Timeout occurred, continue reading
			}
			if err != io.EOF {
				return nil, fmt.Errorf("failed to read from socket: received=%v: %w", received, err)
			}
			if received < fileSize {
				return nil, fmt.Errorf("received EOF before finishing received=%v n=%v", received, n)
			}
			logger.Println("EOF received. Finish file receiving. n=", n)
			break
		}
		//logger.Println("Read:", n)
		now := time.Now()
		if now.After(ack) {
			ack = now.Add(ackInterval)
			if _, err := output.Write([]byte(fmt.Sprintf("ACK:%v:%v\n", id, received))); err != nil {
				return nil, fmt.Errorf("failed to write ack: %w", err)
			}
			logger.Printf("File received %d out of %d\n", received, fileSize)
			go output.Flush()
		}
		if int64(n)+received > fileSize {
			m := int(fileSize - received)
			extra = buffer[m:n]
			n = m
		}
		_, err = writer.Write(buffer[:n])
		if err != nil {
			return nil, fmt.Errorf("failed to write to file: %w", err)
		}
		received += int64(n)
		if received == fileSize {
			logger.Printf("File received all out of %d\n", fileSize)
			break
		} else {
			//logger.Printf("File received %d out of %d\n", received, fileSize)
		}
	}

	delta := time.Since(start).Milliseconds()
	logger.Printf("Completed file receiving in %v ms. Notify APP\n", delta)
	broadcastOrBufferMessage("FILE_END:" + id + ":" + filePath)
	return extra, nil
}

func broadcastMessage(message string) {
	if len(subscribers) <= 0 {
		return
	}
	logger.Println("There are subscribers. Broadcasting message", message)
	for conn, stopCh := range subscribers {
		_, err := conn.Write([]byte(message + "\n"))
		if err != nil {
			logger.Printf("Error writing to subscriber socket %v: %v\n", conn.RemoteAddr(), err)
			stopCh <- struct{}{}
			continue
		}
		logger.Println("Message sent to", conn.RemoteAddr())
	}

}

func broadcastOrBufferMessage(message string) {
	if len(subscribers) > 0 {
		broadcastMessage(message)
	} else {
		logger.Println("No subscriber, buffering message", message)
		bufferMutex.Lock()
		appendMessagesToBufferFileLocked([]string{message})
		bufferMutex.Unlock()
	}
}

func sendBufferedMessages(conn net.Conn) error {
	remote := conn.RemoteAddr()
	messages := loadBufferedMessages()
	var failedMessages []string
	for index, message := range messages {
		_, err := conn.Write([]byte(message + "\n"))
		if err != nil {
			logger.Printf("Error sending buffered message to %v: %v, message=%s\n", remote, err, message)
			failedMessages = messages[index:]
			break
		}
		logger.Println("Sending buffered message to", remote, message)
	}
	bufferMutex.Lock()
	defer bufferMutex.Unlock()
	clearBufferFileLocked()
	appendMessagesToBufferFileLocked(failedMessages)
	if len(failedMessages) > 0 {
		return fmt.Errorf("failed to send buffered messages to %v failed=%v", remote, len(failedMessages))
	}
	return nil
}

func loadBufferedMessages() []string {
	var messages []string
	_, err := os.Stat(bufferFilePath)
	if os.IsNotExist(err) {
		logger.Println("Buffered messages file not found")
		return messages
	}
	file, err := os.Open(bufferFilePath)
	if err != nil {
		logger.Println("Error opening buffered message file", err)
		return messages
	}
	defer file.Close()
	scanner := bufio.NewScanner(file)
	for scanner.Scan() {
		messages = append(messages, scanner.Text())
	}
	if err := scanner.Err(); err != nil {
		logger.Println("Error reading buffered messages file :", err)
		return []string{}
	}
	logger.Println("Buffered messages loaded successfully")
	return messages

}
func appendMessagesToBufferFileLocked(messages []string) {
	file, err := os.OpenFile(bufferFilePath, os.O_APPEND|os.O_CREATE|os.O_WRONLY, 0644)
	if err != nil {
		logger.Println("Error opening buffer file:", err)
		return
	}
	defer file.Close()
	for _, message := range messages {
		_, err = file.WriteString(message + "\n")
		if err != nil {
			logger.Println("Error writing to buffer file:", err)
		}
	}
	logger.Println("Buffered messages saved successfully")
}

func clearBufferFileLocked() {
	err := os.Truncate(bufferFilePath, 0)
	if err != nil {
		logger.Println("Error truncating buffered message file:", err)
		return
	}
	logger.Println("Buffered messages cleared")
}
