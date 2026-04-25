import SwiftUI

struct ChargeEstimationView: View {
    let batteryState: BatteryState
    let config: ChargeConfig

    /// Assumed average charge rate in watts when charging.
    /// MacBook batteries are typically 50-100 Wh; a rough heuristic is used
    /// to convert watt-hours remaining into a time estimate.
    private static let assumedBatteryCapacityWh: Double = 70.0

    var body: some View {
        HStack(spacing: 16) {
            estimatedTimeLabel
            Divider().frame(height: 16)
            chargeRateLabel
        }
        .font(.callout)
    }

    // MARK: - Subviews

    private var estimatedTimeLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "clock.fill")
                .foregroundStyle(.secondary)
            Text("Full at: ")
                .foregroundStyle(.secondary)
            Text(estimatedCompletionTimeString)
                .fontWeight(.medium)
        }
    }

    private var chargeRateLabel: some View {
        HStack(spacing: 4) {
            Image(systemName: "bolt.fill")
                .foregroundStyle(.secondary)
            Text("Rate: ")
                .foregroundStyle(.secondary)
            Text(chargeRateString)
                .fontWeight(.medium)
        }
    }

    // MARK: - Calculations

    /// Estimated time string for when charging will reach the stop threshold.
    private var estimatedCompletionTimeString: String {
        guard batteryState.isCharging,
              batteryState.level >= 0,
              batteryState.level < config.chargeStopThreshold else {
            return "N/A"
        }

        let remainingPercent = config.chargeStopThreshold - batteryState.level
        guard remainingPercent > 0 else { return "N/A" }

        // Use the system-reported time remaining if available and reasonable.
        // timeRemaining from IOKit reports minutes to full (100%), so we scale
        // proportionally to the stop threshold.
        if let systemMinutes = batteryState.timeRemaining, systemMinutes > 0 {
            let percentToFull = 100 - batteryState.level
            guard percentToFull > 0 else { return "N/A" }
            let minutesToThreshold = Int(Double(remainingPercent) / Double(percentToFull) * Double(systemMinutes))
            return formattedTime(addingMinutes: minutesToThreshold)
        }

        // Fallback: estimate ~0.7 min per percent (rough average for a 70 Wh
        // battery charging at ~60 W).
        let estimatedMinutes = Int(Double(remainingPercent) * 0.7)
        return formattedTime(addingMinutes: estimatedMinutes)
    }

    /// Estimated charge rate in watts based on the system time-remaining data.
    private var chargeRateString: String {
        guard batteryState.isCharging else { return "N/A" }

        if let systemMinutes = batteryState.timeRemaining, systemMinutes > 0 {
            let percentToFull = 100 - batteryState.level
            guard percentToFull > 0 else { return "N/A" }
            let hoursToFull = Double(systemMinutes) / 60.0
            let estimatedWatts = (Double(percentToFull) / 100.0 * Self.assumedBatteryCapacityWh) / hoursToFull
            return "\(Int(estimatedWatts))W"
        }

        return "N/A"
    }

    // MARK: - Helpers

    /// Format a time that is `minutes` from now as a short clock string (e.g. "2:30 PM").
    private func formattedTime(addingMinutes minutes: Int) -> String {
        let target = Calendar.current.date(byAdding: .minute, value: minutes, to: Date()) ?? Date()
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: target)
    }
}
