import Foundation

/// SkillRunner discovers, parses, and invokes skills stored as markdown files.
/// Skills live in `~/.axis/skills/*.md` and define natural-language instructions
/// that Claude can invoke by name.
actor SkillRunner {
    // MARK: - Constants

    private let skillsDirectory: URL

    // MARK: - Init

    init(skillsDirectory: URL? = nil) {
        if let dir = skillsDirectory {
            self.skillsDirectory = dir
        } else {
            let home = FileManager.default.homeDirectoryForCurrentUser
            self.skillsDirectory = home.appendingPathComponent(".axis/skills", isDirectory: true)
        }
    }

    // MARK: - Public API

    /// Lists all available skills.
    func listSkills() -> [Skill] {
        ensureSkillsDirectoryExists()

        guard let files = try? FileManager.default.contentsOfDirectory(
            at: skillsDirectory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }

        return files
            .filter { $0.pathExtension == "md" }
            .compactMap { parseSkillMetadata(from: $0) }
            .filter { $0.isEnabled }
            .sorted { $0.name < $1.name }
    }

    /// Invokes a skill by name, returning the parsed result.
    func invokeSkill(name: String) -> SkillResult {
        guard let skill = listSkills().first(where: { $0.name.lowercased() == name.lowercased() }) else {
            return .failure("Skill '\(name)' not found")
        }

        return invokeSkill(skill)
    }

    /// Invokes a skill by Skill object.
    func invokeSkill(_ skill: Skill) -> SkillResult {
        let fileURL = URL(fileURLWithPath: skill.filePath)

        guard let content = try? String(contentsOf: fileURL, encoding: .utf8) else {
            return .failure("Could not read skill file: \(skill.filePath)")
        }

        switch skill.type {
        case .mcp:
            return handleMCPSkill(skill: skill, content: content)
        case .agent:
            return handleAgentSkill(skill: skill, content: content)
        case .custom:
            return handleCustomSkill(skill: skill, content: content)
        }
    }

    /// Parses the raw markdown content of a skill file.
    func parseSkillContent(_ content: String) -> SkillContent {
        return SkillParser.parse(content)
    }

    // MARK: - Private

    private func ensureSkillsDirectoryExists() {
        if !FileManager.default.fileExists(atPath: skillsDirectory.path) {
            try? FileManager.default.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
            installBuiltInSkills()
        }
    }

    private func installBuiltInSkills() {
        let builtins: [(name: String, description: String, type: Skill.SkillType, content: String)] = [
            (
                name: "Handoff",
                description: "Transfer context to a new chat session",
                type: .mcp,
                content: """
                # Skill: Handoff

                You are the Handoff skill. When invoked:

                1. Summarize the current conversation state concisely
                2. Create a new chat session with the summary as system context
                3. Preserve all file paths, decisions, and pending work
                4. Format the handoff as:

                ## Handoff Summary
                **Project:** [project name]
                **Status:** [what was happening]
                **Key Files:** [list of relevant files]
                **Pending:** [what needs to be done next]
                """
            ),
            (
                name: "Remember",
                description: "Search across saved chat history semantically",
                type: .mcp,
                content: """
                # Skill: Remember

                You are the Remember skill. When invoked:

                1. Search through saved chats in ~/.axisblueprint/chats/
                2. Find conversations matching the user's query
                3. Return relevant snippets with chat titles and timestamps
                4. Present as a ranked list of matches

                Usage: "Remember when we talked about [topic]"
                """
            ),
            (
                name: "Context Trim",
                description: "Surgically trim conversation to save context",
                type: .mcp,
                content: """
                # Skill: Context Trim

                You are the Context Trim skill. When invoked:

                1. Identify the bulkiest messages in the conversation (usually old tool calls)
                2. Replace them with concise tombstones that preserve meaning
                3. Target recovering 30-50% of context space
                4. Report what was trimmed and token savings

                Tombstones should say: "This message was trimmed (X tokens saved)"
                """
            ),
            (
                name: "Guardian",
                description: "Reminds Claude about available MCP tools",
                type: .mcp,
                content: """
                # Skill: Guardian

                You are the Guardian skill. When invoked:

                1. Read the guardian rules from ~/.axisblueprint/guardian.md
                2. Check Claude's last message against each rule pattern
                3. If a pattern matches, send a reminder: "You have access to [tool] via MCP — use it directly"
                4. Track reminder count per session (max 3 before stopping)

                Guardian rules format:
                - "Claude says X" → Remind: you have [tool]
                """
            ),
            (
                name: "Code Review",
                description: "Review changed files for bugs and issues",
                type: .agent,
                content: """
                # Skill: Code Review

                You are the Code Review skill. When invoked:

                1. Identify the changed files since the last commit
                2. Read each changed file in full
                3. Analyze for:
                   - Potential bugs (logic errors, nil handling, race conditions)
                   - Style inconsistencies
                   - Security concerns (SQL injection, hardcoded secrets, etc.)
                   - Performance issues
                   - Missing error handling
                4. Present findings as a numbered list with severity (High/Medium/Low)
                5. Include specific line numbers and code snippets for each issue

                Severity guide:
                - High: Will cause crashes, security vulnerabilities
                - Medium: May cause incorrect behavior
                - Low: Style, minor inefficiencies, code smell
                """
            ),
            (
                name: "Researcher",
                description: "Find edge cases and missing test coverage",
                type: .agent,
                content: """
                # Skill: Researcher

                You are the Researcher skill. When invoked:

                1. Identify the core functionality being worked on
                2. Brainstorm edge cases and corner scenarios
                3. Check existing test coverage for these cases
                4. Suggest additional tests that should be written
                5. Look for:
                   - Empty input, nil values
                   - Boundary conditions (0, -1, max values)
                   - Race conditions in concurrent code
                   - API rate limiting and error handling paths
                   - Cross-platform differences (if applicable)

                Present as: "Tests to add: [list with rationale]"
                """
            )
        ]

        for builtin in builtins {
            let filePath = skillsDirectory.appendingPathComponent("\(builtin.name).md")
            if !FileManager.default.fileExists(atPath: filePath.path) {
                try? builtin.content.write(to: filePath, atomically: true, encoding: .utf8)
            }
        }
    }

    private func parseSkillMetadata(from url: URL) -> Skill? {
        guard let content = try? String(contentsOf: url, encoding: .utf8) else {
            return nil
        }

        // Parse first 20 lines for name, description, type
        let lines = content.components(separatedBy: .newlines).prefix(20)

        var name: String?
        var description: String?
        var type: Skill.SkillType = .custom
        var isEnabled = true

        for line in lines {
            let lower = line.lowercased()

            if lower.hasPrefix("# skill:") || lower.hasPrefix("#skill:") {
                name = line
                    .replacingOccurrences(of: "# skill:", with: "")
                    .replacingOccurrences(of: "#skill:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            if lower.hasPrefix("**description:**") || lower.hasPrefix("- description:") {
                description = line
                    .replacingOccurrences(of: "**description:**", with: "")
                    .replacingOccurrences(of: "- description:", with: "")
                    .trimmingCharacters(in: .whitespaces)
            }

            if lower.contains("**type:**") || lower.contains("- type:") {
                if lower.contains(": mcp") || lower.contains(":mcp") {
                    type = .mcp
                } else if lower.contains(": agent") || lower.contains(":agent") {
                    type = .agent
                } else {
                    type = .custom
                }
            }

            if lower.contains("**disabled**") || lower.contains("- disabled") {
                isEnabled = false
            }
        }

        guard let skillName = name else {
            // Use filename as fallback name
            return Skill(
                name: url.deletingPathExtension().lastPathComponent,
                description: description ?? "No description",
                type: type,
                filePath: url.path,
                isEnabled: isEnabled
            )
        }

        return Skill(
            name: skillName,
            description: description ?? "No description",
            type: type,
            filePath: url.path,
            isEnabled: isEnabled
        )
    }

    private func handleMCPSkill(skill: Skill, content: String) -> SkillResult {
        // MCP skills return instructions for what MCP tool to call
        // The actual tool execution happens via MCPServer
        let parsed = parseSkillContent(content)
        return .success(parsed.instructions)
    }

    private func handleAgentSkill(skill: Skill, content: String) -> SkillResult {
        // Agent skills return instructions for spawning a background agent
        let parsed = parseSkillContent(content)
        return .success(parsed.instructions)
    }

    private func handleCustomSkill(skill: Skill, content: String) -> SkillResult {
        // Custom skills just return their full content
        return .success(content)
    }
}

// MARK: - Skill Content

struct SkillContent: Sendable {
    let name: String?
    let description: String?
    let instructions: String
    let metadata: [String: String]
}

// MARK: - Skill Parser

enum SkillParser {
    static func parse(_ content: String) -> SkillContent {
        let lines = content.components(separatedBy: .newlines)
        var name: String?
        var description: String?
        var metadata: [String: String] = [:]

        var inFrontMatter = false
        var frontMatterLines: [String] = []
        var bodyLines: [String] = []
        var pastFrontMatter = false

        for line in lines {
            if line == "---" && !pastFrontMatter {
                if inFrontMatter {
                    pastFrontMatter = true
                    // Parse front matter
                    for fmLine in frontMatterLines {
                        if let colonIdx = fmLine.firstIndex(of: ":") {
                            let key = String(fmLine[..<colonIdx]).trimmingCharacters(in: .whitespaces)
                            let value = String(fmLine[fmLine.index(after: colonIdx)...]).trimmingCharacters(in: .whitespaces)
                            metadata[key] = value

                            if key.lowercased() == "name" { name = value }
                            if key.lowercased() == "description" { description = value }
                        }
                    }
                } else {
                    inFrontMatter = true
                    continue
                }
            }

            if inFrontMatter && !pastFrontMatter {
                frontMatterLines.append(line)
            } else {
                bodyLines.append(line)
            }
        }

        let body = bodyLines.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)

        // Also check for # Skill: header
        if name == nil {
            for line in lines.prefix(10) {
                if line.lowercased().hasPrefix("# skill:") || line.lowercased().hasPrefix("#skill:") {
                    name = line
                        .replacingOccurrences(of: "# Skill:", with: "")
                        .replacingOccurrences(of: "#skill:", with: "")
                        .trimmingCharacters(in: .whitespaces)
                    break
                }
            }
        }

        return SkillContent(
            name: name,
            description: description,
            instructions: body,
            metadata: metadata
        )
    }
}
