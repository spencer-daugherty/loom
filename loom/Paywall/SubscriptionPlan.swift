import SwiftUI

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case annual
    case monthly

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        }
    }

    var priceText: LocalizedStringKey {
        switch self {
        case .annual:
            return "$99 / year"
        case .monthly:
            return "$15 / month"
        }
    }

    var trialText: LocalizedStringKey? {
        switch self {
        case .annual:
            return "7-day free trial"
        case .monthly:
            return nil
        }
    }

    var ctaText: LocalizedStringKey {
        switch self {
        case .annual:
            return "Start 7-Day Free Trial"
        case .monthly:
            return "Subscribe Monthly"
        }
    }
}
