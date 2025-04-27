import Foundation
import UIKit
import UserNotifications

class BackgroundTask {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIDLock = NSLock()
    private var endBackgroundWorkItem: DispatchWorkItem?
    private var periodicalBackgroundTaskWorkItem: DispatchWorkItem?
    private var notificationWorkItem: DispatchWorkItem?
    private let logger = Logger(tag: "BackgroundTask")
    private weak var delegate: BackgroundTaskProtocol?
    static let appGroup = "group.io.cylonix.sase.ios"
    static let bufferPath = "tailchat/.tailchat_buffer.json"
    private let rescheduleInterval: TimeInterval = 5 * 60 // 5 minutes

    init(delegate: BackgroundTaskProtocol) {
        self.delegate = delegate
    }

    func startBackgroundTask() {
        logger.i("Starting background task")
        backgroundTaskIDLock.lock()
        if backgroundTask != .invalid {
            logger.i("Background task already running with identifier: \(backgroundTask)")
            backgroundTaskIDLock.unlock()
            return
        }

        let taskIdentifier = "io.cylonix.tailchat.chatServiceTask"
        backgroundTask = UIApplication.shared.beginBackgroundTask(withName: taskIdentifier) { [weak self] in
            self?.logger.i("Background task expiring by system")
            self?.cleanupAndEndTask(bySystem: true)
        }
        backgroundTaskIDLock.unlock()

        scheduleNotificationAndCleanup()
        logger.i("Started background task with identifier: \(backgroundTask)")
    }

    private func scheduleNotificationAndCleanup() {
        scheduleNextBackgroundTask()

        if ChatService.isCylonixServiceActive {
            checkBufferAndNotify()
            return
        }

        endBackgroundWorkItem = DispatchWorkItem { [weak self] in
            self?.cleanupAndEndTask()
        }

        // Schedule cleanup for 20 seconds
        if let endItem = endBackgroundWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: endItem)
        }
    }

    private func checkBufferAndNotify() {
        guard let containerURL = FileManager.default.containerURL(
            forSecurityApplicationGroupIdentifier: Self.appGroup
        ) else {
            logger.e("Failed to access shared container")
            return
        }

        let bufferURL = containerURL.appendingPathComponent(Self.bufferPath)

        do {
            let fileExists = FileManager.default.fileExists(atPath: bufferURL.path)
            if !fileExists {
                logger.d("No buffer file exists")
                return
            }

            let data = try Data(contentsOf: bufferURL)
            if !data.isEmpty {
                let content = UNMutableNotificationContent()
                content.title = "New Messages"
                content.body = "You have new messages waiting in Tailchat"
                content.sound = .default

                if #available(iOS 15.0, *) {
                    content.interruptionLevel = .timeSensitive
                    content.relevanceScore = 0.8
                }

                let request = UNNotificationRequest(
                    identifier: "new-messages-\(UUID().uuidString)",
                    content: content,
                    trigger: nil
                )

                UNUserNotificationCenter.current().add(request) { [weak self] error in
                    if let error = error {
                        self?.logger.e("Failed to schedule new messages notification: \(error)")
                    }
                }
            }
        } catch {
            logger.e("Failed to read buffer file: \(error)")
        }
    }

    private func scheduleNextBackgroundTask() {
        periodicalBackgroundTaskWorkItem?.cancel()
        periodicalBackgroundTaskWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            logger.i("Refreshed background task activated")
            self.cleanupAndEndTask()

            // Start the background task
            logger.i("Schedule to start the background task")
            DispatchQueue.main.asyncAfter(deadline: .now() + 1) {
                self.startBackgroundTask()
            }
        }

        if let item = periodicalBackgroundTaskWorkItem {
            DispatchQueue.global().asyncAfter(
                deadline: .now() + rescheduleInterval,
                execute: item
            )
        }
        logger.i("Scheduled next background task in \(rescheduleInterval) seconds")
    }

    private func cleanupAndEndTask(bySystem: Bool = false) {
        logger.i("Cleaning up and ending background task. by system: \(bySystem)")
        delegate?.cleanup()
        endBackgroundTask(bySystem: bySystem)
    }

    func endPeriodicalBackgroundTask() {
        logger.i("Ending periodical background task")
        periodicalBackgroundTaskWorkItem?.cancel()
        periodicalBackgroundTaskWorkItem = nil
    }

    func endBackgroundTask(bySystem: Bool = false) {
        UNUserNotificationCenter.current().removeAllPendingNotificationRequests()

        backgroundTaskIDLock.lock()
        if backgroundTask == .invalid {
            backgroundTaskIDLock.unlock()
            return
        }

        let id = backgroundTask
        backgroundTask = .invalid
        backgroundTaskIDLock.unlock()

        logger.i("Ending background task. by system: \(bySystem)")
        notificationWorkItem?.cancel()
        endBackgroundWorkItem?.cancel()
        notificationWorkItem = nil
        endBackgroundWorkItem = nil
        UIApplication.shared.endBackgroundTask(id)
    }

    private func showBackgroundTaskExpirationNotification() {
        logger.i("Preparing to show background expiration notification")

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

        UNUserNotificationCenter.current().add(request) { [weak self] error in
            if let error = error {
                self?.logger.e("Failed to schedule notification: \(error)")
            } else {
                self?.logger.i("Background expiration notification scheduled successfully")
            }
        }
    }
}
