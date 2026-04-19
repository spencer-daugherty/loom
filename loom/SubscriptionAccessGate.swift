import Foundation

extension Notification.Name {
    static let loomPresentInactiveSubscriptionPaywall = Notification.Name("loomPresentInactiveSubscriptionPaywall")
}

enum SubscriptionAccessGate {
    static let inactivePurchaseOverrideKey = "dev_inactive_purchase_override"
    static let inactiveBannerMessage = "Your subscription is inactive. Select an option to continue access."

    static func shouldForceInactiveSubscription(
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> Bool {
        _ = workspace
        return false
    }

    static func defaultPlan(
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> SubscriptionPlan? {
        _ = workspace
        return nil
    }

    static func hasActiveSubscription(
        isSubscribed: Bool,
        inactivePurchaseOverrideEnabled: Bool,
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> Bool {
        _ = workspace
        return isSubscribed && !LoomDeveloperBuild.enabled(inactivePurchaseOverrideEnabled)
    }

    static func presentInactiveSubscriptionPaywall() {
        NotificationCenter.default.post(name: .loomPresentInactiveSubscriptionPaywall, object: nil)
    }
}
