import SwiftUI
import ServiceManagement

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @ObservedObject var configStore: ChargeConfigStore

    @State private var currentPage = 0

    private let pageCount = 3

    var body: some View {
        VStack(spacing: 0) {
            // Page content
            TabView(selection: $currentPage) {
                welcomePage.tag(0)
                howItWorksPage.tag(1)
                getStartedPage.tag(2)
            }
            .tabViewStyle(.automatic)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

            // Navigation buttons
            navigationBar
                .padding(.horizontal, 32)
                .padding(.bottom, 24)
        }
        .frame(width: 560, height: 520)
        .background(Color(nsColor: .windowBackgroundColor))
    }

    // MARK: - Page 1: Welcome

    private var welcomePage: some View {
        VStack(spacing: 20) {
            Spacer()

            Image(systemName: "bolt.batteryblock.fill")
                .font(.system(size: 72))
                .foregroundStyle(.linearGradient(
                    colors: [.blue, .purple],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ))
                .padding(.bottom, 4)

            Text("Welcome to SmartCharge")
                .font(.largeTitle.bold())

            Text("Protect your battery health automatically")
                .font(.title3)
                .foregroundStyle(.secondary)

            Text("SmartCharge keeps your MacBook battery in the optimal charge range by automatically controlling when your Mac charges. This prevents overcharging and extends your battery's lifespan.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 420)
                .padding(.top, 4)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Page 2: How It Works

    private var howItWorksPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("How It Works")
                .font(.largeTitle.bold())

            // Charge zone visualization
            chargeZoneVisualization
                .padding(.vertical, 8)

            VStack(alignment: .leading, spacing: 14) {
                BulletRow(icon: "bolt.fill", color: .green,
                          text: "Charges only when needed")
                BulletRow(icon: "stop.circle.fill", color: .orange,
                          text: "Stops at your threshold")
                BulletRow(icon: "heart.fill", color: .pink,
                          text: "Keeps your battery healthy")
            }
            .padding(.horizontal, 40)

            Text("SmartCharge automatically starts charging when your battery drops to the lower threshold and stops when it reaches the upper threshold.")
                .font(.callout)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            Spacer()
        }
        .padding(32)
    }

    private var chargeZoneVisualization: some View {
        VStack(spacing: 6) {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let startPct = CGFloat(configStore.config.chargeStartThreshold) / 100
                let stopPct = CGFloat(configStore.config.chargeStopThreshold) / 100

                ZStack(alignment: .leading) {
                    // Background track
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.primary.opacity(0.08))
                        .frame(height: h)

                    // Optimal zone (green)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color.green.opacity(0.25))
                        .frame(width: (stopPct - startPct) * w, height: h - 8)
                        .offset(x: startPct * w + 4)

                    // Start marker
                    Rectangle()
                        .fill(Color.orange)
                        .frame(width: 3, height: h)
                        .offset(x: startPct * w)

                    // Stop marker
                    Rectangle()
                        .fill(Color.green)
                        .frame(width: 3, height: h)
                        .offset(x: stopPct * w)

                    // Labels
                    Text("\(configStore.config.chargeStartThreshold)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.orange)
                        .offset(x: startPct * w - 12, y: h / 2 + 16)

                    Text("\(configStore.config.chargeStopThreshold)%")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.green)
                        .offset(x: stopPct * w - 12, y: h / 2 + 16)

                    // "Optimal" label centered in zone
                    Text("Optimal Zone")
                        .font(.caption.weight(.medium))
                        .foregroundStyle(.green)
                        .position(x: (startPct + stopPct) / 2 * w, y: h / 2)
                }
            }
            .frame(height: 40)
            .padding(.horizontal, 40)

            HStack {
                Text("0%").font(.caption2).foregroundStyle(.tertiary)
                Spacer()
                Text("100%").font(.caption2).foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 40)
        }
    }

    // MARK: - Page 3: Get Started

    private var getStartedPage: some View {
        VStack(spacing: 20) {
            Spacer()

            Text("Get Started")
                .font(.largeTitle.bold())

            Text("Review your settings and start protecting your battery.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .frame(maxWidth: 400)

            VStack(spacing: 16) {
                // Current thresholds
                HStack(spacing: 24) {
                    ThresholdDisplay(
                        label: "Start Charging",
                        value: configStore.config.chargeStartThreshold,
                        color: .orange,
                        icon: "bolt.fill"
                    )
                    ThresholdDisplay(
                        label: "Stop Charging",
                        value: configStore.config.chargeStopThreshold,
                        color: .green,
                        icon: "bolt.slash.fill"
                    )
                }

                Divider().padding(.horizontal, 40)

                // Toggles
                VStack(spacing: 12) {
                    Toggle(isOn: $configStore.config.launchAtLogin) {
                        HStack(spacing: 8) {
                            Image(systemName: "arrow.clockwise.circle.fill")
                                .foregroundStyle(.blue)
                            Text("Launch at Login")
                        }
                    }
                    .onChange(of: configStore.config.launchAtLogin) { enabled in
                        try? enabled
                            ? SMAppService.mainApp.register()
                            : SMAppService.mainApp.unregister()
                    }

                    Toggle(isOn: $configStore.config.notificationsEnabled) {
                        HStack(spacing: 8) {
                            Image(systemName: "bell.badge.fill")
                                .foregroundStyle(.purple)
                            Text("Enable Notifications")
                        }
                    }
                }
                .toggleStyle(.switch)
                .padding(.horizontal, 60)
            }
            .padding(.vertical, 12)

            Spacer()
        }
        .padding(32)
    }

    // MARK: - Navigation

    private var navigationBar: some View {
        HStack {
            // Back button
            if currentPage > 0 {
                Button("Back") {
                    withAnimation { currentPage -= 1 }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
            }

            Spacer()

            // Page indicators
            HStack(spacing: 8) {
                ForEach(0..<pageCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentPage ? Color.accentColor : Color.primary.opacity(0.2))
                        .frame(width: 8, height: 8)
                }
            }

            Spacer()

            // Next / Start button
            if currentPage < pageCount - 1 {
                Button("Next") {
                    withAnimation { currentPage += 1 }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            } else {
                Button("Start") {
                    completeOnboarding()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
        }
    }

    // MARK: - Actions

    private func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
        hasCompletedOnboarding = true
    }
}

// MARK: - Subviews

private struct BulletRow: View {
    let icon: String
    let color: Color
    let text: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 28)
            Text(text)
                .font(.body)
        }
    }
}

private struct ThresholdDisplay: View {
    let label: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
            Text("\(value)%")
                .font(.title.weight(.bold).monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(width: 140)
        .padding(.vertical, 14)
        .background(color.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
    }
}
