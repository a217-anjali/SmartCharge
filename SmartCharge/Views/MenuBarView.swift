import SwiftUI

struct MenuBarView: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var stateMachine: ChargeStateMachine
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        Group {
            Text("SmartCharge")
                .font(.headline)

            Divider()

            LabeledItem("Battery", value: batteryMonitor.batteryState.levelDescription)
            LabeledItem("Power", value: batteryMonitor.batteryState.statusDescription)
            LabeledItem("Control", value: stateMachine.state.description)
            LabeledItem("Start At", value: "\u{2264} \(configStore.config.chargeStartThreshold)%")
            LabeledItem("Stop At", value: "\u{2265} \(configStore.config.chargeStopThreshold)%")

            if let health = batteryMonitor.batteryState.batteryHealth {
                LabeledItem("Health", value: health)
            }

            if let cycles = batteryMonitor.batteryState.cycleCount {
                LabeledItem("Cycles", value: "\(cycles)")
            }

            if let lastTransition = stateMachine.lastTransition {
                LabeledItem("Last Change", value: lastTransition.formatted(date: .omitted, time: .shortened))
            }

            if let newVersion = updateChecker.updateAvailable {
                Divider()
                Button("Update Available: v\(newVersion)") {
                    NSWorkspace.shared.open(updateChecker.releaseURL)
                }
            }

            Divider()

            Button("Open SmartCharge Window") {
                NSApp.activate(ignoringOtherApps: true)
            }

            Button("Check for Updates...") {
                updateChecker.checkForUpdate()
            }

            Button("Settings...") {
                if #available(macOS 14.0, *) {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } else {
                    NSApp.sendAction(Selector(("showPreferencesWindow:")), to: nil, from: nil)
                }
                NSApp.activate(ignoringOtherApps: true)
            }
            .keyboardShortcut(",", modifiers: .command)

            Divider()

            Button("Quit SmartCharge") {
                stateMachine.forceDisableCharging()
                NSApp.terminate(nil)
            }
            .keyboardShortcut("q", modifiers: .command)
        }
    }
}

private struct LabeledItem: View {
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
