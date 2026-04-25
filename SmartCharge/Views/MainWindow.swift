import SwiftUI

struct MainWindow: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var stateMachine: ChargeStateMachine
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var updateChecker: UpdateChecker

    var body: some View {
        VStack(spacing: 0) {
            headerSection
            Divider()
            batteryVisualization
            Divider()
            statusSection
            Divider()
            thresholdControls
            Spacer(minLength: 12)
            footerSection
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SmartCharge")
                    .font(.title.bold())
                Text("Automatic battery charge management")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            statusBadge
        }
        .padding(.bottom, 16)
    }

    private var statusBadge: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(statusColor)
                .frame(width: 10, height: 10)
            Text(stateMachine.state.description)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(statusColor.opacity(0.12), in: Capsule())
    }

    private var statusColor: Color {
        switch stateMachine.state {
        case .charging: return .green
        case .waiting: return .orange
        }
    }

    // MARK: - Battery Visualization

    private var batteryVisualization: some View {
        VStack(spacing: 16) {
            ZStack {
                BatteryShape(level: batteryMonitor.batteryState.level, config: configStore.config)
                    .frame(height: 120)
            }
            .padding(.vertical, 20)

            HStack(spacing: 32) {
                StatCard(
                    title: "Battery Level",
                    value: batteryMonitor.batteryState.levelDescription,
                    icon: "battery.100",
                    color: batteryLevelColor
                )
                StatCard(
                    title: "Power Source",
                    value: batteryMonitor.batteryState.isPluggedIn ? "Plugged In" : "Battery",
                    icon: batteryMonitor.batteryState.isPluggedIn ? "powerplug.fill" : "bolt.slash",
                    color: batteryMonitor.batteryState.isPluggedIn ? .green : .gray
                )
                StatCard(
                    title: "Charge Control",
                    value: stateMachine.state.rawValue,
                    icon: stateMachine.state == .charging ? "bolt.fill" : "pause.circle",
                    color: statusColor
                )
            }
        }
        .padding(.vertical, 12)
    }

    private var batteryLevelColor: Color {
        let level = batteryMonitor.batteryState.level
        if level <= 20 { return .red }
        if level <= 50 { return .orange }
        return .green
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.headline)
                .padding(.top, 12)

            HStack {
                InfoRow(label: "Current Action", value: currentActionDescription)
                Spacer()
                if let lastTransition = stateMachine.lastTransition {
                    InfoRow(label: "Last Change", value: lastTransition.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if !batteryMonitor.batteryState.isPluggedIn {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill")
                        .foregroundStyle(.blue)
                    Text("Plug in your charger — SmartCharge manages charging automatically while plugged in.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
        .padding(.bottom, 12)
    }

    private var currentActionDescription: String {
        let level = batteryMonitor.batteryState.level
        guard batteryMonitor.batteryState.isPluggedIn else {
            return "Not plugged in"
        }
        switch stateMachine.state {
        case .charging:
            return "Charging until \(configStore.config.chargeStopThreshold)%"
        case .waiting:
            if level >= configStore.config.chargeStopThreshold {
                return "Fully charged — holding at \(level)%"
            }
            return "Waiting until battery drops to \(configStore.config.chargeStartThreshold)%"
        }
    }

    // MARK: - Threshold Controls

    private var thresholdControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Charge Thresholds")
                .font(.headline)
                .padding(.top, 12)

            HStack(spacing: 24) {
                ThresholdBadge(
                    label: "Start At",
                    value: configStore.config.chargeStartThreshold,
                    color: .orange,
                    icon: "bolt.fill"
                )
                ThresholdBadge(
                    label: "Stop At",
                    value: configStore.config.chargeStopThreshold,
                    color: .green,
                    icon: "bolt.slash.fill"
                )
                Spacer()
                Button("Settings...") {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if let newVersion = updateChecker.updateAvailable {
                Button("Update Available: v\(newVersion)") {
                    NSWorkspace.shared.open(updateChecker.releaseURL)
                }
                .foregroundStyle(.blue)
            } else {
                Text("v1.0.0")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            Spacer()
            Button("Check for Updates") {
                updateChecker.checkForUpdate()
            }
            .buttonStyle(.borderless)
            .font(.caption)
        }
        .padding(.top, 8)
    }
}

// MARK: - Battery Shape Visualization

private struct BatteryShape: View {
    let level: Int
    let config: ChargeConfig

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let bodyWidth = width - 20
            let fillWidth = max(0, bodyWidth * CGFloat(max(0, level)) / 100.0)
            let startX = bodyWidth * CGFloat(config.chargeStartThreshold) / 100.0
            let stopX = bodyWidth * CGFloat(config.chargeStopThreshold) / 100.0

            ZStack(alignment: .leading) {
                // Battery outline
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    .frame(width: bodyWidth, height: height)

                // Battery tip
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 8, height: height * 0.4)
                    .offset(x: bodyWidth + 2)

                // Threshold zone (green band)
                Rectangle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: stopX - startX, height: height - 4)
                    .offset(x: startX + 2)

                // Current level fill
                RoundedRectangle(cornerRadius: 10)
                    .fill(fillGradient)
                    .frame(width: max(0, fillWidth - 4), height: height - 4)
                    .offset(x: 2)

                // Start threshold marker
                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: height)
                    .offset(x: startX)

                // Stop threshold marker
                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: height)
                    .offset(x: stopX)

                // Level label
                Text("\(max(0, level))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: bodyWidth, height: height)

                // Threshold labels
                Text("\(config.chargeStartThreshold)%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.orange)
                    .offset(x: startX - 10, y: height / 2 + 12)

                Text("\(config.chargeStopThreshold)%")
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.green)
                    .offset(x: stopX - 10, y: height / 2 + 12)
            }
        }
    }

    private var fillGradient: LinearGradient {
        let color: Color = level <= 20 ? .red : (level <= 50 ? .orange : .green)
        return LinearGradient(
            colors: [color.opacity(0.7), color.opacity(0.4)],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Stat Card

private struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.title3, design: .rounded, weight: .semibold))
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.medium))
        }
    }
}

// MARK: - Threshold Badge

private struct ThresholdBadge: View {
    let label: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("\(value)%")
                    .font(.body.weight(.semibold).monospacedDigit())
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
