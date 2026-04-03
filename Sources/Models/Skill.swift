import Foundation
import SwiftUI

// MARK: - Skill Model

/// Represents a skill — a natural-language defined tool or agent.
struct Skill: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var type: SkillType
    var filePath: String
    var isEnabled: Bool
    var content: String

    init(
        id: UUID = UUID(),
        name: String,
        description: String,
        type: SkillType,
        filePath: String,
        isEnabled: Bool = true,
        content: String = ""
    ) {
        self.id = id
        self.name = name
        self.description = description
        self.type = type
        self.filePath = filePath
        self.isEnabled = isEnabled
        self.content = content
    }

    enum SkillType: String, Codable, Sendable, CaseIterable, Identifiable {
        case mcp     // Wraps an MCP tool
        case agent   // Spawns a background agent
        case custom  // User-defined natural language

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .mcp:    return Color(hex: 0x4B9EFF)
            case .agent:  return Color(hex: 0x7B61FF)
            case .custom: return Color(hex: 0xF1DDBC)
            }
        }

        var icon: String {
            switch self {
            case .mcp:    return "puzzlepiece.fill"
            case .agent:  return "cpu"
            case .custom: return "wand.and.stars"
            }
        }
    }
}

// MARK: - Skill Result

/// Result of a skill invocation.
struct SkillResult: Codable, Sendable {
    let success: Bool
    let output: String
    let error: String?

    static func success(_ output: String) -> SkillResult {
        SkillResult(success: true, output: output, error: nil)
    }

    static func failure(_ error: String) -> SkillResult {
        SkillResult(success: false, output: "", error: error)
    }
}

// MARK: - MCP Tool

/// Describes an MCP tool exposed by Axis.
struct MCPTool: Codable, Identifiable, Sendable {
    var id: String { name }
    let name: String
    let description: String
    let inputSchema: MCPToolInputSchema

    struct MCPToolInputSchema: Codable, Sendable {
        let type: String
        let properties: [String: MCPToolProperty]
        let required: [String]?

        struct MCPToolProperty: Codable, Sendable {
            let type: String
            let description: String?
        }
    }
}

// MARK: - JSON-RPC 2.0 Message Types

/// JSON-RPC 2.0 message envelope.
enum MCPMessage: Codable, Sendable {
    case request(MCPRequest)
    case response(MCPResponse)
    case notification(MCPNotification)

    enum CodingKeys: String, CodingKey {
        case jsonrpc
        case method, id, params, result, error
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        let jsonrpc = try container.decode(String.self, forKey: .jsonrpc)

        guard jsonrpc == "2.0" else {
            throw MCPServerError.invalidJSONRPC
        }

        // Check if this is a response (has result or error) or request/notification
        let idValue: MCPMessageID
        if let intId = try? container.decode(Int.self, forKey: .id) {
            idValue = .integer(intId)
        } else if let stringId = try? container.decode(String.self, forKey: .id) {
            idValue = .string(stringId)
        } else {
            idValue = .integer(0)
        }

        if let result = try container.decodeIfPresent(MCPResultPayload.self, forKey: .result) {
            let response = MCPResponse(id: idValue, result: result)
            self = .response(response)
        } else if let error = try container.decodeIfPresent(MCPErrorPayload.self, forKey: .error) {
            let response = MCPResponse(id: idValue, error: error)
            self = .response(response)
        } else {
            let method = try container.decode(String.self, forKey: .method)
            let params = try container.decodeIfPresent(MCPRequest.MCPRequestParams.self, forKey: .params)

            let request = MCPRequest(id: idValue, method: method, params: params)
            self = .request(request)
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode("2.0", forKey: .jsonrpc)

        switch self {
        case .request(let req):
            try container.encode(req.method, forKey: .method)
            if let idInt = req.id.intValue {
                try container.encode(idInt, forKey: .id)
            } else if let idString = req.id.stringValue {
                try container.encode(idString, forKey: .id)
            }
            if let params = req.params {
                try container.encode(params, forKey: .params)
            }
        case .response(let resp):
            if let result = resp.result {
                try container.encode(result, forKey: .result)
            }
            if let error = resp.error {
                try container.encode(error, forKey: .error)
            }
            if let idInt = resp.id.intValue {
                try container.encode(idInt, forKey: .id)
            } else if let idString = resp.id.stringValue {
                try container.encode(idString, forKey: .id)
            }
        case .notification(let notif):
            try container.encode(notif.method, forKey: .method)
            if let params = notif.params {
                try container.encode(params, forKey: .params)
            }
        }
    }
}

// MARK: - MCP Request

struct MCPRequest: Codable, Sendable {
    let id: MCPMessageID
    let method: String
    let params: MCPRequestParams?

    struct MCPRequestParams: Codable, Sendable {
        let name: String?
        let arguments: [String: String]?
    }
}

// MARK: - MCP Response

struct MCPResponse: Codable, Sendable {
    let id: MCPMessageID
    var result: MCPResultPayload?
    var error: MCPErrorPayload?
}

struct MCPResultPayload: Codable, Sendable {
    let content: [MCPContentBlock]?
    let isError: Bool?

    struct MCPContentBlock: Codable, Sendable {
        let type: String
        let text: String?
    }
}

struct MCPErrorPayload: Codable, Sendable {
    let code: Int
    let message: String
    let data: String?
}

// MARK: - MCP Notification

struct MCPNotification: Codable, Sendable {
    let method: String
    let params: MCPRequestParams?
}

// MARK: - Message ID

enum MCPMessageID: Codable, Sendable {
    case integer(Int)
    case string(String)

    var intValue: Int? {
        if case .integer(let v) = self { return v }
        return nil
    }

    var stringValue: String? {
        if case .string(let v) = self { return v }
        return nil
    }
}

// MARK: - MCP Server Error

enum MCPServerError: Error, LocalizedError {
    case invalidJSONRPC
    case invalidMessageID
    case methodNotFound(String)
    case invalidParams(String)
    case internalError(String)
    case toolExecutionFailed(String)

    var errorDescription: String? {
        switch self {
        case .invalidJSONRPC:        return "Invalid JSON-RPC version"
        case .invalidMessageID:      return "Invalid message ID"
        case .methodNotFound(let m): return "Method not found: \(m)"
        case .invalidParams(let p):  return "Invalid params: \(p)"
        case .internalError(let e):  return "Internal error: \(e)"
        case .toolExecutionFailed(let t): return "Tool execution failed: \(t)"
        }
    }
}
