// resync_2026_receipts.swift
//
// One-off CLI that backfills 2026 purchase receipts from Apple Mail into the
// same ~/Library/Application Support/macsync buffer as the running Lumen app,
// and optionally exports the merged 2026 ledger to CSV.
//
// Why a script instead of the app's built-in Rescan:
//   * The app's ReceiptMailCollector caps its inbox walk at `maxMessagesToScan`
//     (2500 messages). On a large Gmail-via-Mail inbox that stops before
//     reaching 2026-01-01, so only ~Jul 2026 onward got stored.
//   * This tool walks far enough to reach the full calendar year, dedupes by
//     mail message id (fixing duplicates caused by wiping the processed-file),
//     and reuses the SAME parsing/categorizing/format code the app ships.
//
// Git-tracked source compiled against:
//   Sources/macsync/Models.swift
//   Sources/macsync/Spend/ReceiptParser.swift
//   Sources/macsync/Spend/ReceiptCategorizer.swift
//
// Build & run (from repo root):
//   swiftc -O bin/resync_2026_receipts.swift \
//       Sources/macsync/Models.swift \
//       Sources/macsync/Spend/ReceiptParser.swift \
//       Sources/macsync/Spend/ReceiptCategorizer.swift \
//       -o /tmp/resync_2026_receipts
//   /tmp/resync_2026_receipts --export "$HOME/Documents/macsync-spend/macsync-receipts-2026.csv"
//
// Automation consent: first run will prompt for permission to control "Mail"
// (the same TCC grant the app already has).

import Foundation
import Darwin

// MARK: - Constants / options

struct Options {
    var year = 2026
    var storePath: String
    var processFile: String
    var limit = 50_000          // inbox messages to walk (BEFORE date cutoff)
    var chunkSize = 150
    var exportPath: String?
    var dryRun = false

    static func parse(_ args: [String]) -> Options {
        var o = Options(storePath: "", processFile: "", exportPath: nil)
        for i in 0..<args.count {
            switch args[i] {
            case "--year":
                if i + 1 < args.count { o.year = Int(args[i + 1]) ?? 2026 }
            case "--limit":
                if i + 1 < args.count { o.limit = Int(args[i + 1]) ?? 50_000 }
            case "--chunk":
                if i + 1 < args.count { o.chunkSize = Int(args[i + 1]) ?? 150 }
            case "--export":
                if i + 1 < args.count { o.exportPath = args[i + 1] }
            case "--store":
                if i + 1 < args.count { o.storePath = args[i + 1] }
            case "--process":
                if i + 1 < args.count { o.processFile = args[i + 1] }  // placeholder fixed below
            case "--dry-run":
                o.dryRun = true
            default:
                break
            }
        }
        return o
    }
}

func defaultStoreRoot() -> String {
    let fm = FileManager.default
    let appSupport = fm.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    return appSupport.appendingPathComponent("macsync", isDirectory: true).path
}

let ARGS = Array(CommandLine.arguments.dropFirst())
var OPT = Options.parse(ARGS)

let bufferDir = OPT.storePath + "/buffer"
let archiveDir = OPT.storePath + "/archive"
let stateDir = OPT.storePath + "/state"

// MARK: - AppleScript runner (no AppKit dependency)

enum AppleScript {
    static func run(_ source: String) -> String? {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        p.arguments = ["-e", source]
        let out = Pipe(); let err = Pipe()
        p.standardOutput = out; p.standardError = err
        do { try p.run() } catch { print("osascript launch error: \(error)"); return nil }
        p.waitUntilExit()
        let outData = out.fileHandleForReading.readDataToEndOfFile()
        let errData = err.fileHandleForReading.readDataToEndOfFile()
        if !errData.isEmpty, let e = String(data: errData, encoding: .utf8), !e.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            print("osascript stderr: \(e.trimmingCharacters(in: .whitespacesAndNewlines))")
        }
        return String(data: outData, encoding: .utf8)
    }
}
// MARK: - Candidate / Detail records

