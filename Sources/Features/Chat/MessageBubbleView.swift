import SwiftUI

// MARK: - MessageBubbleView
//
// Renders a single message in the chat stream. Five visual variants:
//
//   .user    — Right-aligned, accent blue background, white text
//   .claude  — Left-aligned, surface background, primary text
//   .tool    — Mono font, elevated surface, collapsible (R1: static)
//   .thinking— Italic, tertiary text, collapsed by default
//   .tombstone— Dashed border, tertiary italic text, placeholder
//
// Interactions:
//   Hover → reveals action bar: copy / delete / trim
//   Streaming → blinking cursor appended to text
//
// Why these five types?
//   Claude's output has fundamentally different shapes:
//     - prose (readable, selectable)
//     - code / structured output (mono, may need collapsing)
//     - internal reasoning (always collapsible — distracting if shown)
//     - tombstones (preserved for conversation continuity)
//   Treating them all as "text" loses meaning. The types carry intent.

struct MessageBubbleView: View {
    let message: Message
    let isStreaming: Bool

    // Hover state — shown via GeometryReader trick since
    // iOS 17's onHover doesn't propagate cleanly in scroll views.
    @State private var isHovered = false

    // Tool output collapsed state (R1: always expanded, toggle wired for future)
    @State private var isToolCollapsed = false

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            if message.role == .user {
                Spacer(minLength: 60)
            }

            bubbleContent
                .modifier(HoverTrackingModifier(isHovered: $isHovered))

