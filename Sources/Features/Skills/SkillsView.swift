import SwiftUI

// MARK: - SkillType

enum SkillType: String, CaseIterable, Identifiable {
    case mcp = "MCP"
    case agent = "Agent"
    case custom = "Custom"

    var id: String { rawValue }

    var color: Color {
        switch self {
        case .mcp:    return Color(hex: 0x4B9EFF)   // blue
        case .agent:  return Color(hex: 0x7B61FF)  // purple
        case .custom: return Color(hex: 0xF1DDBC)  // gold
        }
    }

    var icon: String {
        switch self {
        case .mcp:    return "puzzlepiece.fill"
        case .agent:  return "cpu"
        case .custom: return "wand.and.stars"
        }
    }
}

// MARK: - Skill

struct SkillRow: Identifiable, Equatable {
    let id: UUID
    var name: String
    var description: String
    var type: SkillType
    var content: String
    var isEnabled: Bool

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: SkillType,
        content: String = "",
        isEnabled: Bool = true
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.content = content
        self.isEnabled = isEnabled
    }

    // Sample skills for previews / empty state
    static let samples: [Skill] = [
        Skill(
            name: "Handoff",
            description: "Transfers entire context to a new chat. Claude names the chat.",
            type: .mcp
        ),
        Skill(
            name: "Remember",
            description: "Semantic search across all saved chats. 'Remember when we talked about X'",
            type: .mcp
        ),
        Skill(
            name: "Context Trim",
            description: "Surgically removes tool call bloat while preserving conversation meaning.",
            type: .mcp
        ),
        Skill(
            name: "Guardian",
            description: "Manages false modesty rules — keeps Claude confident and capable.",
            type: .mcp
        ),
        Skill(
            name: "Code Review",
            description: "Reviews changed files after commits. Posts findings as a chat message.",
            type: .agent
        ),
        Skill(
            name: "Researcher",
            description: "Finds edge cases and missing test coverage in parallel with Code Reviewer.",
            type: .agent
        ),
    ]
}

// MARK: - SkillsView

struct SkillsView: View {

    @State private var skills: [Skill] = []
    @State private var showSkillEditor = false
    @State private var skillToEdit: Skill?
    @State private var searchText = ""

    private let skillsDirectory: URL = {
        FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent(".axisblueprint/skills")
    }()

