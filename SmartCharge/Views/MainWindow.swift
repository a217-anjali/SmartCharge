import SwiftUI

struct MainWindow: View {
    @ObservedObject var batteryMonitor: BatteryMonitor
    @ObservedObject var stateMachine: ChargeStateMachine
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var updateChecker: UpdateChecker
    @ObservedObject var helperProxy: HelperProxy
    @ObservedObject var activityLogger: ActivityLogger

    @State private var showActivityLog = false
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 12) {
            errorBanner
            headerSection
            Divider()
            batteryVisualization
            statsGrid
            Divider()
            statusSection
            Divider()
            thresholdControls
            Divider()
            activityLogSection
            footerSection
        }
        .padding(20)
        .frame(width: 560)
        .background(Color(nsColor: .windowBackgroundColor))
        .sheet(isPresented: $showSettings) {
            SettingsView(configStore: configStore, activityLogger: activityLogger, isPresented: $showSettings)
        }
    }

    // MARK: - Error Banner

    @ViewBuilder
    private var errorBanner: some View {
        if let error = stateMachine.lastError ?? helperProxy.lastError {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                Text(error)
                    .lineLimit(2)
                Spacer()
                Button("Dismiss") {
                    stateMachine.lastError = nil
                    helperProxy.lastError = nil
                }
                .buttonStyle(.bordered)
                .tint(.white)
            }
            .font(.callout)
            .foregroundStyle(.white)
            .padding(12)
            .background(Color.red.gradient, in: RoundedRectangle(cornerRadius: 10))
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
            HStack(spacing: 6) {
                Circle()
                    .fill(statusColor)
                    .frame(width: 10, height: 10)
                Text(stateMachine.state.description)
                    .font(.subheadline.weight(.medium))
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(statusColor.opacity(0.12), in: Capsule())
        }
    }

    private var statusColor: Color {
        stateMachine.state == .charging ? .green : .orange
    }

    // MARK: - Battery Visualization

    private var batteryVisualization: some View {
        BatteryShape(level: batteryMonitor.batteryState.level, config: configStore.config)
            .frame(height: 100)
            .padding(.vertical, 4)
            .allowsHitTesting(false)
    }

    // MARK: - Stats Grid

    private var statsGrid: some View {
        HStack(spacing: 10) {
            StatCard(title: "Battery", value: batteryMonitor.batteryState.levelDescription,
                     icon: batteryIcon, color: batteryLevelColor)
            StatCard(title: "Power",
                     value: batteryMonitor.batteryState.isPluggedIn ? "Plugged In" : "Battery",
                     icon: batteryMonitor.batteryState.isPluggedIn ? "powerplug.fill" : "bolt.slash",
                     color: batteryMonitor.batteryState.isPluggedIn ? .green : .gray)
            StatCard(title: "Control", value: stateMachine.state.rawValue,
                     icon: stateMachine.state == .charging ? "bolt.fill" : "pause.circle",
                     color: statusColor)
            StatCard(title: "Health", value: batteryMonitor.batteryState.healthDescription,
                     icon: "heart.fill", color: healthColor)
        }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Status").font(.headline)

            HStack(spacing: 20) {
                InfoRow(label: "Current Action", value: currentActionDescription)
                if let time = batteryMonitor.batteryState.timeRemainingFormatted {
                    InfoRow(label: "Time Remaining", value: time)
                }
                if let lastTransition = stateMachine.lastTransition {
                    InfoRow(label: "Last Change", value: lastTransition.formatted(date: .abbreviated, time: .shortened))
                }
            }

            if batteryMonitor.batteryState.cycleCount != nil || batteryMonitor.batteryState.maxCapacity != nil {
                HStack(spacing: 20) {
                    if let cycles = batteryMonitor.batteryState.cycleCount {
                        InfoRow(label: "Cycle Count", value: "\(cycles)")
                    }
                    if let cap = batteryMonitor.batteryState.maxCapacity {
                        InfoRow(label: "Max Capacity", value: "\(cap)%")
                    }
                }
            }

            if !batteryMonitor.batteryState.isPluggedIn {
                HStack(spacing: 8) {
                    Image(systemName: "info.circle.fill").foregroundStyle(.blue)
                    Text("Plug in your charger — SmartCharge manages charging automatically while plugged in.")
                        .font(.callout).foregroundStyle(.secondary)
                }
                .padding(10)
                .background(Color.blue.opacity(0.08), in: RoundedRectangle(cornerRadius: 8))
            }
        }
    }

    private var currentActionDescription: String {
        let level = batteryMonitor.batteryState.level
        guard batteryMonitor.batteryState.isPluggedIn else { return "Not plugged in" }
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
        VStack(alignment: .leading, spacing: 8) {
            Text("Charge Thresholds").font(.headline)

            HStack(spacing: 20) {
                ThresholdBadge(label: "Start At", value: configStore.config.chargeStartThreshold,
                               color: .orange, icon: "bolt.fill")
                ThresholdBadge(label: "Stop At", value: configStore.config.chargeStopThreshold,
                               color: .green, icon: "bolt.slash.fill")
                Spacer()
                Button("Settings") {
                    showSettings = true
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.regular)
            }
        }
    }

    // MARK: - Activity Log

    private var activityLogSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                showActivityLog.toggle()
            } label: {
                HStack {
                    Image(systemName: showActivityLog ? "chevron.down" : "chevron.right")
                        .frame(width: 14)
                    Text("Activity Log").font(.headline)
                    Spacer()
                    Text("\(activityLogger.events.count) events")
                        .font(.caption).foregroundStyle(.tertiary)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if showActivityLog {
                if activityLogger.events.isEmpty {
                    Text("No activity recorded yet.")
                        .font(.callout).foregroundStyle(.tertiary)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 0) {
                        ForEach(activityLogger.events.prefix(20)) { event in
                            VStack(spacing: 0) {
                                HStack(spacing: 10) {
                                    Image(systemName: event.iconName)
                                        .foregroundStyle(event.color)
                                        .frame(width: 18)
                                    VStack(alignment: .leading, spacing: 1) {
                                        Text(event.kind.rawValue).font(.callout.weight(.medium))
                                        Text(event.detail).font(.caption).foregroundStyle(.secondary).lineLimit(1)
                                    }
                                    Spacer()
                                    VStack(alignment: .trailing, spacing: 1) {
                                        Text(event.date.formatted(date: .abbreviated, time: .shortened))
                                            .font(.caption2).foregroundStyle(.tertiary)
                                        if event.batteryLevel >= 0 {
                                            Text("\(event.batteryLevel)%")
                                                .font(.caption2.monospacedDigit()).foregroundStyle(.secondary)
                                        }
                                    }
                                }
                                .padding(.vertical, 5)
                                Divider()
                            }
                        }
                    }
                    .padding(.leading, 4)
                }
            }
        }
    }

    // MARK: - Footer

    private var footerSection: some View {
        HStack {
            if let newVersion = updateChecker.updateAvailable {
                Button("Update Available: v\(newVersion)") {
                    NSWorkspace.shared.open(updateChecker.releaseURL)
                }
                .buttonStyle(.link)
            } else {
                Text("SmartCharge v\(updateChecker.appVersion)")
                    .font(.caption).foregroundStyle(.tertiary)
            }
            Spacer()
            if updateChecker.isChecking {
                ProgressView().controlSize(.small).padding(.trailing, 4)
            }
            Button("Check for Updates") {
                updateChecker.checkForUpdate()
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .disabled(updateChecker.isChecking)
        }
        .padding(.top, 4)
    }
}

