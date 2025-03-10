// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import UserNotifications

#if os(iOS)
    import Flutter
    import Foundation
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
    private var chatMesssageEventSink: FlutterEventSink?
    private var eventSink: FlutterEventSink?
    var isAppInBackground = false
    private let logger = Logger(tag: "AppDelegate")

    // MARK: - BackgroundTaskProtocol

    func cleanup() {
        logger.i("Service cleanup called from background task")
        stopChatService()
    }

    #if os(iOS)
        private var _chatService: Unmanaged<ChatService>?
        private var chatService: ChatService? {
            get {
                return _chatService?.takeUnretainedValue()
            }
            set {
                if let service = _chatService {
                    logger.i("[ChatService] Setter called. Ref-count=\(CFGetRetainCount(service as AnyObject))")
                }
                // Release existing service if any
                _chatService?.release()

                // Retain new service if provided
                if let newValue = newValue {
                    _chatService = Unmanaged.passRetained(newValue)
                    logger.i("[ChatService] New instance retained. Ref count=\(CFGetRetainCount(newValue))")
                } else {
                    _chatService = nil
                    logger.i("[ChatService] Instance cleared")
                }
            }
        }

        private var backgroundTaskHandler: BackgroundTask?
        override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            application.registerForRemoteNotifications()
            GeneratedPluginRegistrant.register(with: self)
            requestNotificationPermissions()
            startChatService()
            setupFlutterChannels()
            backgroundTaskHandler = BackgroundTask(delegate: self)
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
            startChatService()
            chatService?.setAppActive(true)
        }

    #endif

    #if os(macOS)
        private var chatService: ChatService?
        override func applicationDidFinishLaunching(_: Notification) {
            if chatService == nil {
                chatService = ChatService()
            }
            requestNotificationPermissions()
            setupFlutterChannels()
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
                self.startChatService()
                result(nil)
            case "stopService":
                self.stopChatService()
                result(nil)
            case "restartService":
                self.restartChatService()
                result(nil)
            case "logs":
                self.getLogs()
                result(nil)
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
        logger.i("Starting chat service")
        if chatService == nil {
            let service = ChatService()
            chatService = service
        }
        chatService?.startService()
        chatService?.setChatMessageSink(eventSink: chatMesssageEventSink)
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
        logger.i("Restarting chat service")
        if let service = chatService {
            service.restartServer()
        }
    }

    deinit {
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
            chatMesssageEventSink = events
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
            chatMesssageEventSink = nil
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
}

protocol BackgroundTaskProtocol: AnyObject {
    func cleanup()
}
