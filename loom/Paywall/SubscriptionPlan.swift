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

    private static let foundingMemberEndDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 5
        components.day = 31
        components.hour = 23
        components.minute = 59
        components.second = 59
        return components.date ?? .distantFuture
    }()

    private static let annualPricingLockEndDate: Date = {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(secondsFromGMT: 0)
        components.year = 2026
        components.month = 6
        components.day = 30
        components.hour = 23
        components.minute = 59
        components.second = 59
        return components.date ?? .distantFuture
    }()

    var title: String {
        switch self {
        case .lifetime:
            return "Founding Member (Lifetime)"
        case .annual:
            return "Annual (Early Adopter)"
        case .monthly:
            return "Monthly"
        }
    }

    var plainTitle: String {
        switch self {
        case .lifetime:
            return "Founding Member (Lifetime)"
        case .annual:
            return "Annual (Early Adopter)"
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
        switch self {
        case .lifetime:
            let calendar = Calendar(identifier: .gregorian)
            let today = calendar.startOfDay(for: Date())
            let endDay = calendar.startOfDay(for: Self.foundingMemberEndDate)
            let remainingDays = max(0, calendar.dateComponents([.day], from: today, to: endDay).day ?? 0)
            let dayWord = remainingDays == 1 ? "day" : "days"
            return "Ends in \(remainingDays) \(dayWord)"
        case .annual, .monthly:
            return nil
        }
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
        switch self {
        case .annual:
            return "$180"
        case .lifetime, .monthly:
            return nil
        }
    }

    var trialText: String? {
        switch self {
        case .lifetime:
            return nil
        case .annual:
            return "10-day free trial"
        case .monthly:
            return "Most flexible, cancel anytime"
        }
    }

    var trialDetailText: String? {
        switch self {
        case .lifetime:
            return nil
        case .annual:
            let calendar = Calendar(identifier: .gregorian)
            let today = calendar.startOfDay(for: Date())
            let endDay = calendar.startOfDay(for: Self.annualPricingLockEndDate)
            let remainingDays = max(0, calendar.dateComponents([.day], from: today, to: endDay).day ?? 0)
            let dayWord = remainingDays == 1 ? "day" : "days"
            return "Start in \(remainingDays) \(dayWord) for price-lock for life"
        case .monthly:
            return nil
        }
    }

    var summaryText: String? {
        switch self {
        case .lifetime:
            return "$129 one-time purchase. No subscription renewal."
        case .annual:
            return "Manage or cancel subscriptions anytime in Apple Account Settings."
        case .monthly:
            return "Manage or cancel subscriptions anytime in Apple Account Settings."
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
            return "Founding Member (Lifetime) access is a one-time payment. Members enjoy all Loom features for life and get exclusive, early access to innovations. This offer ends May 31, 2026."
        case .annual:
            return "Annual (Early Adopter) includes a 10-day free trial and price-lock for life if you start before June 30, 2026. Payment will be charged to your Apple ID at the end of the trial period unless canceled at least 24 hours before the trial ends. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in your Apple ID account settings."
        case .monthly:
            return "Monthly is billed to your Apple ID after purchase confirmation. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in your Apple ID account settings."
        }
    }

    var detailSheetTitle: String {
        switch self {
        case .lifetime:
            return "Founding Member (Lifetime)"
        case .annual:
            return "Annual (Early Adopter)"
        case .monthly:
            return "Monthly"
        }
    }

    var ctaText: String {
        switch self {
        case .lifetime:
            return "Purchase Lifetime Access"
        case .annual:
            return "Start 10-Day Free Trial"
        case .monthly:
            return "Subscribe Monthly"
        }
    }

    var plainCTATitle: String {
        switch self {
        case .lifetime:
            return "Purchase Lifetime Access"
        case .annual:
            return "Start 10-Day Free Trial"
        case .monthly:
            return "Subscribe Monthly"
        }
    }
}
