import SwiftUI
import AppKit

struct StandupModalView: View {
    @Environment(\.dismiss) private var dismiss
    let report: DailyStandupReport
    @State private var copied: Bool = false

    init(report: DailyStandupReport) {
        self.report = report
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Header
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                    Text("1-CLICK DAILY STANDUP GENERATOR")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .buttonStyle(.plain)
            }

            // Standup Preview Area
            ScrollView {
                Text(report.markdownOutput)
                    .font(.system(size: 12, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.black.opacity(0.4)))
            }
            .frame(maxHeight: 220)

            // Footer Actions
            HStack {
                Text("Synthesized from \(report.totalFocusMinutes)m focus & Git commits")
                    .font(.system(size: 10))
                    .foregroundStyle(.white.opacity(0.45))

                Spacer()

                Button {
                    let pasteboard = NSPasteboard.general
                    pasteboard.clearContents()
                    pasteboard.setString(report.markdownOutput, forType: .string)
                    withAnimation { copied = true }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
                        withAnimation { copied = false }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: copied ? "checkmark.circle.fill" : "doc.on.doc.fill")
                            .font(.system(size: 11))
                        Text(copied ? "Copied to Clipboard!" : "Copy Standup (Markdown)")
                            .font(.system(size: 11, weight: .bold))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(copied ? Color(hex: "#10B981") : AppTheme.accent)
                    )
                    .foregroundStyle(.black)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(18)
        .frame(width: 480)
        .background(
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(hex: "#12131A"))
                .overlay(
                    RoundedRectangle(cornerRadius: 16)
                        .stroke(Color.white.opacity(0.12), lineWidth: 1)
                )
        )
    }
}
