import Foundation

public enum PinPolicy: String, Codable, CaseIterable {
    case alwaysLocal = "Always Local"     // Pin & download to SSD
    case alwaysCloud = "Always Cloud"     // Aggressively evict to dataless (0 bytes)
    case adaptive = "Adaptive"           // Auto-evict if unaccessed > 14 days
}

public struct PinnedFolderRule: Identifiable, Codable {
    public let id: UUID
    public let path: String
    public let displayName: String
    public var policy: PinPolicy
    public var lastSyncDate: Date?

    public init(id: UUID = UUID(), path: String, displayName: String, policy: PinPolicy, lastSyncDate: Date? = Date()) {
        self.id = id
        self.path = path
        self.displayName = displayName
        self.policy = policy
        self.lastSyncDate = lastSyncDate
    }
}

public enum FolderPinningEngine {
    private static let storageKey = "lumen.storage.pinnedFolders"

    public static func loadRules() -> [PinnedFolderRule] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let rules = try? JSONDecoder().decode([PinnedFolderRule].self, from: data) else {
            return defaultRules()
        }
        return rules
    }

    public static func saveRules(_ rules: [PinnedFolderRule]) {
        if let data = try? JSONEncoder().encode(rules) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    public static func defaultRules() -> [PinnedFolderRule] {
        let home = NSHomeDirectory()
        return [
            PinnedFolderRule(path: "\(home)/Documents/Projects", displayName: "Projects (Active Repos)", policy: .alwaysLocal),
            PinnedFolderRule(path: "\(home)/Documents/MacBackup_20260827", displayName: "System Backup Snapshot", policy: .alwaysCloud),
            PinnedFolderRule(path: "\(home)/Library/Mobile Documents/com~apple~CloudDocs/Downloads_Evicted", displayName: "Downloads Evicted Archive", policy: .alwaysCloud),
            PinnedFolderRule(path: "\(home)/Documents/School", displayName: "School & Study Materials", policy: .adaptive)
        ]
    }

    public static func applyPolicy(for rule: PinnedFolderRule) -> Bool {
        let url = URL(fileURLWithPath: rule.path)
        guard FileManager.default.fileExists(atPath: rule.path) else { return false }

        switch rule.policy {
        case .alwaysLocal:
            // Download ubiquitous item
            do {
                try FileManager.default.startDownloadingUbiquitousItem(at: url)
                return true
            } catch {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/usr/bin/brctl")
                process.arguments = ["download", rule.path]
                try? process.run()
                process.waitUntilExit()
                return process.terminationStatus == 0
            }
        case .alwaysCloud:
            return iCloudStorageOptimizer.evictItem(atPath: rule.path)
        case .adaptive:
            return true
        }
    }

    public static func isProtectedFromEviction(path: String) -> Bool {
        let rules = loadRules()
        for r in rules where r.policy == .alwaysLocal {
            if path.hasPrefix(r.path) {
                return true
            }
        }
        return false
    }
}
