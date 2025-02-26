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
    private let logger = Logger(tag: "ChatService")
    private var eventSink: FlutterEventSink?
    private var chatMessageEventSink: FlutterEventSink?
    private var isServerStarted = false
    private var subscribers: [NWConnection] = []
    private let subscriberMutex = DispatchQueue(label: "io.cylonix.tailchat.subscriberMutex")

    func startService() {
        logger.i("Starting service")
        if !isRunning {
            logger.i("Service is not yet running. Starting it.")
            isRunning = true
            startNetworkMonitor()
            startServer()
            #if os(iOS)
                registerForAppStateNotifications()
            #endif
        }
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

        private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
        private func registerForAppStateNotifications() {
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appDidEnterBackground),
                name: UIApplication.didEnterBackgroundNotification,
                object: nil
            )
            NotificationCenter.default.addObserver(
                self,
                selector: #selector(appWillEnterForeground),
                name: UIApplication.willEnterForegroundNotification,
                object: nil
            )
        }

        @objc private func appDidEnterBackground() {
            logger.i("App entered background")
            startBackgroundTask()
        }

        @objc private func appWillEnterForeground() {
            logger.i("App will enter foreground")
            endBackgroundTask()
        }

        private func startBackgroundTask() {
            let taskIdentifier = "io.cylonix.tailchat.chatServiceTask"
            backgroundTask = UIApplication.shared.beginBackgroundTask(
                withName: taskIdentifier
            ) { [weak self] in
                self?.endBackgroundTask()
            }

            // Schedule notification and task end after 30 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 20) { [weak self] in
                // Show notification 10 seconds before expiration
                self?.showBackgroundTaskExpirationNotification()
            }

            // Schedule task end after 30 seconds
            DispatchQueue.global().asyncAfter(deadline: .now() + 30) { [weak self] in
                self?.endBackgroundTask()
            }
        }

        private var notificationTimer: Timer?
        private func showBackgroundTaskExpirationNotification() {
            logger.i("Preparing to show background expiration notification")

            // Stop any existing notification timer
            notificationTimer?.invalidate()
            notificationTimer = nil
            if backgroundTask == .invalid || isAppActive() {
                logger.i("Background task is already invalid or App is active. Not showing notification.")
                return
            }

            // Create notification content
            let content = UNMutableNotificationContent()
            content.title = "Tailchat Service"
            content.subtitle = "Swipe down to show options"
            content.body = "Tailchat background receiving service will stop soon. Swipe down to continue or stop the service."
            content.sound = .default
            content.categoryIdentifier = "SERVICE_EXPIRING"

            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 1.0
            }

            let request = UNNotificationRequest(
                identifier: "service-expiring-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            // Schedule the notification
            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if let error = error {
                    self?.logger.e("Failed to schedule notification: \(error)")
                } else {
                    self?.logger.i("Background expiration notification scheduled successfully")

                    // Start repeating timer to show notification every 3 seconds
                    // Create timer on main queue
                    DispatchQueue.main.async {
                        self?.notificationTimer = Timer.scheduledTimer(
                            withTimeInterval: 5.0,
                            repeats: true
                        ) { [weak self] _ in
                            self?.logger.i("Timer fired - showing notification again")
                            self?.showBackgroundTaskExpirationNotification()
                        }

                        // Make sure timer runs in background
                        self?.notificationTimer?.tolerance = 0.1
                        RunLoop.current.add(self?.notificationTimer ?? Timer(), forMode: .common)
                    }
                }
            }
        }

        private func endBackgroundTask() {
            logger.i("Entering endBackgroundTask. Stopping timer.")
            // Stop notification timer
            notificationTimer?.invalidate()
            notificationTimer = nil

            // Remove any pending notifications
            UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

            if backgroundTask != .invalid {
                UIApplication.shared.endBackgroundTask(backgroundTask)
                backgroundTask = .invalid
            }
        }

    #endif

    private func startNetworkMonitor() {
        networkMonitor = NetworkMonitor(delegate: self)
        networkMonitor?.start()
    }

    // MARK: - NetworkMonitorDelegate

    private var networkConfig: [Device]?
    func didUpdateNetworkConfig(devices: [Device]) {
        networkConfig = devices
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
            DispatchQueue.main.async {
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

    private var authorizationStatus: Bool = false

    private func requestAuthorization() throws {
        if #available(iOS 14.0, *) {
            let localNetworkAuthorization = NWPathMonitor().currentPath.status
            switch localNetworkAuthorization {
            case .satisfied:
                authorizationStatus = true
                startServer()
            case .unsatisfied:
                logger.e("Local network access denied")
                throw NSError(domain: "ChatService", code: -65555)
            case .requiresConnection:
                logger.e("Network connection required")
                throw NSError(domain: "ChatService", code: -65555)
            @unknown default:
                break
            }
        } else {
            // Fallback for older iOS versions
            startServer()
        }
    }

    // Long running service to listen for incoming connections and each connection
    // is handled in a separate queue and run in synchronous mode.
    private func startServer() {
        if !isServerStarted {
            isServerStarted = true
            do {
                let parameters = NWParameters.tcp
                parameters.allowLocalEndpointReuse = true
                let content = NWEndpoint.Port(rawValue: port)!
                listener = try NWListener(using: parameters, on: content)
                listener?.stateUpdateHandler = handleStateUpdate
                listener?.newConnectionHandler = { [weak self] connection in
                    guard let self = self else { return }
                    let connectionQueue = DispatchQueue(label: "connectionQueue-\(connection.endpoint)")
                    connectionQueue.async {
                        self.handleConnection(connection: connection)
                    }
                }
                listener?.start(queue: DispatchQueue.global(qos: .background))
                logger.i("Server started on port \(port)")

                let subscriberParameters = NWParameters.tcp
                subscriberParameters.allowLocalEndpointReuse = true
                let subscriberContent = NWEndpoint.Port(rawValue: subscriberPort)!
                subscriberListener = try NWListener(using: subscriberParameters, on: subscriberContent)
                subscriberListener?.stateUpdateHandler = handleSubscriberStateUpdate
                subscriberListener?.newConnectionHandler = { [weak self] connection in
                    guard let self = self else { return }
                    let connectionQueue = DispatchQueue(label: "subscriberConnectionQueue-\(connection.endpoint)")
                    connectionQueue.async {
                        self.handleSubscriberConnection(connection: connection)
                    }
                }
                subscriberListener?.start(queue: DispatchQueue.global(qos: .background))
                logger.i("Subscriber Server started on port \(subscriberPort)")
            } catch {
                logger.e("Failed to start server: \(error)")
            }
        }
    }

    // Connection cancel() is called when the connection is closed.
    // Service does not stop when connection is closed.
    private func handleStateUpdate(state: NWListener.State) {
        switch state {
        case .setup:
            logger.i("Listener setup")
        case let .waiting(error):
            logger.e("Listener waiting with error: \(error)")
        case .ready:
            logger.i("Listener ready")
        case let .failed(error):
            logger.e("Listener failed with error: \(error)")
        case .cancelled:
            logger.i("Listener cancelled")
        default:
            break
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
        case .cancelled:
            logger.i("Subscriber listener cancelled")
        default:
            break
        }
    }

    typealias MessageHandler = (NWConnection, String, inout Data) -> Error?
    private func handleConnection(connection: NWConnection) {
        logger.i("New connection received from \(connection.endpoint)")
        connection.start(queue: DispatchQueue.global(qos: .background))
        defer {
            connection.cancel()
        }
        receiveMessages(connection: connection, messageHandler: handleMessage)
    }

    private func handleSubscriberConnection(connection: NWConnection) {
        logger.i("New subscriber connection received from \(connection.endpoint)")

        connection.start(queue: DispatchQueue.global(qos: .background))
        subscriberMutex.sync {
            subscribers.append(connection)
        }
        defer {
            self.subscriberMutex.sync {
                if let index = self.subscribers.firstIndex(where: { $0.endpoint == connection.endpoint }) {
                    self.subscribers.remove(at: index)
                }
            }
            self.logger.i("Subscriber disconnected \(connection.endpoint)")
            connection.cancel()
        }

        receiveMessages(connection: connection) { _, message, _ in
            self.logger.d(
                "Received message from subscriber \(connection.endpoint): \(message)"
            )
            return nil
        }
    }

    private func receiveMessages(connection: NWConnection, messageHandler: MessageHandler) {
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
                logger.e("Connection receive error: \(error)")
                return
            }

            if let data = receivedData, !data.isEmpty {
                fullBuffer.append(data)
                while let messageIndex = fullBuffer.firstIndex(of: 10) {
                    let message = String(data: fullBuffer.subdata(in: 0 ..< messageIndex), encoding: .utf8)
                    fullBuffer = fullBuffer.subdata(in: messageIndex + 1 ..< fullBuffer.count)
                    if let message = message {
                        logger.d("received message \(message)")
                        if let error = messageHandler(connection, message, &fullBuffer) {
                            logger.e("Error processing message: \(Logger.opt(error))")
                            return
                        }
                    }
                }
            }
            if isComplete {
                logger.d("Completed. Return.")
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
        switch parts[0] {
        case "CTRL":
            error = broadcastOrBufferMessage(message: message)
        case "TEXT":
            error = broadcastOrBufferMessage(message: message)
        case "FILE_START":
            error = handleFileTransfer(connection: connection, message: message, fullBuffer: &fullBuffer)
        case "PING":
            logger.d("Received PING: \(message)")
        default:
            error = NSError(
                domain: "ChatService", code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized message type"]
            )
        }
        logger.d("DONE handling message error=\(Logger.opt(error))")
        if error == nil {
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                let shouldNotify = !isAppActive()
                if shouldNotify {
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
                    if totalRead >= fileSize {
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
                    let now = Date()
                    if now.timeIntervalSince(lastAckTime) >= ackInterval {
                        lastAckTime = now
                        if let error = sendAck(connection: connection, id: id, status: "\(totalRead)") {
                            return error
                        }
                        sendFileMessageUpdate(filePath: filePath, totalRead: totalRead, fileSize: fileSize)
                    }
                } catch {
                    logger.e("Error receiving file: \(error)")
                    return error
                }
            }
        }
        return nil
    }

    private func sendFileMessageUpdate(filePath: String, totalRead: Int64, fileSize: Int64) {
        if let eventSink = eventSink {
            DispatchQueue.main.async {
                eventSink(
                    [
                        "type": "file_receive",
                        "file_path": filePath,
                        "total_read": totalRead,
                        "file_size": fileSize,
                    ]
                )
            }
        }
    }

    #if os(iOS)
        private func sendApnInfo() {
            if let eventSink = eventSink {
                DispatchQueue.main.async {
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
            completion: .contentProcessed { sendError in
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

    private func showNotification(title: String, body: String) {
        DispatchQueue.main.async {
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

            UNUserNotificationCenter.current().add(request) { error in
                if let error = error {
                    self.logger.e("Error showing notification: \(error)")
                }
            }
        }
    }

    private func broadcastOrBufferMessage(message: String) -> Error? {
        if let eventSink = chatMessageEventSink {
            logger.i("UI app is running, sending message to eventSink: \(message)")
            DispatchQueue.main.async {
                eventSink(message)
            }
        } else {
            logger.i("UI app is not running, buffering message \(message)")
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
            completion: .contentProcessed { error in
                if let error = error {
                    self.logger.e(
                        "Error sending message to subscriber \(connection.endpoint), error \(error)")
                    self.removeSubscriber(connection: connection)
                }
            }
        )
        connection.send(
            content: Data("\n".utf8),
            completion: .contentProcessed { error in
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
                let fileHandle = try FileHandle(forWritingTo: fileURL)
                try fileHandle.seekToEnd()
                if let data = message.data(using: .utf8) {
                    try fileHandle.write(contentsOf: data)
                    logger.d("Appended message \(message) to buffer file ")
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
        if let fileURL = getBufferFileURL() {
            do {
                let data = try Data(contentsOf: fileURL)
                if let string = String(data: data, encoding: .utf8) {
                    return string.components(separatedBy: "\n")
                }
            } catch {
                logger.e("Error loading messages from file \(error)")
            }
        }
        return []
    }

    private func sendBufferedMessages() {
        guard let eventSink = chatMessageEventSink else {
            logger.e("Chat message event sink is not available")
            return
        }

        do {
            let messages = getBufferedMessages()
            for message in messages {
                DispatchQueue.main.async {
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
        #if os(iOS)
            endBackgroundTask()
        #endif
        listener?.cancel()
        subscriberListener?.cancel()
        isRunning = false
        isServerStarted = false
        subscribers.removeAll()
        logger.i("Service stopped")
        eventSink = nil
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
