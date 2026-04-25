import SwiftUI

struct TemperatureGaugeView: View {
    let temperature: Double?

    @State private var isPulsing = false

    private var displayTemp: Double {
        temperature ?? 0
    }

    private var gaugeColor: Color {
        guard let temp = temperature else { return .gray }
        if temp > 40 { return .red }
        if temp >= 35 { return .yellow }
        return .green
    }

    /// Normalized progress for the ring (0...1), mapping 20°C..50°C range.
    private var progress: Double {
        guard let temp = temperature else { return 0 }
        let clamped = min(max(temp, 20), 50)
        return (clamped - 20) / 30.0
    }

    private var isOverheating: Bool {
        guard let temp = temperature else { return false }
        return temp > 40
    }

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                // Background ring
                Circle()
                    .stroke(Color.gray.opacity(0.2), lineWidth: 5)

                // Colored progress ring
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(gaugeColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .opacity(isPulsing ? 0.5 : 1.0)
                    .animation(
                        isOverheating
                            ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                            : .default,
                        value: isPulsing
                    )

                // Center temperature text
                if let temp = temperature {
                    Text(String(format: "%.1f°", temp))
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(gaugeColor)
                } else {
                    Text("--")
                        .font(.system(size: 12, weight: .semibold, design: .rounded))
                        .foregroundColor(.gray)
                }
            }
            .frame(width: 48, height: 48)

            Text("Battery Temp")
                .font(.system(size: 9, weight: .medium))
                .foregroundColor(.secondary)
        }
        .frame(width: 60, height: 80)
        .onAppear {
            if isOverheating {
                isPulsing = true
            }
        }
        .onChange(of: isOverheating) { overheating in
            isPulsing = overheating
        }
    }
}

#if DEBUG
struct TemperatureGaugeView_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 16) {
            TemperatureGaugeView(temperature: 28.5)
            TemperatureGaugeView(temperature: 37.2)
            TemperatureGaugeView(temperature: 42.8)
            TemperatureGaugeView(temperature: nil)
        }
        .padding()
    }
}
#endif
