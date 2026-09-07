import Foundation

/// User-facing toggles for the Receipts & Spending module.
/// Capture is **off by default** — Lumen reads no email bodies unless the
/// user explicitly enables `lumen.receiptCaptureEnabled`.
enum SpendOptions {
    private static var d: UserDefaults { .standard }

    // MARK: - One-time key migration (macsync.* → lumen.*)
    // Called once at app launch so any previously saved settings carry forward.
    static func migrateKeysIfNeeded() {
        let migrations: [(old: String, new: String)] = [
            ("macsync.receiptCaptureEnabled", "lumen.receiptCaptureEnabled"),
            ("macsync.receiptMailbox",        "lumen.receiptMailbox"),
            ("macsync.receiptBackfillDays",   "lumen.receiptBackfillDays"),
            ("macsync.menuBarTime",           "lumen.menuBarTime"),
            ("macsync.nightPauseEnabled",     "lumen.nightPauseEnabled"),
            ("macsync.zipArchives",           "lumen.zipArchives"),
            ("macsync.encryptArchives",       "lumen.encryptArchives"),
            ("macsync.mailSenderNames",       "lumen.mailSenderNames"),
            ("macsync.onboarded",             "lumen.onboarded"),
            ("macsync.storage.pinnedFolders", "lumen.storage.pinnedFolders"),
        ]
        for m in migrations {
            guard d.object(forKey: m.new) == nil,
                  let oldVal = d.object(forKey: m.old) else { continue }
            d.set(oldVal, forKey: m.new)
            d.removeObject(forKey: m.old)
        }
    }

    /// Master switch. When off, the receipt collector does not run and no
    /// message bodies are ever read.
    static var captureEnabled: Bool {
        get { d.bool(forKey: "lumen.receiptCaptureEnabled") }
        set { d.set(newValue, forKey: "lumen.receiptCaptureEnabled") }
    }

    /// Mailbox to scan. Reserved value "INBOX" (default) = the virtual Inbox
    /// across all accounts; anything else must match a real mailbox name.
    static var mailboxName: String {
        get { d.string(forKey: "lumen.receiptMailbox") ?? "INBOX" }
        set { d.set(newValue, forKey: "lumen.receiptMailbox") }
    }

    /// History window: how far back to scan on the first (backfill) pass.
    static var backfillDays: Int {
        get { d.object(forKey: "lumen.receiptBackfillDays") as? Int ?? 365 }
        set { d.set(newValue, forKey: "lumen.receiptBackfillDays") }
    }
}