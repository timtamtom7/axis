import SwiftUI

// MARK: - ComposeView
//
// The input area docked at the bottom of the chat. Auto-expanding
// TextEditor (1–6 lines), send button, and two R1 stub buttons.
//
// Intentionality:
//   ⌘↵ to send — mirrors terminal convention. Enter alone adds newline.
//   Disabled during streaming — prevents interleaved messages that would
//     corrupt the Claude Code CLI's output stream.
//   Voice & attachment are wired stubs — the pipeline exists, just
//     the downstream services (faster-whisper, file picker) are R2.
//   6-line max isn't a hard constraint on message length — users can
//     still scroll within the editor. It's a UX hint to keep messages
//     focused rather than pasting novels.

struct ComposeView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void

    // R1 stub states
    @State private var voiceAlertShown = false
    @State private var attachmentAlertShown = false

    // Line limit before auto-scroll kicks in
    private let maxVisibleLines = 6

    // TextEditor is a plain NSTextView wrapper; we use a State variable
    // to track its content height and clamp it.
    @State private var editorHeight: CGFloat = 36

    var body: some View {
        VStack(spacing: 0) {
            Divider()
                .background(Color.axisBorder)

            HStack(alignment: .bottom, spacing: 8) {
                // Voice input stub
                stubButton(
                    icon: "mic",
                    alertTitle: "Voice Input",
                    alertMessage: "Voice input will be available in R2.",
                    alertShown: $voiceAlertShown
                )

                // Attachment stub
                stubButton(
                    icon: "paperclip",
                    alertTitle: "Attachments",
                    alertMessage: "File and screenshot attachments will be available in R2.",
                    alertShown: $attachmentAlertShown
                )

                // Text editor
                textEditor
                    .frame(minHeight: 36, maxHeight: 6 * 22) // ~22pt per line
                    .fixedSize(horizontal: false, vertical: true)

                // Send button
                sendButton
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color.axisBackground)
        }
    }

    // MARK: - Text Editor

    private var textEditor: some View {
        ZStack(alignment: .topLeading) {
            // Placeholder — overlaid above the TextEditor, hidden when text is non-empty
            Text("Ask Claude...")
                .font(.system(size: 14))
                .foregroundColor(.axisTextTertiary)
                .padding(.horizontal, 4)
                .padding(.vertical, 8)
                .opacity(text.isEmpty ? 1 : 0)
                .allowsHitTesting(false)

            TextEditor(text: $text)
                .font(.system(size: 14))
                .foregroundColor(.axisTextPrimary)
                .scrollContentBackground(.hidden)
                .background(Color.clear)
                .frame(minHeight: 36, maxHeight: 6 * 22)
                .fixedSize(horizontal: false, vertical: true)
                .disabled(isStreaming)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(Color.axisSurface)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.axisBorder, lineWidth: 1)
        )
        .onKeyPress(.return) {
            // Check ⌘↵ — the modifiers come from NSEvent
            #if canImport(AppKit)
            let flags = NSEvent.modifierFlags
            let cmdPressed = flags.contains(.command)
            #else
            let cmdPressed = false
            #endif
            if cmdPressed {
                guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
                    return .handled
                }
                onSend()
                return .handled
            }
            return .ignored
        }
    }

    // MARK: - Send Button

    private var sendButton: some View {
        Button {
            guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
            onSend()
        } label: {
            Image(systemName: "arrow.up.circle.fill")
                .font(.system(size: 28))
                .foregroundColor(
                    canSend ? .axisAccent : .axisTextTertiary
                )
        }
        .buttonStyle(.plain)
        .disabled(!canSend)
    }

    private var canSend: Bool {
        !isStreaming &&
        !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    // MARK: - Stub Button

    private func stubButton(
        icon: String,
        alertTitle: String,
        alertMessage: String,
        alertShown: Binding<Bool>
    ) -> some View {
        Button {
            alertShown.wrappedValue = true
        } label: {
            Image(systemName: icon)
                .font(.system(size: 16))
                .foregroundColor(.axisTextTertiary)
                .frame(width: 28, height: 28)
        }
        .buttonStyle(.plain)
        .alert(alertTitle, isPresented: alertShown) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(alertMessage)
        }
    }
}

// MARK: - Preview

#Preview("Default") {
    ComposeView(
        text: .constant(""),
        isStreaming: false,
        onSend: {}
    )
    .frame(width: 480)
    .background(Color.axisBackground)
}

#Preview("With text") {
    ComposeView(
        text: .constant("How do I set up the project map?"),
        isStreaming: false,
        onSend: {}
    )
    .frame(width: 480)
    .background(Color.axisBackground)
}

#Preview("Streaming (disabled)") {
    ComposeView(
        text: .constant("How do I set up the project map?"),
        isStreaming: true,
        onSend: {}
    )
    .frame(width: 480)
    .background(Color.axisBackground)
}
