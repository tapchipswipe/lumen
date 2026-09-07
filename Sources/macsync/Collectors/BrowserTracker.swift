import AppKit
import Foundation

/// Polls the active tab URL + title from Safari and Chrome via AppleScript.
/// Requires Automation (Apple Events) consent, triggered by
/// NSAppleEventsUsageDescription in Info.plist.
final class BrowserTracker {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.lumen.browser", qos: .utility)
    private var timer: DispatchSourceTimer?

    /// Only query the browser if it is currently frontmost — avoids launching
    /// background browsers and keeps noise down.
    private let safariBundleID = "com.apple.Safari"
    private let chromeBundleID = "com.google.Chrome"

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 15, repeating: 15.0)
        timer.setEventHandler { [weak self] in self?.poll() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    private func poll() {
        guard let front = NSWorkspace.shared.frontmostApplication,
              let bundleID = front.bundleIdentifier else { return }

        if bundleID == safariBundleID {
            querySafari()
        } else if bundleID == chromeBundleID {
            queryChrome()
        }
    }

    // MARK: - AppleScript queries

    private func querySafari() {
        let source = """
        tell application "Safari"
            if (count of windows) = 0 then return ""
            tell front window
                if (count of tabs) = 0 then return ""
                set t to current tab
                return (URL of t as text) & "\\n" & (name of t as text)
            end tell
        end tell
        """
        runBrowserQuery(source: source, browser: "Safari")
    }

    private func queryChrome() {
        let source = """
        tell application "Google Chrome"
            if (count of windows) = 0 then return ""
            tell front window
                set t to active tab
                return (URL of t as text) & "\\n" & (title of t as text)
            end tell
        end tell
        """
        runBrowserQuery(source: source, browser: "Chrome")
    }

    private func runBrowserQuery(source: String, browser: String) {
        var errorDict: NSDictionary?
        let script = NSAppleScript(source: source)
        let result = script?.executeAndReturnError(&errorDict)

        let now = Date()
        if let error = errorDict {
            let message = error[NSAppleScript.errorMessage] as? String ?? "Unknown AppleScript error"
            let payload = BrowserActivityPayload(
                browser: browser, url: nil, tabTitle: nil,
                observedAt: now, success: false, errorMessage: message
            )
            store.append(TrackerEvent(ts: now, kind: .browserActivity, payload: .browserActivity(payload)))
            return
        }

        let raw = result?.stringValue ?? ""
        let parts = raw.components(separatedBy: "\n")
        let url = parts.first?.isEmpty == false ? parts.first : nil
        let title = parts.count > 1 && !parts[1].isEmpty ? parts[1] : nil

        guard url != nil || title != nil else { return } // nothing meaningful to log
        let payload = BrowserActivityPayload(
            browser: browser, url: url, tabTitle: title,
            observedAt: now, success: true, errorMessage: nil
        )
        store.append(TrackerEvent(ts: now, kind: .browserActivity, payload: .browserActivity(payload)))
    }
}
