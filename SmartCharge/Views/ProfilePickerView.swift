import SwiftUI

struct ProfilePickerView: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var activityLogger: ActivityLogger

    @State private var showAddSheet = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Profiles")
                    .font(.headline)
                Spacer()
                Button {
                    showAddSheet = true
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title3)
                }
                .buttonStyle(.plain)
                .help("Add custom profile")
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(profileManager.profiles) { profile in
                        ProfileCardView(
                            profile: profile,
                            isActive: profileManager.activeProfileId == profile.id,
                            onTap: {
                                activateProfile(profile)
                            },
                            onDelete: profile.isBuiltIn ? nil : {
                                deleteProfile(profile)
                            }
                        )
                    }
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 2)
            }
        }
        .sheet(isPresented: $showAddSheet) {
            AddProfileSheet(
                profileManager: profileManager,
                configStore: configStore,
                activityLogger: activityLogger
            )
        }
    }

    // MARK: - Actions

    private func activateProfile(_ profile: ChargingProfile) {
        if profileManager.activeProfileId == profile.id {
            profileManager.deactivate()
            activityLogger.log(.configChanged, batteryLevel: -1, detail: "Deactivated profile '\(profile.name)'")
        } else {
            profileManager.activate(profile, configStore: configStore)
            activityLogger.log(.configChanged, batteryLevel: -1, detail: "Activated profile '\(profile.name)': \(profile.thresholdLabel)")
        }
    }

    private func deleteProfile(_ profile: ChargingProfile) {
        let name = profile.name
        profileManager.deleteProfile(profile)
        activityLogger.log(.configChanged, batteryLevel: -1, detail: "Deleted profile '\(name)'")
    }
}

// MARK: - Profile Card

private struct ProfileCardView: View {
    let profile: ChargingProfile
    let isActive: Bool
    let onTap: () -> Void
    let onDelete: (() -> Void)?

    @State private var isHovering = false

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: profile.icon)
                .font(.title2)
                .foregroundStyle(isActive ? .white : .primary)

            Text(profile.name)
                .font(.caption.weight(.medium))
                .foregroundStyle(isActive ? .white : .primary)
                .lineLimit(1)

            Text(profile.thresholdLabel)
                .font(.caption2)
                .foregroundStyle(isActive ? .white.opacity(0.85) : .secondary)
                .monospacedDigit()
        }
        .frame(width: 80, height: 76)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(isActive ? Color.accentColor : Color.gray.opacity(isHovering ? 0.15 : 0.08))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .strokeBorder(isActive ? Color.accentColor : Color.gray.opacity(0.25), lineWidth: isActive ? 2 : 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 10))
        .onTapGesture { onTap() }
        .onHover { hovering in isHovering = hovering }
        .contextMenu {
            if let onDelete {
                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Label("Delete", systemImage: "trash")
                }
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isActive)
        .animation(.easeInOut(duration: 0.1), value: isHovering)
    }
}

// MARK: - Add Profile Sheet

private struct AddProfileSheet: View {
    @ObservedObject var profileManager: ProfileManager
    @ObservedObject var configStore: ChargeConfigStore
    @ObservedObject var activityLogger: ActivityLogger

    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var selectedIcon = "bolt.fill"
    @State private var startThreshold: Double = 20
    @State private var stopThreshold: Double = 85
    @State private var showValidationAlert = false

    private static let availableIcons = [
        "bolt.fill", "house.fill", "airplane", "person.2.fill", "leaf.fill",
        "briefcase.fill", "moon.fill", "sun.max.fill", "desktopcomputer",
        "gamecontroller.fill", "cup.and.saucer.fill", "bed.double.fill",
        "car.fill", "book.fill", "wrench.and.screwdriver.fill", "heart.fill"
    ]

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("New Profile")
                    .font(.title3.bold())
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.bordered)
                    .keyboardShortcut(.escape, modifiers: [])
            }
            .padding()

            Form {
                Section("Name") {
                    TextField("Profile name", text: $name)
                        .textFieldStyle(.roundedBorder)
                }

                Section("Icon") {
                    LazyVGrid(columns: Array(repeating: GridItem(.fixed(36), spacing: 8), count: 8), spacing: 8) {
                        ForEach(Self.availableIcons, id: \.self) { icon in
                            Image(systemName: icon)
                                .font(.body)
                                .frame(width: 32, height: 32)
                                .background(
                                    RoundedRectangle(cornerRadius: 6)
                                        .fill(selectedIcon == icon ? Color.accentColor : Color.gray.opacity(0.1))
                                )
                                .foregroundStyle(selectedIcon == icon ? .white : .primary)
                                .onTapGesture { selectedIcon = icon }
                        }
                    }
                }

                Section("Thresholds") {
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Text("Start charging at")
                            Spacer()
                            Text("\(Int(startThreshold))%")
                                .fontWeight(.semibold)
                                .foregroundStyle(.orange)
                                .monospacedDigit()
                        }
                        Slider(value: $startThreshold, in: 5...50, step: 1)
                            .tint(.orange)

                        HStack {
                            Text("Stop charging at")
                            Spacer()
                            Text("\(Int(stopThreshold))%")
                                .fontWeight(.semibold)
                                .foregroundStyle(.green)
                                .monospacedDigit()
                        }
                        Slider(value: $stopThreshold, in: 50...100, step: 1)
                            .tint(.green)
                    }
                }
            }
            .formStyle(.grouped)

            // Footer
            HStack {
                Text("Gap must be at least 10%.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Button("Add Profile") {
                    addProfile()
                }
                .buttonStyle(.borderedProminent)
                .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
            }
            .padding()
        }
        .frame(width: 380, height: 460)
        .alert("Invalid Thresholds", isPresented: $showValidationAlert) {
            Button("OK") {}
        } message: {
            Text("Start must be at least 10% below stop.\nStart: 5-50% / Stop: 50-100%")
        }
    }

    private func addProfile() {
        let profile = ChargingProfile(
            id: UUID(),
            name: name.trimmingCharacters(in: .whitespaces),
            chargeStartThreshold: Int(startThreshold),
            chargeStopThreshold: Int(stopThreshold),
            icon: selectedIcon,
            isBuiltIn: false
        )
        guard profile.isValid else {
            showValidationAlert = true
            return
        }
        profileManager.addProfile(profile)
        activityLogger.log(.configChanged, batteryLevel: -1, detail: "Created profile '\(profile.name)': \(profile.thresholdLabel)")
        dismiss()
    }
}
