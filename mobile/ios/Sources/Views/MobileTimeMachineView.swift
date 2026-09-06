import SwiftUI

public struct MobileTimeMachineView: View {
    @State private var scrubberMinutes: Double = 720 // 12:00 PM default
    @State private var events: [MobileTrackerEvent] = []

    public var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                // Scrubber Dial Card
                VStack(spacing: 12) {
                    HStack {
                        Text("SCRUBBER TIME")
                            .font(.system(size: 11, weight: .bold, design: .monospaced))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatScrubberTime(scrubberMinutes))
                            .font(.system(size: 24, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.36, green: 0.55, blue: 1.0))
                    }

                    Slider(value: $scrubberMinutes, in: 0...1440, step: 5)
                        .accentColor(Color(red: 0.36, green: 0.55, blue: 1.0))

                    HStack {
                        Text("00:00 AM")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("12:00 PM")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                        Spacer()
                        Text("11:59 PM")
                            .font(.system(size: 10))
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
                .background(Color(white: 0.12))
                .cornerRadius(14)
                .padding(.horizontal)

                // Replay Window
                VStack(alignment: .leading, spacing: 14) {
                    Text("SYNCHRONIZED TIMELINE FRAME")
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundColor(.secondary)

                    HStack {
                        Label("Motion State", systemImage: "figure.walk")
                            .foregroundColor(.cyan)
                        Spacer()
                        Text("Active Walking (84 steps/min)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        Label("Audio Route", systemImage: "airpodspro")
                            .foregroundColor(.orange)
                        Spacer()
                        Text("AirPods Pro (ANC Active)")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                    Divider().background(Color.white.opacity(0.08))

                    HStack {
                        Label("Network & GPS", systemImage: "location.fill")
                            .foregroundColor(.purple)
                        Spacer()
                        Text("5G Ultra Wideband · Boston, MA")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.white)
                    }
                }
                .padding()
                .background(Color(white: 0.08))
                .cornerRadius(14)
                .padding(.horizontal)

                Spacer()
            }
            .padding(.top, 10)
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Time Machine")
        }
    }

    private func formatScrubberTime(_ totalMinutes: Double) -> String {
        let hrs = Int(totalMinutes) / 60
        let mins = Int(totalMinutes) % 60
        let period = hrs >= 12 ? "PM" : "AM"
        let displayHrs = hrs == 0 ? 12 : (hrs > 12 ? hrs - 12 : hrs)
        return String(format: "%02d:%02d %@", displayHrs, mins, period)
    }
}
