import Foundation

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case lifetime
    case annual
    case monthly

    var id: String { rawValue }

    var storeKitProductID: String {
        switch self {
        case .lifetime:
            return "loom.lifetime"
        case .annual:
            return "loom.annual.locked"
        case .monthly:
            return "loom.monthly"
        }
    }

    static func from(storeKitProductID: String) -> SubscriptionPlan? {
        allCases.first { $0.storeKitProductID == storeKitProductID }
    }

    var title: String {
        switch self {
        case .lifetime:
            return "Lifetime"
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        }
    }

    var plainTitle: String {
        switch self {
        case .lifetime:
            return "Lifetime"
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        }
    }

    var tierText: String? {
        switch self {
        case .lifetime:
            return nil
        case .annual:
            return nil
        case .monthly:
            return nil
        }
    }

    var tierDetailText: String? {
        nil
    }

    var priceText: String {
        switch self {
        case .lifetime:
            return "$129 one-time"
        case .annual:
            return "$79 / year"
        case .monthly:
            return "$15 / month"
        }
    }

    var originalPriceText: String? {
        nil
    }

    var trialText: String? {
        nil
    }

    var trialDetailText: String? {
        nil
    }

    var summaryText: String? {
        switch self {
        case .lifetime:
            return "One-time purchase. No subscription renewal."
        case .annual:
            return "Auto-renewable yearly subscription."
        case .monthly:
            return "Auto-renewable monthly subscription."
        }
    }

    var manageOrCancelText: String? {
        switch self {
        case .lifetime:
            return nil
        case .annual, .monthly:
            return "Manage or cancel subscriptions anytime in Apple Account Settings."
        }
    }

    var disclosureDetailText: String? {
        switch self {
        case .lifetime:
            return "Lifetime is billed to your Apple ID after purchase confirmation as a one-time payment and does not renew automatically."
        case .annual:
            return "Annual is billed to your Apple ID after purchase confirmation. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in Apple Account Settings."
        case .monthly:
            return "Monthly is billed to your Apple ID after purchase confirmation. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in Apple Account Settings."
        }
    }

    var detailSheetTitle: String {
        switch self {
        case .lifetime:
            return "Lifetime"
        case .annual:
            return "Annual"
        case .monthly:
            return "Monthly"
        }
    }

    var ctaText: String {
        switch self {
        case .lifetime:
            return "Purchase Lifetime Access"
        case .annual:
            return "Subscribe Annual"
        case .monthly:
            return "Subscribe Monthly"
        }
    }

    var plainCTATitle: String {
        switch self {
        case .lifetime:
            return "Purchase Lifetime Access"
        case .annual:
            return "Subscribe Annual"
        case .monthly:
            return "Subscribe Monthly"
        }
    }
}
