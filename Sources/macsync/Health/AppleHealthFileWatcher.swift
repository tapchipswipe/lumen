import AppKit
import Foundation

// MARK: - Apple Health File Watcher
// Monitors ~/Downloads, ~/Desktop, ~/Documents for a new export.xml from iPhone.
// When detected, auto-parses and publishes updated health data — no relaunch needed.

final class AppleHealthFileWatcher {
    static let shared = AppleHealthFileWatcher()

    private var sources: [DispatchSourceFileSystemObject] = []
    private var onUpdate: ((AppleHealthSnapshot) -> Void)?
    private let queue = DispatchQueue(label: "com.lumen.healthwatcher", qos: .background)
    private var lastKnownXMLDate: Date?

    private let watchDirs = [
        NSHomeDirectory() + "/Downloads",
        NSHomeDirectory() + "/Desktop",
        NSHomeDirectory() + "/Documents"
    ]

    private init() {}

    // MARK: - Public

    /// Start watching for Apple Health export files. Calls `onUpdate` whenever a new export is detected.
    func start(onUpdate: @escaping (AppleHealthSnapshot) -> Void) {
        self.onUpdate = onUpdate
        stopAll()

        for dir in watchDirs {
            guard FileManager.default.fileExists(atPath: dir) else { continue }
            let fd = open(dir, O_EVTONLY)
            guard fd >= 0 else { continue }

            let source = DispatchSource.makeFileSystemObjectSource(
                fileDescriptor: fd,
                eventMask: [.write, .rename, .link],
                queue: queue
            )

            source.setEventHandler { [weak self] in
                self?.checkForNewExport()
            }

            source.setCancelHandler { close(fd) }
            source.resume()
            sources.append(source)
        }

        // Also do an immediate scan on start
        queue.async { [weak self] in self?.checkForNewExport() }

        // Poll every 5 minutes as backup in case FSEvents misses something
        schedulePolling()
    }

    func stop() { stopAll() }

    // MARK: - Detection

    private func checkForNewExport() {
        guard let (xmlURL, modDate) = findLatestExportXML() else { return }

        // Only re-parse if the file is newer than what we last saw
        if let last = lastKnownXMLDate, modDate <= last { return }

        lastKnownXMLDate = modDate

        guard let data = try? Data(contentsOf: xmlURL) else { return }
        guard let snap = AppleHealthEngine.parsePublicXMLData(data) else { return }

        DispatchQueue.main.async { [weak self] in
            self?.onUpdate?(snap)
        }
    }

    private func findLatestExportXML() -> (URL, Date)? {
        var best: (URL, Date)? = nil

        for dir in watchDirs {
            let url = URL(fileURLWithPath: dir)
            guard let files = try? FileManager.default.contentsOfDirectory(
                at: url,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
            ) else { continue }

            for file in files {
                let name = file.lastPathComponent.lowercased()
                // Match: export.xml, apple_health_export.xml, health_export.xml, etc.
                guard (name.contains("export") || name.contains("health")) && file.pathExtension.lowercased() == "xml" else { continue }
                guard let attrs = try? file.resourceValues(forKeys: [.contentModificationDateKey]),
                      let modDate = attrs.contentModificationDate else { continue }

                if best == nil || modDate > best!.1 {
                    best = (file, modDate)
                }
            }
        }

        return best
    }

    // MARK: - Polling fallback

    private var pollTimer: Timer?

    private func schedulePolling() {
        DispatchQueue.main.async { [weak self] in
            self?.pollTimer?.invalidate()
            self?.pollTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
                self?.queue.async { self?.checkForNewExport() }
            }
        }
    }

    private func stopAll() {
        sources.forEach { $0.cancel() }
        sources.removeAll()
        pollTimer?.invalidate()
        pollTimer = nil
    }
}

// MARK: - Shortcuts Integration
// Creates and triggers an Apple Shortcut that exports Health data automatically.

enum LumenHealthShortcuts {

    static let shortcutName = "Lumen Health Sync"

    /// Check if the user has the Lumen Health Sync shortcut installed.
    static var isShortcutInstalled: Bool {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
        guard FileManager.default.fileExists(atPath: "/usr/bin/shortcuts") else { return false }
        task.arguments = ["list"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()
        try? task.run()
        task.waitUntilExit()
        let output = String(data: pipe.fileHandleForReading.readDataToEndOfFile(), encoding: .utf8) ?? ""
        return output.lowercased().contains(shortcutName.lowercased())
    }

    /// Trigger the Lumen Health Sync shortcut immediately (background).
    static func runShortcut(completion: @escaping (Bool) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let task = Process()
            task.executableURL = URL(fileURLWithPath: "/usr/bin/shortcuts")
            task.arguments = ["run", shortcutName]
            task.standardOutput = Pipe()
            task.standardError = Pipe()
            do {
                try task.run()
                task.waitUntilExit()
                DispatchQueue.main.async { completion(task.terminationStatus == 0) }
            } catch {
                DispatchQueue.main.async { completion(false) }
            }
        }
    }

    /// Opens Shortcuts.app to let the user create/install the Lumen Health Sync shortcut.
    static func openShortcutsApp() {
        NSWorkspace.shared.open(URL(string: "shortcuts://")!)
    }

    /// Deep-link to Shortcuts gallery or open the app to a specific shortcut URL.
    static func openShortcutCreationGuide() {
        // Open Shortcuts app and guide user to create automation
        let url = URL(string: "shortcuts://create-shortcut")
            ?? URL(string: "x-shortcuts://")
            ?? URL(fileURLWithPath: "/Applications/Shortcuts.app")
        NSWorkspace.shared.open(url)
    }

    /// The shortcut instructions users can follow to set up auto-sync.
    static let setupInstructions = """
    One-time setup in Shortcuts app:
    1. Open Shortcuts → New Shortcut → name it "Lumen Health Sync"
    2. Add action: "Export Health Data" (search "health export")
    3. Add action: "Save File" → set location to Downloads folder
    4. To auto-run daily: Shortcuts → Automation → New → Time of Day → 7:00 AM → Run "Lumen Health Sync"
    """
}
