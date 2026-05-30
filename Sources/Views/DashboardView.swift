import SwiftUI

/// Dashboard showing all active sessions and stats
struct DashboardView: View {
    @ObservedObject var viewModel: PetViewModel
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("ClawdOnDesk Dashboard")
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(12)
            .background(Color(.windowBackgroundColor))

            Divider()

            // Stats bar
            HStack(spacing: 16) {
                StatBadge(icon: "bolt.fill", label: "Sessions", value: "\(viewModel.sessions.count)")
                StatBadge(icon: "number", label: "Tokens", value: formatTokens(viewModel.totalTokens))
                StatBadge(icon: "exclamationmark.triangle.fill", label: "Pending", value: "\(viewModel.pendingPermissions.count)")
            }
            .padding(12)
            .background(Color(.controlBackgroundColor))

            Divider()

            // Session list
            if viewModel.sessions.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "moon.zzz.fill")
                        .font(.system(size: 24))
                        .foregroundColor(.secondary)
                    Text("No active sessions")
                        .font(.system(size: 11))
                        .foregroundColor(.secondary)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(viewModel.sessions) { session in
                            SessionRow(session: session, viewModel: viewModel)
                        }
                    }
                    .padding(12)
                }
            }
        }
        .frame(width: 320, height: 400)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000)
        }
        return "\(count)"
    }
}

// MARK: - Stat Badge
struct StatBadge: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
                Text(value)
                    .font(.system(size: 12, weight: .semibold, design: .monospaced))
            }
            Text(label)
                .font(.system(size: 9))
                .foregroundColor(.secondary)
        }
    }
}

// MARK: - Session Row
struct SessionRow: View {
    let session: ClaudeSession
    @ObservedObject var viewModel: PetViewModel

    var body: some View {
        HStack(spacing: 10) {
            // State indicator
            Circle()
                .fill(colorForState(session.state))
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(session.projectName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                Text(session.state.displayName)
                    .font(.system(size: 9))
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Token count
            Text("\(session.tokenCount)")
                .font(.system(size: 9, design: .monospaced))
                .foregroundColor(.secondary)

            // Permission button if pending
            if let permission = session.pendingPermission {
                HStack(spacing: 4) {
                    Button(action: { viewModel.denyPermission(permission) }) {
                        Image(systemName: "xmark")
                            .font(.system(size: 9))
                            .foregroundColor(.red)
                    }
                    .buttonStyle(.plain)

                    Button(action: { viewModel.approvePermission(permission) }) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 9))
                            .foregroundColor(.green)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(Color(.controlBackgroundColor))
        )
    }

    private func colorForState(_ state: PetState) -> Color {
        switch state {
        case .sleeping: return .gray
        case .idle: return .blue
        case .thinking: return .purple
        case .typing: return .green
        case .building, .installing: return .orange
        case .testing: return .cyan
        case .error: return .red
        case .celebrate: return .yellow
        case .attention: return .red
        case .searching: return .indigo
        case .subAgent: return .mint
        }
    }
}
