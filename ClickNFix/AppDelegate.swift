import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let popover = NSPopover()

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        if let button = statusItem.button {
            button.title = "🛠️"
            button.action = #selector(togglePopover(_:))
            button.target = self
        }

        popover.behavior = .transient
        popover.contentSize = NSSize(width: 480, height: 680)
        popover.contentViewController = NSHostingController(rootView: ContentView(viewModel: AppServices.shared.viewModel))

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateStatusIcon),
            name: .issueSeverityDidChange,
            object: nil
        )
    }

    @objc func togglePopover(_ sender: Any?) {
        guard let button = statusItem.button else { return }
        if popover.isShown {
            popover.performClose(sender)
        } else {
            popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
            NSApp.activate(ignoringOtherApps: true)
        }
    }

    @objc private func updateStatusIcon() {
        guard let button = statusItem.button else { return }
        switch AppServices.shared.viewModel.issueSeverity {
        case .none:
            button.title = "🛠️"
        case .warning:
            button.title = "🟡"
        case .critical:
            button.title = "🔴"
        }
    }
}

extension Notification.Name {
    static let issueSeverityDidChange = Notification.Name("issueSeverityDidChange")
}
