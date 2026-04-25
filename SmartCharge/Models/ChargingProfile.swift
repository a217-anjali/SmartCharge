import Foundation
import os

struct ChargingProfile: Codable, Identifiable, Equatable {
    let id: UUID
    var name: String
    var chargeStartThreshold: Int
    var chargeStopThreshold: Int
    var icon: String // SF Symbol name
    var isBuiltIn: Bool

    var isValid: Bool {
        chargeStartThreshold >= 5
            && chargeStopThreshold <= 100
            && chargeStartThreshold < chargeStopThreshold
            && (chargeStopThreshold - chargeStartThreshold) >= 10
            && !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var thresholdLabel: String {
        "\(chargeStartThreshold)%-\(chargeStopThreshold)%"
    }

    // MARK: - Built-in profiles

    static let home = ChargingProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Home", chargeStartThreshold: 20, chargeStopThreshold: 85,
        icon: "house.fill", isBuiltIn: true
    )
    static let travel = ChargingProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000002")!,
        name: "Travel", chargeStartThreshold: 10, chargeStopThreshold: 100,
        icon: "airplane", isBuiltIn: true
    )
    static let presentation = ChargingProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000003")!,
        name: "Presentation", chargeStartThreshold: 15, chargeStopThreshold: 100,
        icon: "person.2.fill", isBuiltIn: true
    )
    static let balanced = ChargingProfile(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000004")!,
        name: "Balanced", chargeStartThreshold: 25, chargeStopThreshold: 80,
        icon: "leaf.fill", isBuiltIn: true
    )

    static let builtIn: [ChargingProfile] = [.home, .travel, .presentation, .balanced]
}

@MainActor
final class ProfileManager: ObservableObject {
    @Published var profiles: [ChargingProfile]
    @Published var activeProfileId: UUID?

    private static let storageKey = "ChargingProfiles"
    private static let activeKey = "ActiveProfileId"
    private static let logger = Logger(subsystem: "com.smartcharge.app", category: "Profiles")

    init() {
        if let data = UserDefaults.standard.data(forKey: Self.storageKey),
           let decoded = try? JSONDecoder().decode([ChargingProfile].self, from: data) {
            // Merge: always keep fresh built-in profiles, append any saved custom ones
            let customProfiles = decoded.filter { !$0.isBuiltIn }
            self.profiles = ChargingProfile.builtIn + customProfiles
            Self.logger.info("Loaded \(customProfiles.count) custom profile(s) + \(ChargingProfile.builtIn.count) built-in")
        } else {
            self.profiles = ChargingProfile.builtIn
            Self.logger.info("Using default built-in profiles")
        }

        if let idString = UserDefaults.standard.string(forKey: Self.activeKey),
           let id = UUID(uuidString: idString),
           profiles.contains(where: { $0.id == id }) {
            self.activeProfileId = id
            Self.logger.info("Restored active profile: \(idString)")
        } else {
            self.activeProfileId = nil
        }
    }

    // MARK: - Profile activation

    func activate(_ profile: ChargingProfile, configStore: ChargeConfigStore) {
        guard profiles.contains(where: { $0.id == profile.id }) else {
            Self.logger.warning("Attempted to activate unknown profile: \(profile.name)")
            return
        }

        configStore.config = ChargeConfig(
            chargeStartThreshold: profile.chargeStartThreshold,
            chargeStopThreshold: profile.chargeStopThreshold,
            notificationsEnabled: configStore.config.notificationsEnabled,
            launchAtLogin: configStore.config.launchAtLogin
        )

        activeProfileId = profile.id
        UserDefaults.standard.set(profile.id.uuidString, forKey: Self.activeKey)
        Self.logger.info("Activated profile '\(profile.name)': \(profile.chargeStartThreshold)%-\(profile.chargeStopThreshold)%")
    }

    func deactivate() {
        activeProfileId = nil
        UserDefaults.standard.removeObject(forKey: Self.activeKey)
        Self.logger.info("Deactivated profile")
    }

    // MARK: - CRUD

    func addProfile(_ profile: ChargingProfile) {
        guard profile.isValid else {
            Self.logger.warning("Rejected invalid profile '\(profile.name)'")
            return
        }
        var newProfile = profile
        newProfile.isBuiltIn = false
        profiles.append(newProfile)
        save()
        Self.logger.info("Added custom profile '\(newProfile.name)'")
    }

    func updateProfile(_ profile: ChargingProfile) {
        guard let index = profiles.firstIndex(where: { $0.id == profile.id }) else {
            Self.logger.warning("Cannot update non-existent profile '\(profile.name)'")
            return
        }
        guard profile.isValid else {
            Self.logger.warning("Rejected invalid update for profile '\(profile.name)'")
            return
        }
        profiles[index] = profile
        save()
        Self.logger.info("Updated profile '\(profile.name)'")
    }

    func deleteProfile(_ profile: ChargingProfile) {
        guard !profile.isBuiltIn else {
            Self.logger.warning("Cannot delete built-in profile '\(profile.name)'")
            return
        }
        profiles.removeAll { $0.id == profile.id }
        if activeProfileId == profile.id {
            deactivate()
        }
        save()
        Self.logger.info("Deleted custom profile '\(profile.name)'")
    }

    // MARK: - Persistence

    func save() {
        if let data = try? JSONEncoder().encode(profiles) {
            UserDefaults.standard.set(data, forKey: Self.storageKey)
        }
    }
}
