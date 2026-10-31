import SwiftUI

@main
struct SwingApp: App {
    @NSApplicationDelegateAdaptor private var appDelegate: AppDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(tagging: appDelegate.tagging)
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    /// Shared by every window, so the model loads once, and owned here so quitting can wait for it.
    let tagging = TaggingController()

    func applicationShouldTerminate(_ sender: NSApplication) -> NSApplication.TerminateReply {
        Task {
            await tagging.releaseModel()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
