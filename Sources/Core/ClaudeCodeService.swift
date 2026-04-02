import Foundation

// MARK: - Protocol

/// Protocol for Claude Code CLI interaction
@preconcurrency protocol ClaudeCodeServiceProtocol: Sendable {
    func startSession(projectPath: String?) async throws -> AsyncThrowingStream<ClaudeEvent, Error>
    func sendMessage(_ message: String) async throws
    func sendToolResult(_ result: ToolResult) async throws
    func stop() async
    /// Note: async because it must hop to the actor to read mutable state.
    func isRunning() async -> Bool
}

// MARK: - Event Types

enum ClaudeEvent: Sendable, Identifiable {
    case connected
    case message(ClaudeMessage)
    case toolCall(ToolCall)
    case toolResult(id: String, result: String)
    case streaming(text: String)
    case done
    case error(Error)

    var id: UUID { UUID() }
}

struct ClaudeMessage: Sendable, Identifiable {
    let id: UUID
    let role: Role
    let content: String
    let timestamp: Date

    enum Role: String, Sendable {
        case user
        case assistant
        case system
    }
}

struct ToolCall: Identifiable {
    let id: String
    let name: String
    /// Stored as [String: String] — complex types JSON-encoded.
    let arguments: [String: String]
}

struct ToolResult: Sendable {
    let toolCallId: String
    let output: String
    let isError: Bool
}

// MARK: - Claude Code Service

