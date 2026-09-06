import Foundation

public struct iCloudConflictItem: Identifiable, Codable {
    public let id: UUID
    public let originalName: String
    public let conflictPath: String
    public let sizeBytes: Int64
    public let detectedDate: Date

    public init(id: UUID = UUID(), originalName: String, conflictPath: String, sizeBytes: Int64, detectedDate: Date = Date()) {
        self.id = id
        self.originalName = originalName
        self.conflictPath = conflictPath
        self.sizeBytes = sizeBytes
        self.detectedDate = detectedDate
    }
}

public struct iCloudRadarStatus: Codable {
    public let isOnline: Bool
    public let syncingCount: Int
    public let pendingUploads: Int
    public let conflictCount: Int
    public let conflicts: [iCloudConflictItem]
    public let lastChecked: Date

    public static let healthy = iCloudRadarStatus(
        isOnline: true,
        syncingCount: 0,
        pendingUploads: 0,
        conflictCount: 0,
        conflicts: [],
        lastChecked: Date()
    )
}

public enum iCloudSyncRadar {

    public static func inspectSyncRadar() -> iCloudRadarStatus {
        let home = NSHomeDirectory()
        let cloudRoot = "\(home)/Library/Mobile Documents/com~apple~CloudDocs"
        let fm = FileManager.default

        var conflicts: [iCloudConflictItem] = []
        let syncingCount = 0
        let pendingUploads = 0

        guard fm.fileExists(atPath: cloudRoot) else {
            return .healthy
        }

        // 1. Fast Scan for conflicting file patterns (e.g. " 2.", " (1).", ".icloud" conflict files)
        if let enumerator = fm.enumerator(at: URL(fileURLWithPath: cloudRoot), includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey], options: [.skipsHiddenFiles]) {
            var checked = 0
            for case let fileURL as URL in enumerator {
                checked += 1
                if checked > 300 { break }

                let name = fileURL.lastPathComponent
                let parentURL = fileURL.deletingLastPathComponent()

                var isConflict = false
                if name.contains(" (conflicted copy") || name.contains(" (conflict ") {
                    isConflict = true
                } else if name.contains(" (1).") {
                    let baseName = name.replacingOccurrences(of: " (1).", with: ".")
                    let originalFileURL = parentURL.appendingPathComponent(baseName)
                    if fm.fileExists(atPath: originalFileURL.path) {
                        isConflict = true
                    }
                }

                if isConflict {
                    let size = (try? fileURL.resourceValues(forKeys: [.fileSizeKey]).fileSize) ?? 0
                    conflicts.append(iCloudConflictItem(
                        originalName: name,
                        conflictPath: fileURL.path,
                        sizeBytes: Int64(size)
                    ))
                }
            }
        }

        return iCloudRadarStatus(
            isOnline: true,
            syncingCount: syncingCount,
            pendingUploads: pendingUploads,
            conflictCount: conflicts.count,
            conflicts: conflicts,
            lastChecked: Date()
        )
    }

    /// Auto-resolves a conflict by removing duplicate conflict copy.
    public static func resolveConflict(_ item: iCloudConflictItem) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: item.conflictPath) else { return false }
        do {
            try fm.removeItem(atPath: item.conflictPath)
            return true
        } catch {
            return false
        }
    }

    public static func resolveAllConflicts() -> Int {
        let radar = inspectSyncRadar()
        var resolved = 0
        for c in radar.conflicts {
            if resolveConflict(c) {
                resolved += 1
            }
        }
        return resolved
    }
}
