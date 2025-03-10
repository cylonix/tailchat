// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import Foundation
import Network
import UserNotifications

#if os(iOS)
    import Flutter
    import UIKit
#elseif os(macOS)
    import AppKit
    import FlutterMacOS
#endif

@available(macOS 10.15, iOS 13.0, *)
class ChatService: NSObject, NetworkMonitorDelegate {
    private var networkMonitor: NetworkMonitor?
    private let port: UInt16 = 50311 // Port to listen for messages
    private let subscriberPort: UInt16 = 50312 // Port to listen for subscribers
    private var listener: NWListener?
    private var subscriberListener: NWListener?
    private var isRunning = false
    private let isRunningLock = NSLock()
    private let logger = Logger(tag: "ChatService")
    private var eventSink: FlutterEventSink?
    private var chatMessageEventSink: FlutterEventSink?
    private var isServerStarting = false
    private let isServerStartingLock = NSLock()
    private var subscribers: [NWConnection] = []
    private let subscriberMutex = DispatchQueue(label: "io.cylonix.tailchat.subscriberMutex")
    private var connections: [NWConnection] = []
    private let connectionMutex = DispatchQueue(label: "io.cylonix.tailchat.connectionMutex")
    private var isShuttingDown: Bool = false
    private let shutdownLock = NSLock()
    private var isDeleted: Bool = false

    func startService() {
        logger.i("Starting service if not yet running.")
        if isDeleted {
            logger.e("Deleted and yet still running. This is messed up!")
            return
        }

        isRunningLock.lock()
        if isRunning {
            isRunningLock.unlock()
            logger.w("Service already running. Skip...")
            return
        }

        isRunning = true
        isRunningLock.unlock()
        logger.i("Service is not yet running. Starting it.")
        startNetworkMonitor()
        startServer()
    }

    #if os(iOS)
        private var apnToken: String?
        private var apnUUID: String?

        func setAPNToken(token: String, uuid: String) {
            apnToken = token
            apnUUID = uuid
            logger.i("Set APN token: \(token) with UUID: \(uuid)")

            broadcastAPNToken()
        }

        private func broadcastAPNToken() {
            sendApnInfo()
        }

        func handleIncomingConnection(fromPeerID: String) {
            logger.i("Handling incoming connection request from peer: \(fromPeerID)")
            // Handle connection request from push notification
        }

        deinit {
            isDeleted = true
            logger.i("Deinit. I am gone!")
        }
    #endif

    private func startNetworkMonitor() {
        networkMonitor = NetworkMonitor(delegate: self)
        networkMonitor?.start()
    }

    private func stopNetworkMonitor() {
        networkMonitor?.stop()
        networkMonitor = nil
    }

    private var localHostname: String?
    private let hostnameKey = "io.cylonix.tailchat.hostname"

    // Add after NetworkMonitorDelegate methods
    private func updateLocalHostname(devices: [Device]) {
        // Try to get saved hostname first
        if let saved = UserDefaults.standard.string(forKey: hostnameKey) {
            localHostname = saved
            logger.i("Using saved hostname: \(saved)")
            return
        }

        // Find our device in the network config
        if let device = devices.first(where: { device in
            device.isLocal
        }) {
            localHostname = device.hostname
            // Save for future use
            UserDefaults.standard.set(device.hostname, forKey: hostnameKey)
            logger.i("Set local hostname from network config: \(device.hostname)")
        } else {
            logger.w("Could not determine local hostname from network config")
        }
    }

    // MARK: - NetworkMonitorDelegate

    private var networkConfig: [Device]?
    func didUpdateNetworkConfig(devices: [Device]) {
        networkConfig = devices
        updateLocalHostname(devices: devices)
        updateNetworkConfig()
    }

    func didFailToUpdateNetwork(error: Error) {
        logger.e("Failed to update network configuration: \(error)")
        networkConfig = nil
        updateNetworkConfig()
    }

