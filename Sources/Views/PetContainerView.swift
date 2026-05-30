import SwiftUI

/// Main container view for the pet - handles all visual states
struct PetContainerView: View {
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        ZStack {
            // Pet body
            VStack(spacing: 4) {
                PetSpriteView(
                    state: viewModel.currentState,
                    frame: viewModel.currentFrame
                )
                .scaleEffect(viewModel.isMiniMode ? 0.4 : 1.0)
                .transition(.scale.combined(with: .opacity))
                .padding(.bottom, -6)

                if !viewModel.isMiniMode {
                    Text(viewModel.currentState.displayName)
                        .font(.system(size: 11, weight: .medium, design: .rounded))
                        .foregroundColor(.white.opacity(0.85))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.black.opacity(0.35), in: Capsule())
                        .transition(.opacity.combined(with: .scale(scale: 0.8)))
                }
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
