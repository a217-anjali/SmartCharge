import SwiftUI
import Combine

@main
struct SmartChargeApp: App {
    @StateObject private var configStore = ChargeConfigStore()
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var helperProxy = HelperProxy()
    @StateObject private var stateMachine: ChargeStateMachine

    private let notificationManager = NotificationManager()
    private var cancellables = Set<AnyCancellable>()

    init() {
        let nm = NotificationManager()
        nm.requestPermission()
        let hp = HelperProxy()
        let sm = ChargeStateMachine(helperProxy: hp, notificationManager: nm)

        _helperProxy = StateObject(wrappedValue: hp)
        _stateMachine = StateObject(wrappedValue: sm)

        // Can't store nm in a let since self isn't fully initialized.
        // It's captured by the state machine and stays alive through it.
    }

    var body: some Scene {
        MenuBarExtra {
            MenuBarView(
                batteryMonitor: batteryMonitor,
                stateMachine: stateMachine,
                configStore: configStore
            )
        } label: {
            Text(batteryMonitor.batteryState.menuBarTitle)
        }

        Settings {
            SettingsView(configStore: configStore)
        }
    }
}

/// Glue that runs the monitor loop and feeds battery state into the state machine.
@MainActor
final class AppCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()

    func start(
        batteryMonitor: BatteryMonitor,
        stateMachine: ChargeStateMachine,
        configStore: ChargeConfigStore
    ) {
        batteryMonitor.start()

        batteryMonitor.$batteryState
            .combineLatest(configStore.$config)
            .sink { battery, config in
                stateMachine.evaluate(battery: battery, config: config)
            }
            .store(in: &cancellables)
    }
}
