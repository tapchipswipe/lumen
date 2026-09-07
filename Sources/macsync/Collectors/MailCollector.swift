import AppKit
import Foundation

/// Queries Mail.app statistics via AppleScript.
/// Counts ONLY (unread / received today / sent today) by default; top-sender
/// NAMES are logged only when `lumen.mailSenderNames` is enabled.
/// Reuses the existing Automation (Apple Events) consent like browsers.
final class MailCollector {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.lumen.mail", qos: .utility)
    private var timer: DispatchSourceTimer?

    private let pollInterval: TimeInterval = 30 * 60   // every 30 minutes

    static var shouldLogSenders: Bool {
        UserDefaults.standard.bool(forKey: "lumen.mailSenderNames")
    }

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 20, repeating: pollInterval)
        timer.setEventHandler { [weak self] in self?.queryMail() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func queryMail() {
        let wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.mail" }

        defer {
            if !wasRunning {
                if let mailApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.mail" }) {
                    mailApp.terminate()
                }
            }
        }

        let source = Self.shouldLogSenders
            ? self.senderScript
            : self.countsScript

        var errorDict: NSDictionary?
        let result = NSAppleScript(source: source)?.executeAndReturnError(&errorDict)
        let now = Date()

        if let error = errorDict {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown"
            append(unread: 0, received: 0, sent: 0, senders: nil, success: false, error: message, at: now)
            return
        }

        let raw = result?.stringValue ?? ""
        let parts = raw.components(separatedBy: "|")
        guard parts.count >= 3,
              let unread = Int(parts[0]),
              let received = Int(parts[1]),
              let sent = Int(parts[2]) else { return }

        var senders: [String]? = nil
        if Self.shouldLogSenders, parts.count >= 4 {
            let names = parts[3].split(separator: "\n").map(String.init).filter { !$0.isEmpty }
            if !names.isEmpty { senders = Array(names.prefix(5)) }
        }
        append(unread: unread, received: received, sent: sent, senders: senders, success: true, error: nil, at: now)
    }

    private func append(unread: Int, received: Int, sent: Int, senders: [String]?, success: Bool, error: String?, at now: Date) {
        let payload = MailStatsPayload(observedAt: now, unreadCount: unread, receivedToday: received,
                                       sentToday: sent, topSenders: senders, success: success,
                                       errorMessage: error)
        store.append(TrackerEvent(ts: now, kind: .mailStats, payload: .mailStats(payload)))
    }

    private var countsScript: String {
        """
        tell application "Mail"
            set unread to (count of (messages of inbox whose read status is false))
            set received to (count of (messages of inbox whose date received is greater than (current date) - (24 * hours)))
            set sent to (count of (messages of mailbox "Sent" whose date sent is greater than (current date) - (24 * hours)))
            return unread & "|" & received & "|" & sent
        end tell
        """
    }

    private var senderScript: String {
        """
        tell application "Mail"
            set unread to (count of (messages of inbox whose read status is false))
            set received to (count of (messages of inbox whose date received is greater than (current date) - (24 * hours)))
            set sent to (count of (messages of mailbox "Sent" whose date sent is greater than (current date) - (24 * hours)))
            set names to ""
            set i to 0
            repeat with m in (every message of inbox)
                if i < 5 then
                    set names to names & (sender of m as text) & linefeed
                    set i to i + 1
                end if
            end repeat
            return unread & "|" & received & "|" & sent & "|" & names
        end tell
        """
    }
}