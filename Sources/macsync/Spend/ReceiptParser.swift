import Foundation

/// Result of parsing a candidate receipt message. Field-level confidence lets
/// the UI surface low-confidence hits for one-tap confirmation instead of
/// silently filing a wrong amount.
struct ParsedReceipt {
    var merchant: String?
    var amount: Decimal?
    var currency: String?
    var cardLast4: String?
    var transactionDate: Date?
    var confidence: Double
    var needsReview: Bool
}

/// Pure text → receipt parser. No I/O, unit-testable. Heuristics are
/// order-independent; the strongest, most narrowly-scoped match wins (an
/// explicit "Total: $…" beats the first bare "$…" in the body).
enum ReceiptParser {

    // MARK: - Merchant templates (~40 known senders)

    private struct SenderRule {
        let domain: String
        let merchant: String
        let category: ReceiptCategory
    }

    private static let senderRules: [SenderRule] = [
        SenderRule(domain: "amazon.com", merchant: "Amazon", category: .shopping),
        SenderRule(domain: "amazonaws.com", merchant: "Amazon Web Services", category: .software),
        SenderRule(domain: "shopify.com", merchant: "Shopify", category: .business),
        SenderRule(domain: "apple.com", merchant: "Apple", category: .subscriptions),
        SenderRule(domain: "adobereceipts.com", merchant: "Adobe", category: .software),
        SenderRule(domain: "netflix.com", merchant: "Netflix", category: .subscriptions),
        SenderRule(domain: "spotify.com", merchant: "Spotify", category: .subscriptions),
        SenderRule(domain: "microsoft.com", merchant: "Microsoft", category: .software),
        SenderRule(domain: "xbox.com", merchant: "Microsoft", category: .software),
        SenderRule(domain: "google.com", merchant: "Google", category: .subscriptions),
        SenderRule(domain: "paypal.com", merchant: "PayPal", category: .business),
        SenderRule(domain: "stripe.com", merchant: "Stripe", category: .business),
        SenderRule(domain: "squareup.com", merchant: "Square", category: .business),
        SenderRule(domain: "ubereats.com", merchant: "Uber Eats", category: .dining),
        SenderRule(domain: "uber.com", merchant: "Uber", category: .transport),
        SenderRule(domain: "doordash.com", merchant: "DoorDash", category: .dining),
        SenderRule(domain: "grubhub.com", merchant: "Grubhub", category: .dining),
        SenderRule(domain: "lyft.com", merchant: "Lyft", category: .transport),
        SenderRule(domain: "starbucks.com", merchant: "Starbucks", category: .dining),
        SenderRule(domain: "chipotle.com", merchant: "Chipotle", category: .dining),
        SenderRule(domain: "dunkindonuts.com", merchant: "Dunkin'", category: .dining),
        SenderRule(domain: "walmart.com", merchant: "Walmart", category: .shopping),
        SenderRule(domain: "target.com", merchant: "Target", category: .shopping),
        SenderRule(domain: "bestbuy.com", merchant: "Best Buy", category: .shopping),
        SenderRule(domain: "costco.com", merchant: "Costco", category: .shopping),
        SenderRule(domain: "delta.com", merchant: "Delta Air Lines", category: .travel),
        SenderRule(domain: "southwest.com", merchant: "Southwest Airlines", category: .travel),
        SenderRule(domain: "united.com", merchant: "United Airlines", category: .travel),
        SenderRule(domain: "airbnb.com", merchant: "Airbnb", category: .travel),
        SenderRule(domain: "xfinity.com", merchant: "Xfinity", category: .utilities),
        SenderRule(domain: "comcast.net", merchant: "Xfinity", category: .utilities),
        SenderRule(domain: "verizon.com", merchant: "Verizon", category: .utilities),
        SenderRule(domain: "tmobile.com", merchant: "T-Mobile", category: .utilities),
        SenderRule(domain: "att.com", merchant: "AT&T", category: .utilities),
        SenderRule(domain: "epicgames.com", merchant: "Epic Games", category: .software),
        SenderRule(domain: "playstation.com", merchant: "PlayStation", category: .software),
        SenderRule(domain: "github.com", merchant: "GitHub", category: .software),
        SenderRule(domain: "figma.com", merchant: "Figma", category: .software),
        SenderRule(domain: "notion.com", merchant: "Notion", category: .software),
        SenderRule(domain: "canva.com", merchant: "Canva", category: .software),
        SenderRule(domain: "planetfitness.com", merchant: "Planet Fitness", category: .health),
        SenderRule(domain: "equinox.com", merchant: "Equinox", category: .health),
        SenderRule(domain: "cvshealth.com", merchant: "CVS", category: .health),
        SenderRule(domain: "walgreens.com", merchant: "Walgreens", category: .health),
        SenderRule(domain: "venmo.com", merchant: "Venmo", category: .business),
        SenderRule(domain: "paywire.com", merchant: "Paywire", category: .business),
        SenderRule(domain: "steampowered.com", merchant: "Steam", category: .software)
    ]

