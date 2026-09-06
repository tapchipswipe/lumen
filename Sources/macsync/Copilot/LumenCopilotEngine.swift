import Foundation

struct CopilotResponse: Identifiable {
    let id = UUID()
    let title: String
    let answer: String
    let bulletPoints: [String]
    let actionPill: String?

    init(title: String, answer: String, bulletPoints: [String], actionPill: String? = nil) {
        self.title = title
        self.answer = answer
        self.bulletPoints = bulletPoints
        self.actionPill = actionPill
    }
}

enum LumenCopilotEngine {

    /// Answers natural language and voice questions across lifelog and system telemetry.
    static func ask(
        query: String,
        stats: TodayStats,
        spendMonth: SpendSummary,
        taxReport: ScheduleCTaxReport,
        forecast: FinancialForecast,
        storage: StorageSnapshot = .empty,
        power: PowerSnapshot = .empty,
        renewals: [PredictedRenewal] = [],
        audioReport: AudioFlowReport = .empty,
        gitCommits: [GitCommitNode] = [],
        aiFleet: AIFleetSummary = .empty
    ) -> CopilotResponse {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)

        // 1. Greetings & Voice Pleasantries
        if q == "hey lumen" || q == "hi lumen" || q == "hello" || q == "hi" || q == "hey" || q.starts(with: "good morning") || q.starts(with: "good afternoon") || q.starts(with: "good evening") || q.contains("how are you") || q.contains("what's up") || q.contains("how are you doing") {
            let p = power.estimatedRemainingMinutes > 0 ? power : PowerPacingEngine.captureSnapshot()
            let timeGreeting = getTimeBasedGreeting()
            let answer = "\(timeGreeting)! Your Mac is running smoothly at \(p.batteryPercent)% battery with a Focus Score of \(stats.focusScore). How can I assist your workflow?"
            return CopilotResponse(
                title: "Lumen Assistant",
                answer: answer,
                bulletPoints: [
                    "Battery Runway: \(p.batteryPercent)% (\(p.runwayFormatted))",
                    "Today's Focus: \(stats.focusScore)/100 (\(stats.focusScoreLabel))",
                    "Active Apps: \(stats.apps.first?.name ?? "Cursor")",
                    "Voice Interaction: Active & Listening"
                ],
                actionPill: "Ask Anything"
            )
        }

        // 2. Identity & Assistant Capabilities
        if q.contains("who are you") || q.contains("what are you") || q.contains("what can you do") || q.contains("help me") || q.contains("capabilities") {
            return CopilotResponse(
                title: "Lumen Cognitive Assistant",
                answer: "I am Lumen, your macOS cognitive and developer companion. I track your AI usage across Cursor and Antigravity, monitor Apple Silicon battery wattage, pace your focus flow, and manage your iCloud storage.",
                bulletPoints: [
                    "🤖 AI Fleet: Track tokens, fast requests, and student plans",
                    "🔋 Metal Power: Live SoC wattage draw and battery runway",
                    "⏳ Time Machine: 24-hour focus and Git commit scrubber",
                    "🧹 Turbo Sweep: 1-click iCloud offloading and bloat cleanup"
                ],
                actionPill: "Explore Features"
            )
        }

        // 3. Time & Date queries
        if q.contains("what time") || q.contains("the time") || q.contains("what day") || q.contains("today's date") || q.contains("what is the date") {
            let formatter = DateFormatter()
            formatter.dateFormat = "h:mm a 'on' EEEE, MMMM d"
            let timeStr = formatter.string(from: Date())
            return CopilotResponse(
                title: "Current Time & Date",
                answer: "It is currently \(timeStr).",
                bulletPoints: [
                    "Active Time Today: \(Int(stats.activeMinutes)) minutes",
                    "Focus Score: \(stats.focusScore)/100"
                ],
                actionPill: nil
            )
        }

        // 4. Power & Battery queries
        if q.contains("battery") || q.contains("power") || q.contains("watts") || q.contains("wattage") || q.contains("runway") || q.contains("drain") || q.contains("charging") {
            let p = power.estimatedRemainingMinutes > 0 ? power : PowerPacingEngine.captureSnapshot()
            return CopilotResponse(
                title: "Apple Silicon Power Telemetry",
                answer: "Your Mac battery is at \(p.batteryPercent)%, \(p.narrative.lowercased()).",
                bulletPoints: [
                    "Battery Status: \(p.batteryPercent)% (\(p.runwayFormatted))",
                    "Estimated SoC Draw: ~\(String(format: "%.1f", p.estimatedWatts))W",
                    "Thermal State: \(p.thermalState)",
                    "Battery Cycle Count: \(p.cycleCount) cycles"
                ],
                actionPill: "View Power Telemetry"
            )
        }

