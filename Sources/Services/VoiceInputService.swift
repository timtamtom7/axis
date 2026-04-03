import Foundation
import AVFoundation
import Speech
import Combine
import AppKit

// MARK: - VoiceInputService
//
// Privacy-first voice input using on-device speech recognition.
// No network calls — works fully offline on macOS 13+.
//
// Flow:
//   1. User presses ⌥ Space or clicks mic → recording starts
//   2. AVAudioEngine captures audio from input node
//   3. SFSpeechRecognizer streams transcription in real-time
//   4. User releases or clicks again → recording stops, transcript inserted

@MainActor
final class VoiceInputService: ObservableObject {

    // MARK: - Published State

    /// True while actively recording/transcribing.
    @Published private(set) var isRecording = false

    /// Live transcription — updates in real-time as user speaks.
    @Published private(set) var liveTranscript = ""

    /// Error message, if any. Cleared on next successful recording or via clearError().
    @Published var error: VoiceInputError?

    /// True when speech recognition is available and permissions granted.
    @Published private(set) var isAvailable = false

    /// True when permissions have been requested but not yet granted.
    @Published private(set) var needsPermission = false

    // MARK: - Configuration

    struct Config {
        /// Default hotkey: Option + Space (keycode 49).
        var hotkeyKeyCode: UInt16 = 49
        var hotkeyModifiers: NSEvent.ModifierFlags = .option
        /// Require on-device recognition (no network).
        var requiresOnDeviceRecognition = true
    }

    var config = Config()

    // MARK: - Private State

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer: SFSpeechRecognizer?

    /// CGEvent tap for global hotkey.
    private var eventTap: CFMachPort?

    /// Tracks if cleanup has been run.
    private var hasCleanedUp = false

    // MARK: - Singleton

    static let shared = VoiceInputService()

    // MARK: - Init

    init() {
        // Create speech recognizer with user's locale
        speechRecognizer = SFSpeechRecognizer(locale: Locale.current)

        // Check initial availability
        checkAvailability()

        // Register global hotkey
        registerGlobalHotkey()
    }

    // MARK: - Public API

    /// Request microphone + speech recognition permissions.
    /// Call this before the first use of voice input.
    func requestPermissions() {
        needsPermission = true

        SFSpeechRecognizer.requestAuthorization { [weak self] status in
            DispatchQueue.main.async {
                self?.handleSpeechAuthorization(status)
            }
        }
    }

    /// Toggle recording on/off. Returns true if recording started.
    @discardableResult
    func toggleRecording() -> Bool {
        if isRecording {
            _stopRecording()
            return false
        } else {
            return startRecording()
        }
    }

    /// Start recording and transcribing.
    @discardableResult
    func startRecording() -> Bool {
        guard isAvailable else {
            if needsPermission {
                error = .permissionDenied
            } else {
                error = .speechRecognizerUnavailable
            }
            return false
        }

        guard !isRecording else { return true }

        // Reset state
        liveTranscript = ""
        error = nil

        // Set up audio engine
        let engine = AVAudioEngine()
        let inputNode = engine.inputNode

        // Configure format
        let recordingFormat = inputNode.outputFormat(forBus: 0)
        guard recordingFormat.sampleRate > 0 else {
            error = .audioEngineError("Invalid audio format")
            return false
        }

        // Create recognition request
        let request = SFSpeechAudioBufferRecognitionRequest()
        request.shouldReportPartialResults = true
        if #available(macOS 13, *) {
            request.requiresOnDeviceRecognition = config.requiresOnDeviceRecognition
        }

