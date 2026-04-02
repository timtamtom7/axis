import SwiftUI

// MARK: - Axis Color System
// Fully adaptive: light + dark mode via semantic Color tokens.
// All colors adapt to the current color scheme automatically.
// Reference: Raycast + ChatGPT + Apple dark/light quality.

// MARK: - Backgrounds (ColorScheme-aware)

extension Color {

    /// Root background — #0A0A0C (dark) / #FFFFFF (light)
    static let axisBackground = Color(".axisBackground")

    /// Card / panel background — #161619 (dark) / #F5F5F7 (light)
    static let axisSurface = Color(".axisSurface")

    /// Elevated surface (hover, selected) — #1E1E22 (dark) / #EBEBF0 (light)
    static let axisSurfaceElevated = Color(".axisSurfaceElevated")

    /// Overlay (dropdowns, tooltips) — #222226 (dark) / #E0E0E5 (light)
    static let axisSurfaceOverlay = Color(".axisSurfaceOverlay")

    /// Dividers — #2C2C32 (dark) / #D1D1D6 (light)
    static let axisBorder = Color(".axisBorder")

    /// Focused borders — #3A3A42 (dark) / #A0A0A8 (light)
    static let axisBorderFocused = Color(".axisBorderFocused")
}

// MARK: - Text Hierarchy

extension Color {

    /// Primary text — adapts automatically via system
    static let axisTextPrimary = Color(".axisTextPrimary")

    /// Secondary text — adapts automatically
    static let axisTextSecondary = Color(".axisTextSecondary")

    /// Tertiary / placeholder — adapts automatically
    static let axisTextTertiary = Color(".axisTextTertiary")
}

// MARK: - Accents (static — not colorScheme dependent)

extension Color {

    /// #4B9EFF — Electric blue. Primary CTA, send button, active tab.
    static let axisAccent = Color(hex: 0x4B9EFF)

    /// #4B9EFF at 15% — selected rows, subtle highlights.
    static let axisAccentTint = Color(hex: 0x4B9EFF).opacity(0.15)

    /// #7B61FF — Purple. AI/agent elements: Claude messages, thinking pulse.
    static let axisAccentSecondary = Color(hex: 0x7B61FF)

    /// #7B61FF at 15% — secondary accent tint.
    static let axisAccentSecondaryTint = Color(hex: 0x7B61FF).opacity(0.15)

    /// #F1DDBC — Champagne gold. Brand accent, premium highlights.
    /// WCAG AA on dark (#0A0A0C): ~9.2:1. On light (#FFFFFF): ~1.6:1.
    /// Use only on dark surfaces or with dark overlay.
    static let axisGold = Color(hex: 0xF1DDBC)

    /// #30D158 — Success, connected, checkmarks.
    static let axisSuccess = Color(hex: 0x30D158)

    /// #30D158 at 15%
    static let axisSuccessTint = Color(hex: 0x30D158).opacity(0.15)

    /// #FFD60A — Warning, high token count.
    static let axisWarning = Color(hex: 0xFFD60A)

    /// #FFD60A at 15%
    static let axisWarningTint = Color(hex: 0xFFD60A).opacity(0.15)

    /// #FF453A — Destructive: delete, stop, error.
    static let axisDestructive = Color(hex: 0xFF453A)

    /// #FF453A at 15%
    static let axisDestructiveTint = Color(hex: 0xFF453A).opacity(0.15)
}

// MARK: - Chat Bubbles (ColorScheme-aware)

extension Color {

    /// User bubble — #2A2A30 (dark) / #E8EDFF (light, blue tint)
    static let axisChatUserBubble = Color(".axisChatUserBubble")

    /// Claude bubble — #1E1E22 (dark) / #F0EDFF (light, purple tint)
    static let axisChatClaudeBubble = Color(".axisChatClaudeBubble")

    /// Tool output — #111113 (dark) / #F5F5F7 (light)
    static let axisChatToolBackground = Color(".axisChatToolBackground")

    /// Thinking block — #18181B (dark) / #EBEBF0 (light)
    static let axisChatThinkingBackground = Color(".axisChatThinkingBackground")
}

// MARK: - Context Ring

extension Color {

    /// Inactive track in the token bar.
    static let axisContextRingTrack = Color(".axisContextRingTrack")

    /// Filled portion of the context ring — gradient from accent → warning.
    static let axisContextRingFill = LinearGradient(
        colors: [Color(hex: 0x4B9EFF), Color(hex: 0x7B61FF), Color(hex: 0xFFD60A)],
        startPoint: .leading,
        endPoint: .trailing
    )
}

// MARK: - Map / Graph

extension Color {

    static let axisMapSwift    = Color(hex: 0x4B9EFF)
    static let axisMapMarkdown = Color(hex: 0x7B61FF)
    static let axisMapConfig   = Color(hex: 0x8E8E93)
    static let axisMapGeneric  = Color(hex: 0x5C5C60)
    static let axisMapEdge     = Color(hex: 0x2C2C32)
    static let axisMapPulse    = Color(hex: 0x7B61FF).opacity(0.6)
}

// MARK: - Scrollbar / Chrome

extension Color {

    static let axisScrollbarTrack = Color(".axisScrollbarTrack")
    static let axisScrollbarThumb = Color(hex: 0x3A3A42)
    static let axisScrollbarThumbHover = Color(hex: 0x5C5C60)
}

// MARK: - Hex Initializer

extension Color {
    init(hex: UInt, alpha: Double = 1.0) {
        self.init(
            .sRGB,
            red: Double((hex >> 16) & 0xFF) / 255.0,
            green: Double((hex >> 8) & 0xFF) / 255.0,
            blue: Double(hex & 0xFF) / 255.0,
            opacity: alpha
        )
    }
}
