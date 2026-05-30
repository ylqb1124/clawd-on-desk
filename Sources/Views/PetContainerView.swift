import SwiftUI

/// Main container view for the pet - handles all visual states
struct PetContainerView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        ZStack {
            // Pet body
            PetSpriteView(
                state: viewModel.currentState,
                frame: viewModel.currentFrame
            )
            .scaleEffect(viewModel.isMiniMode ? 0.4 : 1.0)
            .transition(.scale.combined(with: .opacity))

            // Permission bubble
            if viewModel.showPermissionBubble, let permission = viewModel.pendingPermissions.first {
                PermissionBubbleView(
                    permission: permission,
                    onApprove: { viewModel.approvePermission(permission) },
                    onDeny: { viewModel.denyPermission(permission) }
                )
                .offset(y: -80)
                .transition(.scale.combined(with: .opacity))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.spring(response: 0.4, dampingFraction: 0.7), value: viewModel.currentState)
        .animation(.easeInOut(duration: 0.3), value: viewModel.showPermissionBubble)
        .animation(.easeInOut(duration: 0.2), value: viewModel.isMiniMode)
        .onTapGesture(count: 2) {
            viewModel.showDashboard.toggle()
        }
        .contextMenu {
            PetContextMenu(viewModel: viewModel)
        }
    }
}

// MARK: - Context Menu
struct PetContextMenu: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        Button("Dashboard") {
            viewModel.showDashboard.toggle()
        }

        Divider()

        Button(viewModel.isMiniMode ? "Normal Size" : "Mini Mode") {
            viewModel.isMiniMode.toggle()
        }

        Divider()

        Button("Quit ClawdOnDesk") {
            NSApplication.shared.terminate(nil)
        }
    }
}
