import Foundation

struct BatteryState: Equatable {
    let level: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let timeRemaining: Int?

    static let unknown = BatteryState(level: -1, isPluggedIn: false, isCharging: false, timeRemaining: nil)

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
}
