import SwiftUI
import Combine

// MARK: - ComposeView
//
// The input area docked at the bottom of the chat. Auto-expanding
// TextEditor (1–6 lines), send button, and two R1 stub buttons.
//
// Intentionality:
//   ⌘↵ to send — mirrors terminal convention. Enter alone adds newline.
//   Disabled during streaming — prevents interleaved messages that would
//     corrupt the Claude Code CLI's output stream.
//   Voice input via ⌥ Space global hotkey or mic button — on-device,
//     privacy-first transcription via SFSpeechRecognizer.
//   6-line max isn't a hard constraint on message length — users can
//     still scroll within the editor. It's a UX hint to keep messages
//     focused rather than pasting novels.

struct ComposeView: View {
    @Binding var text: String
    let isStreaming: Bool
    let onSend: () -> Void

    // Voice input
    @StateObject private var voiceService = VoiceInputService.shared
    @State private var attachmentAlertShown = false

    var body: some View {
        VStack(spacing: 0) {
            // Live transcript strip — appears above input while recording
            if voiceService.isRecording && !voiceService.liveTranscript.isEmpty {
                liveTranscriptBar
            }

            Divider()
                .background(Color.axisBorder)

            HStack(alignment: .bottom, spacing: 8) {
                // Voice input button (replaces stub)
                voiceMicButton

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

            // Permission/error banner
            if let error = voiceService.error {
                voiceErrorBar(error: error)
            }
        }
        .onAppear {
            // Request permissions on first use
            if voiceService.needsPermission {
                voiceService.requestPermissions()
            }
        }
        // Sync live transcript into text field when recording stops
        .onChange(of: voiceService.isRecording) { _, recording in
            if !recording && !voiceService.liveTranscript.isEmpty {
                // Recording stopped — insert transcript into text
                let transcript = voiceService.liveTranscript.trimmingCharacters(in: .whitespacesAndNewlines)
                if !transcript.isEmpty {
                    if text.isEmpty {
                        text = transcript
                    } else {
                        text += " " + transcript
                    }
                }
            }
        }
    }

    // MARK: - Live Transcript Bar

    private var liveTranscriptBar: some View {
        HStack(spacing: 8) {
            // Pulsing red dot
            Circle()
                .fill(Color.axisDestructive)
                .frame(width: 8, height: 8)
                .modifier(PulseAnimation())

            Text(voiceService.liveTranscript)
                .font(.system(size: 12))
                .foregroundColor(.axisTextSecondary)
                .lineLimit(2)
                .truncationMode(.tail)
                .frame(maxWidth: .infinity, alignment: .leading)

            Text("⌥ Space to stop")
                .font(.system(size: 10))
                .foregroundColor(.axisTextTertiary)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.axisDestructiveTint)
    }

    // MARK: - Voice Mic Button

    private var voiceMicButton: some View {
        Button {
            handleMicTap()
        } label: {
            MicButtonLabel(isRecording: voiceService.isRecording, color: micButtonColor)
        }
        .buttonStyle(.plain)
        .disabled(!voiceService.isAvailable && !voiceService.isRecording)
        .help(voiceHelpText)
    }

    private var micButtonColor: Color {
        voiceService.isAvailable ? .axisTextTertiary : .axisTextTertiary.opacity(0.4)
    }

    private var voiceHelpText: String {
        if !voiceService.isAvailable {
            return "Voice input unavailable — check permissions in System Settings"
        } else if voiceService.isRecording {
            return "Stop recording (⌥ Space)"
        } else {
            return "Start voice input (⌥ Space)"
        }
    }

    private func handleMicTap() {
        if !voiceService.isAvailable {
            voiceService.openSettings()
            return
        }
        voiceService.toggleRecording()
    }

    // MARK: - Error Bar

    private func voiceErrorBar(error: VoiceInputError) -> some View {
        HStack {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.axisWarning)

            Text(error.localizedDescription)
                .font(.system(size: 12))
                .foregroundColor(.axisTextSecondary)

            Spacer()

            Button("Open Settings") {
                voiceService.openSettings()
            }
            .buttonStyle(.plain)
            .font(.system(size: 12, weight: .medium))
            .foregroundColor(.axisAccent)

            Button {
                voiceService.error = nil
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10))
                    .foregroundColor(.axisTextTertiary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color.axisWarningTint)
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

// MARK: - MicButtonLabel

/// Label view for the mic button, with pulse animation when recording.
struct MicButtonLabel: View {
    let isRecording: Bool
    let color: Color

    @State private var isPulsing = false

    var body: some View {
        Image(systemName: isRecording ? "mic.fill" : "mic")
            .font(.system(size: 16))
            .foregroundColor(isRecording ? .axisDestructive : color)
            .frame(width: 28, height: 28)
            .opacity(isPulsing ? 0.5 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.6).repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onChange(of: isRecording) { _, newValue in
                isPulsing = newValue
            }
            .onAppear { isPulsing = isRecording }
    }
}

// MARK: - PulseAnimation

/// Simple opacity pulse modifier for the recording indicator.
struct PulseAnimation: ViewModifier {
    @State private var isPulsing = false

    func body(content: Content) -> some View {
        content
            .opacity(isPulsing ? 0.4 : 1.0)
            .animation(
                Animation.easeInOut(duration: 0.6)
                    .repeatForever(autoreverses: true),
                value: isPulsing
            )
            .onAppear { isPulsing = true }
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
