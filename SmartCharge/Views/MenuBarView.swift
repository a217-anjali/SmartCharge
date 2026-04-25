import SwiftUI

struct MenuBarView: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var stateMachine: ChargeStateMachine
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("SmartCharge")
                .font(.headline)

            Divider()

            LabeledRow("Battery", value: batteryMonitor.batteryState.levelDescription)
            LabeledRow("Power", value: batteryMonitor.batteryState.statusDescription)
            LabeledRow("Charge Control", value: stateMachine.state.description)
            LabeledRow("Start At", value: "≤ \(configStore.config.chargeStartThreshold)%")
            LabeledRow("Stop At", value: "≥ \(configStore.config.chargeStopThreshold)%")

            if let lastTransition = stateMachine.lastTransition {
                LabeledRow("Last Change", value: lastTransition.formatted(date: .omitted, time: .shortened))
            }

            if let newVersion = updateChecker.updateAvailable {
                Divider()
                Button("Update Available: v\(newVersion)") {
                    NSWorkspace.shared.open(updateChecker.releaseURL)
                }
                .foregroundStyle(.blue)
            }

            Divider()

            Button("Check for Updates...") {
                updateChecker.checkForUpdate()
            }

            Button("Settings...") {
                NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Button("Quit SmartCharge") {
                stateMachine.forceDisableCharging()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
        .padding(8)
    }
}

private struct LabeledRow: View {
    let label: String
    let value: String

    init(_ label: String, value: String) {
        self.label = label
        self.value = value
    }

    var body: some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .font(.system(.body, design: .rounded))
    }
}
