import Foundation
import Combine

/// Agent types available in Axis
enum AgentType: String, Codable, CaseIterable {
    case codeReviewer = "code_reviewer"
    case researcher = "researcher"
    case explorer = "explorer"

    var displayName: String {
        switch self {
        case .codeReviewer: return "Code Reviewer"
        case .researcher: return "Researcher"
        case .explorer: return "Explorer"
        }
    }

    var description: String {
        switch self {
        case .codeReviewer: return "Reviews code for issues, performance, and best practices"
        case .researcher: return "Researches topics and provides detailed analysis"
        case .explorer: return "Explores codebases and generates insights"
        }
    }
}

/// Agent execution status
enum AgentStatus: String, Codable {
    case pending
    case running
    case done
    case failed
}

/// Represents a background agent task
struct Agent: Identifiable, Equatable {
    let id: UUID
    let name: String
    let type: AgentType
    let createdAt: Date
    var status: AgentStatus
    var result: String?
    var error: String?

    init(id: UUID = UUID(), name: String, type: AgentType, status: AgentStatus = .pending) {
        self.id = id
        self.name = name
        self.type = type
        self.createdAt = Date()
        self.status = status
        self.result = nil
        self.error = nil
    }

    static func == (lhs: Agent, rhs: Agent) -> Bool {
        lhs.id == rhs.id
    }
}

/// Manages background agents and their lifecycle
@MainActor
final class AgentManager: ObservableObject {
    static let shared = AgentManager()

    @Published private(set) var agents: [Agent] = []
    @Published private(set) var runningAgents: [Agent] = []

    private var activeTasks: [UUID: Task<Void, Never>] = [:]
    private let notificationService = NotificationService.shared

    // MARK: - Public API

    /// Spawn a new background agent
    func spawnAgent(type: AgentType, context: Chat, name: String? = nil) -> Agent {
        let agentName = name ?? "\(type.displayName) #\(agents.count(where: { $0.type == type }) + 1)"
        var agent = Agent(name: agentName, type: type, status: .running)

        agents.append(agent)
        runningAgents.append(agent)

        // Start background task
        let task = Task {
            await runAgent(&agent)
        }
        activeTasks[agent.id] = task

        return agent
    }

    /// Cancel a running agent
    func cancelAgent(id: UUID) {
        activeTasks[id]?.cancel()
        activeTasks.removeValue(forKey: id)

        if let index = agents.firstIndex(where: { $0.id == id }) {
            agents[index].status = .failed
            agents[index].error = "Cancelled by user"
        }
        runningAgents.removeAll { $0.id == id }
    }

    /// Get agent by ID
    func agent(id: UUID) -> Agent? {
        agents.first { $0.id == id }
    }

    /// Remove completed agents
    func cleanupAgents() {
        agents.removeAll { $0.status == .done || $0.status == .failed }
    }

    // MARK: - Private

    private func runAgent(_ agent: inout Agent) async {
        defer {
            // Remove from running agents
            runningAgents.removeAll { $0.id == agent.id }
            activeTasks.removeValue(forKey: agent.id)
        }

        do {
            // Update status to running
            agent.status = .running

            // Simulate agent work (placeholder for actual agent execution)
            let result = await executeAgent(agent: agent, context: Chat())

            agent.status = .done
            agent.result = result

            // Send completion notification
            notificationService.sendAgentDone(agentName: agent.name, result: result)

        } catch {
            agent.status = .failed
            agent.error = error.localizedDescription

            // Send failure notification
            notificationService.send(
                title: "Agent Failed",
                body: "\(agent.name) failed: \(error.localizedDescription)",
                identifier: "agent-failed-\(agent.id)"
            )
        }
    }

    private func executeAgent(agent: Agent, context: Chat) async -> String {
        // Placeholder: actual implementation would run Claude Code agent
        // TODO: Integrate with Claude Code background execution

        // Simulate work
        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second

        return "\(agent.type.displayName) completed analysis"
    }
}

// MARK: - Placeholder Chat Model

/// Placeholder Chat model — replace with actual Chat from Models
struct Chat: Identifiable {
    let id: UUID
    let title: String
    let createdAt: Date
    var messages: [ChatMessage]

    init(id: UUID = UUID(), title: String = "New Chat", messages: [ChatMessage] = []) {
        self.id = id
        self.title = title
        self.createdAt = Date()
        self.messages = messages
    }
}

/// Placeholder ChatMessage model
struct ChatMessage: Identifiable {
    let id: UUID
    let role: MessageRole
    let content: String
    let timestamp: Date

    init(id: UUID = UUID(), role: MessageRole, content: String, timestamp: Date = Date()) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

enum MessageRole: String {
    case user
    case assistant
    case system
}
