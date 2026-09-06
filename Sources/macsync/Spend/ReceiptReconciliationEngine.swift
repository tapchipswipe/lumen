import Foundation

/// Receipt Auto-Reconciliation Engine.
/// Matches mobile camera scans (`source == "camera" / "manual"`) with
/// Apple Mail parsed receipts (`source == "mail"`), eliminating double-counting
/// and elevating confidence scores for IRS Schedule-C deductions.
public final class ReceiptReconciliationEngine {
    
    struct ReconciledReceipt: Identifiable, Codable {
        public let id: UUID
        public let primaryReceipt: ReceiptPayload
        public let matchedMailID: String?
        public let matchedCameraID: UUID?
        public let isCrossVerified: Bool
        public let scheduleCLine: String // e.g. "Line 18 (Software)", "Line 24b (Meals)"
        public let taxYear: Int
    }

    static func reconcile(receipts: [ReceiptPayload]) -> [ReconciledReceipt] {
        var reconciled: [ReconciledReceipt] = []
        var processedIDs: Set<UUID> = []

        let mailReceipts = receipts.filter { $0.source == "mail" }
        let mobileReceipts = receipts.filter { $0.source != "mail" }

        for mobile in mobileReceipts {
            // Match criteria: Amount within $0.05, within 2 days, and matching card or merchant
            let match = mailReceipts.first { mail in
                let amtDiff = abs(mobile.amountDouble - mail.amountDouble)
                let dateDiff = abs(mobile.transactionDate.timeIntervalSince(mail.transactionDate))
                let cardMatch = (mobile.cardLast4 != nil && mail.cardLast4 != nil && mobile.cardLast4 == mail.cardLast4)
                let merchantMatch = mobile.merchant.lowercased().contains(mail.merchant.lowercased()) || mail.merchant.lowercased().contains(mobile.merchant.lowercased())
                
                return amtDiff <= 0.05 && dateDiff <= (2 * 86400) && (cardMatch || merchantMatch)
            }

            if let match = match {
                processedIDs.insert(match.id)
                let line = scheduleCLine(for: mobile.category)
                reconciled.append(ReconciledReceipt(
                    id: mobile.id,
                    primaryReceipt: mobile,
                    matchedMailID: match.mailMessageID,
                    matchedCameraID: mobile.id,
                    isCrossVerified: true,
                    scheduleCLine: line,
                    taxYear: 2026
                ))
            } else {
                let line = scheduleCLine(for: mobile.category)
                reconciled.append(ReconciledReceipt(
                    id: mobile.id,
                    primaryReceipt: mobile,
                    matchedMailID: nil,
                    matchedCameraID: mobile.id,
                    isCrossVerified: false,
                    scheduleCLine: line,
                    taxYear: 2026
                ))
            }
        }

        // Add remaining unmatched mail receipts
        for mail in mailReceipts where !processedIDs.contains(mail.id) {
            let line = scheduleCLine(for: mail.category)
            reconciled.append(ReconciledReceipt(
                id: mail.id,
                primaryReceipt: mail,
                matchedMailID: mail.mailMessageID,
                matchedCameraID: nil,
                isCrossVerified: false,
                scheduleCLine: line,
                taxYear: 2026
            ))
        }

        return reconciled.sorted { $0.primaryReceipt.transactionDate > $1.primaryReceipt.transactionDate }
    }

    static func scheduleCLine(for category: ReceiptCategory) -> String {
        switch category {
        case .software, .subscriptions:
            return "Line 18 (Office/Software & Cloud Services)"
        case .travel, .transport:
            return "Line 22 (Travel & Transportation)"
        case .dining:
            return "Line 24b (Business Meals - 50% Deductible)"
        case .utilities:
            return "Line 25 (Utilities & Internet)"
        case .business:
            return "Line 27a (Other Business Expenses)"
        default:
            return "Non-Deductible / Personal"
        }
    }
}
