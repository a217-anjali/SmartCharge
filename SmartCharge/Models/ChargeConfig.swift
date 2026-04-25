import Foundation
import os

struct ChargeConfig: Codable, Equatable {
    var chargeStartThreshold: Int
    var chargeStopThreshold: Int
    var notificationsEnabled: Bool
    var launchAtLogin: Bool

    static let `default` = ChargeConfig(
        chargeStartThreshold: 20,
        chargeStopThreshold: 85,
        notificationsEnabled: true,
        launchAtLogin: false
    )

    var isValid: Bool {
        chargeStartThreshold >= 5
            && chargeStopThreshold <= 100
            && chargeStartThreshold < chargeStopThreshold
            && (chargeStopThreshold - chargeStartThreshold) >= 10
    }

    func toJSON() -> Data? {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try? encoder.encode(self)
    }

    static func fromJSON(_ data: Data) -> ChargeConfig? {
        guard let config = try? JSONDecoder().decode(ChargeConfig.self, from: data),
              config.isValid else { return nil }
        return config
    }
}

@MainActor
final class ChargeConfigStore: ObservableObject {
    @Published var config: ChargeConfig {
        didSet { save() }
    }

    private static let key = "ChargeConfig"
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "Config")

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ChargeConfig.self, from: data) {
            self.config = decoded
            Self.logger.info("Loaded config: start=\(decoded.chargeStartThreshold)%, stop=\(decoded.chargeStopThreshold)%")
        } else {
            self.config = .default
            Self.logger.info("Using default config")
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func reset() {
        config = .default
        Self.logger.info("Config reset to defaults")
    }

    func exportToFile(url: URL) throws {
        guard let data = config.toJSON() else {
            throw NSError(domain: "SmartCharge", code: 1, userInfo: [NSLocalizedDescriptionKey: "Failed to encode config"])
        }
        try data.write(to: url)
        Self.logger.info("Config exported to \(url.path)")
    }

    func importFromFile(url: URL) throws {
        let data = try Data(contentsOf: url)
        guard let imported = ChargeConfig.fromJSON(data) else {
            throw NSError(domain: "SmartCharge", code: 2, userInfo: [NSLocalizedDescriptionKey: "Invalid or corrupt config file"])
        }
        config = imported
        Self.logger.info("Config imported: start=\(imported.chargeStartThreshold)%, stop=\(imported.chargeStopThreshold)%")
    }
}
