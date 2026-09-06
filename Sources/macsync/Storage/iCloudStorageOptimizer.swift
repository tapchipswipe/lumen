import Foundation

public enum StorageCategory: String, Codable, CaseIterable {
    case iCloudEvictable = "iCloud Evictable"
    case duplicateFile = "Duplicate Media"
    case cachePurge = "System Cache"
    case downloadsArchive = "Downloads to Cloud"
    case largeMedia = "Large Local Media"

    public var icon: String {
        switch self {
        case .iCloudEvictable: return "icloud.and.arrow.up"
        case .duplicateFile: return "doc.on.doc.fill"
        case .cachePurge: return "trash.circle.fill"
        case .downloadsArchive: return "arrow.down.doc.fill"
        case .largeMedia: return "film.fill"
        }
    }
}

public struct StorageOptimizationCandidate: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let detail: String
    public let path: String
    public let sizeBytes: Int64
    public let category: StorageCategory
    public var isEvicted: Bool

    public init(id: UUID = UUID(), title: String, detail: String, path: String, sizeBytes: Int64, category: StorageCategory, isEvicted: Bool = false) {
        self.id = id
        self.title = title
        self.detail = detail
        self.path = path
        self.sizeBytes = sizeBytes
        self.category = category
        self.isEvicted = isEvicted
    }

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public struct StorageSnapshot: Codable {
    public let totalDiskBytes: Int64
    public let usedDiskBytes: Int64
    public let freeDiskBytes: Int64
    public let diskUsagePercentage: Double
    public let iCloudDriveTotalBytes: Int64
    public let iCloudLocalBytes: Int64
    public let iCloudEvictedBytes: Int64
    public let reclaimableBytes: Int64
    public let duplicateSavingsBytes: Int64
    public let cachePurgeableBytes: Int64
    public let candidates: [StorageOptimizationCandidate]
    public let lastScanned: Date

    public static let empty = StorageSnapshot(
        totalDiskBytes: 0,
        usedDiskBytes: 0,
        freeDiskBytes: 0,
        diskUsagePercentage: 0,
        iCloudDriveTotalBytes: 0,
        iCloudLocalBytes: 0,
        iCloudEvictedBytes: 0,
        reclaimableBytes: 0,
        duplicateSavingsBytes: 0,
        cachePurgeableBytes: 0,
        candidates: [],
        lastScanned: Date()
    )

    public var freeDiskFormatted: String {
        ByteCountFormatter.string(fromByteCount: freeDiskBytes, countStyle: .file)
    }

    public var totalDiskFormatted: String {
        ByteCountFormatter.string(fromByteCount: totalDiskBytes, countStyle: .file)
    }

    public var usedDiskFormatted: String {
        ByteCountFormatter.string(fromByteCount: usedDiskBytes, countStyle: .file)
    }

    public var reclaimableFormatted: String {
        ByteCountFormatter.string(fromByteCount: reclaimableBytes, countStyle: .file)
    }

    public var iCloudEvictedFormatted: String {
        ByteCountFormatter.string(fromByteCount: iCloudEvictedBytes, countStyle: .file)
    }

    public var statusNarrative: String {
        if diskUsagePercentage >= 90.0 {
            return "Disk space is critical (\(Int(diskUsagePercentage))% full). \(reclaimableFormatted) can be offloaded to iCloud immediately."
        } else if diskUsagePercentage >= 75.0 {
            return "\(freeDiskFormatted) available. \(reclaimableFormatted) reclaimable via iCloud dataless eviction."
        } else {
            return "Storage healthy. \(iCloudEvictedFormatted) offloaded to iCloud (0 bytes local footprint)."
        }
    }
}

public enum iCloudStorageOptimizer {

