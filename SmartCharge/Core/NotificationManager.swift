import Foundation
import UserNotifications
import os

@MainActor
final class NotificationManager: ObservableObject {
    @Published private(set) var isAuthorized = false
    var notificationsEnabled = true
    private nonisolated static let logger = Logger(subsystem: "com.smartcharge.app", category: "Notifications")

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { [weak self] granted, error in
            Task { @MainActor [weak self] in
                self?.isAuthorized = granted
                if granted {
                    Self.logger.info("Notification permission granted")
                } else if let error = error {
                    Self.logger.error("Notification permission denied: \(error.localizedDescription)")
                } else {
                    Self.logger.warning("Notification permission denied by user")
                }
            }
        }
    }

    func send(title: String, body: String) {
        guard notificationsEnabled, isAuthorized else { return }

        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let request = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )
        UNUserNotificationCenter.current().add(request) { error in
            if let error = error {
                Self.logger.error("Failed to deliver notification: \(error.localizedDescription)")
            } else {
                Self.logger.debug("Notification sent: \(title)")
            }
        }
    }
}
