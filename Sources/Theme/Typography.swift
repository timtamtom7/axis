import SwiftUI

// MARK: - AXISBlueprint Typography System
// SF Pro for UI text, SF Mono for code/tool output.
// 14px base unit — all sizes scale from this foundation.
// Design reference: Apple HIG + ChatGPT macOS app.

enum AxisTypography {
    // MARK: - Display

    /// 20pt SF Pro Semibold — App name in header, large section titles.
    static let displayFont = Font.system(size: 20, weight: .semibold, design: .default)

    /// Line height 28pt, tight but breathable for a popover header.
    static let displayLineHeight: CGFloat = 28

    /// Slight negative tracking for large display text.
    static let displayLetterSpacing: CGFloat = -0.3

    // MARK: - Title

    /// 17pt SF Pro Semibold — Section headers, card titles, tab labels.
    static let titleFont = Font.system(size: 17, weight: .semibold, design: .default)

    /// Line height 24pt.
    static let titleLineHeight: CGFloat = 24

    /// Minimal tracking at title size.
    static let titleLetterSpacing: CGFloat = -0.2

    // MARK: - Headline

    /// 15pt SF Pro Medium — Subsection headings, message sender labels,
    /// inline bold text within a body paragraph.
    static let headlineFont = Font.system(size: 15, weight: .medium, design: .default)

    /// Line height 22pt.
    static let headlineLineHeight: CGFloat = 22

    /// Slight tracking for medium-weight headline.
    static let headlineLetterSpacing: CGFloat = -0.1

    // MARK: - Body

    /// 14pt SF Pro Regular — The workhorse. All message content, input text,
    /// descriptions, metadata. This is the base unit (14px).
    static let bodyFont = Font.system(size: 14, weight: .regular, design: .default)

    /// Line height 20pt — comfortable reading height in tight spaces.
    static let bodyLineHeight: CGFloat = 20

    /// Neutral tracking for body text.
    static let bodyLetterSpacing: CGFloat = 0

    // MARK: - Caption

    /// 12pt SF Pro Regular — Timestamps, token counts, badges, tertiary labels.
    /// Small but legible at popover scale.
    static let captionFont = Font.system(size: 12, weight: .regular, design: .default)

    /// Line height 16pt — compact but not cramped.
    static let captionLineHeight: CGFloat = 16

    /// Slight positive tracking to prevent caption text from feeling tight.
    static let captionLetterSpacing: CGFloat = 0.1

    // MARK: - Mono / Code

    /// 13pt SF Mono Regular — Tool output, code blocks, file paths, terminal
    /// output, keyboard shortcuts. Slightly smaller than body to distinguish
    /// from prose without feeling cramped.
    static let monoFont = Font.system(size: 13, weight: .regular, design: .monospaced)

    /// Line height 18pt — mono text needs a touch more breathing room per line.
    static let monoLineHeight: CGFloat = 18

    /// Monospace fonts benefit from neutral tracking.
    static let monoLetterSpacing: CGFloat = 0

    // MARK: - Code Block (Large)

    /// 12pt SF Mono — Inline code within prose.
    static let inlineCodeFont = Font.system(size: 12, weight: .regular, design: .monospaced)

    /// 18pt line height for inline code.
    static let inlineCodeLineHeight: CGFloat = 18
}

// MARK: - Helper Modifiers

extension View {
    /// Applies display font + tracking + line height.
    func axisDisplayStyle() -> some View {
        self
            .font(AxisTypography.displayFont)
            .tracking(AxisTypography.displayLetterSpacing)
            .lineSpacing(AxisTypography.displayLineHeight - 20)
    }

    /// Applies title font + tracking + line height.
    func axisTitleStyle() -> some View {
        self
            .font(AxisTypography.titleFont)
            .tracking(AxisTypography.titleLetterSpacing)
            .lineSpacing(AxisTypography.titleLineHeight - 17)
    }

    /// Applies headline font + tracking + line height.
    func axisHeadlineStyle() -> some View {
        self
            .font(AxisTypography.headlineFont)
            .tracking(AxisTypography.headlineLetterSpacing)
            .lineSpacing(AxisTypography.headlineLineHeight - 15)
    }

    /// Applies body font + line height.
    func axisBodyStyle() -> some View {
        self
            .font(AxisTypography.bodyFont)
            .tracking(AxisTypography.bodyLetterSpacing)
            .lineSpacing(AxisTypography.bodyLineHeight - 14)
    }

    /// Applies caption font + tracking + line height.
    func axisCaptionStyle() -> some View {
        self
            .font(AxisTypography.captionFont)
            .tracking(AxisTypography.captionLetterSpacing)
            .lineSpacing(AxisTypography.captionLineHeight - 12)
    }

    /// Applies mono font + line height.
    func axisMonoStyle() -> some View {
        self
            .font(AxisTypography.monoFont)
            .tracking(AxisTypography.monoLetterSpacing)
            .lineSpacing(AxisTypography.monoLineHeight - 13)
    }
}

// MARK: - Font Role Enum (for theming / dynamic type)

/// Semantic font role used across the app.
enum AxisFontRole {
    case display, title, headline, body, caption, mono

    var font: Font {
        switch self {
        case .display:   return AxisTypography.displayFont
        case .title:     return AxisTypography.titleFont
        case .headline:  return AxisTypography.headlineFont
        case .body:      return AxisTypography.bodyFont
        case .caption:   return AxisTypography.captionFont
        case .mono:      return AxisTypography.monoFont
        }
    }

    var size: CGFloat {
        switch self {
        case .display:   return 20
        case .title:     return 17
        case .headline:  return 15
        case .body:      return 14
        case .caption:   return 12
        case .mono:      return 13
        }
    }

    var lineHeight: CGFloat {
        switch self {
        case .display:   return AxisTypography.displayLineHeight
        case .title:     return AxisTypography.titleLineHeight
        case .headline:  return AxisTypography.headlineLineHeight
        case .body:      return AxisTypography.bodyLineHeight
        case .caption:   return AxisTypography.captionLineHeight
        case .mono:      return AxisTypography.monoLineHeight
        }
    }
}