// MARK: - Subviews

private struct BatteryShape: View {
    let level: Int
    let config: ChargeConfig

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width - 20
            let h = geo.size.height
            let fill = max(0, w * CGFloat(max(0, level)) / 100)
            let startX = w * CGFloat(config.chargeStartThreshold) / 100
            let stopX = w * CGFloat(config.chargeStopThreshold) / 100

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 12)
                    .stroke(Color.primary.opacity(0.3), lineWidth: 2)
                    .frame(width: w, height: h)
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color.primary.opacity(0.3))
                    .frame(width: 8, height: h * 0.4)
                    .offset(x: w + 2)
                Rectangle()
                    .fill(Color.green.opacity(0.08))
                    .frame(width: stopX - startX, height: h - 4)
                    .offset(x: startX + 2)
                RoundedRectangle(cornerRadius: 10)
                    .fill(fillColor)
                    .frame(width: max(0, fill - 4), height: h - 4)
                    .offset(x: 2)
                Rectangle().fill(Color.orange).frame(width: 2, height: h).offset(x: startX)
                Rectangle().fill(Color.green).frame(width: 2, height: h).offset(x: stopX)
                Text("\(max(0, level))%")
                    .font(.system(size: 34, weight: .bold, design: .rounded))
                    .frame(width: w, height: h)
                Text("\(config.chargeStartThreshold)%")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.orange)
                    .offset(x: startX - 10, y: h / 2 + 12)
                Text("\(config.chargeStopThreshold)%")
                    .font(.system(size: 10, weight: .medium)).foregroundStyle(.green)
                    .offset(x: stopX - 10, y: h / 2 + 12)
            }
        }
    }

    private var fillColor: LinearGradient {
        let c: Color = level <= 20 ? .red : (level <= 50 ? .orange : .green)
        return LinearGradient(colors: [c.opacity(0.7), c.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
    }
}

private struct StatCard: View {
    let title: String; let value: String; let icon: String; let color: Color
    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(value).font(.system(.callout, design: .rounded, weight: .semibold)).lineLimit(1).minimumScaleFactor(0.7)
            Text(title).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12).padding(.horizontal, 4)
        .background(color.opacity(0.06), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct InfoRow: View {
    let label: String; let value: String
    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.callout.weight(.medium))
        }
    }
}

private struct ThresholdBadge: View {
    let label: String; let value: Int; let color: Color; let icon: String
    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon).foregroundStyle(color)
            VStack(alignment: .leading, spacing: 1) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text("\(value)%").font(.body.weight(.semibold).monospacedDigit())
            }
        }
        .padding(.horizontal, 14).padding(.vertical, 8)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 10))
    }
}
