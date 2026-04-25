import Foundation
import IOKit.ps
import Combine
import os

@MainActor
final class BatteryMonitor: ObservableObject {
    @Published private(set) var batteryState: BatteryState = .unknown

    private var timer: Timer?
    private let pollInterval: TimeInterval
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "BatteryMonitor")

    init(pollInterval: TimeInterval = 60) {
        self.pollInterval = pollInterval
    }

    func start() {
        Self.logger.info("Battery monitor started (polling every \(self.pollInterval)s)")
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: pollInterval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.refresh()
            }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
        Self.logger.info("Battery monitor stopped")
    }

    func refresh() {
        let snapshot = IOPSCopyPowerSourcesInfo().takeRetainedValue()
        let sources = IOPSCopyPowerSourcesList(snapshot).takeRetainedValue() as Array

        guard let source = sources.first else {
            Self.logger.error("No power sources found")
            batteryState = .unknown
            return
        }

        guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any] else {
            Self.logger.error("Failed to read power source description")
            batteryState = .unknown
            return
        }

        let level = desc[kIOPSCurrentCapacityKey] as? Int ?? -1
        let powerSource = desc[kIOPSPowerSourceStateKey] as? String ?? ""
        let isPluggedIn = powerSource == kIOPSACPowerValue
        let isCharging = desc[kIOPSIsChargingKey] as? Bool ?? false
        let timeRemaining = desc[kIOPSTimeToEmptyKey] as? Int

        let batteryHealth = desc["BatteryHealth"] as? String
        let maxCapacity = desc[kIOPSMaxCapacityKey] as? Int

        let cycleCount = readCycleCount()

        batteryState = BatteryState(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            batteryHealth: batteryHealth,
            maxCapacity: maxCapacity
        )

        Self.logger.debug("Battery: \(level)%, plugged: \(isPluggedIn), charging: \(isCharging), health: \(batteryHealth ?? "n/a"), cycles: \(cycleCount ?? -1)")
    }

    private func readCycleCount() -> Int? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let prop = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        return prop.takeRetainedValue() as? Int
    }
}
