import SwiftUI

public struct AIFleetDashboardView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isRefreshing = false

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header Stats Banner (Usage-first)
            headerStatsBanner

            // Student Plan Banner
            studentPlanBanner

            // Accounts List
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Text("CONNECTED AI ACCOUNTS & USAGE")
                        .font(.system(size: 10.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.5))

                    Spacer()

                    Button {
                        refreshData()
                    } label: {
                        HStack(spacing: 3) {
                            Image(systemName: "arrow.triangle.2.circlepath")
                                .font(.system(size: 9))
                                .rotationEffect(.degrees(isRefreshing ? 360 : 0))
                            Text("Rescan")
                                .font(.system(size: 10, weight: .semibold))
                        }
                        .foregroundStyle(AppTheme.accent)
                    }
                    .buttonStyle(.plain)
                }

                ForEach(appState.aiFleetSummary.accounts) { account in
                    AIAccountCardView(account: account)
                }
            }
        }
        .onAppear {
            if appState.aiFleetSummary.accounts.isEmpty {
                appState.refreshAIFleet()
            }
        }
    }

    private var headerStatsBanner: some View {
        HStack(spacing: 8) {
            statBox(
                title: "Student Cost",
                value: "$0.00",
                subtitle: "100% Free Access",
                icon: "graduationcap.fill",
                accentHex: "#10B981"
            )

            statBox(
                title: "Daily Prompts",
                value: "\(appState.aiFleetSummary.totalDailyPrompts)",
                subtitle: "across fleet",
                icon: "bolt.fill",
                accentHex: "#FBBF24"
            )

            statBox(
                title: "Active Models",
                value: "\(appState.aiFleetSummary.activeModelsCount)",
                subtitle: "Gemini, Claude, GPT",
                icon: "sparkles",
                accentHex: "#A855F7"
            )
        }
    }

    private func statBox(title: String, value: String, subtitle: String, icon: String, accentHex: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9.5))
                    .foregroundStyle(Color(hex: accentHex))
                Text(title)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(.white.opacity(0.6))
            }

            Text(value)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundStyle(.white)

            Text(subtitle)
                .font(.system(size: 8.5))
                .foregroundStyle(.white.opacity(0.4))
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#1A1B24").opacity(0.7))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.06), lineWidth: 1)
        )
    }

    private var studentPlanBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 18))
                .foregroundStyle(Color(hex: "#10B981"))

            VStack(alignment: .leading, spacing: 2) {
                Text("Student & Education Fleet Active")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(.white)

                Text("All accounts (Google Antigravity, Cursor Pro, GitHub Copilot) are tracked at $0.00 student tier with full token and quota monitoring.")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(hex: "#10B981").opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(hex: "#10B981").opacity(0.3), lineWidth: 1)
        )
    }

    private func refreshData() {
        withAnimation(.easeInOut(duration: 0.5)) {
            isRefreshing = true
        }
        appState.refreshAIFleet()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.6) {
            withAnimation {
                isRefreshing = false
            }
        }
    }
}
