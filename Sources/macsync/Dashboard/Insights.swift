import Foundation

// MARK: - Context tagging (#3)

enum ActivityCategory: String, CaseIterable, Identifiable {
    case code, writing, comms, design, media, meetings, browse, other
    var id: String { rawValue }

    var label: String {
        switch self {
        case .code: "Code"; case .writing: "Writing"; case .comms: "Comms"
        case .design: "Design"; case .media: "Media"; case .meetings: "Meetings"
        case .browse: "Browse"; case .other: "Other"
        }
    }

    var colorHex: String {
        switch self {
        case .code: "#5B8CFF"; case .writing: "#FFD166"; case .comms: "#FF8A5B"
        case .design: "#C77DFF"; case .media: "#63E6BE"; case .meetings: "#FF6B8A"
        case .browse: "#7BDFF2"; case .other: "#9AA0B5"
        }
    }

    var icon: String {
        switch self {
        case .code: "chevron.left.forwardslash.chevron.right"; case .writing: "pencil.line"
        case .comms: "bubble.left.and.bubble.right"; case .design: "paintbrush"
        case .media: "play.circle"; case .meetings: "video"
        case .browse: "safari"; case .other: "square.grid.2x2"
        }
    }

    private static let appRules: [(ActivityCategory, [String])] = [
        (.code, ["xcode", "terminal", "iterm", "cursor", "vscode", "visual studio code", "sublime text", "zed", "npm", "git", "github desktop"]),
        (.writing, ["notes", "obsidian", "notion", "word", "pages", "ia writer", "typora", "bear", "textedit", "drafts"]),
        (.comms, ["slack", "messages", "mail", "discord", "telegram", "whatsapp", "spark"]),
        (.design, ["figma", "sketch", "photoshop", "illustrator", "canva", "pixelmator", "affinity"]),
        (.media, ["spotify", "music", "netflix", "podcasts", "vlc", "iina"]),
        (.meetings, ["zoom", "teams", "webex", "facetime", "google meet", "whereby"]),
        (.browse, ["safari", "chrome", "arc", "firefox", "edge", "brave"])
    ]

    private static let domainRules: [(ActivityCategory, [String])] = [
        (.code, ["github.com", "gitlab.com", "stackoverflow.com", "developer.apple.com", "docs.rs", "npmjs.com"]),
        (.comms, ["mail.google.com", "outlook.", "web.whatsapp.com"]),
        (.media, ["youtube.com", "netflix.com", "spotify.com", "twitch.tv"]),
        (.design, ["figma.com", "dribbble.com"]),
        (.writing, ["notion.so", "docs.google.com"]),
        (.meetings, ["zoom.us", "teams.microsoft.com", "meet.google.com"])
    ]

    static func forApp(_ name: String) -> ActivityCategory {
        let lower = name.lowercased()
        for (cat, needles) in appRules where needles.contains(where: { lower.contains($0) }) {
            return cat
        }
        return .other
    }

    static func forURL(_ url: String?) -> ActivityCategory? {
        guard let url else { return nil }
        let lower = url.lowercased()
        for (cat, needles) in domainRules where needles.contains(where: { lower.contains($0) }) {
            return cat
        }
        return nil
    }
}

struct CategoryUsage: Identifiable {
    let id = UUID()
    let category: ActivityCategory
    let seconds: TimeInterval
}

// MARK: - History (#1)

struct DayPoint: Identifiable {
    let id = UUID()
    let date: Date
    let keystrokes: Int
    let clicks: Int
    let activeMinutes: Double
}

struct HistoryLoader {
    private static let lock = NSLock()
    private static var eventCache: [String: [TrackerEvent]] = [:]

    /// Clears the memory cache when archives are pruned or synced.
    static func invalidateCache() {
        lock.lock()
        eventCache.removeAll()
        lock.unlock()
    }

    /// Load events persisted in the local archive (past synced days) with in-memory caching.
    static func archivedEvents(daysBack: Int) -> [(day: String, events: [TrackerEvent])] {
        let fm = FileManager.default
        let dir = DataStore.shared.archiveDir
        guard let files = try? fm.contentsOfDirectory(atPath: dir.path) else { return [] }
        let cal = Calendar.current
        var out: [(String, [TrackerEvent])] = []
        for name in files.sorted() where name.hasPrefix("events-") && name.hasSuffix(".jsonl") {
            let day = String(name.dropFirst(7).dropLast(6))
            guard let date = SyncFormat.dayFormatter.date(from: day),
                  let age = cal.dateComponents([.day], from: cal.startOfDay(for: date), to: cal.startOfDay(for: Date())).day,
                  age >= 1, age <= daysBack else { continue }
            
            lock.lock()
            if let cached = eventCache[day] {
                lock.unlock()
                if !cached.isEmpty { out.append((day, cached)) }
                continue
            }
            lock.unlock()

            guard let data = try? Data(contentsOf: dir.appendingPathComponent(name)) else { continue }
            let events = data.split(separator: 0x0A).compactMap {
                try? SyncFormat.jsonDecoder.decode(TrackerEvent.self, from: Data($0))
            }
            
            lock.lock()
            eventCache[day] = events
            lock.unlock()

            if !events.isEmpty { out.append((day, events)) }
        }
        return out
    }

