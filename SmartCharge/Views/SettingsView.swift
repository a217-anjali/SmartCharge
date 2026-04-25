import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct SettingsView: View {
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var activityLogger: ActivityLogger
    @State private var startThreshold: Double
    @State private var stopThreshold: Double
    @State private var showInvalidAlert = false
    @State private var showResetConfirmation = false
    @State private var showExportSuccess = false
    @State private var showImportError = false
    @State private var importErrorMessage = ""

    init(configStore: ChargeConfigStore, activityLogger: ActivityLogger) {
        self.configStore = configStore
        self.activityLogger = activityLogger
        _startThreshold = State(initialValue: Double(configStore.config.chargeStartThreshold))
        _stopThreshold = State(initialValue: Double(configStore.config.chargeStopThreshold))
    }

    var body: some View {
        TabView {
            generalTab
                .tabItem { Label("General", systemImage: "gearshape") }

            thresholdsTab
                .tabItem { Label("Thresholds", systemImage: "battery.75") }

            advancedTab
                .tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
        }
        .frame(width: 480, height: 380)
    }

    // MARK: - General Tab

    private var generalTab: some View {
        Form {
            Section("Notifications") {
                Toggle("Show desktop notifications", isOn: $configStore.config.notificationsEnabled)
                Text("Get notified when charging starts and stops.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Startup") {
                Toggle("Launch SmartCharge at login", isOn: $configStore.config.launchAtLogin)
                    .onChange(of: configStore.config.launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
                Text("SmartCharge will start automatically when you log in.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Thresholds Tab

    private var thresholdsTab: some View {
        Form {
            Section("Charge Thresholds") {
                VStack(alignment: .leading, spacing: 16) {
                    ThresholdSlider(
                        label: "Start charging at",
                        value: $startThreshold,
                        range: 5...50,
                        color: .orange
                    )
                    Text("Charging begins when battery drops to this level.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Divider()

                    ThresholdSlider(
                        label: "Stop charging at",
                        value: $stopThreshold,
                        range: 50...100,
                        color: .green
                    )
                    Text("Charging stops when battery reaches this level.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                Text("The gap between start and stop must be at least 10% to prevent rapid on/off cycling which can damage the battery controller.")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                HStack {
                    Button("Reset to Defaults") {
                        showResetConfirmation = true
                    }
                    .confirmationDialog("Reset all thresholds to defaults?", isPresented: $showResetConfirmation) {
                        Button("Reset", role: .destructive) {
                            configStore.reset()
                            startThreshold = Double(configStore.config.chargeStartThreshold)
                            stopThreshold = Double(configStore.config.chargeStopThreshold)
                            activityLogger.log(.configChanged, batteryLevel: -1, detail: "Config reset to defaults")
                        }
                        Button("Cancel", role: .cancel) {}
                    }

                    Spacer()

                    Button("Apply") {
                        applyThresholds()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .alert("Invalid Thresholds", isPresented: $showInvalidAlert) {
            Button("OK") {}
        } message: {
            Text("Start threshold must be at least 10% below the stop threshold.\n\nStart: 5–50%\nStop: 50–100%")
        }
    }

    // MARK: - Advanced Tab

    private var advancedTab: some View {
        Form {
            Section("Configuration") {
                HStack {
                    Button("Export Config...") {
                        exportConfig()
                    }
                    Text("Save your settings to a JSON file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Import Config...") {
                        importConfig()
                    }
                    Text("Load settings from a JSON file.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Activity") {
                HStack {
                    Text("Events logged: \(activityLogger.events.count)")
                        .font(.callout)
                    Spacer()
                    Button("Clear History") {
                        activityLogger.clearHistory()
                    }
                }
            }

            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                LabeledContent("Bundle ID", value: "com.smartcharge.app")
                LabeledContent("Minimum macOS", value: "13.0 Ventura")
                LabeledContent("License", value: "MIT")
            }
        }
        .formStyle(.grouped)
        .alert("Export Successful", isPresented: $showExportSuccess) {
            Button("OK") {}
        } message: {
            Text("Configuration saved successfully.")
        }
        .alert("Import Failed", isPresented: $showImportError) {
            Button("OK") {}
        } message: {
            Text(importErrorMessage)
        }
    }

    // MARK: - Actions

    private func applyThresholds() {
        let start = Int(startThreshold)
        let stop = Int(stopThreshold)

        let candidate = ChargeConfig(
            chargeStartThreshold: start,
            chargeStopThreshold: stop,
            notificationsEnabled: configStore.config.notificationsEnabled,
            launchAtLogin: configStore.config.launchAtLogin
        )

        guard candidate.isValid else {
            showInvalidAlert = true
            return
        }

        configStore.config = candidate
        activityLogger.log(.configChanged, batteryLevel: -1, detail: "Thresholds set to \(start)%–\(stop)%")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            // Silently handle — the toggle will still update the local setting
        }
    }

    private func exportConfig() {
        let panel = NSSavePanel()
        panel.title = "Export SmartCharge Configuration"
        panel.nameFieldStringValue = "smartcharge-config.json"
        panel.allowedContentTypes = [.json]

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try configStore.exportToFile(url: url)
            showExportSuccess = true
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }

    private func importConfig() {
        let panel = NSOpenPanel()
        panel.title = "Import SmartCharge Configuration"
        panel.allowedContentTypes = [.json]
        panel.allowsMultipleSelection = false

        guard panel.runModal() == .OK, let url = panel.url else { return }

        do {
            try configStore.importFromFile(url: url)
            startThreshold = Double(configStore.config.chargeStartThreshold)
            stopThreshold = Double(configStore.config.chargeStopThreshold)
            activityLogger.log(.configChanged, batteryLevel: -1, detail: "Config imported from file")
        } catch {
            importErrorMessage = error.localizedDescription
            showImportError = true
        }
    }
}

// MARK: - Threshold Slider

private struct ThresholdSlider: View {
    let label: String
    @Binding var value: Double
    let range: ClosedRange<Double>
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value))%")
                    .fontWeight(.semibold)
                    .foregroundStyle(color)
                    .monospacedDigit()
            }
            Slider(value: $value, in: range, step: 1)
                .tint(color)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(label): \(Int(value)) percent")
    }
}
