import Foundation
import IOKit.ps
import Combine

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var batteryState: BatteryState = .unknown

    private var timer: Timer?
    private let pollInterval: TimeInterval

    init(pollInterval: TimeInterval = 60) {
        self.pollInterval = pollInterval
    }

    func start() {
        readBattery()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.readBattery()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func readBattery() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let source = sources.first else {
            batteryState = .unknown
            return
        }

        guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            batteryState = .unknown
            return
        }

        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let isPluggedIn = powerSource == kIOPSACPowerValue
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int

        batteryState = BatteryState(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            timeRemaining: timeRemaining
        )
    }
}