/// Concrete implementation wrapping the `claude code` CLI process.
/// Communicates via stdin/stdout using Claude's streaming output format.
actor ClaudeCodeService: ClaudeCodeServiceProtocol {
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var _isRunning = false
    private var continuation: AsyncThrowingStream<ClaudeEvent, Error>.Continuation?

    private let processQueue = DispatchQueue(label: "com.axisblueprint.claudecode.process")

    // MARK: - Session Lifecycle

    func startSession(projectPath: String?) async throws -> AsyncThrowingStream<ClaudeEvent, Error> {
        let stream = AsyncThrowingStream<ClaudeEvent, Error> { continuation in
            self.continuation = continuation

            continuation.onTermination = { @Sendable _ in
                Task { await self.stop() }
            }

            Task {
                do {
                    try await self.launchProcess(projectPath: projectPath)
                    continuation.yield(.connected)
                    await self.readOutput()
                } catch {
                    continuation.yield(.error(error))
                    continuation.finish()
                }
            }
        }

        return stream
    }

    private func launchProcess(projectPath: String?) throws {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/local/bin/claude")

        // Try common installation paths
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude"
        ]

        var found = false
        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                process.executableURL = URL(fileURLWithPath: path)
                found = true
                break
            }
        }

        if !found {
            // Fallback to PATH lookup
            let whichProcess = Process()
            whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
            whichProcess.arguments = ["claude"]
            let pipe = Pipe()
            whichProcess.standardOutput = pipe
            try whichProcess.run()
            whichProcess.waitUntilExit()
            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) {
                process.executableURL = URL(fileURLWithPath: path)
            }
        }

        // Build arguments
        var args = ["code", "--no-input"]
        if let path = projectPath {
            args.append(contentsOf: ["--project", path])
        }
        process.arguments = args

        // Pipes
        let outputPipe = Pipe()
        let inputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardOutput = outputPipe
        process.standardInput = inputPipe
        process.standardError = errorPipe

        self.outputPipe = outputPipe
        self.inputPipe = inputPipe
        self.errorPipe = errorPipe
        self.process = process

        // Handle stderr separately
        errorPipe.fileHandleForReading.readabilityHandler = { handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                Task {
                    await self.handleErrorOutput(text)
                }
            }
        }

        process.terminationHandler = { [weak self] proc in
            Task {
                await self?.handleTermination(status: proc.terminationStatus)
            }
        }

        try process.run()
        self._isRunning = true
    }

    func sendMessage(_ message: String) async throws {
        guard let inputPipe = inputPipe, _isRunning else {
            throw ClaudeCodeError.notRunning
        }

        // Wrap message in Claude's input format
        let payload = """
        \(message)

        """

        if let data = payload.data(using: .utf8) {
            inputPipe.fileHandleForWriting.write(data)
            try inputPipe.fileHandleForWriting.close()
        }
    }

    func sendToolResult(_ result: ToolResult) async throws {
        guard let inputPipe = inputPipe, _isRunning else {
            throw ClaudeCodeError.notRunning
        }

        let payload = """
        {{"type": "tool_result", "tool_use_id": "\(result.toolCallId)", "content": "\(escapeJSON(result.output))", "is_error": \(result.isError)}}

        """

        if let data = payload.data(using: .utf8) {
            try inputPipe.fileHandleForWriting.write(data)
        }
    }

    func stop() async {
        guard _isRunning else { return }

        process?.terminate()
        _isRunning = false

        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.closeFile()
        errorPipe?.fileHandleForReading.closeFile()

        continuation?.finish()
    }

    func isRunning() async -> Bool {
        return _isRunning
    }

    // MARK: - Output Parsing

    private func readOutput() async {
        guard let outputPipe = outputPipe else { return }

        let handle = outputPipe.fileHandleForReading

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.resume()
                    return
                }

                if let text = String(data: data, encoding: .utf8) {
                    Task {
                        await self.parseOutput(text)
                    }
                }
            }
        }
    }

    private func parseOutput(_ text: String) {
        // Claude Code streams in SSE-like format:
        // event: ...
        // data: ...

        let lines = text.components(separatedBy: "\n")
        var currentEvent: String?
        var currentData = ""

        for line in lines {
            if line.starts(with: "event: ") {
                currentEvent = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "data: ") {
                currentData = String(line.dropFirst(6))
            } else if line.isEmpty && currentData.isEmpty == false {
                // End of data block — process
                processEvent(currentEvent, data: currentData)
                currentEvent = nil
                currentData = ""
            } else if line.isEmpty == false {
                // Continuation of data
                currentData += "\n" + line
            }
        }

        if !currentData.isEmpty {
            processEvent(currentEvent, data: currentData)
        }
    }

    private func processEvent(_ event: String?, data: String) {
        // Parse based on event type or content
        if let event = event {
            switch event {
            case "assistant":
                if let content = parseContentFromJSON(data) {
                    let msg = ClaudeMessage(id: UUID(), role: .assistant, content: content, timestamp: Date())
                    continuation?.yield(.message(msg))
                }
            case "tool_call":
                if let toolCall = parseToolCall(data) {
                    continuation?.yield(.toolCall(toolCall))
                }
            case "tool_result":
                // Handled via sendToolResult
                break
            default:
                break
            }
        } else {
            // Raw streaming text
            if let parsed = parseStreamingText(data) {
                for fragment in parsed {
                    continuation?.yield(.streaming(text: fragment))
                }
            } else if !data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                continuation?.yield(.streaming(text: data))
            }
        }
    }

    private func parseContentFromJSON(_ data: String) -> String? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(data.utf8), options: []) as? [String: Any],
              let content = json["content"] as? String else {
            return nil
        }
        return content
    }

    private func parseToolCall(_ data: String) -> ToolCall? {
        guard let json = try? JSONSerialization.jsonObject(with: Data(data.utf8), options: []) as? [String: Any],
              let id = json["id"] as? String,
              let name = json["name"] as? String,
              let rawArgs = json["arguments"] as? [String: Any] else {
            return nil
        }
        // Convert Any values to JSON-encoded strings for storage.
        let args: [String: String] = rawArgs.compactMapValues { value in
            guard let data = try? JSONSerialization.data(withJSONObject: value, options: []),
                  let string = String(data: data, encoding: .utf8) else { return nil }
            return string
        }
        return ToolCall(id: id, name: name, arguments: args)
    }

    private func parseStreamingText(_ data: String) -> [String]? {
        // Try to parse as JSON array of content blocks
        guard let json = try? JSONSerialization.jsonObject(with: Data(data.utf8), options: []) as? [String: Any],
              let content = json["content"] as? [[String: Any]] else {
            return nil
        }

        var fragments: [String] = []
        for block in content {
            if let text = block["text"] as? String {
                fragments.append(text)
            }
        }
        return fragments.isEmpty ? nil : fragments
    }

    private func handleErrorOutput(_ text: String) {
        // Log errors for debugging but don't crash
        print("[ClaudeCode stderr] \(text)")
    }

    private func handleTermination(status: Int32) {
        _isRunning = false

        if status == 0 {
            continuation?.yield(.done)
        } else {
            continuation?.yield(.error(ClaudeCodeError.processExited(status)))
        }
        continuation?.finish()
    }

    private func escapeJSON(_ string: String) -> String {
        string
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\n", with: "\\n")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\t", with: "\\t")
    }
}

// MARK: - Errors

enum ClaudeCodeError: Error, LocalizedError {
    case notRunning
    case processExited(Int32)
    case invalidOutput
    case timeout
    case apiKeyMissing

    var errorDescription: String? {
        switch self {
        case .notRunning:
            return "Claude Code process is not running"
        case .processExited(let status):
            return "Claude Code process exited with status \(status)"
        case .invalidOutput:
            return "Received invalid output from Claude Code"
        case .timeout:
            return "Claude Code request timed out"
        case .apiKeyMissing:
            return "ANTHROPIC_API_KEY is not set"
        }
    }
}

// MARK: - Token Counter

/// Estimates token count using a character-based approximation.
/// For production, replace with cl100k_base encoding match (≈ 0.25 chars/token).
struct TokenCounter {
    /// Estimate tokens using character count × 0.25 (approximates cl100k_base)
    static func estimate(_ text: String) -> Int {
        return Int(Double(text.count) * 0.25)
    }

    /// Estimate tokens for a structured message array
    static func estimate(messages: [ClaudeMessage]) -> Int {
        messages.reduce(0) { sum, msg in
            let roleCount = msg.role.rawValue.count + 3 // overhead for role wrapper
            return sum + estimate(msg.content) + roleCount
        }
    }
}
