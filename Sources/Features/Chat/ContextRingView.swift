import SwiftUI

// MARK: - ContextRingView
//
// A collapsible token meter docked at the very bottom of the chat.
// Shows total tokens / 200k limit with a color-coded bar.
// Tap to expand: reveals per-component breakdown.
//
// Intentionality:
//   Context management is AXISBlueprint's core job. The ring makes the
//   invisible (token count) visible and actionable. Without it, users
//   hit the context ceiling without warning — leading to forced compactions
//   that lose important context mid-conversation.
//
//   We chose a ring (not a percentage number) because:
//     - It's scannable at a glance — color pops faster than a number
//     - It doesn't compete with the chat content visually
//     - It's a physical metaphor that maps to "filling up"
//
//   R1 decision: collapsed by default, 32pt. This is the right tradeoff —
//   the ring is visible but doesn't eat chat real estate. Users who care
//   about context will tap to expand. Users in flow can ignore it.

struct ContextRingView: View {
    let metrics: ContextMetrics
    @State private var isExpanded = false

    // Collapsed height — the default state
    private let collapsedHeight: CGFloat = 32

    var body: some View {
        VStack(spacing: 0) {
            // Main ring bar — always visible
            ringBar
                .frame(height: collapsedHeight)

            // Expanded breakdown — toggled on tap
            if isExpanded {
                breakdownView
                    .transition(.opacity.combined(with: .move(edge: .bottom)))
            }
        }
        .background(Color.axisSurface)
        .overlay(alignment: .top) {
            Divider()
                .background(Color.axisBorder)
        }
        .contentShape(Rectangle())
        .onTapGesture {
            withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                isExpanded.toggle()
            }
        }
    }

    // MARK: - Ring Bar (Collapsed)

    private var ringBar: some View {
        HStack(spacing: 12) {
            // Token label
            Text("Tokens:")
                .font(.system(size: 11, weight: .medium))
                .foregroundColor(.axisTextSecondary)

            // Progress bar
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    // Track
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color.axisSurfaceElevated)
                        .frame(height: 6)

                    // Fill
                    RoundedRectangle(cornerRadius: 3)
                        .fill(metrics.thresholdWarning)
                        .frame(width: fillWidth(in: geometry), height: 6)
                        .animation(.easeInOut(duration: 0.3), value: metrics.totalTokens)
                }
            }
            .frame(height: 6)

            // Fraction text
            Text("\(metrics.totalTokenString) / \(metrics.limitTokenString)")
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(.axisTextSecondary)

            // Expand chevron
            Image(systemName: isExpanded ? "chevron.down" : "chevron.up")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(.axisTextTertiary)
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 16)
    }

    // MARK: - Fill Width

    private func fillWidth(in geometry: GeometryProxy) -> CGFloat {
        let fraction = min(metrics.usageFraction, 1.0)
        return geometry.size.width * CGFloat(fraction)
    }

    // MARK: - Breakdown View (Expanded)

    private var breakdownView: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.axisBorder)

            VStack(spacing: 6) {
                componentRow("App prompt", tokens: metrics.appPromptTokens)
                componentRow("Global MD", tokens: metrics.globalMDTokens)
                componentRow("Project MD", tokens: metrics.projectMDTokens)
                componentRow("Memory files", tokens: metrics.memoryTokens)
                componentRow("Skills", tokens: metrics.skillsTokens)
                componentRow("Agents", tokens: metrics.agentsTokens)
                componentRow("Conversation", tokens: metrics.conversationTokens)

                Divider()
                    .background(Color.axisBorder)

                HStack {
                    Text("Total")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(.axisTextPrimary)
                    Spacer()
                    Text("\(metrics.totalTokenString) / \(metrics.limitTokenString)")
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.axisTextPrimary)
                }
                .padding(.top, 2)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .background(Color.axisSurfaceElevated)
    }

    private func componentRow(_ label: String, tokens: Int) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 11))
                .foregroundColor(.axisTextSecondary)
            Spacer()
            Text(metrics.toTokenString(tokens))
                .font(.system(size: 11, design: .monospaced))
                .foregroundColor(tokens > 0 ? .axisTextPrimary : .axisTextTertiary)
        }
    }
}

// MARK: - Previews

#Preview("Healthy (<50%)") {
    ContextRingView(metrics: .preview)
        .frame(width: 480)
}

#Preview("Warning (50–80%)") {
    ContextRingView(metrics: .previewWarning)
        .frame(width: 480)
}

#Preview("Critical (>80%)") {
    ContextRingView(metrics: .previewCritical)
        .frame(width: 480)
}

#Preview("Expanded") {
    ContextRingView(metrics: .preview)
        .frame(width: 480)
}