    // MARK: - Brokerage / Investment / Banking Exclusion Lists

    private static let brokerageDomains: [String] = [
        "public.com", "geopod-ismtpd", "robinhood.com", "coinbase.com",
        "fidelity.com", "schwab.com", "vanguard.com", "etrade.com",
        "webull.com", "interactivebrokers.com", "kraken.com", "gemini.com",
        "crypto.com", "binance.com", "acorns.com", "betterment.com",
        "wealthfront.com", "m1finance.com", "empower.com", "sofi.com"
    ]

    private static let investmentKeywords: [String] = [
        "trade", "trades", "traded", "trading", "shares", "share price",
        "limit order", "market order", "stop order", "stop loss", "dividend",
        "portfolio", "brokerage", "crypto", "cryptocurrency", "bitcoin", "ethereum",
        "treasury bill", "t-bill", "yield payout", "order to buy", "order to sell",
        "order filled", "order execution", "trade executed", "trade confirmation",
        "your trade", "executed order", "deposit of $", "funds transferred",
        "transfer of $", "withdrew", "withdrawal"
    ]

    private static let bankingTransferKeywords: [String] = [
        "credit card payment", "payment received - thank you", "payment posted",
        "transfer from checking", "transfer to savings", "ach transfer",
        "wire transfer", "direct deposit", "autopay scheduled",
        "monthly statement", "statement available", "account statement is ready",
        "minimum payment due", "balance update", "paid off", "pay in 4",
        "loan payment", "installment paid", "loan payoff", "repayment"
    ]

    private static let travelNonPurchaseKeywords: [String] = [
        "time to check in", "check in now", "check-in", "boarding pass",
        "flight update", "gate change", "baggage update", "flight status",
        "trip reminder", "upcoming trip", "trip details", "flight details",
        "skymiles", "mileageplus", "rapid rewards", "frequent flyer",
        "miles earned", "qualifying miles", "upgrade offer", "upgrade to",
        "fares starting at", "book now from", "flight alert", "schedule change",
        "ecredit", "flight credit"
    ]

    private static let cloudBudgetKeywords: [String] = [
        "budget alert", "budget reached", "% of budget", "spending limit",
        "cost threshold", "usage summary", "billing alert", "estimated charges for",
        "daily spend alert"
    ]

    private static let userExcludedMerchants: [String] = [
        "kart rising", "steam", "steampowered", "valve corporation"
    ]

    private static let shippingTrackingKeywords: [String] = [
        "a shipment from order", "your order is on the way", "your order is out for delivery",
        "your order has been delivered", "track your shipment", "shipment tracking",
        "has been shipped", "out for delivery", "has been delivered", "package delivered",
        "order has been delivered", "delivery update"
    ]

    // MARK: - Enter / parse

