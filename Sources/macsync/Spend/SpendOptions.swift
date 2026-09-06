import Foundation

/// User-facing toggles for the Receipts & Spending module.
/// Capture is **off by default** — macsync reads no email bodies unless the
/// user explicitly enables `macsync.receiptCaptureEnabled`.
enum SpendOptions {
    private static var d: UserDefaults { .standard }

    /// Master switch. When off, the receipt collector does not run and no
    /// message bodies are ever read.
    static var captureEnabled: Bool {
        get { d.bool(forKey: "macsync.receiptCaptureEnabled") }
        set { d.set(newValue, forKey: "macsync.receiptCaptureEnabled") }
    }

    /// Mailbox to scan. Reserved value "INBOX" (default) = the virtual Inbox
    /// across all accounts; anything else must match a real mailbox name.
    static var mailboxName: String {
        get { d.string(forKey: "macsync.receiptMailbox") ?? "INBOX" }
        set { d.set(newValue, forKey: "macsync.receiptMailbox") }
    }

    /// History window: how far back to scan on the first (backfill) pass.
    static var backfillDays: Int {
        get { d.object(forKey: "macsync.receiptBackfillDays") as? Int ?? 365 }
        set { d.set(newValue, forKey: "macsync.receiptBackfillDays") }
    }
}