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

    deinit {
        timer?.invalidate()
        timer = nil
    }

    func start() {
        guard timer == nil else {
            Self.logger.debug("Battery monitor already running")
            return
        }
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

        // Read temperature and charge rate from AppleSmartBattery IORegistry
        let temperature = readBatteryTemperature()
        let chargeRate = readChargeRate()

        batteryState = BatteryState(
            level: level,
            isPluggedIn: isPluggedIn,
            isCharging: isCharging,
            timeRemaining: timeRemaining,
            cycleCount: cycleCount,
            batteryHealth: batteryHealth,
            maxCapacity: maxCapacity,
            temperature: temperature,
            chargeRate: chargeRate
        )

        Self.logger.debug("Battery: \(level)%, plugged: \(isPluggedIn), charging: \(isCharging)")
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

    /// Reads battery temperature from the AppleSmartBattery IORegistry service.
    /// The "Temperature" key returns a value in centidegrees Celsius (e.g. 3250 = 32.50°C).
    private func readBatteryTemperature() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let prop = IORegistryEntryCreateCFProperty(service, "Temperature" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }
        guard let centidegrees = prop.takeRetainedValue() as? Int else { return nil }
        return Double(centidegrees) / 100.0
    }

    /// Reads instantaneous amperage and voltage from the AppleSmartBattery IORegistry service
    /// and computes the charge rate in watts: voltage (mV) * amperage (mA) / 1,000,000.
    private func readChargeRate() -> Double? {
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        guard service != 0 else { return nil }
        defer { IOObjectRelease(service) }

        guard let amperageProp = IORegistryEntryCreateCFProperty(service, "InstantAmperage" as CFString, kCFAllocatorDefault, 0),
              let voltageProp = IORegistryEntryCreateCFProperty(service, "Voltage" as CFString, kCFAllocatorDefault, 0) else {
            return nil
        }

        guard let amperage = amperageProp.takeRetainedValue() as? Int,
              let voltage = voltageProp.takeRetainedValue() as? Int else { return nil }

        let watts = Double(voltage) * Double(amperage) / 1_000_000.0
        return abs(watts)
    }
}