    /// Cheap subject/sender heuristic used to shortlist messages before their
    /// bodies are fetched. Single source of truth shared by the collector.
    static func looksLikeReceipt(subject: String, sender: String) -> Bool {
        // Declined / failed payments are NOT purchases — never count them.
        if looksLikeFailedPayment(subject: subject, sender: sender) { return false }
        // Investment, banking transfers, and non-purchase alerts are never receipts.
        if looksLikeNonPurchase(subject: subject, sender: sender) { return false }

        let subj = subject.lowercased()

        // 1. Explicit purchase / invoice keywords in subject (highest confidence)
        let receiptSubjectKeywords = [
            "receipt", "invoice", "payment receipt", "your order", "order confirmation",
            "purchase receipt", "e-receipt", "ereceipt", "ticket receipt", "flight receipt",
            "booking confirmation", "you paid", "paid you", "tax invoice", "bill for",
            "order #", "order placed", "order confirmed", "payment for order",
            "payment confirmed"
        ]
        if receiptSubjectKeywords.contains(where: { subj.contains($0) }) {
            return true
        }

        // 2. Known sender rules: require transactional subject and reject marketing/alerts
        let senderLC = sender.lowercased()
        if senderRules.contains(where: { senderLC.contains($0.domain.lowercased()) }) {
            let nonTransactionSubjects = [
                "update", "newsletter", "recap", "reminder", "check-in", "check in",
                "boarding", "gate", "status", "statement", "alert", "security",
                "password", "welcome", "survey", "review your", "how was", "offer",
                "deal", "sale", "save", "miles", "points", "reward", "rewards",
                "notification", "trade", "shares", "deposit", "transfer", "budget", "limit"
            ]
            if !nonTransactionSubjects.contains(where: { subj.contains($0) }) {
                let transactionalSubjWords = [
                    "order", "receipt", "invoice", "payment", "charged", "paid",
                    "subscription renewal", "ticket", "booking", "shipment",
                    "delivery", "delivered", "shipped", "bill"
                ]
                if transactionalSubjWords.contains(where: { subj.contains($0) }) {
                    return true
                }
            }
        }

        return false
    }

    /// Checks if subject or sender belongs to an investment/brokerage platform,
    /// bank transfer, or non-purchase alert.
    static func looksLikeNonPurchase(subject: String, sender: String) -> Bool {
        let senderLC = sender.lowercased()
        let subjLC = subject.lowercased()

        // Brokerage platform sender
        if brokerageDomains.contains(where: { senderLC.contains($0) }) { return true }

        // Investment / trading language in subject
        if investmentKeywords.contains(where: { subjLC.contains($0) }) { return true }

        // Bank transfer / CC payments / statements in subject
        if bankingTransferKeywords.contains(where: { subjLC.contains($0) }) { return true }

        // Travel non-receipts (check-in, flight updates, SkyMiles, upgrade promos)
        if travelNonPurchaseKeywords.contains(where: { subjLC.contains($0) }) {
            let travelReceiptPhrases = ["flight receipt", "ticket receipt", "eticket receipt", "e-ticket receipt", "passenger receipt", "flight booking confirmation", "your receipt and itinerary"]
            if !travelReceiptPhrases.contains(where: { subjLC.contains($0) }) {
                return true
            }
        }

        // Cloud budget alerts in subject
        if cloudBudgetKeywords.contains(where: { subjLC.contains($0) }) { return true }

        // Shipping & tracking status updates (not invoices)
        if shippingTrackingKeywords.contains(where: { subjLC.contains($0) }) { return true }

        // Marketing promo discount subjects (e.g. "$50 off your order?!")
        let discountPhrases = ["off your order", "off your next", "off your purchase", "off your first", "% off", "dollars off", "save $", "save up to"]
        if discountPhrases.contains(where: { subjLC.contains($0) }) && !subjLC.contains("receipt") && !subjLC.contains("invoice") {
            return true
        }

        // User-excluded merchants (e.g. Kart Rising)
        if userExcludedMerchants.contains(where: { subjLC.contains($0) || senderLC.contains($0) }) { return true }

        return false
    }

    /// Declined / unsuccessful payments must never be counted as spending.
    /// Matches the common bank/processor phrasings (Privacy.com pseudo-card
    /// decline alerts, Stripe "unsuccessful payment" retries, etc.).
    static func looksLikeFailedPayment(subject: String, sender: String) -> Bool {
        let subj = subject.lowercased()
        let declineWords = ["decline", "unsuccessful", "payment failed", "failed payment",
                            "was declined", "could not be processed", "couldn't be processed",
                            "payment attempt failed", "fix your payment", "action required: update"]
        if declineWords.contains(where: { subj.contains($0) }) { return true }
        let s = sender.lowercased()
        return s.hasPrefix("failed-payments") || s.contains("failed-payments@")
    }