    private var filteredSkills: [Skill] {
        if searchText.isEmpty {
            return skills
        }
        return skills.filter {
            $0.name.localizedCaseInsensitiveContains(searchText) ||
            $0.description.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()
                .background(Color.axisBorder)

            if skills.isEmpty {
                emptyState
            } else {
                skillList
            }
        }
        .background(Color.axisBackground)
        .sheet(isPresented: $showSkillEditor) {
            SkillEditorView(
                skill: skillToEdit,
                onSave: { skill in
                    saveSkill(skill)
                    showSkillEditor = false
                    skillToEdit = nil
                },
                onCancel: {
                    showSkillEditor = false
                    skillToEdit = nil
                }
            )
        }
        .task {
            await loadSkills()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Skills")
                .font(AxisTypography.titleFont)
                .foregroundColor(.axisTextPrimary)

            Spacer()

            Button {
                skillToEdit = nil
                showSkillEditor = true
            } label: {
                HStack(spacing: AxisSpacing.space2) {
                    Image(systemName: "plus")
                        .font(.system(size: 12, weight: .medium))
                    Text("New")
                        .font(AxisTypography.bodyFont)
                }
                .foregroundColor(.axisAccent)
                .padding(.horizontal, AxisSpacing.space3)
                .padding(.vertical, AxisSpacing.space2)
                .background(Color.axisAccent.opacity(0.12))
                .cornerRadius(AxisSpacing.radiusSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AxisSpacing.space5)
        .padding(.vertical, AxisSpacing.space4)
        .background(Color.axisSurface)
    }

    // MARK: - Skill List

    private var skillList: some View {
        ScrollView {
            LazyVStack(spacing: 1) {
                // Search bar
                searchBar
                    .padding(.horizontal, AxisSpacing.space5)
                    .padding(.top, AxisSpacing.space3)
                    .padding(.bottom, AxisSpacing.space2)

                ForEach(filteredSkills) { skill in
                    SkillRowView(
                        skill: skill,
                        onToggle: {
                            toggleSkill(skill)
                        },
                        onEdit: {
                            skillToEdit = skill
                            showSkillEditor = true
                        },
                        onDelete: {
                            deleteSkill(skill)
                        }
                    )
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private var searchBar: some View {
        HStack(spacing: AxisSpacing.space2) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.axisTextTertiary)

            TextField("Search skills", text: $searchText)
                .font(AxisTypography.bodyFont)
                .textFieldStyle(.plain)
                .foregroundColor(.axisTextPrimary)

            if !searchText.isEmpty {
                Button {
                    searchText = ""
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 12))
                        .foregroundColor(.axisTextTertiary)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, AxisSpacing.space3)
        .padding(.vertical, AxisSpacing.space2 + 2)
        .background(Color.axisSurfaceElevated)
        .cornerRadius(AxisSpacing.radiusMedium)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: AxisSpacing.space5) {
            Spacer()

            // Illustration: stacked gear/skill icons
            ZStack {
                Circle()
                    .fill(Color.axisSurfaceElevated)
                    .frame(width: 80, height: 80)

                Image(systemName: "wand.and.stars")
                    .font(.system(size: 32))
                    .foregroundColor(.axisTextTertiary)
            }

            VStack(spacing: AxisSpacing.space2) {
                Text("Skills extend Claude's abilities")
                    .font(AxisTypography.headlineFont)
                    .foregroundColor(.axisTextPrimary)

                Text("Add skills to automate tasks, manage context,\nand shape how Claude works.")
                    .font(AxisTypography.bodyFont)
                    .foregroundColor(.axisTextSecondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
            }

            Button {
                skillToEdit = nil
                showSkillEditor = true
            } label: {
                HStack(spacing: AxisSpacing.space2) {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .medium))
                    Text("Create a Skill")
                        .font(AxisTypography.bodyFont)
                }
                .foregroundColor(.white)
                .padding(.horizontal, AxisSpacing.space5)
                .padding(.vertical, AxisSpacing.space3)
                .background(Color.axisAccent)
                .cornerRadius(AxisSpacing.radiusSmall)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .frame(maxWidth: .infinity)
        .padding(AxisSpacing.space6)
    }

    // MARK: - Actions

    private func loadSkills() async {
        // Try to load from disk
        let fileManager = FileManager.default

        if fileManager.fileExists(atPath: skillsDirectory.path) {
            do {
                let contents = try fileManager.contentsOfDirectory(
                    at: skillsDirectory,
                    includingPropertiesForKeys: [.contentModificationDateKey],
                    options: [.skipsHiddenFiles]
                )

                var loaded: [Skill] = []
                for url in contents where url.pathExtension == "md" {
                    if let content = try? String(contentsOf: url, encoding: .utf8) {
                        let name = url.deletingPathExtension().lastPathComponent
                        // Heuristic: infer type from path or content
                        let type = inferType(from: content, name: name)
                        let skill = Skill(
                            name: name,
                            description: extractDescription(from: content),
                            type: type,
                            content: content
                        )
                        loaded.append(skill)
                    }
                }
                skills = loaded
            } catch {
                // Fall back to samples
                skills = Skill.samples
            }
        } else {
            // No skills directory yet — use samples for the preview
            skills = Skill.samples
        }
    }

    private func inferType(from content: String, name: String) -> SkillType {
        let lower = content.lowercased()
        if lower.contains("mcp") || lower.contains("tool") {
            return .mcp
        } else if lower.contains("agent") || lower.contains("background") {
            return .agent
        } else {
            return .custom
        }
    }

    private func extractDescription(from content: String) -> String {
        // Try to extract first non-heading paragraph
        let lines = content.components(separatedBy: .newlines)
        for line in lines {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if !trimmed.isEmpty && !trimmed.hasPrefix("#") {
                // Strip markdown
                return trimmed
                    .replacingOccurrences(of: #"\*\*(.+?)\*\*"#, with: "$1", options: .regularExpression)
                    .replacingOccurrences(of: #"\*(.+?)\*"#, with: "$1", options: .regularExpression)
                    .trimmingCharacters(in: .whitespaces)
            }
        }
        return ""
    }

    private func saveSkill(_ skill: Skill) {
        // Update in-memory list
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index] = skill
        } else {
            skills.append(skill)
        }

        // Persist to disk
        let fileManager = FileManager.default
        let fileURL = skillsDirectory.appendingPathComponent("\(skill.name).md")

        do {
            if !fileManager.fileExists(atPath: skillsDirectory.path) {
                try fileManager.createDirectory(at: skillsDirectory, withIntermediateDirectories: true)
            }
            try skill.content.write(to: fileURL, atomically: true, encoding: .utf8)
        } catch {
            print("[SkillsView] Failed to save skill: \(error)")
        }
    }

    private func toggleSkill(_ skill: Skill) {
        if let index = skills.firstIndex(where: { $0.id == skill.id }) {
            skills[index].isEnabled.toggle()
        }
    }

    private func deleteSkill(_ skill: Skill) {
        skills.removeAll { $0.id == skill.id }

        let fileURL = skillsDirectory.appendingPathComponent("\(skill.name).md")
        try? FileManager.default.removeItem(at: fileURL)
    }
}

// MARK: - SkillRowView

private struct SkillRowView: View {
    let skill: Skill
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(spacing: AxisSpacing.space3) {
            // Type icon
            ZStack {
                Circle()
                    .fill(skill.type.color.opacity(0.15))
                    .frame(width: 32, height: 32)

                Image(systemName: skill.type.icon)
                    .font(.system(size: 13))
                    .foregroundColor(skill.type.color)
            }

            // Content
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: AxisSpacing.space2) {
                    Text(skill.name)
                        .font(AxisTypography.headlineFont)
                        .foregroundColor(skill.isEnabled ? .axisTextPrimary : .axisTextTertiary)

                    SkillTypeBadge(type: skill.type)
                }

                if !skill.description.isEmpty {
                    Text(skill.description)
                        .font(AxisTypography.captionFont)
                        .foregroundColor(.axisTextSecondary)
                        .lineLimit(2)
                }
            }

            Spacer()

            // Hover actions
            if isHovered {
                HStack(spacing: AxisSpacing.space2) {
                    Button {
                        onEdit()
                    } label: {
                        Image(systemName: "pencil")
                            .font(.system(size: 11))
                            .foregroundColor(.axisTextSecondary)
                    }
                    .buttonStyle(.plain)

                    Button {
                        onDelete()
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11))
                            .foregroundColor(.axisDestructive)
                    }
                    .buttonStyle(.plain)
                }
            } else {
                AxisToggle(isOn: .constant(skill.isEnabled), label: nil)
                    .frame(width: 52)
                    .onTapGesture {
                        onToggle()
                    }
            }
        }
        .padding(.horizontal, AxisSpacing.space5)
        .padding(.vertical, AxisSpacing.space3)
        .background(isHovered ? Color.axisSurfaceElevated : Color.clear)
        .contentShape(Rectangle())
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - SkillTypeBadge

struct SkillTypeBadge: View {
    let type: SkillType

    var body: some View {
        Text(type.rawValue)
            .font(.system(size: 10, weight: .semibold))
            .foregroundColor(type.color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(type.color.opacity(0.15))
            .cornerRadius(AxisSpacing.radiusSmall)
    }
}

// MARK: - Previews

#Preview("With skills") {
    SkillsView()
        .frame(width: 480, height: 640)
}

#Preview("Empty") {
    SkillsView()
        .frame(width: 480, height: 640)
}