        // 5. Git & Commit queries
        if q.contains("git") || q.contains("commit") || q.contains("branch") || q.contains("repo") || q.contains("shipped") {
            let commits = !gitCommits.isEmpty ? gitCommits : GitVelocityLinker.scanRecentCommits()
            let count = commits.count
            let latest = commits.first
            return CopilotResponse(
                title: "Git Commit & Output Velocity",
                answer: "You have shipped \(count) commits across local repositories today.",
                bulletPoints: [
                    "Latest Commit: \(latest?.repoName ?? "macsync") · \"\(latest?.message ?? "Initial commit")\"",
                    "Active Branch: \(latest?.branch ?? "main")",
                    "Hash: \(latest?.shortHash ?? "e1f03ad")",
                    "Total Repos Active: \(Set(commits.map { $0.repoName }).count)"
                ],
                actionPill: "Scrub in Time Machine"
            )
        }

        // 6. Subscription Renewals & Price Hikes
        if q.contains("renewal") || q.contains("renew") || q.contains("upcoming bill") || q.contains("next charge") || q.contains("subscription") || q.contains("hike") {
            let nextSub = renewals.first
            let imminentCount = renewals.filter { $0.isImminent }.count
            return CopilotResponse(
                title: "Subscription Renewal Radar",
                answer: "You have \(renewals.count) recurring subscriptions scheduled for renewal over the next 30 days.",
                bulletPoints: [
                    "Next Upcoming Charge: \(nextSub?.merchant ?? "None") (\(nextSub?.amountFormatted ?? "$0.00")) on \(nextSub?.renewalRelativeFormatted ?? "soon")",
                    "Imminent Renewals (<= 3 days): \(imminentCount) services",
                    "Monthly Recurring SaaS Total: \(SpendFormat.amount(spendMonth.byCategory[.software] ?? 0))",
                    "Price Hike Alerts: \(renewals.filter { $0.isPriceHike }.count) detected"
                ],
                actionPill: "Inspect Renewals"
            )
        }

        // 7. Music & Audio Flow correlation
        if q.contains("music") || q.contains("song") || q.contains("audio") || q.contains("spotify") || q.contains("soundtrack") || q.contains("artist") {
            return CopilotResponse(
                title: "Soundtrack to Deep Work",
                answer: audioReport.summary,
                bulletPoints: [
                    "Top Productivity Audio: \(audioReport.topTracks.first?.title ?? "Ambient Flow")",
                    "Top Artist: \(audioReport.topArtist)",
                    "Typing Speed Boost: +\(audioReport.flowStateVelocityBoostPercent)% keystroke velocity",
                    "Correlated Focus Score: \(audioReport.topTracks.first?.avgFocusScore ?? 90)/100"
                ],
                actionPill: "View Flow Insights"
            )
        }

        // 8. Storage & iCloud Optimization queries
        if q.contains("storage") || q.contains("space") || q.contains("disk") || q.contains("clean") || q.contains("icloud") || q.contains("offload") || q.contains("evict") || q.contains("sweep") {
            let s = storage.totalDiskBytes > 0 ? storage : iCloudStorageOptimizer.scanStorage()
            return CopilotResponse(
                title: "iCloud Storage Optimization",
                answer: "Your Mac has \(s.freeDiskFormatted) free of \(s.totalDiskFormatted) (\(Int(s.diskUsagePercentage))% capacity). You have \(s.reclaimableFormatted) ready to offload to iCloud.",
                bulletPoints: [
                    "iCloud Dataless Eviction: \(s.reclaimableFormatted) reclaimable at 0 bytes local footprint",
                    "iCloud Offloaded Content: \(s.iCloudEvictedFormatted) stored in cloud",
                    "Disposable Caches: \(ByteCountFormatter.string(fromByteCount: s.cachePurgeableBytes, countStyle: .file)) purgeable",
                    "Top Target: \(s.candidates.first?.title ?? "System Application Caches")"
                ],
                actionPill: "Optimize in Cloud"
            )
        }

        // 9. Tax / Schedule-C queries
        if q.contains("tax") || q.contains("deduct") || q.contains("schedule c") || q.contains("write off") {
            return CopilotResponse(
                title: "Tax & Schedule-C Strategy",
                answer: "You have \(SpendFormat.amount(taxReport.totalDeductibleAmount)) in verified business deductions mapped to IRS Schedule-C for 2026.",
                bulletPoints: [
                    "Line 18 (Software & SaaS): \(SpendFormat.amount(taxReport.byLine[.line18Software] ?? 0))",
                    "Line 22 (Supplies & Hardware): \(SpendFormat.amount(taxReport.byLine[.line22Supplies] ?? 0))",
                    "Line 24b (50% Business Meals): \(SpendFormat.amount(taxReport.byLine[.line24bMeals] ?? 0))",
                    "Estimated Cash Saved on Taxes (28%): \(SpendFormat.amount(forecast.estimatedTaxSavings))"
                ],
                actionPill: "Export Schedule-C CSV"
            )
        }

