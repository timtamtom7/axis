import Foundation

// MARK: - MCP Request Params

/// Parameters passed to an MCP tool call.
struct MCPRequestParams: Codable {
    let name: String?
    let arguments: [String: String]?

    init(name: String? = nil, arguments: [String: String]? = nil) {
        self.name = name
        self.arguments = arguments
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        name = try container.decodeIfPresent(String.self, forKey: .name)
        arguments = try container.decodeIfPresent([String: String].self, forKey: .arguments)
    }

    /// Convert from MCPRequest.MCPRequestParams
    init(from other: MCPRequest.MCPRequestParams) {
        self.name = other.name
        self.arguments = other.arguments
    }

    enum CodingKeys: String, CodingKey {
        case name, arguments
    }
}

/// MCPServer implements the server side of the MCP protocol.
/// Axis acts as an MCP server that Claude Code connects to via `--mcp` flag.
/// Communication is JSON-RPC 2.0 over stdin/stdout.
final class MCPServer: @unchecked Sendable {
    // MARK: - Types

    typealias ToolHandler = (MCPRequestParams) async throws -> MCPResultPayload

    // MARK: - State

    private var tools: [String: ToolHandler] = [:]
    private var isRunning = false
    private var contextManager: ContextManager?
    private var skillRunner: SkillRunner?

    // MARK: - Init

    init() {
        // Built-in tools registered here
    }

    /// Sets the ContextManager for context-aware operations.
    nonisolated func setContextManager(_ cm: ContextManager) {
        // Note: This is a bit awkward since ContextManager is a struct.
        // In practice, MCPServer would hold a reference to the actor that owns ContextManager.
    }

    /// Sets the SkillRunner for skill operations.
    func setSkillRunner(_ sr: SkillRunner) {
        self.skillRunner = sr
    }

    // MARK: - Public API

    /// Starts the MCP server loop — reads JSON-RPC messages from stdin and writes responses to stdout.
    func start() async {
        isRunning = true

        let stdin = FileHandle.standardInput
        let stdout = FileHandle.standardOutput

        while isRunning {
            // Read a line from stdin
            guard let line = try? await readLine(from: stdin) else {
                break
            }

            // Parse and handle
            let response = await handleMessage(line)

            // Write response
            if let response = response {
                let jsonData = try! JSONEncoder().encode(response)
                var jsonString = String(data: jsonData, encoding: .utf8)!
                jsonString += "\n"
                if let data = jsonString.data(using: .utf8) {
                    stdout.write(data)
                }
            }
        }

        isRunning = false
    }

    /// Stops the server loop.
    func stop() {
        isRunning = false
    }

    /// Registers a custom tool handler.
    func registerTool(name: String, handler: @escaping ToolHandler) {
        tools[name] = handler
    }