    private func updateNetworkConfig() {
        if let eventSink = eventSink {
            logger.d("Send network configuration: \(Logger.opt(networkConfig))")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.logger.d("Sending network configuration: \(Logger.opt(self.networkConfig))")
                let encoder = JSONEncoder()
                if let encodedDevices = try? encoder.encode(self.networkConfig),
                   let jsonString = String(data: encodedDevices, encoding: .utf8)
                {
                    eventSink(["type": "network_config", "devices": jsonString])
                } else {
                    self.logger.e("Failed to encode network configuration")
                }
            }
        } else {
            logger.i("EventSink is not available")
        }
    }

    // Long running service to listen for incoming connections and each connection
    // is handled in a separate queue and run in synchronous mode.
    private func startServer() {
        isServerStartingLock.lock()
        if isServerStarting {
            isServerStartingLock.unlock()
            logger.w("Server already started. Skip...")
            return
        }

        isServerStarting = true
        isServerStartingLock.unlock()

        logger.i("Sarting server")

        // Add listener state check before creating new ones
        if let existingListener = listener, existingListener.state == .ready,
           let existingSubscriberListener = subscriberListener, existingSubscriberListener.state == .ready
        {
            logger.i("Both listeners already in ready state")
            return
        }

        do {
            // Main listener setup
            let parameters = NWParameters.tcp
            parameters.allowLocalEndpointReuse = true

            // Add TCP settings trying to work around some problems on the ios
            // networking stake when connection is not cleanly closed due to
            // network connectivity issues.
            if let tcpOptions = parameters.defaultProtocolStack.internetProtocol as? NWProtocolTCP.Options {
                tcpOptions.keepaliveIdle = 5 // Start keepalive after 5 seconds of idle
                tcpOptions.keepaliveCount = 1 // Try 1 time
                tcpOptions.keepaliveInterval = 5 // 5 seconds between attempts
                tcpOptions.retransmitFinDrop = true
                tcpOptions.persistTimeout = 0 // this one reduces waiting time significantly when there is no open connections
                tcpOptions.enableKeepalive = true // this one reduces the number of open connections by reusing existing ones
                tcpOptions.connectionDropTime = 5
                tcpOptions.connectionTimeout = 5
                tcpOptions.noDelay = true
            }

            let content = NWEndpoint.Port(rawValue: port)!
            listener = try NWListener(using: parameters, on: content)
            listener?.stateUpdateHandler = handleStateUpdate
            listener?.newConnectionHandler = { [weak self] connection in
                let logger = Logger(tag: "ChatService")
                logger.i("New connection from \(connection.endpoint)")
                guard let self = self else { 
                    logger.e("Self is nil. Ignoring connection: \(connection.endpoint)")
                    connection.cancel()
                    return
                }
                let connectionQueue = DispatchQueue(label: "connectionQueue-\(connection.endpoint)")
                connectionQueue.async { [weak self] in
                    guard let self = self else {
                        logger.e("ConnectionQueue.async: Self is nil. Ignoring connection: \(connection.endpoint).")
                        connection.cancel()
                        return
                    }
                    self.handleConnection(connection: connection)
                }
            }

            listener?.start(queue: DispatchQueue.global(qos: .background))
            logger.i("Server listener started on port \(port)")

            // Subscriber listener setup
            let subscriberParameters = NWParameters.tcp
            subscriberParameters.allowLocalEndpointReuse = true

            let subscriberContent = NWEndpoint.Port(rawValue: subscriberPort)!
            subscriberListener = try NWListener(using: subscriberParameters, on: subscriberContent)
            subscriberListener?.stateUpdateHandler = handleSubscriberStateUpdate
            subscriberListener?.newConnectionHandler = { [weak self] connection in
                guard let self = self else { return }
                let connectionQueue = DispatchQueue(label: "subscriberConnectionQueue-\(connection.endpoint)")
                connectionQueue.async { [weak self] in
                    guard let self = self else {
                        Logger(tag: "ChatService").e("Self is nil. Ignoring subscriber connection: \(connection.endpoint).")
                        connection.cancel()
                        return
                    }
                    self.handleSubscriberConnection(connection: connection)
                }
            }

            subscriberListener?.start(queue: DispatchQueue.global(qos: .background))
            logger.i("Subscriber Server listener started on port \(subscriberPort)")

            // Check both listeners' states after a delay
            DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
                guard let self = self else { return }
                let listenerNotReady = self.listener?.state != .ready
                let subscriberNotReady = self.subscriberListener?.state != .ready

                if listenerNotReady {
                    self.logger.e("Main listener did not become ready within timeout period")
                }

                if subscriberNotReady {
                    self.logger.e("Subscriber listener did not become ready within timeout period")
                }

                if !listenerNotReady, !subscriberNotReady {
                    self.logger.i("Start success!")
                    self.restartCountLock.lock()
                    self.restartAttemptCount = 0
                    self.restartCountLock.unlock()
                    self.logger.i("Restart count reset to 0")
                    return
                }

                self.isRunningLock.lock()
                if self.isRunning {
                    self.logger.i("Restart server: main listener not ready \(listenerNotReady), subscriber listener not ready \(subscriberNotReady), is running \(self.isRunning)")
                    self.isRunningLock.unlock()
                    self.restartServer()
                } else {
                    self.isRunningLock.unlock()
                }

                self.logger.i("Finished listener not ready state handling.")
            }
        } catch { 
            logger.e("Failed to start listener servers: \(error). Restart...")
            restartServer()
        }

        isServerStartingLock.lock()
        isServerStarting = false
        isServerStartingLock.unlock()
        logger.i("Finished starting server.")
    }

    private func stopAndExit() {
        stopService()

        // Show critical notification to user
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let content = UNMutableNotificationContent()
            content.title = "Tailchat Service Error"
            content.body = "Failed to start chat service after \(self.maxRestartAttempts) attempts. Tailchat will now exit."
            content.sound = .default

            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0
            }

            let request = UNNotificationRequest(
                identifier: "service-failure-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.e("Failed to show service failure notification: \(error)")
                }
            }
        }

        // Force quit the app after a brief delay.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            guard let self = self else { return }
            self.logger.e("Failed to start chat service. Exiting App.")
            exit(1)
        }
    }

    private let maxRestartAttempts = 3
    private var restartAttemptCount = 0
    private let restartCountLock = NSLock()
    private let restartLock = NSLock()
    private var isServerRestarting: Bool = false
    func restartServer() { 
        restartLock.lock()
        if isServerRestarting {
            restartLock.unlock()
            logger.i("Server listener is already restarting. Skip.")
            return
        }
        isServerRestarting = true
        restartLock.unlock()
        logger.i("Restarting listener service")

        restartCountLock.lock()
        restartAttemptCount += 1
        let currentCount = restartAttemptCount
        restartCountLock.unlock()
        logger.i("Restart count \(currentCount)")

        if currentCount > maxRestartAttempts {
            logger.e("Maximum restart attempts (\(maxRestartAttempts)) reached. Stopping service and exit.")
            stopAndExit()
            return
        }

        logger.w("Attempting restart \(currentCount) of \(maxRestartAttempts)")
        logger.i("Stop listener service now and restart service in 2 seconds.")
        stopServer()

        // Increase delay and add network check before restart
        DispatchQueue.global().asyncAfter(deadline: .now() + 2) { [weak self] in
            guard let self = self else { return }
            self.logger.i("Restarting the listener service.")
            self.startServer()
            self.restartLock.lock()
            self.isServerRestarting = false
            self.restartLock.unlock()
            self.logger.i("Restarted the listener service")
        }
    }

    private func handleStateUpdate(state: NWListener.State) {
        switch state {
        case .setup:
            logger.i("Listener entering setup state")
        case let .waiting(error):
            logger.e("Listener waiting. Error: \(error.localizedDescription)")
            logger.e("Detailed error: \(String(describing: error))")
        case .ready:
            logger.i("Listener ready on port \(port)")
        case let .failed(error):
            logger.e("Listener failed. Error: \(error.localizedDescription)")
            logger.e("Listener network error code: \(error)")
            logger.e("Listener Detailed error: \(String(describing: error))")
            isRunningLock.lock()
            if isRunning {
                isRunningLock.unlock()
                restartServer()
            } else {
                isRunningLock.unlock()
            }
            logger.i("Finshed listener failed state handling.")
        case .cancelled:
            logger.i("Listener cancelled")
        @unknown default:
            logger.w("Unknown listener state: \(state)")
        }
    }

    // Subscriber connection cancel() is called when the connection is closed.
    // Subscriber is removed from the list when the connection is closed.
    // Service does not stop when subscriber connection is closed.
    private func handleSubscriberStateUpdate(state: NWListener.State) {
        switch state {
        case .setup:
            logger.i("Subscriber listener setup")
        case let .waiting(error):
            logger.e("Subscriber listener waiting with error: \(error)")
        case .ready:
            logger.i("Subscriber listener ready")
        case let .failed(error):
            logger.e("Subscriber listener failed with error: \(error)")
            isRunningLock.lock()
            if isRunning {
                isRunningLock.unlock()
                restartServer()
            } else {
                isRunningLock.unlock()
            }
            logger.i("Finished subscriber listener failed state handling.")
        case .cancelled:
            logger.i("Subscriber listener cancelled")
        default:
            break
        }
    }

    typealias MessageHandler = (NWConnection, String, inout Data) -> Error?
    private func handleConnection(connection: NWConnection) {
        logger.i("New connection received from \(connection.endpoint)")
        shutdownLock.lock()
        if isShuttingDown {
            shutdownLock.unlock()
            logger.i("Rejecting new connection during shutdown from \(connection.endpoint)")
            connection.cancel()
            return
        }
        shutdownLock.unlock()

        logger.i("Start handling connection $\(connection.endpoint)")

        connection.start(queue: DispatchQueue.global(qos: .background))
        connectionMutex.sync {
            connections.append(connection)
        }
        defer {
            logger.i("Connection from \(connection.endpoint) is now closed.")
            connectionMutex.sync {
                if let index = connections.firstIndex(where: { $0.endpoint == connection.endpoint }) {
                    connections.remove(at: index)
                }
            }
            connection.cancel()
        }
        #if os(iOS)
            if let uuid = apnUUID, let hostname = localHostname {
                _ = sendApnInfo(connection: connection, hostname: hostname, uuid: uuid)
            }
        #endif
        receiveMessages(connection: connection, messageHandler: handleMessage)
    }

    private func handleSubscriberConnection(connection: NWConnection) {
        shutdownLock.lock()
        if isShuttingDown {
            shutdownLock.unlock()
            logger.i("Rejecting new subscriber connection during shutdown from \(connection.endpoint)")
            connection.cancel()
            return
        }
        shutdownLock.unlock()
        logger.i("New subscriber connection received from \(connection.endpoint)")

        connection.start(queue: DispatchQueue.global(qos: .background))
        subscriberMutex.sync {
            subscribers.append(connection)
        }
        defer {
            subscriberMutex.sync {
                if let index = subscribers.firstIndex(where: { $0.endpoint == connection.endpoint }) {
                    subscribers.remove(at: index)
                }
            }
            logger.i("Subscriber disconnected \(connection.endpoint)")
            connection.cancel()
        }

        receiveMessages(connection: connection) { [weak self] _, message, _ in
            guard let self = self else { return nil }
            self.logger.d(
                "Received message from subscriber \(connection.endpoint): \(message)"
            )
            return nil
        }
    }

    private func preview(_ message: String) -> String {
        let previewLength = 300
        return message.count > previewLength
            ? message.prefix(previewLength) + "..."
            : message
    }

    private func setDefaultConnectionStateHandler(_ connection: NWConnection) {
        connection.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .preparing:
                self.logger.d("Connection preparing: \(connection.endpoint)")
            case .ready:
                self.logger.d("Connection ready: \(connection.endpoint)")
            case let .failed(error):
                self.logger.e("Connection failed: \(error)")
            case .cancelled:
                self.logger.d("Connection cancelled: \(connection.endpoint)")
            default:
                self.logger.e("Connection unknown state \(state): \(connection.endpoint)")
            }
        }
    }

    private func receiveMessages(connection: NWConnection, messageHandler: MessageHandler) {
        let readyGroup = DispatchGroup()
        readyGroup.enter()
        if connection.state == .ready {
            readyGroup.leave()
        } else {
            connection.stateUpdateHandler = { [weak self] state in
                guard let self = self else { return }
                switch state {
                case .preparing:
                    self.logger.d("[Pre-receive] Connection preparing: \(connection.endpoint)")
                case .ready:
                    self.logger.d("[Pre-receive] Connection ready: \(connection.endpoint)")
                    readyGroup.leave()
                case let .failed(error):
                    self.logger.e("[Pre-receive] Connection failed: \(error)")
                    readyGroup.leave()
                case .cancelled:
                    self.logger.d("[Pre-receive] Connection cancelled: \(connection.endpoint)")
                    readyGroup.leave()
                default:
                    self.logger.e("[Pre-receive] Connection unknown state \(state): \(connection.endpoint)")
                }
            }
        }

        // Wait for ready state with timeout
        let timeout = DispatchTime.now() + .seconds(5)
        switch readyGroup.wait(timeout: timeout) {
        case .success:
            setDefaultConnectionStateHandler(connection)
            if connection.state == .ready {
                receiveLoop(connection: connection, messageHandler: messageHandler)
            } else {
                logger.e("Connection not ready after state update")
                connection.cancel()
            }
        case .timedOut:
            setDefaultConnectionStateHandler(connection)
            logger.e("Connection ready timeout for \(connection.endpoint)")
            connection.cancel()
        }
    }

    private func receiveLoop(connection: NWConnection, messageHandler: MessageHandler) { 
        var fullBuffer = Data()
        while true {
            let semaphore = DispatchSemaphore(value: 0)
            var receivedData: Data?
            var receivedError: Error?
            var isComplete = false

            connection.receive(minimumIncompleteLength: 1, maximumLength: 4096) { data, _, complete, error in
                receivedData = data
                receivedError = error
                isComplete = complete
                semaphore.signal()
            }

            semaphore.wait()

            if let error = receivedError {
                logger.e("Connection \(connection.endpoint) receive error: \(error)")
                return
            }

            if let data = receivedData, !data.isEmpty {
                fullBuffer.append(data)
                while let messageIndex = fullBuffer.firstIndex(of: 10) {
                    let message = String(data: fullBuffer.subdata(in: 0 ..< messageIndex), encoding: .utf8)
                    fullBuffer = fullBuffer.subdata(in: messageIndex + 1 ..< fullBuffer.count)
                    if let message = message {
                        logger.d("received message length \(message.count): \(preview(message))")
                        if let error = messageHandler(connection, message, &fullBuffer) {
                            logger.e("Error processing message: \(Logger.opt(error))")
                            return
                        }
                    }
                }
            }
            if isComplete {
                logger.d("Connection \(connection.endpoint) Completed. Return.")
                return
            }
        }
    }

    private func handleMessage(connection: NWConnection, message: String, fullBuffer: inout Data) -> Error? {
        let message = message.trimmingCharacters(in: .whitespacesAndNewlines)
        let parts = message.components(separatedBy: ":")
        guard parts.count > 1 else {
            return NSError(
                domain: "ChatService", code: 1001,
                userInfo: [NSLocalizedDescriptionKey: "Invalid message format"]
            )
        }
        var error: Error?
        var shouldNotify = !isAppActive()
        switch parts[0] {
        case "CTRL":
            error = broadcastOrBufferMessage(message: message)
            shouldNotify = false
        case "TEXT":
            error = broadcastOrBufferMessage(message: message)
            if parts.count > 3, parts[2] == "SENDER" {
                shouldNotify = false
            }
        case "FILE_START":
            error = handleFileTransfer(connection: connection, message: message, fullBuffer: &fullBuffer)
        case "PING":
            logger.d("Received PING: \(message)")
            shouldNotify = false
        default:
            error = NSError(
                domain: "ChatService", code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized message type"]
            )
        }
        logger.d("DONE handling message error=\(Logger.opt(error))")
        if error == nil {
            if shouldNotify { 
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.showNotification(title: "New Message Received", body: "")
                }
            }
            error = sendAck(connection: connection, id: parts[1], status: "DONE")
        }
        return error
    }

    private var isAppActiveFlag: Bool = true
    private let stateLock = NSLock()

    // Add setter for app state
    func setAppActive(_ active: Bool) {
        stateLock.lock()
        isAppActiveFlag = active
        stateLock.unlock()
    }

    private func isAppActive() -> Bool {
        stateLock.lock()
        defer { stateLock.unlock() }
        return isAppActiveFlag
    }

    private func handleFileTransfer(connection: NWConnection, message: String, fullBuffer: inout Data) -> Error? {
        let parts = message.components(separatedBy: ":")
        guard parts.count == 4 else {
            return NSError(
                domain: "ChatService", code: 1003,
                userInfo: [NSLocalizedDescriptionKey: "Invalid file start message format: \(message) \(parts.count)"]
            )
        }

        let filename = parts[2]
        guard let fileSize = Int64(parts[3]) else {
            return NSError(
                domain: "ChatService", code: 1004,
                userInfo: [NSLocalizedDescriptionKey: "Invalid file size: \(parts[2])"]
            )
        }
        do {
            let docDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            let chatDir = docDir.appendingPathComponent("tailchat", isDirectory: true)

            try FileManager.default.createDirectory(at: chatDir, withIntermediateDirectories: true)

            let filePath = chatDir.appendingPathComponent(filename).path
            let fileURL = URL(fileURLWithPath: filePath)

            if FileManager.default.fileExists(atPath: filePath) {
                try FileManager.default.removeItem(at: fileURL)
            }
            FileManager.default.createFile(atPath: filePath, contents: nil)

            let fileHandle = try FileHandle(forWritingTo: fileURL)
            if let error = receiveFile(connection: connection, fileHandle: fileHandle, fileSize: fileSize, filePath: filePath, fullBuffer: &fullBuffer, id: parts[1]) {
                return error
            }
        } catch {
            logger.e("Error opening file: \(error)")
            return error
        }
        return nil
    }

    private let ackInterval: TimeInterval = 0.5 // 500ms
    private let fileBufferSize: Int = 1024 * 64
    private func receiveFile(
        connection: NWConnection, fileHandle: FileHandle, fileSize: Int64, filePath: String,
        fullBuffer: inout Data, id: String = ""
    ) -> Error? {
        var received: Int64 = 0
        // Consume data from fullBuffer first
        if !fullBuffer.isEmpty {
            do {
                let remainingBytes = fileSize - received
                var bytesToWrite = fullBuffer
                if Int64(fullBuffer.count) > remainingBytes {
                    bytesToWrite = fullBuffer.subdata(in: 0 ..< Int(remainingBytes))
                    fullBuffer = fullBuffer.subdata(in: Int(remainingBytes) ..< fullBuffer.count)
                } else {
                    fullBuffer.removeAll()
                }
                try fileHandle.seekToEnd()
                try fileHandle.write(contentsOf: bytesToWrite)
                received += Int64(bytesToWrite.count)
                if received >= fileSize {
                    try fileHandle.close()
                    logger.i("File transfer complete: \(filePath)")
                    return nil
                }
            } catch {
                logger.e("Error writing to file: \(error)")
                return error
            }
        }

        // Continue receiving data from connection
        let start = Date()
        var lastAckTime = Date()
        while received < fileSize {
            let semaphore = DispatchSemaphore(value: 0)
            var receivedData: Data?
            var receivedError: Error?
            var chunkComplete = false

            connection.receive(minimumIncompleteLength: 1, maximumLength: fileBufferSize) { data, _, complete, error in
                receivedData = data
                receivedError = error
                chunkComplete = complete
                semaphore.signal()
            }

            semaphore.wait()
            if let error = receivedError {
                return error
            }
            if let data = receivedData, !data.isEmpty {
                do {
                    var totalRead = received
                    var bytesToWrite = data
                    let remainingBytes = fileSize - totalRead
                    if Int64(data.count) > remainingBytes {
                        bytesToWrite = data.subdata(in: 0 ..< Int(remainingBytes))
                        fullBuffer.append(data.subdata(in: Int(remainingBytes) ..< data.count))
                    }
                    try fileHandle.seekToEnd()
                    try fileHandle.write(contentsOf: bytesToWrite)
                    totalRead += Int64(bytesToWrite.count)
                    received = totalRead
                    let now = Date()
                    if totalRead >= fileSize {
                        sendFileMessageUpdate(filePath: filePath, totalRead: fileSize, fileSize: fileSize, time: Int64(round(now.timeIntervalSince(start) * 1000)))
                        try fileHandle.close()
                        logger.i("File transfer complete: \(filePath)")
                        return nil
                    }
                    if chunkComplete {
                        return NSError(
                            domain: "ChatService", code: 1006,
                            userInfo: [NSLocalizedDescriptionKey: "Connection closed before file transfer is complete"]
                        )
                    }
                    if now.timeIntervalSince(lastAckTime) >= ackInterval {
                        lastAckTime = now
                        if let error = sendAck(connection: connection, id: id, status: "\(totalRead)") {
                            return error
                        }
                        sendFileMessageUpdate(filePath: filePath, totalRead: totalRead, fileSize: fileSize, time: Int64(round(now.timeIntervalSince(start) * 1000)))
                    }
                } catch {
                    logger.e("Error receiving file: \(error)")
                    return error
                }
            }
        }
        return nil
    }

    private func sendFileMessageUpdate(filePath: String, totalRead: Int64, fileSize: Int64, time: Int64) { 
        if let eventSink = eventSink {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                eventSink(
                    [
                        "type": "file_receive",
                        "file_path": filePath,
                        "total_read": totalRead,
                        "file_size": fileSize,
                        "time": time,
                    ]
                )
            }
        }
    }

    #if os(iOS)
        private func sendApnInfo() {
            if let eventSink = eventSink {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    eventSink(
                        [
                            "type": "pn_info",
                            "token": self.apnToken ?? "",
                            "uuid": self.apnUUID ?? "",
                        ]
                    )
                }
            }
        }
    #endif

    private func sendAck(connection: NWConnection, id: String, status: String) -> Error? {
        let ackMessage = "ACK:\(id):\(status)\n"
        let semaphore = DispatchSemaphore(value: 0)
        var receivedError: Error?

        connection.send(
            content: ackMessage.data(using: .utf8),
            completion: .contentProcessed { [weak self] sendError in
                guard let self = self else { return }
                if let sendError = sendError {
                    self.logger.e("Failed to send ACK: \(sendError)")
                    receivedError = sendError
                } else {
                    self.logger.d("ACK sent for id: \(id) with status: \(status)")
                }
                semaphore.signal()
            }
        )
        semaphore.wait()
        return receivedError
    }

    private func sendApnInfo(connection: NWConnection, hostname: String, uuid: String) -> Error? {
        let message = "TEXT:NULL_ID:PN_INFO:\(hostname) \(uuid)\n"
        let semaphore = DispatchSemaphore(value: 0)
        var receivedError: Error?

        connection.send(
            content: message.data(using: .utf8),
            completion: .contentProcessed { [weak self] sendError in
                guard let self = self else { return }
                if let sendError = sendError {
                    self.logger.e("Failed to send apn info: \(sendError)")
                    receivedError = sendError
                } else {
                    self.logger.d("APN info sent: \(hostname) \(uuid)")
                }
                semaphore.signal()
            }
        )
        semaphore.wait()
        return receivedError
    }

    private func showNotification(title: String, body: String) {
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let content = UNMutableNotificationContent()
            content.title = title
            content.body = body
            #if os(iOS)
                content.sound = .default
            #elseif os(macOS)
                content.sound = UNNotificationSound.default
            #endif

            let request = UNNotificationRequest(
                identifier: UUID().uuidString,
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.e("Error showing notification: \(error)")
                }
            }
        }
    }

    private func broadcastOrBufferMessage(message: String) -> Error? {
        if let eventSink = chatMessageEventSink {
            logger.i("UI app is running, sending message to eventSink: length \(message.count): \(preview(message))")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                eventSink(message)
            }
        } else {
            logger.i("UI app is not running, buffering message: length \(message.count): \(preview(message))")
            appendMessageToBufferFile(message: message + "\n")
        }
        return nil
    }

    private func removeSubscriber(connection: NWConnection) {
        subscriberMutex.sync {
            if let index = subscribers.firstIndex(where: { $0.endpoint == connection.endpoint }) {
                subscribers.remove(at: index)
            }
        }
    }

    private func sendMessageToSubscriber(connection: NWConnection, messageData: Data) {
        connection.send(
            content: messageData,
            completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.e(
                        "Error sending message to subscriber \(connection.endpoint), error \(error)")
                    self.removeSubscriber(connection: connection)
                }
            }
        )
        connection.send(
            content: Data("\n".utf8),
            completion: .contentProcessed { [weak self] error in
                guard let self = self else { return }
                if let error = error {
                    self.logger.e(
                        "Error sending new line to subscriber \(connection.endpoint), error \(error)")
                    self.removeSubscriber(connection: connection)
                }
            }
        )
    }

    private func appendMessageToBufferFile(message: String) {
        if let fileURL = getBufferFileURL() {
            do {
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    logger.i("Creating new buffer file at \(fileURL.path)")
                    FileManager.default.createFile(atPath: fileURL.path, contents: nil)
                }
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                try fileHandle.seekToEnd()
                if let data = message.data(using: .utf8) {
                    try fileHandle.write(contentsOf: data)
                    logger.d("Appended message to buffer file: \(preview(message))")
                }
                try fileHandle.close()
            } catch {
                logger.e("Error saving message to buffer file \(error)")
            }
        }
    }

    private func getBufferFileURL() -> URL? {
        let cacheDir = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
        return cacheDir.appendingPathComponent(".tailchat_buffer.json")
    }

    private func getBufferedMessages() -> [String] {
        guard let fileURL = getBufferFileURL() else {
            logger.e("Could not get buffer file URL")
            return []
        }

        // Check if file exists first
        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.i("No buffered messages file exists at \(fileURL.path)")
            return []
        }

        do {
            let data = try Data(contentsOf: fileURL)
            if let string = String(data: data, encoding: .utf8) {
                return string.components(separatedBy: "\n")
            }
        } catch { 
            logger.e("Error loading messages from buffer file: \(error)")
        }
        return []
    }

    private func sendBufferedMessages() {
        guard let eventSink = chatMessageEventSink else {
            logger.e("Chat message event sink is not available")
            return
        }

        guard let fileURL = getBufferFileURL() else {
            logger.e("Could not get buffer file URL")
            return
        }

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            logger.i("No buffered messages file exists at \(fileURL.path)")
            return
        }

        do {
            let messages = getBufferedMessages()
            for message in messages {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    eventSink(String(message))
                }
            }
            if let url = getBufferFileURL() {
                try FileManager.default.removeItem(at: url)
            }
        } catch {
            logger.e("Error sending buffered messages: \(error)")
        }
    }

    func stopService() {
        isRunningLock.lock()
        if !isRunning {
            isRunningLock.unlock()
            logger.w("Service already stopped. Skip...")
            return
        }

        isRunning = false
        isRunningLock.unlock()

        logger.i("Stopping service")
        stopNetworkMonitor()
        stopServer()
        logger.i("Service stopped")
    }

    private func stopServer() {
        logger.i("Stop server")
        shutdownLock.lock()
        if isShuttingDown {
            logger.i("Already shutting down. Skip...")
            shutdownLock.unlock()
            return
        }
        logger.d("Got isShuttingDown lock. Proceed to shutdown server.")
        isShuttingDown = true
        shutdownLock.unlock()

        logger.i("Stopping server...")

        // Close all main connections first
        connectionMutex.sync {
            for connection in connections {
                logger.d("Closing connection to \(connection.endpoint)")
                connection.forceCancel()
            }
            connections.removeAll()
        }

        // Close all subscriber connections
        subscriberMutex.sync {
            for connection in subscribers {
                logger.d("Closing subscriber connection to \(connection.endpoint)")
                connection.forceCancel()
            }
            subscribers.removeAll()
        }
        if let existingListener = listener {
            existingListener.cancel()
            // Wait briefly for cancellation to complete
            DispatchQueue.global().sync {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }

        if let existingSubscriberListener = subscriberListener {
            existingSubscriberListener.cancel()
            // Wait briefly for cancellation to complete
            DispatchQueue.global().sync {
                Thread.sleep(forTimeInterval: 0.1)
            }
        }
        listener = nil
        subscriberListener = nil

        // Reset shutdown flag
        shutdownLock.lock()
        isShuttingDown = false
        shutdownLock.unlock()

        logger.i("Server stopped")
    }

    func setEventSink(eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
        if eventSink != nil {
            logger.i("EventSink set")
            updateNetworkConfig()
            #if os(iOS)
                sendApnInfo()
            #endif
        } else {
            logger.i("EventSink unset")
        }
    }

    func setChatMessageSink(eventSink: FlutterEventSink?) {
        chatMessageEventSink = eventSink
        if eventSink != nil {
            logger.i("ChatMessageSink set")
            logger.i("Sending buffered messages")
            sendBufferedMessages()
        } else {
            logger.i("ChatMessageSink unset")
        }
    }
}
