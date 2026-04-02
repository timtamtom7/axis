import Foundation
import AppKit

enum HapticService {
    static func play(type: HapticType) {
        let manager = NSHapticFeedbackManager.defaultPerformer
        switch type {
        case .selection:
            manager.perform(.selection, performanceTime: .default)
        case .success:
            manager.perform(.generic, performanceTime: .default)
        case .warning:
            manager.perform(.generic, performanceTime: .default)
        case .error:
            manager.perform(.negative, performanceTime: .default)
        case .light:
            manager.perform(.levelChange, performanceTime: .default)
        case .medium:
            manager.perform(.levelChange, performanceTime: .default)
        case .heavy:
            manager.perform(.negative, performanceTime: .default)
        @unknown default:
            manager.perform(.generic, performanceTime: .default)
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
