// Copyright (c) EZBLOCK Inc & AUTHORS
// SPDX-License-Identifier: BSD-3-Clause

import UserNotifications

#if os(iOS)
    import Flutter
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
class AppDelegate: FlutterAppDelegate, FlutterStreamHandler {
    private var chatService: ChatService?
    private var methodChannel: FlutterMethodChannel?
    private var eventChannel: FlutterEventChannel?
    private var chatMessageChannel: FlutterEventChannel?
    var isAppInBackground = false
    private let logger = Logger(tag: "AppDelegate")
    #if os(iOS)
        override func application(
            _ application: UIApplication,
            didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
        ) -> Bool {
            GeneratedPluginRegistrant.register(with: self)
            requestNotificationPermissions()
            startChatService()
            setupFlutterChannels()
            return super.application(application, didFinishLaunchingWithOptions: launchOptions)
        }

        override func applicationWillTerminate(_: UIApplication) {
            stopChatService()
        }

        override func applicationDidEnterBackground(_: UIApplication) {
            isAppInBackground = true
            chatService?.setAppActive(false)
            startChatService()
        }

        override func applicationWillEnterForeground(_: UIApplication) {
            isAppInBackground = false
            chatService?.setAppActive(true)
        }
    #endif

    #if os(macOS)
        override func applicationDidFinishLaunching(_: Notification) {
            if chatService == nil {
                chatService = ChatService()
            }
            requestNotificationPermissions()
            // startChatService()
            setupFlutterChannels()
        }

        // Handle window close
        override func applicationShouldTerminateAfterLastWindowClosed(_: NSApplication) -> Bool {
            chatService?.setAppActive(false)
            //return false // Keep running after window closes
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
                logger.i("Starting service")
                self.startChatService()
                result(nil)
            case "stopService":
                self.stopChatService()
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
        if chatService == nil {
            chatService = ChatService()
        }
        logger.i("Starting chat service")
        chatService?.startService()
    }

    private func stopChatService() {
        chatService?.stopService()
        chatService = nil
    }

    // FlutterStreamHandler
    func onListen(withArguments args: Any?, eventSink events: @escaping FlutterEventSink) -> FlutterError? {
        let argsDescription = args.map { String(describing: $0) } ?? "nil"
        logger.i("Setting event sink \(argsDescription) from onListen")
        if args as? String == "chat_messages" {
            chatService?.setChatMessageSink(eventSink: events)
        } else {
            chatService?.setEventSink(eventSink: events)
        }
        return nil
    }

    func onCancel(withArguments args: Any?) -> FlutterError? {
        let argsDescription = args.map { String(describing: $0) } ?? "nil"
        logger.i("Cancelling event sink \(argsDescription) from onCancel")
        if args as? String == "chat_messages" {
            chatService?.setChatMessageSink(eventSink: nil)
        } else {
            chatService?.setEventSink(eventSink: nil)
        }
        return nil
    }

    private func requestNotificationPermissions() {
        #if os(iOS)
            UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
                if granted {
                    self.logger.i("Notification permission granted")
                } else {
                    self.logger.e("Notification permission denied: \(String(describing: error))")
                }
            }
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
}
