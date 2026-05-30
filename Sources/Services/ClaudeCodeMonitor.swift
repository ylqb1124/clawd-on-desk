import Foundation
import Combine

/// Monitors Claude Code sessions by watching ~/.claude/sessions/ JSON files
/// and detecting running claude processes
@MainActor
class ClaudeCodeMonitor: ObservableObject {
    static let shared = ClaudeCodeMonitor()

    private var fileWatcher: DispatchSourceFileSystemObject?
    private var permissionWatcher: DispatchSourceFileSystemObject?
    private var pollTimer: Timer?
    private var permissionPollTimer: Timer?
    private let claudeDirectory: URL
    private let ipcDirectory: URL
    private var knownSessions: [String: ClaudeSession] = [:]

    init() {
        claudeDirectory = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".claude")
        ipcDirectory = claudeDirectory.appendingPathComponent("clawdondesk")
    }

    // MARK: - Public API

    func startMonitoring() {
        // Ensure IPC directory exists
        try? FileManager.default.createDirectory(at: ipcDirectory, withIntermediateDirectories: true)

        // Poll for session changes every 2 seconds
        pollTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollSessions()
            }
        }
        // Initial poll
        pollSessions()

        // Poll for permission requests every 0.5 seconds
        permissionPollTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkPendingPermission()
            }
        }
        RunLoop.main.add(permissionPollTimer!, forMode: .common)

        // Also watch for file system changes
        setupFileWatcher()
        setupPermissionWatcher()
    }

    func stopMonitoring() {
        pollTimer?.invalidate()
        pollTimer = nil
        permissionPollTimer?.invalidate()
        permissionPollTimer = nil
        fileWatcher?.cancel()
        fileWatcher = nil
        permissionWatcher?.cancel()
        permissionWatcher = nil
    }

    func respondToPermission(sessionId: String, approved: Bool) {
        // Find the pending permission and write response
        guard let pending = currentPendingPermission else { return }

        let response = PermissionResponse(
            id: pending.id,
            decision: approved ? "allow" : "deny"
        )

        let responseFile = ipcDirectory.appendingPathComponent("permission_response.json")
        if let data = try? JSONEncoder().encode(response) {
            try? data.write(to: responseFile)
        }

        currentPendingPermission = nil
    }

    // MARK: - Permission IPC

    private var currentPendingPermission: PendingPermissionFile?

    private func checkPendingPermission() {
        let pendingFile = ipcDirectory.appendingPathComponent("pending_permission.json")

        guard FileManager.default.fileExists(atPath: pendingFile.path),
              let data = try? Data(contentsOf: pendingFile),
              let pending = try? JSONDecoder().decode(PendingPermissionFile.self, from: data) else {
            // No pending permission — clear if we had one
            if currentPendingPermission != nil {
                currentPendingPermission = nil
                PetViewModel.shared.clearPermission()
            }
            return
        }

        // Only process if it's a new request
        if currentPendingPermission?.id != pending.id {
            currentPendingPermission = pending

            let request = PermissionRequest(
                sessionId: pending.sessionId,
                tool: pending.tool,
                description: pending.description
            )

            PetViewModel.shared.showPermissionRequest(request)
        }
    }

    private func setupPermissionWatcher() {
        let ipcPath = ipcDirectory.path
        let fd = open(ipcPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.checkPendingPermission()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        permissionWatcher = source
    }

    // MARK: - Session Monitoring

    private func setupFileWatcher() {
        let sessionsPath = claudeDirectory.appendingPathComponent("sessions").path
        let fd = open(sessionsPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .rename, .attrib],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                self?.pollSessions()
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        fileWatcher = source
    }

    private func pollSessions() {
        readSessionFiles()
    }

    /// Read flat JSON files in ~/.claude/sessions/ (e.g. 18413.json)
    /// Format: {"pid":18413, "status":"busy", "cwd":"...", "kind":"interactive", ...}
    private func readSessionFiles() {
        let sessionsDir = claudeDirectory.appendingPathComponent("sessions")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else {
            // No sessions directory or can't read it
            if knownSessions.isEmpty {
                PetViewModel.shared.transitionTo(.sleeping)
            }
            return
        }

        let jsonFiles = contents.filter { $0.pathExtension == "json" }

        if jsonFiles.isEmpty {
            // No session files — sleeping
            knownSessions.removeAll()
            PetViewModel.shared.transitionTo(.sleeping)
            return
        }

        var activeSessionIds = Set<String>()

        for file in jsonFiles {
            guard let data = try? Data(contentsOf: file),
                  let state = try? JSONDecoder().decode(SessionStateFile.self, from: data) else {
                continue
            }

            let sessionId = file.deletingPathExtension().lastPathComponent

            // Check if the process is still alive
            guard isProcessAlive(pid: state.pid) else {
                // Process dead — remove stale session file
                try? FileManager.default.removeItem(at: file)
                continue
            }

            activeSessionIds.insert(sessionId)

            let petState = mapToPetState(state.status)
            let projectName = state.cwd.map { URL(fileURLWithPath: $0).lastPathComponent } ?? "Unknown"

            let session = ClaudeSession(
                id: sessionId,
                state: petState,
                tokenCount: 0,
                lastActivity: Date(timeIntervalSince1970: Double(state.updatedAt ?? state.startedAt) / 1000.0),
                projectName: projectName
            )

            PetViewModel.shared.updateSession(session)
            knownSessions[sessionId] = session
        }

        // Remove sessions that no longer have files
        for id in knownSessions.keys where !activeSessionIds.contains(id) {
            PetViewModel.shared.removeSession(id)
            knownSessions.removeValue(forKey: id)
        }

        // If no active sessions remain, sleep
        if knownSessions.isEmpty {
            PetViewModel.shared.transitionTo(.sleeping)
        }
    }

    private func isProcessAlive(pid: Int) -> Bool {
        // kill(pid, 0) returns 0 if process exists
        return kill(Int32(pid), 0) == 0
    }

    private func mapToPetState(_ status: String) -> PetState {
        switch status.lowercased() {
        case "busy", "thinking", "reasoning": return .thinking
        case "typing", "writing", "editing": return .typing
        case "building", "compiling": return .building
        case "testing": return .testing
        case "searching", "reading": return .searching
        case "installing": return .installing
        case "sub_agent", "subagent": return .subAgent
        case "error", "failed": return .error
        case "done", "complete", "success": return .celebrate
        case "idle", "waiting": return .idle
        case "permission", "attention": return .attention
        default: return .idle
        }
    }
}

