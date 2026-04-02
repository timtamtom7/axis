import Foundation

// MARK: - Message
// Core data model for a single chat message.
// Used by both the Chat feature and the persistence layer.

// NOTE: Token counting is an estimate via local cl100k_base-equivalent
// counting. Real token counts come from the Claude Code service response
// headers and are updated post-hoc.

struct Message: Identifiable, Codable, Equatable {
    let id: UUID
    let role: Role
    var content: String
    let timestamp: Date

    /// True when this message has been surgically trimmed.
    /// Rendered as a "tombstone" — dashed border, italic placeholder text.
    var isTombstone: Bool

    /// Estimated token count for context window accounting.
    /// Updated when Claude Code responds with usage metadata.
    var tokenCount: Int

    init(
        id: UUID = UUID(),
        role: Role,
        content: String,
        timestamp: Date = Date(),
        isTombstone: Bool = false,
        tokenCount: Int = 0
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.isTombstone = isTombstone
        self.tokenCount = tokenCount
    }
}

// MARK: - Role

extension Message {
    enum Role: String, Codable {
        case user
        case claude
        case system

        /// system messages are rendered like claude messages but with
        /// an icon prefix to indicate they are app-generated.
        var isClaudeOwned: Bool {
            self == .claude || self == .system
        }
    }
}

// MARK: - Message Type
// Distinguishes the visual rendering style within a Role's messages.
// e.g., a "thinking" message is claude-owned but visually distinct.

extension Message {
    enum MessageType: String, Codable {
        case text           // Standard prose
        case tool           // MCP tool call output — mono font, collapsible
        case thinking       // Claude's internal reasoning — italic, collapsed by default
        case tombstone      // Trimmed/removed — dashed border, placeholder text
    }

    /// The visual type, derived from role and tombstone flag.
    /// Used by MessageBubbleView to select the correct rendering style.
    var messageType: MessageType {
        if isTombstone { return .tombstone }
        // Role alone isn't enough — tool/thinking come from Claude but render differently.
        // The service layer annotates these via metadata; default to .text.
        return .text
    }

    /// Convenience for creating a tombstone placeholder message.
    static func tombstone(from original: Message, reason: String = "trimmed to save context") -> Message {
        Message(
            id: original.id,
            role: original.role,
            content: "[\(reason)]",
            timestamp: original.timestamp,
            isTombstone: true,
            tokenCount: 0
        )
    }
}

// MARK: - Convenience Constructors

extension Message {
    static func user(_ content: String) -> Message {
        Message(role: .user, content: content)
    }

    static func claude(_ content: String) -> Message {
        Message(role: .claude, content: content)
    }

    static func thinking(_ content: String) -> Message {
        Message(role: .claude, content: content)
    }

    static func tool(_ content: String) -> Message {
        Message(role: .claude, content: content)
    }
}