    /// Rejects messages that look receipt-like but are not real purchases:
    /// - Declined / failed charges
    /// - Zero-dollar totals ($0.00 / free)
    /// - Investment / trading / brokerage activities (Public, Robinhood, etc.)
    /// - Bank transfers / Credit card bill payments
    /// - Travel check-in / flight status / SkyMiles / upgrade promos
    /// - Cloud / SaaS budget threshold alerts and monthly usage statements
    /// - Marketing ESP promotional campaigns ("$X off", "save $X")
    /// - Pseudo-card promotional notifications
    static func shouldRejectNonTransaction(subject: String, sender: String, body: String, amount: Decimal?) -> Bool {
        let text = (subject + "\n" + body).lowercased()
        let senderLC = sender.lowercased()
        let subjLC = subject.lowercased()

        // 1. Declined language in body even if subject didn't carry it.
        let declineWords = ["declined", "was declined", "payment failed", "unsuccessful payment",
                            "could not be processed", "couldn't be processed", "fix your payment",
                            "payment attempt failed", "charge failed", "authorization failed",
                            "not authorized", "rejected by bank"]
        if declineWords.contains(where: { text.contains($0) }) { return true }

        // 2. $0 total — never a real purchase.
        if let amt = amount, amt == 0 { return true }

        // 3. "No charge" / "free" confirmation (e.g. $0 trial, free order).
        if text.contains("no charge") || text.contains("charged $0") || text.contains("total: $0.00") { return true }

        // 4. Brokerage / Investment platforms (Public, Robinhood, Coinbase, etc.)
        if brokerageDomains.contains(where: { senderLC.contains($0) }) { return true }
        if investmentKeywords.contains(where: { text.contains($0) }) { return true }

        // 5. Bank transfers / credit card bill payments
        if bankingTransferKeywords.contains(where: { text.contains($0) }) { return true }

        // 6. Travel non-purchases (flight status, check-in, SkyMiles, upgrade offers)
        if travelNonPurchaseKeywords.contains(where: { text.contains($0) }) {
            let travelReceiptPhrases = ["flight receipt", "ticket receipt", "eticket receipt", "e-ticket receipt", "passenger receipt", "flight booking confirmation", "your receipt and itinerary"]
            if !travelReceiptPhrases.contains(where: { subjLC.contains($0) }) {
                return true
            }
        }

        // 7. Cloud / Tech budget threshold alerts
        if cloudBudgetKeywords.contains(where: { text.contains($0) }) { return true }

        // 8. Pseudo-card / promotional notifications (Flux Team Privacy, etc.)
        let promoSenders = ["teamprivacy", "team@privacy", "noreply@privacy", "flux.ai"]
        if promoSenders.contains(where: { senderLC.contains($0) }) { return true }

        // 9. ESP marketing platforms (Klaviyo, Brevo, SendGrid, etc.)
        let promoDomains = ["klaviyomail.com", "sender-sib.com", "broadridge.net",
                            "sendgrid.net", "mailgun", "postmark", "list-manage.com"]
        if promoDomains.contains(where: { senderLC.contains($0) }) {
            let transactionalWords = ["receipt", "order", "invoice", "payment", "you paid", "paid you", "charge", "ticket", "bill"]
            if !transactionalWords.contains(where: { subjLC.contains($0) }) {
                return true
            }
        }

        // 10. General notifications/recap/newsletter subjects
        let nonPurchaseSubjects = ["notification", "reminder", "update", "your account",
                                   "security alert", "password", "verification code",
                                   "new sign-in", "login", "newsletter", "weekly recap"]
        if nonPurchaseSubjects.contains(where: { subjLC.contains($0) }) && !subjLC.contains("receipt") && !subjLC.contains("invoice") && !subjLC.contains("order") {
            return true
        }

        // 11. User-excluded merchants (e.g. Kart Rising)
        if userExcludedMerchants.contains(where: { text.contains($0) || senderLC.contains($0) }) { return true }

        return false
    }

