import SwiftUI
import Combine

@MainActor
class PetViewModel: ObservableObject {
    static let shared = PetViewModel()

    // MARK: - Published State
    @Published var currentState: PetState = .sleeping
    @Published var sessions: [ClaudeSession] = []
    @Published var pendingPermissions: [PermissionRequest] = []
    @Published var isMiniMode: Bool = false
    @Published var currentFrame: Int = 0
    @Published var showPermissionBubble: Bool = false
    @Published var showDashboard: Bool = false
    @Published var totalTokens: Int = 0

    // MARK: - Animation
    private var animationTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    /// Tracks when the current state started, for time-based animations
    @Published var stateStartTime: Date = Date()

    init() {
        startAnimationLoop()
    }

    // MARK: - Animation Loop
    private func startAnimationLoop() {
        animationTimer?.invalidate()

        // Use adaptive frame rate based on state activity level
        let interval = currentState.timerInterval
        let timer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                self.currentFrame = (self.currentFrame + 1) % self.currentState.frameCount
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        animationTimer = timer
    }

    func transitionTo(_ newState: PetState) {
        guard newState != currentState else { return }
        currentState = newState
        currentFrame = 0
        stateStartTime = Date()
        startAnimationLoop()

        if newState == .attention {
            showPermissionBubble = true
        }
    }

    // MARK: - Session Management
    func updateSession(_ session: ClaudeSession) {
        if let index = sessions.firstIndex(where: { $0.id == session.id }) {
            sessions[index] = session
        } else {
            sessions.append(session)
        }
        recalculateState()
    }

    func removeSession(_ sessionId: String) {
        sessions.removeAll { $0.id == sessionId }
        recalculateState()
    }

    private func recalculateState() {
        // Priority: attention > error > active states > idle > sleeping
        if sessions.contains(where: { $0.state == .attention }) {
            transitionTo(.attention)
        } else if sessions.contains(where: { $0.state == .error }) {
            transitionTo(.error)
        } else if let activeSession = sessions.first(where: { $0.isActive && $0.state != .idle }) {
            transitionTo(activeSession.state)
        } else if sessions.contains(where: { $0.isActive }) {
            transitionTo(.idle)
        } else {
            transitionTo(.sleeping)
        }

        totalTokens = sessions.reduce(0) { $0 + $1.tokenCount }
        pendingPermissions = sessions.compactMap { $0.pendingPermission }
        showPermissionBubble = !pendingPermissions.isEmpty
    }

    // MARK: - Permission Actions

    func showPermissionRequest(_ request: PermissionRequest) {
        pendingPermissions = [request]
        showPermissionBubble = true
        transitionTo(.attention)
    }

    func clearPermission() {
        pendingPermissions = []
        showPermissionBubble = false
        recalculateState()
    }

    func approvePermission(_ permission: PermissionRequest) {
        ClaudeCodeMonitor.shared.respondToPermission(sessionId: permission.sessionId, approved: true)
        pendingPermissions.removeAll { $0.id == permission.id }
        showPermissionBubble = !pendingPermissions.isEmpty
        recalculateState()
    }

    func denyPermission(_ permission: PermissionRequest) {
        ClaudeCodeMonitor.shared.respondToPermission(sessionId: permission.sessionId, approved: false)
        pendingPermissions.removeAll { $0.id == permission.id }
        showPermissionBubble = !pendingPermissions.isEmpty
        recalculateState()
    }
}
