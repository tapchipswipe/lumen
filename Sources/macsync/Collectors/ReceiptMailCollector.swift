import AppKit
import Foundation

/// Scans Apple Mail for receipt-like messages across 2026 and emits `ReceiptPayload`
/// events into the same DataStore buffer as every other collector.
final class ReceiptMailCollector {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.macsync.receipts", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var isScanning: Bool = false

    private let pollInterval: TimeInterval = 30 * 60   // every 30 minutes
    private let chunkSize = 150                        // 150 messages per chunk
    private let maxMessagesToScan = 2500               // deep scan up to 2,500 messages

    // MARK: - Lifecycle

    func start() {
        stop()
        guard SpendOptions.captureEnabled else { return }
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 10, repeating: pollInterval)
        timer.setEventHandler { [weak self] in self?.scan() }
        timer.resume()
        self.timer = timer
        queue.asyncAfter(deadline: .now() + 2) { [weak self] in self?.scan() }
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    func forceRescan() {
        queue.async { [weak self] in
            guard let self = self else { return }
            try? FileManager.default.removeItem(at: self.stateFile)
            self.scan()
        }
    }

    // MARK: - Progressive Chunked Scan

    private func scan() {
        guard SpendOptions.captureEnabled else { return }
        guard !isScanning else { return }
        isScanning = true
        defer { isScanning = false }

        let wasRunning = NSWorkspace.shared.runningApplications.contains { $0.bundleIdentifier == "com.apple.mail" }
        defer {
            if !wasRunning {
                if let mailApp = NSWorkspace.shared.runningApplications.first(where: { $0.bundleIdentifier == "com.apple.mail" }) {
                    mailApp.terminate()
                }
            }
        }

        let cutoffDays = SpendOptions.backfillDays
        let cal = Calendar.current
        let cutoffDate = cal.date(byAdding: .day, value: -cutoffDays, to: Date()) ?? Date()

        var currentStart = 1
        var shouldContinue = true

        while currentStart < maxMessagesToScan && shouldContinue {
            let chunkEnd = currentStart + chunkSize - 1
            guard let batch = fetchCandidateBatch(start: currentStart, end: chunkEnd) else {
                break
            }

            if batch.isEmpty { break }

            let processed = processedMessageIDs
            var freshCandidates: [Candidate] = []

            for item in batch {
                if item.date < cutoffDate {
                    // Reached beyond 2026 backfill window
                    shouldContinue = false
                    break
                }

                if !processed.contains(item.id) && ReceiptParser.looksLikeReceipt(subject: item.subject, sender: item.sender) {
                    freshCandidates.append(item)
                }
            }

            if !freshCandidates.isEmpty {
                let details = fetchDetails(ids: freshCandidates.map(\.id))
                var newlySaved = 0

                for detail in details {
                    let parsed = ReceiptParser.parse(
                        subject: detail.subject,
                        sender: detail.sender,
                        body: detail.body,
                        sentDate: detail.date
                    )

                    guard let amount = parsed.amount, amount > 0 else {
                        continue
                    }

                    let merchant = parsed.merchant ?? Self.merchantGuess(from: detail.sender)
                    let txDate = parsed.transactionDate ?? detail.date
                    let payload = ReceiptPayload(
                        id: UUID(),
                        merchant: merchant,
                        amount: amount,
                        currency: parsed.currency ?? "USD",
                        cardLast4: parsed.cardLast4,
                        category: ReceiptCategorizer.category(for: merchant),
                        transactionDate: txDate,
                        capturedAt: Date(),
                        source: "mail",
                        mailMessageID: detail.id,
                        confidence: parsed.confidence,
                        needsReview: parsed.needsReview,
                        notes: nil
                    )

                    store.append(TrackerEvent(ts: txDate, kind: .receipt, payload: .receipt(payload)))
                    newlySaved += 1
                }

                process(freshCandidates.map(\.id))

                if newlySaved > 0 {
                    DispatchQueue.main.async {
                        AppState.shared.refreshSpend()
                    }
                }
            }

            currentStart += chunkSize
        }

        DispatchQueue.main.async {
            AppState.shared.refreshSpend()
        }
    }

