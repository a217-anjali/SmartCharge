import Foundation
import Combine
import os

enum ChargeState: String, CustomStringConvertible {
    case waiting = "Waiting"
    case charging = "Charging"

    var description: String { rawValue }
}

@MainActor
final class ChargeStateMachine: ObservableObject {
    @Published private(set) var state: ChargeState = .waiting
    @Published private(set) var lastTransition: Date?
    @Published var lastError: String?

    private let helperProxy: HelperProxy
    private let notificationManager: NotificationManager
    private let activityLogger: ActivityLogger
    private var isTransitioning = false
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "StateMachine")

    init(helperProxy: HelperProxy, notificationManager: NotificationManager, activityLogger: ActivityLogger) {
        self.helperProxy = helperProxy
        self.notificationManager = notificationManager
        self.activityLogger = activityLogger
    }

    func evaluate(battery: BatteryState, config: ChargeConfig) {
        guard battery.level >= 0, battery.isPluggedIn else { return }
        guard !isTransitioning else {
            Self.logger.debug("Skipping evaluate — transition in progress")
            return
        }

        switch state {
        case .waiting:
            if battery.level <= config.chargeStartThreshold {
                Self.logger.info("Battery at \(battery.level)% <= \(config.chargeStartThreshold)% — start charging")
                transitionTo(.charging, battery: battery, config: config)
            }

        case .charging:
            if battery.level >= config.chargeStopThreshold {
                Self.logger.info("Battery at \(battery.level)% >= \(config.chargeStopThreshold)% — stop charging")
                transitionTo(.waiting, battery: battery, config: config)
            }
        }
    }

    func forceDisableCharging() {
        Self.logger.info("Force disabling charging (app quit)")
        helperProxy.disableCharging { [weak self] success, error in
            if !success {
                Self.logger.error("Failed to force-disable charging: \(error ?? "unknown")")
            }
            self?.activityLogger.log(.appTerminated, batteryLevel: -1, detail: "Charging re-enabled on quit")
        }
        state = .waiting
        lastTransition = Date()
    }

    private func transitionTo(_ newState: ChargeState, battery: BatteryState, config: ChargeConfig) {
        let oldState = state
        state = newState
        lastTransition = Date()
        lastError = nil
        isTransitioning = true

        let level = battery.level
        let stopThreshold = config.chargeStopThreshold
        let startThreshold = config.chargeStartThreshold

        switch newState {
        case .charging:
            helperProxy.enableCharging { [weak self] success, error in
                guard let self = self else { return }
                self.isTransitioning = false
                if success {
                    self.notificationManager.send(
                        title: "Charging Started",
                        body: "Battery at \(level)% — charging to \(stopThreshold)%"
                    )
                    self.activityLogger.log(.chargingStarted, batteryLevel: level,
                        detail: "Charging to \(stopThreshold)%")
                } else {
                    let msg = error ?? "Unknown error"
                    Self.logger.error("Enable charging failed: \(msg)")
                    self.lastError = msg
                    self.activityLogger.log(.helperError, batteryLevel: level,
                        detail: "Failed to enable charging: \(msg)")
                }
            }

        case .waiting:
            helperProxy.disableCharging { [weak self] success, error in
                guard let self = self else { return }
                self.isTransitioning = false
                if success {
                    let reason = oldState == .charging
                        ? "Battery reached \(stopThreshold)%"
                        : "Battery above \(startThreshold)%"
                    self.notificationManager.send(title: "Charging Paused", body: reason)
                    self.activityLogger.log(.chargingStopped, batteryLevel: level, detail: reason)
                } else {
                    let msg = error ?? "Unknown error"
                    Self.logger.error("Disable charging failed: \(msg)")
                    self.lastError = msg
                    self.activityLogger.log(.helperError, batteryLevel: level,
                        detail: "Failed to disable charging: \(msg)")
                }
            }
        }
    }
}
