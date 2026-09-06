import AppKit
import SwiftUI

@MainActor
public final class StatusBarController: NSObject {
    public static let shared = StatusBarController()

    private var statusItem: NSStatusItem?
    private var popover: NSPopover?

    public func setup() {
        guard statusItem == nil else { return }

        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = item.button {
            let config = NSImage.SymbolConfiguration(pointSize: 13, weight: .semibold)
            let img = NSImage(systemSymbolName: "bolt.fill", accessibilityDescription: "Lumen")?.withSymbolConfiguration(config)
            img?.isTemplate = true
            button.image = img
            button.action = #selector(handleStatusItemClick(_:))
            button.target = self
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        let pop = NSPopover()
        pop.contentSize = NSSize(width: 380, height: 600)
        pop.behavior = .transient
        pop.animates = true
        pop.contentViewController = NSHostingController(rootView: MenuContentView(appState: AppState.shared))

        self.statusItem = item
        self.popover = pop
    }

    @objc private func handleStatusItemClick(_ sender: NSStatusBarButton) {
        guard let popover = popover, let button = statusItem?.button else { return }

        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp {
            // Right click opens Dashboard
            DashboardWindowController.shared.show()
        } else {
            if popover.isShown {
                popover.performClose(sender)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    public func showPopover() {
        guard let popover = popover, let button = statusItem?.button else { return }
        if !popover.isShown {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            popover.contentViewController?.view.window?.makeKey()
        }
    }

    public func hidePopover() {
        popover?.performClose(nil)
    }
}