        // Start recognition task
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            error = .speechRecognizerUnavailable
            return false
        }

        let task = recognizer.recognitionTask(with: request) { [weak self] result, taskError in
            guard let self = self else { return }

            if let result = result {
                Task { @MainActor in
                    self.liveTranscript = result.bestTranscription.formattedString
                }
            }

            if taskError != nil || (result?.isFinal ?? false) {
                // Recognition ended naturally
            }
        }

        // Install tap on input node
        inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
            self?.recognitionRequest?.append(buffer)
        }

        // Start engine
        do {
            try engine.start()
        } catch {
            let voiceError = VoiceInputError.audioEngineError(error.localizedDescription)
            self.error = voiceError
            inputNode.removeTap(onBus: 0)
            request.endAudio()
            task.cancel()
            return false
        }

        audioEngine = engine
        recognitionRequest = request
        recognitionTask = task
        isRecording = true

        return true
    }

    /// Stop recording and return the final transcript.
    func stopRecording() -> String {
        _stopRecording()
        return liveTranscript
    }

    /// Internal stop that doesn't return a value.
    private func _stopRecording() {
        guard isRecording else { return }

        audioEngine?.stop()
        audioEngine?.inputNode.removeTap(onBus: 0)

        recognitionRequest?.endAudio()
        recognitionTask?.cancel()

        audioEngine = nil
        recognitionRequest = nil
        recognitionTask = nil
        isRecording = false
    }

    /// Reset transcript without stopping recording.
    func resetTranscript() {
        liveTranscript = ""
    }

    /// Clear the current error.
    func clearError() {
        error = nil
    }

    // MARK: - Availability

    private func checkAvailability() {
        guard let recognizer = speechRecognizer, recognizer.isAvailable else {
            isAvailable = false
            return
        }

        // Check authorization
        let micStatus = AVCaptureDevice.authorizationStatus(for: .audio)
        let speechStatus: SFSpeechRecognizerAuthorizationStatus = SFSpeechRecognizer.authorizationStatus()

        isAvailable = micStatus == .authorized && speechStatus == .authorized
        needsPermission = micStatus == .notDetermined || speechStatus == .notDetermined
    }

    // MARK: - Permission Handling

    private func handleSpeechAuthorization(_ status: SFSpeechRecognizerAuthorizationStatus) {
        switch status {
        case .authorized:
            AVCaptureDevice.requestAccess(for: .audio) { [weak self] granted in
                DispatchQueue.main.async {
                    self?.needsPermission = false
                    self?.isAvailable = granted
                    if !granted {
                        self?.error = .permissionDenied
                    }
                }
            }

        case .denied, .restricted:
            needsPermission = false
            isAvailable = false
            error = .permissionDenied

        case .notDetermined:
            // Still waiting
            break

        @unknown default:
            break
        }
    }

    // MARK: - Global Hotkey (⌥ Space via CGEvent Tap)

    /// Re-register the global hotkey (call after permission changes).
    func refreshGlobalHotkey() {
        unregisterGlobalHotkey()
        registerGlobalHotkey()
    }

    private func registerGlobalHotkey() {
        let eventMask = (1 << CGEventType.keyDown.rawValue) | (1 << CGEventType.keyUp.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon = refcon else { return Unmanaged.passRetained(event) }

            let service = Unmanaged<VoiceInputService>.fromOpaque(refcon).takeUnretainedValue()

            if type == .keyDown {
                let flags = event.flags
                let keyCode = event.getIntegerValueField(.keyboardEventKeycode)

                if keyCode == Int64(service.config.hotkeyKeyCode) &&
                   flags.contains(.maskAlternate) &&
                   !flags.contains(.maskCommand) &&
                   !flags.contains(.maskControl) {
                    Task { @MainActor in
                        service.toggleRecording()
                    }
                    return nil // Consume event
                }
            }

            return Unmanaged.passRetained(event)
        }

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: callback,
            userInfo: Unmanaged.passUnretained(self).toOpaque()
        ) else {
            print("[VoiceInput] Failed to create event tap. Check Accessibility permissions in System Settings.")
            return
        }

        eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        print("[VoiceInput] Global hotkey registered (⌥ Space)")
    }

    private func unregisterGlobalHotkey() {
        guard let tap = eventTap else { return }
        CGEvent.tapEnable(tap: tap, enable: false)
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        eventTap = nil
    }

    // MARK: - System Settings

    /// Open System Settings > Privacy & Security > Microphone or Speech.
    func openSettings() {
        if #available(macOS 13, *) {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Microphone") {
                NSWorkspace.shared.open(url)
            }
        } else {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_SpeechRecognition") {
                NSWorkspace.shared.open(url)
            }
        }
    }

    // MARK: - Cleanup

    func cleanup() {
        guard !hasCleanedUp else { return }
        hasCleanedUp = true
        _stopRecording()
        unregisterGlobalHotkey()
    }
}

// MARK: - VoiceInputError

enum VoiceInputError: Error, LocalizedError, Identifiable {
    case permissionDenied
    case speechRecognizerUnavailable
    case audioEngineError(String)

    var id: String { localizedDescription }

    var errorDescription: String? {
        switch self {
        case .permissionDenied:
            return "Microphone or speech recognition access was denied. Please enable it in System Settings."
        case .speechRecognizerUnavailable:
            return "Speech recognition is not available on this device."
        case .audioEngineError(let message):
            return "Audio engine error: \(message)"
        }
    }

    var recoverySuggestion: String? {
        switch self {
        case .permissionDenied:
            return "Open System Settings and grant microphone and speech recognition access."
        case .speechRecognizerUnavailable:
            return "Try again later or restart the app."
        case .audioEngineError:
            return "Try disconnecting any external microphones."
        }
    }
}
