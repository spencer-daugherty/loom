import Foundation

extension Notification.Name {
    static let loomPresentInactiveSubscriptionPaywall = Notification.Name("loomPresentInactiveSubscriptionPaywall")
}

enum SubscriptionAccessGate {
    static let inactivePurchaseOverrideKey = "dev_inactive_purchase_override"
    static let inactiveBannerMessage = "Your subscription is inactive. Select an option to continue access."

    static func hasActiveSubscription(
        isSubscribed: Bool,
        inactivePurchaseOverrideEnabled: Bool
    ) -> Bool {
        isSubscribed && !inactivePurchaseOverrideEnabled
    }

    static func presentInactiveSubscriptionPaywall() {
        NotificationCenter.default.post(name: .loomPresentInactiveSubscriptionPaywall, object: nil)
    }
}
