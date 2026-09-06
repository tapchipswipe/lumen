import SwiftUI

struct HUDContentView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            // ⌘K Copilot Chat Trigger Button
            Button {
                appState.showSpotlightSearch = true
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(Color(hex: "#FBBF24"))
                    Text("⌘K")
                        .font(.system(size: 10, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.85))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Capsule().fill(Color.white.opacity(0.08)))
            }
            .buttonStyle(.plain)
            .help("Open Lumen Copilot Chat (⌘K)")

            Divider().frame(height: 14).opacity(0.3)

            // Lumen Bolt Indicator
            HStack(spacing: 6) {
                Image(systemName: "bolt.fill")
                    .font(.system(size: 13, weight: .bold))
                    .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                Text("\(Int(appState.stats.activeMinutes))m")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
            }

            Divider().frame(height: 14).opacity(0.3)

            // Keystroke / Typing velocity
            HStack(spacing: 5) {
                Image(systemName: "keyboard.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.tileKey)
                Text("\(max(appState.stats.keystrokes, appState.liveKeystrokes)) keys")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.85))
            }

            Divider().frame(height: 14).opacity(0.3)

            // Cognitive Flow Score Badge
            HStack(spacing: 4) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 10))
                    .foregroundStyle(Color(hex: "#10B981"))
                Text("Flow: \(appState.cognitiveSnapshot.flowScore)")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
                    .foregroundStyle(Color(hex: "#10B981"))
            }

            Divider().frame(height: 14).opacity(0.3)

            // Top App Indicator
            HStack(spacing: 5) {
                Image(systemName: "sparkles")
                    .font(.system(size: 10))
                    .foregroundStyle(AppTheme.accent)
                Text(appState.stats.apps.first?.name ?? "Lumen")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.white.opacity(0.85))
                    .lineLimit(1)
            }

            if isHovered {
                Button {
                    appState.showStandupModal = true
                } label: {
                    Image(systemName: "doc.text.fill")
                        .font(.system(size: 11))
                        .foregroundStyle(AppTheme.accent)
                        .help("Generate Daily Standup")
                }
                .buttonStyle(.plain)
            }

            if isHovered {
                Button {
                    HUDWindowController.shared.hide()
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.white.opacity(0.5))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color(hex: "#12131A").opacity(0.88))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color(hex: "#FBBF24").opacity(0.4), Color.white.opacity(0.1)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1
                )
        )
        .shadow(color: .black.opacity(0.35), radius: 10, x: 0, y: 4)
        .onHover { isHovered = $0 }
    }
}