struct Candidate {
    let id: String
    let subject: String
    let sender: String
    let offset: Double
    var date: Date { Date().addingTimeInterval(offset) }
}

struct Detail {
    let id: String
    let subject: String
    let sender: String
    let body: String
    let offset: Double
    var date: Date { Date().addingTimeInterval(offset) }
}

let fld = "`FLD`"
let row = "`ROW`"

// Replicates ReceiptMailCollector.merchantGuess (private upstream).
func merchantGuess(from sender: String) -> String {
    let prefix = sender.components(separatedBy: "<").first?.trimmingCharacters(in: .whitespaces) ?? ""
    if !prefix.isEmpty && !prefix.contains("@") { return prefix }
    let domain = sender.replacingOccurrences(of: ".*@", with: "", options: .regularExpression)
        .split(separator: ".").first.map(String.init) ?? "Unknown"
    return domain.capitalized
}

func candidateScript(start: Int, end: Int, totalCount: Int) -> String {
    """
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
        set endIdx to \(end)
        set tot to \(totalCount)
        if tot < endIdx then set endIdx to tot
        set msgList to (messages \(start) thru endIdx of inbox)
        repeat with m in msgList
            try
                set mid to (message id of m) as text
                if mid is not "" then
                    set subj to subject of m
                    set sndr to sender of m
                    set out to out & mid & "\(fld)" & my esc(subj) & "\(fld)" & my esc(sndr) & "\(fld)" & (((date received of m) - (current date)) as text) & "\(row)"
                end if
            end try
        end repeat
        return out
    end tell
    """
}

func detailScript(ids: [String]) -> String {
    let idList = ids.map { "\"" + $0.replacingOccurrences(of: "\"", with: "").replacingOccurrences(of: "\\\\", with: "") + "\"" }.joined(separator: ", ")
    return """
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
                set out to out & (midTxt as text) & "\(fld)" & my esc(subject of m) & "\(fld)" & my esc(sender of m) & "\(fld)" & my esc((content of m) as text) & "\(fld)" & (((date received of m) - (current date)) as text) & "\(row)"
            end try
        end repeat
        return out
    end tell
    """
}

func fetchCandidateBatch(start: Int, end: Int, totalCount: Int) -> [Candidate] {
    guard let raw = AppleScript.run(candidateScript(start: start, end: end, totalCount: totalCount)) else { return [] }
    return raw.components(separatedBy: row)
        .filter { !$0.isEmpty }
        .compactMap { line -> Candidate? in
            let parts = line.components(separatedBy: fld)
            guard parts.count >= 4, let ep = Double(parts[3]) else { return nil }
            return Candidate(id: parts[0], subject: unescape(parts[1]), sender: unescape(parts[2]), offset: ep)
        }
}

func fetchDetails(ids: [String]) -> [Detail] {
    guard !ids.isEmpty else { return [] }
    guard let raw = AppleScript.run(detailScript(ids: ids)) else { return [] }
    return raw.components(separatedBy: row)
        .filter { !$0.isEmpty }
        .compactMap { line -> Detail? in
            let parts = line.components(separatedBy: fld)
            guard parts.count >= 5, let ep = Double(parts[4]) else { return nil }
            return Detail(id: parts[0], subject: unescape(parts[1]), sender: unescape(parts[2]),
                          body: unescape(parts[3]), offset: ep)
        }
}

func unescape(_ s: String) -> String {
    s.replacingOccurrences(of: "\\n", with: "\n").replacingOccurrences(of: "\\t", with: "\t")
}
// MARK: - Existing store

