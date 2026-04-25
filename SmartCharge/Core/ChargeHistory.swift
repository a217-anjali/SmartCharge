import Foundation
import os

// MARK: - Models

struct BatterySnapshot: Codable, Identifiable {
    let id: UUID
    let date: Date
    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool

    init(date: Date = Date(), level: Int, isCharging: Bool, isPluggedIn: Bool) {
        self.id = UUID()
        self.date = date
        self.level = level
        self.isCharging = isCharging
        self.isPluggedIn = isPluggedIn
    }
}

struct HealthRecord: Codable, Identifiable {
    var id: Date { date }
    let date: Date
    let maxCapacity: Int
    let cycleCount: Int
}

enum TimePeriod: String, CaseIterable, Identifiable {
    case day, week

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .day:  return "24 Hours"
        case .week: return "7 Days"
        }
    }

    var cutoffDate: Date {
        switch self {
        case .day:  return Calendar.current.date(byAdding: .hour, value: -24, to: Date())!
        case .week: return Calendar.current.date(byAdding: .day, value: -7, to: Date())!
        }
    }
}

// MARK: - ChargeHistory

@MainActor
final class ChargeHistory: ObservableObject {
    @Published var snapshots: [BatterySnapshot] = []
    @Published var healthHistory: [HealthRecord] = []

    private static let snapshotKey = "BatteryHistory"
    private static let healthKey = "BatteryHealthHistory"
    private static let recordInterval: TimeInterval = 5 * 60   // 5 minutes
    private static let retentionDays = 7
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "ChargeHistory")

    private var lastRecordDate: Date?
    private var lastHealthDate: Date?

    // MARK: - Init

    init() {
        loadSnapshots()
        loadHealthHistory()
    }

    // MARK: - Recording

    /// Record a battery state snapshot. Should be called frequently; the method
    /// internally enforces the 5-minute minimum interval between persisted snapshots.
    func record(state: BatteryState) {
        guard state.level >= 0 else { return }

        let now = Date()

        // Enforce minimum interval between snapshots
        if let last = lastRecordDate, now.timeIntervalSince(last) < Self.recordInterval {
            return
        }

        let snapshot = BatterySnapshot(
            date: now,
            level: state.level,
            isCharging: state.isCharging,
            isPluggedIn: state.isPluggedIn
        )
        snapshots.append(snapshot)
        lastRecordDate = now

        trimOldSnapshots()
        persistSnapshots()

        Self.logger.debug("Recorded snapshot: \(state.level)% (total: \(self.snapshots.count))")

        // Health tracking: once per day when maxCapacity is available
        recordHealthIfNeeded(state: state, now: now)
    }

    // MARK: - Queries

    /// Return snapshots filtered to the given time period.
    func snapshots(for period: TimePeriod) -> [BatterySnapshot] {
        let cutoff = period.cutoffDate
        return snapshots.filter { $0.date >= cutoff }
    }

    /// Average battery level for the given period.
    func averageLevel(for period: TimePeriod) -> Int? {
        let data = snapshots(for: period)
        guard !data.isEmpty else { return nil }
        let sum = data.reduce(0) { $0 + $1.level }
        return sum / data.count
    }

    /// Approximate time spent on charger (plugged in) for the given period, in minutes.
    func timeOnCharger(for period: TimePeriod) -> Int {
        let data = snapshots(for: period).sorted { $0.date < $1.date }
        guard data.count > 1 else { return 0 }

        var totalSeconds: TimeInterval = 0
        for i in 1..<data.count {
            if data[i - 1].isPluggedIn {
                totalSeconds += data[i].date.timeIntervalSince(data[i - 1].date)
            }
        }
        return Int(totalSeconds / 60)
    }

    /// Approximate number of charge cycles observed in the period. A cycle is
    /// counted each time `isCharging` transitions from false to true.
    func chargeCycles(for period: TimePeriod) -> Int {
        let data = snapshots(for: period).sorted { $0.date < $1.date }
        guard data.count > 1 else { return 0 }

        var cycles = 0
        for i in 1..<data.count {
            if data[i].isCharging && !data[i - 1].isCharging {
                cycles += 1
            }
        }
        return cycles
    }

    // MARK: - Clearing

    func clearHistory() {
        snapshots.removeAll()
        persistSnapshots()
        Self.logger.info("Snapshot history cleared")
    }

    func clearHealthHistory() {
        healthHistory.removeAll()
        persistHealthHistory()
        Self.logger.info("Health history cleared")
    }

    // MARK: - Private: Health

    private func recordHealthIfNeeded(state: BatteryState, now: Date) {
        guard let maxCapacity = state.maxCapacity,
              let cycleCount = state.cycleCount else { return }

        let calendar = Calendar.current
        if let last = lastHealthDate, calendar.isDate(last, inSameDayAs: now) {
            return
        }

        // Only record if capacity changed since last entry (or first entry)
        if let lastRecord = healthHistory.last, lastRecord.maxCapacity == maxCapacity {
            lastHealthDate = now
            return
        }

        let record = HealthRecord(date: now, maxCapacity: maxCapacity, cycleCount: cycleCount)
        healthHistory.append(record)
        lastHealthDate = now
        persistHealthHistory()

        Self.logger.info("Recorded health: maxCapacity=\(maxCapacity)%, cycles=\(cycleCount)")
    }

    // MARK: - Private: Persistence

    private func loadSnapshots() {
        guard let data = UserDefaults.standard.data(forKey: Self.snapshotKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([BatterySnapshot].self, from: data)
            snapshots = decoded
            lastRecordDate = decoded.last?.date
            Self.logger.info("Loaded \(decoded.count) snapshots from storage")
        } catch {
            Self.logger.error("Failed to decode snapshots: \(error.localizedDescription)")
        }
    }

    private func persistSnapshots() {
        do {
            let data = try JSONEncoder().encode(snapshots)
            UserDefaults.standard.set(data, forKey: Self.snapshotKey)
        } catch {
            Self.logger.error("Failed to encode snapshots: \(error.localizedDescription)")
        }
    }

    private func loadHealthHistory() {
        guard let data = UserDefaults.standard.data(forKey: Self.healthKey) else { return }
        do {
            let decoded = try JSONDecoder().decode([HealthRecord].self, from: data)
            healthHistory = decoded
            lastHealthDate = decoded.last?.date
            Self.logger.info("Loaded \(decoded.count) health records from storage")
        } catch {
            Self.logger.error("Failed to decode health records: \(error.localizedDescription)")
        }
    }

    private func persistHealthHistory() {
        do {
            let data = try JSONEncoder().encode(healthHistory)
            UserDefaults.standard.set(data, forKey: Self.healthKey)
        } catch {
            Self.logger.error("Failed to encode health records: \(error.localizedDescription)")
        }
    }

    private func trimOldSnapshots() {
        let cutoff = Calendar.current.date(byAdding: .day, value: -Self.retentionDays, to: Date())!
        let before = snapshots.count
        snapshots.removeAll { $0.date < cutoff }
        let removed = before - snapshots.count
        if removed > 0 {
            Self.logger.debug("Trimmed \(removed) snapshots older than \(Self.retentionDays) days")
        }
    }
}