// MARK: - File Models

/// Matches the actual ~/.claude/sessions/<pid>.json format
private struct SessionStateFile: Codable {
    let pid: Int
    let sessionId: String?
    let cwd: String?
    let startedAt: Int64
    let status: String
    let updatedAt: Int64?
    let kind: String?
    let entrypoint: String?
    let version: String?
}

/// Matches ~/.claude/clawdondesk/pending_permission.json
struct PendingPermissionFile: Codable {
    let id: String
    let sessionId: String
    let tool: String
    let description: String
    let timestamp: Int
    let toolInput: [String: AnyCodableValue]?

    enum CodingKeys: String, CodingKey {
        case id, sessionId, tool, description, timestamp, toolInput
    }
}

/// Response written to ~/.claude/clawdondesk/permission_response.json
struct PermissionResponse: Codable {
    let id: String
    let decision: String
}

/// Type-erased Codable value for arbitrary JSON
enum AnyCodableValue: Codable {
    case string(String)
    case int(Int)
    case double(Double)
    case bool(Bool)
    case null

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if let v = try? container.decode(String.self) { self = .string(v) }
        else if let v = try? container.decode(Int.self) { self = .int(v) }
        else if let v = try? container.decode(Double.self) { self = .double(v) }
        else if let v = try? container.decode(Bool.self) { self = .bool(v) }
        else { self = .null }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        switch self {
        case .string(let v): try container.encode(v)
        case .int(let v): try container.encode(v)
        case .double(let v): try container.encode(v)
        case .bool(let v): try container.encode(v)
        case .null: try container.encodeNil()
        }
    }
}