var existingByMessageID: [String: ReceiptPayload] = [:]
func loadExistingReceipts() {
    let fm = FileManager.default
    func parseFile(_ url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        for line in data.split(separator: 0x0A) {
            guard let ev = try? SyncFormat.jsonDecoder.decode(TrackerEvent.self, from: Data(line)) else { continue }
            if case .receipt(let p) = ev.payload, let mid = p.mailMessageID {
                if existingByMessageID[mid] == nil { existingByMessageID[mid] = p }
            }
        }
    }
    for dir in [bufferDir, archiveDir] {
        guard let names = try? fm.contentsOfDirectory(atPath: dir) else { continue }
        for name in names where name.hasPrefix("events-") && name.hasSuffix(".jsonl") {
            parseFile(URL(fileURLWithPath: dir + "/" + name))
        }
    }
    print("Existing stored receipts by message id: \(existingByMessageID.count)")
}

var processedIDs: Set<String> = {
    guard let data = try? Data(contentsOf: URL(fileURLWithPath: OPT.processFile)),
          let list = try? SyncFormat.jsonDecoder.decode([String].self, from: data) else { return [] }
    return Set(list)
}()

func saveProcessed(_ additions: [String]) {
    var merged = processedIDs
    merged.formUnion(additions)
    let capped = Array(merged.sorted().suffix(5000))
    processedIDs = Set(capped)
    guard let data = try? SyncFormat.jsonEncoder.encode(capped) else { return }
    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: stateDir), withIntermediateDirectories: true)
    try? data.write(to: URL(fileURLWithPath: OPT.processFile), options: .atomic)
}

func appendReceipt(_ payload: ReceiptPayload) {
    let ev = TrackerEvent(ts: payload.transactionDate, kind: .receipt, payload: .receipt(payload))
    guard let data = try? SyncFormat.jsonEncoder.encode(ev) else { return }
    var line = data; line.append(0x0A)
    let day = SyncFormat.dayString(for: payload.transactionDate)
    let file = URL(fileURLWithPath: bufferDir + "/events-" + day + ".jsonl")
    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: bufferDir), withIntermediateDirectories: true)
    if FileManager.default.fileExists(atPath: file.path) {
        if let h = try? FileHandle(forWritingTo: file) {
            defer { try? h.close() }
            try? h.seekToEnd()
            try? h.write(contentsOf: line)
        }
    } else {
        try? line.write(to: file, options: .atomic)
    }
}

// MARK: - CSV export (replicates SpendExport.csvString columns)

let exportDateFmt: DateFormatter = {
    let f = DateFormatter(); f.locale = Locale(identifier: "en_US_POSIX")
    f.dateFormat = "yyyy-MM-dd"; return f
}()

