import AppKit
import SwiftUI

/// Menu bar controller with status icon and dropdown
class StatusBarController {
    private var statusItem: NSStatusItem
    private var petWindowController: PetWindowController

    init(petWindowController: PetWindowController) {
        self.petWindowController = petWindowController
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        setupButton()
        setupMenu()
    }

    private func setupButton() {
        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "sparkle", accessibilityDescription: "ClawdOnDesk")
            button.image?.size = NSSize(width: 16, height: 16)
            button.toolTip = "ClawdOnDesk"
        }
    }

    private func setupMenu() {
        let menu = NSMenu()

        // Status header
        let statusItem = NSMenuItem(title: "ClawdOnDesk", action: nil, keyEquivalent: "")
        statusItem.isEnabled = false
        menu.addItem(statusItem)
        menu.addItem(NSMenuItem.separator())

        // Dashboard
        let dashboardItem = NSMenuItem(title: "Dashboard", action: #selector(showDashboard), keyEquivalent: "d")
        dashboardItem.target = self
        menu.addItem(dashboardItem)

        // Toggle pet visibility
        let toggleItem = NSMenuItem(title: "Show/Hide Pet", action: #selector(togglePet), keyEquivalent: "h")
        toggleItem.target = self
        menu.addItem(toggleItem)

        // Mini mode
        let miniItem = NSMenuItem(title: "Mini Mode", action: #selector(toggleMini), keyEquivalent: "m")
        miniItem.target = self
        menu.addItem(miniItem)

        // Demo all states
        let demoItem = NSMenuItem(title: "Demo All States", action: #selector(demoAllStates), keyEquivalent: "")
        demoItem.target = self
        menu.addItem(demoItem)

        menu.addItem(NSMenuItem.separator())

        // Quit
        let quitItem = NSMenuItem(title: "Quit", action: #selector(quit), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        self.statusItem.menu = menu
    }

    @objc private func showDashboard() {
        Task { @MainActor in
            PetViewModel.shared.showDashboard.toggle()
        }
    }

    @objc private func togglePet() {
        if petWindowController.window?.isVisible == true {
            petWindowController.window?.orderOut(nil)
        } else {
            petWindowController.showWindow(nil)
        }
    }

    @objc private func toggleMini() {
        petWindowController.toggleMiniMode()
    }

    @objc private func demoAllStates() {
        Task { @MainActor in
            let states: [PetState] = [.idle, .thinking, .typing, .building, .testing, .installing, .searching, .subAgent, .celebrate, .error, .attention, .sleeping]
            let vm = PetViewModel.shared
            vm.isDemoMode = true
            for (i, state) in states.enumerated() {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 5.0) {
                    vm.transitionTo(state)
                }
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + Double(states.count) * 5.0) {
                vm.isDemoMode = false
            }
        }
    }

    @objc private func quit() {
        NSApplication.shared.terminate(nil)
    }
}
