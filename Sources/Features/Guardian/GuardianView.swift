import SwiftUI

// MARK: - GuardianView
//
// Guardian status panel — subtle, quiet, like a settings sub-panel.
// Shown as a sheet or sidebar. Contains:
//   - Guardian enabled/disabled toggle
//   - Recent corrections count
//   - Rules list (pattern → reminder)
//   - "Add Rule" button → inline form
//
// Design: minimal, clean. Guardian is present but not intrusive.

struct GuardianView: View {

    @StateObject private var service = GuardianServiceBridge()
    @State private var isGuardianEnabled = true
    @State private var showAddRuleForm = false
    @State private var ruleToEdit: GuardianService.GuardianRule?
    @State private var newRulePattern = ""
    @State private var newRuleReminder = ""

    @Environment(\.dismiss) private var dismiss

    private let sectionHeaderFont = AxisTypography.captionFont
    private let sectionHeaderColor = Color.axisTextTertiary

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()
                .background(Color.axisBorder)

            ScrollView {
                VStack(alignment: .leading, spacing: AxisSpacing.space6) {
                    // Status section
                    statusSection

                    AxisSectionDivider(spacing: AxisSpacing.space6)

                    // Rules section
                    rulesSection

                    // Add rule
                    addRuleSection
                }
                .padding(AxisSpacing.space5)
            }
            .background(Color.axisBackground)
        }
        .background(Color.axisBackground)
        .task {
            await service.load()
        }
    }

    // MARK: - Header

    private var headerBar: some View {
        HStack {
            Text("Guardian")
                .font(AxisTypography.titleFont)
                .foregroundColor(.axisTextPrimary)

            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(.axisTextSecondary)
                    .frame(width: 24, height: 24)
                    .background(Color.axisSurfaceElevated)
                    .clipShape(Circle())
            }
            .buttonStyle(.plain)
            .help("Close")
        }
        .padding(.horizontal, AxisSpacing.space5)
        .padding(.vertical, AxisSpacing.space4)
        .background(Color.axisSurface)
    }

    // MARK: - Status Section

    private var statusSection: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space4) {
            // Toggle row
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Guardian")
                        .font(AxisTypography.headlineFont)
                        .foregroundColor(.axisTextPrimary)

                    Text("Quietly corrects Claude's false modesty")
                        .font(AxisTypography.captionFont)
                        .foregroundColor(.axisTextSecondary)
                }

                Spacer()

                AxisToggle(isOn: $isGuardianEnabled)
                    .frame(width: 140)
            }

            if !service.recentReminders.isEmpty {
                HStack(spacing: AxisSpacing.space2) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 11))
                        .foregroundColor(.axisSuccess)

                    Text("\(service.recentReminders.count) correction\(service.recentReminders.count == 1 ? "" : "s") this session")
                        .font(AxisTypography.captionFont)
                        .foregroundColor(.axisTextSecondary)
                }
            }
        }
    }

    // MARK: - Rules Section

    private var rulesSection: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space3) {
            Text("RULES")
                .font(sectionHeaderFont)
                .foregroundColor(sectionHeaderColor)
                .tracking(0.5)

            if service.rules.isEmpty {
                Text("No rules yet. Add a pattern to get started.")
                    .font(AxisTypography.bodyFont)
                    .foregroundColor(.axisTextTertiary)
                    .padding(.vertical, AxisSpacing.space3)
            } else {
                ForEach(service.rules) { rule in
                    RuleRowView(
                        rule: rule,
                        onToggle: {
                            Task { await service.toggleRule(id: rule.id) }
                        },
                        onEdit: {
                            ruleToEdit = rule
                            newRulePattern = rule.pattern
                            newRuleReminder = rule.reminder
                            showAddRuleForm = true
                        },
                        onDelete: {
                            Task { await service.removeRule(id: rule.id) }
                        }
                    )
                }
            }
        }
    }

    // MARK: - Add Rule Section

    private var addRuleSection: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space3) {
            AxisSectionDivider(spacing: AxisSpacing.space4)

            if showAddRuleForm {
                addRuleForm
            } else {
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        showAddRuleForm = true
                    }
                } label: {
                    HStack(spacing: AxisSpacing.space2) {
                        Image(systemName: "plus.circle.fill")
                            .font(.system(size: 13))
                        Text("Add Rule")
                            .font(AxisTypography.bodyFont)
                    }
                    .foregroundColor(.axisAccent)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var addRuleForm: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space4) {
            Text("PATTERN")
                .font(sectionHeaderFont)
                .foregroundColor(sectionHeaderColor)
                .tracking(0.5)

            TextField("e.g. \"I can't\" or regex", text: $newRulePattern)
                .font(AxisTypography.monoFont)
                .textFieldStyle(.plain)
                .padding(AxisSpacing.space3)
                .background(Color.axisSurfaceElevated)
                .cornerRadius(AxisSpacing.radiusMedium)
                .foregroundColor(.axisTextPrimary)

            Text("REMINDER")
                .font(sectionHeaderFont)
                .foregroundColor(sectionHeaderColor)
                .tracking(0.5)

            TextField("What to remind Claude", text: $newRuleReminder)
                .font(AxisTypography.bodyFont)
                .textFieldStyle(.plain)
                .padding(AxisSpacing.space3)
                .background(Color.axisSurfaceElevated)
                .cornerRadius(AxisSpacing.radiusMedium)
                .foregroundColor(.axisTextPrimary)

            HStack(spacing: AxisSpacing.space3) {
                Button {
                    let rule = GuardianService.GuardianRule(
                        pattern: newRulePattern,
                        reminder: newRuleReminder
                    )
                    Task {
                        await service.addRule(rule)
                    }
                    resetForm()
                } label: {
                    Text("Save Rule")
                        .font(AxisTypography.bodyFont)
                        .foregroundColor(.white)
                        .padding(.horizontal, AxisSpacing.space4)
                        .padding(.vertical, AxisSpacing.space2 + 2)
                        .background(Color.axisAccent)
                        .cornerRadius(AxisSpacing.radiusSmall)
                }
                .buttonStyle(.plain)
                .disabled(newRulePattern.isEmpty || newRuleReminder.isEmpty)

                Button {
                    resetForm()
                } label: {
                    Text("Cancel")
                        .font(AxisTypography.bodyFont)
                        .foregroundColor(.axisTextSecondary)
                        .padding(.horizontal, AxisSpacing.space4)
                        .padding(.vertical, AxisSpacing.space2 + 2)
                        .background(Color.axisSurfaceElevated)
                        .cornerRadius(AxisSpacing.radiusSmall)
                }
                .buttonStyle(.plain)

                Spacer()
            }
        }
        .padding(AxisSpacing.space4)
        .background(Color.axisSurfaceElevated)
        .cornerRadius(AxisSpacing.radiusLarge)
    }

    private func resetForm() {
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            showAddRuleForm = false
            ruleToEdit = nil
            newRulePattern = ""
            newRuleReminder = ""
        }
    }
}

