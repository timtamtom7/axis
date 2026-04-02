import Foundation
import UserNotifications

/// Notification category identifiers
enum NotificationCategory: String {
    case agentDone = "AGENT_DONE"
    case contextWarning = "CONTEXT_WARNING"
    case reminder = "REMINDER"
}

/// Notification action identifiers
enum NotificationAction: String {
    case viewResults = "VIEW_RESULTS"
    case trimContext = "TRIM_CONTEXT"
    case dismiss = "DISMISS"
}

/// Centralized notification service using UNUserNotificationCenter
final class NotificationService: NSObject, @unchecked Sendable {
    static let shared = NotificationService()

    private let center = UNUserNotificationCenter.current()

    // MARK: - Setup

    override init() {
        super.init()
        center.delegate = self
        registerCategories()
    }

    /// Request authorization on first launch
    func requestAuthorization() {
        center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, error in
            if let error = error {
                print("[NotificationService] Authorization error: \(error.localizedDescription)")
                return
            }
            if granted {
                print("[NotificationService] Authorization granted")
            } else {
                print("[NotificationService] Authorization denied")
            }
        }
    }

    // MARK: - Categories

    private func registerCategories() {
        // AGENT_DONE: "Agent finished" with action to view results
        let viewResultsAction = UNNotificationAction(
            identifier: NotificationAction.viewResults.rawValue,
            title: "View Results",
            options: .foreground
        )
        let agentDoneCategory = UNNotificationCategory(
            identifier: NotificationCategory.agentDone.rawValue,
            actions: [viewResultsAction],
            intentIdentifiers: [],
            options: []
        )

        // CONTEXT_WARNING: "Context getting full" with action to trim
        let trimContextAction = UNNotificationAction(
            identifier: NotificationAction.trimContext.rawValue,
            title: "Trim Context",
            options: .foreground
        )
        let contextWarningCategory = UNNotificationCategory(
            identifier: NotificationCategory.contextWarning.rawValue,
            actions: [trimContextAction],
            intentIdentifiers: [],
            options: []
        )

        // REMINDER: belief check-in reminders
        let reminderCategory = UNNotificationCategory(
            identifier: NotificationCategory.reminder.rawValue,
            actions: [],
            intentIdentifiers: [],
            options: []
        )

        center.setNotificationCategories([agentDoneCategory, contextWarningCategory, reminderCategory])
    }

    // MARK: - Send

    /// Send a notification with the given title, body, and identifier
    func send(title: String, body: String, identifier: String, category: NotificationCategory? = nil) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        if let category = category {
            content.categoryIdentifier = category.rawValue
        }

        let request = UNNotificationRequest(
            identifier: identifier,
            content: content,
            trigger: nil // deliver immediately
        )

        center.add(request) { error in
            if let error = error {
                print("[NotificationService] Failed to send notification: \(error.localizedDescription)")
            }
        }
    }

    /// Send an agent completion notification
    func sendAgentDone(agentName: String, result: String) {
        send(
            title: "Agent Finished",
            body: "\(agentName) completed: \(result)",
            identifier: "agent-done-\(UUID().uuidString)",
            category: .agentDone
        )
    }

    /// Send a context warning notification
    func sendContextWarning(percentage: Int) {
        send(
            title: "Context Getting Full",
            body: "Context usage at \(percentage)%. Consider trimming.",
            identifier: "context-warning-\(UUID().uuidString)",
            category: .contextWarning
        )
    }

    /// Send a reminder notification
    func sendReminder(title: String, body: String, identifier: String) {
        send(
            title: title,
            body: body,
            identifier: identifier,
            category: .reminder
        )
    }
}

// MARK: - UNUserNotificationCenterDelegate

extension NotificationService: UNUserNotificationCenterDelegate {
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let actionIdentifier = response.actionIdentifier

        switch actionIdentifier {
        case NotificationAction.viewResults.rawValue:
            // Handle view results action
            NotificationCenter.default.post(name: .notificationViewResults, object: nil)
        case NotificationAction.trimContext.rawValue:
            // Handle trim context action
            NotificationCenter.default.post(name: .notificationTrimContext, object: nil)
        default:
            break
        }

        completionHandler()
    }

    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        // Show notification even when app is in foreground
        completionHandler([.banner, .sound])
    }
}

// MARK: - Notification Names

extension Notification.Name {
    static let notificationViewResults = Notification.Name("notificationViewResults")
    static let notificationTrimContext = Notification.Name("notificationTrimContext")
}
