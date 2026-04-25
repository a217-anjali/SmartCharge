import Foundation

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
}

@MainActor
final class ChargeConfigStore: ObservableObject {
    @Published var config: ChargeConfig {
        didSet { save() }
    }

    private static let key = "ChargeConfig"

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.key),
           let decoded = try? JSONDecoder().decode(ChargeConfig.self, from: data) {
            self.config = decoded
        } else {
            self.config = .default
        }
    }

    private func save() {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: Self.key)
        }
    }

    func reset() {
        config = .default
    }
}
