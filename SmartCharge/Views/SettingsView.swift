import SwiftUI
import ServiceManagement
import UniformTypeIdentifiers

struct ConfigDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }
    var data: Data

    init(data: Data) { self.data = data }

    init(configuration: ReadConfiguration) throws {
        guard let d = configuration.file.regularFileContents else { throw CocoaError(.fileReadCorruptFile) }
        self.data = d
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}

struct SettingsView: View {
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var activityLogger: ActivityLogger
    @Binding var isPresented: Bool

    @State private var startThreshold: Double
    @State private var stopThreshold: Double
    @State private var showInvalidAlert = false
    @State private var showResetAlert = false
    @State private var showExporter = false
    @State private var showImporter = false
    @State private var exportDocument: ConfigDocument?
    @State private var alertMessage = ""
    @State private var showAlert = false

    init(configStore: ChargeConfigStore, activityLogger: ActivityLogger, isPresented: Binding<Bool>) {
        self.configStore = configStore
        self.activityLogger = activityLogger
        self._isPresented = isPresented
        _startThreshold = State(initialValue: Double(configStore.config.chargeStartThreshold))
        _stopThreshold = State(initialValue: Double(configStore.config.chargeStopThreshold))
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("Settings").font(.title2.bold())
                Spacer()
                Button("Done") { isPresented = false }
                    .buttonStyle(.borderedProminent)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            TabView {
                thresholdsTab.tabItem { Label("Thresholds", systemImage: "battery.75") }
                generalTab.tabItem { Label("General", systemImage: "gearshape") }
                advancedTab.tabItem { Label("Advanced", systemImage: "wrench.and.screwdriver") }
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .frame(width: 480, height: 420)
        .alert("Invalid Thresholds", isPresented: $showInvalidAlert) {
            Button("OK") {}
        } message: {
            Text("Start must be at least 10% below stop.\nStart: 5-50% / Stop: 50-100%")
        }
        .alert("Reset to Defaults?", isPresented: $showResetAlert) {
            Button("Reset", role: .destructive) {
                configStore.reset()
                startThreshold = Double(configStore.config.chargeStartThreshold)
                stopThreshold = Double(configStore.config.chargeStopThreshold)
                activityLogger.log(.configChanged, batteryLevel: -1, detail: "Reset to defaults")
            }
            Button("Cancel", role: .cancel) {}
        }
        .alert(alertMessage, isPresented: $showAlert) { Button("OK") {} }
        .fileExporter(isPresented: $showExporter, document: exportDocument, contentType: .json,
                      defaultFilename: "smartcharge-config.json") { result in
            if case .failure(let e) = result { alertMessage = e.localizedDescription; showAlert = true }
            else { alertMessage = "Config exported successfully."; showAlert = true }
        }
        .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json], allowsMultipleSelection: false) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                let accessing = url.startAccessingSecurityScopedResource()
                defer { if accessing { url.stopAccessingSecurityScopedResource() } }
                do {
                    try configStore.importFromFile(url: url)
                    startThreshold = Double(configStore.config.chargeStartThreshold)
                    stopThreshold = Double(configStore.config.chargeStopThreshold)
                    activityLogger.log(.configChanged, batteryLevel: -1, detail: "Config imported")
                    alertMessage = "Config imported successfully."; showAlert = true
                } catch {
                    alertMessage = "Import failed: \(error.localizedDescription)"; showAlert = true
                }
            case .failure(let e):
                alertMessage = "Import failed: \(e.localizedDescription)"; showAlert = true
            }
        }
    }

    // MARK: - Thresholds

    private var thresholdsTab: some View {
        Form {
            Section("Charge Thresholds") {
                VStack(alignment: .leading, spacing: 14) {
                    SliderRow(label: "Start charging at", value: $startThreshold, range: 5...50, color: .orange)
                    Text("Charging begins when battery drops to this level.").font(.caption).foregroundStyle(.secondary)
                    Divider()
                    SliderRow(label: "Stop charging at", value: $stopThreshold, range: 50...100, color: .green)
                    Text("Charging stops when battery reaches this level.").font(.caption).foregroundStyle(.secondary)
                }
            }
            Section {
                Text("Gap must be at least 10% to prevent rapid cycling.").font(.caption).foregroundStyle(.secondary)
                HStack {
                    Button("Reset to Defaults") { showResetAlert = true }.buttonStyle(.bordered)
                    Spacer()
                    Button("Apply") { applyThresholds() }.buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - General

    private var generalTab: some View {
        Form {
            Section("Notifications") {
                Toggle("Show desktop notifications", isOn: $configStore.config.notificationsEnabled)
            }
            Section("Startup") {
                Toggle("Launch at login", isOn: $configStore.config.launchAtLogin)
                    .onChange(of: configStore.config.launchAtLogin) { v in setLaunchAtLogin(v) }
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Advanced

    private var advancedTab: some View {
        Form {
            Section("Configuration") {
                HStack {
                    Button("Export...") {
                        if let d = configStore.config.toJSON() { exportDocument = ConfigDocument(data: d); showExporter = true }
                    }.buttonStyle(.bordered)
                    Spacer()
                    Button("Import...") { showImporter = true }.buttonStyle(.bordered)
                }
            }
            Section("Activity") {
                HStack {
                    Text("\(activityLogger.events.count) events logged")
                    Spacer()
                    Button("Clear") { activityLogger.clearHistory() }.buttonStyle(.bordered)
                }
            }
            Section("About") {
                LabeledContent("Version", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0.0")
                LabeledContent("License", value: "MIT")
            }
        }
        .formStyle(.grouped)
    }

    // MARK: - Actions

    private func applyThresholds() {
        let c = ChargeConfig(chargeStartThreshold: Int(startThreshold), chargeStopThreshold: Int(stopThreshold),
                             notificationsEnabled: configStore.config.notificationsEnabled, launchAtLogin: configStore.config.launchAtLogin)
        guard c.isValid else { showInvalidAlert = true; return }
        configStore.config = c
        activityLogger.log(.configChanged, batteryLevel: -1, detail: "Thresholds: \(Int(startThreshold))%-\(Int(stopThreshold))%")
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        try? enabled ? SMAppService.mainApp.register() : SMAppService.mainApp.unregister()
    }
}

private struct SliderRow: View {
    let label: String; @Binding var value: Double; let range: ClosedRange<Double>; let color: Color
    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                Text(label)
                Spacer()
                Text("\(Int(value))%").fontWeight(.semibold).foregroundStyle(color).monospacedDigit()
            }
            Slider(value: $value, in: range, step: 1).tint(color)
        }
    }
}
