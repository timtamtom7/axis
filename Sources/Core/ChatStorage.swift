import Foundation

/// File-based chat persistence layer.
/// Chats are stored in `~/.axisblueprint/chats/` as:
///   <chat-id>/
///     manifest.json    — metadata (title, created, message count, token estimate)
///     messages/
///       <timestamp>-<uuid>.json  — individual message files
final class ChatStorage: @unchecked Sendable {
    // MARK: - Directory Layout

    private let baseURL: URL
    private let fileManager = FileManager.default

    // MARK: - Init

    init(basePath: String? = nil) {
        let path = basePath ?? "~/.axisblueprint/chats"
        self.baseURL = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        ensureDirectoryExists()
    }

    private func ensureDirectoryExists() {
        try? fileManager.createDirectory(at: baseURL, withIntermediateDirectories: true)
    }

    // MARK: - Chat Operations

    struct ChatManifest: Codable {
        let id: UUID
        var title: String
        let createdAt: Date
        var updatedAt: Date
        var messageCount: Int
        var tokenEstimate: Int
        var lastMessagePreview: String?

        enum CodingKeys: String, CodingKey {
            case id, title, createdAt, updatedAt, messageCount, tokenEstimate, lastMessagePreview
        }
    }

    struct Chat: Identifiable {
        let id: UUID
        var manifest: ChatManifest
        var messages: [ChatMessage]
    }

    struct ChatMessage: Identifiable, Codable {
        let id: UUID
        let role: String
        var content: String
        let timestamp: Date
        var tokenEstimate: Int?
        var isTombstone: Bool
        var tombstoneSummary: String?
    }

    // MARK: - Save

    func save(_ chat: Chat) throws {
        let chatDir = baseURL.appendingPathComponent(chat.id.uuidString)
        try fileManager.createDirectory(at: chatDir, withIntermediateDirectories: true)

        // Write manifest
        let manifestURL = chatDir.appendingPathComponent("manifest.json")
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let manifestData = try encoder.encode(chat.manifest)
        try manifestData.write(to: manifestURL)

        // Write messages
        let messagesDir = chatDir.appendingPathComponent("messages")
        try fileManager.createDirectory(at: messagesDir, withIntermediateDirectories: true)

        for message in chat.messages {
            let filename = "\(Int(message.timestamp.timeIntervalSince1970))-\(message.id.uuidString).json"
            let messageURL = messagesDir.appendingPathComponent(filename)
            let messageData = try encoder.encode(message)
            try messageData.write(to: messageURL)
        }
    }

    func saveMessage(_ message: ChatMessage, to chatId: UUID) throws {
        let chatDir = baseURL.appendingPathComponent(chatId.uuidString)
        let messagesDir = chatDir.appendingPathComponent("messages")
        try fileManager.createDirectory(at: messagesDir, withIntermediateDirectories: true)

        let filename = "\(Int(message.timestamp.timeIntervalSince1970))-\(message.id.uuidString).json"
        let messageURL = messagesDir.appendingPathComponent(filename)

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(message)
        try data.write(to: messageURL)

        // Update manifest
        let manifestURL = chatDir.appendingPathComponent("manifest.json")
        if let manifestData = try? Data(contentsOf: manifestURL) {
            var manifest = try JSONDecoder().decode(ChatManifest.self, from: manifestData)
            manifest.messageCount += 1
            manifest.updatedAt = Date()
            manifest.lastMessagePreview = String(message.content.prefix(100))
            manifest.tokenEstimate = (manifest.tokenEstimate ?? 0) + (message.tokenEstimate ?? TokenCounter.estimate(message.content))

            let encoder = JSONEncoder()
            encoder.dateEncodingStrategy = .iso8601
            try encoder.encode(manifest).write(to: manifestURL)
        }
    }

    // MARK: - Load

    func loadChat(id: UUID) throws -> Chat {
        let chatDir = baseURL.appendingPathComponent(id.uuidString)
        let manifestURL = chatDir.appendingPathComponent("manifest.json")
        let messagesDir = chatDir.appendingPathComponent("messages")

        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let manifest = try decoder.decode(ChatManifest.self, from: manifestData)

        var messages: [ChatMessage] = []
        let messageFiles = try fileManager.contentsOfDirectory(at: messagesDir, includingPropertiesForKeys: nil)
            .filter { $0.pathExtension == "json" }
            .sorted { $0.path < $1.path }

        for file in messageFiles {
            let data = try Data(contentsOf: file)
            if let msg = try? decoder.decode(ChatMessage.self, from: data) {
                messages.append(msg)
            }
        }

        return Chat(id: id, manifest: manifest, messages: messages)
    }

    // MARK: - List

    func listChats() throws -> [ChatManifest] {
        let contents = try fileManager.contentsOfDirectory(
            at: baseURL,
            includingPropertiesForKeys: [.isDirectoryKey],
            options: [.skipsHiddenFiles]
        )

        var manifests: [ChatManifest] = []
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        for dir in contents {
            let isDir = try? dir.resourceValues(forKeys: [.isDirectoryKey]).isDirectory
            guard isDir == true else { continue }

            let manifestURL = dir.appendingPathComponent("manifest.json")
            guard let data = try? Data(contentsOf: manifestURL),
                  let manifest = try? decoder.decode(ChatManifest.self, from: data) else {
                continue
            }
            manifests.append(manifest)
        }

        return manifests.sorted { $0.updatedAt > $1.updatedAt }
    }

    // MARK: - Search

    func searchChats(query: String) throws -> [ChatManifest] {
        let all = try listChats()
        let lowercased = query.lowercased()

        return all.filter { manifest in
            manifest.title.lowercased().contains(lowercased) ||
            (manifest.lastMessagePreview?.lowercased().contains(lowercased) ?? false)
        }
    }

    // MARK: - Delete

    func deleteChat(id: UUID) throws {
        let chatDir = baseURL.appendingPathComponent(id.uuidString)
        try fileManager.removeItem(at: chatDir)
    }

    // MARK: - New Chat

    func createChat(title: String = "Untitled") throws -> Chat {
        let id = UUID()
        let now = Date()
        let manifest = ChatManifest(
            id: id,
            title: title,
            createdAt: now,
            updatedAt: now,
            messageCount: 0,
            tokenEstimate: 0,
            lastMessagePreview: nil
        )
        let chat = Chat(id: id, manifest: manifest, messages: [])
        try save(chat)
        return chat
    }
}
