import Foundation

public struct DeveloperProjectCandidate: Identifiable, Codable {
    public let id: UUID
    public let projectName: String
    public let projectPath: String
    public let bloatPath: String
    public let bloatType: String // e.g. "node_modules", ".venv", "target", ".build"
    public let sizeBytes: Int64
    public let lastModified: Date

    public init(id: UUID = UUID(), projectName: String, projectPath: String, bloatPath: String, bloatType: String, sizeBytes: Int64, lastModified: Date = Date()) {
        self.id = id
        self.projectName = projectName
        self.projectPath = projectPath
        self.bloatPath = bloatPath
        self.bloatType = bloatType
        self.sizeBytes = sizeBytes
        self.lastModified = lastModified
    }

    public var sizeFormatted: String {
        ByteCountFormatter.string(fromByteCount: sizeBytes, countStyle: .file)
    }
}

public enum DeveloperProjectTrimmer {

    public static func scanDeveloperBloat() -> [DeveloperProjectCandidate] {
        let home = NSHomeDirectory()
        let searchRoots = [
            "\(home)/Projects",
            "\(home)/Documents/Projects",
            "\(home)/repos",
            "\(home)/welift_sandbox",
            "\(home)/Developer",
            "\(home)/Code",
            "\(home)/workspace",
            "\(home)/Desktop",
            "\(home)/src"
        ]

        var results: [DeveloperProjectCandidate] = []
        let fm = FileManager.default

        let targets = [
            ("node_modules", "Node.js Dependencies"),
            (".venv", "Python Virtualenv"),
            ("venv", "Python Virtualenv"),
            ("target", "Rust Build Artifacts"),
            (".build", "Swift Build Cache"),
            (".turbo", "Turborepo Cache"),
            (".next", "Next.js Build")
        ]

        // Also check top-level home directories that are projects (like ~/macsync)
        if let homeEntries = try? fm.contentsOfDirectory(atPath: home) {
            for entry in homeEntries {
                if entry.hasPrefix(".") || entry == "Library" || entry == "Applications" || entry == "System" { continue }
                let p = "\(home)/\(entry)"
                var isDir: ObjCBool = false
                if fm.fileExists(atPath: p, isDirectory: &isDir), isDir.boolValue {
                    if fm.fileExists(atPath: "\(p)/.git") || fm.fileExists(atPath: "\(p)/Package.swift") || fm.fileExists(atPath: "\(p)/package.json") {
                        for (folderName, typeLabel) in targets {
                            let bloatDir = "\(p)/\(folderName)"
                            if fm.fileExists(atPath: bloatDir) {
                                let size = iCloudStorageOptimizer.getDirectorySize(URL(fileURLWithPath: bloatDir))
                                if size > 5_000_000 {
                                    results.append(DeveloperProjectCandidate(
                                        projectName: entry,
                                        projectPath: p,
                                        bloatPath: bloatDir,
                                        bloatType: typeLabel,
                                        sizeBytes: size
                                    ))
                                }
                            }
                        }
                    }
                }
            }
        }

        for root in searchRoots {
            guard fm.fileExists(atPath: root) else { continue }
            guard let projects = try? fm.contentsOfDirectory(atPath: root) else { continue }

            for proj in projects {
                if proj.hasPrefix(".") { continue }
                let projPath = "\(root)/\(proj)"

                var isDir: ObjCBool = false
                guard fm.fileExists(atPath: projPath, isDirectory: &isDir), isDir.boolValue else { continue }

                for (folderName, typeLabel) in targets {
                    let bloatDir = "\(projPath)/\(folderName)"
                    if fm.fileExists(atPath: bloatDir) {
                        let size = iCloudStorageOptimizer.getDirectorySize(URL(fileURLWithPath: bloatDir))
                        if size > 5_000_000 { // > 5MB
                            let candidate = DeveloperProjectCandidate(
                                projectName: proj,
                                projectPath: projPath,
                                bloatPath: bloatDir,
                                bloatType: typeLabel,
                                sizeBytes: size
                            )
                            results.append(candidate)
                        }
                    }
                }
            }
        }

        return results.sorted(by: { $0.sizeBytes > $1.sizeBytes })
    }

    /// Trims a specific bloat candidate folder safely.
    public static func trimCandidate(_ candidate: DeveloperProjectCandidate) -> Bool {
        let fm = FileManager.default
        guard fm.fileExists(atPath: candidate.bloatPath) else { return false }
        do {
            try fm.removeItem(atPath: candidate.bloatPath)
            return true
        } catch {
            return false
        }
    }

    /// Trims all developer bloat across inactive projects.
    public static func trimAllCandidates() -> Int64 {
        let candidates = scanDeveloperBloat()
        var reclaimed: Int64 = 0
        for c in candidates {
            if trimCandidate(c) {
                reclaimed += c.sizeBytes
            }
        }
        return reclaimed
    }
}
