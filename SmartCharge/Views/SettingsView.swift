import SwiftUI
import ServiceManagement

struct SettingsView: View {
    @ObservedObject var configStore: ChargeConfigStore
    @State private var startThreshold: Double
    @State private var stopThreshold: Double
    @State private var showInvalidAlert = false

    init(configStore: ChargeConfigStore) {
        self.configStore = configStore
        _startThreshold = State(initialValue: Double(configStore.config.chargeStartThreshold))
        _stopThreshold = State(initialValue: Double(configStore.config.chargeStopThreshold))
    }

    var body: some View {
        Form {
            Section("Charge Thresholds") {
                VStack(alignment: .leading, spacing: 12) {
                    ThresholdSlider(
                        label: "Start charging at",
                        value: $startThreshold,
                        range: 5...50,
                        color: .orange
                    )
                    ThresholdSlider(
                        label: "Stop charging at",
                        value: $stopThreshold,
                        range: 50...100,
                        color: .green
                    )
                }
            }

            Section("General") {
                Toggle("Show notifications", isOn: $configStore.config.notificationsEnabled)
                Toggle("Launch at login", isOn: $configStore.config.launchAtLogin)
                    .onChange(of: configStore.config.launchAtLogin) { newValue in
                        setLaunchAtLogin(newValue)
                    }
            }

            Section {
                HStack {
                    Button("Reset to Defaults") {
                        configStore.reset()
                        startThreshold = Double(configStore.config.chargeStartThreshold)
                        stopThreshold = Double(configStore.config.chargeStopThreshold)
                    }

                    Spacer()

                    Button("Save") {
                        applyThresholds()
                    }
                    .keyboardShortcut(.return, modifiers: .command)
                    .buttonStyle(.borderedProminent)
                }
            }
        }
        .formStyle(.grouped)
        .frame(width: 400, height: 320)
        .alert("Invalid Thresholds", isPresented: $showInvalidAlert) {
            Button("OK") {}
        } message: {
            Text("Start threshold must be at least 10% below the stop threshold, with start between 5-50% and stop between 50-100%.")
        }
    }

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
    }

    private func setLaunchAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }
        } catch {
            print("Launch at login toggle failed: \(error)")
        }
    }
}

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
    }
}
