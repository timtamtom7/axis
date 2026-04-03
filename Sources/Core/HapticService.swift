import Foundation
import AppKit

enum HapticService {
    static func play(type: HapticType) {
        let performer = NSHapticFeedbackManager.defaultPerformer
        switch type {
        case .selection:
            // No macOS equivalent — skip
            break
        case .success, .warning, .error, .light, .medium, .heavy:
            performer.perform(.generic, performanceTime: .default)
        @unknown default:
            performer.perform(.generic, performanceTime: .default)
        }
    }

    enum HapticType {
        case selection
        case success
        case warning
        case error
        case light
        case medium
        case heavy
    }
}
