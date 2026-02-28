import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum PurchaseOutcome {
        case success
        case failed(errorType: String)
    }

    @Published private(set) var isProcessing = false

    // TODO: Replace with real StoreKit product IDs when wiring to production.
    // TODO: Load Product instances from the App Store and map to SubscriptionPlan.

    func purchase(plan: SubscriptionPlan, session: UserSessionStore) async -> PurchaseOutcome {
        guard !isProcessing else { return .failed(errorType: "failed") }
        isProcessing = true
        defer { isProcessing = false }

        UserDefaults.standard.set(plan.rawValue, forKey: "loom.subscription_plan")
        try? await Task.sleep(for: .milliseconds(800))
        session.markSubscribed()
        return .success
    }

    func restorePurchases(session: UserSessionStore) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        try? await Task.sleep(for: .milliseconds(800))
        if UserDefaults.standard.string(forKey: "loom.subscription_plan") == nil {
            UserDefaults.standard.set(SubscriptionPlan.annual.rawValue, forKey: "loom.subscription_plan")
        }
        session.markSubscribed()
    }
}
