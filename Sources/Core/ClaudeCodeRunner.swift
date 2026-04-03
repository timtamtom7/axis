import Foundation

/// ClaudeCodeRunner spawns and manages the `claude code` CLI process.
/// It passes the MCP server address via `--mcp` flag so Claude Code
/// can connect back to Axis's MCP tools.
actor ClaudeCodeRunner {
    // MARK: - Types

    enum RunnerState: Sendable {
        case idle
        case starting
        case running(processID: UUID)
        case stopping
        case error(String)
    }

    // MARK: - State

    private var state: RunnerState = .idle
    private var process: Process?
    private var inputPipe: Pipe?
    private var outputPipe: Pipe?
    private var errorPipe: Pipe?
    private var mcpServer: MCPServer?
    private var sessionID: UUID?
    private var projectPath: String?

    // Event continuation for streaming output
    private var outputContinuation: AsyncThrowingStream<String, Error>.Continuation?

    // MARK: - Configuration

    struct Config: Sendable {
        var claudePath: String = "/usr/local/bin/claude"
        var projectPath: String?
        var sessionID: UUID = UUID()
        var extraArgs: [String] = []

        /// Path to the MCP server socket or stdio marker.
        /// For stdio mode, we pass a special marker that tells claude to connect via stdin/stdout.
        var mcpServerPath: String = "stdio"
    }

    var config: Config = Config()

    // MARK: - Public API

    /// Starts the Claude Code process with MCP support.
    func start() async throws {
        guard case .idle = state else {
            throw RunnerError.alreadyRunning
        }

        state = .starting

        // Create MCP server for this session
        let mcpServer = MCPServer()
        self.mcpServer = mcpServer

        // Find claude executable
        let claudePath = try findClaudeExecutable()
        config.claudePath = claudePath

        // Build arguments
        var args = buildArguments()

        // Create process
        let process = Process()
        process.executableURL = URL(fileURLWithPath: config.claudePath)
        process.arguments = args

        // Setup pipes
        let inputPipe = Pipe()
        let outputPipe = Pipe()
        let errorPipe = Pipe()

        process.standardInput = inputPipe
        process.standardOutput = outputPipe
        process.standardError = errorPipe

        self.process = process
        self.inputPipe = inputPipe
        self.outputPipe = outputPipe
        self.errorPipe = errorPipe

        // Handle stderr
        errorPipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            if !data.isEmpty, let text = String(data: data, encoding: .utf8) {
                Task { await self?.handleError(text) }
            }
        }

        // Handle process termination
        process.terminationHandler = { [weak self] proc in
            Task { await self?.handleTermination(status: proc.terminationStatus) }
        }

        // Start the MCP server
        Task {
            await mcpServer.start()
        }

        // Launch process
        try process.run()

        let sessionID = config.sessionID
        self.sessionID = sessionID
        state = .running(processID: sessionID)

        // Start reading output
        Task {
            await readOutput()
        }
    }

    /// Stops the Claude Code process.
    func stop() async {
        await gracefulStop()
    }

    /// Graceful stop: save context before terminating Claude Code.
    /// Context is saved to disk so no work is lost.
    func gracefulStop() async {
        guard case .running = state else { return }

        state = .stopping

        // Stop-safe: save session context before killing the process
        _ = await SessionManager.shared.prepareGracefulStop()

        // Now terminate
        process?.terminate()

        // Close pipes
        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.closeFile()
        errorPipe?.fileHandleForReading.closeFile()

        // Stop MCP server
        await mcpServer?.stop()

        state = .idle
    }

    /// Force stop: terminate immediately without saving context.
    /// Use only when context has already been saved or is not needed.
    func forceStop() async {
        guard case .running = state else { return }

        state = .stopping
        process?.terminate()

        inputPipe?.fileHandleForWriting.closeFile()
        outputPipe?.fileHandleForReading.closeFile()
        errorPipe?.fileHandleForReading.closeFile()

        await mcpServer?.stop()

        state = .idle
    }

    /// Sends a message to Claude Code's stdin.
    func sendMessage(_ message: String) async throws {
        guard case .running = state else {
            throw RunnerError.notRunning
        }

        guard let inputPipe = inputPipe else {
            throw RunnerError.pipeNotAvailable
        }

        // Format message for Claude Code
        let payload = """
        \(message)

        """

        if let data = payload.data(using: .utf8) {
            try inputPipe.fileHandleForWriting.write(data)
            try inputPipe.fileHandleForWriting.close()
        }
    }

    /// Returns the current state.
    func getState() -> RunnerState {
        return state
    }

    /// Returns the session ID.
    func getSessionID() -> UUID? {
        return sessionID
    }

    /// Stream of output lines from Claude Code.
    func outputStream() -> AsyncThrowingStream<String, Error> {
        return AsyncThrowingStream { continuation in
            self.outputContinuation = continuation
            continuation.onTermination = { @Sendable _ in
                Task { await self.stop() }
            }
        }
    }

    // MARK: - Private

    private func findClaudeExecutable() throws -> String {
        let possiblePaths = [
            "/usr/local/bin/claude",
            "/opt/homebrew/bin/claude",
            "/usr/bin/claude"
        ]

        for path in possiblePaths {
            if FileManager.default.isExecutableFile(atPath: path) {
                return path
            }
        }

        // Fallback: use `which` to find it
        let whichProcess = Process()
        whichProcess.executableURL = URL(fileURLWithPath: "/usr/bin/which")
        whichProcess.arguments = ["claude"]

        let pipe = Pipe()
        whichProcess.standardOutput = pipe

        try whichProcess.run()
        whichProcess.waitUntilExit()

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        if let path = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty {
            return path
        }

        throw RunnerError.claudeNotFound
    }

    private func buildArguments() -> [String] {
        var args = ["code"]

        // Disable headless mode since we're communicating via stdio
        // (Axis provides input via stdin)
        args.append("--no-input")

        // MCP flag — tells Claude to connect to Axis's MCP server
        // For stdio mode, we use "stdio" as the path marker
        args.append(contentsOf: ["--mcp", config.mcpServerPath])

        // Project path
        if let projectPath = config.projectPath ?? projectPath {
            args.append(contentsOf: ["--project", projectPath])
        }

        // Session ID (passed as environment or argument)
        if let sessionID = sessionID {
            args.append(contentsOf: ["--session", sessionID.uuidString])
        }

        // Extra user args
        args.append(contentsOf: config.extraArgs)

        return args
    }

    private func readOutput() async {
        guard let outputPipe = outputPipe else { return }

        let handle = outputPipe.fileHandleForReading

        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            handle.readabilityHandler = { [weak self] handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.resume()
                    return
                }

                if let text = String(data: data, encoding: .utf8) {
                    Task {
                        await self?.processOutput(text)
                    }
                }
            }
        }
    }

    private func processOutput(_ text: String) {
        // Claude Code streams in various formats:
        // 1. SSE-like: "event: ...\ndata: ..."
        // 2. JSON lines
        // 3. Plain text

        let lines = text.components(separatedBy: "\n")
        var currentEvent: String?
        var currentData = ""

        for line in lines {
            if line.starts(with: "event: ") {
                currentEvent = String(line.dropFirst(7)).trimmingCharacters(in: .whitespaces)
            } else if line.starts(with: "data: ") {
                currentData = String(line.dropFirst(6))
            } else if line.isEmpty && !currentData.isEmpty {
                // End of data block
                processEvent(currentEvent, data: currentData)
                currentEvent = nil
                currentData = ""
            } else if !line.isEmpty {
                // Continuation or plain text
                currentData += "\n" + line
            }
        }

        if !currentData.isEmpty {
            processEvent(currentEvent, data: currentData)
        }
    }

    private func processEvent(_ event: String?, data: String) {
        // Forward to continuation
        if !data.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            outputContinuation?.yield(data)
        }
    }

    private func handleError(_ text: String) {
        // Log errors but don't crash
        print("[ClaudeCodeRunner] stderr: \(text)")
    }

    private func handleTermination(status: Int32) {
        let finalState: RunnerState
        if status == 0 {
            finalState = .idle
        } else {
            finalState = .error("Process exited with status \(status)")
        }

        state = finalState
        outputContinuation?.finish()
    }
}

// MARK: - Errors

enum RunnerError: Error, LocalizedError {
    case alreadyRunning
    case notRunning
    case pipeNotAvailable
    case claudeNotFound
    case startupFailed(String)

    var errorDescription: String? {
        switch self {
        case .alreadyRunning:
            return "Claude Code runner is already running"
        case .notRunning:
            return "Claude Code runner is not running"
        case .pipeNotAvailable:
            return "Process pipes are not available"
        case .claudeNotFound:
            return "Could not find claude executable"
        case .startupFailed(let reason):
            return "Startup failed: \(reason)"
        }
    }
}
