import Foundation

enum L10n {
    static let appName = NSLocalizedString("SmartCharge", comment: "App name")
    static let chargingStarted = NSLocalizedString("Charging Started", comment: "Notification title")
    static let chargingStopped = NSLocalizedString("Charging Paused", comment: "Notification title")
    static let settings = NSLocalizedString("Settings", comment: "Settings button")
    static let batteryLevel = NSLocalizedString("Battery Level", comment: "Stat card title")
    static let powerSource = NSLocalizedString("Power Source", comment: "Stat card title")
    static let chargeControl = NSLocalizedString("Charge Control", comment: "Stat card title")
    static let health = NSLocalizedString("Health", comment: "Stat card title")
    static let activityLog = NSLocalizedString("Activity Log", comment: "Section title")
    static let checkForUpdates = NSLocalizedString("Check for Updates", comment: "Button title")
    static let startChargingAt = NSLocalizedString("Start charging at", comment: "Threshold label")
    static let stopChargingAt = NSLocalizedString("Stop charging at", comment: "Threshold label")
    static let plugInReminder = NSLocalizedString("Plug in your charger — SmartCharge manages charging automatically while plugged in.", comment: "Info banner")
    // Profiles
    static let home = NSLocalizedString("Home", comment: "Profile name")
    static let travel = NSLocalizedString("Travel", comment: "Profile name")
    static let presentation = NSLocalizedString("Presentation", comment: "Profile name")
    static let balanced = NSLocalizedString("Balanced", comment: "Profile name")
}
