import SwiftUI

// MARK: - SettingsView
//
// Standard macOS settings pattern: sidebar (section list) on the left,
// content panel on the right. All settings use @AppStorage via SettingsStore.

struct SettingsView: View {
    @StateObject private var settings = SettingsStore()
    @State private var selectedSection: Section = .general
    @State private var showClearHistoryConfirmation = false
    @State private var showAPIKeySheet = false

    enum Section: String, CaseIterable, Identifiable {
        case general        = "General"
        case context       = "Context"
        case notifications = "Notifications"
        case privacy       = "Privacy"
        case about         = "About"

        var id: String { rawValue }

        var icon: String {
            switch self {
            case .general:       return "gearshape"
            case .context:       return "brain.head.profile"
            case .notifications: return "bell"
            case .privacy:       return "lock.shield"
            case .about:         return "info.circle"
            }
        }
    }

    var body: some View {
        HSplitView {
            sectionSidebar
            Divider()
            sectionContent
                .frame(minWidth: 300)
        }
        .background(Color.axisBackground)
    }

    // MARK: - Section Sidebar

    private var sectionSidebar: some View {
        List(Section.allCases, id: \.self, selection: $selectedSection) { section in
            Label(section.rawValue, systemImage: section.icon)
                .font(.system(size: 13))
                .foregroundColor(.axisTextPrimary)
                .listRowBackground(
                    selectedSection == section
                        ? Color.axisAccentTint
                        : Color.clear
                )
        }
        .listStyle(.sidebar)
        .scrollContentBackground(.hidden)
        .frame(width: 180)
        .background(Color.axisSurface)
    }

    // MARK: - Section Content

    @ViewBuilder
    private var sectionContent: some View {
        switch selectedSection {
        case .general:
            GeneralSettingsContent(settings: settings)
        case .context:
            ContextSettingsContent(settings: settings)
        case .notifications:
            NotificationSettingsContent(settings: settings)
        case .privacy:
            PrivacySettingsContent(
                settings: settings,
                showClearConfirmation: $showClearHistoryConfirmation,
                showAPIKeySheet: $showAPIKeySheet
            )
        case .about:
            AboutSettingsContent(settings: settings)
        }
    }
}

// MARK: - General Settings Content

private struct GeneralSettingsContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space7) {
                settingsSection("Appearance") {
                    settingsRow("Theme") {
                        Picker("", selection: $settings.theme) {
                            ForEach(SettingsStore.Theme.allCases) { theme in
                                Text(theme.rawValue).tag(theme)
                            }
                        }
                        .labelsHidden()
                        .pickerStyle(.segmented)
                        .frame(maxWidth: 240)
                    }
                }

