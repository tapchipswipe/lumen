import CryptoKit
import Foundation

/// Compiles a day's JSONL buffer into a single structured JSON archive and
/// copies it to iCloud Drive (optionally zipped #6 and/or AES-GCM encrypted #9).
final class iCloudSync {
    private let store = DataStore.shared
    private let syncQueue = DispatchQueue(label: "com.lumen.icloudsync", qos: .utility)
    private let fm = FileManager.default

    func syncUnsyncedDays(upToAndIncluding dayString: String) {
        syncQueue.async { [self] in
            let days = store.bufferedDays().filter { $0 <= dayString }
            for day in days { syncDay(day, archiveAfterSuccess: true) }
        }
    }

    func syncDay(_ dayString: String, archiveAfterSuccess: Bool) {
        syncQueue.async { [self] in
            let result = performSync(dayString: dayString, archiveAfterSuccess: archiveAfterSuccess)
            store.append(TrackerEvent(ts: Date(), kind: .syncResult, payload: .syncResult(result.payload)))
            store.recordSync(date: Date(), success: result.payload.success, detail: result.detail)
        }
    }

    private struct SyncOutcome {
        let payload: SyncResultPayload
        let detail: String
    }

    private func performSync(dayString: String, archiveAfterSuccess: Bool) -> SyncOutcome {
        let events = store.events(forDay: dayString)
        guard !events.isEmpty else {
            return fail(dayString, events: 0, msg: "No events buffered", detail: "\(dayString): no events")
        }
        let archive = DayArchive(
            date: dayString, generatedAt: Date(), generator: "macsync 0.2.0",
            eventCount: events.count,
            eventsByKind: Dictionary(grouping: events, by: { $0.kind.rawValue }).mapValues(\.count),
            summary: Self.buildSummary(events: events), events: events)
        guard var payloadData = try? SyncFormat.prettyJSONEncoder.encode(archive) else {
            return fail(dayString, events: events.count, msg: "JSON encoding failed", detail: "\(dayString): encoding failed")
        }

        var suffix = "json"
        if SyncOptions.encryptArchives {
            do { payloadData = try CryptoVault.seal(payloadData, key: CryptoVault.currentKey()) ; suffix = "enc" }
            catch {
                return fail(dayString, events: events.count, msg: "Encryption failed: \(error.localizedDescription)", detail: "\(dayString): encrypt failed")
            }
        }
        if SyncOptions.zipArchives { suffix = "zip" }

        let filename = "lumen_\(dayString).\(suffix)"
        guard let destination = resolveDestination() else {
            return fail(dayString, events: events.count, msg: "No writable destination", detail: "\(dayString): no destination")
        }
        do {
            try fm.createDirectory(at: destination.dir, withIntermediateDirectories: true)
            let fileURL = destination.dir.appendingPathComponent(filename)
            if suffix == "zip" {
                let tmp = fm.temporaryDirectory.appendingPathComponent("lumen-\(dayString).json")
                try payloadData.write(to: tmp, options: .atomic)
                defer { try? fm.removeItem(at: tmp) }
                try? fm.removeItem(at: fileURL)
                let p = Process()
                p.executableURL = URL(fileURLWithPath: "/usr/bin/ditto")
                p.arguments = ["-c", "-k", "--keepParent", tmp.lastPathComponent, fileURL.path]
                p.currentDirectoryURL = tmp.deletingLastPathComponent()
                try p.run(); p.waitUntilExit()
                guard p.terminationStatus == 0 else {
                    return fail(dayString, events: events.count, msg: "zip failed", detail: "\(dayString): ditto failed")
                }
            } else {
                try payloadData.write(to: fileURL, options: .atomic)
            }
            if archiveAfterSuccess { store.archiveAndClear(dayString: dayString) }
            let payload = SyncResultPayload(
                date: dayString, destination: destination.name, filePath: fileURL.path,
                eventCount: events.count, success: true, errorMessage: nil)
            return SyncOutcome(payload: payload,
                               detail: "\(events.count) events → \(destination.name)\(SyncOptions.encryptArchives ? " (encrypted)" : "")")
        } catch {
            return fail(dayString, events: events.count, msg: error.localizedDescription,
                        detail: "\(dayString): write failed")
        }
    }

    private func fail(_ day: String, events: Int, msg: String, detail: String) -> SyncOutcome {
        SyncOutcome(
            payload: SyncResultPayload(date: day, destination: "None", filePath: nil,
                                       eventCount: events, success: false, errorMessage: msg),
            detail: detail)
    }

    private struct Destination { let name: String; let dir: URL }

    private func resolveDestination() -> Destination? {
        if let ubiquity = fm.url(forUbiquityContainerIdentifier: nil) {
            return Destination(name: "iCloud", dir: ubiquity.appendingPathComponent("Documents/Lumen", isDirectory: true))
        }
        let cloudDocs = fm.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs", isDirectory: true)
        var isDir: ObjCBool = false
        if fm.fileExists(atPath: cloudDocs.path, isDirectory: &isDir), isDir.boolValue {
            return Destination(name: "iCloudDrive", dir: cloudDocs.appendingPathComponent("Lumen", isDirectory: true))
        }
        return Destination(name: "LocalExports", dir: store.exportsDir)
    }

    static func buildSummary(events: [TrackerEvent]) -> DaySummary {
        var keystrokes = 0, clicks = 0
        var cursor = 0.0, idle = 0.0
        var appUsage: [String: TimeInterval] = [:]
        var batteryMin: Int?, batteryMax: Int?
        for e in events {
            switch e.payload {
            case .inputMetrics(let p): keystrokes += p.keystrokeCount; clicks += p.mouseClickCount; cursor += p.cursorDistancePoints
            case .idleSession(let p): idle += p.durationSeconds
            case .appFocus(let p): appUsage[p.appName, default: 0] += p.durationSeconds
            case .hardwareStatus(let p): if let pct = p.batteryPercent { batteryMin = min(batteryMin ?? pct, pct); batteryMax = max(batteryMax ?? pct, pct) }
            default: break
            }
        }
        return DaySummary(totalKeystrokes: keystrokes, totalClicks: clicks, totalCursorDistancePoints: cursor,
                          appUsageSeconds: appUsage, idleSeconds: idle, batteryMin: batteryMin, batteryMax: batteryMax)
    }
}
