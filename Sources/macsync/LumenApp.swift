import SwiftUI

@main
struct LumenApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var appState = AppState.shared

    var body: some Scene {
        MenuBarExtra {
            MenuContentView(appState: appState)
        } label: {
            Image(systemName: "bolt.fill")
        }
        .menuBarExtraStyle(.window)
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        AppState.shared.applicationDidFinishLaunching()
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        Task { @MainActor in
            DashboardWindowController.shared.show()
        }
        return true
    }

    func applicationWillTerminate(_ notification: Notification) {
        AppState.shared.applicationWillTerminate()
    }
}
