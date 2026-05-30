import Foundation
import Combine

/// Monitors Claude Code sessions by watching ~/.claude/sessions/ JSON files
/// and inferring fine-grained state from JSONL conversation logs
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

    /// Track previous status per session to detect busy→idle transitions (celebrate)
    private var previousStatus: [String: String] = [:]
    /// Timestamp when celebrate state was triggered, auto-clears after duration
    private var celebrateTimestamp: [String: Date] = [:]
    private let celebrateDuration: TimeInterval = 3.0

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
    /// When status is "busy", parse the JSONL conversation log for fine-grained state
    private func readSessionFiles() {
        let sessionsDir = claudeDirectory.appendingPathComponent("sessions")

        guard let contents = try? FileManager.default.contentsOfDirectory(
            at: sessionsDir,
            includingPropertiesForKeys: nil
        ) else {
            if knownSessions.isEmpty {
                PetViewModel.shared.transitionTo(.sleeping)
            }
            return
        }

        let jsonFiles = contents.filter { $0.pathExtension == "json" }

        if jsonFiles.isEmpty {
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
                try? FileManager.default.removeItem(at: file)
                continue
            }

            activeSessionIds.insert(sessionId)

            let petState = inferPetState(from: state, sessionId: sessionId)
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
            previousStatus.removeValue(forKey: id)
            celebrateTimestamp.removeValue(forKey: id)
        }

        if knownSessions.isEmpty {
            PetViewModel.shared.transitionTo(.sleeping)
        }
    }

    // MARK: - Fine-grained State Inference

    /// Infer pet state by combining session status with JSONL log analysis
    private func inferPetState(from state: SessionStateFile, sessionId: String) -> PetState {
        let status = state.status.lowercased()
        let prevStatus = previousStatus[sessionId]
        previousStatus[sessionId] = status

        // Check if we're in a celebrate cooldown
        if let celebrateTime = celebrateTimestamp[sessionId] {
            if Date().timeIntervalSince(celebrateTime) < celebrateDuration {
                return .celebrate
            } else {
                celebrateTimestamp.removeValue(forKey: sessionId)
            }
        }

        // Detect busy→idle transition → celebrate briefly
        if status == "idle" && prevStatus == "busy" {
            celebrateTimestamp[sessionId] = Date()
            return .celebrate
        }

        // If idle/waiting, just return idle
        if status == "idle" || status == "waiting" {
            return .idle
        }

        // If busy, dig into the JSONL to figure out what's happening
        if status == "busy" {
            if let cwd = state.cwd, let logSessionId = state.sessionId {
                let inferredState = inferStateFromJSONL(cwd: cwd, sessionId: logSessionId)
                if let inferred = inferredState {
                    return inferred
                }
            }
            // Fallback: busy without JSONL info → thinking
            return .thinking
        }

        // Direct status mappings for non-standard statuses (future-proofing)
        switch status {
        case "error", "failed": return .error
        case "permission", "attention": return .attention
        default: return .idle
        }
    }

    /// Parse the tail of the JSONL conversation log to determine current activity
    private func inferStateFromJSONL(cwd: String, sessionId: String) -> PetState? {
        let projectSlug = cwd.replacingOccurrences(of: "/", with: "-")
        let projectsDir = claudeDirectory.appendingPathComponent("projects")
        let jsonlFile = projectsDir
            .appendingPathComponent(projectSlug)
            .appendingPathComponent("\(sessionId).jsonl")

        guard FileManager.default.fileExists(atPath: jsonlFile.path) else {
            return nil
        }

        // Read the last ~8KB of the file to find recent tool_use entries
        guard let tailLines = readTailLines(of: jsonlFile, byteCount: 8192) else {
            return nil
        }

        // Walk lines in reverse to find the most recent tool_use
        for line in tailLines.reversed() {
            guard let data = line.data(using: .utf8),
                  let entry = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                  let message = entry["message"] as? [String: Any],
                  let role = message["role"] as? String,
                  role == "assistant",
                  let content = message["content"] as? [[String: Any]] else {
                continue
            }

            // Find the last tool_use block in this message
            for block in content.reversed() {
                guard let blockType = block["type"] as? String,
                      blockType == "tool_use",
                      let toolName = block["name"] as? String else {
                    continue
                }

                let input = block["input"] as? [String: Any] ?? [:]
                return mapToolUseToPetState(tool: toolName, input: input)
            }
        }

        return nil
    }

    /// Map a tool_use call to a pet state based on tool name and input content
    private func mapToolUseToPetState(tool: String, input: [String: Any]) -> PetState {
        switch tool {
        // Writing/editing files → typing
        case "Write", "Edit", "NotebookEdit":
            return .typing

        // Reading/searching → searching
        case "Read", "Grep", "Glob", "WebSearch", "WebFetch", "LSP":
            return .searching

        // Sub-agents and workflows → subAgent
        case "Agent", "Workflow":
            return .subAgent

        // Bash commands need deeper inspection
        case "Bash":
            let command = (input["command"] as? String ?? "").lowercased()
            return classifyBashCommand(command)

        // Task management tools → thinking (planning)
        case "TaskCreate", "TaskUpdate", "TaskList", "TaskGet":
            return .thinking

        // Unknown tools → thinking
        default:
            return .thinking
        }
    }

    /// Classify a bash command into a pet state
    private func classifyBashCommand(_ command: String) -> PetState {
        // Testing patterns
        let testPatterns = [
            "test", "jest", "pytest", "vitest", "mocha", "karma",
            "swift test", "cargo test", "go test", "npm test",
            "yarn test", "pnpm test", "xcodebuild test",
            "rspec", "phpunit", "unittest"
        ]
        for pattern in testPatterns {
            if command.contains(pattern) { return .testing }
        }

        // Build/compile patterns
        let buildPatterns = [
            "swift build", "cargo build", "go build", "make",
            "cmake", "gcc", "g++", "clang", "javac", "mvn compile",
            "gradle build", "xcodebuild", "npm run build",
            "yarn build", "pnpm build", "tsc", "webpack",
            "vite build", "esbuild", "rollup"
        ]
        for pattern in buildPatterns {
            if command.contains(pattern) { return .building }
        }

        // Install patterns
        let installPatterns = [
            "npm install", "npm i ", "npm ci", "yarn add", "yarn install",
            "pnpm install", "pnpm add", "pip install", "pip3 install",
            "brew install", "apt install", "apt-get install",
            "cargo install", "go install", "gem install",
            "swift package resolve", "swift package update",
            "pod install", "composer install"
        ]
        for pattern in installPatterns {
            if command.contains(pattern) { return .installing }
        }

        // Search patterns (grep, find, etc. in shell)
        let searchPatterns = [
            "grep", "rg ", "ag ", "find ", "fd ", "locate ",
            "ack ", "git log", "git show", "git diff"
        ]
        for pattern in searchPatterns {
            if command.contains(pattern) { return .searching }
        }

        // Default bash → could be anything, treat as building (running something)
        return .building
    }

    /// Read the last N bytes of a file and split into lines
    private func readTailLines(of url: URL, byteCount: Int) -> [String]? {
        guard let fileHandle = try? FileHandle(forReadingFrom: url) else {
            return nil
        }
        defer { try? fileHandle.close() }

        let fileSize = fileHandle.seekToEndOfFile()
        let readStart = fileSize > UInt64(byteCount) ? fileSize - UInt64(byteCount) : 0
        fileHandle.seek(toFileOffset: readStart)

        let data = fileHandle.availableData
        guard let content = String(data: data, encoding: .utf8) else {
            return nil
        }

        let lines = content.components(separatedBy: .newlines)
            .filter { !$0.isEmpty }

        // If we started mid-line (readStart > 0), drop the first partial line
        if readStart > 0 && lines.count > 1 {
            return Array(lines.dropFirst())
        }
        return lines
    }

    private func isProcessAlive(pid: Int) -> Bool {
        return kill(Int32(pid), 0) == 0
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