    /// Lists all registered tools.
    func listTools() -> [MCPTool] {
        return [
            MCPTool(
                name: "axis_read",
                description: "Read file contents with optional line range limits",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "File path to read"),
                        "max_lines": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "number", description: "Maximum lines to return"),
                        "start_line": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "number", description: "Starting line number (1-indexed)")
                    ],
                    required: ["path"]
                )
            ),
            MCPTool(
                name: "axis_write",
                description: "Write content to a file atomically",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "File path to write"),
                        "content": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Content to write")
                    ],
                    required: ["path", "content"]
                )
            ),
            MCPTool(
                name: "axis_edit",
                description: "Targeted edit using old_text/new_text replacement",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "File path to edit"),
                        "old_text": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Exact text to find"),
                        "new_text": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Replacement text")
                    ],
                    required: ["path", "old_text", "new_text"]
                )
            ),
            MCPTool(
                name: "axis_search",
                description: "Grep across project files",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "query": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Search query"),
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Directory path to search in (default: current directory)"),
                        "case_sensitive": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "boolean", description: "Case sensitive search")
                    ],
                    required: ["query"]
                )
            ),
            MCPTool(
                name: "axis_trim_context",
                description: "Surgically trim conversation to save context",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "target_reduction": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "number", description: "Target token reduction")
                    ],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_handoff",
                description: "Create new chat with current context",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "name": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Name for the handoff chat")
                    ],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_notify",
                description: "Send a macOS notification",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "title": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Notification title"),
                        "body": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Notification body")
                    ],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_run_agent",
                description: "Spawn a background agent",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "agent": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Agent name to run"),
                        "task": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Task description")
                    ],
                    required: ["agent"]
                )
            ),
            MCPTool(
                name: "axis_guardian_check",
                description: "Check message against Guardian patterns",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "message": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Claude's message to check")
                    ],
                    required: ["message"]
                )
            ),
            MCPTool(
                name: "axis_skill_list",
                description: "List all available skills",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [:],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_skill_invoke",
                description: "Invoke a skill by name",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "name": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Skill name to invoke")
                    ],
                    required: ["name"]
                )
            ),
            MCPTool(
                name: "axis_git_status",
                description: "Returns current git status for the project",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Directory path (default: current directory)")
                    ],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_git_diff",
                description: "Returns git diff for changed files",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "file": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Specific file to diff"),
                        "staged": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "boolean", description: "Show staged diff"),
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Directory path (default: current directory)")
                    ],
                    required: nil
                )
            ),
            MCPTool(
                name: "axis_git_commit",
                description: "Creates a commit with the given message",
                inputSchema: MCPTool.MCPToolInputSchema(
                    type: "object",
                    properties: [
                        "message": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Commit message"),
                        "all": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "boolean", description: "Stage all changes before committing"),
                        "path": MCPTool.MCPToolInputSchema.MCPToolProperty(type: "string", description: "Directory path (default: current directory)")
                    ],
                    required: ["message"]
                )
            )
        ]
    }

    // MARK: - Message Handling

    private func handleMessage(_ line: String) async -> MCPMessage? {
        guard let data = line.data(using: .utf8) else { return nil }

        do {
            let message = try JSONDecoder().decode(MCPMessage.self, from: data)
            return await processMessage(message)
        } catch {
            // Try to parse as a simple JSON object for tools/list
            if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any] {
                return await handleJSONMessage(json)
            }
            return nil
        }
    }

    private func handleJSONMessage(_ json: [String: Any]) async -> MCPMessage? {
        guard let method = json["method"] as? String else { return nil }

        let idValue = json["id"]
        let id: MCPMessageID
        if let intId = idValue as? Int {
            id = MCPMessageID.integer(intId)
        } else if let stringId = idValue as? String {
            id = MCPMessageID.string(stringId)
        } else {
            id = MCPMessageID.integer(0)
        }

        switch method {
        case "tools/list":
            let tools = listTools()
            let result = tools.map { tool in
                [
                    "name": tool.name,
                    "description": tool.description,
                    "inputSchema": try! JSONSerialization.jsonObject(with: JSONEncoder().encode(tool.inputSchema))
                ] as [String: Any]
            }
            return MCPMessage.response(MCPResponse(id: id, result: MCPResultPayload(content: nil, isError: nil), error: nil))

        case "tools/call":
            guard let params = json["params"] as? [String: Any],
                  let toolName = params["name"] as? String else {
                return MCPMessage.response(MCPResponse(id: id, result: nil, error: MCPErrorPayload(code: -32602, message: "Invalid params", data: nil)))
            }

            let arguments = params["arguments"] as? [String: String] ?? [:]
            let requestParams = MCPRequestParams(name: toolName, arguments: arguments)

            do {
                guard let handler = tools[toolName] else {
                    throw MCPServerError.methodNotFound(toolName)
                }
                let result = try await handler(requestParams)
                return MCPMessage.response(MCPResponse(id: id, result: result, error: nil))
            } catch let error as MCPServerError {
                let (code, message) = errorCodeAndMessage(for: error)
                return MCPMessage.response(MCPResponse(id: id, result: nil, error: MCPErrorPayload(code: code, message: message, data: nil)))
            } catch {
                return MCPMessage.response(MCPResponse(id: id, result: nil, error: MCPErrorPayload(code: -32603, message: error.localizedDescription, data: nil)))
            }

        default:
            return MCPMessage.response(MCPResponse(id: id, result: nil, error: MCPErrorPayload(code: -32601, message: "Method not found: \(method)", data: nil)))
        }
    }

    private func processMessage(_ message: MCPMessage) async -> MCPMessage? {
        switch message {
        case .request(let request):
            return await handleRequest(request)
        case .notification(let notification):
            await handleNotification(notification)
            return nil
        case .response:
            // We don't expect responses as an MCP server
            return nil
        }
    }

    private func handleRequest(_ request: MCPRequest) async -> MCPMessage {
        switch request.method {
        case "tools/list":
            let toolList = listTools()
            let content = toolList.map { tool in
                MCPResultPayload.MCPContentBlock(type: "text", text: "\(tool.name): \(tool.description)")
            }
            return MCPMessage.response(MCPResponse(id: request.id, result: MCPResultPayload(content: content, isError: false), error: nil))

        case "tools/call":
            guard let params = request.params,
                  let toolName = params.name ?? params.arguments?["name"] else {
                return MCPMessage.response(MCPResponse(id: request.id, result: nil, error: MCPErrorPayload(code: -32602, message: "Invalid params", data: nil)))
            }

            do {
                guard let handler = tools[toolName] else {
                    throw MCPServerError.methodNotFound(toolName)
                }
                let result = try await handler(MCPRequestParams(from: params))
                return MCPMessage.response(MCPResponse(id: request.id, result: result, error: nil))
            } catch let error as MCPServerError {
                let (code, message) = errorCodeAndMessage(for: error)
                return MCPMessage.response(MCPResponse(id: request.id, result: nil, error: MCPErrorPayload(code: code, message: message, data: nil)))
            } catch {
                return MCPMessage.response(MCPResponse(id: request.id, result: nil, error: MCPErrorPayload(code: -32603, message: error.localizedDescription, data: nil)))
            }

        default:
            return MCPMessage.response(MCPResponse(id: request.id, result: nil, error: MCPErrorPayload(code: -32601, message: "Method not found: \(request.method)", data: nil)))
        }
    }

    private func handleNotification(_ notification: MCPNotification) async {
        // Handle incoming notifications (e.g., cancellations, progress updates)
        print("[MCPServer] Received notification: \(notification.method)")
    }

    private func errorCodeAndMessage(for error: MCPServerError) -> (Int, String) {
        switch error {
        case .invalidJSONRPC:        return (-32600, error.localizedDescription)
        case .invalidMessageID:      return (-32600, error.localizedDescription)
        case .methodNotFound:       return (-32601, error.localizedDescription)
        case .invalidParams:        return (-32602, error.localizedDescription)
        case .internalError:        return (-32603, error.localizedDescription)
        case .toolExecutionFailed:  return (-32603, error.localizedDescription)
        }
    }

    // MARK: - stdin Reading

    private func readLine(from handle: FileHandle) async throws -> String? {
        return try await withCheckedThrowingContinuation { continuation in
            handle.readabilityHandler = { handle in
                let data = handle.availableData
                if data.isEmpty {
                    handle.readabilityHandler = nil
                    continuation.resume(returning: nil)
                    return
                }
                if let line = String(data: data, encoding: .utf8)?
                    .components(separatedBy: .newlines)
                    .first(where: { !$0.isEmpty }) {
                    handle.readabilityHandler = nil
                    continuation.resume(returning: line)
                }
            }
        }
    }

    // MARK: - Built-in Tool Handlers

    private func registerBuiltInTools() {
        // axis_read — read file with context
        tools["axis_read"] = { [weak self] params in
            guard let path = params.arguments?["path"] ?? params.arguments?["name"] else {
                throw MCPServerError.invalidParams("path required")
            }

            let maxLines = params.arguments?["max_lines"].flatMap { (v: String) -> Int? in Int(v) }
            let startLine = params.arguments?["start_line"].flatMap { (v: String) -> Int? in Int(v) }

            return try await self!.handleRead(path: path, maxLines: maxLines, startLine: startLine)
        }

        // axis_write — write file atomically
        tools["axis_write"] = { [weak self] params in
            guard let path = params.arguments?["path"],
                  let content = params.arguments?["content"] else {
                throw MCPServerError.invalidParams("path and content required")
            }

            return try await self!.handleWrite(path: path, content: content)
        }

        // axis_edit — targeted edit using line ranges
        tools["axis_edit"] = { [weak self] params in
            guard let path = params.arguments?["path"],
                  let oldText = params.arguments?["old_text"],
                  let newText = params.arguments?["new_text"] else {
                throw MCPServerError.invalidParams("path, old_text, new_text required")
            }

            return try await self!.handleEdit(path: path, oldText: oldText, newText: newText)
        }

        // axis_search — grep across project files
        tools["axis_search"] = { [weak self] params in
            guard let query = params.arguments?["query"] else {
                throw MCPServerError.invalidParams("query required")
            }

            let searchPath = params.arguments?["path"] ?? "."
            let caseSensitive = params.arguments?["case_sensitive"] == "true"

            return try await self!.handleSearch(query: query, path: searchPath, caseSensitive: caseSensitive)
        }

        // axis_trim_context — surgical context trimming
        tools["axis_trim_context"] = { [weak self] params in
            return try await self!.handleTrimContext(params: params)
        }

        // axis_handoff — create new chat with current context
        tools["axis_handoff"] = { params in
            return try await MCPServer.handleHandoff(params: params)
        }

        // axis_notify — send macOS notification
        tools["axis_notify"] = { params in
            return try await MCPServer.handleNotify(params: params)
        }

        // axis_run_agent — spawn background agent
        tools["axis_run_agent"] = { params in
            return try await MCPServer.handleRunAgent(params: params)
        }

        // axis_guardian_check — Guardian pattern match
        tools["axis_guardian_check"] = { [weak self] params in
            return try await self!.handleGuardianCheck(params: params)
        }

        // axis_skill_list — list available skills
        tools["axis_skill_list"] = { [weak self] _ in
            return try await self!.handleSkillList()
        }

        // axis_skill_invoke — invoke a skill by name
        tools["axis_skill_invoke"] = { [weak self] params in
            guard let name = params.arguments?["name"] else {
                throw MCPServerError.invalidParams("skill name required")
            }

            return try await self!.handleSkillInvoke(name: name)
        }

        // axis_git_status — returns git status
        tools["axis_git_status"] = { [weak self] params in
            let path = params.arguments?["path"] ?? FileManager.default.currentDirectoryPath
            return try await self!.handleGitStatus(path: path)
        }

        // axis_git_diff — returns git diff
        tools["axis_git_diff"] = { [weak self] params in
            let file = params.arguments?["file"]
            let staged = params.arguments?["staged"] == "true"
            let path = params.arguments?["path"] ?? FileManager.default.currentDirectoryPath
            return try await self!.handleGitDiff(file: file, staged: staged, path: path)
        }

        // axis_git_commit — creates a commit
        tools["axis_git_commit"] = { [weak self] params in
            guard let message = params.arguments?["message"] else {
                throw MCPServerError.invalidParams("message required")
            }
            let all = params.arguments?["all"] == "true"
            let path = params.arguments?["path"] ?? FileManager.default.currentDirectoryPath
            return try await self!.handleGitCommit(message: message, all: all, path: path)
        }
    }

    // MARK: - Tool Handler Implementations

    private func handleRead(path: String, maxLines: Int?, startLine: Int?) async throws -> MCPResultPayload {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw MCPServerError.toolExecutionFailed("File not found: \(path)")
        }

        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            throw MCPServerError.toolExecutionFailed("Could not read file: \(path)")
        }

        var lines = content.components(separatedBy: .newlines)
        let totalLines = lines.count

        // Apply start_line offset (1-indexed)
        if let start = startLine, start > 1 {
            lines = Array(lines.dropFirst(min(start - 1, lines.count)))
        }

        // Apply max_lines limit
        if let max = maxLines {
            lines = Array(lines.prefix(max))
        }

        let truncatedContent = lines.joined(separator: "\n")

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: truncatedContent
                )
            ],
            isError: false
        )
    }

    private func handleWrite(path: String, content: String) async throws -> MCPResultPayload {
        let url = URL(fileURLWithPath: path)

        // Ensure parent directory exists
        let parentDir = url.deletingLastPathComponent()
        if !FileManager.default.fileExists(atPath: parentDir.path) {
            try FileManager.default.createDirectory(at: parentDir, withIntermediateDirectories: true)
        }

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return MCPResultPayload(
                content: [
                    MCPResultPayload.MCPContentBlock(
                        type: "text",
                        text: "Successfully wrote \(content.count) bytes to \(path)"
                    )
                ],
                isError: false
            )
        } catch {
            throw MCPServerError.toolExecutionFailed("Write failed: \(error.localizedDescription)")
        }
    }

    private func handleEdit(path: String, oldText: String, newText: String) async throws -> MCPResultPayload {
        let url = URL(fileURLWithPath: path)

        guard FileManager.default.fileExists(atPath: path) else {
            throw MCPServerError.toolExecutionFailed("File not found: \(path)")
        }

        guard var content = try? String(contentsOf: url, encoding: .utf8) else {
            throw MCPServerError.toolExecutionFailed("Could not read file: \(path)")
        }

        // Find and replace
        if !content.contains(oldText) {
            throw MCPServerError.toolExecutionFailed("old_text not found in file")
        }

        content = content.replacingOccurrences(of: oldText, with: newText)

        do {
            try content.write(to: url, atomically: true, encoding: .utf8)
            return MCPResultPayload(
                content: [
                    MCPResultPayload.MCPContentBlock(
                        type: "text",
                        text: "Successfully edited \(path)"
                    )
                ],
                isError: false
            )
        } catch {
            throw MCPServerError.toolExecutionFailed("Edit failed: \(error.localizedDescription)")
        }
    }

    private nonisolated func handleSearch(query: String, path: String, caseSensitive: Bool) async throws -> MCPResultPayload {
        var searchPath = path
        if searchPath == "." {
            searchPath = FileManager.default.currentDirectoryPath
        }

        let results: [String] = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<[String], Error>) in
            var localResults: [String] = []
            let fileManager = FileManager.default

            guard let enumerator = fileManager.enumerator(
                at: URL(fileURLWithPath: searchPath),
                includingPropertiesForKeys: [.isRegularFileKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continuation.resume(throwing: MCPServerError.toolExecutionFailed("Could not enumerate directory: \(searchPath)"))
                return
            }

            for case let fileURL as URL in enumerator {
                guard let resourceValues = try? fileURL.resourceValues(forKeys: [.isRegularFileKey]),
                      resourceValues.isRegularFile == true else {
                    continue
                }

                let ext = fileURL.pathExtension.lowercased()
                guard ["swift", "md", "json", "yml", "yaml", "txt", "sh", "zsh", "bash", "py", "js", "ts", "tsx", "jsx", "html", "css"].contains(ext) else {
                    continue
                }

                guard let fileContent = try? String(contentsOf: fileURL, encoding: .utf8) else {
                    continue
                }

                let options: String.CompareOptions = caseSensitive ? [] : .caseInsensitive
                if fileContent.range(of: query, options: options) != nil {
                    // Find line numbers with matches
                    let lines = fileContent.components(separatedBy: .newlines)
                    for (idx, line) in lines.enumerated() {
                        if line.range(of: query, options: options) != nil {
                            let truncatedLine = line.trimmingCharacters(in: .whitespaces)
                            if truncatedLine.count > 150 {
                                localResults.append("\(fileURL.path):\(idx + 1): \(truncatedLine.prefix(150))...")
                            } else {
                                localResults.append("\(fileURL.path):\(idx + 1): \(truncatedLine)")
                            }
                        }
                    }
                }
            }
            continuation.resume(returning: localResults)
        }

        let output = results.isEmpty
            ? "No matches found for '\(query)'"
            : results.prefix(100).joined(separator: "\n")

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private func handleTrimContext(params: MCPRequestParams?) async throws -> MCPResultPayload {
        let targetReduction = params?.arguments?["target_reduction"].flatMap { Int($0) }

        let output = """
        Context trim initiated.
        Target reduction: \(targetReduction.map { "\($0) tokens" } ?? "auto")
        Note: Connect to actual message history to perform real trimming.
        """

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private static func handleHandoff(params: MCPRequestParams?) async throws -> MCPResultPayload {
        let chatName = params?.arguments?["name"] ?? "Handoff Chat"

        let output = """
        Handoff created: \(chatName)
        Context has been packaged for transfer to a new chat session.
        User will review and confirm transfer.
        """

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private static func handleNotify(params: MCPRequestParams?) async throws -> MCPResultPayload {
        let title = params?.arguments?["title"] ?? "Axis"
        let body = params?.arguments?["body"] ?? ""

        // In production, this would use UserNotifications framework
        let output = "Notification queued: [\(title)] \(body)"

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private static func handleRunAgent(params: MCPRequestParams?) async throws -> MCPResultPayload {
        let agentName = params?.arguments?["agent"] ?? "unknown"
        let task = params?.arguments?["task"] ?? ""

        let output = """
        Agent '\(agentName)' spawned for task: \(task)
        Agent will run in background and post results when complete.
        """

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private func handleGuardianCheck(params: MCPRequestParams?) async throws -> MCPResultPayload {
        let message = params?.arguments?["message"] ?? ""

        // Read guardian rules
        let home = FileManager.default.homeDirectoryForCurrentUser
        let guardianPath = home.appendingPathComponent(".axisblueprint/guardian.md")

        guard let rulesContent = try? String(contentsOf: guardianPath, encoding: .utf8) else {
            return MCPResultPayload(
                content: [
                    MCPResultPayload.MCPContentBlock(
                        type: "text",
                        text: "Guardian: No rules file found"
                    )
                ],
                isError: false
            )
        }

        // Parse and match rules
        let lowerMessage = message.lowercased()
        var reminders: [String] = []

        let lines = rulesContent.components(separatedBy: .newlines)
        for line in lines {
            guard line.contains("→") || line.contains("->") else { continue }

            let separators = CharacterSet(charactersIn: "→->")
            let parts = line.components(separatedBy: separators)
            guard parts.count >= 2 else { continue }

            let conditionPart = parts[0].trimmingCharacters(in: .whitespaces)
            let reminderPart = parts[1].trimmingCharacters(in: .whitespaces)

            // Extract condition phrase
            let conditionPhrase = conditionPart
                .replacingOccurrences(of: "If Claude says:", with: "")
                .replacingOccurrences(of: "If Claude said:", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .lowercased()
                .trimmingCharacters(in: .whitespaces)

            if !conditionPhrase.isEmpty && lowerMessage.contains(conditionPhrase) {
                // Extract reminder
                let reminder = reminderPart
                    .replacingOccurrences(of: "Remind:", with: "")
                    .replacingOccurrences(of: "Remind:", with: "")
                    .replacingOccurrences(of: "you have ", with: "")
                    .replacingOccurrences(of: "You have ", with: "")
                    .trimmingCharacters(in: .whitespaces)
                reminders.append("Reminder: \(reminder)")
            }
        }

        let output = reminders.isEmpty
            ? "Guardian: No matching rules triggered."
            : reminders.joined(separator: "\n")

        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: output
                )
            ],
            isError: false
        )
    }

    private func handleSkillList() async throws -> MCPResultPayload {
        guard let sr = skillRunner else {
            let defaultRunner = SkillRunner()
            let skills = await defaultRunner.listSkills()

            let output = skills.map { "\($0.name): \($0.description) (\($0.type.rawValue))" }.joined(separator: "\n")
            return MCPResultPayload(
                content: [MCPResultPayload.MCPContentBlock(type: "text", text: output)],
                isError: false
            )
        }

        let skills = await sr.listSkills()
        let output = skills.map { "\($0.name): \($0.description) (\($0.type.rawValue))" }.joined(separator: "\n")
        return MCPResultPayload(
            content: [MCPResultPayload.MCPContentBlock(type: "text", text: output)],
            isError: false
        )
    }

    private func handleSkillInvoke(name: String) async throws -> MCPResultPayload {
        guard let sr = skillRunner else {
            let defaultRunner = SkillRunner()
            let result = await defaultRunner.invokeSkill(name: name)

            return MCPResultPayload(
                content: [
                    MCPResultPayload.MCPContentBlock(
                        type: "text",
                        text: result.success ? result.output : "Error: \(result.error ?? "Unknown error")"
                    )
                ],
                isError: !result.success
            )
        }

        let result = await sr.invokeSkill(name: name)
        return MCPResultPayload(
            content: [
                MCPResultPayload.MCPContentBlock(
                    type: "text",
                    text: result.success ? result.output : "Error: \(result.error ?? "Unknown error")"
                )
            ],
            isError: !result.success
        )
    }

    // MARK: - Git Tool Handlers

    private nonisolated func handleGitStatus(path: String) async throws -> MCPResultPayload {
        return try await withCheckedThrowingContinuation { continuation in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = ["-C", path, "status", "--porcelain"]
            process.environment = ProcessInfo.processInfo.environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""

                // Check if it's a git repo
                if output.contains("fatal: not a git repository") {
                    continuation.resume(throwing: MCPServerError.toolExecutionFailed("Not a git repository"))
                    return
                }

                // Parse porcelain output
                var modified: [String] = []
                var untracked: [String] = []
                var deleted: [String] = []

                let lines = output.components(separatedBy: .newlines).filter { !$0.isEmpty }
                for line in lines {
                    guard line.count >= 3 else { continue }
                    let indexStatus = line.prefix(1)
                    let workTreeStatus = line.dropFirst(1).prefix(1)
                    let fileName = String(line.dropFirst(3))

                    // Staged changes (index status)
                    if indexStatus == "M" {
                        modified.append(fileName)
                    } else if indexStatus == "A" {
                        modified.append(fileName)
                    } else if indexStatus == "D" {
                        deleted.append(fileName)
                    }

                    // Unstaged/untracked changes (work tree status)
                    if workTreeStatus == "M" {
                        if !modified.contains(fileName) {
                            modified.append(fileName)
                        }
                    } else if workTreeStatus == "D" {
                        if !deleted.contains(fileName) {
                            deleted.append(fileName)
                        }
                    } else if indexStatus == "?" && workTreeStatus == "?" {
                        untracked.append(fileName)
                    }
                }

                let result: [String: Any] = [
                    "modified": modified,
                    "untracked": untracked,
                    "deleted": deleted
                ]

                let jsonData = try! JSONSerialization.data(withJSONObject: result)
                let jsonString = String(data: jsonData, encoding: .utf8)!

                continuation.resume(returning: MCPResultPayload(
                    content: [MCPResultPayload.MCPContentBlock(type: "text", text: jsonString)],
                    isError: false
                ))
            } catch {
                continuation.resume(throwing: MCPServerError.toolExecutionFailed("Git failed: \(error.localizedDescription)"))
            }
        }
    }

    private nonisolated func handleGitDiff(file: String?, staged: Bool, path: String) async throws -> MCPResultPayload {
        return try await withCheckedThrowingContinuation { continuation in
            var args = ["-C", path]
            if staged {
                args.append("--cached")
            }
            if let file = file, !file.isEmpty {
                args.append("--")
                args.append(file)
            }
            args.append("diff")

            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            process.arguments = args
            process.environment = ProcessInfo.processInfo.environment

            let outputPipe = Pipe()
            let errorPipe = Pipe()
            process.standardOutput = outputPipe
            process.standardError = errorPipe

            do {
                try process.run()
                process.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                var output = String(data: outputData, encoding: .utf8) ?? ""

                // Check if it's a git repo
                if output.contains("fatal: not a git repository") {
                    continuation.resume(throwing: MCPServerError.toolExecutionFailed("Not a git repository"))
                    return
                }

                // Truncate to 5000 chars
                if output.count > 5000 {
                    output = String(output.prefix(5000)) + "\n... (truncated)"
                }

                continuation.resume(returning: MCPResultPayload(
                    content: [MCPResultPayload.MCPContentBlock(type: "text", text: output)],
                    isError: false
                ))
            } catch {
                continuation.resume(throwing: MCPServerError.toolExecutionFailed("Git diff failed: \(error.localizedDescription)"))
            }
        }
    }

    private nonisolated func handleGitCommit(message: String, all: Bool, path: String) async throws -> MCPResultPayload {
        return try await withCheckedThrowingContinuation { continuation in
            // First check if it's a git repo
            let statusProcess = Process()
            statusProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
            statusProcess.arguments = ["-C", path, "status", "--porcelain"]
            statusProcess.environment = ProcessInfo.processInfo.environment

            let statusPipe = Pipe()
            statusProcess.standardOutput = statusPipe
            statusProcess.standardError = Pipe()

            do {
                try statusProcess.run()
                statusProcess.waitUntilExit()

                let statusData = statusPipe.fileHandleForReading.readDataToEndOfFile()
                let statusOutput = String(data: statusData, encoding: .utf8) ?? ""

                if statusOutput.contains("fatal: not a git repository") {
                    continuation.resume(throwing: MCPServerError.toolExecutionFailed("Not a git repository"))
                    return
                }

                // If --all flag is used, stage all changes first
                if all {
                    let addProcess = Process()
                    addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                    addProcess.arguments = ["-C", path, "add", "-A"]
                    addProcess.environment = ProcessInfo.processInfo.environment

                    try addProcess.run()
                    addProcess.waitUntilExit()
                }

                // Run git commit
                let commitProcess = Process()
                commitProcess.executableURL = URL(fileURLWithPath: "/usr/bin/git")
                commitProcess.arguments = ["-C", path, "commit", "-m", message]
                commitProcess.environment = ProcessInfo.processInfo.environment

                let outputPipe = Pipe()
                let errorPipe = Pipe()
                commitProcess.standardOutput = outputPipe
                commitProcess.standardError = errorPipe

                try commitProcess.run()
                commitProcess.waitUntilExit()

                let outputData = outputPipe.fileHandleForReading.readDataToEndOfFile()
                let errorData = errorPipe.fileHandleForReading.readDataToEndOfFile()
                let output = String(data: outputData, encoding: .utf8) ?? ""
                let errorOutput = String(data: errorData, encoding: .utf8) ?? ""

                // Check for "nothing to commit"
                if output.lowercased().contains("nothing to commit") || errorOutput.lowercased().contains("nothing to commit") {
                    continuation.resume(throwing: MCPServerError.toolExecutionFailed("Nothing to commit"))
                    return
                }

                // Check for failure
                if commitProcess.terminationStatus != 0 {
                    let errorMsg = errorOutput.isEmpty ? output : errorOutput
                    continuation.resume(throwing: MCPServerError.toolExecutionFailed("Git commit failed: \(errorMsg)"))
                    return
                }

                // Parse SHA from output (format: "[branch abc1234] message")
                var sha = ""
                let lines = output.components(separatedBy: .newlines)
                for line in lines {
                    if line.contains("]") {
                        let bracketContent = line.components(separatedBy: "]").first ?? ""
                        let shaPart = bracketContent.replacingOccurrences(of: "[", with: "")
                        // Extract short SHA (first 7 chars after branch name)
                        let parts = shaPart.components(separatedBy: .whitespaces).filter { !$0.isEmpty }
                        if parts.count >= 2 {
                            sha = String(parts[1].prefix(7))
                        }
                        break
                    }
                }

                let result: [String: Any] = [
                    "success": true,
                    "sha": sha,
                    "message": message
                ]

                let jsonData = try! JSONSerialization.data(withJSONObject: result)
                let jsonString = String(data: jsonData, encoding: .utf8)!

                continuation.resume(returning: MCPResultPayload(
                    content: [MCPResultPayload.MCPContentBlock(type: "text", text: jsonString)],
                    isError: false
                ))
            } catch {
                continuation.resume(throwing: MCPServerError.toolExecutionFailed("Git commit failed: \(error.localizedDescription)"))
            }
        }
    }
}


