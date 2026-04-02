import SwiftUI

// MARK: - AXISBlueprint Spacing System
// 4pt base unit. All spacing values are multiples of 4.
// Design reference: 9-grid Apple spacing + Raycast density.

/// Holds all spacing design tokens.
enum AxisSpacing {
    // MARK: - Spacing Scale

    /// 2pt — Hairline gaps, icon-to-label micro spacing.
    static let space1: CGFloat = 2

    /// 4pt — Tight grouping, inline element separation.
    static let space2: CGFloat = 4

    /// 8pt — Standard component internal padding (icon + label), list item compact gaps.
    static let space3: CGFloat = 8

    /// 12pt — Input field internal padding (horizontal), card section gaps.
    static let space4: CGFloat = 12

    /// 16pt — Standard padding: card edges, section separators, popover margins.
    static let space5: CGFloat = 16

    /// 20pt — Large section padding, between major layout blocks.
    static let space6: CGFloat = 20

    /// 24pt — Major layout dividers, large card padding.
    static let space7: CGFloat = 24

    /// 32pt — Between major sections (header ↔ content ↔ footer in popover).
    static let space8: CGFloat = 32

    /// 40pt — Large gaps: hero sections, empty state illustrations.
    static let space9: CGFloat = 40

    /// 48pt — Maximum spacing: screen-level margins in expanded window mode.
    static let space10: CGFloat = 48

    // MARK: - Corner Radii

    /// 6pt — Small buttons, badge chips, compact inputs.
    static let radiusSmall: CGFloat = 6

    /// 10pt — Standard inputs, text fields, search bars.
    static let radiusMedium: CGFloat = 10

    /// 14pt — Cards, panels, message bubbles, modals.
    static let radiusLarge: CGFloat = 14

    /// 20pt — Large modals, dialog overlays, popover when expanded to window.
    static let radiusXLarge: CGFloat = 20

    // MARK: - Popover Dimensions

    /// Default popover size.
    static let popoverDefaultWidth: CGFloat  = 480
    static let popoverDefaultHeight: CGFloat = 640

    /// Expanded window size.
    static let windowDefaultWidth: CGFloat  = 800
    static let windowDefaultHeight: CGFloat = 700

    // MARK: - Icon Sizes

    /// 12pt — Small icons: inline with caption text, badge icons.
    static let iconSizeSmall: CGFloat = 12

    /// 16pt — Standard icons: toolbar buttons, list item icons, tab bar.
    static let iconSizeStandard: CGFloat = 16

    /// 20pt — Large icons: empty state illustrations, feature icons.
    static let iconSizeLarge: CGFloat = 20

    /// 24pt — Extra large: header icons, special callouts.
    static let iconSizeXLarge: CGFloat = 24

    // MARK: - Component Heights

    /// Standard row height for list items, chat message rows.
    static let rowHeightStandard: CGFloat = 44

    /// Compact row: history list, skill list.
    static let rowHeightCompact: CGFloat = 36

    /// Text input minimum height (1 line).
    static let inputMinHeight: CGFloat = 36

    /// Text input maximum height (6 lines before scroll).
    static let inputMaxHeight: CGFloat = 144

    // MARK: - Shadows

    /// Subtle drop shadow for cards and elevated surfaces.
    static let shadowSubtle = AxisShadow(
        color: Color.black.opacity(0.25),
        radius: 8,
        x: 0,
        y: 2
    )

    /// Medium shadow for floating elements: dropdowns, tooltips.
    static let shadowMedium = AxisShadow(
        color: Color.black.opacity(0.35),
        radius: 16,
        x: 0,
        y: 4
    )

    /// Strong shadow for modal overlays, expanded panels.
    static let shadowStrong = AxisShadow(
        color: Color.black.opacity(0.5),
        radius: 32,
        x: 0,
        y: 8
    )
}

// MARK: - Shadow Value Type

/// A simple shadow descriptor, applied via `.shadow(color:radius:x:y:)` modifier.
struct AxisShadow {
    let color: Color
    let radius: CGFloat
    let x: CGFloat
    let y: CGFloat
}

extension View {
    /// Applies a named shadow to a surface.
    func axisShadow(_ shadow: AxisShadow) -> some View {
        self.shadow(color: shadow.color, radius: shadow.radius, x: shadow.x, y: shadow.y)
    }

    /// Applies subtle surface shadow.
    func axisShadowSubtle() -> some View {
        self.axisShadow(AxisSpacing.shadowSubtle)
    }

    /// Applies medium floating shadow.
    func axisShadowMedium() -> some View {
        self.axisShadow(AxisSpacing.shadowMedium)
    }

    /// Applies strong modal shadow.
    func axisShadowStrong() -> some View {
        self.axisShadow(AxisSpacing.shadowStrong)
    }
}

// MARK: - Separator

/// A 1px horizontal divider using axisBorder.
struct AxisSeparator: View {
    var body: some View {
        Rectangle()
            .fill(Color.axisBorder)
            .frame(height: 1)
    }
}

// MARK: - Divider with Vertical Spacing

/// A section divider with consistent padding around it.
struct AxisSectionDivider: View {
    let spacing: CGFloat

    init(spacing: CGFloat = AxisSpacing.space5) {
        self.spacing = spacing
    }

    var body: some View {
        VStack(spacing: spacing) {
            AxisSeparator()
        }
    }
}