    /// Per-day summary points for week/month charts (today appended from live stats).
    static func dayPoints(daysBack: Int, today: TodayStats) -> [DayPoint] {
        var points: [DayPoint] = []
        let cal = Calendar.current
        for (day, events) in archivedEvents(daysBack: daysBack) {
            var keys = 0, clicks = 0, active = 0.0
            for e in events {
                if case .inputMetrics(let p) = e.payload {
                    keys += p.keystrokeCount; clicks += p.mouseClickCount
                    active += Double(p.activeSeconds)
                }
            }
            if let d = SyncFormat.dayFormatter.date(from: day) {
                points.append(DayPoint(date: d, keystrokes: keys, clicks: clicks, activeMinutes: active / 60.0))
            }
        }
        if let todayDate = cal.date(byAdding: .day, value: 0, to: Date()) {
            points.append(DayPoint(date: cal.startOfDay(for: todayDate),
                                   keystrokes: today.keystrokes, clicks: today.clicks,
                                   activeMinutes: today.activeMinutes))
        }
        return points.sorted { $0.date < $1.date }
    }
}

// MARK: - Insights (#4 #5 #18)

enum InsightsBuilder {
    /// Plain-English bullets about today (#18).
    static func summary(_ s: TodayStats) -> [String] {
        var lines: [String] = []
        let h = Int(s.activeMinutes) / 60, m = Int(s.activeMinutes) % 60
        lines.append("You were active \(h > 0 ? "\(h)h " : "")\(m)m today across \(s.focusSessions) focus sessions.")
        if let top = s.apps.first {
            lines.append("Most time in \(top.name) (\(Int(top.seconds / 60))m).")
        }
        if s.zombieSeconds > 60 {
            let zm = Int(s.zombieSeconds / 60)
            let pct = max(1, Int((s.zombieSeconds / max(s.activeSeconds, 1)) * 100))
            lines.append("\(zm)m of window time had zero input (\(pct)% of active time).")
        }
        if let b = s.batteryPercent {
            lines.append("Battery is at \(b)%\(s.batteryCharging == true ? " and charging" : "").")
        }
        if !s.pages.isEmpty {
            lines.append("You viewed \(s.pages.count) distinct pages.")
        }
        lines.append("\(s.keystrokes) keystrokes · \(s.clicks) clicks · \(Self.distance(s.cursorDistance)) cursor travel.")
        // ── v0.4.0 context pack insights ──
        if s.meetingMinutes >= 5 {
            lines.append("\(Int(s.meetingMinutes))m on calls (camera/mic active).")
        }
        if let media = s.topMediaApp, let mins = s.mediaSeconds[media], mins >= 300 {
            lines.append("\(Int(mins / 60))m of playback in \(media).")
        }
        if s.clipboardCopies > 0 {
            lines.append("\(s.clipboardCopies) copy/paste actions — \(s.clipboardCopies > 30 ? "heavy shuttling between apps." : "steady clipboard use.")")
        }
        if let unread = s.mailUnread {
            var mailLine = "Inbox: \(unread) unread"
            if let recv = s.mailReceivedToday { mailLine += ", \(recv) received today" }
            if let sent = s.mailSentToday { mailLine += ", \(sent) sent" }
            lines.append(mailLine + ".")
        }
        if s.screenLockCount > 0 {
            lines.append("You locked the screen \(s.screenLockCount) time\(s.screenLockCount == 1 ? "" : "s") today.")
        }
        if let ssid = s.wifiSSID, !ssid.isEmpty {
            var net = "On Wi-Fi network \(ssid)"
            if let vpn = s.onVPN, vpn { net += " via VPN" }
            lines.append(net + ".")
        }
        if let f = s.focusActive {
            lines.append(f ? "Focus mode is on — you were in a Focus state when last checked." : "Focus mode was off at your last check.")
        }
        return lines
    }

    /// Anomaly nudge (#4): today's top app vs its 7-day average.
    static func anomaly(_ s: TodayStats, archived: [(day: String, events: [TrackerEvent])]) -> String? {
        guard let top = s.apps.first, top.seconds > 1800, !archived.isEmpty else { return nil }
        var perDay: [String: TimeInterval] = [:]
        for (day, events) in archived {
            var secs: TimeInterval = 0
            for e in events {
                if case .appFocus(let p) = e.payload, p.appName == top.name { secs += p.durationSeconds }
            }
            perDay[day] = secs
        }
        guard !perDay.isEmpty else { return nil }
        let avg = perDay.values.reduce(0, +) / Double(perDay.count)
        guard avg > 300, top.seconds > avg * 2 else { return nil }
        return "⚠️ \(top.name) is at \(Int(top.seconds / 60))m today — \(Int(top.seconds / max(avg, 1) * 100))% of your usual (\(Int(avg / 60))m)."
    }

    static func distance(_ pts: Double) -> String {
        let meters = pts / 72.0 * 0.0254
        if meters < 1000 { return "\(Int(meters))m" }
        return String(format: "%.1fkm", meters / 1000.0)
    }
}
