import Foundation

struct BatteryState: Equatable {
    let level: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let timeRemaining: Int?
    let cycleCount: Int?
    let batteryHealth: String?
    let maxCapacity: Int?

    static let unknown = BatteryState(
        level: -1, isPluggedIn: false, isCharging: false,
        timeRemaining: nil, cycleCount: nil, batteryHealth: nil, maxCapacity: nil
    )

    var levelDescription: String {
        guard level >= 0 else { return "Unknown" }
        return "\(level)%"
    }

    var statusDescription: String {
        if !isPluggedIn { return "On Battery" }
        if isCharging { return "Charging" }
        return "Plugged In (Not Charging)"
    }

    var menuBarTitle: String {
        guard level >= 0 else { return "⚡ --%" }
        return "⚡ \(level)%"
    }

    var timeRemainingFormatted: String? {
        guard let minutes = timeRemaining, minutes > 0 else { return nil }
        if minutes == -1 { return "Calculating..." }
        let h = minutes / 60
        let m = minutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }

    var healthDescription: String {
        batteryHealth ?? "Unknown"
    }

    var cycleCountDescription: String {
        guard let count = cycleCount else { return "Unknown" }
        return "\(count)"
    }

    var capacityDescription: String {
        guard let cap = maxCapacity else { return "Unknown" }
        return "\(cap)%"
    }
}