// MARK: - RuleRowView

private struct RuleRowView: View {
    let rule: GuardianService.GuardianRule
    let onToggle: () -> Void
    let onEdit: () -> Void
    let onDelete: () -> Void

    @State private var isHovered = false

    var body: some View {
        HStack(alignment: .top, spacing: AxisSpacing.space3) {
            // Toggle
            Button {
                onToggle()
            } label: {
                Circle()
                    .fill(rule.isEnabled ? Color.axisAccent : Color.axisBorder)
                    .frame(width: 8, height: 8)
                    .padding(.top, 4)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(rule.isEnabled ? "Rule enabled" : "Rule disabled")

            // Content
            VStack(alignment: .leading, spacing: AxisSpacing.space1) {
                Text(rule.pattern)
                    .font(AxisTypography.monoFont)
                    .foregroundColor(rule.isEnabled ? .axisTextPrimary : .axisTextTertiary)
                    .lineLimit(1)

                Text(rule.reminder)
                    .font(AxisTypography.captionFont)
                    .foregroundColor(.axisTextSecondary)
                    .lineLimit(2)

                if rule.matchCount > 0 {
                    Text("\(rule.matchCount) firing\(rule.matchCount == 1 ? "" : "s")")
                        .font(AxisTypography.captionFont)
                        .foregroundColor(.axisTextTertiary)
                }
            }

            Spacer()

            // Actions (visible on hover)
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
            }
        }
        .padding(AxisSpacing.space3)
        .background(isHovered ? Color.axisSurfaceElevated : Color.clear)
        .cornerRadius(AxisSpacing.radiusSmall)
        .onHover { hovering in
            isHovered = hovering
        }
    }
}

// MARK: - Previews

#Preview {
    GuardianView()
        .frame(width: 360, height: 560)
}
