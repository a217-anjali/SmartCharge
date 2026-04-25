import Foundation
import SwiftUI

struct ChargeEvent: Identifiable, Codable, Equatable {
    let id: UUID
    let date: Date
    let kind: Kind
    let batteryLevel: Int
    let detail: String

    enum Kind: String, Codable, CaseIterable {
        case chargingStarted = "Charging Started"
        case chargingStopped = "Charging Stopped"
        case appLaunched = "App Launched"
        case appTerminated = "App Terminated"
        case helperError = "Helper Error"
        case configChanged = "Config Changed"
    }

    init(kind: Kind, batteryLevel: Int, detail: String) {
        self.id = UUID()
        self.date = Date()
        self.kind = kind
        self.batteryLevel = batteryLevel
        self.detail = detail
    }

    var iconName: String {
        switch kind {
        case .chargingStarted: return "bolt.fill"
        case .chargingStopped: return "bolt.slash.fill"
        case .appLaunched: return "power"
        case .appTerminated: return "power.circle"
        case .helperError: return "exclamationmark.triangle.fill"
        case .configChanged: return "gearshape.fill"
        }
    }

    var color: SwiftUI.Color {
        switch kind {
        case .chargingStarted: return .green
        case .chargingStopped: return .orange
        case .appLaunched: return .blue
        case .appTerminated: return .gray
        case .helperError: return .red
        case .configChanged: return .purple
        }
    }
}
