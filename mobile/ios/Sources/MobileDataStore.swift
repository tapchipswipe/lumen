import Foundation

/// High-performance, battery-aware, append-only JSONL datastore for iOS.
/// Gracefully falls back to local Documents/ storage when running under free provisioning
/// (where iCloud Ubiquity containers are inaccessible).
public final class MobileDataStore {
    public static let shared = MobileDataStore()

    private let writeQueue = DispatchQueue(label: "com.lumen.mobile.datastore", qos: .utility)
    private let stateLock = NSLock()

    public let rootDir: URL
    public let bufferDir: URL
    public let archiveDir: URL
    public let exportDir: URL

    // In-memory write buffer to batch flash writes and reduce disk wakeups
    private var memoryBuffer: [Data] = []
    private let maxBufferedBatchCount = 10
    private var lastFlushTime: Date = Date()

    public private(set) var todayEventCount: Int = 0
    public var onEventsUpdated: (() -> Void)?

    private init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first ?? URL(fileURLWithPath: NSTemporaryDirectory())
        rootDir = docs.appendingPathComponent("LumenMobile", isDirectory: true)
        bufferDir = rootDir.appendingPathComponent("buffer", isDirectory: true)
        archiveDir = rootDir.appendingPathComponent("archive", isDirectory: true)
        exportDir = docs.appendingPathComponent("lumen_exports", isDirectory: true)

        for dir in [rootDir, bufferDir, archiveDir, exportDir] {
            try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        recalculateTodayCount()
    }

    /// Dedicated, isolated filename per device to prevent collision with macOS app writes
    public func bufferFile(for day: String) -> URL {
        bufferDir.appendingPathComponent("events-\(day)-iphone.jsonl")
    }

    // MARK: - Batched & Energy-Optimized Append

    public func append(_ event: MobileTrackerEvent) {
        writeQueue.async { [weak self] in
            guard let self = self else { return }

            guard let encoded = try? MobileFormat.jsonEncoder.encode(event) else { return }
            var line = encoded
            line.append(0x0A) // \n

            self.memoryBuffer.append(line)

            self.stateLock.lock()
            self.todayEventCount += 1
            self.stateLock.unlock()

            // Flush if batch limit exceeded or 30 seconds elapsed
            if self.memoryBuffer.count >= self.maxBufferedBatchCount || Date().timeIntervalSince(self.lastFlushTime) >= 30.0 {
                self.flushToDiskInternal()
            }

            DispatchQueue.main.async {
                self.onEventsUpdated?()
            }
        }
    }

    /// Explicitly flushes in-memory buffer before entering background or syncing
    public func flush() {
        writeQueue.sync { [weak self] in
            self?.flushToDiskInternal()
        }
    }

    private func flushToDiskInternal() {
        guard !memoryBuffer.isEmpty else { return }

        let day = MobileFormat.dayString()
        let file = bufferFile(for: day)

        var combined = Data()
        combined.reserveCapacity(memoryBuffer.reduce(0) { $0 + $1.count })
        for chunk in memoryBuffer {
            combined.append(chunk)
        }
        memoryBuffer.removeAll(keepingCapacity: true)
        lastFlushTime = Date()

        if FileManager.default.fileExists(atPath: file.path) {
            if let handle = try? FileHandle(forWritingTo: file) {
                defer { try? handle.close() }
                try? handle.seekToEnd()
                try? handle.write(contentsOf: combined)
            }
        } else {
            try? combined.write(to: file, options: .atomic)
        }

        // Also update the browsable export file in Documents/lumen_exports
        let exportFile = exportDir.appendingPathComponent("events-\(day)-iphone.jsonl")
        if FileManager.default.fileExists(atPath: file.path) {
            try? FileManager.default.removeItem(at: exportFile)
            try? FileManager.default.copyItem(at: file, to: exportFile)
        }
    }

    // MARK: - Thread-Safe Readers

    public func loadTodayEvents() -> [MobileTrackerEvent] {
        flush()
        let file = bufferFile(for: MobileFormat.dayString())
        guard let data = try? Data(contentsOf: file) else { return [] }

        var results: [MobileTrackerEvent] = []
        data.split(separator: 0x0A).forEach { slice in
            if let ev = try? MobileFormat.jsonDecoder.decode(MobileTrackerEvent.self, from: Data(slice)) {
                results.append(ev)
            }
        }
        return results
    }

    private func recalculateTodayCount() {
        let file = bufferFile(for: MobileFormat.dayString())
        if let data = try? Data(contentsOf: file) {
            let count = data.split(separator: 0x0A).count
            todayEventCount = count
        }
    }

    // MARK: - Safe iCloud / Local Fallback Sync

    public func syncToCloudOrDesktopContainer() -> Bool {
        flush()
        let day = MobileFormat.dayString()
        let src = bufferFile(for: day)
        guard FileManager.default.fileExists(atPath: src.path) else { return true }

        // Safely check iCloud Ubiquity Container (returns nil on Free Apple ID profiles)
        if let cloudURL = FileManager.default.url(forUbiquityContainerIdentifier: "iCloud.com.lumen.app")?.appendingPathComponent("Documents/Lumen/buffer") {
            do {
                try FileManager.default.createDirectory(at: cloudURL, withIntermediateDirectories: true)
                let dest = cloudURL.appendingPathComponent("events-\(day)-iphone.jsonl")
                try? FileManager.default.removeItem(at: dest)
                try FileManager.default.copyItem(at: src, to: dest)
                return true
            } catch {
                // Graceful fallback to local Documents export
            }
        }

        // Local Documents Fallback (Visible in iOS Files app)
        let localDest = exportDir.appendingPathComponent("events-\(day)-iphone.jsonl")
        try? FileManager.default.removeItem(at: localDest)
        try? FileManager.default.copyItem(at: src, to: localDest)
        return true
    }
}
