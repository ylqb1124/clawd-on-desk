import AppKit
import SwiftUI

class PetWindowController: NSWindowController {

    private static let positionXKey = "ClawdOnDesk.windowPositionX"
    private static let positionYKey = "ClawdOnDesk.windowPositionY"

    convenience init() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 120, height: 140),
            styleMask: .borderless,
            backing: .buffered,
            defer: false
        )

        // Transparent, always-on-top, no shadow
        window.isOpaque = false
        window.backgroundColor = .clear
        window.hasShadow = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .stationary, .ignoresCycle]
        window.isMovableByWindowBackground = true

        // Restore saved position or default to bottom-right
        let defaults = UserDefaults.standard
        if defaults.object(forKey: PetWindowController.positionXKey) != nil {
            let x = defaults.double(forKey: PetWindowController.positionXKey)
            let y = defaults.double(forKey: PetWindowController.positionYKey)
            window.setFrameOrigin(NSPoint(x: x, y: y))
        } else if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let x = screenFrame.maxX - 140
            let y = screenFrame.minY + 20
            window.setFrameOrigin(NSPoint(x: x, y: y))
        }

        let hostingView = NSHostingView(rootView: PetContainerView(viewModel: PetViewModel.shared))
        hostingView.frame = window.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 120, height: 140)
        hostingView.autoresizingMask = [.width, .height]
        window.contentView = hostingView

        self.init(window: window)

        // Save position whenever window moves
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(windowDidMove(_:)),
            name: NSWindow.didMoveNotification,
            object: window
        )
    }

    @objc private func windowDidMove(_ notification: Notification) {
        guard let window = self.window else { return }
        let origin = window.frame.origin
        UserDefaults.standard.set(origin.x, forKey: PetWindowController.positionXKey)
        UserDefaults.standard.set(origin.y, forKey: PetWindowController.positionYKey)
    }

    func toggleMiniMode() {
        guard let window = self.window else { return }
        let newSize = PetViewModel.shared.isMiniMode ? NSSize(width: 120, height: 140) : NSSize(width: 48, height: 48)
        PetViewModel.shared.isMiniMode.toggle()

        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.3
            window.animator().setContentSize(newSize)
        }
    }
}
