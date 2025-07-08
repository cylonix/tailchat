// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import Darwin
import Darwin.POSIX.net
import Darwin.POSIX.netinet
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
    @Atomic private var isRunning = false
    private let logger = Logger(tag: "ChatService")
    private var eventSink: FlutterEventSink?
    private var chatMessageEventSink: FlutterEventSink?
    private var isServerStarting = false
    private var subscribers: [NWConnection] = []
    private let subscriberMutex = DispatchQueue(label: "io.cylonix.tailchat.subscriberMutex")
    private var connections: [NWConnection] = []
    private let connectionMutex = DispatchQueue(label: "io.cylonix.tailchat.connectionMutex")
    private var isShuttingDown: Bool = false
    private let startServerLock = NSLock()
    private let stopServerLock = NSLock()
    private let startStopServerLock = NSLock()
    private var isDeleted: Bool = false
    private var isNetworkAvailable = false
    private var stateCheckWorkItem: DispatchWorkItem?

    private var mainSockfd: Int32 = -1
    private var subSockfd: Int32 = -1

    static let appGroup = "group.io.cylonix.sase.ios"
    static let cylonixServiceKey = "tailchat_service_enabled"
    public static var isCylonixServiceActive: Bool {
        guard let userDefaults = UserDefaults(suiteName: appGroup) else {
            Logger(tag: "ChatService").w("Could not access app group: \(appGroup)")
            return false
        }
        let state = userDefaults.bool(forKey: Self.cylonixServiceKey)
        Logger(tag: "ChatService").i("Cylonix service state: \(state)")
        return state
    }

    public static var cylonixSharedFolderPath: String? {
        let fileManager = FileManager.default
        guard let sharedContainerURL = fileManager.containerURL(forSecurityApplicationGroupIdentifier: Self.appGroup) else {
            Logger(tag: "ChatService").e("Failed to get shared container URL")
            return nil
        }
        let sharedFolderPath = sharedContainerURL.appendingPathComponent("tailchat").path
        Logger(tag: "ChatService").i("Cylonix shared folder path: \(sharedFolderPath)")
        return sharedFolderPath
    }

    func startService() {
        logger.i("Starting service if not yet running.")
        if isDeleted {
            logger.e("Deleted and yet still running. This is messed up!")
            return
        }

        if isRunning {
            logger.w("Service already running. Skip...")
            return
        }
        isRunning = true

        let monitor = NWPathMonitor()
        monitor.pathUpdateHandler = { path in
            let interfaces = path.availableInterfaces.map { $0.name }
            let isVpnActive = interfaces.contains { $0.starts(with: "utun") }
            if !isVpnActive {
                let allInterfaces = self.getAllInterfaces()
                self.logger.i("""
                Network Path Status: \(path.status)
                Expensive: \(path.isExpensive)
                Constrained: \(path.isConstrained)

                Available Interfaces:
                \(interfaces.joined(separator: "\n----\n"))

                All System Interfaces:
                \(allInterfaces)
                """)
            }
            self.logger.i("Path: \(path.status), VPN active: \(isVpnActive), Interfaces: \(interfaces) at \(Date())")
        }

        monitor.start(queue: .global())

        logger.i("Service is not yet running. Starting it.")
        startNetworkMonitor()
        startServer()
    }

    private func getAllInterfaces() -> String {
        var interfaceList: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&interfaceList) == 0 else {
            logger.e("Failed to get interface list")
            return "Failed to get interfaces"
        }
        defer { freeifaddrs(interfaceList) }

        var interfaces: [String] = []
        var current = interfaceList

        while let interface = current {
            let name = String(cString: interface.pointee.ifa_name)
            let flags = interface.pointee.ifa_flags
            let isUp = (flags & UInt32(IFF_UP)) != 0
            let isRunning = (flags & UInt32(IFF_RUNNING)) != 0

            if let addr = interface.pointee.ifa_addr {
                let family = addr.pointee.sa_family
                var ipAddress = "unknown"

                if family == UInt8(AF_INET) {
                    var hostname = [CChar](repeating: 0, count: Int(NI_MAXHOST))
                    let success = getnameinfo(addr, socklen_t(addr.pointee.sa_len),
                                              &hostname, socklen_t(hostname.count),
                                              nil, 0, NI_NUMERICHOST)
                    if success == 0 {
                        ipAddress = String(cString: hostname)
                    }
                }

                let info = """
                Interface: \(name)
                Status: \(isUp ? "UP" : "DOWN")/\(isRunning ? "RUNNING" : "NOT RUNNING")
                Address: \(ipAddress)
                Family: \(family)
                """
                interfaces.append(info)
            }

            current = interface.pointee.ifa_next
        }

        return interfaces.joined(separator: "\n----\n")
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

    // Restarting listeners base on network availability does not work as
    // expected. Will do more investigation and experiments to decide the
    // best path forward.
    private func startNetworkMonitor() {
        networkMonitor = NetworkMonitor(delegate: self)
        networkMonitor?.onNetworkStatusChange = { [weak self] isAvailable in
            guard let self = self else { return }
            self.logger.i("Network availability changed: \(isAvailable)")
            if isAvailable, self.isRunning {
                self.isNetworkAvailable = true
                self.logger.i("Network became available.")
                self.updateNetworkAvailable()
                // self.restartServer()
            } else {
                self.isNetworkAvailable = false
                self.logger.i("Network became unavailable.")
                self.updateNetworkAvailable()
                // self.stopServer()
            }
        }
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

    private func updateNetworkAvailable() {
        if let eventSink = eventSink {
            logger.d("Send network available state: \(Logger.opt(isNetworkAvailable))")
            DispatchQueue.main.async { [weak self] in
                guard let self = self else { return }
                self.logger.d("Sending network available state: \(Logger.opt(self.isNetworkAvailable))")
                eventSink(["type": "network_available", "available": self.isNetworkAvailable])
            }
        } else {
            logger.i("EventSink is not available")
        }
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

    // POSIX-based startServer with blocking sockets
    private var mainAcceptThread: Thread?
    private var subAcceptThread: Thread?
    private var activeConnections: [Int32: Thread] = [:] // Track clientfd -> thread
    private let connectionLock = NSLock() // Thread safety
    func startServerPosix() {
        logger.i("Starting POSIX server listeners with blocking sockets")

        mainSockfd = startPosixListener(port: port)
        guard mainSockfd >= 0 else {
            logger.e("Failed to start main POSIX listener on port \(port)")
            return
        }

        subSockfd = startPosixListener(port: subscriberPort)
        guard subSockfd >= 0 else {
            logger.e("Failed to start subscriber POSIX listener on port \(subscriberPort)")
            close(mainSockfd)
            return
        }

        // Start dedicated threads for accepting connections
        mainAcceptThread = Thread { [weak self] in
            self?.acceptConnectionsPosix(sockfd: self!.mainSockfd, isMain: true)
        }
        mainAcceptThread?.name = "MainAcceptThread"
        mainAcceptThread?.start()

        subAcceptThread = Thread { [weak self] in
            self?.acceptConnectionsPosix(sockfd: self!.subSockfd, isMain: false)
        }
        subAcceptThread?.name = "SubAcceptThread"
        subAcceptThread?.start()

        logger.i("POSIX listeners started on ports \(port) and \(subscriberPort) with dedicated threads at \(Date())")
    }

    private func startPosixListener(port: UInt16) -> Int32 {
        let sockfd = socket(AF_INET, SOCK_STREAM, 0)
        guard sockfd >= 0 else {
            logger.e("Failed to create POSIX socket for port \(port): \(errno)")
            return -1
        }

        var reuse: Int32 = 1
        setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

        var addr = sockaddr_in(
            sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
            sin_family: sa_family_t(AF_INET),
            sin_port: in_port_t(port).bigEndian,
            sin_addr: in_addr(s_addr: INADDR_ANY),
            sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
        )
        let bindResult = withUnsafePointer(to: &addr) {
            Darwin.bind(sockfd, UnsafeRawPointer($0).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
        }
        guard bindResult == 0 else {
            logger.e("Failed to bind POSIX socket on port \(port): \(errno)")
            close(sockfd)
            return -1
        }

        let listenResult = listen(sockfd, 5)
        guard listenResult == 0 else {
            logger.e("Failed to POSIX listen on port \(port): \(errno)")
            close(sockfd)
            return -1
        }

        logger.i("POSIX listener bound and listening on port \(port), fd=\(sockfd) at \(Date())")
        return sockfd
    }

    // POSIX blocking connection handling
    private func acceptConnectionsPosix(sockfd: Int32, isMain: Bool) {
        Thread.current.name = isMain ? "MainAccept-\(sockfd)" : "SubAccept-\(sockfd)"
        logger.i("Starting POSIX accept loop on port \(isMain ? port : subscriberPort), thread: \(Thread.current.name ?? "unnamed")")

        while isRunning {
            var clientAddr = sockaddr()
            var addrLen = socklen_t(MemoryLayout<sockaddr>.size)
            let clientfd = accept(sockfd, &clientAddr, &addrLen)
            guard clientfd >= 0 else {
                if errno != EINTR {
                    logger.e("Accept failed on POSIX port \(isMain ? port : subscriberPort): \(errno)")
                }
                continue
            }

            // Extract remote address
            let remoteAddress = withUnsafePointer(to: &clientAddr) { ptr -> String in
                var sockaddrIn = ptr.withMemoryRebound(to: sockaddr_in.self, capacity: 1) { $0.pointee }
                var ipString = [CChar](repeating: 0, count: Int(INET_ADDRSTRLEN))
                guard let ip = inet_ntop(AF_INET, &sockaddrIn.sin_addr, &ipString, socklen_t(INET_ADDRSTRLEN)) else {
                    return "Unknown IP"
                }
                let port = CFSwapInt16BigToHost(sockaddrIn.sin_port)
                return "\(String(cString: ip)):\(port)"
            }

            logger.i("Accepted POSIX connection from \(remoteAddress) on port \(isMain ? port : subscriberPort), clientfd=\(clientfd) at \(Date())")

            // Spawn a dedicated thread for this connection
            let connectionThread = Thread { [weak self] in
                self?.handleConnectionPosix(clientfd: clientfd, isMain: isMain)
                self?.connectionLock.lock()
                if let thread = self?.activeConnections[clientfd] {
                    if !thread.isCancelled {
                        self?.logger.i("Closed POSIX clientfd \(clientfd) for port \(isMain ? self!.port : self!.subscriberPort)")
                        close(clientfd)
                        thread.cancel()
                    }
                    self?.activeConnections.removeValue(forKey: clientfd)
                }
                self?.connectionLock.unlock()
            }
            connectionThread.name = "Conn-\(clientfd)"
            connectionLock.lock()
            activeConnections[clientfd] = connectionThread
            connectionLock.unlock()
            connectionThread.start()
        }
        logger.i("Stopped accepting POSIX connections on port \(isMain ? port : subscriberPort)")
    }

    private func handleConnectionPosix(clientfd: Int32, isMain: Bool) {
        Thread.current.name = "Handle-\(clientfd)"
        logger.i("Handling POSIX connection on clientfd \(clientfd), thread: \(Thread.current.name ?? "unnamed")")
        #if os(iOS)
            if let uuid = apnUUID, let hostname = localHostname {
                sendApnInfoPosix(clientfd: clientfd, hostname: hostname, uuid: uuid)
            }
        #endif
        receiveMessagesPosix(clientfd: clientfd, isMain: isMain)
        logger.i("DONE handling POSIX connection on clientfd \(clientfd), thread: \(Thread.current.name ?? "unnamed")")
    }

    // POSIX receive messages
    private func receiveMessagesPosix(clientfd: Int32, isMain _: Bool) {
        logger.d("Receive messages from POSIX connection")
        var fullBuffer = Data()
        var buffer = [UInt8](repeating: 0, count: 16 * 1024)
        while isRunning {
            let bytesRead = recv(clientfd, &buffer, buffer.count, 0)
            switch bytesRead {
            case -1:
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    logger.i("POSIX connection stopped.")
                    return
                }
                logger.e("Error reading from POSIX clientfd \(clientfd): \(errno)")
                return

            case 0:
                logger.i("Client disconnectd on POSIX clientfd \(clientfd)")
                return

            default:
                let data = Data(buffer[0 ..< bytesRead])
                fullBuffer.append(data)
                while let messageIndex = fullBuffer.firstIndex(of: 10) {
                    let message = String(data: fullBuffer.subdata(in: 0 ..< messageIndex), encoding: .utf8)
                    fullBuffer = fullBuffer.subdata(in: messageIndex + 1 ..< fullBuffer.count)
                    if let message = message {
                        logger.d("POSIX received message length \(message.count): \(preview(message))")
                        if let error = handleMessagePosix(clientfd: clientfd, message: message, fullBuffer: &fullBuffer) {
                            logger.e("POSIX Error processing message: \(Logger.opt(error))")
                            return
                        }
                    }
                }
            }
        }
    }

    private func handleMessagePosix(clientfd: Int32, message: String, fullBuffer: inout Data) -> Error? {
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
            error = handleFileTransferPosix(clientfd: clientfd, message: message, fullBuffer: &fullBuffer)
        case "PING":
            logger.d("Received PING: \(message)")
            shouldNotify = false
        default:
            error = NSError(
                domain: "ChatService", code: 1002,
                userInfo: [NSLocalizedDescriptionKey: "Unrecognized message type"]
            )
        }
        logger.d("POSIX DONE handling message error=\(Logger.opt(error))")
        if error == nil {
            if shouldNotify {
                DispatchQueue.main.async { [weak self] in
                    guard let self = self else { return }
                    self.showNotification(title: "New Message Received", body: "")
                }
            }
            sendAckPosix(clientfd: clientfd, id: parts[1], status: "DONE")
        }
        return error
    }

    private func handleFileTransferPosix(clientfd: Int32, message: String, fullBuffer: inout Data) -> Error? {
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
            if let error = receiveFilePosix(clientfd: clientfd, fileHandle: fileHandle, fileSize: fileSize, filePath: filePath, fullBuffer: &fullBuffer, id: parts[1]) {
                return error
            }
        } catch {
            logger.e("Error opening file: \(error)")
            return error
        }
        return nil
    }

    private func receiveFilePosix(
        clientfd: Int32, fileHandle: FileHandle, fileSize: Int64, filePath: String,
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
        var buffer = [UInt8](repeating: 0, count: 64 * 1024)
        while received < fileSize {
            let bytesRead = recv(clientfd, &buffer, buffer.count, 0)
            switch bytesRead {
            case -1:
                if errno == EAGAIN || errno == EWOULDBLOCK {
                    // Should we continue to try?
                    continue
                }
                logger.e("Error reading from clientfd \(clientfd): \(errno)")
                return NSError(
                    domain: "ChatService", code: 1006,
                    userInfo: [NSLocalizedDescriptionKey: "Connection closed before file transfer is complete"]
                )

            case 0:
                logger.i("Client disconnected on clientfd \(clientfd)")
                return NSError(
                    domain: "ChatService", code: 1006,
                    userInfo: [NSLocalizedDescriptionKey: "Connection closed before file transfer is complete"]
                )

            default:
                let data = Data(buffer[0 ..< bytesRead])
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
                    if now.timeIntervalSince(lastAckTime) >= ackInterval {
                        lastAckTime = now
                        sendAckPosix(clientfd: clientfd, id: id, status: "\(totalRead)")
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

    // POSIX sendAck
    private func sendAckPosix(clientfd: Int32, id: String, status: String) {
        let message = "ACK:\(id):\(status)\n"
        let data = message.utf8CString
        data.withUnsafeBufferPointer { ptr in
            let bytesSent = send(clientfd, ptr.baseAddress, data.count - 1, 0)
            if bytesSent < 0 {
                logger.e("Failed to send POSIX ACK on clientfd \(clientfd): \(errno)")
                close(clientfd)
            } else {
                logger.i("Sent POSIX ACK: \(message)")
            }
        }
    }

    // POSIX sendApnInfo
    private func sendApnInfoPosix(clientfd: Int32, hostname: String, uuid: String) {
        let message = "TEXT:NULL_ID:PN_INFO:\(hostname) \(uuid)\n"
        let apnInfo = message.utf8CString
        apnInfo.withUnsafeBufferPointer { ptr in
            let bytesSent = send(clientfd, ptr.baseAddress, apnInfo.count - 1, 0)
            if bytesSent < 0 {
                logger.e("Failed to send POSIX APN info on clientfd \(clientfd): \(errno)")
                close(clientfd)
            } else {
                logger.i("Sent POSIX APN info")
            }
        }
    }

    func stopServerPosix() {
        logger.i("Stopping POSIX server listeners")
        if mainSockfd >= 0 {
            close(mainSockfd)
            mainSockfd = -1
            logger.i("Closed main POSIX listener on port \(port)")
        }
        if subSockfd >= 0 {
            close(subSockfd)
            subSockfd = -1
            logger.i("Closed subscriber POSIX listener on port \(subscriberPort)")
        }
        // Terminate active connection threads
        connectionLock.lock()
        for (clientfd, thread) in activeConnections {
            if !thread.isCancelled {
                close(clientfd) // Unblock recv()
                thread.cancel() // Mark for termination
                logger.i("Requested termination of thread for POSIX clientfd \(clientfd)")
            }
        }
        activeConnections.removeAll()
        connectionLock.unlock()
        mainAcceptThread?.cancel()
        subAcceptThread?.cancel()
    }

    // Long running service to listen for incoming connections and each connection
    // is handled in a separate queue and run in synchronous mode.
    private func startServer() {
        if !startServerLock.try() {
            logger.w("Server already being started. Skip...")
            return
        }
        defer {
            logger.d("Relaseing startServer lock")
            startServerLock.unlock()
        }
        isServerStarting = true
        logger.i("Start server lock acquired")

        // Wait for ongoing shutdown to finish if any.
        startStopServerLock.lock()
        defer {
            isServerStarting = false
            logger.d("Releasing startStopServer lock")
            startStopServerLock.unlock()
        }

        logger.i("Start-stop server lock acquired. Starting server")
        // Check if Cylonix app is handling the service
        if Self.isCylonixServiceActive {
            logger.i("Cylonix app is already providing tailchat service. Skip starting listeners.")
            return
        }
        #if os(iOS)
            startServerPosix()
            logger.i("Finished starting server.")
            return
        #endif

        // Retarting listeners base on network availability does not work as
        // expected. Will do more investigation and experiments to decide the
        // best path forward.
        /* if !isNetworkAvailable {
             logger.i("Network is not yet available. Wait for network status change to start server.")
             return
         } */

        // Add listener state check before creating new ones
        if let existingListener = listener, existingListener.state == .ready,
           let existingSubscriberListener = subscriberListener, existingSubscriberListener.state == .ready
        {
            logger.i("Both listeners already in ready state")
            return
        }

        // Cancel existing work item if any
        stateCheckWorkItem?.cancel()

        // Create new work item for state check
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            self.logger.i("[StateCheck] Checking listener states after delay")
            self.restartServerIfNecessary()
        }

        stateCheckWorkItem = workItem

        do {
            logger.i("Testing POSIX socket binding on port \(port)")
            let posixSuccess = testRawSocketBinding(port: port, logger: logger)
            logger.i("POSIX test result for port \(port): \(posixSuccess)")

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
            logger.i("Setting state handler for main listener")
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
            logger.i("Server listener started on port \(port) \(Date())")
            if let error = listener?.debugDescription.range(of: "error") {
                logger.e("Debug hint of error in listener: \(listener?.debugDescription ?? "nil")")
            }

            if let state = listener?.state {
                logger.i("Manual state check post-start: \(state) at \(Date())")
            }

            if listener?.stateUpdateHandler != nil {
                logger.i("Main listener handler is set at \(Date())")
            } else {
                logger.e("Main listener handler is nil post-start!")
            }

            // Subscriber listener setup...
            logger.i("Testing POSIX socket binding on port \(subscriberPort)")
            let subscriberPosixSuccess = testRawSocketBinding(port: subscriberPort, logger: logger)
            logger.i("POSIX test result for port \(subscriberPort): \(subscriberPosixSuccess)")

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

            // Schedule the check
            DispatchQueue.global().asyncAfter(deadline: .now() + 10, execute: workItem)
            logger.i("[StateCheck] Scheduled state check work item")
        } catch {
            logger.e("Failed to start listener servers: \(error). Retry in two seconds...")
            DispatchQueue.global().asyncAfter(deadline: .now() + 2, execute: workItem)
        }

        logger.i("Finished starting server.")
    }

    private func restartServerIfNecessary() {
        let listenerReady = listener?.state == .ready
        let subscriberReady = subscriberListener?.state == .ready

        if !listenerReady {
            logger.e("Main listener is not ready state=\(listener?.state)")
        }

        if !subscriberReady {
            logger.e("Subscriber listener is not ready state=\(subscriberListener?.state)")
        }

        if listenerReady, subscriberReady {
            logger.i("Start success!")
            stateCheckWorkItem?.cancel()
            stateCheckWorkItem = nil
            restartCountLock.lock()
            restartAttemptCount = 0
            restartCountLock.unlock()
            logger.i("Restart count reset to 0")
            return
        }

        if isRunning {
            logger.i("Restart server: main listener ready \(listenerReady), subscriber listener ready \(subscriberReady), is running \(isRunning)")
            restartServer()
        }
    }

    private func stopAndExit() {
        stopService()

        // Show critical notification to user
        DispatchQueue.main.async { [weak self] in
            guard let self = self else { return }
            let content = UNMutableNotificationContent()
            content.title = "Tailchat Service Error"
            content.body = "Tailchat will now exit due to error."
            content.sound = .default

            if #available(iOS 15.0, macOS 12.0, *) {
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
            self.logger.e("Failed to start or stop chat service. Exiting App.")
            // exit(0)
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
            logger.i("[Restart] Server listener is already restarting. Skip.")
            return
        }
        isServerRestarting = true
        restartLock.unlock()
        logger.i("[Restart] Restarting listener service")

        restartCountLock.lock()
        restartAttemptCount += 1
        let currentCount = restartAttemptCount
        restartCountLock.unlock()
        logger.i("[Restart] Restart count \(currentCount)")

        if currentCount > maxRestartAttempts {
            logger.e("[Restart] Maximum restart attempts (\(maxRestartAttempts)) reached. Stopping service and exit.")
            stopAndExit()
            return
        }

        logger.i("[Restart] Stop listener service first")
        stopServer()

        logger.i("[Restart] Server stopped. Scheduling delayed start at \(Date())")
        logger.i("[Restart] Current thread: \(Thread.current), isMain: \(Thread.isMainThread)")
        let startTime = Date()

        let workItem = DispatchWorkItem { [weak self] in
            let executionTime = Date()
            let logger = Logger(tag: "ChatService")
            logger.i("[Restart] Delayed block executing at \(executionTime)")
            logger.i("[Restart] Execution thread: \(Thread.current), isMain: \(Thread.isMainThread)")

            guard let self = self else {
                logger.i("[Restart] Self is nil. Skip restarting.")
                return
            }

            self.logger.i("[Restart] Starting server on thread: \(Thread.current)")
            self.startServer()
            self.restartLock.lock()
            self.isServerRestarting = false
            self.restartLock.unlock()
            let completionTime = Date()
            self.logger.i("[Restart] Restart sequence completed at \(completionTime)")
            self.logger.i("[Restart] Total restart duration: \(completionTime.timeIntervalSince(startTime))s")
        }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(deadline: .now() + 2, execute: workItem)
        logger.i("[Restart] Scheduled restart work item at \(Date())")
    }

    private func handleStateUpdate(state: NWListener.State) {
        logger.i("Handler called with state: \(state) at \(Date())")
        switch state {
        case .setup:
            logger.i("Listener entering setup state")
        case let .waiting(error):
            logger.e("Listener waiting. Error: \(error.localizedDescription)")
            logger.e("Detailed error: \(String(describing: error))")
        case .ready:
            logger.i("Listener ready on port \(port)")
            if let subscriber = subscriberListener, subscriber.state == .ready {
                logger.i("Both listeners ready, cancelling state check")
                stateCheckWorkItem?.cancel()
                stateCheckWorkItem = nil
            }
        case let .failed(error):
            logger.e("Listener failed. Error: \(error.localizedDescription)")
            logger.e("Listener network error code: \(error)")
            logger.e("Listener Detailed error: \(String(describing: error))")
            if isRunning {
                restartServer()
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
            if let listener = listener, listener.state == .ready {
                logger.i("Both listeners ready, cancelling state check")
                stateCheckWorkItem?.cancel()
                stateCheckWorkItem = nil
            }
        case let .failed(error):
            logger.e("Subscriber listener failed with error: \(error)")
            if isRunning {
                restartServer()
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
        if isShuttingDown {
            logger.i("Rejecting new connection during shutdown from \(connection.endpoint)")
            connection.cancel()
            return
        }
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
        if isShuttingDown {
            logger.i("Rejecting new subscriber connection during shutdown from \(connection.endpoint)")
            connection.cancel()
            return
        }
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
            DispatchQueue.main.async {
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
            DispatchQueue.main.async {
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
        if !isRunning {
            logger.w("Service already stopped. Skip...")
            return
        }
        isRunning = false

        logger.i("Stopping service")
        stopNetworkMonitor()
        stopServer()
        logger.i("Service stopped")
    }

    private func stopServer() {
        logger.i("Stop server")

        // Cancel state check work item
        stateCheckWorkItem?.cancel()
        stateCheckWorkItem = nil

        if !stopServerLock.try() {
            logger.i("Already shutting down. Skip...")
            return
        }
        defer {
            logger.d("Releasing stopServer lock")
            stopServerLock.unlock()
        }

        isShuttingDown = true
        logger.d("Got stopServer lock. Proceed to shutdown server.")

        // Wait for current startSever to finish.
        startStopServerLock.lock()
        defer {
            logger.d("Releasing startStopServer lock")
            isShuttingDown = false
            startStopServerLock.unlock()
        }

        logger.i("Got startStopServer lock. Stopping server...")

        // Stop Posix sockets.
        stopServerPosix()

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
        let cancelGroup = DispatchGroup()

        // Cancel main listener
        if let existingListener = listener {
            if existingListener.state != .cancelled {
                cancelGroup.enter()
                existingListener.stateUpdateHandler = { [weak self] state in
                    guard let self = self else { return }
                    self.logger.i("[Main] Listener state during cancellation: \(state)")
                    if state == .cancelled {
                        self.logger.i("[Main] Listener cancelled successfully")
                        cancelGroup.leave()
                    }
                }
                existingListener.cancel()
            } else {
                logger.i("[Main] Listener already cancelled")
            }
        }

        // Cancel subscriber listener
        if let existingSubscriberListener = subscriberListener {
            if existingSubscriberListener.state != .cancelled {
                cancelGroup.enter()
                existingSubscriberListener.stateUpdateHandler = { [weak self] state in
                    guard let self = self else { return }
                    self.logger.i("[Subscriber] Listener state during cancellation: \(state)")
                    if state == .cancelled {
                        self.logger.i("[Subscriber] Listener cancelled successfully")
                        cancelGroup.leave()
                    }
                }
                existingSubscriberListener.cancel()
            } else {
                logger.i("[Subscriber] Listener already cancelled")
            }
        }

        // Wait with timeout
        let result = cancelGroup.wait(timeout: .now() + 5.0)
        if result == .timedOut {
            logger.e("Timeout waiting for listeners to cancel")
            logger.e("This is no expected. We are going to simply exit.")
            stopAndExit()
        }

        listener = nil
        subscriberListener = nil

        logger.i("Server stopped")
    }

    func setEventSink(eventSink: FlutterEventSink?) {
        self.eventSink = eventSink
        if eventSink != nil {
            logger.i("EventSink set")
            updateNetworkConfig()
            updateNetworkAvailable()
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

func testRawSocketBinding(port: UInt16, logger: Logger) -> Bool {
    // Create socket
    let sockfd = socket(AF_INET, SOCK_STREAM, 0)
    guard sockfd >= 0 else {
        logger.e("Failed to create socket: \(errno)")
        return false
    }

    // Set SO_REUSEADDR to avoid "Address already in use" from lingering sockets
    var reuse: Int32 = 1
    setsockopt(sockfd, SOL_SOCKET, SO_REUSEADDR, &reuse, socklen_t(MemoryLayout<Int32>.size))

    // Prepare sockaddr_in
    var addr = sockaddr_in(
        sin_len: __uint8_t(MemoryLayout<sockaddr_in>.size),
        sin_family: sa_family_t(AF_INET),
        sin_port: in_port_t(port).bigEndian,
        sin_addr: in_addr(s_addr: INADDR_ANY),
        sin_zero: (0, 0, 0, 0, 0, 0, 0, 0)
    )

    // Bind with proper casting
    let bindResult = withUnsafePointer(to: &addr) { addrPtr in
        bind(sockfd, UnsafeRawPointer(addrPtr).assumingMemoryBound(to: sockaddr.self), socklen_t(MemoryLayout<sockaddr_in>.size))
    }

    if bindResult == 0 {
        logger.i("POSIX socket bound successfully to port \(port) at \(Date())")
        // Optionally listen to confirm it’s usable
        let listenResult = listen(sockfd, 5)
        if listenResult == 0 {
            logger.i("POSIX socket listening on port \(port)")
        } else {
            logger.e("POSIX listen failed on port \(port): \(errno)")
        }
    } else {
        logger.e("POSIX bind failed on port \(port): \(errno) at \(Date())")
    }

    // Clean up: close the socket
    close(sockfd)
    logger.i("POSIX socket closed for port \(port) at \(Date())")

    return bindResult == 0
}
