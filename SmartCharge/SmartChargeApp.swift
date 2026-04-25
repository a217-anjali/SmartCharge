import SwiftUI
import Combine

@main
struct SmartChargeApp: App {
    @StateObject private var configStore = ChargeConfigStore()
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var helperProxy = HelperProxy()
    @StateObject private var stateMachine: ChargeStateMachine
    @StateObject private var updateChecker = UpdateChecker()
    @StateObject private var coordinator = AppCoordinator()

    init() {
        let nm = NotificationManager()
        nm.requestPermission()
        let hp = HelperProxy()
        let sm = ChargeStateMachine(helperProxy: hp, notificationManager: nm)

        _helperProxy = StateObject(wrappedValue: hp)
        _stateMachine = StateObject(wrappedValue: sm)
    }

    var body: some Scene {
        WindowGroup {
            MainWindow(
                batteryMonitor: batteryMonitor,
                stateMachine: stateMachine,
                configStore: configStore,
                updateChecker: updateChecker
            )
            .onAppear {
                coordinator.start(
                    batteryMonitor: batteryMonitor,
                    stateMachine: stateMachine,
                    configStore: configStore
                )
                updateChecker.checkForUpdate()
            }
            .frame(minWidth: 520, minHeight: 560)
        }
        .windowResizability(.contentSize)

        Settings {
            SettingsView(configStore: configStore)
        }
    }
}

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
