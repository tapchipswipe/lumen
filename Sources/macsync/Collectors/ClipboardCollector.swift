import AppKit
import Foundation

/// Tracks clipboard ACTIVITY METADATA ONLY — changeCount deltas, UTI type
/// identifiers, and byte sizes. The copied content itself is NEVER read or
/// stored, in line with the keystroke-counting privacy model.
final class ClipboardCollector {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.lumen.clipboard", qos: .utility)
    private var timer: DispatchSourceTimer?
    private var lastChangeCount: Int = 0
    private var pendingCopies: Int = 0

    private let pollInterval: TimeInterval = 5      // detect copies quickly
    private let flushInterval: Int = 12             // flush every 12 polls = 60s

    func start() {
        stop()
        lastChangeCount = NSPasteboard.general.changeCount
        var pollCount = 0
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + pollInterval, repeating: pollInterval)
        timer.setEventHandler { [weak self] in
            guard let self else { return }
            pollCount += 1
            self.poll()
            if pollCount % self.flushInterval == 0 { self.flush() }
        }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        flush()
    }

    private func poll() {
        let pb = NSPasteboard.general
        let count = pb.changeCount
        if count != lastChangeCount {
            pendingCopies += max(1, count - lastChangeCount)
            lastChangeCount = count
        }
    }

    private func flush() {
        guard pendingCopies > 0 else { return }
        let copies = pendingCopies
        pendingCopies = 0

        // Read metadata of the CURRENT item only — types and data sizes,
        // never the payload bytes' contents.
        let pb = NSPasteboard.general
        let types = (pb.types ?? []).map { $0.rawValue }
        var byteSize: Int?
        if let items = pb.pasteboardItems, let first = items.first {
            var total = 0
            for type in first.types {
                if let data = first.data(forType: type) { total += data.count }
            }
            if total > 0 { byteSize = total }
        }

        let payload = ClipboardMetricPayload(
            observedAt: Date(),
            copiesInInterval: copies,
            contentTypes: types,
            byteSize: byteSize
        )
        store.append(TrackerEvent(ts: payload.observedAt, kind: .clipboardMetric, payload: .clipboardMetric(payload)))
    }
}
