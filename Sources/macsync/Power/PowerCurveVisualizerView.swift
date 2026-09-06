import SwiftUI

struct PowerCurveVisualizerView: View {
    let powerSnapshot: PowerSnapshot
    let powerHistory: [Double] // Array of recent Watt measurements

    init(powerSnapshot: PowerSnapshot, powerHistory: [Double] = [3.8, 4.2, 5.1, 4.0, 6.2, 4.5, 3.9, 4.8, 5.4, 4.2]) {
        self.powerSnapshot = powerSnapshot
        self.powerHistory = powerHistory.isEmpty ? [4.2] : powerHistory
    }

    private var maxWatts: Double {
        max(10.0, (powerHistory.max() ?? 10.0) * 1.2)
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header with live wattage
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "bolt.badge.automatic.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(Color(hex: "#38BDF8"))
                    Text("SOC POWER & THERMAL CURVE")
                        .font(.system(size: 9.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.6))
                }
                Spacer()
                Text(String(format: "%.1fW", powerSnapshot.estimatedWatts))
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#38BDF8"))
            }

            // Real-time interactive power sparkline curve
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height

                Path { path in
                    guard powerHistory.count > 1 else { return }
                    let step = w / CGFloat(powerHistory.count - 1)

                    for (index, val) in powerHistory.enumerated() {
                        let normalizedY = CGFloat(1.0 - (val / maxWatts)) * h
                        let x = CGFloat(index) * step
                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: normalizedY))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: normalizedY))
                        }
                    }
                }
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#38BDF8"), Color(hex: "#10B981")],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )
            }
            .frame(height: 32)

            // Pacing & Thermal status
            HStack {
                Text(powerSnapshot.runwayFormatted)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                Spacer()
                Text(powerSnapshot.thermalState)
                    .font(.system(size: 9.5, weight: .semibold))
                    .foregroundStyle(Color(hex: "#10B981"))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.white.opacity(0.04))
        )
    }
}
