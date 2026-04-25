import SwiftUI
import Combine
import os

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "AppDelegate")
    var onTerminate: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        Self.logger.info("App terminating")
        onTerminate?()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logger.info("SmartCharge launched")
    }
}

// MARK: - App Entry Point

@main
struct SmartChargeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var configStore = ChargeConfigStore()
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var helperProxy: HelperProxy
    @StateObject private var stateMachine: ChargeStateMachine
    @StateObject private var updateChecker = UpdateChecker()
    @StateObject private var activityLogger: ActivityLogger
    @StateObject private var coordinator = AppCoordinator()

    @State private var hasAppeared = false

    init() {
        let nm = NotificationManager()
        nm.requestPermission()
        let hp = HelperProxy()
        let al = ActivityLogger()
        let sm = ChargeStateMachine(helperProxy: hp, notificationManager: nm, activityLogger: al)

        _helperProxy = StateObject(wrappedValue: hp)
        _stateMachine = StateObject(wrappedValue: sm)
        _activityLogger = StateObject(wrappedValue: al)
    }

    var body: some Scene {
        Window("SmartCharge", id: "main") {
            MainWindow(
                batteryMonitor: batteryMonitor,
                stateMachine: stateMachine,
                configStore: configStore,
                updateChecker: updateChecker,
                helperProxy: helperProxy,
                activityLogger: activityLogger
            )
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true

                appDelegate.onTerminate = { [weak sm = stateMachine] in
                    sm?.forceDisableCharging()
                }

                coordinator.start(
                    batteryMonitor: batteryMonitor,
                    stateMachine: stateMachine,
                    configStore: configStore
                )
                updateChecker.checkForUpdate()
                activityLogger.log(.appLaunched, batteryLevel: batteryMonitor.batteryState.level,
                    detail: "SmartCharge v\(updateChecker.appVersion) started")
            }
        }
        .defaultSize(width: 560, height: 680)
        .commands {
            CommandGroup(replacing: .newItem) { }

            CommandGroup(replacing: .appInfo) {
                Button("About SmartCharge") {
                    NSApp.orderFrontStandardAboutPanel(options: [
                        .applicationName: "SmartCharge",
                        .applicationVersion: updateChecker.appVersion,
                        .version: "",
                        .credits: NSAttributedString(string: "Copyright © 2026 a217-anjali.\nMIT License.\n\nAutomatic battery charge management for macOS.")
                    ])
                }
            }

            CommandGroup(after: .appInfo) {
                Button("Check for Updates...") {
                    updateChecker.checkForUpdate()
                }
                .disabled(updateChecker.isChecking)

                Divider()
            }

            CommandMenu("View") {
                Button("Refresh Battery Status") {
                    batteryMonitor.refresh()
                }
                .keyboardShortcut("r", modifiers: .command)

                Divider()

                Button("Clear Activity Log") {
                    activityLogger.clearHistory()
                }
            }

            CommandGroup(replacing: .help) {
                Button("SmartCharge Help") {
                    if let url = URL(string: "https://github.com/a217-anjali/SmartCharge#readme") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Button("Visit GitHub Repository") {
                    if let url = URL(string: "https://github.com/a217-anjali/SmartCharge") {
                        NSWorkspace.shared.open(url)
                    }
                }
                Divider()
                Button("Report an Issue...") {
                    if let url = URL(string: "https://github.com/a217-anjali/SmartCharge/issues/new") {
                        NSWorkspace.shared.open(url)
                    }
                }
            }
        }

        MenuBarExtra {
            MenuBarView(
                batteryMonitor: batteryMonitor,
                stateMachine: stateMachine,
                configStore: configStore,
                updateChecker: updateChecker
            )
        } label: {
            Label(batteryMonitor.batteryState.menuBarTitle, systemImage: "bolt.batteryblock.fill")
        }

        Settings {
            SettingsView(configStore: configStore, activityLogger: activityLogger)
        }
    }
}

// MARK: - App Coordinator

@MainActor
final class AppCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var started = false
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "Coordinator")

    func start(
        batteryMonitor: BatteryMonitor,
        stateMachine: ChargeStateMachine,
        configStore: ChargeConfigStore
    ) {
        guard !started else { return }
        started = true

        batteryMonitor.start()

        batteryMonitor.$batteryState
            .combineLatest(configStore.$config)
            .sink { battery, config in
                stateMachine.evaluate(battery: battery, config: config)
            }
            .store(in: &cancellables)

        Self.logger.info("Coordinator started — monitoring battery and config changes")
    }
}
