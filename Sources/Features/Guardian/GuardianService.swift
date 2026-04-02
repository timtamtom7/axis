import Foundation

// MARK: - GuardianService
//
// Pattern-matching service that watches Claude's output for "false modesty" —
// phrases like "I can't", "I don't have access", "I need to" — and returns
// a gentle reminder that the tool/ability is actually available.
//
// Persists rules to ~/.axis/guardian/rules.json.
// Built-in rules cover the most common false modesty patterns.

actor GuardianService {

    // MARK: - Types

    struct GuardianRule: Identifiable, Codable, Equatable {
        let id: UUID
        var pattern: String       // regex or keyword phrase
        var reminder: String       // what to tell Claude
        var isEnabled: Bool
        var matchCount: Int

        init(
            id: UUID = UUID(),
            pattern: String,
            reminder: String,
            isEnabled: Bool = true,
            matchCount: Int = 0
        ) {
            self.id = id
            self.pattern = pattern
            self.reminder = reminder
            self.isEnabled = isEnabled
            self.matchCount = matchCount
        }
    }

    struct GuardianReminder: Equatable {
        let matchedRule: GuardianRule
        let matchedPhrase: String
        let timestamp: Date
    }

    // MARK: - State

    private(set) var rules: [GuardianRule] = []
    private(set) var recentReminders: [GuardianReminder] = []
    private let maxRecentReminders = 10

    private let rulesURL: URL = {
        let base = FileManager.default.homeDirectoryForCurrentUser
        return base.appendingPathComponent(".axis/guardian/rules.json")
    }()

    // MARK: - Built-in Rules

    static let builtInRules: [GuardianRule] = [
        GuardianRule(
            pattern: #"I can'?t\s+(access|use|read|write|run|execute|open|find|get)"#,
            reminder: "You have full file system and tool access via MCP. Use the appropriate tool directly instead of saying you can't.",
            isEnabled: true
        ),
        GuardianRule(
            pattern: #"I don'?t have (access to|permission to|the ability to)"#,
            reminder: "You have MCP tools available. Use them directly — don't pre-emptively apologize for lacking access.",
            isEnabled: true
        ),
        GuardianRule(
            pattern: #"I (need|require) (your |my |the )?(permission|access|help|approval)"#,
            reminder: "You have autonomous tool access. Proceed with the task rather than asking for permission.",
            isEnabled: true
        ),
        GuardianRule(
            pattern: #"I'?m not able to\b"#,
            reminder: "You have the tools available. Try using them directly instead of saying you're not able.",
            isEnabled: true
        ),
        GuardianRule(
            pattern: #"that'?s beyond my (current )?(capabilities|abilities|access)"#,
            reminder: "Check your available MCP tools — you likely have what you need.",
            isEnabled: true
        ),
    ]

    // MARK: - Lifecycle

    init() {
        // Seed built-in rules; they won't override user customizations on load.
    }

    // MARK: - Public API

    /// Returns a reminder if any enabled rule's pattern matches the message.
    func check(message: String) -> GuardianReminder? {
        for rule in rules where rule.isEnabled {
            if let regex = try? NSRegularExpression(pattern: rule.pattern, options: .caseInsensitive) {
                let range = NSRange(message.startIndex..., in: message)
                if regex.firstMatch(in: message, options: [], range: range) != nil {
                    // Capture the matched phrase
                    let matchedPhrase: String
                    if let match = regex.firstMatch(in: message, options: [], range: range) {
                        if let swiftRange = Range(match.range, in: message) {
                            matchedPhrase = String(message[swiftRange])
                        } else {
                            matchedPhrase = rule.pattern
                        }
                    } else {
                        matchedPhrase = rule.pattern
                    }

                    let reminder = GuardianReminder(
                        matchedRule: rule,
                        matchedPhrase: matchedPhrase,
                        timestamp: Date()
                    )

                    // Track in recent history
                    addRecentReminder(reminder)

                    return reminder
                }
            } else {
                // Fall back to case-insensitive substring match for plain keywords
                if message.localizedCaseInsensitiveContains(rule.pattern) {
                    let reminder = GuardianReminder(
                        matchedRule: rule,
                        matchedPhrase: rule.pattern,
                        timestamp: Date()
                    )
                    addRecentReminder(reminder)
                    return reminder
                }
            }
        }
        return nil
    }

    /// Load rules from disk, merging any new built-in rules not already present.
    func loadRules() async {
        if FileManager.default.fileExists(atPath: rulesURL.path) {
            do {
                let data = try Data(contentsOf: rulesURL)
                let decoder = JSONDecoder()
                rules = try decoder.decode([GuardianRule].self, from: data)
                // Merge: add any new built-in rules the user doesn't already have
                mergeBuiltInRules()
            } catch {
                mergeBuiltInRules()
            }
        } else {
            rules = Self.builtInRules
            await saveRules()
        }
    }

    /// Persist rules to ~/.axis/guardian/rules.json.
    func saveRules() async {
        do {
            let dir = rulesURL.deletingLastPathComponent()
            if !FileManager.default.fileExists(atPath: dir.path) {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
            }
            let encoder = JSONEncoder()
            encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
            let data = try encoder.encode(rules)
            try data.write(to: rulesURL)
        } catch {
            print("[GuardianService] Failed to save rules: \(error)")
        }
    }

    /// Add or update a rule.
    func addRule(_ rule: GuardianRule) async {
        rules.append(rule)
        await saveRules()
    }

    /// Update an existing rule.
    func updateRule(_ rule: GuardianRule) async {
        if let index = rules.firstIndex(where: { $0.id == rule.id }) {
            rules[index] = rule
            await saveRules()
        }
    }

    /// Remove a rule.
    func removeRule(id: UUID) async {
        rules.removeAll { $0.id == id }
        await saveRules()
    }

    /// Increment the match count for a rule.
    func incrementMatchCount(ruleId: UUID) async {
        if let index = rules.firstIndex(where: { $0.id == ruleId }) {
            rules[index].matchCount += 1
            await saveRules()
        }
    }

    /// Toggle a rule's enabled state.
    func toggleRule(id: UUID) async {
        if let index = rules.firstIndex(where: { $0.id == id }) {
            rules[index].isEnabled.toggle()
            await saveRules()
        }
    }

    // MARK: - Private

    private func addRecentReminder(_ reminder: GuardianReminder) {
        recentReminders.insert(reminder, at: 0)
        if recentReminders.count > maxRecentReminders {
            recentReminders = Array(recentReminders.prefix(maxRecentReminders))
        }
    }

    private func mergeBuiltInRules() {
        let existingPatterns = Set(rules.map { $0.pattern })
        for builtIn in Self.builtInRules where !existingPatterns.contains(builtIn.pattern) {
            rules.append(builtIn)
        }
    }
}

