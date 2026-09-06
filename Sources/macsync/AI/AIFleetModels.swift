import Foundation

public enum AIServiceType: String, CaseIterable, Codable, Identifiable {
    case antigravity = "antigravity"
    case cursor = "cursor"
    case copilot = "copilot"
    case openai = "openai"
    case anthropic = "anthropic"
    case perplexity = "perplexity"

    public var id: String { rawValue }

    public var displayName: String {
        switch self {
        case .antigravity: return "Google Antigravity"
        case .cursor: return "Cursor AI"
        case .copilot: return "GitHub Copilot"
        case .openai: return "OpenAI"
        case .anthropic: return "Anthropic (Claude)"
        case .perplexity: return "Perplexity Pro"
        }
    }

    public var iconName: String {
        switch self {
        case .antigravity: return "atom"
        case .cursor: return "cursorarrow.rays"
        case .copilot: return "chevron.left.forwardslash.chevron.right"
        case .openai: return "sparkles"
        case .anthropic: return "brain"
        case .perplexity: return "magnifyingglass.circle.fill"
        }
    }

    public var brandColorHex: String {
        switch self {
        case .antigravity: return "#4285F4" // Google Blue
        case .cursor: return "#A855F7"      // Cursor Purple
        case .copilot: return "#10B981"     // Copilot Emerald
        case .openai: return "#10A37F"      // OpenAI Teal
        case .anthropic: return "#D97706"   // Claude Amber
        case .perplexity: return "#06B6D4"  // Perplexity Cyan
        }
    }
}

public enum AIQuotaStatus: String, Codable {
    case healthy = "Healthy"
    case warning = "Near Limit"
    case critical = "Critical"
    case exhausted = "Limit Reached"
    case unlimited = "Active"
}

public struct AIAccountQuota: Identifiable, Codable {
    public let id: String
    public let service: AIServiceType
    public let accountIdentifier: String
    public let planTier: String
    public let isStudentOrFree: Bool
    public let monthlyCostUSD: Double
    public let renewalDateFormatted: String
    public let usedUnits: Int64
    public let totalUnits: Int64
    public let unitLabel: String
    public let activeModels: [String]
    public let status: AIQuotaStatus
    public let dailyPromptCount: Int
    public let lastActiveRelative: String
    public let summaryNarrative: String

    public init(
        id: String,
        service: AIServiceType,
        accountIdentifier: String,
        planTier: String,
        isStudentOrFree: Bool = true,
        monthlyCostUSD: Double = 0.0,
        renewalDateFormatted: String,
        usedUnits: Int64,
        totalUnits: Int64,
        unitLabel: String,
        activeModels: [String],
        status: AIQuotaStatus,
        dailyPromptCount: Int,
        lastActiveRelative: String,
        summaryNarrative: String
    ) {
        self.id = id
        self.service = service
        self.accountIdentifier = accountIdentifier
        self.planTier = planTier
        self.isStudentOrFree = isStudentOrFree
        self.monthlyCostUSD = monthlyCostUSD
        self.renewalDateFormatted = renewalDateFormatted
        self.usedUnits = usedUnits
        self.totalUnits = totalUnits
        self.unitLabel = unitLabel
        self.activeModels = activeModels
        self.status = status
        self.dailyPromptCount = dailyPromptCount
        self.lastActiveRelative = lastActiveRelative
        self.summaryNarrative = summaryNarrative
    }

    public var usagePercentage: Double {
        guard totalUnits > 0 else { return 0.0 }
        return min(1.0, Double(usedUnits) / Double(totalUnits))
    }

    public var remainingUnits: Int64 {
        max(0, totalUnits - usedUnits)
    }

    public var formattedUsed: String {
        if usedUnits >= 1_000_000 {
            return String(format: "%.1fM", Double(usedUnits) / 1_000_000.0)
        } else if usedUnits >= 1_000 {
            return String(format: "%.1fk", Double(usedUnits) / 1_000.0)
        }
        return "\(usedUnits)"
    }

    public var formattedTotal: String {
        if totalUnits >= 1_000_000 {
            return String(format: "%.1fM", Double(totalUnits) / 1_000_000.0)
        } else if totalUnits >= 1_000 {
            return String(format: "%.1fk", Double(totalUnits) / 1_000.0)
        }
        return "\(totalUnits)"
    }
}

public struct AIFleetSummary: Codable {
    public let totalAccounts: Int
    public let totalMonthlySpendUSD: Double
    public let isAllStudentOrFree: Bool
    public let totalDailyPrompts: Int
    public let totalTokensUsedToday: Int64
    public let activeModelsCount: Int
    public let accounts: [AIAccountQuota]

    public init(
        totalAccounts: Int,
        totalMonthlySpendUSD: Double = 0.0,
        isAllStudentOrFree: Bool = true,
        totalDailyPrompts: Int,
        totalTokensUsedToday: Int64 = 0,
        activeModelsCount: Int,
        accounts: [AIAccountQuota]
    ) {
        self.totalAccounts = totalAccounts
        self.totalMonthlySpendUSD = totalMonthlySpendUSD
        self.isAllStudentOrFree = isAllStudentOrFree
        self.totalDailyPrompts = totalDailyPrompts
        self.totalTokensUsedToday = totalTokensUsedToday
        self.activeModelsCount = activeModelsCount
        self.accounts = accounts
    }

    public static let empty = AIFleetSummary(
        totalAccounts: 0,
        totalMonthlySpendUSD: 0.0,
        isAllStudentOrFree: true,
        totalDailyPrompts: 0,
        totalTokensUsedToday: 0,
        activeModelsCount: 0,
        accounts: []
    )
}
