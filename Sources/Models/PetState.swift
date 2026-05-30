import Foundation

/// All possible animation states for the pet
enum PetState: String, CaseIterable, Codable {
    case idle           // Connected, nothing happening
    case thinking       // Claude is processing/reasoning
    case typing         // Claude is writing code
    case building       // Running build/compile
    case testing        // Running tests
    case subAgent       // Sub-agent spawned
    case error          // Something went wrong
    case celebrate      // Task completed / milestone
    case sleeping       // No active sessions
    case attention      // Permission needed!
    case searching      // Searching/reading files
    case installing     // Installing dependencies

    var displayName: String {
        switch self {
        case .idle: return "Idle"
        case .thinking: return "Thinking..."
        case .typing: return "Writing code"
        case .building: return "Building"
        case .testing: return "Running tests"
        case .subAgent: return "Sub-agent active"
        case .error: return "Error"
        case .celebrate: return "Done!"
        case .sleeping: return "Sleeping"
        case .attention: return "Needs approval"
        case .searching: return "Searching"
        case .installing: return "Installing"
        }
    }

    var frameCount: Int {
        switch self {
        case .idle: return 4
        case .thinking: return 6
        case .typing: return 4
        case .building: return 6
        case .testing: return 4
        case .subAgent: return 4
        case .error: return 3
        case .celebrate: return 8
        case .sleeping: return 4
        case .attention: return 12
        case .searching: return 4
        case .installing: return 6
        }
    }

    var frameDuration: TimeInterval {
        switch self {
        case .idle: return 0.8
        case .thinking: return 0.3
        case .typing: return 0.15
        case .building: return 0.25
        case .testing: return 0.4
        case .subAgent: return 0.35
        case .error: return 0.5
        case .celebrate: return 0.12
        case .sleeping: return 1.2
        case .attention: return 0.25
        case .searching: return 0.3
        case .installing: return 0.3
        }
    }

    /// Whether this state should pulse/flash the pet
    var isUrgent: Bool {
        self == .attention || self == .error
    }

    /// Adaptive timer interval — low-activity states tick slower to save CPU
    var timerInterval: TimeInterval {
        switch self {
        case .sleeping: return 1.0       // Very slow — just breathing
        case .idle: return 0.6           // Gentle bob, no rush
        case .thinking: return 0.25      // Moderate — orbiting particles
        case .typing: return 0.12        // Fast — keystroke ripples
        case .building: return 0.2       // Gear rotation
        case .testing: return 0.3        // Scan line
        case .subAgent: return 0.25      // Orbiting clones
        case .error: return 0.35         // Shake
        case .celebrate: return 0.1      // Fast — fireworks
        case .attention: return 0.5      // Slow pulse — stays visible for interaction
        case .searching: return 0.25     // Radar sweep
        case .installing: return 0.25    // Progress ring
        }
    }
}

/// Represents a permission request from Claude Code
struct PermissionRequest: Identifiable, Codable {
    let id: UUID
    let sessionId: String
    let tool: String
    let description: String
    let timestamp: Date

    init(sessionId: String, tool: String, description: String) {
        self.id = UUID()
        self.sessionId = sessionId
        self.tool = tool
        self.description = description
        self.timestamp = Date()
    }
}

/// Represents a Claude Code session
struct ClaudeSession: Identifiable, Codable {
    let id: String
    var state: PetState
    var tokenCount: Int
    var lastActivity: Date
    var projectName: String
    var pendingPermission: PermissionRequest?

    var isActive: Bool {
        state != .sleeping
    }
}
