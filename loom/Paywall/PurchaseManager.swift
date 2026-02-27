import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    @Published private(set) var isProcessing = false

    // TODO: Replace with real StoreKit product IDs when wiring to production.
    // TODO: Load Product instances from the App Store and map to SubscriptionPlan.

    func purchase(plan: SubscriptionPlan, session: UserSessionStore) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        _ = plan
        try? await Task.sleep(for: .milliseconds(800))
        session.markSubscribed()
    }

    func restorePurchases(session: UserSessionStore) async {
        guard !isProcessing else { return }
        isProcessing = true
        defer { isProcessing = false }

        try? await Task.sleep(for: .milliseconds(800))
        session.markSubscribed()
    }
}
