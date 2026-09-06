import Foundation

public final class CrashReporter {
    public static let shared = CrashReporter()

    private var crashLogURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        return docs.appendingPathComponent("crash_log.txt")
    }

    private init() {}

    public func install() {
        NSSetUncaughtExceptionHandler { exception in
            let stack = exception.callStackSymbols.joined(separator: "\n")
            let content = """
            ========================================
            💥 LUMEN MOBILE UNCAUGHT EXCEPTION CRASH
            Date: \(Date())
            Name: \(exception.name.rawValue)
            Reason: \(exception.reason ?? "Unknown")
            ----------------------------------------
            Stack Trace:
            \(stack)
            ========================================
            """
            CrashReporter.shared.writeCrashLog(content)
        }

        signal(SIGABRT) { sig in CrashReporter.handleSignal(sig, name: "SIGABRT") }
        signal(SIGSEGV) { sig in CrashReporter.handleSignal(sig, name: "SIGSEGV") }
        signal(SIGBUS)  { sig in CrashReporter.handleSignal(sig, name: "SIGBUS") }
        signal(SIGILL)  { sig in CrashReporter.handleSignal(sig, name: "SIGILL") }
        signal(SIGFPE)  { sig in CrashReporter.handleSignal(sig, name: "SIGFPE") }
        signal(SIGTRAP) { sig in CrashReporter.handleSignal(sig, name: "SIGTRAP") }
    }

    private static func handleSignal(_ sig: Int32, name: String) {
        let stack = Thread.callStackSymbols.joined(separator: "\n")
        let content = """
        ========================================
        💥 LUMEN MOBILE POSIX SIGNAL CRASH (\(name))
        Date: \(Date())
        Signal Code: \(sig)
        ----------------------------------------
        Stack Trace:
        \(stack)
        ========================================
        """
        CrashReporter.shared.writeCrashLog(content)
        exit(sig)
    }

    public func writeCrashLog(_ text: String) {
        try? text.write(to: crashLogURL, atomically: true, encoding: .utf8)
    }

    public func hasPendingCrashLog() -> Bool {
        FileManager.default.fileExists(atPath: crashLogURL.path)
    }

    public func readCrashLog() -> String? {
        try? String(contentsOf: crashLogURL, encoding: .utf8)
    }

    public func clearCrashLog() {
        try? FileManager.default.removeItem(at: crashLogURL)
    }
}
