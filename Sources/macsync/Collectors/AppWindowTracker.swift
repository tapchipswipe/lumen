import AppKit
import CoreGraphics

/// Tracks frontmost application switches (NSWorkspace notifications) and
/// frontmost window titles (CGWindowList polling). Window titles require
/// Screen Recording permission on modern macOS; app focus needs nothing.
final class AppWindowTracker {
    private let store = DataStore.shared
    private var workspaceObserver: NSObjectProtocol?
    private var pollTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.lumen.appwindow", qos: .utility)

    private var currentApp: NSRunningApplication?
    private var appFocusStart: Date?
    private var currentWindowTitle: String?
    private var windowFocusStart: Date?

    func start() {
        stop()
        workspaceObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: nil
        ) { [weak self] note in
            guard let app = note.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication else { return }
            self?.queue.async { self?.handleAppSwitch(to: app) }
        }
        // Prime with whatever is frontmost right now.
        if let front = NSWorkspace.shared.frontmostApplication {
            queue.async { [weak self] in self?.handleAppSwitch(to: front) }
        }
        // Poll the frontmost window title every 2 s.
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 2, repeating: 2.0)
        timer.setEventHandler { [weak self] in self?.pollWindowTitle() }
        timer.resume()
        pollTimer = timer
    }

    func stop() {
        if let obs = workspaceObserver {
            NSWorkspace.shared.notificationCenter.removeObserver(obs)
            workspaceObserver = nil
        }
        pollTimer?.cancel()
        pollTimer = nil
        queue.async { [weak self] in self?.flushCurrent(finalDate: Date()) }
    }

    // MARK: - App focus

    private func handleAppSwitch(to app: NSRunningApplication) {
        let now = Date()
        // Close previous app focus session.
        if let prev = currentApp, let start = appFocusStart, prev.processIdentifier != app.processIdentifier {
            let payload = AppFocusPayload(
                appName: prev.localizedName ?? "Unknown",
                bundleID: prev.bundleIdentifier,
                pid: prev.processIdentifier,
                start: start,
                end: now,
                durationSeconds: now.timeIntervalSince(start)
            )
            store.append(TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(payload)))
            closeWindowSession(at: now)
        }
        currentApp = app
        appFocusStart = now
        currentWindowTitle = nil
        windowFocusStart = nil
        pollWindowTitle()
    }

    // MARK: - Window title polling

    private func pollWindowTitle() {
        guard let app = currentApp else { return }
        let title = Self.frontmostWindowTitle(of: app.processIdentifier)
        let now = Date()
        if title != currentWindowTitle {
            closeWindowSession(at: now)
            currentWindowTitle = title
            windowFocusStart = now
        }
    }

    private func closeWindowSession(at date: Date) {
        guard let app = currentApp, let start = windowFocusStart,
              date.timeIntervalSince(start) >= 1 else { return }
        let payload = WindowFocusPayload(
            appName: app.localizedName ?? "Unknown",
            windowTitle: currentWindowTitle,
            start: start,
            end: date,
            durationSeconds: date.timeIntervalSince(start)
        )
        store.append(TrackerEvent(ts: date, kind: .windowFocus, payload: .windowFocus(payload)))
    }

    private func flushCurrent(finalDate: Date) {
        if let app = currentApp, let start = appFocusStart {
            let payload = AppFocusPayload(
                appName: app.localizedName ?? "Unknown",
                bundleID: app.bundleIdentifier,
                pid: app.processIdentifier,
                start: start,
                end: finalDate,
                durationSeconds: finalDate.timeIntervalSince(start)
            )
            store.append(TrackerEvent(ts: finalDate, kind: .appFocus, payload: .appFocus(payload)))
        }
        closeWindowSession(at: finalDate)
        currentApp = nil
        appFocusStart = nil
        currentWindowTitle = nil
        windowFocusStart = nil
    }

    /// Returns the title of the frontmost on-screen window owned by `pid`,
    /// or nil if none / Screen Recording permission is missing.
    static func frontmostWindowTitle(of pid: Int32) -> String? {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let list = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[String: Any]] else { return nil }
        let candidates = list.filter { info in
            guard let owner = info[kCGWindowOwnerPID as String] as? Int32, owner == pid else { return false }
            let layer = info[kCGWindowLayer as String] as? Int ?? -1
            return layer == 0
        }
        // Pick the entry that actually has a title; prefer it over untitled layer-0 windows.
        for info in candidates {
            if let name = info[kCGWindowName as String] as? String, !name.isEmpty {
                return name
            }
        }
        return nil
    }
}
