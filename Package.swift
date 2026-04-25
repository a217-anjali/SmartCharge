// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartCharge",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SmartCharge",
            path: "SmartCharge",
            exclude: ["Info.plist", "SmartCharge.entitlements", "Resources"],
            sources: ["SmartChargeApp.swift", "HelperProtocol.swift",
                       "Views/MainWindow.swift", "Views/MenuBarView.swift", "Views/SettingsView.swift",
                       "Core/BatteryMonitor.swift", "Core/ChargeStateMachine.swift",
                       "Core/HelperProxy.swift", "Core/NotificationManager.swift",
                       "Core/UpdateChecker.swift", "Core/ActivityLogger.swift",
                       "Models/ChargeConfig.swift", "Models/BatteryState.swift",
                       "Models/ChargeEvent.swift"],
            linkerSettings: [
                .linkedFramework("IOKit"),
                .linkedFramework("ServiceManagement"),
                .linkedFramework("UserNotifications")
            ]
        ),
        .executableTarget(
            name: "SmartChargeHelper",
            path: "SmartChargeHelper",
            exclude: ["Info.plist", "launchd.plist"],
            sources: ["main.swift", "SMCKit.swift", "HelperProtocol.swift"],
            linkerSettings: [
                .linkedFramework("IOKit")
            ]
        )
    ]
)
