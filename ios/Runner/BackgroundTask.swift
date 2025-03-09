import Foundation
import UIKit
import UserNotifications

class BackgroundTask {
    private var backgroundTask: UIBackgroundTaskIdentifier = .invalid
    private let backgroundTaskIDLock = NSLock()
    private var endBackgroundWorkItem: DispatchWorkItem?
    private var notificationWorkItem: DispatchWorkItem?
    private let logger = Logger(tag: "BackgroundTask")
    private weak var delegate: BackgroundTaskProtocol?

    init(delegate: BackgroundTaskProtocol) {
        self.delegate = delegate
    }

    func startBackgroundTask() {
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
        notificationWorkItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            if self.backgroundTask != .invalid {
                self.showBackgroundTaskExpirationNotification()
            }
        }

        endBackgroundWorkItem = DispatchWorkItem { [weak self] in
            self?.cleanupAndEndTask()
        }

        // Schedule notification for 15 seconds
        if let notificationItem = notificationWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + 15, execute: notificationItem)
        }

        // Schedule cleanup for 20 seconds
        if let endItem = endBackgroundWorkItem {
            DispatchQueue.global().asyncAfter(deadline: .now() + 20, execute: endItem)
        }
    }

    private func cleanupAndEndTask(bySystem: Bool = false) {
        delegate?.cleanup()
        endBackgroundTask(bySystem: bySystem)
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
