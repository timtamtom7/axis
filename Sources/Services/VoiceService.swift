import Foundation
import AppKit
import Combine

/// Voice input service stub for R2
/// Structure is ready for faster-whisper integration in R3
final class VoiceService: NSObject, ObservableObject {
    static let shared = VoiceService()

    @Published private(set) var isRecording = false
    @Published private(set) var lastTranscript = ""

    private var audioEngine: AVAudioEngine?
    private var recordingStartTime: Date?

    // MARK: - Public API

    /// Starts recording and returns a publisher that emits the transcript when done
    /// For R2: shows alert "Voice input coming in R3"
    func record() -> AnyPublisher<String, Error> {
        // R2 stub: show alert and return empty publisher
        showR3Alert()
        return Empty().eraseToAnyPublisher()
    }

    /// Stops recording and returns the transcript
    /// For R2: returns empty string
    func stop() -> String {
        isRecording = false
        return ""
    }

    /// Check if voice input is available
    var isAvailable: Bool {
        // R2: not available yet
        return false
    }

    // MARK: - Private

    private func showR3Alert() {
        DispatchQueue.main.async {
            let alert = NSAlert()
            alert.messageText = "Voice Input"
            alert.informativeText = "Voice input coming in R3"
            alert.alertStyle = .informational
            alert.addButton(withTitle: "OK")
            alert.runModal()
        }
    }

    // MARK: - R3 Placeholder (for faster-whisper integration)

    /// Placeholder for R3 audio recording implementation
    private func startAudioRecording() {
        // TODO(R3): Implement with faster-whisper
        // 1. Set up AVAudioEngine
        // 2. Configure audio session
        // 3. Start capturing audio buffers
        // 4. Process with whisper.cpp or faster-whisper
    }

    /// Placeholder for R3 transcription
    private func transcribeAudio(data: Data) -> String {
        // TODO(R3): Integrate faster-whisper
        return ""
    }
}

// MARK: - Audio Session Configuration (R3 placeholder)

extension VoiceService {
    private func configureAudioSession() {
        // TODO(R3): Configure AVAudioSession for voice recording
        // let session = AVAudioSession.sharedInstance()
        // try? session.setCategory(.record, mode: .measurement, options: .duckOthers)
        // try? session.setActive(true)
    }

    private func deactivateAudioSession() {
        // TODO(R3): Deactivate audio session
        // try? AVAudioSession.sharedInstance().setActive(false, options: .notifyOthersOnDeactivation)
    }
}
