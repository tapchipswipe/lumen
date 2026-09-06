import SwiftUI

struct AudioFlowInsightView: View {
    @ObservedObject var appState = AppState.shared

    var body: some View {
        let report = appState.audioFlowReport

        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Soundtrack to Deep Work", systemImage: "music.quarternote.3")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#A78BFA"))
                Spacer()
                if appState.crossDeviceReport.mobileFocusMinutes > 0 {
                    HStack(spacing: 3) {
                        Image(systemName: "iphone")
                            .font(.system(size: 8))
                        Text("\(appState.crossDeviceReport.mobileFocusMinutes)m iPhone")
                            .font(.system(size: 8.5, weight: .semibold))
                    }
                    .foregroundStyle(Color(hex: "#60A5FA"))
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Capsule().fill(Color(hex: "#60A5FA").opacity(0.15)))
                }
                Text("+\(report.flowStateVelocityBoostPercent)% FLOW VELOCITY")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(AppTheme.batteryGreen)
                    .padding(.horizontal, 5).padding(.vertical, 1.5)
                    .background(Capsule().fill(AppTheme.batteryGreen.opacity(0.15)))
            }

            Text(report.summary)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.6))

            VStack(spacing: 6) {
                ForEach(report.topTracks.prefix(4)) { t in
                    HStack(spacing: 8) {
                        Image(systemName: "headphones")
                            .font(.system(size: 11))
                            .foregroundStyle(Color(hex: "#A78BFA"))
                            .frame(width: 22, height: 22)
                            .background(Circle().fill(Color(hex: "#A78BFA").opacity(0.12)))

                        VStack(alignment: .leading, spacing: 1) {
                            Text(t.title)
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                            Text("\(t.artist) · \(t.playMinutes)m played")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                        }

                        Spacer()

                        VStack(alignment: .trailing, spacing: 1) {
                            if t.avgKeystrokesPerMin > 0 {
                                Text("\(t.avgKeystrokesPerMin) keys/min")
                                    .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                    .foregroundStyle(AppTheme.tileKey)
                                Text("Score \(t.avgFocusScore)")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(Color(hex: "#FBBF24"))
                            } else {
                                Text("\(t.playCount) plays")
                                    .font(.system(size: 10.5, weight: .semibold, design: .rounded))
                                    .foregroundStyle(Color(hex: "#A78BFA"))
                                Text("Library Track")
                                    .font(.system(size: 8.5))
                                    .foregroundStyle(.white.opacity(0.4))
                            }
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.02)))
                }
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }
}
