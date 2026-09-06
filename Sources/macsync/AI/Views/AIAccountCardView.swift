import SwiftUI

public struct AIAccountCardView: View {
    public let account: AIAccountQuota

    public init(account: AIAccountQuota) {
        self.account = account
    }

    public var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Service Icon, Account Name, and Student Badge
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(Color(hex: account.service.brandColorHex).opacity(0.18))
                        .frame(width: 30, height: 30)

                    Image(systemName: account.service.iconName)
                        .font(.system(size: 14, weight: .bold))
                        .foregroundStyle(Color(hex: account.service.brandColorHex))
                }

                VStack(alignment: .leading, spacing: 1.5) {
                    Text(account.service.displayName)
                        .font(.system(size: 12.5, weight: .bold))
                        .foregroundStyle(.white)

                    Text(account.planTier)
                        .font(.system(size: 10.5))
                        .foregroundStyle(.white.opacity(0.6))
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 1.5) {
                    HStack(spacing: 4) {
                        Image(systemName: "graduationcap.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(Color(hex: "#10B981"))
                        Text(account.monthlyCostUSD == 0 ? "FREE" : String(format: "$%.2f", account.monthlyCostUSD))
                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#10B981"))
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Capsule().fill(Color(hex: "#10B981").opacity(0.15)))

                    HStack(spacing: 3) {
                        Circle()
                            .fill(statusColor)
                            .frame(width: 5, height: 5)
                        Text(account.status.rawValue)
                            .font(.system(size: 9.5, weight: .medium))
                            .foregroundStyle(statusColor)
                    }
                }
            }

            // Quota Bar / Progress
            VStack(spacing: 4) {
                HStack {
                    Text("Usage: \(account.formattedUsed) / \(account.formattedTotal) \(account.unitLabel)")
                        .font(.system(size: 10.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.85))

                    Spacer()

                    Text("\(Int(account.usagePercentage * 100))%")
                        .font(.system(size: 10.5, weight: .bold, design: .rounded))
                        .foregroundStyle(statusColor)
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.08))
                            .frame(height: 6)

                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [
                                        Color(hex: account.service.brandColorHex),
                                        Color(hex: account.service.brandColorHex).opacity(0.7)
                                    ],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: max(4, geo.size.width * CGFloat(account.usagePercentage)), height: 6)
                    }
                }
                .frame(height: 6)
            }

            // Active Models Tag Row
            HStack(spacing: 5) {
                ForEach(account.activeModels.prefix(3), id: \.self) { model in
                    Text(model)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2.5)
                        .background(Capsule().fill(Color.white.opacity(0.06)))
                }

                Spacer()

                HStack(spacing: 3) {
                    Image(systemName: "clock")
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.4))
                    Text(account.lastActiveRelative)
                        .font(.system(size: 9.5))
                        .foregroundStyle(.white.opacity(0.5))
                }
            }

            // Summary Narrative
            Text(account.summaryNarrative)
                .font(.system(size: 10))
                .foregroundStyle(.white.opacity(0.55))
                .lineLimit(2)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(hex: "#1A1B24").opacity(0.85))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var statusColor: Color {
        switch account.status {
        case .healthy, .unlimited: return Color(hex: "#10B981")
        case .warning: return Color(hex: "#F59E0B")
        case .critical, .exhausted: return Color(hex: "#EF4444")
        }
    }
}
