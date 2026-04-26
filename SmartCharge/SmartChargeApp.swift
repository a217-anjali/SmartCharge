import SwiftUI
import Combine
import os

class AppDelegate: NSObject, NSApplicationDelegate {
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "AppDelegate")
    var onTerminate: (() -> Void)?

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        Self.logger.info("App terminating")
        onTerminate?()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        Self.logger.info("SmartCharge launched")
    }
}

@main
struct SmartChargeApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    @StateObject private var configStore = ChargeConfigStore()
    @StateObject private var batteryMonitor = BatteryMonitor()
    @StateObject private var smcController: SMCController
    @StateObject private var stateMachine: ChargeStateMachine
    @StateObject private var updateChecker = UpdateChecker()
    @StateObject private var activityLogger: ActivityLogger
    @StateObject private var coordinator = AppCoordinator()
    @StateObject private var chargeHistory = ChargeHistory()
    @StateObject private var profileManager = ProfileManager()
    @StateObject private var globalShortcuts = GlobalShortcuts()

    @State private var hasAppeared = false
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    init() {
        let nm = NotificationManager()
        nm.requestPermission()
        let smc = SMCController()
        let al = ActivityLogger()
        let sm = ChargeStateMachine(smcController: smc, notificationManager: nm, activityLogger: al)

        _smcController = StateObject(wrappedValue: smc)
        _stateMachine = StateObject(wrappedValue: sm)
        _activityLogger = StateObject(wrappedValue: al)
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if hasCompletedOnboarding {
                    MainWindow(
                        batteryMonitor: batteryMonitor,
                        stateMachine: stateMachine,
                        configStore: configStore,
                        updateChecker: updateChecker,
                        smcController: smcController,
                        activityLogger: activityLogger,
                        chargeHistory: chargeHistory,
                        profileManager: profileManager
                    )
                } else {
                    OnboardingView(
                        hasCompletedOnboarding: $hasCompletedOnboarding,
                        configStore: configStore
                    )
                }
            }
            .onAppear {
                guard !hasAppeared else { return }
                hasAppeared = true

                if !smcController.open() {
                    activityLogger.log(.helperError, batteryLevel: -1,
                        detail: "Cannot open SMC — run app with sudo or install via .pkg")
                }

                appDelegate.onTerminate = { [weak sm = stateMachine] in
                    sm?.forceDisableCharging()
                }

                coordinator.start(
                    batteryMonitor: batteryMonitor,
                    stateMachine: stateMachine,
                    configStore: configStore,
                    chargeHistory: chargeHistory
                )

                globalShortcuts.onToggleCharging = { [weak smc = smcController] in
                    if smc?.isChargingEnabled() == true {
                        _ = smc?.disableCharging()
                    } else {
                        _ = smc?.enableCharging()
                    }
                }
                globalShortcuts.onShowWindow = {
                    NSApp.activate(ignoringOtherApps: true)
                }
                if globalShortcuts.shortcutsEnabled {
                    globalShortcuts.register()
                }

                updateChecker.checkForUpdate()
                activityLogger.log(.appLaunched, batteryLevel: batteryMonitor.batteryState.level,
                    detail: "SmartCharge v\(updateChecker.appVersion) started")
            }
        }
        .defaultSize(width: 580, height: 800)
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
                Button("Check for Updates...") { updateChecker.checkForUpdate() }
                    .disabled(updateChecker.isChecking)
                Divider()
            }

            CommandMenu("View") {
                Button("Refresh Battery Status") { batteryMonitor.refresh() }
                    .keyboardShortcut("r", modifiers: .command)
            }

            CommandGroup(replacing: .help) {
                Button("SmartCharge Help") {
                    if let u = URL(string: "https://github.com/a217-anjali/SmartCharge#readme") { NSWorkspace.shared.open(u) }
                }
                Button("Visit GitHub Repository") {
                    if let u = URL(string: "https://github.com/a217-anjali/SmartCharge") { NSWorkspace.shared.open(u) }
                }
                Divider()
                Button("Report an Issue...") {
                    if let u = URL(string: "https://github.com/a217-anjali/SmartCharge/issues/new") { NSWorkspace.shared.open(u) }
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
    }
}

@MainActor
final class AppCoordinator: ObservableObject {
    private var cancellables = Set<AnyCancellable>()
    private var started = false

    func start(
        batteryMonitor: BatteryMonitor,
        stateMachine: ChargeStateMachine,
        configStore: ChargeConfigStore,
        chargeHistory: ChargeHistory
    ) {
        guard !started else { return }
        started = true
        batteryMonitor.start()

        batteryMonitor.$batteryState
            .combineLatest(configStore.$config)
            .sink { battery, config in
                stateMachine.evaluate(battery: battery, config: config)
                chargeHistory.record(state: battery)
            }
            .store(in: &cancellables)
    }
}