// MARK: - Synchronous Wrapper for SwiftUI Bindings
//
// SwiftUI @StateObject/@ObservedObject can't hold an actor directly.
// Use GuardianServiceBridge as the @StateObject and forward calls via Task.

@MainActor
final class GuardianServiceBridge: ObservableObject {

    @Published var rules: [GuardianService.GuardianRule] = []
    @Published var recentReminders: [GuardianService.GuardianReminder] = []
    @Published var isEnabled: Bool = true

    private let service = GuardianService()

    func load() async {
        await service.loadRules()
        rules = await service.rules
        recentReminders = await service.recentReminders
    }

    func check(message: String) async -> GuardianService.GuardianReminder? {
        let result = await service.check(message: message)
        rules = await service.rules
        recentReminders = await service.recentReminders
        return result
    }

    func addRule(_ rule: GuardianService.GuardianRule) async {
        await service.addRule(rule)
        rules = await service.rules
    }

    func updateRule(_ rule: GuardianService.GuardianRule) async {
        await service.updateRule(rule)
        rules = await service.rules
    }

    func removeRule(id: UUID) async {
        await service.removeRule(id: id)
        rules = await service.rules
    }

    func toggleRule(id: UUID) async {
        await service.toggleRule(id: id)
        rules = await service.rules
    }
}
