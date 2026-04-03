import Foundation

// MARK: - ChatSearch
//
// Semantic (R1: basic text) search across all chat history.
// `search(query:)` returns ranked results with highlighted snippets.

struct ChatSearch {
    private let storage: ChatStorage

    init(storage: ChatStorage) {
        self.storage = storage
    }

    // MARK: - Search

    /// Search across all chats by title and message content.
    /// Returns results ranked by relevance score.
    func search(query: String) -> [ChatSearchResult] {
        guard !query.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return []
        }

        let lowercased = query.lowercased()
        let manifests = (try? storage.listChats()) ?? []

        var results: [ChatSearchResult] = []

        for manifest in manifests {
            var relevanceScore: Double = 0
            var bestSnippet: String?

            // Title match (highest weight)
            if manifest.title.lowercased().contains(lowercased) {
                relevanceScore += 100
                bestSnippet = highlight(manifest.title, query: lowercased)
            }

            // Preview match (medium weight)
            if let preview = manifest.lastMessagePreview,
               preview.lowercased().contains(lowercased) {
                relevanceScore += 50
                if bestSnippet == nil {
                    bestSnippet = highlight(truncate(preview, maxLength: 120), query: lowercased)
                }
            }

            // Full content search (highest weight for content matches)
            if let contentMatch = searchContent(chatId: manifest.id, query: lowercased) {
                relevanceScore += contentMatch.score
                if bestSnippet == nil {
                    bestSnippet = contentMatch.snippet
                }
            }

            if relevanceScore > 0 {
                results.append(ChatSearchResult(
                    chatId: manifest.id,
                    title: manifest.title,
                    snippet: bestSnippet ?? manifest.lastMessagePreview ?? "",
                    relevanceScore: relevanceScore,
                    updatedAt: manifest.updatedAt
                ))
            }
        }

        return results.sorted { $0.relevanceScore > $1.relevanceScore }
    }

    // MARK: - Content Search

    private struct ContentMatch {
        let score: Double
        let snippet: String
    }

    private func searchContent(chatId: UUID, query: String) -> ContentMatch? {
        guard let chat = try? storage.loadChat(id: chatId) else { return nil }

        var bestScore: Double = 0
        var bestSnippet: String?

        for message in chat.messages {
            if message.content.lowercased().contains(query) {
                // Score based on position (earlier = slightly higher weight)
                let positionFactor = 1.0 - (Double(chat.messages.firstIndex(where: { $0.id == message.id }) ?? 0) / Double(max(chat.messages.count, 1)))
                let score = 30 * positionFactor

                if score > bestScore {
                    bestScore = score
                    bestSnippet = highlight(truncate(message.content, maxLength: 120), query: query)
                }
            }
        }

        guard bestScore > 0, let snippet = bestSnippet else { return nil }
        return ContentMatch(score: bestScore, snippet: snippet)
    }

    // MARK: - Highlighting

    /// Wraps matching substring with a marker for UI highlighting.
    /// Returns the text with match wrapped in **bold** markers.
    private func highlight(_ text: String, query: String) -> String {
        guard !query.isEmpty else { return text }

        var result = text
        let lowercased = text.lowercased()
        let range = lowercased.range(of: query)

        if let range = range {
            let startIndex = text.index(text.startIndex, offsetBy: lowercased.distance(from: lowercased.startIndex, to: range.lowerBound))
            let endIndex = text.index(startIndex, offsetBy: query.count)

            let match = String(text[startIndex..<endIndex])
            result = text.replacingCharacters(in: startIndex..<endIndex, with: "**\(match)**")
        }

        return result
    }

    private func truncate(_ text: String, maxLength: Int) -> String {
        if text.count <= maxLength {
            return text
        }
        let index = text.index(text.startIndex, offsetBy: maxLength - 3)
        return String(text[..<index]) + "..."
    }
}

// MARK: - ChatSearchResult

/// A single search result with relevance scoring.
struct ChatSearchResult: Identifiable {
    let id = UUID()
    let chatId: UUID
    let title: String
    let snippet: String
    let relevanceScore: Double
    let updatedAt: Date

    /// Formatted relevance as a percentage (0-100).
    var relevancePercent: Int {
        min(Int(relevanceScore), 100)
    }
}

// MARK: - Highlighted Text

import SwiftUI

/// A SwiftUI Text view that renders search-highlighted text.
/// Handles **bold** markers used by `ChatSearch.highlight()`.
struct HighlightedText: View {
    let text: String
    let highlightColor: Color

    init(_ text: String, color: Color = .axisAccent) {
        self.text = text
        self.highlightColor = color
    }

    var body: some View {
        buildAnnotatedText()
    }

    @ViewBuilder
    private func buildAnnotatedText() -> some View {
        if #available(macOS 14.0, *) {
            highlightedTextModern
        } else {
            Text(text)
                .font(.system(size: 13))
                .foregroundColor(.axisTextSecondary)
        }
    }

    private var highlightedTextModern: Text {
        var result = Text("")
        let parts = text.components(separatedBy: "**")

        for (index, part) in parts.enumerated() {
            if part.isEmpty { continue }

            if index % 2 == 1 {
                // This is a highlighted match
                result = result + Text(part)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(highlightColor)
            } else {
                result = result + Text(part)
                    .font(.system(size: 13))
                    .foregroundColor(.axisTextSecondary)
            }
        }

        return result
    }
}
