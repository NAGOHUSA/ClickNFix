import SwiftUI

@main
struct ClickNFixApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
        .commands {
            CommandMenu("ClickNFix") {
                Button("Open ClickNFix") {
                    appDelegate.togglePopover(nil)
                }
                .keyboardShortcut("O", modifiers: [.command, .shift])
            }
        }
    }
}
