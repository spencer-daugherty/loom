import Foundation

enum SubscriptionPlan: String, CaseIterable, Identifiable {
    case lifetime
    case annual
    case monthly

    var id: String { rawValue }

    static let launchVisiblePlans: [SubscriptionPlan] = [.lifetime]

    static var launchVisibleProductIDs: [String] {
        launchVisiblePlans.map(\.storeKitProductID)
    }

    var availabilityDate: Date? {
        let calendar = Calendar(identifier: .gregorian)

        switch self {
        case .lifetime:
            return nil
        case .annual:
            return calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))
        case .monthly:
            return calendar.date(from: DateComponents(year: 2026, month: 7, day: 1))
        }
    }

    var availabilityDateLabel: String? {
        switch self {
        case .lifetime:
            return nil
        case .annual:
            return "June 1, 2026"
        case .monthly:
            return "July 1, 2026"
        }
    }

    func isSelectable(on currentDate: Date = Date(), calendar: Calendar = .current) -> Bool {
        guard let availabilityDate else { return true }
        return calendar.startOfDay(for: currentDate) >= calendar.startOfDay(for: availabilityDate)
    }

    func availabilityCountdownText(on currentDate: Date = Date(), calendar: Calendar = .current) -> String? {
        guard let availabilityDate, let availabilityDateLabel else { return nil }

        let currentDay = calendar.startOfDay(for: currentDate)
        let availableDay = calendar.startOfDay(for: availabilityDate)
        guard currentDay < availableDay else { return nil }

        let remainingDays = max(1, calendar.dateComponents([.day], from: currentDay, to: availableDay).day ?? 0)
        let dayText = remainingDays == 1 ? "1 day" : "\(remainingDays) days"
        return "Available on \(availabilityDateLabel) (\(dayText))"
    }

    var storeKitProductID: String {
        switch self {
        case .lifetime:
            return "lifetime"
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
            return title
        case .annual:
            return title
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
