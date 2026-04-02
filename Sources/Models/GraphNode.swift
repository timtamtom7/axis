import Foundation

// MARK: - FileType

enum FileType: String, Codable, CaseIterable {
    case swift
    case markdown
    case json
    case other

    var displayName: String {
        switch self {
        case .swift:    return "Swift"
        case .markdown: return "Markdown"
        case .json:     return "JSON"
        case .other:    return "Other"
        }
    }

    static func from(extension ext: String) -> FileType {
        switch ext.lowercased() {
        case "swift":          return .swift
        case "md", "markdown": return .markdown
        case "json":           return .json
        default:               return .other
        }
    }
}

// MARK: - GraphNode

struct GraphNode: Identifiable, Codable, Equatable, Hashable {
    let id: UUID
    let name: String
    let path: String
    let fileType: FileType
    let lineCount: Int
    let lastModified: Date

    var isActive: Bool = false

    init(
        id: UUID = UUID(),
        name: String,
        path: String,
        fileType: FileType,
        lineCount: Int,
        lastModified: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.path = path
        self.fileType = fileType
        self.lineCount = lineCount
        self.lastModified = lastModified
    }

    var fileExtension: String {
        (path as NSString).pathExtension
    }

    var directory: String {
        (path as NSString).deletingLastPathComponent
    }

    var formattedLineCount: String {
        if lineCount >= 1000 {
            return String(format: "%.1fk", Double(lineCount) / 1000.0)
        }
        return "\(lineCount)"
    }

    var formattedLastModified: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: lastModified, relativeTo: Date())
    }

    static func == (lhs: GraphNode, rhs: GraphNode) -> Bool {
        lhs.id == rhs.id
    }

    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
}

// MARK: - GraphEdge

struct GraphEdge: Codable, Equatable {
    let fromId: UUID
    let toId: UUID
    let strength: Double // 0.0–1.0, affects opacity and spring tension

    init(fromId: UUID, toId: UUID, strength: Double = 0.5) {
        self.fromId = fromId
        self.toId = toId
        self.strength = max(0.0, min(1.0, strength))
    }
}

// MARK: - FileInfo

struct FileInfo: Identifiable {
    let id: UUID
    let node: GraphNode

    var formattedSize: String {
        "\(node.lineCount) lines"
    }

    init(node: GraphNode) {
        self.id = node.id
        self.node = node
    }
}
