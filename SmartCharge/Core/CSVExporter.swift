import Foundation

enum CSVExporter {

    // MARK: - Date / Time Formatters

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss"
        return f
    }()

    // MARK: - Activity Log Export

    /// Converts an array of `ChargeEvent` into a CSV string.
    ///
    /// Headers: Date, Time, Event, Battery Level, Detail
    static func exportActivityLog(events: [ChargeEvent]) -> String {
        var lines: [String] = ["Date,Time,Event,Battery Level,Detail"]

        for event in events {
            let date = dateFormatter.string(from: event.date)
            let time = timeFormatter.string(from: event.date)
            let kind = escapeCSV(event.kind.rawValue)
            let level = event.batteryLevel >= 0 ? "\(event.batteryLevel)%" : "N/A"
            let detail = escapeCSV(event.detail)
            lines.append("\(date),\(time),\(kind),\(level),\(detail)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Battery History Export

    /// Converts an array of `BatterySnapshot` into a CSV string.
    ///
    /// Headers: Date, Time, Battery Level, Charging, Plugged In
    static func exportBatteryHistory(snapshots: [BatterySnapshot]) -> String {
        var lines: [String] = ["Date,Time,Battery Level,Charging,Plugged In"]

        for snapshot in snapshots {
            let date = dateFormatter.string(from: snapshot.date)
            let time = timeFormatter.string(from: snapshot.date)
            let level = "\(snapshot.level)%"
            let charging = snapshot.isCharging ? "Yes" : "No"
            let pluggedIn = snapshot.isPluggedIn ? "Yes" : "No"
            lines.append("\(date),\(time),\(level),\(charging),\(pluggedIn)")
        }

        return lines.joined(separator: "\n")
    }

    // MARK: - Helpers

    /// Escapes a value for safe inclusion in a CSV field.
    /// Wraps the value in double-quotes if it contains commas, quotes, or newlines.
    private static func escapeCSV(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            let escaped = value.replacingOccurrences(of: "\"", with: "\"\"")
            return "\"\(escaped)\""
        }
        return value
    }
}
