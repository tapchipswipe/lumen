import Charts
import SwiftUI

// MARK: - Apple Health Dashboard View

struct AppleHealthDashboardView: View {
    let snap: AppleHealthSnapshot
    @State private var animateRings = false

    private let amber = Color(hex: "#FBBF24")
    private let emerald = Color(hex: "#10B981")
    private let purple = Color(hex: "#8B5CF6")
    private let blue = Color(hex: "#3B82F6")
    private let red = Color(hex: "#EF4444")
    private let rose = Color(hex: "#FB7185")
    private let teal = Color(hex: "#14B8A6")
    private let surface = Color(hex: "#1A1A2E")

    var body: some View {
        if !snap.isAvailable {
            notConnectedView
        } else {
            healthDataView
        }
    }

    // MARK: - Not Connected Placeholder

    private var notConnectedView: some View {
        VStack(spacing: 24) {
            // Header
            HStack(spacing: 0) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rose)
                Text("  Apple Health")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Not Connected")
                    .font(.system(size: 10, weight: .semibold))
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.45))
            }

            // Big prompt
            VStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(rose.opacity(0.08))
                        .frame(width: 80, height: 80)
                    Image(systemName: "heart.text.square.fill")
                        .font(.system(size: 36))
                        .foregroundStyle(rose.opacity(0.7))
                }
                Text("Connect Apple Health")
                    .font(.system(size: 17, weight: .bold))
                    .foregroundStyle(.white)
                Text("Export your health data from iPhone to see\nstep counts, sleep, heart rate, and more — right here.")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)

            // Two-column setup: First export + Auto-sync
            HStack(spacing: 12) {

                // Column 1: First-time manual export
                VStack(alignment: .leading, spacing: 12) {
                    Label("One-Time Setup", systemImage: "arrow.down.doc.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(amber)

                    stepRow(n: 1, text: "On iPhone: **Health** app")
                    stepRow(n: 2, text: "Profile photo → **Export All Health Data**")
                    stepRow(n: 3, text: "**Share → Files → Downloads**")
                    stepRow(n: 4, text: "Lumen detects it **instantly** — no restart needed")

                    Spacer()

                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(Color(hex: "#10B981"))
                        Text("Watching Downloads folder live")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(surface))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(amber.opacity(0.2), lineWidth: 1))

                // Column 2: Auto-sync via Shortcuts
                VStack(alignment: .leading, spacing: 12) {
                    Label("Auto-Sync Daily", systemImage: "arrow.clockwise.icloud.fill")
                        .font(.system(size: 12, weight: .bold))
                        .foregroundStyle(Color(hex: "#8B5CF6"))

                    stepRow(n: 1, text: "Open **Shortcuts** app on iPhone")
                    stepRow(n: 2, text: "**Automation → New → Time of Day** (e.g. 7 AM)")
                    stepRow(n: 3, text: "Add: **Export Health Data → Save to Downloads**")
                    stepRow(n: 4, text: "Runs every morning — Lumen reads it automatically")

                    Spacer()

                    Button {
                        LumenHealthShortcuts.openShortcutsApp()
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: "arrow.up.forward.app.fill")
                            Text("Open Shortcuts App")
                        }
                        .font(.system(size: 11, weight: .bold))
                        .padding(.horizontal, 12).padding(.vertical, 6)
                        .background(Capsule().fill(Color(hex: "#8B5CF6").opacity(0.2)))
                        .foregroundStyle(Color(hex: "#8B5CF6"))
                    }
                    .buttonStyle(.plain)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RoundedRectangle(cornerRadius: 12).fill(surface))
                .overlay(RoundedRectangle(cornerRadius: 12).strokeBorder(Color(hex: "#8B5CF6").opacity(0.2), lineWidth: 1))
            }
        }
    }

    private func stepRow(n: Int, text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Text("\(n)")
                .font(.system(size: 10, weight: .black))
                .frame(width: 18, height: 18)
                .background(Circle().fill(amber.opacity(0.2)))
                .foregroundStyle(amber)
            Text(text)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.7))
        }
    }

    // MARK: - Main Health Data View

    private var healthDataView: some View {
        VStack(spacing: 20) {
            // Header row
            HStack(spacing: 0) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(rose)
                Text("  Apple Health")
                    .font(.system(size: 15, weight: .bold))
                    .foregroundStyle(.white)
                Spacer()
                Text("Updated \(snap.lastUpdated, style: .relative) ago")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.4))
            }

        // Activity Rings + Step Hero
        HStack(spacing: 20) {
            // Activity Rings
            ZStack {
                RingView(progress: snap.moveRing / 100, color: red, thickness: 12, radius: 55)
                RingView(progress: snap.exerciseRing / 100, color: emerald, thickness: 10, radius: 42)
                RingView(progress: snap.standRing / 100, color: blue, thickness: 8, radius: 30)
            }
            .frame(width: 130, height: 130)
                .onAppear { withAnimation(.easeOut(duration: 1.2)) { animateRings = true } }

                // Ring Legend
                VStack(alignment: .leading, spacing: 8) {
                    ringLegendRow(color: red, label: "Move", value: "\(Int(snap.activeEnergyBurned)) kcal", pct: snap.moveRing)
                    ringLegendRow(color: emerald, label: "Exercise", value: "\(snap.exerciseMinutes) min", pct: snap.exerciseRing)
                    ringLegendRow(color: blue, label: "Stand", value: "\(snap.standHours)h", pct: snap.standRing)
                }

                Spacer()

                // Step count hero
                VStack(spacing: 4) {
                    Text("\(snap.stepCount.formatted(.number.grouping(.automatic)))")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(.white)
                    Text("steps today")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                    Divider().frame(width: 60).padding(.vertical, 4)
                    HStack(spacing: 12) {
                        miniStat(icon: "figure.walk", value: "\(String(format: "%.1f", snap.distanceWalkingRunning)) km", color: emerald)
                        miniStat(icon: "arrow.up.forward", value: "\(snap.flightsClimbed)", color: amber)
                    }
                }
            }
            .lumenCard()

            // Vitals Row
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 12), count: 4), spacing: 12) {
                vitalCard(icon: "heart.fill", label: "Resting HR", value: "\(snap.restingHeartRate)", unit: "bpm", color: rose, trend: heartRateTrend)
                vitalCard(icon: "waveform.path.ecg", label: "HRV", value: String(format: "%.0f", snap.heartRateVariability), unit: "ms", color: purple, trend: hrvTrend)
                vitalCard(icon: "lungs.fill", label: "Blood O₂", value: String(format: "%.1f", snap.bloodOxygen), unit: "%", color: blue, trend: .neutral)
                vitalCard(icon: "bolt.heart.fill", label: "VO₂ Max", value: String(format: "%.1f", snap.vo2Max), unit: "mL/kg", color: teal, trend: .neutral)
            }

            // Sleep Row
            HStack(spacing: 12) {
                // Sleep card
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "moon.stars.fill")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(purple)
                        Text("Sleep")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                        sleepScoreBadge(snap.sleepScore)
                    }
                    HStack(alignment: .lastTextBaseline, spacing: 4) {
                        Text(String(format: "%.1f", snap.sleepHours))
                            .font(.system(size: 32, weight: .black, design: .rounded))
                            .foregroundStyle(.white)
                        Text("hours")
                            .font(.system(size: 12))
                            .foregroundStyle(.white.opacity(0.5))
                    }
                    HStack(spacing: 4) {
                        Text("🛏  \(snap.sleepBedtime)")
                        Text("→")
                        Text("☀️ \(snap.sleepWakeTime)")
                    }
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.55))

                    // Sleep stage bar
                    sleepStageBar
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(surface))
                .frame(maxWidth: .infinity)

                // Body Metrics
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Image(systemName: "figure.stand")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(amber)
                        Text("Body")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.white)
                        Spacer()
                    }
                    VStack(spacing: 10) {
                        bodyMetricRow(label: "Weight", value: snap.weight > 0 ? String(format: "%.1f kg", snap.weight) : "--", icon: "scalemass.fill", color: amber)
                        bodyMetricRow(label: "BMI", value: snap.bmi > 0 ? String(format: "%.1f", snap.bmi) : "--", icon: "chart.bar.fill", color: teal)
                        bodyMetricRow(label: "Resp. Rate", value: snap.respiratoryRate > 0 ? String(format: "%.0f /min", snap.respiratoryRate) : "--", icon: "wind", color: blue)
                        bodyMetricRow(label: "Mindfulness", value: snap.mindfulnessMinutes > 0 ? "\(snap.mindfulnessMinutes) min" : "--", icon: "brain.head.profile", color: purple)
                        bodyMetricRow(label: "Env. Noise", value: snap.environmentalNoise > 0 ? String(format: "%.0f dB", snap.environmentalNoise) : "--", icon: "ear", color: rose)
                    }
                }
                .padding(16)
                .background(RoundedRectangle(cornerRadius: 12).fill(surface))
                .frame(maxWidth: .infinity)
            }

        }  // end VStack (healthDataView)
    }

    // MARK: - Sub-views

    private func ringLegendRow(color: Color, label: String, value: String, pct: Double) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.7))
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.white)
            Text(String(format: "%.0f%%", pct))
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(color)
        }
    }

    private func miniStat(icon: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
            Text(value).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
        }
    }

    private func vitalCard(icon: String, label: String, value: String, unit: String, color: Color, trend: TrendDirection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon).font(.system(size: 13)).foregroundStyle(color)
                Spacer()
                trend.badge
            }
            HStack(alignment: .lastTextBaseline, spacing: 3) {
                Text(value == "0" ? "--" : value)
                    .font(.system(size: 22, weight: .black, design: .rounded))
                    .foregroundStyle(.white)
                Text(unit)
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.5))
            }
            Text(label)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(.white.opacity(0.55))
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: 12).fill(surface))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .strokeBorder(color.opacity(0.2), lineWidth: 1)
        )
    }

    private func bodyMetricRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack {
            Image(systemName: icon).font(.system(size: 11)).foregroundStyle(color).frame(width: 18)
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.6))
            Spacer()
            Text(value).font(.system(size: 12, weight: .bold)).foregroundStyle(.white)
        }
    }

    private func sleepScoreBadge(_ score: Int) -> some View {
        let color: Color = score >= 80 ? emerald : score >= 60 ? amber : red
        return Text("\(score)")
            .font(.system(size: 11, weight: .black))
            .padding(.horizontal, 8).padding(.vertical, 3)
            .background(Capsule().fill(color.opacity(0.25)))
            .foregroundStyle(color)
    }

    private var sleepStageBar: some View {
        let total = snap.sleepDeepHours + snap.sleepREMHours + snap.sleepCoreLightHours
        let deepFrac = total > 0 ? snap.sleepDeepHours / total : 0
        let remFrac = total > 0 ? snap.sleepREMHours / total : 0
        let lightFrac = total > 0 ? snap.sleepCoreLightHours / total : 0

        return VStack(alignment: .leading, spacing: 4) {
            GeometryReader { geo in
                HStack(spacing: 2) {
                    Capsule().fill(blue).frame(width: geo.size.width * deepFrac)
                    Capsule().fill(purple).frame(width: geo.size.width * remFrac)
                    Capsule().fill(Color(hex: "#64748B")).frame(width: geo.size.width * lightFrac)
                }
            }
            .frame(height: 7)

            HStack(spacing: 12) {
                stageLegend(color: blue, label: "Deep \(String(format: "%.1f", snap.sleepDeepHours))h")
                stageLegend(color: purple, label: "REM \(String(format: "%.1f", snap.sleepREMHours))h")
                stageLegend(color: Color(hex: "#64748B"), label: "Core \(String(format: "%.1f", snap.sleepCoreLightHours))h")
            }
        }
    }

    private func stageLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 6, height: 6)
            Text(label).font(.system(size: 9, weight: .medium)).foregroundStyle(.white.opacity(0.5))
        }
    }

    // MARK: - Computed Properties

    private var heartRateTrend: TrendDirection {
        guard snap.restingHeartRate > 0 else { return .neutral }
        if snap.restingHeartRate < 60 { return .up }
        if snap.restingHeartRate > 80 { return .down }
        return .neutral
    }

    private var hrvTrend: TrendDirection {
        guard snap.heartRateVariability > 0 else { return .neutral }
        return snap.heartRateVariability > 50 ? .up : .down
    }
}

