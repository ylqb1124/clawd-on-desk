import SwiftUI
import AppKit

@main
struct ClawdOnDeskApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var petWindowController: PetWindowController?
    var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Hide dock icon - menu bar only app
        NSApplication.shared.setActivationPolicy(.accessory)

        // Initialize pet window
        petWindowController = PetWindowController()
        petWindowController?.showWindow(nil)

        // Initialize status bar
        statusBarController = StatusBarController(petWindowController: petWindowController!)

        // Start Claude Code monitor
        ClaudeCodeMonitor.shared.startMonitoring()
    }
}
