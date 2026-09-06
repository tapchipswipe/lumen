import SwiftUI

struct BatteryRunwayCardView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        let p = appState.powerSnapshot

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Apple Silicon Power & Runway", systemImage: p.isCharging ? "bolt.batteryblock.fill" : "battery.100percent.bolt")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#63E6BE"))
                Spacer()
                Text("SOC METRICS")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            // Power Gauge & Metrics
            HStack(spacing: 14) {
                // Battery Percent Gauge
                ZStack {
                    Circle().stroke(Color.white.opacity(0.08), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: max(0.01, p.batteryLevel))
                        .stroke(
                            LinearGradient(
                                colors: [Color(hex: "#63E6BE"), Color(hex: "#10B981")],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                    VStack(spacing: 0) {
                        Text("\(p.batteryPercent)%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                    }
                }
                .frame(width: 42, height: 42)

                VStack(alignment: .leading, spacing: 2) {
                    Text(p.runwayFormatted)
                        .font(.system(size: 12.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(p.narrative)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("~\(String(format: "%.1f", p.estimatedWatts))W")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                    Text(p.thermalState)
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.03)))

            // Real-time Apple Silicon SoC power curve sparkline
            PowerCurveVisualizerView(powerSnapshot: p, powerHistory: appState.powerHistoryWatts)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}
