import Foundation

struct DailyStandupReport: Codable {
    let dateFormatted: String
    let totalFocusMinutes: Int
    let topProjects: [String]
    let commitsSummary: [String]
    let uncommittedDiffLines: Int
    let cognitiveFlowScore: Int
    let markdownOutput: String

    static let empty = DailyStandupReport(
        dateFormatted: "Today",
        totalFocusMinutes: 0,
        topProjects: [],
        commitsSummary: [],
        uncommittedDiffLines: 0,
        cognitiveFlowScore: 85,
        markdownOutput: "No activity recorded yet."
    )
}

enum StandupGeneratorEngine {

    /// Generates a structured daily standup report from Attention Time Machine frames, Git commits, and focus telemetry.
    static func generate(
        stats: TodayStats,
        frames: [TimeMachineFrame],
        cognitive: CognitiveFragmentationSnapshot
    ) -> DailyStandupReport {
        let df = DateFormatter()
        df.dateStyle = .long
        let dateStr = df.string(from: Date())

        let focusMinutes = Int(stats.activeMinutes)
        let hours = focusMinutes / 60
        let mins = focusMinutes % 60
        let focusTimeStr = hours > 0 ? "\(hours)h \(mins)m" : "\(mins)m"

        let topApps = stats.apps.prefix(3).map { "\($0.name) (\(Int($0.seconds / 60))m)" }
        let topProjects = stats.apps.prefix(3).map { $0.name }

        // Extract today's git commits from recent local repositories
        let gitSummary = extractGitActivity()

        // Construct formatted Markdown standup
        var lines: [String] = [
            "### 🚀 Daily Standup · \(dateStr)",
            "",
            "#### 🔨 Shipped & Built Today:"
        ]

        if gitSummary.commits.isEmpty {
            lines.append("* Active development in: \(topProjects.joined(separator: ", ")) (\(stats.keystrokes) keystrokes)")
        } else {
            for commit in gitSummary.commits {
                lines.append("* **\(commit.repo)** (`\(commit.branch)`): \(commit.message)")
            }
        }

        if gitSummary.diffLines > 0 {
            lines.append("* **Uncommitted Velocity**: +\(gitSummary.diffLines) modified lines in flight")
        }

        lines.append("")
        lines.append("#### 🧠 Focus & Productivity:")
        lines.append("* **Deep Focus**: \(focusMinutes) minutes total (\(focusTimeStr))")
        lines.append("* **Cognitive Flow Score**: \(cognitive.flowScore)/100 (\(cognitive.flowStateLabel))")
        lines.append("* **Top Applications**: \(topApps.joined(separator: " · "))")
        lines.append("* **Context Switching Pace**: \(cognitive.switchesPerHour) switches/hr")

        lines.append("")
        lines.append("#### 🎯 In-Flight / Tomorrow:")
        lines.append("* Continue sprint iterations on \(topProjects.first ?? "Lumen")")

        let fullMarkdown = lines.joined(separator: "\n")

        return DailyStandupReport(
            dateFormatted: dateStr,
            totalFocusMinutes: focusMinutes,
            topProjects: topProjects,
            commitsSummary: gitSummary.commits.map { "\($0.repo): \($0.message)" },
            uncommittedDiffLines: gitSummary.diffLines,
            cognitiveFlowScore: cognitive.flowScore,
            markdownOutput: fullMarkdown
        )
    }

    private static func extractGitActivity() -> (commits: [(repo: String, branch: String, message: String)], diffLines: Int) {
        let repos = [
            "/Users/lucasdespot/macsync",
            "/Users/lucasdespot/paper_trading_bot",
            NSHomeDirectory() + "/Projects",
            NSHomeDirectory() + "/repos"
        ]

        var commitList: [(repo: String, branch: String, message: String)] = []
        var totalDiff = 0
        let fm = FileManager.default

        for r in repos {
            guard fm.fileExists(atPath: "\(r)/.git") else { continue }
            let name = (r as NSString).lastPathComponent
            let branch = runGit(args: ["branch", "--show-current"], cwd: r).trimmingCharacters(in: .whitespacesAndNewlines)
            let commitsOut = runGit(args: ["log", "--since=midnight", "--oneline", "-n", "3"], cwd: r)
            let diffStat = runGit(args: ["diff", "--shortstat"], cwd: r)

            let lines = commitsOut.split(separator: "\n")
            for line in lines {
                let parts = line.split(separator: " ", maxSplits: 1)
                let msg = parts.count > 1 ? String(parts[1]) : String(line)
                commitList.append((repo: name, branch: branch.isEmpty ? "main" : branch, message: msg))
            }

            // Parse diff lines
            let diffParts = diffStat.components(separatedBy: ",")
            for p in diffParts {
                if p.contains("insertion") || p.contains("deletion") {
                    let digits = p.filter { $0.isNumber }
                    if let num = Int(digits) { totalDiff += num }
                }
            }
        }

        return (commitList, totalDiff)
    }

    private static func runGit(args: [String], cwd: String) -> String {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/bin/git")
        p.arguments = ["-C", cwd] + args
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        return String(data: data, encoding: .utf8) ?? ""
    }
}
