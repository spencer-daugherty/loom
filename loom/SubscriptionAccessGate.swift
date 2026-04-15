import Foundation

extension Notification.Name {
    static let loomPresentInactiveSubscriptionPaywall = Notification.Name("loomPresentInactiveSubscriptionPaywall")
}

enum SubscriptionAccessGate {
    static let inactivePurchaseOverrideKey = "dev_inactive_purchase_override"
    static let starterManualEntitlementAccessKey = "starter_manual_entitlement_access"
    static let starterPreferredProductIDKey = "starter_preferred_product_id"
    static let inactiveBannerMessage = "Your subscription is inactive. Select an option to continue access."

    static func shouldForceInactiveSubscription(
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> Bool {
        workspace == .starter
    }

    static func defaultPlan(
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> SubscriptionPlan? {
        switch workspace {
        case .reviewDemo:
            return .monthly
        default:
            return nil
        }
    }

    static func hasActiveSubscription(
        isSubscribed: Bool,
        inactivePurchaseOverrideEnabled: Bool,
        workspace: LoomSpecialAccountWorkspace? = LoomDefaultsScope.currentWorkspace()
    ) -> Bool {
        _ = workspace
        return isSubscribed && !inactivePurchaseOverrideEnabled
    }

    static func allowsStarterEntitlementAccess(defaults: UserDefaults = .standard) -> Bool {
        defaults.bool(forKey: starterManualEntitlementAccessKey)
    }

    static func setStarterEntitlementAccess(_ isEnabled: Bool, defaults: UserDefaults = .standard) {
        defaults.set(isEnabled, forKey: starterManualEntitlementAccessKey)
    }

    static func starterPreferredProductID(defaults: UserDefaults = .standard) -> String? {
        let productID = defaults.string(forKey: starterPreferredProductIDKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let productID, !productID.isEmpty else { return nil }
        return productID
    }

    static func setStarterPreferredProductID(_ productID: String?, defaults: UserDefaults = .standard) {
        let trimmedProductID = productID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedProductID.isEmpty {
            defaults.removeObject(forKey: starterPreferredProductIDKey)
        } else {
            defaults.set(trimmedProductID, forKey: starterPreferredProductIDKey)
        }
    }

    static func presentInactiveSubscriptionPaywall() {
        NotificationCenter.default.post(name: .loomPresentInactiveSubscriptionPaywall, object: nil)
    }
}