                settingsSection("Popover") {
                    settingsRow("Size") {
                        Picker("", selection: $settings.popoverSize) {
                            ForEach(SettingsStore.PopoverSize.allCases) { size in
                                Text(size.rawValue).tag(size)
                            }
                        }
                        .labelsHidden()
                        .frame(width: 140)
                    }

                    settingsRow("Show Context Ring") {
                        Toggle("", isOn: $settings.showContextRing)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                settingsSection("Startup") {
                    settingsRow("Launch at Login") {
                        Toggle("", isOn: $settings.launchAtLogin)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Context Settings Content

private struct ContextSettingsContent: View {
    @ObservedObject var settings: SettingsStore

    private var contextLimitBinding: Binding<Double> {
        Binding(
            get: { Double(settings.contextLimit) },
            set: { settings.contextLimit = Int($0) }
        )
    }

    private var trimThresholdBinding: Binding<Double> {
        Binding(
            get: { Double(settings.trimThreshold) },
            set: { settings.trimThreshold = Int($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space7) {
                settingsSection("Context Limit") {
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Text("Max tokens")
                                .font(.system(size: 13))
                                .foregroundColor(.axisTextSecondary)
                            Spacer()
                            Text(settings.contextLimitFormatted)
                                .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                .foregroundColor(.axisAccent)
                        }

                        Slider(
                            contextLimitBinding,
                            in: 100_000...200_000,
                            step: 10_000
                        )
                        .labelsHidden()

                        HStack {
                            Text("100k")
                                .font(.system(size: 10))
                                .foregroundColor(.axisTextTertiary)
                            Spacer()
                            Text("200k")
                                .font(.system(size: 10))
                                .foregroundColor(.axisTextTertiary)
                        }
                    }
                }

                settingsSection("Auto-Trim") {
                    settingsRow("Enable Auto-Trim") {
                        Toggle("", isOn: $settings.autoTrim)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    if settings.autoTrim {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Trim threshold")
                                    .font(.system(size: 13))
                                    .foregroundColor(.axisTextSecondary)
                                Spacer()
                                Text(settings.trimThresholdFormatted)
                                    .font(.system(size: 13, weight: .semibold, design: .monospaced))
                                    .foregroundColor(.axisWarning)
                            }

                            Slider(
                                trimThresholdBinding,
                                in: 50_000...Double(settings.contextLimit - 10_000),
                                step: 5_000
                            )
                            .labelsHidden()

                            Text("Auto-trim kicks in when context approaches this threshold")
                                .font(.system(size: 11))
                                .foregroundColor(.axisTextTertiary)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Notification Settings Content

private struct NotificationSettingsContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space7) {
                settingsSection("Notifications") {
                    settingsRow("Enable Notifications") {
                        Toggle("", isOn: $settings.notificationsEnabled)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    settingsRow("Notification Sound") {
                        Toggle("", isOn: $settings.notificationSound)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Privacy Settings Content

private struct PrivacySettingsContent: View {
    @ObservedObject var settings: SettingsStore
    @Binding var showClearConfirmation: Bool
    @Binding var showAPIKeySheet: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space7) {
                settingsSection("Streamer Mode") {
                    settingsRow("Enable Streamer Mode") {
                        Toggle("", isOn: $settings.streamerMode)
                            .labelsHidden()
                            .toggleStyle(.switch)
                    }

                    Text("Hides API keys, tokens, and usernames during screen recording")
                        .font(.system(size: 11))
                        .foregroundColor(.axisTextTertiary)
                }

                settingsSection("API Key") {
                    HStack {
                        Text(settings.apiKeySet ? "API key is configured" : "No API key set")
                            .font(.system(size: 13))
                            .foregroundColor(.axisTextSecondary)

                        Spacer()

                        Button(settings.apiKeySet ? "Update" : "Add Key") {
                            showAPIKeySheet = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .buttonStyle(.borderedProminent)
                        .tint(.axisAccent)
                    }
                }

                settingsSection("Chat History") {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Clear all chat history permanently")
                            .font(.system(size: 13))
                            .foregroundColor(.axisTextSecondary)

                        Button("Clear Chat History") {
                            showClearConfirmation = true
                        }
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.axisDestructive)
                        .buttonStyle(.plain)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color.axisDestructiveTint)
                        .cornerRadius(AxisSpacing.radiusSmall)
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - About Settings Content

private struct AboutSettingsContent: View {
    @ObservedObject var settings: SettingsStore

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: AxisSpacing.space7) {
                settingsSection("Axis") {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Version \(settings.appVersion) (\(settings.buildNumber))")
                            .font(.system(size: 13))
                            .foregroundColor(.axisTextPrimary)

                        Text("Built with SwiftUI + Claude Code")
                            .font(.system(size: 12))
                            .foregroundColor(.axisTextTertiary)
                    }
                }

                settingsSection("Links") {
                    VStack(alignment: .leading, spacing: 8) {
                        Link(destination: URL(string: "https://github.com")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "link")
                                    .font(.system(size: 12))
                                Text("GitHub Repository")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.axisAccent)
                        }

                        Link(destination: URL(string: "https://github.com")!) {
                            HStack(spacing: 6) {
                                Image(systemName: "book")
                                    .font(.system(size: 12))
                                Text("Documentation")
                                    .font(.system(size: 13))
                            }
                            .foregroundColor(.axisAccent)
                        }
                    }
                }

                Spacer()
            }
            .padding(24)
        }
    }
}

// MARK: - Settings Section / Row Helpers

private struct SettingsSection<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: AxisSpacing.space4) {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.axisTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            VStack(alignment: .leading, spacing: 1) {
                content()
            }
            .padding(12)
            .background(Color.axisSurfaceElevated)
            .cornerRadius(AxisSpacing.radiusMedium)
        }
    }
}

private struct SettingsRow<Content: View>: View {
    let label: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 13))
                .foregroundColor(.axisTextPrimary)

            Spacer()

            content()
        }
    }
}

// MARK: - Preview

#Preview {
    SettingsView()
        .frame(width: 560, height: 640)
}
