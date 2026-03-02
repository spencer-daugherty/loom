import SwiftUI

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case annual
    case monthly

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .annual:
            return "Annual - Founding Member"
        case .monthly:
            return "Monthly"
        }
    }

    var tierText: LocalizedStringKey? {
        switch self {
        case .annual:
            return "First 1,000"
        case .monthly:
            return nil
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
            return "10-day free trial"
        case .monthly:
            return nil
        }
    }

    var trialDetailText: LocalizedStringKey? {
        switch self {
        case .annual:
            return "Locked annual pricing for life"
        case .monthly:
            return nil
        }
    }

    var ctaText: LocalizedStringKey {
        switch self {
        case .annual:
            return "Start 10-Day Free Trial"
        case .monthly:
            return "Subscribe Monthly"
        }
    }
}
