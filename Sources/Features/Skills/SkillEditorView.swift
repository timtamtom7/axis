import SwiftUI

// MARK: - SkillEditorView
//
// Sheet for creating or editing a skill.
// Fields: name, description, type picker, markdown content.
// Live preview pane shows how Claude will see the skill.
// Validation: name and description are required.

struct SkillEditorView: View {

    /// Skill being edited (nil = new skill)
    let skill: Skill?

    /// Called when save is tapped with the final skill.
    let onSave: (Skill) -> Void

    /// Called when cancel is tapped.
    let onCancel: () -> Void

    @State private var name: String = ""
    @State private var description: String = ""
    @State private var selectedType: Skill.SkillType = .mcp
    @State private var content: String = ""
    @State private var showValidation = false

    @Environment(\.dismiss) private var dismiss

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var previewSkill: Skill {
        Skill(
            id: skill?.id ?? UUID(),
            name: name.isEmpty ? "Skill Name" : name,
            description: description.isEmpty ? "Skill description" : description,
            type: selectedType,
            filePath: skill?.filePath ?? "",
            isEnabled: true,
            content: content
        )
    }

    var body: some View {
        VStack(spacing: 0) {
            headerBar

            Divider()
                .background(Color.axisBorder)

            GeometryReader { geometry in
                HStack(spacing: 0) {
                    // Left: form
                    formPanel
                        .frame(width: geometry.size.width * 0.5)

                    Divider()
                        .background(Color.axisBorder)

                    // Right: preview
                    previewPanel
                        .frame(width: geometry.size.width * 0.5)
                }
            }
            .background(Color.axisBackground)
        }
        .frame(minWidth: 700, idealWidth: 800, minHeight: 520, idealHeight: 600)
        .onAppear {
            if let skill = skill {
                name = skill.name
                description = skill.description
                selectedType = skill.type
                content = skill.content.isEmpty ? defaultContent(for: skill.name) : skill.content
            } else {
                content = defaultContent(for: "")
            }
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text(skill == nil ? "New Skill" : "Edit Skill")
                .font(AxisTypography.titleFont)
                .foregroundColor(.axisTextPrimary)

            if showValidation && !isValid {
                Text("— Name and description are required")
                    .font(AxisTypography.captionFont)
                    .foregroundColor(.axisDestructive)
            }

            Spacer()

            Button {
                onCancel()
                dismiss()
            } label: {
                Text("Cancel")
                    .font(AxisTypography.bodyFont)
                    .foregroundColor(.axisTextSecondary)
                    .padding(.horizontal, AxisSpacing.space4)
                    .padding(.vertical, AxisSpacing.space2)
                    .background(Color.axisSurfaceElevated)
                    .cornerRadius(AxisSpacing.radiusSmall)
            }
            .buttonStyle(.plain)

            Button {
                if !isValid {
                    showValidation = true
                    return
                }
                let saved = Skill(
                    id: skill?.id ?? UUID(),
                    name: name.trimmingCharacters(in: .whitespacesAndNewlines),
                    description: description.trimmingCharacters(in: .whitespacesAndNewlines),
                    type: selectedType,
                    filePath: skill?.filePath ?? "",
                    isEnabled: skill?.isEnabled ?? true,
                    content: content
                )
                onSave(saved)
                dismiss()
            } label: {
                Text("Save")
                    .font(AxisTypography.bodyFont)
                    .foregroundColor(.white)
                    .padding(.horizontal, AxisSpacing.space4)
                    .padding(.vertical, AxisSpacing.space2)
                    .background(isValid ? Color.axisAccent : Color.axisBorder)
                    .cornerRadius(AxisSpacing.radiusSmall)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, AxisSpacing.space5)
        .padding(.vertical, AxisSpacing.space4)
        .background(Color.axisSurface)
    }

    // MARK: - Form Panel

    private var formPanel: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space5) {
                fieldGroup("NAME") {
                    TextField("e.g. Code Review, Remember", text: $name)
                        .font(AxisTypography.bodyFont)
                        .textFieldStyle(.plain)
                        .padding(AxisSpacing.space3)
                        .background(Color.axisSurfaceElevated)
                        .cornerRadius(AxisSpacing.radiusMedium)
                        .foregroundColor(.axisTextPrimary)
                }

                fieldGroup("DESCRIPTION") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $description)
                            .font(AxisTypography.bodyFont)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.axisTextPrimary)
                            .frame(minHeight: 72)

                        if description.isEmpty {
                            Text("Brief description of what this skill does")
                                .font(AxisTypography.bodyFont)
                                .foregroundColor(.axisTextTertiary)
                                .padding(.horizontal, 4)
                                .padding(.vertical, 8)
                                .allowsHitTesting(false)
                        }
                    }
                    .padding(AxisSpacing.space3)
                    .background(Color.axisSurfaceElevated)
                    .cornerRadius(AxisSpacing.radiusMedium)
                }

                fieldGroup("TYPE") {
                    HStack(spacing: AxisSpacing.space2) {
                        ForEach(Skill.SkillType.allCases) { type in
                            SkillTypePickerRow(
                                type: type,
                                isSelected: selectedType == type,
                                onSelect: { selectedType = type }
                            )
                        }
                        Spacer()
                    }
                }

                fieldGroup("CONTENT (MARKDOWN)") {
                    ZStack(alignment: .topLeading) {
                        TextEditor(text: $content)
                            .font(AxisTypography.monoFont)
                            .scrollContentBackground(.hidden)
                            .foregroundColor(.axisTextPrimary)
                            .frame(minHeight: 220)

                        if content.isEmpty {
                            Text("""
                            # Skill: [Name]

                            You are a specialized skill. When invoked:

                            1. Understand the request
                            2. Take action
                            3. Present results
                            """)
                            .font(AxisTypography.monoFont)
                            .foregroundColor(.axisTextTertiary)
                            .padding(.horizontal, 4)
                            .padding(.vertical, 8)
                            .allowsHitTesting(false)
                        }
                    }
                    .padding(AxisSpacing.space3)
                    .background(Color.axisSurfaceElevated)
                    .cornerRadius(AxisSpacing.radiusMedium)
                }
            }
            .padding(AxisSpacing.space5)
        }
        .background(Color.axisBackground)
    }

    // MARK: - Preview Panel

    private var previewPanel: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack {
                Text("PREVIEW")
                    .font(AxisTypography.captionFont)
                    .foregroundColor(.axisTextTertiary)
                    .tracking(0.5)

                Spacer()

                Text("How Claude sees this skill")
                    .font(AxisTypography.captionFont)
                    .foregroundColor(.axisTextTertiary)
            }
            .padding(.horizontal, AxisSpacing.space5)
            .padding(.vertical, AxisSpacing.space3)
            .background(Color.axisSurface)

            Divider()
                .background(Color.axisBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.space4) {
                    // Skill card
                    VStack(alignment: .leading, spacing: AxisSpacing.space3) {
                        HStack(spacing: AxisSpacing.space2) {
                            ZStack {
                                Circle()
                                    .fill(previewSkill.type.color.opacity(0.15))
                                    .frame(width: 28, height: 28)

                                Image(systemName: previewSkill.type.icon)
                                    .font(.system(size: 12))
                                    .foregroundColor(previewSkill.type.color)
                            }

                            Text(previewSkill.name)
                                .font(AxisTypography.headlineFont)
                                .foregroundColor(.axisTextPrimary)

                            SkillTypeBadge(type: previewSkill.type)
                        }

                        if !previewSkill.description.isEmpty {
                            Text(previewSkill.description)
                                .font(AxisTypography.bodyFont)
                                .foregroundColor(.axisTextSecondary)
                        }
                    }
                    .padding(AxisSpacing.space4)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.axisSurfaceElevated)
                    .cornerRadius(AxisSpacing.radiusLarge)

                    // Content preview
                    if !content.isEmpty || !name.isEmpty {
                        Text("SKILL CONTENT")
                            .font(AxisTypography.captionFont)
                            .foregroundColor(.axisTextTertiary)
                            .tracking(0.5)

                        Text(content.isEmpty ? defaultContent(for: name) : content)
                            .font(AxisTypography.monoFont)
                            .foregroundColor(.axisTextPrimary)
                            .padding(AxisSpacing.space4)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color.axisSurfaceElevated)
                            .cornerRadius(AxisSpacing.radiusLarge)
                    }
                }
                .padding(AxisSpacing.space5)
            }
        }
    }

    // MARK: - Helpers

    private func fieldGroup(_ label: String, @ViewBuilder content: () -> some View) -> some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space2) {
            Text(label)
                .font(AxisTypography.captionFont)
                .foregroundColor(.axisTextTertiary)
                .tracking(0.5)
            content()
        }
    }

    private func defaultContent(for skillName: String) -> String {
        """
        # Skill: \(skillName.isEmpty ? "[Skill Name]" : skillName)

        You are a specialized assistant skill. When invoked:

        1. Understand the user's request
        2. Take the appropriate action
        3. Present results clearly
        4. Ask if anything else is needed

        Available context: full project and chat history.
        """
    }
}

// MARK: - SkillTypePickerRow

private struct SkillTypePickerRow: View {
    let type: Skill.SkillType
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: AxisSpacing.space2) {
                Image(systemName: type.icon)
                    .font(.system(size: 11))

                Text(type.rawValue)
                    .font(AxisTypography.captionFont)
            }
            .foregroundColor(isSelected ? type.color : .axisTextSecondary)
            .padding(.horizontal, AxisSpacing.space3)
            .padding(.vertical, AxisSpacing.space2)
            .background(isSelected ? type.color.opacity(0.15) : Color.axisSurfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: AxisSpacing.radiusSmall)
                    .stroke(isSelected ? type.color.opacity(0.4) : Color.clear, lineWidth: 1)
            )
            .cornerRadius(AxisSpacing.radiusSmall)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Previews

#Preview("New skill") {
    SkillEditorView(
        skill: nil,
        onSave: { _ in },
        onCancel: {}
    )
}

#Preview("Edit skill") {
    SkillEditorView(
        skill: Skill(
            name: "Code Review",
            description: "Reviews changed files after commits.",
            type: .agent,
            filePath: "",
            content: "# Skill: Code Review\n\nYou are a code reviewer..."
        ),
        onSave: { _ in },
        onCancel: {}
    )
}