    /// Parses one candidate receipt message. `sentDate` is the message date
    /// (used when no explicit purchase date can be found in the body).
    static func parse(subject: String, sender: String, body: String, sentDate: Date) -> ParsedReceipt {
        let merchant = resolveMerchant(subject: subject, sender: sender)
        let card = cardLast4(in: body.replacingOccurrences(of: "\n", with: " "))
        let date = purchaseDate(in: subject, body: body) ?? sentDate

        var amount = firstAmount(in: body, subject: subject, cardPresent: card != nil)
        let labeled = hasLabeledTotal(in: body)

        var confidence = 0.30                              // baseline
        if merchant != nil { confidence += 0.20 }
        if labeled { confidence += 0.25 }
        if card != nil { confidence += 0.15 }
        if merchantWasKnown(sender) { confidence += 0.10 }

        // If amount was found only through fallback (no labeled total, no card last4), penalize confidence
        if !labeled && card == nil && amount != nil {
            confidence -= 0.15
        }

        // Hard rejects (declined / non-transactions): zero out everything
        if shouldRejectNonTransaction(subject: subject, sender: sender, body: body, amount: amount) {
            confidence = 0
            amount = nil
        }

        confidence = max(0.0, min(1.0, confidence))

        return ParsedReceipt(
            merchant: merchant,
            amount: amount,
            currency: firstCurrency(in: body) ?? "USD",
            cardLast4: card,
            transactionDate: date,
            confidence: confidence,
            needsReview: confidence < 0.75
        )
    }

    // MARK: - Amount

    /// Strongest-signal amount first: labeled totals beat bare "$x".
    /// Bare "$x" is only accepted if supported by card last-4 or an explicit receipt subject.
    static func firstAmount(in text: String, subject: String = "", cardPresent: Bool = false) -> Decimal? {
        // 1. Explicit labeled totals ("Total: $...", "Amount charged: $...", "Total paid: $...")
        // Uses (?<!sub) to avoid matching "Subtotal" before discounts.
        let labeledPatterns = [
            #"(?<!sub)\btotal(?:\s+(?:amount|paid|charged|due))?[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]\s?([0-9][0-9,]*\.?[0-9]{0,2})"#,
            #"(?:amount\s+(?:paid|charged|due)|grand\s+total|order\s+total|final\s+total|payment\s+amount|total\s+cost|total\s+fare|ticket\s+total|fare\s+total)[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]\s?([0-9][0-9,]*\.?[0-9]{0,2})"#,
            #"(?:charged|billed|amount charged|paid)[^0-9$€£\n]{0,15}?\n?[^0-9$€£\n]{0,10}?[$€£]\s?([0-9][0-9,]*\.?[0-9]{0,2})"#,
            #"(?:you paid)[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]\s?([0-9][0-9,]*\.?[0-9]{0,2})"#
        ]
        for p in labeledPatterns {
            if let m = firstMatch(p, in: text, group: 1), let d = moneyDecimal(m) {
                return d
            }
        }

        // 2. Fallback to bare money ONLY if context confirms it is a transaction
        // (card last-4 present, or subject has explicit "receipt / order / invoice / you paid")
        let subjLC = subject.lowercased()
        let hasExplicitReceiptSubject = subjLC.contains("receipt") || subjLC.contains("order") ||
                                       subjLC.contains("invoice") || subjLC.contains("you paid")

        if cardPresent || hasExplicitReceiptSubject {
            if let d = firstMoney(in: text) {
                return d
            }
        }

        return nil
    }

    static func hasLabeledTotal(in text: String) -> Bool {
        let labeledPatterns = [
            #"(?<!sub)\btotal(?:\s+(?:amount|paid|charged|due))?[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]"#,
            #"(?:amount\s+(?:paid|charged|due)|grand\s+total|order\s+total|final\s+total|payment\s+amount|total\s+cost|total\s+fare|ticket\s+total|fare\s+total)[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]"#,
            #"(?:charged|billed|amount charged|paid)[^0-9$€£\n]{0,15}?\n?[^0-9$€£\n]{0,10}?[$€£]"#,
            #"(?:you paid)[^0-9$€£\n]{0,25}?\n?[^0-9$€£\n]{0,10}?[$€£]"#
        ]
        return labeledPatterns.contains { firstMatch($0, in: text) != nil }
    }

    /// First bare currency amount ("$42.95", "USD 42.95", "$ 1,234.56").
    /// Rejects promotional/discount phrasings ("save $", "starting at $", "$... off").
    static func firstMoney(in text: String) -> Decimal? {
        let patterns = [
            #"[$€£]\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#,
            #"\b(?:USD|CAD|EUR|GBP|AUD)\s?([0-9][0-9,]*(?:\.[0-9]{1,2})?)"#
        ]
        for p in patterns {
            if let m = firstMatch(p, in: text, group: 1), let d = moneyDecimal(m) {
                return d
            }
        }
        return nil
    }

