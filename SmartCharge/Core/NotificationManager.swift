import Foundation
import UserNotifications

final class NotificationManager {
    private var isAuthorized = false
    var notificationsEnabled = true

    func requestPermission() {
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound]) { granted, error in
            self.isAuthorized = granted
            if let error = error {
                print("Notification permission error: \(error)")
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
        UNUserNotificationCenter.current().add(request)
    }
}
