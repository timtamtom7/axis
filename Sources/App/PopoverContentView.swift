import SwiftUI

/// Root SwiftUI view for the Axis menu bar popover.
/// Contains the tabbed interface: Chat | Map | History | Skills | Settings
struct PopoverContentView: View {
    @State private var selectedTab: Tab = .chat
    @State private var currentChatName: String? = nil
    @State private var currentChat: ChatStorage.Chat?
    @State private var messages: [Message] = []
    @State private var isStreaming: Bool = false
    @State private var contextMetrics: ContextMetrics = .empty
    @StateObject private var chatStorage = ChatStorageState()
    @State private var showSettings = false

    enum Tab: String, CaseIterable {
        case chat = "Chat"
        case map = "Map"
        case history = "History"
        case skills = "Skills"
        case settings = "Settings"

        var icon: String {
            switch self {
            case .chat:    return "bubble.left.and.bubble.right"
            case .map:     return "map"
            case .history: return "clock"
            case .skills:  return "bolt.fill"
            case .settings: return "gear"
            }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()
                .background(Color.axisBorder)

            // Tab bar
            TabBar

            Divider()
                .background(Color.axisBorder)

            // Content
            TabView(selection: $selectedTab) {
                chatTab
                    .tag(Tab.chat)

                MapView(projectPath: nil)
                    .tag(Tab.map)

                HistoryView(
                    storage: chatStorage.storage,
                    onSelectChat: { chat in
                        loadChat(chat)
                    },
                    onDeleteChat: { id in
                        deleteChat(id: id)
                    }
                )
                .tag(Tab.history)

                SkillsView()
                    .tag(Tab.skills)

                SettingsView()
                    .tag(Tab.settings)
            }
            .tabViewStyle(.automatic)
        }
        .frame(width: 480, height: 640)
        .background(Color.axisBackground)
    }

    // MARK: - Chat Tab

    @ViewBuilder
    private var chatTab: some View {
        if let chat = currentChat, !messages.isEmpty {
            ChatView(
                messages: $messages,
                isStreaming: $isStreaming,
                contextMetrics: contextMetrics,
                onSend: { text in
                    handleSend(text: text)
                },
                onNewChat: {
                    handleNewChat()
                },
                onDeleteMessage: { message in
                    handleDeleteMessage(message)
                },
                onTrimMessage: { message in
                    handleTrimMessage(message)
                }
            )
        } else {
            EmptyChatView {
                handleNewChat()
            }
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack(spacing: 10) {
            // Left: App name
            HStack(spacing: 6) {
                Circle()
                    .fill(Color.axisAccent)
                    .frame(width: 7, height: 7)

                Text("AXIS")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(.axisTextPrimary)
                    .tracking(1.0)
            }

            // Center: Chat name or project
            if let chatName = currentChatName {
                HStack(spacing: 4) {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 8))
                        .foregroundColor(.axisTextTertiary)

                    Text(chatName)
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.axisTextSecondary)
                        .lineLimit(1)
                }
            } else {
                Spacer()
            }

            Spacer()

            // Right: New chat button (only when chat tab is active)
            if selectedTab == .chat && currentChat != nil {
                Button {
                    handleNewChat()
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11))
                        Text("New")
                            .font(.system(size: 11, weight: .medium))
                    }
                    .foregroundColor(.axisTextSecondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.axisSurfaceElevated)
                    .cornerRadius(AxisSpacing.radiusSmall)
                }
                .buttonStyle(.plain)
            }

            // Settings button (always visible)
            Button {
                withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                    selectedTab = .settings
                }
            } label: {
                Image(systemName: "gear")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundColor(selectedTab == .settings ? .axisAccent : .axisTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(Color.axisSurface)
    }

    // MARK: - Tab Bar

    private var TabBar: some View {
        HStack(spacing: 0) {
            ForEach(Tab.allCases, id: \.self) { tab in
                Button {
                    withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                        selectedTab = tab
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 12, weight: .medium))
                        Text(tab.rawValue)
                            .font(.system(size: 13, weight: .medium))
                    }
                    .foregroundColor(selectedTab == tab ? Color(hex: "FAFAFA") : Color(hex: "8E8E93"))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                    .background(
                        selectedTab == tab
                            ? Color(hex: "1E1E22")
                            : Color.clear
                    )
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }

            Spacer()
        }
        .padding(.horizontal, 8)
        .padding(.top, 8)
    }

    // MARK: - Actions

    private func handleSend(text: String) {
        // Placeholder for Claude Code service integration
        let newMessage = Message.user(text)
        messages.append(newMessage)
        isStreaming = true

        // Simulate response
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            let response = Message.claude("This is a placeholder response from Claude Code.")
            messages.append(response)
            isStreaming = false
        }
    }

    private func handleNewChat() {
        currentChat = nil
        currentChatName = nil
        messages = []
        isStreaming = false
        contextMetrics = .empty
    }

    private func loadChat(_ chat: ChatStorage.Chat) {
        currentChat = chat
        currentChatName = chat.manifest.title
        messages = chat.messages.map { msg in
            Message(
                id: msg.id,
                role: msg.role == "user" ? .user : .claude,
                content: msg.content,
                timestamp: msg.timestamp,
                isTombstone: msg.isTombstone,
                tokenCount: msg.tokenEstimate ?? 0
            )
        }
        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
            selectedTab = .chat
        }
    }

    private func deleteChat(id: UUID) {
        try? chatStorage.storage.deleteChat(id: id)
        chatStorage.reload()
        if currentChat?.id == id {
            handleNewChat()
        }
    }

    private func handleDeleteMessage(_ message: Message) {
        messages.removeAll { $0.id == message.id }
    }

    private func handleTrimMessage(_ message: Message) {
        if let index = messages.firstIndex(where: { $0.id == message.id }) {
            messages[index] = Message(
                id: message.id,
                role: message.role,
                content: "[trimmed to save context]",
                timestamp: message.timestamp,
                isTombstone: true,
                tokenCount: 0
            )
        }
    }
}

// MARK: - ChatStorageState

/// Observable wrapper that reloads manifests on demand.
@MainActor
final class ChatStorageState: ObservableObject {
    let storage: ChatStorage

    init() {
        self.storage = ChatStorage()
    }

    func reload() {
        // Force refresh by accessing manifests
        _ = storage.manifests
    }
}

// MARK: - Placeholder Tab

private struct PlaceholderTab: View {
    let title: String

    var body: some View {
        VStack {
            Spacer()
            Text(title)
                .font(.system(size: 20, weight: .semibold))
                .foregroundColor(Color(hex: "8E8E93"))
            Text("Coming in R1")
                .font(.system(size: 13))
                .foregroundColor(Color(hex: "5C5C60"))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(hex: "0A0A0C"))
    }
}

// MARK: - Color Extension (hex support)

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 3: // RGB (12-bit)
            (a, r, g, b) = (255, (int >> 8) * 17, (int >> 4 & 0xF) * 17, (int & 0xF) * 17)
        case 6: // RGB (24-bit)
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8: // ARGB (32-bit)
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}
