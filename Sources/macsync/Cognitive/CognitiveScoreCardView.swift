import SwiftUI

struct CognitiveScoreCardView: View {
    let snapshot: CognitiveFragmentationSnapshot

    init(snapshot: CognitiveFragmentationSnapshot) {
        self.snapshot = snapshot
    }

    private var scoreColor: Color {
        if snapshot.flowScore >= 80 { return Color(hex: "#10B981") } // Emerald Flow
        if snapshot.flowScore >= 60 { return Color(hex: "#38BDF8") } // Sky Blue
        if snapshot.flowScore >= 40 { return Color(hex: "#F59E0B") } // Amber
        return Color(hex: "#EF4444") // Red
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(scoreColor)
                    Text("COGNITIVE FLOW & FRAGMENTATION")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.75))
                }
                Spacer()
                Text(snapshot.flowStateLabel)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(scoreColor)
                    .padding(.horizontal, 7)
                    .padding(.vertical, 3)
                    .background(Capsule().fill(scoreColor.opacity(0.15)))
            }

            // Primary Flow Gauge & Metrics
            HStack(spacing: 16) {
                // Circular Flow Gauge
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.08), lineWidth: 6)
                        .frame(width: 54, height: 54)
                    Circle()
                        .trim(from: 0, to: CGFloat(snapshot.flowScore) / 100.0)
                        .stroke(
                            LinearGradient(
                                colors: [scoreColor, scoreColor.opacity(0.7)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .frame(width: 54, height: 54)
                    VStack(spacing: 0) {
                        Text("\(snapshot.flowScore)")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                        Text("FLOW")
                            .font(.system(size: 7.5, weight: .bold))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                }

                // 3 Key Cognitive Signals
                VStack(spacing: 6) {
                    HStack {
                        metricItem(title: "CFI Index", value: "\(snapshot.cfiScore)/100", icon: "arrow.triangle.swap")
                        Spacer()
                        metricItem(title: "Context Switches", value: "\(snapshot.switchesPerHour)/hr", icon: "macwindow.on.rectangle")
                    }
                    HStack {
                        metricItem(title: "Avg Sprint", value: "\(snapshot.averageFocusSprintMinutes)m", icon: "timer")
                        Spacer()
                        metricItem(title: "Typing Cadence", value: "\(snapshot.keystrokeCadenceWPM) WPM", icon: "keyboard.fill")
                    }
                }
            }

            // Narrative
            Text(snapshot.narrative)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.75))
                .lineLimit(2)
        }
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(hex: "#161822").opacity(0.85))
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(Color.white.opacity(0.08), lineWidth: 1)
                )
        )
    }

    private func metricItem(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 5) {
            Image(systemName: icon)
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(.system(size: 9))
                    .foregroundStyle(.white.opacity(0.45))
                Text(value)
                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }
        }
    }
}
