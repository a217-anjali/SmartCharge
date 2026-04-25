import Foundation

struct BatteryState: Equatable {
    let level: Int
    let isPluggedIn: Bool
    let isCharging: Bool
    let timeRemaining: Int?
    let cycleCount: Int?
    let batteryHealth: String?
    let maxCapacity: Int?
    let temperature: Double?
    let chargeRate: Double?

    static let unknown = BatteryState(
        level: -1, isPluggedIn: false, isCharging: false,
        timeRemaining: nil, cycleCount: nil, batteryHealth: nil, maxCapacity: nil,
        temperature: nil, chargeRate: nil
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

    var temperatureFormatted: String? {
        guard let temp = temperature else { return nil }
        return String(format: "%.1f°C", temp)
    }

    var isOverheating: Bool {
        guard let temp = temperature else { return false }
        return temp > 40.0
    }

    /// Estimates time to reach a target battery percentage based on current charge rate.
    /// - Parameter target: The target battery percentage (0-100).
    /// - Returns: A formatted string like "1h 23m", or nil if estimation is not possible.
    func estimatedTime(toTarget target: Int) -> String? {
        guard let rate = chargeRate, rate > 0,
              let cap = maxCapacity, cap > 0,
              level >= 0 else { return nil }

        let remainingPercent = target - level
        guard remainingPercent > 0 else { return nil }

        // Estimate watt-hours needed: (remainingPercent / 100) * designCapacityWh
        // maxCapacity here is a percentage; assume a typical MacBook battery ~60 Wh
        // as a rough estimate. The IORegistry maxCapacity is percentage-based in this codebase,
        // so we approximate with a nominal 60 Wh battery capacity.
        let nominalCapacityWh: Double = 60.0
        let remainingWh = (Double(remainingPercent) / 100.0) * nominalCapacityWh
        let hoursNeeded = remainingWh / rate

        guard hoursNeeded.isFinite, hoursNeeded > 0 else { return nil }

        let totalMinutes = Int(hoursNeeded * 60)
        let h = totalMinutes / 60
        let m = totalMinutes % 60
        if h > 0 { return "\(h)h \(m)m" }
        return "\(m)m"
    }
}