    private static func merchantGuess(from sender: String) -> String {
        let v = sender.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespaces) ?? ""
        if !v.isEmpty, !v.contains("@") { return v }
        let domain = sender.replacingOccurrences(of: ".*@", with: "", options: .regularExpression)
            .split(separator: ".").first.map(String.init) ?? "Unknown"
        return domain.capitalized
    }

    // MARK: - AppleScript Chunk Queries

    private struct Candidate {
        let id: String
        let subject: String
        let sender: String
        let date: Date
    }

    private struct Detail {
        let id: String
        let subject: String
        let sender: String
        let body: String
        let date: Date
    }

    private let fld = "`FLD`"
    private let row = "`ROW`"

    private func fetchCandidateBatch(start: Int, end: Int) -> [Candidate]? {
        let script = """
        on esc(s)
            set out to s
            set AppleScript's text item delimiters to linefeed
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\n"
            set out to parts as text
            set AppleScript's text item delimiters to (ASCII character 9)
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\t"
            set out to parts as text
            set AppleScript's text item delimiters to ""
            return out
        end esc

        tell application "Mail"
            set out to ""
            set totalCount to count of messages of inbox
            if totalCount < \(start) then return ""
            set endIdx to \(end)
            if totalCount < endIdx then set endIdx to totalCount
            
            set msgList to (messages \(start) thru endIdx of inbox)
            repeat with m in msgList
                try
                    set mid to (message id of m) as text
                    if mid is not "" then
                        set subj to subject of m
                        set sndr to sender of m
                        set epochSec to ((date received of m) - (date "Thursday, January 1, 1970 at 12:00:00 AM")) as text
                        set out to out & mid & "\(fld)" & my esc(subj) & "\(fld)" & my esc(sndr) & "\(fld)" & epochSec & "\(row)"
                    end if
                end try
            end repeat
            return out
        end tell
        """

        guard let raw = runScript(script), !raw.isEmpty else { return [] }
        return raw.components(separatedBy: row)
            .filter { !$0.isEmpty }
            .compactMap { line -> Candidate? in
                let parts = line.components(separatedBy: fld)
                guard parts.count >= 4, let epoch = Double(parts[3]) else { return nil }
                return Candidate(
                    id: parts[0],
                    subject: Self.unescape(parts[1]),
                    sender: Self.unescape(parts[2]),
                    date: Date(timeIntervalSince1970: epoch)
                )
            }
    }

    private func fetchDetails(ids: [String]) -> [Detail] {
        guard !ids.isEmpty else { return [] }
        let idList = ids.map { $0.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\\", with: "") }
            .map { "\"\($0)\"" }.joined(separator: ", ")

        let script = """
        on esc(s)
            set out to s
            set AppleScript's text item delimiters to linefeed
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\n"
            set out to parts as text
            set AppleScript's text item delimiters to (ASCII character 9)
            set parts to every text item of out
            set AppleScript's text item delimiters to "\\\\t"
            set out to parts as text
            set AppleScript's text item delimiters to ""
            return out
        end esc

        tell application "Mail"
            set out to ""
            repeat with midTxt in {\(idList)}
                try
                    set m to (first message of inbox whose message id is midTxt)
                    set epochSec to ((date received of m) - (date "Thursday, January 1, 1970 at 12:00:00 AM")) as text
                    set out to out & (midTxt as text) & "\(fld)" & my esc(subject of m) & "\(fld)" & my esc(sender of m) & "\(fld)" & my esc((content of m) as text) & "\(fld)" & epochSec & "\(row)"
                end try
            end repeat
            return out
        end tell
        """

        guard let raw = runScript(script) else { return [] }
        return raw.components(separatedBy: row)
            .filter { !$0.isEmpty }
            .compactMap { line -> Detail? in
                let parts = line.components(separatedBy: fld)
                guard parts.count >= 5, let epoch = Double(parts[4]) else { return nil }
                return Detail(
                    id: parts[0],
                    subject: Self.unescape(parts[1]),
                    sender: Self.unescape(parts[2]),
                    body: Self.unescape(parts[3]),
                    date: Date(timeIntervalSince1970: epoch)
                )
            }
    }

    private func runScript(_ script: String) -> String? {
        var errorDict: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)
        if let error = errorDict {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown"
            Log.app.error("receipt AppleScript error: \(message)")
            return nil
        }
        return result?.stringValue
    }

    private static func unescape(_ s: String) -> String {
        s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t")
    }

    // MARK: - Dedup state

    private var stateFile: URL { store.stateDir.appendingPathComponent("processed-receipt-messages.json") }

    private var processedMessageIDs: Set<String> {
        guard let data = try? Data(contentsOf: stateFile),
              let list = try? SyncFormat.jsonDecoder.decode([String].self, from: data) else { return [] }
        return Set(list)
    }

    private func process(_ ids: [String]) {
        let existing = processedMessageIDs
        let merged = Array(Array(existing.union(ids)).sorted().suffix(5000))
        if let data = try? SyncFormat.jsonEncoder.encode(merged) {
            try? data.write(to: stateFile, options: .atomic)
        }
    }
}
