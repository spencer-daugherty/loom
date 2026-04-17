import Foundation
#if canImport(HealthKit)
import HealthKit
#endif

enum TipPreviewType: String {
    case littleWinsMoments
    case loomAIPersonalization
    case appleHealthIntegration
    case assignActions
    case shareToLoom
    case widgets
    case loomAIChat
    case loomAIAutoWrite
    case loomAIEmailAssist
    case loomAIAgent
}

enum TipFeature: String, CaseIterable, Identifiable {
    case littleWinsMoments
    case loomAIPersonalization
    case appleHealthIntegration
    case assignActions
    case shareToLoom
    case widgets
    case loomAIChat
    case loomAIAutoWrite
    case loomAIEmailAssist
    case loomAIAgent

    var id: String { rawValue }

    var hubSection: TipHubSection {
        switch self {
        case .widgets, .loomAIEmailAssist, .loomAIAgent:
            return .inDevelopment
        default:
            return .tips
        }
    }

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
        case .shareToLoom:
            return "Share to Loom"
        case .widgets:
            return "Widgets"
        case .loomAIChat:
            return "LoomAI Chat"
        case .loomAIAutoWrite:
            return "LoomAI AutoWrite"
        case .loomAIEmailAssist:
            return "LoomAI EmailAssist"
        case .loomAIAgent:
            return "LoomAI Agent"
        }
    }

    var summary: String {
        switch self {
        case .littleWinsMoments:
            return "Capture your progress with camera templates and filters made for sharing."
        case .loomAIPersonalization:
            return "Quick diagnostic answers shape personalized guidance across Loom."
        case .appleHealthIntegration:
            return "Bring in Apple Health signals so Little Wins and Goals stay grounded."
        case .assignActions:
            return "Assign actions to people or places to strengthen accountability context."
        case .shareToLoom:
            return "Save photos, links, and notes straight into Capture from any app."
        case .widgets:
            return "Pin focused Loom widgets to your Home Screen for fast visibility and one-tap momentum."
        case .loomAIChat:
            return "Ask LoomAI for focused help and get suggestion cards you can apply fast."
        case .loomAIAutoWrite:
            return "AutoWrite drafts context-aware text using your Loom setup and direction."
        case .loomAIEmailAssist:
            return "Integrate with your email provider and LoomAI will capture any pending actions for your attention."
        case .loomAIAgent:
            return "Assign real-world tasks to LoomAI and review curated options before it books, buys, or schedules."
        }
    }

    var detailBody: String {
        switch self {
        case .littleWinsMoments:
            return "Use camera templates to showcase what you are working on, your streak momentum, and weekly consistency. Filters and overlays keep your progress visual and easy to share."
        case .loomAIPersonalization:
            return "Your diagnostics and insights become persistent context for LoomAI. That lets suggestions feel personal, grounded, and consistent as your setup evolves."
        case .appleHealthIntegration:
            return "Connect Apple Health so progress signals like activity can support your Little Wins and Goals. Loom uses this to keep your direction measurable and realistic."
        case .assignActions:
            return "Tag an action to a person or place when context matters. It keeps responsibility clear inside your plan without changing how your workflow moves."
        case .shareToLoom:
            return "Share anything into Loom from other apps. Photos, website links, and note text arrive in one Capture flow so you can turn incoming context into action fast."
        case .widgets:
            return "Widgets will bring your most important Loom context onto the Home Screen, including focus areas, quick capture entry points, and progress snapshots that keep momentum visible throughout the day."
        case .loomAIChat:
            return "Chat with LoomAI to clarify priorities, unblock execution, and get structured options. Suggestion cards help you move from idea to action quickly."
        case .loomAIAutoWrite:
            return "AutoWrite generates polished drafts in the moment based on your current screen and context. It helps you write faster while keeping your voice and intent intact."
        case .loomAIEmailAssist:
            return "Connect your inbox so LoomAI can scan email threads, surface the follow-ups that need action, and turn them into pending items without manual triage."
        case .loomAIAgent:
            return "LoomAI Agent can take a request like travel, shopping, appointments, or reservations, confirm that you want help, and return strong options before taking the next step."
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
        case .shareToLoom:
            return .shareToLoom
        case .widgets:
            return .widgets
        case .loomAIChat:
            return .loomAIChat
        case .loomAIAutoWrite:
            return .loomAIAutoWrite
        case .loomAIEmailAssist:
            return .loomAIEmailAssist
        case .loomAIAgent:
            return .loomAIAgent
        }
    }

    var symbolName: String {
        switch self {
        case .littleWinsMoments:
            return "camera"
        case .loomAIPersonalization:
            return "sparkles"
        case .appleHealthIntegration:
            return "heart.fill"
        case .assignActions:
            return "person.fill"
        case .shareToLoom:
            return "square.and.arrow.up"
        case .widgets:
            return "square.grid.2x2"
        case .loomAIChat:
            return "bubble.left.and.bubble.right"
        case .loomAIAutoWrite:
            return "wand.and.stars"
        case .loomAIEmailAssist:
            return "envelope.badge"
        case .loomAIAgent:
            return "person.crop.circle.badge.sparkles"
        }
    }

    var isNew: Bool {
        switch self {
        case .littleWinsMoments, .loomAIPersonalization, .shareToLoom:
            return true
        default:
            return false
        }
    }

    var isComingSoon: Bool {
        switch self {
        case .widgets:
            return true
        case .appleHealthIntegration:
            return !TipFeatureSupport.healthDataAvailable
        default:
            return false
        }
    }

    var previewStepCount: Int {
        switch self {
        case .appleHealthIntegration:
            return 5
        case .loomAIAgent:
            return 16
        case .littleWinsMoments, .loomAIPersonalization, .assignActions, .shareToLoom, .widgets, .loomAIChat, .loomAIAutoWrite, .loomAIEmailAssist:
            return 4
        }
    }
}

enum TipHubSection {
    case tips
    case inDevelopment
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