    static func moneyDecimal(_ raw: String) -> Decimal? {
        let cleaned = raw.replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard cleaned.range(of: #"^[0-9]*\.?[0-9]{0,2}$"#, options: .regularExpression) != nil,
              !cleaned.isEmpty,
              let d = Decimal(string: cleaned) else { return nil }
        return d
    }

    static func firstCurrency(in text: String) -> String? {
        if text.range(of: "€", options: .literal) != nil { return "EUR" }
        if text.range(of: "£", options: .literal) != nil { return "GBP" }
        if let m = firstMatch(#"\b(USD|CAD|EUR|GBP|AUD)\b"#, in: text) { return m.uppercased() }
        return text.range(of: "$", options: .literal) != nil ? "USD" : nil
    }

    static func cardLast4(in text: String) -> String? {
        let patterns = [
            #"card[^0-9]{0,20}?ending(?: in| with)?[^0-9]{0,6}(\d{4})(?!\d)"#,
            #"ending (?:in|with)[^0-9]{0,6}(\d{4})(?!\d)"#,
            #"(?:visa|mastercard|amex|american express|discover)[^0-9]{0,12}?(\d{4})(?!\d)"#,
            #"[\u2022*x]{3,}\s?(\d{4})(?!\d)"#,
            #"\b[A-Z]{2}\s+(\d{4})\b"#
        ]
        for p in patterns {
            if let m = firstMatch(p, in: text, group: 1) {
                if m != "2024" && m != "2025" && m != "2026" {
                    return m
                }
            }
        }
        return nil
    }

    // MARK: - Date

    static func purchaseDate(in subject: String, body: String) -> Date? {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        let labeled = subject + "\n" + body
        if let m = firstMatch(#"(?:purchase|transaction|order)?\s?date[^0-9A-Za-z]{1,8}([A-Za-z]{3,9}\s+\d{1,2},?\s+\d{4}|[0-9]{1,2}/[0-9]{1,2}/[0-9]{2,4})"#, in: labeled, group: 1) {
            for fmt in ["MMM d, yyyy", "MMMM d, yyyy", "MM/dd/yyyy", "MM/dd/yy"] {
                f.dateFormat = fmt
                if let d = f.date(from: m) { return d }
            }
        }
        return nil
    }

    // MARK: - Merchant resolution

    private static func resolveMerchant(subject: String, sender: String) -> String? {
        // 1. Explicit "receipt/invoice from {Merchant}" in the subject is the
        //    most specific signal (Square-style receipts name the shop there).
        if let m = firstMatch(#"(?:receipt|invoice|payment)\s+(?:from|by)\s+([A-Za-z0-9][A-Za-z0-9&.' -]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 2. "… bill for {X}" (Shopify billing), "order from {X}".
        if let m = firstMatch(#"(?:bill|invoice|order|payment)\s+for\s+([A-Za-z0-9][A-Za-z0-9&.' -]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 3. "You paid {Person} $8.00" (P2P payments).
        if let m = firstMatch(#"you paid\s+([A-Za-z0-9][A-Za-z0-9 .'&-]{1,40}?)(?=\s*\$|\s+[0-9]|$)"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 4. "Receipt from {Merchant}" (Square-style).
        if let m = firstMatch(#"receipt[^0-9A-Za-z]{1,4}from[^0-9A-Za-z]{1,4}([A-Za-z0-9][^,;]{1,40})"#, in: subject, group: 1) {
            return m.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        // 5. Known sender domain (e.g. order-update@amazon.com).
        if let rule = senderRules.first(where: { sender.localizedLowercase.contains($0.domain.lowercased()) }) {
            return rule.merchant
        }
        return nil
    }

    private static func merchantWasKnown(_ sender: String) -> Bool {
        senderRules.contains { sender.localizedLowercase.contains($0.domain.lowercased()) }
    }

    // MARK: - Regex helper

    /// First regex match; `group` 0 returns the whole match.
    static func firstMatch(_ pattern: String, in text: String, group: Int = 0) -> String? {
        guard let re = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return nil }
        let ns = text as NSString
        guard let m = re.firstMatch(in: text, options: [], range: NSRange(location: 0, length: ns.length)) else { return nil }
        let r = m.range(at: group)
        guard r.location != NSNotFound else { return nil }
        return ns.substring(with: r)
    }
}
