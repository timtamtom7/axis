import Foundation
import Combine

/// Manages conversation context persistence and stop-safe Claude Code lifecycle.
/// Before stopping Claude Code, context is saved to disk so no work is lost.
/// Sessions can be resumed from saved state.
@MainActor
final class SessionManager: ObservableObject {
    // MARK: - Singleton

    static let shared = SessionManager()

    // MARK: - Published State

    @Published private(set) var currentSession: Session?
    @Published private(set) var isSaving = false
    @Published private(set) var lastSaveError: String?

    // MARK: - Private

    private let sessionsDirectory: URL
    private let fileManager = FileManager.default

    // MARK: - Types

    struct Session: Identifiable, Codable {
        let id: UUID
        var title: String
        let createdAt: Date
        var updatedAt: Date
        var messages: [Message]
        var claudeSessionID: UUID?
        var projectPath: String?
        var messageCount: Int { messages.count }
        var tokenEstimate: Int

        struct Message: Identifiable, Codable {
            let id: UUID
            let role: Role
            let content: String
            let timestamp: Date
            var tokenEstimate: Int

            enum Role: String, Codable {
                case user
                case assistant
                case system
            }
        }

        /// Write this session to disk
        func save(to url: URL) throws {
            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(self)
            try data.write(to: url, options: .atomic)
        }

        /// Load a session from disk
        static func load(from url: URL) throws -> Session {
            let data = try Data(contentsOf: url)
            let decoder = JSONDecoder()
            decoder.dateDecodingStrategy = .iso8601
            return try decoder.decode(Session.self, from: data)
        }
    }

    // MARK: - Init

    private init() {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let axisDir = appSupport.appendingPathComponent("Axis/Sessions", isDirectory: true)
        self.sessionsDirectory = axisDir

        // Ensure directory exists
        try? fileManager.createDirectory(at: sessionsDirectory, withIntermediateDirectories: true)
    }

    // MARK: - Session Lifecycle

    /// Start a new session
    func startSession(projectPath: String? = nil) -> Session {
        let session = Session(
            id: UUID(),
            title: "New Chat",
            createdAt: Date(),
            updatedAt: Date(),
            messages: [],
            claudeSessionID: nil,
            projectPath: projectPath,
            tokenEstimate: 0
        )
        currentSession = session
        saveCurrentSession()
        return session
    }

    /// Append a message to the current session
    func appendMessage(role: Session.Message.Role, content: String, tokenEstimate: Int = 0) {
        guard var session = currentSession else { return }

        let message = Session.Message(
            id: UUID(),
            role: role,
            content: content,
            timestamp: Date(),
            tokenEstimate: tokenEstimate
        )
        session.messages.append(message)
        session.updatedAt = Date()
        session.tokenEstimate += tokenEstimate

        // Auto-title from first user message
        if session.messages.count == 1 && role == .user {
            let preview = String(content.prefix(50))
            session.title = preview + (content.count > 50 ? "…" : "")
        }

        currentSession = session
    }

    /// Save the current session to disk (async, non-blocking)
    func saveCurrentSession() {
        guard let session = currentSession else { return }

        isSaving = true
        lastSaveError = nil

        Task.detached(priority: .utility) { [weak self] in
            guard let self = self else { return }

            let filename = "\(session.id.uuidString).json"
            let url = self.sessionsDirectory.appendingPathComponent(filename)

            do {
                try session.save(to: url)
                await MainActor.run {
                    self.isSaving = false
                }
            } catch {
                await MainActor.run {
                    self.isSaving = false
                    self.lastSaveError = error.localizedDescription
                }
            }
        }
    }

    /// Load a session from disk by ID
    func loadSession(id: UUID) throws -> Session {
        let url = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        return try Session.load(from: url)
    }

    /// List all saved sessions (most recent first)
    func listSessions() -> [Session] {
        guard let contents = try? fileManager.contentsOfDirectory(
            at: sessionsDirectory,
            includingPropertiesForKeys: [.contentModificationDateKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return contents.compactMap { url -> Session? in
            guard url.pathExtension == "json" else { return nil }
            return try? Session.load(from: url)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    /// Delete a session
    func deleteSession(id: UUID) {
        let url = sessionsDirectory.appendingPathComponent("\(id.uuidString).json")
        try? fileManager.removeItem(at: url)
    }

    // MARK: - Stop-Safe Handoff

    /// Graceful stop: save context before terminating Claude Code.
    /// Returns true if context was saved successfully.
    /// The caller should then call the actual termination.
    func prepareGracefulStop() async -> Bool {
        guard currentSession != nil else { return true }

        // Save session state
        saveCurrentSession()

        // Wait briefly for save to complete (max 2 seconds)
        for _ in 0..<20 {
            if !isSaving { break }
            try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
        }

        // Write a ".halted" marker so resume can detect interrupted sessions
        if let session = currentSession {
            let markerURL = sessionsDirectory.appendingPathComponent("\(session.id.uuidString).halted")
            let marker = HaltedMarker(
                sessionID: session.id,
                timestamp: Date(),
                reason: .userRequested
            )
            if let data = try? JSONEncoder().encode(marker) {
                try? data.write(to: markerURL, options: .atomic)
            }
        }

        return lastSaveError == nil
    }

    /// Resume an interrupted session (one with a .halted marker)
    func detectInterruptedSession() -> Session? {
        let halted = sessionsDirectory.appendingPathExtension("halted")
        guard fileManager.fileExists(atPath: halted.path) else { return nil }

        // Extract session ID from filename
        let idString = halted.deletingPathExtension().lastPathComponent
        guard let id = UUID(uuidString: idString) else { return nil }

        // Remove marker
        try? fileManager.removeItem(at: halted)

        return try? loadSession(id: id)
    }
}

// MARK: - Halted Marker

struct HaltedMarker: Codable {
    let sessionID: UUID
    let timestamp: Date
    let reason: HaltReason

    enum HaltReason: String, Codable {
        case userRequested
        case appQuit
        case crashed
        case timeout
    }
}

// MARK: - GracefulStopError

enum GracefulStopError: Error, LocalizedError {
    case saveFailed(String)
    case timeout

    var errorDescription: String? {
        switch self {
        case .saveFailed(let reason):
            return "Failed to save session before stop: \(reason)"
        case .timeout:
            return "Timed out waiting to save session"
        }
    }
}
