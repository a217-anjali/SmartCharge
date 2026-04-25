import Foundation
import os

@MainActor
final class ActivityLogger: ObservableObject {
    @Published private(set) var events: [ChargeEvent] = []

    private static let storageKey = "ChargeEventLog"
    private static let maxEvents = 200
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "ActivityLogger")

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ChargeEvent].self, from: data) {
            events = decoded
        }
    }

    func log(_ kind: ChargeEvent.Kind, batteryLevel: Int, detail: String) {
        let event = ChargeEvent(kind: kind, batteryLevel: batteryLevel, detail: detail)
        events.insert(event, at: 0)
        if events.count > Self.maxEvents {
            events = Array(events.prefix(Self.maxEvents))
        }
        persist()
        Self.logger.info("\(kind.rawValue) at \(batteryLevel)%: \(detail)")
    }

    func clearHistory() {
        events.removeAll()
        persist()
        Self.logger.info("Activity history cleared")
    }

    private func persist() {
        if let data = try? JSONEncoder().encode(events) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
