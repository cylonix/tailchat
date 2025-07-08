// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import UserNotifications

#if os(iOS)
    import Flutter
    import Foundation
    import Network
    import UIKit
#elseif os(macOS)
    import AppKit
    import FlutterMacOS
#endif

#if os(iOS)
    @UIApplicationMain
#elseif os(macOS)
    @NSApplicationMain
#endif

@available(macOS 10.15, iOS 13.0, *)
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler, BackgroundTaskProtocol {
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var chatMessageChannel: FlutterEventChannel?
    private var chatMessageEventSink: FlutterEventSink?
    private var eventSink: FlutterEventSink?
    private var cylonixObserver: UnsafeMutableRawPointer?
    private static let cylonixStateChangeNotification = "io.cylonix.sase.tailchat.stateChange"
    private static let chatsReceivedNotification = "io.cylonix.sase.chatsReceived"
    var isAppInBackground = false
    var isServiceEnabled = false
    private let logger = Logger(tag: "AppDelegate")

    // MARK: - BackgroundTaskProtocol

    func cleanup() {
        logger.i("Service cleanup called from background task. Stop Service!")
        stopChatService()
    }

    #if os(iOS)
        private var chatService: ChatService?
        private var backgroundTaskHandler: BackgroundTask?
        override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            setupFlutterChannels()
            application.registerForRemoteNotifications()
            GeneratedPluginRegistrant.register(with: self)
            requestNotificationPermissions()
            startChatService()
            backgroundTaskHandler = BackgroundTask(delegate: self)
            backgroundTaskHandler?.registerBackgroundRefreshTask()
            setupCylonixServiceObserver()
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        override func applicationWillTerminate(_: UIApplication) {
            stopChatService()
        }

        override func applicationDidEnterBackground(_: UIApplication) {
            isAppInBackground = true
            chatService?.setAppActive(false)
            startChatService()
            backgroundTaskHandler?.startBackgroundTask()
        }

        override func applicationWillEnterForeground(_: UIApplication) {
            isAppInBackground = false
            backgroundTaskHandler?.endBackgroundTask()
            backgroundTaskHandler?.endPeriodicalBackgroundTask()
            startChatService()
            chatService?.setAppActive(true)
        }

        private static let observerCallback: CFNotificationCallback = { _, observer, name, _, _ in
            if let nameString = name?.rawValue as String?,
               nameString == AppDelegate.cylonixStateChangeNotification,
               let observer = observer
            {
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                appDelegate.handleCylonixServiceStateChange()
            }
        }

        private func setupCylonixServiceObserver() {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            let selfPtr = Unmanaged.passRetained(self).toOpaque()

            cylonixObserver = selfPtr

            CFNotificationCenterAddObserver(
                center,
                cylonixObserver,
                Self.observerCallback,
                Self.cylonixStateChangeNotification as CFString,
                nil,
                .deliverImmediately
            )
            CFNotificationCenterAddObserver(
                center,
                cylonixObserver,
                Self.chatsReceivedCallback,
                Self.chatsReceivedNotification as CFString,
                nil,
                .deliverImmediately
            )

            logger.i("Registered for Cylonix service state changes")
        }

        private func handleCylonixServiceStateChange() {
            logger.i("Received Cylonix service state change notification")

            let isNowActive = ChatService.isCylonixServiceActive
            logger.i("Cylonix service state changed to \(isNowActive)")

            methodChannel?.invokeMethod("cylonixServiceStateChanged", arguments: isNowActive)
        }

        private static let chatsReceivedCallback: CFNotificationCallback = { _, observer, name, _, _ in
            if let nameString = name?.rawValue as String?,
               nameString == AppDelegate.chatsReceivedNotification,
               let observer = observer
            {
                let appDelegate = Unmanaged<AppDelegate>.fromOpaque(observer).takeUnretainedValue()
                appDelegate.handleChatsReceived()
            }
        }

        private func handleChatsReceived() {
            logger.i("Received new chats notification")

            guard let userDefaults = UserDefaults(suiteName: "group.io.cylonix.sase.ios"),
                  let message = userDefaults.string(forKey: "ChatsReceived")
            else {
                return
            }

            let content = UNMutableNotificationContent()
            content.title = "New Messages"
            content.body = message
            content.sound = .default

            if #available(iOS 15.0, *) {
                content.interruptionLevel = .timeSensitive
                content.relevanceScore = 0.9
            }

            let request = UNNotificationRequest(
                identifier: "new-chats-\(UUID().uuidString)",
                content: content,
                trigger: nil
            )

            UNUserNotificationCenter.current().add(request) { [weak self] error in
                if let error = error {
                    self?.logger.e("Failed to schedule chat notification: \(error)")
                } else {
                    self?.logger.i("Chat notification scheduled successfully")
                }
            }
        }
    #endif

    #if os(macOS)
        private var chatService: ChatService?
        override func applicationDidFinishLaunching(_: Notification) {
            setupFlutterChannels()
            if chatService == nil {
                chatService = ChatService()
            }
            requestNotificationPermissions()
        }

        // Handle window close
        override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            chatService?.setAppActive(false)
            // return false // Keep running after window closes
            return true
        }

        // Handle actual quit
        override func applicationShouldTerminate(_: NSApplication) -> NSApplication.TerminateReply {
            stopChatService()
            return .terminateNow
        }

        // Handle becoming inactive (window minimized/hidden)
        override func applicationDidResignActive(_: Notification) {
            // Service continues running
            logger.i("Application resigned active but service continues")
            chatService?.setAppActive(false)
        }

        override func applicationDidBecomeActive(_: Notification) {
            chatService?.setAppActive(true)
        }

        override func applicationSupportsSecureRestorableState(_: NSApplication) -> Bool {
            return true
        }
    #endif
    private func setupFlutterChannels() {
        #if os(iOS)
            let messenger = (window?.rootViewController as? FlutterViewController)?.binaryMessenger
        #else
            let messenger = (NSApplication.shared.windows.first?.contentViewController as? FlutterViewController)?.engine.binaryMessenger
        #endif

        guard let messenger = messenger else {
            logger.e("Failed to get binary messenger")
            return
        }

        // Setup method channel
        methodChannel = FlutterMethodChannel(
            name: "io.cylonix.tailchat/chat_service",
            binaryMessenger: messenger
        )
        methodChannel?.setMethodCallHandler { [weak self] call, result in
            guard let self = self else { return }

            switch call.method {
            case "startService":
                self.logger.i("Starting chat service from App")
                self.isServiceEnabled = true
                self.startChatService()
                result(nil)
            case "stopService":
                self.logger.i("Stopping chat service from App")
                self.isServiceEnabled = false
                self.stopChatService()
                result(nil)
            case "restartService":
                self.logger.i("Restarting chat service from App")
                self.isServiceEnabled = true
                self.restartChatService()
                result(nil)
            case "isCylonixServiceActive":
                self.logger.i("Checking if chat service is assisted by Cylonix")
                result(ChatService.isCylonixServiceActive)
            case "getCylonixSharedFolderPath":
                self.logger.i("Getting Cylonix shared folder path")
                result(ChatService.cylonixSharedFolderPath)
            case "logs":
                self.getLogs()
                result(nil)
            case "checkLocalNetworkAccess":
                self.logger.i("Checking local network access")
                if #available(iOS 14.0, *) {
                    // Use Bundle.main.object(forInfoDictionaryKey:) to check if permission is declared
                    guard Bundle.main.object(forInfoDictionaryKey: "NSLocalNetworkUsageDescription") != nil else {
                        self.logger.e("NSLocalNetworkUsageDescription not declared in Info.plist")
                        result(FlutterError(
                            code: "PERMISSION_NOT_DECLARED",
                            message: "Local network permission not declared",
                            details: "Add NSLocalNetworkUsageDescription to Info.plist"
                        ))
                        return
                    }

                    // Create a NetService browser to trigger local network permission
                    let browser = NetServiceBrowser()
                    browser.searchForServices(ofType: "_tailchat._tcp.", inDomain: "local.")

                    // Stop browsing after a brief moment and return result
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                        browser.stop()
                        // Permission request triggered, but we can't know the result immediately
                        result("PERMISSION_REQUESTED")
                    }
                } else {
                    // Pre-iOS 14 doesn't need permission
                    result(true)
                }
            default:
                result(FlutterMethodNotImplemented)
            }
        }

        // Setup event channel
        eventChannel = FlutterEventChannel(
            name: "io.cylonix.tailchat/events",
            binaryMessenger: messenger
        )
        eventChannel?.setStreamHandler(self)
        chatMessageChannel = FlutterEventChannel(
            name: "io.cylonix.tailchat/chat_messages",
            binaryMessenger: messenger
        )
        chatMessageChannel?.setStreamHandler(self)
    }

    private func startChatService() {
        if !isServiceEnabled {
            logger.i("Service is not enabled. Not starting chat service.")
            return
        }
        logger.i("Starting chat service")
        if chatService == nil {
            let service = ChatService()
            chatService = service
        }
        chatService?.startService()
        chatService?.setChatMessageSink(eventSink: chatMessageEventSink)
        chatService?.setEventSink(eventSink: eventSink)
    }

    private func stopChatService() {
        logger.i("Stopping chat service")
        if let service = chatService {
            logger.i("[ChatService] Stopping instance. Ref count=\(CFGetRetainCount(service))")
            service.stopService()
        }
        chatService = nil
    }

    private func restartChatService() {
        if !isServiceEnabled {
            logger.i("Service is not enabled. Not restarting chat service.")
            return
        }
        logger.i("Restarting chat service")
        if let service = chatService {
            service.restartServer()
        }
    }

    deinit {
        if let observer = cylonixObserver {
            let center = CFNotificationCenterGetDarwinNotifyCenter()
            CFNotificationCenterRemoveObserver(
                center,
                observer,
                CFNotificationName(Self.cylonixStateChangeNotification as CFString),
                nil
            )
            Unmanaged<AppDelegate>.fromOpaque(observer).release()
        }
        stopChatService()
    }

    private func getLogs() {
        let logFilePath = logger.getLogFilePath()
        do {
            let logContents = try String(contentsOfFile: logFilePath, encoding: .utf8)
            if let eventSink = eventSink {
                DispatchQueue.main.async {
                    eventSink(
                        [
                            "type": "logs",
                            "logs": logContents,
                        ]
                    )
                }
            }
        } catch {
            logger.e("Failed to read log file: \(error)")
        }
    }

    // FlutterStreamHandler
    func onListen(withArguments args: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let argsDescription = args.map { String(describing: $0) } ?? "nil"
        logger.i("Setting event sink \(argsDescription) from onListen")
        if args as? String == "chat_messages" {
            chatMessageEventSink = events
            chatService?.setChatMessageSink(eventSink: events)
        } else {
            eventSink = events
            chatService?.setEventSink(eventSink: events)
        }
        return nil
    }

    func onCancel(withArguments args: Any?) -> FlutterError? {
        let argsDescription = args.map { String(describing: $0) } ?? "nil"
        logger.i("Cancelling event sink \(argsDescription) from onCancel")
        if args as? String == "chat_messages" {
            chatMessageEventSink = nil
            chatService?.setChatMessageSink(eventSink: nil)
        } else {
            eventSink = nil
            chatService?.setEventSink(eventSink: nil)
        }
        return nil
    }

    private func requestNotificationPermissions() {
        #if os(iOS)
            // Request all necessary notification permissions
            UNUserNotificationCenter.current().requestAuthorization(
                options: [.alert, .badge, .sound]
            ) { granted, error in
                if granted {
                    self.logger.i("Notification permission granted")

                    // Configure notification categories
                    let continueAction = UNNotificationAction(
                        identifier: "CONTINUE_SERVICE",
                        title: "Continue",
                        options: [.foreground]
                    )

                    let stopAction = UNNotificationAction(
                        identifier: "STOP_SERVICE",
                        title: "Stop",
                        options: [.destructive]
                    )

                    let category = UNNotificationCategory(
                        identifier: "SERVICE_EXPIRING",
                        actions: [continueAction, stopAction],
                        intentIdentifiers: [],
                        options: [.customDismissAction]
                    )

                    // Register the category
                    UNUserNotificationCenter.current().setNotificationCategories([category])
                } else {
                    self.logger.e("Notification permission denied: \(String(describing: error))")
                }
            }

            // Set notification delegate
            UNUserNotificationCenter.current().delegate = self
        #elseif os(macOS)
            let center = UNUserNotificationCenter.current()
            center.requestAuthorization(options: [.alert, .sound]) { granted, error in
                if granted {
                    self.logger.i("Notification permission granted")
                } else {
                    self.logger.e("Notification permission denied: \(String(describing: error))")
                }
            }
        #endif
    }

    #if os(iOS)
        private var apnUUID: String?
        override func application(
            _: UIApplication,
            didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
        ) {
            let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
            logger.i("Got APN token: \(tokenString)")

            // Get or generate UUID for this device
            if apnUUID == nil {
                if let savedUUID = UserDefaults.standard.string(forKey: "apn_device_uuid") {
                    apnUUID = savedUUID
                    logger.i("Retrieved saved APN UUID: \(savedUUID)")
                } else {
                    apnUUID = UUID().uuidString
                    UserDefaults.standard.set(apnUUID, forKey: "apn_device_uuid")
                    logger.i("Generated new APN UUID: \(apnUUID!)")
                }
            }

            // Store token and UUID in ChatService
            chatService?.setAPNToken(token: tokenString, uuid: apnUUID!)
        }

        override func application(
            _: UIApplication,
            didFailToRegisterForRemoteNotificationsWithError error: Error
        ) {
            logger.e("Failed to register for remote notifications: \(error)")
        }

        // Handle incoming push notifications
        override func application(
            _: UIApplication,
            didReceiveRemoteNotification userInfo: [AnyHashable: Any],
            fetchCompletionHandler completionHandler: @escaping (UIBackgroundFetchResult) -> Void
        ) {
            logger.i("Received remote notification: \(userInfo)")

            startChatService()
            if let peerID = userInfo["peer_id"] as? String {
                chatService?.handleIncomingConnection(fromPeerID: peerID)
            }

            completionHandler(.newData)
        }

        override func userNotificationCenter(
            _: UNUserNotificationCenter,
            willPresent _: UNNotification,
            withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
        ) {
            // Show notification with banner, list, and sound
            completionHandler([.banner, .list, .sound])
        }

        override func userNotificationCenter(
            _: UNUserNotificationCenter,
            didReceive response: UNNotificationResponse,
            withCompletionHandler completionHandler: @escaping () -> Void
        ) {
            switch response.actionIdentifier {
            case "CONTINUE_SERVICE":
                // Will bring app to foreground automatically
                logger.i("User chose to continue service")
            case "STOP_SERVICE":
                logger.i("User chose to stop service")
                stopChatService()
            default:
                logger.i("Default notification action")
            }
            completionHandler()
        }
    #endif
    #if os(iOS)
        override func application(_: UIApplication,
                                  continue userActivity: NSUserActivity,
                                  restorationHandler _: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool
        {
            // Only handle universal links
            if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
               let url = userActivity.webpageURL
            {
                handleAppLink(url)
                return true
            }
            return false
        }

    #elseif os(macOS)
        override func application(_: NSApplication,
                                  open urls: [URL])
        {
            // Handle app links
            logger.i("Application opened with URLs: \(urls)")
            if let url = urls.first {
                handleAppLink(url)
            }
        }

        override func application(_: NSApplication,
                                  continue userActivity: NSUserActivity,
                                  restorationHandler _: @escaping ([NSUserActivityRestoring]) -> Void) -> Bool
        {
            if userActivity.activityType == NSUserActivityTypeBrowsingWeb,
               let url = userActivity.webpageURL
            {
                handleAppLink(url)
                return true
            }
            return false
        }
    #endif

    private func handleAppLink(_ url: URL) {
        logger.d("Handling app link: \(url)")

        // Example: https://cylonix.io/tailchat/add/{name}/{device_name}
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: true) else {
            logger.e("Invalid URL format")
            return
        }

        // Convert URL parameters to a map for Flutter
        var params: [String: String] = [:]
        components.queryItems?.forEach { item in
            if let value = item.value {
                params[item.name] = value
            }
        }

        // Send to Flutter via method channel
        if methodChannel == nil {
            logger.e("Method channel is not initialized")
            return
        }
        methodChannel?.invokeMethod("handleAppLink", arguments: [
            "path": components.path,
            "params": params,
            "pathComponents": url.pathComponents,
        ])
        logger.i("App link handled with path: \(url.path)")
    }
}

protocol BackgroundTaskProtocol: AnyObject {
    func cleanup()
}
