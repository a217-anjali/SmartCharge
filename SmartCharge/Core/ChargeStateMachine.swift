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

    private let smcController: SMCController
    private let notificationManager: NotificationManager
    private let activityLogger: ActivityLogger
    private var isTransitioning = false
    private var hasEnforcedInitialState = false
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "StateMachine")

    init(smcController: SMCController, notificationManager: NotificationManager, activityLogger: ActivityLogger) {
        self.smcController = smcController
        self.notificationManager = notificationManager
        self.activityLogger = activityLogger
    }

    func evaluate(battery: BatteryState, config: ChargeConfig) {
        guard battery.level >= 0, battery.isPluggedIn else { return }
        guard !isTransitioning else { return }

        if !hasEnforcedInitialState {
            hasEnforcedInitialState = true
            if battery.level <= config.chargeStartThreshold {
                Self.logger.info("Startup: battery at \(battery.level)% <= \(config.chargeStartThreshold)% — enabling charging")
                performTransition(to: .charging, battery: battery, config: config, reason: "Startup: below threshold")
            } else {
                Self.logger.info("Startup: battery at \(battery.level)% — disabling charging until \(config.chargeStartThreshold)%")
                performTransition(to: .waiting, battery: battery, config: config, reason: "Startup: charging paused at \(battery.level)%")
            }
            return
        }

        switch state {
        case .waiting:
            if battery.level <= config.chargeStartThreshold {
                Self.logger.info("Battery \(battery.level)% <= \(config.chargeStartThreshold)% — start charging")
                performTransition(to: .charging, battery: battery, config: config, reason: "Battery dropped to \(battery.level)%")
            }
        case .charging:
            if battery.level >= config.chargeStopThreshold {
                Self.logger.info("Battery \(battery.level)% >= \(config.chargeStopThreshold)% — stop charging")
                performTransition(to: .waiting, battery: battery, config: config, reason: "Battery reached \(config.chargeStopThreshold)%")
            }
        }
    }

    func forceDisableCharging() {
        let success = smcController.enableCharging()
        Self.logger.info("App terminating — re-enabled charging: \(success)")
        activityLogger.log(.appTerminated, batteryLevel: -1, detail: "Charging re-enabled on quit")
    }

    private func performTransition(to newState: ChargeState, battery: BatteryState, config: ChargeConfig, reason: String) {
        state = newState
        lastTransition = Date()
        lastError = nil

        let success: Bool
        switch newState {
        case .charging:
            success = smcController.enableCharging()
            if success {
                notificationManager.send(title: "Charging Started", body: "Battery at \(battery.level)% — charging to \(config.chargeStopThreshold)%")
                activityLogger.log(.chargingStarted, batteryLevel: battery.level, detail: reason)
            }
        case .waiting:
            success = smcController.disableCharging(atLevel: battery.level)
            if success {
                notificationManager.send(title: "Charging Paused", body: reason)
                activityLogger.log(.chargingStopped, batteryLevel: battery.level, detail: reason)
            }
        }

        if !success {
            let msg = smcController.lastError ?? "SMC write failed"
            Self.logger.error("Transition to \(newState.rawValue) failed: \(msg)")
            lastError = msg
            activityLogger.log(.helperError, batteryLevel: battery.level, detail: msg)
        }
    }
}
