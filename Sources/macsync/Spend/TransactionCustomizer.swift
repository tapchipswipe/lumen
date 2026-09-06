import Foundation

struct TransactionOverride: Codable {
    var customMerchant: String?
    var customAmount: Decimal?
    var customCardLast4: String?
    var customCategory: ReceiptCategory?
    var isIncome: Bool?
    var isDeductible: Bool?
    var notes: String?

    init(
        customMerchant: String? = nil,
        customAmount: Decimal? = nil,
        customCardLast4: String? = nil,
        customCategory: ReceiptCategory? = nil,
        isIncome: Bool? = nil,
        isDeductible: Bool? = nil,
        notes: String? = nil
    ) {
        self.customMerchant = customMerchant
        self.customAmount = customAmount
        self.customCardLast4 = customCardLast4
        self.customCategory = customCategory
        self.isIncome = isIncome
        self.isDeductible = isDeductible
        self.notes = notes
    }
}

enum TransactionCustomizer {

    private static let storageKey = "lumen.transactionOverrides"

    /// Default seeded user rules:
    /// - Latex Factory -> Joyce Card (1533)
    /// - Swell Labs -> Joyce Card (1533)
    /// - Venmo $17.00 -> Paid to me (Income)
    /// - Venmo $8.00 -> Paid out (Expense)
    private static let defaultRuleMerchants: [String: TransactionOverride] = [
        "latex factory": TransactionOverride(
            customMerchant: "Latex Factory",
            customCardLast4: "1533",
            notes: "Joyce Card"
        ),
        "swell labs": TransactionOverride(
            customMerchant: "Swell Labs",
            customCardLast4: "1533",
            customCategory: .software,
            isDeductible: true,
            notes: "Joyce Card · Dev Tools"
        ),
        "venmo_17": TransactionOverride(
            customMerchant: "Venmo",
            customAmount: Decimal(17.00),
            isIncome: true,
            notes: "Paid to me (Venmo)"
        ),
        "venmo_8": TransactionOverride(
            customMerchant: "Venmo",
            customAmount: Decimal(8.00),
            isIncome: false,
            notes: "Paid out (Venmo)"
        )
    ]

    static var overrides: [String: TransactionOverride] {
        get {
            guard let data = UserDefaults.standard.data(forKey: storageKey),
                  let decoded = try? JSONDecoder().decode([String: TransactionOverride].self, from: data) else {
                return defaultRuleMerchants
            }
            var merged = defaultRuleMerchants
            for (k, v) in decoded {
                merged[k] = v
            }
            return merged
        }
        set {
            if let encoded = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(encoded, forKey: storageKey)
            }
        }
    }

    /// Generates lookup keys for a receipt (by UUID and by Merchant signature)
    static func key(for receipt: ReceiptPayload) -> String {
        return receipt.id.uuidString
    }

    private static func merchantKey(for receipt: ReceiptPayload) -> String {
        let name = receipt.merchant.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let amtInt = NSDecimalNumber(decimal: receipt.amount).intValue
        if name.contains("venmo") {
            return "venmo_\(amtInt)"
        }
        if name.contains("latex") {
            return "latex factory"
        }
        if name.contains("swell") {
            return "swell labs"
        }
        return name
    }

    /// Applies custom overrides (merchant, card, amount, income/expense direction, tax status) to a ReceiptPayload.
    static func apply(to receipt: ReceiptPayload) -> ReceiptPayload {
        let idKey = key(for: receipt)
        let mKey = merchantKey(for: receipt)

        let override = overrides[idKey] ?? overrides[mKey]

        guard let ov = override else {
            return receipt
        }

        let updatedMerchant = ov.customMerchant ?? receipt.merchant
        let updatedAmount = ov.customAmount ?? receipt.amount
        let updatedCard = ov.customCardLast4 ?? receipt.cardLast4
        let updatedCat = ov.customCategory ?? receipt.category
        let updatedNotes = ov.notes ?? receipt.notes

        return ReceiptPayload(
            id: receipt.id,
            merchant: updatedMerchant,
            amount: updatedAmount,
            currency: receipt.currency,
            cardLast4: updatedCard,
            category: updatedCat,
            transactionDate: receipt.transactionDate,
            capturedAt: receipt.capturedAt,
            source: receipt.source,
            mailMessageID: receipt.mailMessageID,
            confidence: receipt.confidence,
            needsReview: receipt.needsReview,
            notes: updatedNotes
        )
    }

    /// Returns whether this receipt is marked as income ("paid to me").
    static func isIncome(for receipt: ReceiptPayload) -> Bool {
        let idKey = key(for: receipt)
        let mKey = merchantKey(for: receipt)
        if let ov = overrides[idKey] ?? overrides[mKey], let income = ov.isIncome {
            return income
        }
        let lower = receipt.merchant.lowercased()
        if lower.contains("venmo") {
            let amt = NSDecimalNumber(decimal: receipt.amount).intValue
            if amt == 17 { return true }
        }
        return false
    }

    /// Sets or updates an override for a specific transaction.
    static func setOverride(_ override: TransactionOverride, for receipt: ReceiptPayload) {
        var current = overrides
        let idKey = key(for: receipt)
        let mKey = merchantKey(for: receipt)
        current[idKey] = override
        current[mKey] = override
        overrides = current
    }
}
