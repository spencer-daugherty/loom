import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

enum TipPreviewType: String {
    case littleWinsMoments
    case loomAIPersonalization
    case appleHealthIntegration
    case assignActions
    case loomAIChat
    case loomAIAutoWrite
}

enum TipFeature: String, CaseIterable, Identifiable {
    case littleWinsMoments
    case loomAIPersonalization
    case appleHealthIntegration
    case assignActions
    case loomAIChat
    case loomAIAutoWrite

    var id: String { rawValue }

    var title: String {
        switch self {
        case .littleWinsMoments:
            return "Little Wins Moments"
        case .loomAIPersonalization:
            return "LoomAI Personalization"
        case .appleHealthIntegration:
            return "Apple Health Integration"
        case .assignActions:
            return "Assign Actions"
        case .loomAIChat:
            return "LoomAI Chat"
        case .loomAIAutoWrite:
            return "LoomAI AutoWrite"
        }
    }

    var summary: String {
        switch self {
        case .littleWinsMoments:
            return "Capture your progress with camera templates and filters made for sharing."
        case .loomAIPersonalization:
            return "Quick diagnostic answers shape personalized guidance across Loom."
        case .appleHealthIntegration:
            return "Bring in Apple Health signals so Little Wins and Outcomes stay grounded."
        case .assignActions:
            return "Assign actions to people or places to strengthen accountability context."
        case .loomAIChat:
            return "Ask LoomAI for focused help and get suggestion cards you can apply fast."
        case .loomAIAutoWrite:
            return "AutoWrite drafts context-aware text using your Loom setup and direction."
        }
    }

    var detailBody: String {
        switch self {
        case .littleWinsMoments:
            return "Use camera templates to showcase what you are working on, your streak momentum, and weekly consistency. Filters and overlays keep your progress visual and easy to share."
        case .loomAIPersonalization:
            return "Your diagnostics and insights become persistent context for LoomAI. That lets suggestions feel personal, grounded, and consistent as your setup evolves."
        case .appleHealthIntegration:
            return "Connect Apple Health so progress signals like activity can support your Little Wins and Outcomes. Loom uses this to keep your direction measurable and realistic."
        case .assignActions:
            return "Tag an action to a person or place when context matters. It keeps responsibility clear inside your plan without changing how your workflow moves."
        case .loomAIChat:
            return "Chat with LoomAI to clarify priorities, unblock execution, and get structured options. Suggestion cards help you move from idea to action quickly."
        case .loomAIAutoWrite:
            return "AutoWrite generates polished drafts in the moment based on your current screen and context. It helps you write faster while keeping your voice and intent intact."
        }
    }

    var previewType: TipPreviewType {
        switch self {
        case .littleWinsMoments:
            return .littleWinsMoments
        case .loomAIPersonalization:
            return .loomAIPersonalization
        case .appleHealthIntegration:
            return .appleHealthIntegration
        case .assignActions:
            return .assignActions
        case .loomAIChat:
            return .loomAIChat
        case .loomAIAutoWrite:
            return .loomAIAutoWrite
        }
    }

    var symbolName: String {
        switch self {
        case .littleWinsMoments:
            return "camera.filters"
        case .loomAIPersonalization:
            return "sparkles"
        case .appleHealthIntegration:
            return "heart.text.square"
        case .assignActions:
            return "person.crop.circle.badge.checkmark"
        case .loomAIChat:
            return "bubble.left.and.bubble.right"
        case .loomAIAutoWrite:
            return "wand.and.stars"
        }
    }

    var isNew: Bool {
        switch self {
        case .littleWinsMoments, .loomAIPersonalization:
            return true
        default:
            return false
        }
    }

    var isComingSoon: Bool {
        switch self {
        case .appleHealthIntegration:
            return !TipFeatureSupport.healthDataAvailable
        default:
            return false
        }
    }

    var previewStepCount: Int {
        switch self {
        case .littleWinsMoments, .loomAIPersonalization, .appleHealthIntegration, .assignActions, .loomAIChat, .loomAIAutoWrite:
            return 4
        }
    }
}

private enum TipFeatureSupport {
    static var healthDataAvailable: Bool {
#if canImport(HealthKit)
        return HKHealthStore.isHealthDataAvailable()
#else
        return false
#endif
    }
}
