import SwiftUI
import Charts

struct ChargeHistoryView: View {
    @ObservedObject var history: ChargeHistory
    @ObservedObject var configStore: ChargeConfigStore

    @State private var selectedPeriod: TimePeriod = .day

    private var filteredSnapshots: [BatterySnapshot] {
        history.snapshots(for: selectedPeriod)
    }

    private var startThreshold: Int {
        configStore.config.chargeStartThreshold
    }

    private var stopThreshold: Int {
        configStore.config.chargeStopThreshold
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                periodPicker
                batteryChart
                summaryStats
                healthTrendSection
            }
            .padding()
        }
    }

    // MARK: - Period Picker

    private var periodPicker: some View {
        Picker("Period", selection: $selectedPeriod) {
            ForEach(TimePeriod.allCases) { period in
                Text(period.displayName).tag(period)
            }
        }
        .pickerStyle(.segmented)
        .frame(maxWidth: 240)
    }

    // MARK: - Battery Level Chart

    private var batteryChart: some View {
        GroupBox("Battery Level") {
            if filteredSnapshots.isEmpty {
                Text("No data recorded yet for this period.")
                    .foregroundStyle(.secondary)
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
            } else {
                Chart {
                    // Area marks colored by battery level band
                    ForEach(filteredSnapshots) { snapshot in
                        AreaMark(
                            x: .value("Time", snapshot.date),
                            y: .value("Level", snapshot.level)
                        )
                        .foregroundStyle(areaGradient)
                        .interpolationMethod(.catmullRom)

                        LineMark(
                            x: .value("Time", snapshot.date),
                            y: .value("Level", snapshot.level)
                        )
                        .foregroundStyle(lineColor(for: snapshot.level))
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 1.5))
                    }

                    // Threshold rule marks
                    RuleMark(y: .value("Stop Threshold", stopThreshold))
                        .foregroundStyle(.green.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
                        .annotation(position: .top, alignment: .leading) {
                            Text("Stop \(stopThreshold)%")
                                .font(.caption2)
                                .foregroundStyle(.green)
                        }

                    RuleMark(y: .value("Start Threshold", startThreshold))
                        .foregroundStyle(.orange.opacity(0.8))
                        .lineStyle(StrokeStyle(lineWidth: 1, dash: [6, 3]))
                        .annotation(position: .bottom, alignment: .leading) {
                            Text("Start \(startThreshold)%")
                                .font(.caption2)
                                .foregroundStyle(.orange)
                        }
                }
                .chartYScale(domain: 0...100)
                .chartYAxis {
                    AxisMarks(values: [0, 25, 50, 75, 100]) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: xAxisFormat)
                    }
                }
                .frame(height: 200)
            }
        }
    }

    private var xAxisFormat: Date.FormatStyle {
        switch selectedPeriod {
        case .day:
            return .dateTime.hour().minute()
        case .week:
            return .dateTime.weekday(.abbreviated).hour()
        }
    }

    private var areaGradient: LinearGradient {
        LinearGradient(
            colors: [.green.opacity(0.4), .orange.opacity(0.2), .red.opacity(0.1)],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    private func lineColor(for level: Int) -> Color {
        if level > 50 { return .green }
        if level > 20 { return .orange }
        return .red
    }

    // MARK: - Summary Statistics

    private var summaryStats: some View {
        GroupBox("Summary") {
            let avgLevel = history.averageLevel(for: selectedPeriod)
            let chargerMinutes = history.timeOnCharger(for: selectedPeriod)
            let cycles = history.chargeCycles(for: selectedPeriod)

            HStack(spacing: 24) {
                statCard(
                    title: "Avg Level",
                    value: avgLevel.map { "\($0)%" } ?? "--",
                    icon: "battery.50percent"
                )
                Divider().frame(height: 36)
                statCard(
                    title: "Time on Charger",
                    value: formattedDuration(minutes: chargerMinutes),
                    icon: "bolt.fill"
                )
                Divider().frame(height: 36)
                statCard(
                    title: "Charge Cycles",
                    value: "\(cycles)",
                    icon: "arrow.triangle.2.circlepath"
                )
            }
            .frame(maxWidth: .infinity)
        }
    }

    private func statCard(title: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .font(.title3)
            Text(value)
                .font(.title2.bold())
                .monospacedDigit()
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formattedDuration(minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes)m"
        }
        let h = minutes / 60
        let m = minutes % 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Battery Health Trend

    @ViewBuilder
    private var healthTrendSection: some View {
        if history.healthHistory.count > 1 {
            GroupBox("Battery Health Trend") {
                Chart(history.healthHistory) { record in
                    LineMark(
                        x: .value("Date", record.date),
                        y: .value("Max Capacity", record.maxCapacity)
                    )
                    .foregroundStyle(.blue)
                    .interpolationMethod(.catmullRom)
                    .lineStyle(StrokeStyle(lineWidth: 2))
                    .symbol(Circle().strokeBorder(lineWidth: 1.5))

                    PointMark(
                        x: .value("Date", record.date),
                        y: .value("Max Capacity", record.maxCapacity)
                    )
                    .foregroundStyle(.blue)
                    .annotation(position: .top) {
                        Text("\(record.maxCapacity)%")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .chartYAxis {
                    AxisMarks { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let intValue = value.as(Int.self) {
                                Text("\(intValue)%")
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks { _ in
                        AxisGridLine()
                        AxisValueLabel(format: .dateTime.month(.abbreviated).day())
                    }
                }
                .frame(height: 200)
            }
        }
    }
}
