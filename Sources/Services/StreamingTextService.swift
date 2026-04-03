import Foundation
import Combine

/// Represents a parsed event from a streaming response
struct StreamEvent: Identifiable, Equatable {
    let id = UUID()
    let type: EventType
    let content: String

    enum EventType: String, Equatable {
        case token
        case toolCall = "tool_call"
        case eom // end of message
        case error
    }

    static func token(_ content: String) -> StreamEvent {
        StreamEvent(type: .token, content: content)
    }

    static func toolCall(_ content: String) -> StreamEvent {
        StreamEvent(type: .toolCall, content: content)
    }

    static let eom = StreamEvent(type: .eom, content: "")
    static func error(_ content: String) -> StreamEvent {
        StreamEvent(type: .error, content: content)
    }
}

/// Service for parsing Claude Code streaming output (SSE-like events)
@MainActor
final class StreamingTextService: ObservableObject {
    static let shared = StreamingTextService()

    @Published private(set) var currentTokens: [String] = []
    @Published private(set) var currentToolCalls: [String] = []
    @Published private(set) var isStreaming = false

    private var buffer = ""

    // MARK: - Public API

    /// Parse a single line from the stream
    /// Returns a StreamEvent if the line contains a complete event
    func parseStream(line: String) -> StreamEvent? {
        let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)

        // Skip empty lines and SSE preamble
        if trimmed.isEmpty || trimmed.hasPrefix(":") || trimmed.hasPrefix("data:") == false {
            return nil
        }

        // Remove "data: " prefix
        let data = trimmed.dropFirst(5).trimmingCharacters(in: .whitespaces)

        // Parse SSE data
        return parseEventData(data)
    }

    /// Process a complete stream and emit events
    func processStream(lines: [String]) -> AnyPublisher<StreamEvent, Never> {
        let subject = PassthroughSubject<StreamEvent, Never>()

        Task {
            for line in lines {
                if let event = parseStream(line: line) {
                    subject.send(event)
                }
            }
            subject.send(StreamEvent.eom)
            subject.send(completion: .finished)
        }

        return subject.eraseToAnyPublisher()
    }

    /// Reset state for a new stream
    func reset() {
        currentTokens = []
        currentToolCalls = []
        buffer = ""
        isStreaming = false
    }

    /// Start tracking a new stream
    func startStream() {
        reset()
        isStreaming = true
    }

    /// Finalize and return accumulated content
    func finalizeStream() -> (tokens: String, toolCalls: [String]) {
        isStreaming = false
        return (currentTokens.joined(), currentToolCalls)
    }

    // MARK: - Private

    private func parseEventData(_ data: String) -> StreamEvent? {
        // Claude Code streaming format (SSE):
        // data: {"type": "content_block", "content": "..."}
        // data: {"type": "content_block", "content": "...", "type": "tool_use"}
        // data: {"type": "done"}

        // Try to parse as JSON
        guard let jsonData = data.data(using: .utf8),
              let json = try? JSONSerialization.jsonObject(with: jsonData) as? [String: Any] else {
            // Fallback: treat as plain token
            if !data.isEmpty {
                currentTokens.append(data)
                return .token(data)
            }
            return nil
        }

        // Check event type
        if let type = json["type"] as? String {
            switch type {
            case "content_block", "text":
                if let content = json["content"] as? String {
                    currentTokens.append(content)
                    return .token(content)
                }

            case "tool_use", "tool_call":
                if let name = json["name"] as? String,
                   let input = json["input"] as? [String: Any],
                   let inputJson = try? JSONSerialization.data(withJSONObject: input),
                   let inputString = String(data: inputJson, encoding: .utf8) {
                    let toolCall = "\(name)(\(inputString))"
                    currentToolCalls.append(toolCall)
                    return .toolCall(toolCall)
                }

            case "done", "end":
                return StreamEvent.eom

            case "error":
                let message = json["message"] as? String ?? "Unknown error"
                return .error(message)

            default:
                break
            }
        }

        // Fallback: check for content field directly
        if let content = json["content"] as? String {
            currentTokens.append(content)
            return .token(content)
        }

        return nil
    }

    // MARK: - SSE Parsing Helpers

    /// Check if line is the end of an SSE event
    func isEndOfEvent(_ line: String) -> Bool {
        line == "" || line == "\n" || line == "\r\n"
    }

    /// Extract event type from SSE event line
    func extractEventType(_ line: String) -> String? {
        guard line.hasPrefix("event:") else { return nil }
        return String(line.dropFirst(6)).trimmingCharacters(in: .whitespaces)
    }
}

// MARK: - Convenience Extensions

extension StreamingTextService {
    /// Create a publisher that processes lines from a stream URL
    static func streamPublisher(from url: URL) -> AnyPublisher<StreamEvent, Error> {
        // Placeholder for URLSession streaming
        // TODO: Implement with URLSession stream
        return Empty().eraseToAnyPublisher()
    }
}
