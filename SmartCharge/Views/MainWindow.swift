import SwiftUI

struct MainWindow: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var stateMachine: ChargeStateMachine
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var updateChecker: UpdateChecker
    @ObservedObject var helperProxy: HelperProxy
    @ObservedObject var activityLogger: ActivityLogger

    @State private var showActivityLog = false

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                errorBanner
                headerSection
                Divider().padding(.horizontal)
                batteryVisualization
                Divider().padding(.horizontal)
                statsGrid
                Divider().padding(.horizontal)
                statusSection
                Divider().padding(.horizontal)
                thresholdControls
                Divider().padding(.horizontal)
                activityLogSection
                Spacer(minLength: 8)
                footerSection
            }
            .padding()
        }
        .background(Color(nsColor: .windowBackgroundColor))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("SmartCharge main window")
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        let error = stateMachine.lastError ?? helperProxy.lastError
        if let error = error {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
                    .lineLimit(2)
                Spacer()
                Button("Dismiss") {
                    stateMachine.lastError = nil
                    helperProxy.lastError = nil
                }
                .buttonStyle(.borderless)
                .foregroundStyle(.white.opacity(0.9))
            }
            .font(.callout)
            .foregroundStyle(.white)
            .padding(12)
            .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 10))
            .padding(.bottom, 12)
            .transition(.move(edge: .top).combined(with: .opacity))
            .accessibilityLabel("Error: \(error)")
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("SmartCharge")
                    .font(.largeTitle.bold())
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
                .shadow(color: statusColor.opacity(0.5), radius: 4)
            Text(stateMachine.state.description)
                .font(.subheadline.weight(.medium))
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(statusColor.opacity(0.12), in: Capsule())
        .animation(.easeInOut(duration: 0.4), value: stateMachine.state)
        .accessibilityLabel("Charge state: \(stateMachine.state.description)")
    }

    private var statusColor: Color {
        switch stateMachine.state {
        case .charging: return .green
        case .waiting: return .orange
        }
    }

    // MARK: - Battery Visualization

    private var batteryVisualization: some View {
        BatteryShape(level: batteryMonitor.batteryState.level, config: configStore.config)
            .frame(height: 110)
            .padding(.vertical, 20)
            .animation(.easeInOut(duration: 0.8), value: batteryMonitor.batteryState.level)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Battery level \(batteryMonitor.batteryState.levelDescription)")
            .accessibilityValue("Charge zone \(configStore.config.chargeStartThreshold) to \(configStore.config.chargeStopThreshold) percent")
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        LazyVGrid(columns: [
            GridItem(.flexible()), GridItem(.flexible()),
            GridItem(.flexible()), GridItem(.flexible())
        ], spacing: 12) {
            StatCard(
                title: "Battery",
                value: batteryMonitor.batteryState.levelDescription,
                icon: batteryIcon,
                color: batteryLevelColor
            )
            StatCard(
                title: "Power",
                value: batteryMonitor.batteryState.isPluggedIn ? "Plugged In" : "Battery",
                icon: batteryMonitor.batteryState.isPluggedIn ? "powerplug.fill" : "bolt.slash",
                color: batteryMonitor.batteryState.isPluggedIn ? .green : .gray
            )
            StatCard(
                title: "Control",
                value: stateMachine.state.rawValue,
                icon: stateMachine.state == .charging ? "bolt.fill" : "pause.circle",
                color: statusColor
            )
            StatCard(
                title: "Health",
                value: batteryMonitor.batteryState.healthDescription,
                icon: "heart.fill",
                color: healthColor
            )
        }
        .padding(.vertical, 16)
    }

    private var batteryIcon: String {
        let level = batteryMonitor.batteryState.level
        if level >= 75 { return "battery.100" }
        if level >= 50 { return "battery.75" }
        if level >= 25 { return "battery.50" }
        return "battery.25"
    }

    private var batteryLevelColor: Color {
        let level = batteryMonitor.batteryState.level
        if level <= 20 { return .red }
        if level <= 50 { return .orange }
        return .green
    }

    private var healthColor: Color {
        switch batteryMonitor.batteryState.batteryHealth {
        case "Good": return .green
        case "Fair": return .orange
        case "Poor": return .red
        default: return .gray
        }
    }

    // MARK: - Status

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Status")
                .font(.headline)
                .padding(.top, 12)

            HStack(spacing: 24) {
                InfoRow(label: "Current Action", value: currentActionDescription)
                if let time = batteryMonitor.batteryState.timeRemainingFormatted {
                    InfoRow(label: "Time Remaining", value: time)
                }
                if let lastTransition = stateMachine.lastTransition {
                    InfoRow(label: "Last Change", value: lastTransition.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if let cycles = batteryMonitor.batteryState.cycleCount {
                HStack(spacing: 24) {
                    InfoRow(label: "Cycle Count", value: "\(cycles)")
                    if let cap = batteryMonitor.batteryState.maxCapacity {
                        InfoRow(label: "Max Capacity", value: "\(cap)%")
                    }
                }
                .padding(.top, 4)
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
                .transition(.opacity)
                .animation(.easeInOut, value: batteryMonitor.batteryState.isPluggedIn)
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
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                    NSApp.activate(ignoringOtherApps: true)
                } label: {
                    Label("Settings", systemImage: "gearshape")
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding(.bottom, 8)
    }

    // MARK: - Activity Log

    private var activityLogSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showActivityLog) {
                if activityLogger.events.isEmpty {
                    Text("No activity recorded yet.")
                        .font(.callout)
                        .foregroundStyle(.tertiary)
                        .padding(.vertical, 8)
                } else {
                    VStack(spacing: 0) {
                        ForEach(activityLogger.events.prefix(25)) { event in
                            HStack(spacing: 10) {
                                Image(systemName: event.iconName)
                                    .foregroundStyle(eventColor(event))
                                    .frame(width: 20)
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(event.kind.rawValue)
                                        .font(.callout.weight(.medium))
                                    Text(event.detail)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                }
                                Spacer()
                                VStack(alignment: .trailing, spacing: 1) {
                                    Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption2)
                                        .foregroundStyle(.tertiary)
                                    if event.batteryLevel >= 0 {
                                        Text("\(event.batteryLevel)%")
                                            .font(.caption2.monospacedDigit())
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 6)
                            .accessibilityElement(children: .combine)

                            if event.id != activityLogger.events.prefix(25).last?.id {
                                Divider()
                            }
                        }
                    }
                }
            } label: {
                HStack {
                    Text("Activity Log")
                        .font(.headline)
                    Spacer()
                    Text("\(activityLogger.events.count) events")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .padding(.top, 12)
            }
        }
    }

    private func eventColor(_ event: ChargeEvent) -> Color {
        switch event.iconColor {
        case "green": return .green
        case "orange": return .orange
        case "blue": return .blue
        case "red": return .red
        case "purple": return .purple
        default: return .gray
        }
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
                Text("SmartCharge v\(updateChecker.appVersion)")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            if updateChecker.isChecking {
                ProgressView()
                    .controlSize(.small)
                    .padding(.trailing, 4)
            }

            Button("Check for Updates") {
                updateChecker.checkForUpdate()
            }
            .buttonStyle(.borderless)
            .font(.caption)
            .disabled(updateChecker.isChecking)
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
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    .frame(width: bodyWidth, height: height)

                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 8, height: height * 0.4)
                    .offset(x: bodyWidth + 2)

                Rectangle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: stopX - startX, height: height - 4)
                    .offset(x: startX + 2)

                RoundedRectangle(cornerRadius: 10)
                    .fill(fillGradient)
                    .frame(width: max(0, fillWidth - 4), height: height - 4)
                    .offset(x: 2)

                Rectangle()
                    .fill(Color.orange)
                    .frame(width: 2, height: height)
                    .offset(x: startX)

                Rectangle()
                    .fill(Color.green)
                    .frame(width: 2, height: height)
                    .offset(x: stopX)

                Text("\(max(0, level))%")
                    .font(.system(size: 36, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .frame(width: bodyWidth, height: height)

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
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
            Text(value)
                .font(.system(.callout, design: .rounded, weight: .semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.04), radius: 3, y: 2)
        .accessibilityElement(children: .combine)
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
        .accessibilityElement(children: .combine)
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
        .accessibilityLabel("\(label): \(value) percent")
    }
}
