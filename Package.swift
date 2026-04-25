// swift-tools-version: 5.9
import PackageDescription

let package = Package(
    name: "SmartCharge",
    platforms: [.macOS(.v13)],
    targets: [
        .executableTarget(
            name: "SmartCharge",
            path: "SmartCharge",
            exclude: ["Info.plist", "SmartCharge.entitlements", "Resources", "homebrew", "Tests"],
            sources: [
                "SmartChargeApp.swift", "HelperProtocol.swift",
                "Core/ActivityLogger.swift", "Core/BatteryMonitor.swift",
                "Core/ChargeHistory.swift", "Core/ChargeStateMachine.swift",
                "Core/CSVExporter.swift", "Core/GlobalShortcuts.swift",
                "Core/HelperProxy.swift", "Core/NotificationManager.swift",
                "Core/SparkleUpdateManager.swift", "Core/UpdateChecker.swift",
                "Models/BatteryState.swift", "Models/ChargeConfig.swift",
                "Models/ChargeEvent.swift", "Models/ChargingProfile.swift",
                "Views/ChargeEstimationView.swift", "Views/ChargeHistoryView.swift",
                "Views/LocalizationStrings.swift", "Views/MainWindow.swift",
                "Views/MenuBarView.swift", "Views/OnboardingView.swift",
                "Views/ProfilePickerView.swift", "Views/SettingsView.swift",
                "Views/TemperatureGaugeView.swift"
            ],
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
