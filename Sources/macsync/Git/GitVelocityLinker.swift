import Foundation

struct GitCommitNode: Identifiable, Codable {
    let id: UUID
    let repoName: String
    let branch: String
    let commitHash: String
    let message: String
    let author: String
    let timestamp: Date
    let minuteOfDay: Int

    init(id: UUID = UUID(), repoName: String, branch: String, commitHash: String, message: String, author: String, timestamp: Date) {
        self.id = id
        self.repoName = repoName
        self.branch = branch
        self.commitHash = commitHash
        self.message = message
        self.author = author
        self.timestamp = timestamp

        let cal = Calendar.current
        self.minuteOfDay = (cal.component(.hour, from: timestamp) * 60) + cal.component(.minute, from: timestamp)
    }

    var shortHash: String {
        String(commitHash.prefix(7))
    }
}

enum GitVelocityLinker {
    private static let isoFormatter = ISO8601DateFormatter()
    private static let lock = NSLock()
    private static var repoCache: [String: (mtime: Date, branch: String, nodes: [GitCommitNode])] = [:]

    static func scanRecentCommits(since date: Date = Calendar.current.startOfDay(for: Date())) -> [GitCommitNode] {
        let home = NSHomeDirectory()
        let searchRoots = [
            "\(home)/Projects",
            "\(home)/Documents/Projects",
            "\(home)/repos",
            "\(home)/welift_sandbox"
        ]

        var nodes: [GitCommitNode] = []
        let fm = FileManager.default

        for root in searchRoots {
            guard fm.fileExists(atPath: root) else { continue }
            guard let entries = try? fm.contentsOfDirectory(atPath: root) else { continue }

            for entry in entries {
                let repoDir = "\(root)/\(entry)"
                let gitDir = "\(repoDir)/.git"
                guard fm.fileExists(atPath: gitDir) else { continue }

                // Guard against evicted / dataless iCloud Drive stubs
                var headStat = stat()
                let headPath = "\(gitDir)/HEAD"
                if lstat(headPath, &headStat) == 0 {
                    // 0x40000000 is UF_DATALESS on macOS
                    if (headStat.st_flags & 0x40000000) != 0 {
                        continue
                    }
                }

                // Check .git/HEAD and .git/logs/HEAD modification timestamp
                let headURL = URL(fileURLWithPath: headPath)
                let headLogsURL = URL(fileURLWithPath: "\(gitDir)/logs/HEAD")
                let headMtime = (try? headURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let logsMtime = (try? headLogsURL.resourceValues(forKeys: [.contentModificationDateKey]))?.contentModificationDate
                let latestMtime = [headMtime, logsMtime].compactMap { $0 }.max() ?? Date.distantPast

                lock.lock()
                if let cached = repoCache[repoDir], cached.mtime >= latestMtime {
                    nodes.append(contentsOf: cached.nodes)
                    lock.unlock()
                    continue
                }
                lock.unlock()

                // Query git branch with safe timeout
                guard let branchOut = safeRunGit(arguments: ["-C", repoDir, "rev-parse", "--abbrev-ref", "HEAD"]) else {
                    continue
                }
                let branch = (branchOut.isEmpty ? "main" : branchOut).trimmingCharacters(in: .whitespacesAndNewlines)

                // Query git log with safe timeout
                guard let logOut = safeRunGit(arguments: [
                    "-C", repoDir, "log", "-n", "8",
                    "--pretty=format:%H|%an|%aI|%s"
                ]), !logOut.isEmpty else {
                    lock.lock()
                    repoCache[repoDir] = (mtime: latestMtime, branch: branch, nodes: [])
                    lock.unlock()
                    continue
                }

                let lines = logOut.components(separatedBy: .newlines)
                var repoNodes: [GitCommitNode] = []

                for l in lines {
                    let parts = l.components(separatedBy: "|")
                    guard parts.count >= 4 else { continue }
                    let hash = parts[0]
                    let author = parts[1]
                    let dateStr = parts[2]
                    let msg = parts[3]

                    if let commitDate = isoFormatter.date(from: dateStr) {
                        repoNodes.append(GitCommitNode(
                            repoName: entry,
                            branch: branch.isEmpty ? "main" : branch,
                            commitHash: hash,
                            message: msg,
                            author: author,
                            timestamp: commitDate
                        ))
                    }
                }

                lock.lock()
                repoCache[repoDir] = (mtime: latestMtime, branch: branch, nodes: repoNodes)
                lock.unlock()

                nodes.append(contentsOf: repoNodes)
            }
        }

        return nodes.sorted(by: { $0.timestamp > $1.timestamp })
    }

    /// Executes a git command with a hard 2-second timeout to prevent hangs on network or cloud mounts.
    private static func safeRunGit(arguments: [String], timeout: TimeInterval = 2.0) -> String? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = FileHandle.nullDevice

        do {
            try process.run()
        } catch {
            return nil
        }

        let deadline = Date().addingTimeInterval(timeout)
        while process.isRunning && Date() < deadline {
            usleep(20_000) // 20ms
        }

        if process.isRunning {
            process.terminate()
            return nil
        }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
