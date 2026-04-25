import Foundation
import Combine

enum ChargeState: String, CustomStringConvertible {
    case waiting = "Waiting"
    case charging = "Charging"

    var description: String { rawValue }
}

@MainActor
final class ChargeStateMachine: ObservableObject {
    @Published private(set) var state: ChargeState = .waiting
    @Published private(set) var lastTransition: Date?

    private let helperProxy: HelperProxy
    private let notificationManager: NotificationManager
    private var cancellables = Set<AnyCancellable>()

    init(helperProxy: HelperProxy, notificationManager: NotificationManager) {
        self.helperProxy = helperProxy
        self.notificationManager = notificationManager
    }

    func evaluate(battery: BatteryState, config: ChargeConfig) {
        guard battery.level >= 0 else { return }
        guard battery.isPluggedIn else { return }

        switch state {
        case .waiting:
            if battery.level <= config.chargeStartThreshold {
                transitionTo(.charging, battery: battery, config: config)
            }

        case .charging:
            if battery.level >= config.chargeStopThreshold {
                transitionTo(.waiting, battery: battery, config: config)
            }
        }
    }

    func forceDisableCharging() {
        helperProxy.disableCharging { success, error in
            if !success {
                print("Failed to disable charging: \(error ?? "unknown")")
            }
        }
        state = .waiting
        lastTransition = Date()
    }

    private func transitionTo(_ newState: ChargeState, battery: BatteryState, config: ChargeConfig) {
        let oldState = state
        state = newState
        lastTransition = Date()

        switch newState {
        case .charging:
            helperProxy.enableCharging { [weak self] success, error in
                if success {
                    self?.notificationManager.send(
                        title: "Charging Started",
                        body: "Battery at \(battery.level)% — charging to \(config.chargeStopThreshold)%"
                    )
                } else {
                    print("Failed to enable charging: \(error ?? "unknown")")
                }
            }

        case .waiting:
            helperProxy.disableCharging { [weak self] success, error in
                if success {
                    let reason = oldState == .charging
                        ? "Battery reached \(config.chargeStopThreshold)%"
                        : "Battery above \(config.chargeStartThreshold)%"
                    self?.notificationManager.send(
                        title: "Charging Paused",
                        body: reason
                    )
                } else {
                    print("Failed to disable charging: \(error ?? "unknown")")
                }
            }
        }
    }
}
