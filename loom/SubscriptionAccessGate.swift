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
        guard LoomInternalDemoMode.isEnabled, workspace == .reviewDemo else { return nil }
        let rawValue = UserDefaults.standard
            .string(forKey: LoomInternalDemoMode.grantedPlanDefaultsKey)?
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard let rawValue, !rawValue.isEmpty else { return nil }
        return SubscriptionPlan(rawValue: rawValue)
    }

    static func hasActiveSubscription(
        isSubscribed: Bool,
        inactivePurchaseOverrideEnabled: Bool,
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> Bool {
        _ = workspace
        return isSubscribed && !inactivePurchaseOverrideEnabled
    }

    static func presentInactiveSubscriptionPaywall() {
        NotificationCenter.default.post(name: .loomPresentInactiveSubscriptionPaywall, object: nil)
    }
}
