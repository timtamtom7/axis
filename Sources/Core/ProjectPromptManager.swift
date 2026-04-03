import Foundation

/// Manages per-project Claude system prompts.
/// Watches for .claude/CLAUDE.md in the current project directory
/// and loads it as the system prompt for Claude Code.
@MainActor
final class ProjectPromptManager: ObservableObject {
    // MARK: - Singleton

    static let shared = ProjectPromptManager()

    // MARK: - Published State

    @Published private(set) var currentProject: ProjectConfig?
    @Published private(set) var isWatching = false

    // MARK: - Types

    struct ProjectConfig: Identifiable, Equatable {
        let id: UUID
        let rootPath: String
        var systemPrompt: String
        var customInstructions: String?
        var lastModified: Date

        /// Path to the project's .claude directory
        var claudeDirPath: String {
            (rootPath as NSString).appendingPathComponent(".claude")
        }

        /// Path to the project's CLAUDE.md
        var claudeMdPath: String {
            (rootPath as NSString).appendingPathComponent(".claude/CLAUDE.md")
        }

        /// Path to the project's .claude/config.json
        var configPath: String {
            (rootPath as NSString).appendingPathComponent(".claude/config.json")
        }

        var hasCustomPrompt: Bool {
            !systemPrompt.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    struct ConfigFile: Codable {
        var systemPrompt: String?
        var customInstructions: String?
        var enabled: Bool?
        var projectName: String?
    }

    // MARK: - Private

    private var currentDirectoryMonitor: DispatchSourceFileSystemObject?
    private var currentProjectPath: String?
    private let fileManager = FileManager.default

    // MARK: - Init

    private init() {}

    // MARK: - Public API

    /// Load project config for the given path (or current working directory).
    /// Returns nil if no .claude directory exists at that path.
    func loadProject(at path: String? = nil) -> ProjectConfig? {
        let projectPath = path ?? fileManager.currentDirectoryPath
        let claudeDir = (projectPath as NSString).appendingPathComponent(".claude")
        let claudeMd = (projectPath as NSString).appendingPathComponent(".claude/CLAUDE.md")
        let configJson = (projectPath as NSString).appendingPathComponent(".claude/config.json")

        guard fileManager.fileExists(atPath: claudeDir) else {
            return nil
        }

        var systemPrompt = ""
        var customInstructions: String?
        var lastModified = Date.distantPast

        // Load CLAUDE.md
        if let mdContent = try? String(contentsOf: URL(fileURLWithPath: claudeMd), encoding: .utf8) {
            systemPrompt = mdContent
            let attrs = try? fileManager.attributesOfItem(atPath: claudeMd)
            lastModified = (attrs?[.modificationDate] as? Date) ?? lastModified
        }

        // Load config.json (overrides CLAUDE.md system prompt if present)
        if let configData = try? Data(contentsOf: URL(fileURLWithPath: configJson)),
           let config = try? JSONDecoder().decode(ConfigFile.self, from: configData) {
            if let promptFromConfig = config.systemPrompt, !promptFromConfig.isEmpty {
                systemPrompt = promptFromConfig
            }
            customInstructions = config.customInstructions
            let attrs = try? fileManager.attributesOfItem(atPath: configJson)
            let configDate = (attrs?[.modificationDate] as? Date) ?? lastModified
            lastModified = max(lastModified, configDate)
        }

        let config = ProjectConfig(
            id: UUID(),
            rootPath: projectPath,
            systemPrompt: systemPrompt,
            customInstructions: customInstructions,
            lastModified: lastModified
        )

        currentProject = config
        currentProjectPath = projectPath
        return config
    }

    /// Start watching the current project directory for changes to .claude/
    func startWatching() {
        guard let project = currentProject else { return }

        stopWatching()

        let fd = open(project.claudeDirPath, O_EVTONLY)
        guard fd >= 0 else { return }

        let source = DispatchSource.makeFileSystemObjectSource(
            fileDescriptor: fd,
            eventMask: [.write, .delete, .rename],
            queue: .main
        )

        source.setEventHandler { [weak self] in
            Task { @MainActor in
                // Reload on any change to .claude directory
                _ = self?.loadProject(at: self?.currentProjectPath)
            }
        }

        source.setCancelHandler {
            close(fd)
        }

        source.resume()
        currentDirectoryMonitor = source
        isWatching = true
    }

    /// Stop watching
    func stopWatching() {
        currentDirectoryMonitor?.cancel()
        currentDirectoryMonitor = nil
        isWatching = false
    }

    /// Save system prompt to the current project's .claude/CLAUDE.md
    func saveSystemPrompt(_ content: String) throws {
        guard let project = currentProject else {
            throw ProjectPromptError.noProjectLoaded
        }

        let dirURL = URL(fileURLWithPath: project.claudeDirPath)
        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let fileURL = URL(fileURLWithPath: project.claudeMdPath)
        try content.write(to: fileURL, atomically: true, encoding: .utf8)

        // Update current config
        currentProject = ProjectConfig(
            id: project.id,
            rootPath: project.rootPath,
            systemPrompt: content,
            customInstructions: project.customInstructions,
            lastModified: Date()
        )
    }

    /// Create a default .claude directory at the given path with starter CLAUDE.md
    func bootstrapProject(at path: String) throws -> ProjectConfig {
        let dirURL = URL(fileURLWithPath: path).appendingPathComponent(".claude")
        let mdURL = dirURL.appendingPathComponent("CLAUDE.md")
        let configURL = dirURL.appendingPathComponent("config.json")

        try fileManager.createDirectory(at: dirURL, withIntermediateDirectories: true)

        let defaultPrompt = """
        # \(path.components(separatedBy: "/").last ?? "Project") — Claude Instructions

        You are working on this project. Read CLAUDE.md for project-specific context.

        ## Project Rules
        - Always verify changes compile before marking done
        - Follow existing code style
        - Write tests for new functionality
        """

        try defaultPrompt.write(to: mdURL, atomically: true, encoding: .utf8)

        let config = ConfigFile(
            systemPrompt: nil,
            customInstructions: nil,
            enabled: true,
            projectName: path.components(separatedBy: "/").last
        )
        let configData = try JSONEncoder().encode(config)
        try configData.write(to: configURL, options: .atomic)

        return loadProject(at: path) ?? ProjectConfig(
            id: UUID(),
            rootPath: path,
            systemPrompt: defaultPrompt,
            customInstructions: nil,
            lastModified: Date()
        )
    }

    /// Returns the effective system prompt for the current project.
    /// Includes base Axis system prompt + project-specific CLAUDE.md content.
    func effectiveSystemPrompt(basePrompt: String) -> String {
        guard let project = currentProject, project.hasCustomPrompt else {
            return basePrompt
        }

        return """
        \(basePrompt)

        ---

        ## Project-Specific Context (\(project.rootPath))

        \(project.systemPrompt)

        \(project.customInstructions ?? "")
        """
    }
}

// MARK: - Errors

enum ProjectPromptError: Error, LocalizedError {
    case noProjectLoaded
    case saveFailed(String)

    var errorDescription: String? {
        switch self {
        case .noProjectLoaded:
            return "No project loaded. Set a project path first."
        case .saveFailed(let reason):
            return "Failed to save system prompt: \(reason)"
        }
    }
}