            if message.role != .user {
                Spacer(minLength: 60)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 4)
        .background(hoverBackground)
    }

    // MARK: - Bubble Content

    @ViewBuilder
    private var bubbleContent: some View {
        switch message.messageType {
        case .tombstone:
            tombstoneBubble

        case .thinking:
            thinkingBubble

        case .tool:
            toolBubble

        case .text:
            if message.role == .user {
                userBubble
            } else {
                claudeBubble
            }
        }
    }

    // MARK: - User Bubble

    private var userBubble: some View {
        Text(message.content)
            .font(.system(size: 14, weight: .regular))
            .foregroundColor(.white)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color.axisAccent)
            .cornerRadius(16, corners: .userBubbleCorners)
            .overlay(alignment: .topLeading) {
                actionBar
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
    }

    // MARK: - Claude Bubble

    private var claudeBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            // Claude avatar dot
            Circle()
                .fill(Color.axisAccentSecondary)
                .frame(width: 8, height: 8)
                .padding(.top, 6)

            VStack(alignment: .leading, spacing: 4) {
                Text(message.content)
                    .font(.system(size: 14, weight: .regular))
                    .foregroundColor(.axisTextPrimary)
                    + streamingCursor

                actionBar
                    .opacity(isHovered ? 1 : 0)
                    .animation(.easeInOut(duration: 0.15), value: isHovered)
            }
        }
        .padding(12)
        .background(Color.axisSurface)
        .cornerRadius(12, corners: .claudeBubbleCorners)
    }

    // MARK: - Tool Bubble

    private var toolBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "terminal")
                .font(.system(size: 11))
                .foregroundColor(.axisTextSecondary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Tool Output")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.axisTextSecondary)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isToolCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isToolCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10))
                            .foregroundColor(.axisTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if !isToolCollapsed {
                    Text(message.content)
                        .font(.system(size: 13, design: .monospaced))
                        .foregroundColor(.axisTextPrimary)
                        .textSelection(.enabled)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(Color.axisSurfaceElevated)
        .cornerRadius(8)
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.axisBorder, lineWidth: 1)
        )
    }

    // MARK: - Thinking Bubble

    private var thinkingBubble: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "brain.head.profile")
                .font(.system(size: 11))
                .foregroundColor(.axisTextTertiary)
                .padding(.top, 2)

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text("Thinking")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundColor(.axisTextTertiary)

                    Spacer()

                    Button {
                        withAnimation(.spring(response: 0.25, dampingFraction: 0.8)) {
                            isToolCollapsed.toggle()
                        }
                    } label: {
                        Image(systemName: isToolCollapsed ? "chevron.down" : "chevron.up")
                            .font(.system(size: 10))
                            .foregroundColor(.axisTextTertiary)
                    }
                    .buttonStyle(.plain)
                }

                if !isToolCollapsed {
                    Text(message.content)
                        .font(.system(size: 13)
                            .italic())
                        .foregroundColor(.axisTextSecondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .padding(12)
        .background(Color.axisSurfaceElevated.opacity(0.5))
        .cornerRadius(8)
    }

    // MARK: - Tombstone Bubble

    private var tombstoneBubble: some View {
        HStack {
            Spacer()
            Text(message.content)
                .font(.system(size: 13)
                    .italic())
                .foregroundColor(.axisTextTertiary)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    Color.axisSurfaceElevated
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .strokeBorder(style: StrokeStyle(lineWidth: 1, dash: [4, 3]))
                                .foregroundColor(.axisTextTertiary)
                        )
                )
                .cornerRadius(8)
            Spacer()
        }
    }

    // MARK: - Action Bar

    private var actionBar: some View {
        HStack(spacing: 12) {
            Button {
                copyToClipboard()
            } label: {
                Label("Copy", systemImage: "doc.on.doc")
                    .font(.system(size: 11))
                    .foregroundColor(.axisTextSecondary)
            }
            .buttonStyle(.plain)

            Button {
                // Emit delete action — handled by parent via binding/closure
            } label: {
                Label("Delete", systemImage: "trash")
                    .font(.system(size: 11))
                    .foregroundColor(.axisDestructive)
            }
            .buttonStyle(.plain)

            Button {
                // Emit trim action — parent handles surgical trim
            } label: {
                Label("Trim", systemImage: "scissors")
                    .font(.system(size: 11))
                    .foregroundColor(.axisTextSecondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 4)
    }

    // MARK: - Streaming Cursor

    /// Returns a blinking cursor Text when streaming, empty Text otherwise.
    /// Both branches return Text so the + concatenation in claudeBubble works.
    private var streamingCursor: Text {
        if isStreaming {
            return Text("▋")
                .font(.system(size: 14))
                .foregroundColor(.axisAccent)
        }
        return Text("")
    }

    // MARK: - Hover Background

    @ViewBuilder
    private var hoverBackground: some View {
        if isHovered && message.messageType != .tombstone {
            Color.axisSurfaceElevated.opacity(0.3)
        } else {
            Color.clear
        }
    }

    // MARK: - Helpers

    private func copyToClipboard() {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(message.content, forType: .string)
        #endif
    }
}

// MARK: - Hover Tracking Modifier
//
// Workaround for onHover not propagating reliably inside ScrollView/LazyVStack.
// Uses a transparent overlay hit-test area. GeometryReader is avoided because
// it triggers layout on every frame — a transparent overlay on the stack is cheaper.

struct HoverTrackingModifier: ViewModifier {
    @Binding var isHovered: Bool

    func body(content: Content) -> some View {
        content
            .overlay(
                GeometryReader { _ in
                    Color.clear
                        .contentShape(Rectangle())
                        .onHover { hovering in
                            isHovered = hovering
                        }
                }
                .frame(width: 0, height: 0)
            )
    }
}

// MARK: - Corner Radius Extension
// Selective corner rounding using a custom path. Works cross-platform
// without needing AppKit/UIKit corner mask types.

extension View {
    /// Rounds specific corners of a view.
    func cornerRadius(_ radius: CGFloat, corners: ChatBubbleCorner) -> some View {
        clipShape(ChatBubbleShape(radius: radius, corners: corners))
    }
}

/// Which corners to round on a chat bubble.
struct ChatBubbleCorner: OptionSet {
    let rawValue: Int
    static let topLeft     = ChatBubbleCorner(rawValue: 1 << 0)
    static let topRight    = ChatBubbleCorner(rawValue: 1 << 1)
    static let bottomLeft  = ChatBubbleCorner(rawValue: 1 << 2)
    static let bottomRight = ChatBubbleCorner(rawValue: 1 << 3)

    static let userBubbleCorners: ChatBubbleCorner = [.topLeft, .topRight, .bottomLeft]
    static let claudeBubbleCorners: ChatBubbleCorner = [.topLeft, .topRight, .bottomRight]
}

/// Custom shape for selective corner rounding without AppKit dependency.
struct ChatBubbleShape: Shape {
    let radius: CGFloat
    let corners: ChatBubbleCorner

    func path(in rect: CGRect) -> Path {
        var path = Path()

        let r = min(radius, rect.width / 2, rect.height / 2)

        let topLeft      = CGPoint(x: rect.minX, y: rect.maxY)
        let topRight     = CGPoint(x: rect.maxX, y: rect.maxY)
        let bottomRight  = CGPoint(x: rect.maxX, y: rect.minY)
        let bottomLeft   = CGPoint(x: rect.minX, y: rect.minY)

        path.move(to: CGPoint(x: rect.minX + (corners.contains(.topLeft) ? r : 0),
                               y: rect.maxY))

        if corners.contains(.topLeft) {
            path.addArc(
                center: CGPoint(x: rect.minX + r, y: rect.maxY - r),
                radius: r, startAngle: .degrees(90), endAngle: .degrees(180),
                clockwise: true
            )
        } else {
            path.addLine(to: topLeft)
        }

        if corners.contains(.bottomLeft) {
            path.addArc(
                center: CGPoint(x: rect.minX + r, y: rect.minY + r),
                radius: r, startAngle: .degrees(180), endAngle: .degrees(270),
                clockwise: true
            )
        } else {
            path.addLine(to: bottomLeft)
        }

        if corners.contains(.bottomRight) {
            path.addArc(
                center: CGPoint(x: rect.maxX - r, y: rect.minY + r),
                radius: r, startAngle: .degrees(270), endAngle: .degrees(0),
                clockwise: true
            )
        } else {
            path.addLine(to: bottomRight)
        }

        if corners.contains(.topRight) {
            path.addArc(
                center: CGPoint(x: rect.maxX - r, y: rect.maxY - r),
                radius: r, startAngle: .degrees(0), endAngle: .degrees(90),
                clockwise: true
            )
        } else {
            path.addLine(to: topRight)
        }

        path.closeSubpath()
        return path
    }
}

// MARK: - Previews

#Preview("User message") {
    MessageBubbleView(
        message: .user("How do I set up the project map?"),
        isStreaming: false
    )
    .background(Color.axisBackground)
}

#Preview("Claude message") {
    MessageBubbleView(
        message: .claude("The project map shows how your files connect. Let me open the map view."),
        isStreaming: false
    )
    .background(Color.axisBackground)
}

#Preview("Claude streaming") {
    MessageBubbleView(
        message: .claude("Here's what I found"),
        isStreaming: true
    )
    .background(Color.axisBackground)
}

#Preview("Tool output") {
    MessageBubbleView(
        message: .tool("Reading: Sources/App/AxisBlueprintApp.swift\nLines: 45\nModified"),
        isStreaming: false
    )
    .background(Color.axisBackground)
}

#Preview("Thinking") {
    MessageBubbleView(
        message: .thinking("The user is asking about project setup. I should check the SPEC.md first to understand the architecture."),
        isStreaming: false
    )
    .background(Color.axisBackground)
}

#Preview("Tombstone") {
    MessageBubbleView(
        message: Message.tombstone(from: .claude("old content")),
        isStreaming: false
    )
    .background(Color.axisBackground)
}
