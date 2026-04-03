import SwiftUI

// MARK: - HistoryView
//
// Full history tab — grouped by date, searchable, swipe-to-delete.
// Tapping a chat loads it into ChatView (switches tab).
// Keyboard: ⌘F focuses the search bar.

struct HistoryView: View {
    @ObservedObject var storage: ChatStorage
    let onSelectChat: (ChatStorage.Chat) -> Void
    let onDeleteChat: (UUID) -> Void

    @State private var searchText = ""
    @FocusState private var searchFocused: Bool
    @State private var chatToDelete: ChatStorage.ChatManifest?
    @State private var showDeleteConfirmation = false

    private var filteredChats: [ChatStorage.ChatManifest] {
        if searchText.isEmpty {
            return storage.manifests
        }
        return storage.manifests.filter { manifest in
            manifest.title.localizedCaseInsensitiveContains(searchText)
        }
    }

    private var groupedChats: [(String, [ChatStorage.ChatManifest])] {
        let calendar = Calendar.current
        let now = Date()

        let today = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: today)!
        let weekAgo = calendar.date(byAdding: .day, value: -7, to: today)!

        var todayChats: [ChatStorage.ChatManifest] = []
        var yesterdayChats: [ChatStorage.ChatManifest] = []
        var thisWeekChats: [ChatStorage.ChatManifest] = []
        var olderChats: [ChatStorage.ChatManifest] = []

        for chat in filteredChats {
            let chatDay = calendar.startOfDay(for: chat.updatedAt)
            if chatDay == today {
                todayChats.append(chat)
            } else if chatDay == yesterday {
                yesterdayChats.append(chat)
            } else if chatDay >= weekAgo {
                thisWeekChats.append(chat)
            } else {
                olderChats.append(chat)
            }
        }

        var result: [(String, [ChatStorage.ChatManifest])] = []
        if !todayChats.isEmpty { result.append(("Today", todayChats)) }
        if !yesterdayChats.isEmpty { result.append(("Yesterday", yesterdayChats)) }
        if !thisWeekChats.isEmpty { result.append(("This Week", thisWeekChats)) }
        if !olderChats.isEmpty { result.append(("Older", olderChats)) }
        return result
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerBar

            Divider()
                .background(Color.axisBorder)

            // Search bar
            searchBar

            Divider()
                .background(Color.axisBorder)

