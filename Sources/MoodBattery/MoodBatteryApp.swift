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
        // Free the model on the spot when idle: waiting needs the main actor, which is blocked if terminate
        // was called from a main-queue block.
        guard tagging.isBusy else {
            tagging.releaseIdleModel()
            return .terminateNow
        }
        Task {
            await tagging.releaseModel()
            sender.reply(toApplicationShouldTerminate: true)
        }
        return .terminateLater
    }
}
