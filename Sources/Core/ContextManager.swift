import Foundation

/// Manages context window usage tracking, warnings, and surgical trimming suggestions.
/// All state is computed from a snapshot — no side effects.
struct ContextManager: Sendable {
    // MARK: - Thresholds

    static let warningLevel1: Int = 150_000  // First warning
    static let warningLevel2: Int = 180_000  // Second warning / trim suggested
    static let warningLevel3: Int = 195_000  // Auto-trim imminent
    static let hardLimit:    Int = 200_000  // Claude hard limit

    // MARK: - State

    private(set) var totalTokens: Int = 0
    private(set) var componentBreakdown: [ContextComponent: Int] = [:]

    // MARK: - Components

    enum ContextComponent: String, CaseIterable, Sendable {
        case appPrompt     = "App Prompt"
        case globalMD      = "Global MD"
        case projectMD     = "Project MD"
        case memoryFiles   = "Memory Files"
        case skills        = "Skills"
        case agents        = "Agents"
        case conversation  = "Conversation"

        var description: String { rawValue }
    }

    // MARK: - Metrics

    struct ContextMetrics {
        let total: Int
        let breakdown: [ContextComponent: Int]
        let warningLevel: WarningLevel
        let limitPercent: Double

        var canContinue: Bool { total < ContextManager.hardLimit }
        var shouldTrim:   Bool { total >= ContextManager.warningLevel2 }
        var shouldWarn:   Bool { total >= ContextManager.warningLevel1 }

        enum WarningLevel: Int, Comparable {
            case safe    = 0
            case low     = 1
            case medium  = 2
            case high    = 3
            case critical = 4

            static func < (lhs: WarningLevel, rhs: WarningLevel) -> Bool {
                lhs.rawValue < rhs.rawValue
            }

            var label: String {
                switch self {
                case .safe:     return "Safe"
                case .low:      return "Low"
                case .medium:   return "Medium"
                case .high:     return "High"
                case .critical: return "Critical"
                }
            }
        }

        static func from(total: Int, breakdown: [ContextComponent: Int]) -> ContextMetrics {
            let level: WarningLevel
            switch total {
            case ..<warningLevel1: level = .safe
            case ..<warningLevel2: level = .low
            case ..<warningLevel3: level = .medium
            case ..<hardLimit:    level = .high
            default:              level = .critical
            }

            let pct = Double(total) / Double(hardLimit) * 100
            return ContextMetrics(total: total, breakdown: breakdown, warningLevel: level, limitPercent: pct)
        }

        static let warningLevel1 = ContextManager.warningLevel1
        static let warningLevel2 = ContextManager.warningLevel2
        static let warningLevel3 = ContextManager.warningLevel3
        static let hardLimit     = ContextManager.hardLimit
    }

    // MARK: - Build from Messages

    /// Build a snapshot from a list of messages plus static context components.
    static func snapshot(
        messages: [ClaudeMessage],
        appPromptTokens: Int = 2000,
        globalMDTokens: Int = 0,
        projectMDTokens: Int = 0,
        memoryFilesTokens: Int = 0,
        skillsTokens: Int = 0,
        agentsTokens: Int = 0
    ) -> ContextMetrics {
        let conversationTokens = TokenCounter.estimate(messages: messages)

        let breakdown: [ContextComponent: Int] = [
            .appPrompt:    appPromptTokens,
            .globalMD:     globalMDTokens,
            .projectMD:    projectMDTokens,
            .memoryFiles: memoryFilesTokens,
            .skills:       skillsTokens,
            .agents:       agentsTokens,
            .conversation: conversationTokens
        ]

        let total = breakdown.values.reduce(0, +)
        return ContextMetrics.from(total: total, breakdown: breakdown)
    }

    // MARK: - Trim Suggestions

    /// Suggests which messages or components to trim to reach the target.
    /// Returns messages that could be collapsed/tombstoned.
    struct TrimSuggestion {
        let messagesToTombstone: [UUID]       // Message IDs to replace with tombstones
        let estimatedSavings: Int              // Tokens that would be recovered
        let reason: String
    }

    /// Generates surgical trim suggestions targeting the bulkiest components.
    /// Strategy: trim oldest tool-call-heavy messages first (they have the most bloat).
    static func suggestTrim(
        current: ContextMetrics,
        targetReduction: Int? = nil
    ) -> TrimSuggestion? {
        let target = targetReduction ?? (current.total - warningLevel1)

        guard current.total > warningLevel1 else { return nil }

        // Strategy: oldest conversation messages with tool output are trimmed first
        // Tool calls typically make up 70-90% of bloat — trimming them has highest ROI
        var savings = 0
        var toTombstone: [UUID] = []

        // Simulate trimming — in production this would be computed from actual messages
        // For now, estimate: each tool-heavy message ≈ 800-2000 tokens
        let estimatedPerMessage = 1200

        while savings < target {
            // Placeholder: would iterate through actual messages
            // For R1, return a general suggestion
            break
        }

        return TrimSuggestion(
            messagesToTombstone: toTombstone,
            estimatedSavings: savings,
            reason: "Trim oldest tool-call-heavy messages to recover context space"
        )
    }

    // MARK: - Tombstone

    /// A tombstone representation for a trimmed message.
    /// Preserves conversation continuity while removing bulk.
    struct Tombstone: Sendable, Codable {
        let originalId: UUID
        let summary: String
        let removedAt: Date
        let tokenSavings: Int

        static func from(message: ClaudeMessage, summary: String, tokenSavings: Int) -> Tombstone {
            Tombstone(
                originalId: message.id,
                summary: summary,
                removedAt: Date(),
                tokenSavings: tokenSavings
            )
        }

        var displayText: String {
            "This message was trimmed to save context (\(tokenSavings) tokens recovered)"
        }
    }
}
