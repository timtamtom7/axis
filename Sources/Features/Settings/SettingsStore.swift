import SwiftUI
import Combine

// MARK: - SettingsStore
//
// ObservableObject holding all user-facing settings.
// Backed by @AppStorage — persisted automatically.
//
// Usage:
//   @StateObject private var settings = SettingsStore()
//   Picker("Theme", selection: $settings.theme) { ... }

@MainActor
final class SettingsStore: ObservableObject {
    // MARK: - General

    /// App theme: system, light, or dark.
    @AppStorage("settings.theme") var theme: Theme = .system

    /// Popover size preset: compact, default, expanded.
    @AppStorage("settings.popoverSize") var popoverSize: PopoverSize = .standard

    /// Whether to launch Axis at login.
    @AppStorage("settings.launchAtLogin") var launchAtLogin: Bool = false

    /// Whether to show the context ring.
    @AppStorage("settings.showContextRing") var showContextRing: Bool = true

    // MARK: - Context

    /// Context window limit in tokens (100,000 – 200,000).
    @AppStorage("settings.contextLimit") var contextLimit: Int = 200_000

    /// Auto-trim when approaching context limit.
    @AppStorage("settings.autoTrim") var autoTrim: Bool = true

    /// Token threshold for auto-trim warning (absolute value).
    @AppStorage("settings.trimThreshold") var trimThreshold: Int = 180_000

    // MARK: - Notifications

    /// Enable notifications.
    @AppStorage("settings.notificationsEnabled") var notificationsEnabled: Bool = true

    /// Play sound with notifications.
    @AppStorage("settings.notificationSound") var notificationSound: Bool = true

    // MARK: - Privacy

    /// Streamer mode: redact API keys, tokens, usernames.
    @AppStorage("settings.streamerMode") var streamerMode: Bool = false

    /// Stored API key (stored securely — shown masked in UI).
    @AppStorage("settings.apiKeySet") var apiKeySet: Bool = false

    // MARK: - App Info

    var appVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
    }

    var buildNumber: String {
        Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
    }

    // MARK: - Theme Enum

    enum Theme: String, CaseIterable, Identifiable {
        case system = "System"
        case light = "Light"
        case dark = "Dark"

        var id: String { rawValue }

        var colorScheme: ColorScheme? {
            switch self {
            case .system: return nil
            case .light:  return .light
            case .dark:   return .dark
            }
        }
    }

    // MARK: - PopoverSize Enum

    enum PopoverSize: String, CaseIterable, Identifiable {
        case compact  = "Compact"
        case standard = "Standard"
        case expanded = "Expanded"

        var id: String { rawValue }

        var dimensions: (width: CGFloat, height: CGFloat) {
            switch self {
            case .compact:  return (400, 500)
            case .standard: return (480, 640)
            case .expanded: return (560, 720)
            }
        }
    }

    // MARK: - Computed Helpers

    var contextLimitFormatted: String {
        if contextLimit >= 1000 {
            return String(format: "%.0fk", Double(contextLimit) / 1000.0)
        }
        return "\(contextLimit)"
    }

    var trimThresholdFormatted: String {
        if trimThreshold >= 1000 {
            return String(format: "%.0fk", Double(trimThreshold) / 1000.0)
        }
        return "\(trimThreshold)"
    }
}

// MARK: - AppStorage Convenience Extensions

extension Binding {
    /// Creates a binding with a custom setter that validates before writing.
    func validated(_ transform: @escaping (Value) -> Value) -> Binding {
        Binding(
            get: { self.wrappedValue },
            set: { self.wrappedValue = transform($0) }
        )
    }
}

// MARK: - Context Limit Validator

extension SettingsStore {
    /// Clamps context limit to valid range (100k–200k).
    static func validatedContextLimit(_ value: Int) -> Int {
        min(200_000, max(100_000, value))
    }

    /// Clamps trim threshold to valid range (100k–context limit).
    static func validatedTrimThreshold(_ value: Int, contextLimit: Int) -> Int {
        min(contextLimit - 10_000, max(50_000, value))
    }
}
