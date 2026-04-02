import SwiftUI

// MARK: - ChatView
//
// The primary chat screen. Contains:
//   - A scrollable LazyVStack of MessageBubbleView messages
//   - A ComposeView pinned above the ContextRingView
//   - ContextRingView at the very bottom
//
// Empty state: centered prompt when no messages exist.
//
// Keyboard shortcuts:
//   ⌘N — new conversation (clears all messages after confirmation)
//
// Intentionality:
//   LazyVStack over ScrollView + VStack — handles large conversations
//     (100+ messages) without performance degradation. Messages are
//     identified by UUID so SwiftUI can animate additions/removals correctly.
//   ScrollViewReader is used to auto-scroll to the latest message when
//     a new one arrives — but we respect the user's scroll position if
//     they've manually scrolled up. This avoids the "always jumps to bottom"
//     frustration common in chat apps.

struct ChatView: View {
    @Binding var messages: [Message]
    @Binding var isStreaming: Bool
    let contextMetrics: ContextMetrics
    let onSend: (String) -> Void
    let onNewChat: () -> Void
    let onDeleteMessage: (Message) -> Void
    let onTrimMessage: (Message) -> Void

    @State private var composeText = ""
    @State private var scrollProxy: ScrollViewProxy?
    @State private var userHasScrolledUp = false
    @State private var showNewChatConfirmation = false

    // Track last message count to detect new messages
    @State private var previousMessageCount = 0

    var body: some View {
        VStack(spacing: 0) {
            // Header bar
            headerBar

            Divider()
                .background(Color.axisBorder)

            // Message list
            if messages.isEmpty {
                emptyState
            } else {
                messageList
            }

            // Compose area
            ComposeView(
                text: $composeText,
                isStreaming: isStreaming,
                onSend: handleSend
            )

            // Context ring
            ContextRingView(metrics: contextMetrics)
        }
        .background(Color.axisBackground)
        .toolbar {
            ToolbarItemGroup(placement: .primaryAction) {
                Button {
                    showNewChatConfirmation = true
                } label: {
                    Label("New Chat", systemImage: "square.and.pencil")
                        .font(.system(size: 13))
                }
                .keyboardShortcut("n", modifiers: .command)
                .help("New conversation (⌘N)")
            }
        }
        .confirmationDialog(
            "Start a new conversation?",
            isPresented: $showNewChatConfirmation,
            titleVisibility: .visible
        ) {
            Button("New Chat", role: .destructive) {
                onNewChat()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("This will clear the current chat. You can always find it in History.")
        }
        .onAppear {
            previousMessageCount = messages.count
        }
        .onChange(of: messages.count) { _, newCount in
            // Auto-scroll only if user hasn't manually scrolled up
            if newCount > previousMessageCount && !userHasScrolledUp {
                scrollToBottom(animated: true)
            }
            previousMessageCount = newCount
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Circle()
                .fill(Color.axisAccent)
                .frame(width: 8, height: 8)
                .opacity(isStreaming ? 1 : 0.4)
                .animation(
                    isStreaming
                        ? Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true)
                        : .default,
                    value: isStreaming
                )

            Text("AXISBLUEPRINT")
                .font(.system(size: 12, weight: .semibold, design: .default))
                .foregroundColor(.axisTextSecondary)
                .tracking(1.2)

            Spacer()

            if isStreaming {
                Text("Claude is thinking...")
                    .font(.system(size: 11))
                    .foregroundColor(.axisTextTertiary)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.axisSurface)
    }

    // MARK: - Message List

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 2) {
                    ForEach(messages) { message in
                        MessageBubbleView(
                            message: message,
                            isStreaming: isStreaming && message.id == messages.last?.id
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, 8)
            }
            .scrollIndicators(.hidden)
            .background(Color.axisBackground)
            .onAppear {
                scrollProxy = proxy
                // If returning to a populated chat, don't auto-scroll
                if messages.isEmpty {
                    userHasScrolledUp = false
                }
            }
            .onChange(of: messages.count) { _, _ in
                // Reset scroll flag when messages are cleared (new chat)
                if messages.isEmpty {
                    userHasScrolledUp = false
                }
            }
        }
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 48))
                .foregroundColor(.axisTextTertiary)

            Text("Start a conversation")
                .font(.system(size: 16, weight: .medium))
                .foregroundColor(.axisTextPrimary)

            Text("Ask Claude anything about your project.\nPress ⌘N to start a new chat.")
                .font(.system(size: 13))
                .foregroundColor(.axisTextSecondary)
                .multilineTextAlignment(.center)
                .lineSpacing(4)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.axisBackground)
    }

    // MARK: - Actions

    private func handleSend() {
        let trimmed = composeText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        onSend(trimmed)
        composeText = ""
    }

    private func scrollToBottom(animated: Bool) {
        guard let lastMessage = messages.last else { return }
        if animated {
            withAnimation(.easeOut(duration: 0.2)) {
                scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
            }
        } else {
            scrollProxy?.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

// MARK: - Previews

#Preview("Empty") {
    ChatView(
        messages: .constant([]),
        isStreaming: .constant(false),
        contextMetrics: .empty,
        onSend: { _ in },
        onNewChat: {},
        onDeleteMessage: { _ in },
        onTrimMessage: { _ in }
    )
    .frame(width: 480, height: 640)
}

#Preview("With messages") {
    ChatView(
        messages: .constant([
            .user("How do I set up the project map?"),
            .claude("The project map shows how your files connect. Let me explain how it works:\n\n• Nodes = files (sized by line count)\n• Edges = import/dependency connections\n• Colors = file type (Swift=blue, MD=purple)"),
            .tool("Reading: Sources/App/AxisBlueprintApp.swift\nLines: 45\nModified: true"),
            .claude("I've loaded the app entry point. It initializes the StatusBarController and PopoverContentView."),
            .thinking("The user is asking about the project map. I should check the SPEC.md first to understand the architecture requirements.")
        ]),
        isStreaming: .constant(false),
        contextMetrics: .preview,
        onSend: { _ in },
        onNewChat: {},
        onDeleteMessage: { _ in },
        onTrimMessage: { _ in }
    )
    .frame(width: 480, height: 640)
}

#Preview("Streaming") {
    ChatView(
        messages: .constant([
            .user("Show me the architecture"),
            .claude("Here's the architecture overview:"),
        ]),
        isStreaming: .constant(true),
        contextMetrics: .preview,
        onSend: { _ in },
        onNewChat: {},
        onDeleteMessage: { _ in },
        onTrimMessage: { _ in }
    )
    .frame(width: 480, height: 640)
}

#Preview("Context warning") {
    ChatView(
        messages: .constant([
            .user("Analyze the entire codebase"),
            .claude("I'll analyze all files now. This is a large context operation."),
        ]),
        isStreaming: .constant(false),
        contextMetrics: .previewWarning,
        onSend: { _ in },
        onNewChat: {},
        onDeleteMessage: { _ in },
        onTrimMessage: { _ in }
    )
    .frame(width: 480, height: 640)
}
