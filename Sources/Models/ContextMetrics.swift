import SwiftUI

// MARK: - ContextMetrics
// Tracks what's inside the 200k token context window and reports it
// to the ContextRingView. Updated on every Claude response.
//
// Why it exists: The context window is AXISBlueprint's most precious
// resource. Users need to see at a glance how much headroom remains
// and which component is consuming it. Hiding this leads to surprise
// compactions and lost context.
//
// Design choice: We show a single aggregated number (total/target)
// by default — the per-component breakdown is revealed on tap. This
// keeps the UI clean while preserving full transparency. No mystery
// about where tokens went.

struct ContextMetrics: Equatable {
    let totalTokens: Int
    let appPromptTokens: Int
    let globalMDTokens: Int
    let projectMDTokens: Int
    let memoryTokens: Int
    let skillsTokens: Int
    let agentsTokens: Int
    let conversationTokens: Int

    /// Hard limit enforced by the model.
    static let hardLimit: Int = 200_000

    /// Soft warning threshold — suggest trim.
    static let warningThreshold: Int = 180_000

    /// Amber caution threshold — show yellow.
    static let cautionThreshold: Int = 100_000

    // MARK: - Computed

    /// Percentage of context window used, 0.0–1.0+.
    var usageFraction: Double {
        Double(totalTokens) / Double(Self.hardLimit)
    }

    /// Color for the context ring based on current usage.
    var thresholdWarning: Color {
        let fraction = usageFraction
        if fraction >= 0.8 {
            return .axisDestructive  // >80% — red
        } else if fraction >= 0.5 {
            return .axisWarning       // 50–80% — yellow
        } else {
            return .axisSuccess       // <50% — green
        }
    }

    /// Short human-readable token string: "2.1k" / "156k" / "200k+"
    func toTokenString(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        } else if value >= 1_000 {
            let k = Double(value) / 1_000.0
            if k == Double(Int(k)) {
                return "\(Int(k))k"
            }
            return String(format: "%.1fk", k)
        }
        return "\(value)"
    }

    var totalTokenString: String {
        toTokenString(totalTokens)
    }

    var limitTokenString: String {
        toTokenString(Self.hardLimit)
    }

    // MARK: - Placeholder / Empty

    static let empty = ContextMetrics(
        totalTokens: 0,
        appPromptTokens: 0,
        globalMDTokens: 0,
        projectMDTokens: 0,
        memoryTokens: 0,
        skillsTokens: 0,
        agentsTokens: 0,
        conversationTokens: 0
    )

    // MARK: - Mock (for SwiftUI previews)

    static let preview = ContextMetrics(
        totalTokens: 45_200,
        appPromptTokens: 3_000,
        globalMDTokens: 1_500,
        projectMDTokens: 4_000,
        memoryTokens: 800,
        skillsTokens: 1_200,
        agentsTokens: 0,
        conversationTokens: 34_700
    )

    static let previewWarning = ContextMetrics(
        totalTokens: 165_000,
        appPromptTokens: 3_000,
        globalMDTokens: 1_500,
        projectMDTokens: 12_000,
        memoryTokens: 2_000,
        skillsTokens: 1_200,
        agentsTokens: 0,
        conversationTokens: 145_300
    )

    static let previewCritical = ContextMetrics(
        totalTokens: 195_000,
        appPromptTokens: 3_000,
        globalMDTokens: 1_500,
        projectMDTokens: 18_000,
        memoryTokens: 2_000,
        skillsTokens: 1_200,
        agentsTokens: 0,
        conversationTokens: 169_300
    )
}