// MARK: - Ring View

struct RingView: View {
    let progress: Double
    let color: Color
    let thickness: CGFloat
    let radius: CGFloat

    var body: some View {
        ZStack {
            Circle()
                .stroke(color.opacity(0.15), lineWidth: thickness)
                .frame(width: radius * 2, height: radius * 2)
            Circle()
                .trim(from: 0, to: min(CGFloat(progress), 1.0))
                .stroke(color, style: StrokeStyle(lineWidth: thickness, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .frame(width: radius * 2, height: radius * 2)
        }
    }
}

// MARK: - Trend Direction

enum TrendDirection {
    case up, down, neutral

    var badge: some View {
        switch self {
        case .up:
            return AnyView(
                Text("↑").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#10B981"))
            )
        case .down:
            return AnyView(
                Text("↓").font(.system(size: 10, weight: .bold)).foregroundStyle(Color(hex: "#EF4444"))
            )
        case .neutral:
            return AnyView(EmptyView())
        }
    }
}

// MARK: - lumenCard modifier helper

extension View {
    func lumenCard() -> some View {
        self
            .padding(16)
            .background(RoundedRectangle(cornerRadius: 14).fill(Color(hex: "#1A1A2E")))
    }
}

// MARK: - Preview

#if DEBUG
struct AppleHealthDashboardView_Previews: PreviewProvider {
    static var previews: some View {
        AppleHealthDashboardView(snap: AppleHealthEngine.buildDemoSnapshot())
            .frame(width: 860)
            .background(Color(hex: "#0A0A0F"))
            .preferredColorScheme(.dark)
    }
}
#endif