        // 10. Financial / Spending queries
        if q.contains("spend") || q.contains("cost") || q.contains("card") || q.contains("steve") || q.contains("joyce") || q.contains("cava") || q.contains("wallet") {
            let total = spendMonth.total
            let topMerchant = spendMonth.byMerchant.max(by: { $0.value < $1.value })?.key ?? "Apple"
            let steveTotal = spendMonth.byCard["8031"] ?? 0
            let joyceTotal = spendMonth.byCard["1533"] ?? 0

            return CopilotResponse(
                title: "Financial Intelligence",
                answer: "You've spent \(SpendFormat.amount(total)) across all cards this month. Current projection is \(SpendFormat.amount(forecast.projectedMonthEndSpend)) by month-end.",
                bulletPoints: [
                    "Steve Credit (••8031): \(SpendFormat.amount(steveTotal))",
                    "Joyce Credit (••1533): \(SpendFormat.amount(joyceTotal))",
                    "Top Merchant: \(topMerchant)",
                    "Monthly Burn Rate: \(SpendFormat.amount(forecast.dailyBurnRate))/day"
                ],
                actionPill: "View Wallet"
            )
        }

        // 11. Work, Coding Output & Focus queries
        if q.contains("work") || q.contains("code") || q.contains("built") || q.contains("focus") || q.contains("today") || q.contains("standup") {
            let topApp = stats.apps.first?.name ?? "Cursor"
            return CopilotResponse(
                title: "Focus & Deep Work Summary",
                answer: "Today you logged \(Int(stats.activeMinutes)) minutes of active work with a Focus Score of \(stats.focusScore) (\(stats.focusScoreLabel)).",
                bulletPoints: [
                    "Top Project / App: \(topApp) (\(Int((stats.apps.first?.seconds ?? 0) / 60))m)",
                    "Keystrokes: \(stats.keystrokes) keys",
                    "Mouse Clicks: \(stats.clicks) clicks",
                    "Meeting Load: \(Int(stats.meetingMinutes))m"
                ],
                actionPill: "Open Dashboard"
            )
        }

        // 12. AI Accounts & Student Usage Tracking
        if q.contains("ai") || q.contains("antigravity") || q.contains("cursor") || q.contains("copilot") || q.contains("token") || q.contains("gemini") || q.contains("claude") || q.contains("gpt") || q.contains("model") || q.contains("quota") {
            let fleet = aiFleet.totalAccounts > 0 ? aiFleet : AIFleetTelemetryCollector.scanFleet()
            let cursorAcc = fleet.accounts.first(where: { $0.service == .cursor })
            let agyAcc = fleet.accounts.first(where: { $0.service == .antigravity })
            let copilotAcc = fleet.accounts.first(where: { $0.service == .copilot })

            var bullets: [String] = []
            if let c = cursorAcc {
                bullets.append("Cursor (Student): \(c.remainingUnits) fast requests remaining (\(c.formattedUsed)/\(c.formattedTotal))")
            }
            if let a = agyAcc {
                bullets.append("Antigravity (Google): \(a.formattedUsed) tokens active across \(a.dailyPromptCount) daily prompts")
            }
            if let p = copilotAcc {
                bullets.append("GitHub Copilot: Free Student Pack Active (\(p.formattedUsed) accepts)")
            }
            bullets.append("Plan Status: 100% Free via Student Memberships ($0.00 spend)")

            let spokenAnswer = "All your AI tools are active under student memberships at zero cost. You have \(cursorAcc?.remainingUnits ?? 328) Cursor fast requests remaining and \(agyAcc?.formattedUsed ?? "520k") active Antigravity tokens across Gemini 3.7 and Claude 3.7 Sonnet."

            return CopilotResponse(
                title: "AI Accounts & Student Usage",
                answer: spokenAnswer,
                bulletPoints: bullets,
                actionPill: "View AI Fleet"
            )
        }

        // 13. Dynamic Conversational Fallback
        let topApp = stats.apps.first?.name ?? "your project"
        return CopilotResponse(
            title: "Lumen Assistant",
            answer: "Regarding \(q): You're currently focused on \(topApp) with a Focus Score of \(stats.focusScore). You can ask me to check your AI usage, battery runway, Git commits, or clean your storage.",
            bulletPoints: [
                "Focus Score: \(stats.focusScore)/100 (\(stats.focusScoreLabel))",
                "Top App: \(topApp)",
                "AI Fleet: Free Student Plan Active",
                "Battery: \(power.batteryPercent)% (\(power.runwayFormatted))"
            ],
            actionPill: nil
        )
    }

    private static func getTimeBasedGreeting() -> String {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour < 12 {
            return "Good morning"
        } else if hour < 17 {
            return "Good afternoon"
        } else {
            return "Good evening"
        }
    }
}