            // Content
            if storage.manifests.isEmpty {
                emptyState
            } else if filteredChats.isEmpty {
                noResultsState
            } else {
                chatList
            }
        }
        .background(Color.axisBackground)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .confirmationDialog(
            "Delete this conversation?",
            isPresented: $showDeleteConfirmation,
            titleVisibility: .visible
        ) {
            Button("Delete", role: .destructive) {
                if let chat = chatToDelete {
                    onDeleteChat(chat.id)
                }
            }
            Button("Cancel", role: .cancel) {
                chatToDelete = nil
            }
        } message: {
            Text("This conversation will be permanently deleted. You can't undo this.")
        }
        .onTapGesture {
            hideKeyboard()
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        HStack {
            Text("Chat History")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(.axisTextPrimary)

            Spacer()

            Text("\(storage.manifests.count) chats")
                .font(.system(size: 12))
                .foregroundColor(.axisTextTertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.axisSurface)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 12))
                .foregroundColor(.axisTextTertiary)

            TextField("Search conversations...", text: $searchText)
                .font(.system(size: 13))
                .foregroundColor(.axisTextPrimary)
                .textFieldStyle(.plain)
                .focused($searchFocused)

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
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.axisSurfaceElevated)
        .cornerRadius(AxisSpacing.radiusMedium)
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(Color.axisBackground)
    }

    // MARK: - Chat List

    private var chatList: some View {
        ScrollView {
            LazyVStack(spacing: 0, pinnedViews: .sectionHeaders) {
                ForEach(groupedChats, id: \.0) { section, chats in
                    Section {
                        ForEach(chats) { manifest in
                            ChatRowView(manifest: manifest)
                                .contentShape(Rectangle())
                                .onTapGesture {
                                    loadChat(manifest: manifest)
                                }
                                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                                    Button(role: .destructive) {
                                        chatToDelete = manifest
                                        showDeleteConfirmation = true
                                    } label: {
                                        Label("Delete", systemImage: "trash")
                                    }
                                }
                        }
                    } header: {
                        sectionHeader(section)
                    }
                }
            }
        }
        .scrollIndicators(.hidden)
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(.axisTextTertiary)
                .textCase(.uppercase)
                .tracking(0.5)

            Spacer()
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 6)
        .background(Color.axisBackground)
    }

    // MARK: - Empty States

    private var emptyState: some View {
        VStack(spacing: AxisSpacing.space4) {
            Spacer()

            Image(systemName: "brain.head.profile")
                .font(.system(size: 40))
                .foregroundColor(.axisTextTertiary)

            Text("Your conversations will appear here")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.axisTextSecondary)

            Text("Start chatting to build your history")
                .font(.system(size: 12))
                .foregroundColor(.axisTextTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var noResultsState: some View {
        VStack(spacing: AxisSpacing.space4) {
            Spacer()

            Image(systemName: "magnifyingglass")
                .font(.system(size: 32))
                .foregroundColor(.axisTextTertiary)

            Text("No results for \"\(searchText)\"")
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(.axisTextSecondary)

            Text("Try searching with different keywords")
                .font(.system(size: 12))
                .foregroundColor(.axisTextTertiary)

            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    // MARK: - Actions

    private func loadChat(manifest: ChatStorage.ChatManifest) {
        guard let chat = try? storage.loadChat(id: manifest.id) else { return }
        onSelectChat(chat)
    }
}

// MARK: - ChatRowView

private struct ChatRowView: View {
    let manifest: ChatStorage.ChatManifest

    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: manifest.updatedAt)
    }

    private var tokenEstimateString: String {
        let tokens = manifest.tokenEstimate
        if tokens >= 1000 {
            return String(format: "%.1fk", Double(tokens) / 1000.0)
        }
        return "\(tokens)"
    }

    var body: some View {
        HStack(spacing: 12) {
            // Chat icon
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.system(size: 14))
                .foregroundColor(.axisAccentSecondary)
                .frame(width: 20)

            // Title and preview
            VStack(alignment: .leading, spacing: 2) {
                Text(manifest.title)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.axisTextPrimary)
                    .lineLimit(1)

                if let preview = manifest.lastMessagePreview, !preview.isEmpty {
                    Text(preview)
                        .font(.system(size: 11))
                        .foregroundColor(.axisTextTertiary)
                        .lineLimit(1)
                }
            }

            Spacer()

            // Metadata
            VStack(alignment: .trailing, spacing: 2) {
                Text(timeString)
                    .font(.system(size: 11))
                    .foregroundColor(.axisTextTertiary)

                HStack(spacing: 2) {
                    Text("\(manifest.messageCount)")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundColor(.axisTextTertiary)

                    Image(systemName: "character.bubble")
                        .font(.system(size: 9))
                        .foregroundColor(.axisTextTertiary)
                }
            }

            // Token estimate
            Text(tokenEstimateString)
                .font(.system(size: 10, weight: .medium, design: .monospaced))
                .foregroundColor(.axisTextTertiary)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.axisSurfaceElevated)
                .cornerRadius(4)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.axisBackground)
    }
}

// MARK: - Helpers

private func hideKeyboard() {
    #if os(macOS)
    NSApp.keyWindow?.makeFirstResponder(nil)
    #endif
}

// MARK: - Previews

#Preview("With chats") {
    HistoryView(
        storage: ChatStorage(),
        onSelectChat: { _ in },
        onDeleteChat: { _ in }
    )
    .frame(width: 480, height: 640)
}