    public static func scanStorage() -> StorageSnapshot {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        var totalBytes: Int64 = 250_000_000_000
        var freeBytes: Int64 = 16_000_000_000

        if let values = try? home.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityForImportantUsageKey]) {
            if let tot = values.volumeTotalCapacity { totalBytes = Int64(tot) }
            if let avail = values.volumeAvailableCapacityForImportantUsage { freeBytes = Int64(avail) }
        }

        let usedBytes = max(0, totalBytes - freeBytes)
        let usagePct = totalBytes > 0 ? (Double(usedBytes) / Double(totalBytes)) * 100.0 : 0.0

        var candidates: [StorageOptimizationCandidate] = []
        var reclaimableBytes: Int64 = 0
        var cacheBytes: Int64 = 0
        var cloudLocalBytes: Int64 = 0
        var cloudEvictedBytes: Int64 = 0

        // 1. Scan iCloud Drive for downloaded items that can be evicted locally
        let cloudDocsPath = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs")
        if FileManager.default.fileExists(atPath: cloudDocsPath.path) {
            let evictable = scanDirectoryForEvictableItems(cloudDocsPath)
            for item in evictable {
                candidates.append(item)
                reclaimableBytes += item.sizeBytes
                cloudLocalBytes += item.sizeBytes
            }
        }

        // 2. Scan safe disposable developer and system build caches
        let safeCacheTargets = [
            ("Xcode DerivedData & Build Caches", home.appendingPathComponent("Library/Developer/Xcode/DerivedData")),
            ("Xcode Module Caches", home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode")),
            ("npm Cache", home.appendingPathComponent(".npm/_cacache")),
            ("CocoaPods Cache", home.appendingPathComponent("Library/Caches/CocoaPods")),
            ("Homebrew Download Caches", home.appendingPathComponent("Library/Caches/Homebrew")),
            ("Cargo Registry Cache", home.appendingPathComponent(".cargo/registry/cache"))
        ]

        for (label, cacheURL) in safeCacheTargets {
            if FileManager.default.fileExists(atPath: cacheURL.path) {
                let size = getDirectorySize(cacheURL)
                if size > 10_000_000 { // > 10MB
                    let candidate = StorageOptimizationCandidate(
                        title: label,
                        detail: "Disposable build & package cache at \(cacheURL.lastPathComponent)",
                        path: cacheURL.path,
                        sizeBytes: size,
                        category: .cachePurge
                    )
                    candidates.append(candidate)
                    cacheBytes += size
                    reclaimableBytes += size
                }
            }
        }

        // 3. Scan Downloads folder for stale heavy files (> 20MB)
        let downloadsPath = home.appendingPathComponent("Downloads")
        let (dlCandidates, _) = scanDownloadsForCloudArchiving(downloadsPath)
        for item in dlCandidates {
            candidates.append(item)
            reclaimableBytes += item.sizeBytes
        }

        // 4. Estimate cloud eviction ghost files
        let evictedPath = cloudDocsPath.appendingPathComponent("Downloads_Evicted")
        if FileManager.default.fileExists(atPath: evictedPath.path) {
            cloudEvictedBytes += getDirectorySize(evictedPath)
        }

        return StorageSnapshot(
            totalDiskBytes: totalBytes,
            usedDiskBytes: usedBytes,
            freeDiskBytes: freeBytes,
            diskUsagePercentage: usagePct,
            iCloudDriveTotalBytes: cloudLocalBytes + cloudEvictedBytes,
            iCloudLocalBytes: cloudLocalBytes,
            iCloudEvictedBytes: cloudEvictedBytes,
            reclaimableBytes: reclaimableBytes,
            duplicateSavingsBytes: 0,
            cachePurgeableBytes: cacheBytes,
            candidates: candidates,
            lastScanned: Date()
        )
    }

    private static func scanDirectoryForEvictableItems(_ url: URL) -> [StorageOptimizationCandidate] {
        var results: [StorageOptimizationCandidate] = []
        let fm = FileManager.default

        guard let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isUbiquitousItemKey, .ubiquitousItemDownloadingStatusKey, .isRegularFileKey], options: [.skipsHiddenFiles, .skipsPackageDescendants]) else {
            return results
        }

        var scannedCount = 0
        for case let fileURL as URL in enumerator {
            scannedCount += 1
            if scannedCount > 500 { break }

            guard let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey, .ubiquitousItemDownloadingStatusKey]),
                  let isFile = res.isRegularFile, isFile,
                  let size = res.fileSize, Int64(size) > 50_000_000 else {
                continue
            }

            // Exclude already evicted (dataless) files
            if res.ubiquitousItemDownloadingStatus == .notDownloaded {
                continue
            }

            // Exclude git internal objects
            if fileURL.path.contains("/.git/") || fileURL.path.contains("/DerivedData/") {
                continue
            }

            let candidate = StorageOptimizationCandidate(
                title: fileURL.lastPathComponent,
                detail: "iCloud file downloaded locally (\(fileURL.deletingLastPathComponent().lastPathComponent))",
                path: fileURL.path,
                sizeBytes: Int64(size),
                category: .iCloudEvictable
            )
            results.append(candidate)
        }

        return results
    }

    private static func scanDownloadsForCloudArchiving(_ url: URL) -> ([StorageOptimizationCandidate], Int64) {
        var results: [StorageOptimizationCandidate] = []
        var total: Int64 = 0
        let fm = FileManager.default

        guard let files = try? fm.contentsOfDirectory(at: url, includingPropertiesForKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey], options: [.skipsHiddenFiles]) else {
            return ([], 0)
        }

        let oneWeekAgo = Date().addingTimeInterval(-86400 * 7)

        for file in files {
            guard let res = try? file.resourceValues(forKeys: [.fileSizeKey, .contentModificationDateKey, .isRegularFileKey]),
                  let isFile = res.isRegularFile, isFile,
                  let size = res.fileSize, Int64(size) > 5_000_000 else {
                continue
            }

            let ext = file.pathExtension.lowercased()
            let isStale = (res.contentModificationDate ?? Date()) < oneWeekAgo
            let isInstallerOrArchive = ["dmg", "pkg", "zip", "tar", "csv", "torrent", "iso", "mov", "mp4"].contains(ext)

            if isStale || isInstallerOrArchive {
                let candidate = StorageOptimizationCandidate(
                    title: file.lastPathComponent,
                    detail: "Downloads item -> Archive to iCloud & evict",
                    path: file.path,
                    sizeBytes: Int64(size),
                    category: .downloadsArchive
                )
                results.append(candidate)
                total += Int64(size)
            }
        }

        return (results, total)
    }

    public static func getDirectorySize(_ url: URL) -> Int64 {
        var total: Int64 = 0
        let fm = FileManager.default
        if let enumerator = fm.enumerator(at: url, includingPropertiesForKeys: [.fileSizeKey, .isRegularFileKey], options: [.skipsHiddenFiles]) {
            for case let fileURL as URL in enumerator {
                if let res = try? fileURL.resourceValues(forKeys: [.fileSizeKey, .isRegularFileKey]),
                   let isFile = res.isRegularFile, isFile,
                   let size = res.fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    /// Evicts a file or directory in iCloud Drive using Cocoa API.
    public static func evictItem(atPath path: String) -> Bool {
        let url = URL(fileURLWithPath: path)
        let fm = FileManager.default

        // If already not downloaded, skip
        if let res = try? url.resourceValues(forKeys: [.ubiquitousItemDownloadingStatusKey]),
           res.ubiquitousItemDownloadingStatus == .notDownloaded {
            return false
        }

        do {
            try fm.evictUbiquitousItem(at: url)
            return true
        } catch {
            return false
        }
    }

    /// Archives a file from local directory (e.g. ~/Downloads) into iCloud Drive and immediately evicts it.
    public static func archiveToCloudAndEvict(sourcePath: String) -> Bool {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let targetDir = home.appendingPathComponent("Library/Mobile Documents/com~apple~CloudDocs/Downloads_Evicted")
        let fm = FileManager.default

        try? fm.createDirectory(at: targetDir, withIntermediateDirectories: true)

        let sourceURL = URL(fileURLWithPath: sourcePath)
        let targetURL = targetDir.appendingPathComponent(sourceURL.lastPathComponent)

        do {
            if fm.fileExists(atPath: targetURL.path) {
                try fm.removeItem(at: targetURL)
            }
            try fm.moveItem(at: sourceURL, to: targetURL)

            // Evict target in iCloud after moving
            DispatchQueue.global().asyncAfter(deadline: .now() + 1.0) {
                _ = evictItem(atPath: targetURL.path)
            }
            return true
        } catch {
            return false
        }
    }

    /// Purges disposable cache folders safely.
    public static func purgeUserCaches() -> Int64 {
        let home = URL(fileURLWithPath: NSHomeDirectory())
        let fm = FileManager.default
        var bytesCleaned: Int64 = 0

        let targetPaths = [
            home.appendingPathComponent("Library/Developer/Xcode/DerivedData"),
            home.appendingPathComponent("Library/Caches/com.apple.dt.Xcode"),
            home.appendingPathComponent(".npm/_cacache"),
            home.appendingPathComponent("Library/Caches/CocoaPods"),
            home.appendingPathComponent("Library/Caches/Homebrew"),
            home.appendingPathComponent(".cargo/registry/cache")
        ]

        for path in targetPaths {
            if fm.fileExists(atPath: path.path) {
                let size = getDirectorySize(path)
                if (try? fm.removeItem(at: path)) != nil {
                    bytesCleaned += size
                }
            }
        }

        return bytesCleaned
    }
}
