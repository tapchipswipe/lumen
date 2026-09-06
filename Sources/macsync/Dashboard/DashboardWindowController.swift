import AppKit
import SwiftUI

@MainActor
public final class DashboardWindowController: NSObject, NSWindowDelegate {
    public static let shared = DashboardWindowController()
    private var window: NSWindow?

    public func show() {
        NSApp.setActivationPolicy(.regular)
        if let w = window {
            NSApp.activate(ignoringOtherApps: true)
            w.makeKeyAndOrderFront(nil)
            w.orderFrontRegardless()
            return
        }

        let w = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 960, height: 720),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        w.title = "Lumen Dashboard"
        w.titlebarAppearsTransparent = true
        w.titleVisibility = .hidden
        w.minSize = NSSize(width: 800, height: 600)
        w.isReleasedWhenClosed = false
        w.delegate = self
        w.center()

        let hostingController = NSHostingController(rootView: DashboardView().environmentObject(AppState.shared))
        w.contentViewController = hostingController

        NSApp.activate(ignoringOtherApps: true)
        w.makeKeyAndOrderFront(nil)
        w.orderFrontRegardless()
        self.window = w
    }

    public func hide() {
        window?.orderOut(nil)
    }

    public func toggle() {
        if let w = window, w.isVisible {
            hide()
        } else {
            show()
        }
    }

    public var isVisible: Bool {
        window?.isVisible ?? false
    }

    public func windowWillClose(_ notification: Notification) {
        // Keep window reference alive so it can be re-opened instantly
    }
}