func csvEscape(_ s: String) -> String {
    if s.contains(",") || s.contains("\"") || s.contains("\n") {
        return "\"" + s.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
    return s
}

func writeCSV(path: String, receipts: [ReceiptPayload]) {
    var lines = ["Date,Merchant,Category,Amount,Currency,CardLast4,Deductible,Source,Notes"]
    for r in receipts.sorted(by: { $0.transactionDate < $1.transactionDate }) {
        let date = exportDateFmt.string(from: r.transactionDate)
        let deductible = r.category.businessDeductible ? "yes" : "no"
        let card = r.cardLast4 ?? (r.source == "manual" ? "" : "Unknown")
        let row = [date, r.merchant, r.category.rawValue,
                   NSDecimalNumber(decimal: r.amount).stringValue, r.currency,
                   card, deductible, r.source, r.notes ?? ""]
            .map(csvEscape).joined(separator: ",")
        lines.append(row)
    }
    let text = lines.joined(separator: "\n") + "\n"
    try? FileManager.default.createDirectory(at: URL(fileURLWithPath: path).deletingLastPathComponent(), withIntermediateDirectories: true)
    try? text.data(using: .utf8)?.write(to: URL(fileURLWithPath: path), options: .atomic)
    print("Wrote CSV: \(path) (\(receipts.count) rows)")
}

// MARK: - Main

var yearStart: Date {
    let cal = Calendar.current
    var comps = DateComponents()
    comps.calendar = cal
    comps.year = OPT.year
    comps.month = 1; comps.day = 1; comps.hour = 0; comps.minute = 0; comps.second = 0
    return cal.date(from: comps) ?? Date()
}

func isReceiptInYear(_ p: ReceiptPayload) -> Bool {
    Calendar.current.component(.year, from: p.transactionDate) == OPT.year
}


@main
struct Runner {
    static func main() {
        if OPT.storePath.isEmpty { OPT.storePath = defaultStoreRoot() }
        if OPT.processFile.isEmpty { OPT.processFile = OPT.storePath + "/state/processed-receipt-messages.json" }

        if OPT.dryRun {
            print("Dry run: year=\(OPT.year), limit=\(OPT.limit). No writes, no Mail probing.")
            return
        }

        // Total inbox count (lightweight osascript probe).
        let totalProbe = AppleScript.run("tell application \"Mail\" to return (count of messages of inbox) as text")
        let inboxCount = Int(totalProbe?.trimmingCharacters(in: .whitespacesAndNewlines) ?? "") ?? -1
        print("Mail inbox message count: \(inboxCount)")

        loadExistingReceipts()

        // ---- Backfill scan driver ----

        let cutoff = yearStart
        var newlyWritten: [ReceiptPayload] = []
        var seenThisRun: Set<String> = []
        var scannedMessages = 0
        var lookedLikeReceipt = 0
        var currentStart = 1
        var stop = false

        while currentStart < OPT.limit && !stop {
            let chunkEnd = currentStart + OPT.chunkSize - 1
            let batch = fetchCandidateBatch(start: currentStart, end: chunkEnd, totalCount: inboxCount)
            if batch.isEmpty { break }

            var fresh: [Candidate] = []
            for c in batch {
                scannedMessages += 1
                if c.date < cutoff { stop = true; break }
                if processedIDs.contains(c.id) { continue }
                if existingByMessageID[c.id] != nil || seenThisRun.contains(c.id) { continue }
                if ReceiptParser.looksLikeReceipt(subject: c.subject, sender: c.sender) {
                    fresh.append(c)
                }
            }

            if !fresh.isEmpty {
                lookedLikeReceipt += fresh.count
                let details = fetchDetails(ids: fresh.map { $0.id })
                for d in details {
                    let parsed = ReceiptParser.parse(subject: d.subject, sender: d.sender, body: d.body, sentDate: d.date)
                    guard let amount = parsed.amount, amount > 0 else { continue }
                    let merchant = parsed.merchant ?? merchantGuess(from: d.sender)
                    let txDate = parsed.transactionDate ?? d.date
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
                        mailMessageID: d.id,
                        confidence: parsed.confidence,
                        needsReview: parsed.needsReview,
                        notes: nil
                    )
                    guard let mid = payload.mailMessageID else { continue }
                    if existingByMessageID[mid] != nil || seenThisRun.contains(mid) { continue }
                    existingByMessageID[mid] = payload
                    seenThisRun.insert(mid)
                    newlyWritten.append(payload)
                    appendReceipt(payload)
                }
                saveProcessed(fresh.map { $0.id })
            }

            currentStart += OPT.chunkSize
            if currentStart > OPT.limit { break }
        }

        // ---- Report ----

        print("Scanned up to \(scannedMessages) messages, \(lookedLikeReceipt) looked like receipts, \(newlyWritten.count) newly written.")

        let yearReceipts = existingByMessageID.values
            .filter(isReceiptInYear)
            .sorted { $0.transactionDate < $1.transactionDate }

        let needsReview = yearReceipts.filter { $0.needsReview || $0.category == .unknown }
        let total = yearReceipts.reduce(Decimal(0)) { $0 + $1.amount }
        print("2026 receipts: \(yearReceipts.count) total, \(newlyWritten.count) new this run, \(needsReview.count) need review, sum $\(NSDecimalNumber(decimal: total).stringValue)")

        if let ep = OPT.exportPath {
            writeCSV(path: ep, receipts: yearReceipts)
        } else {
            print("No --export path given; skipping CSV.")
        }

        print("Done")
    }
}
