import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    enum PurchaseOutcome: Equatable {
        case success
        case pending
        case userCancelled
        case failed(errorType: String)
    }

    enum RestoreOutcome: Equatable {
        case restoredActiveEntitlement
        case noActivePurchasesFound
        case failed(errorType: String)
    }

    @Published private(set) var products: [Product] = []
    @Published private(set) var ownedProductIDs: Set<String> = []
    @Published private(set) var isPremium = false
    @Published private(set) var activePlan: SubscriptionPlan?
    @Published private(set) var isProcessing = false
    @Published private(set) var hasLoadedEntitlements = false

    private let defaults: UserDefaults
    private var productsByID: [String: Product] = [:]
    private var transactionUpdatesTask: Task<Void, Never>?
    private weak var session: UserSessionStore?

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        transactionUpdatesTask = observeTransactionUpdates()
    }

    deinit {
        transactionUpdatesTask?.cancel()
    }

    func configure(session: UserSessionStore) {
        self.session = session
    }

    func product(for plan: SubscriptionPlan) -> Product? {
        productsByID[plan.storeKitProductID]
    }

    func loadProducts() async {
        do {
            let fetchedProducts = try await Product.products(for: SubscriptionPlan.allCases.map(\.storeKitProductID))
            let mappedProducts = Dictionary(uniqueKeysWithValues: fetchedProducts.map { ($0.id, $0) })
            let missingProductIDs = Set(SubscriptionPlan.allCases.map(\.storeKitProductID)).subtracting(mappedProducts.keys)
            if !missingProductIDs.isEmpty {
                log("Missing products from App Store Connect: \(missingProductIDs.sorted().joined(separator: ", "))")
            }

            productsByID = mappedProducts
            products = SubscriptionPlan.allCases.compactMap { mappedProducts[$0.storeKitProductID] }
        } catch {
            log("Failed to load products: \(error.localizedDescription)")
            productsByID = [:]
            products = []
        }
    }

    func refreshEntitlements(session: UserSessionStore? = nil) async {
        if let session {
            configure(session: session)
        }

        var activeProductIDs = Set<String>()
        let now = Date()

        for await entitlement in Transaction.currentEntitlements {
            switch entitlement {
            case .verified(let transaction):
                guard transaction.revocationDate == nil else { continue }
                if let expirationDate = transaction.expirationDate, expirationDate <= now {
                    continue
                }
                guard SubscriptionPlan.from(storeKitProductID: transaction.productID) != nil else { continue }
                activeProductIDs.insert(transaction.productID)
            case .unverified(let transaction, let error):
                log("Ignoring unverified entitlement \(transaction.productID): \(error.localizedDescription)")
            }
        }

        applyEntitlementSnapshot(activeProductIDs: activeProductIDs)
        hasLoadedEntitlements = true
    }

    func purchase(plan: SubscriptionPlan, session: UserSessionStore? = nil) async -> PurchaseOutcome {
        if let session {
            configure(session: session)
        }

        guard !isProcessing else { return .failed(errorType: "busy") }
        if product(for: plan) == nil {
            await loadProducts()
        }
        guard let product = product(for: plan) else {
            log("Attempted purchase with missing product: \(plan.storeKitProductID)")
            return .failed(errorType: "product_missing")
        }

        isProcessing = true
        defer { isProcessing = false }

        do {
            let result = try await product.purchase()
            switch result {
            case .success(let verification):
                switch verification {
                case .verified(let transaction):
                    await transaction.finish()
                    await refreshEntitlements()
                    return .success
                case .unverified(let transaction, let error):
                    log("Unverified purchase for \(transaction.productID): \(error.localizedDescription)")
                    return .failed(errorType: "unverified")
                }
            case .pending:
                return .pending
            case .userCancelled:
                return .userCancelled
            @unknown default:
                log("Unknown purchase result for \(plan.storeKitProductID)")
                return .failed(errorType: "unknown_result")
            }
        } catch {
            let nsError = error as NSError
            if nsError.domain == SKErrorDomain, nsError.code == SKError.paymentCancelled.rawValue {
                return .userCancelled
            }
            log("Purchase failed for \(plan.storeKitProductID): \(error.localizedDescription)")
            return .failed(errorType: "purchase_error")
        }
    }

    func restorePurchases(session: UserSessionStore? = nil) async -> RestoreOutcome {
        if let session {
            configure(session: session)
        }

        guard !isProcessing else { return .failed(errorType: "busy") }
        isProcessing = true
        defer { isProcessing = false }

        do {
            try await AppStore.sync()
        } catch {
            log("Restore purchases failed: \(error.localizedDescription)")
            await refreshEntitlements()
            return .failed(errorType: "sync_failed")
        }

        await refreshEntitlements()
        return isPremium ? .restoredActiveEntitlement : .noActivePurchasesFound
    }

    private func observeTransactionUpdates() -> Task<Void, Never> {
        Task(priority: .background) { [weak self] in
            for await update in Transaction.updates {
                guard let self else { return }
                switch update {
                case .verified(let transaction):
                    await transaction.finish()
                    await self.refreshEntitlements()
                case .unverified(let transaction, let error):
                    self.log("Ignoring unverified transaction update \(transaction.productID): \(error.localizedDescription)")
                }
            }
        }
    }

    private func applyEntitlementSnapshot(activeProductIDs: Set<String>) {
        ownedProductIDs = activeProductIDs

        let resolvedPlan: SubscriptionPlan?
        if activeProductIDs.contains(SubscriptionPlan.lifetime.storeKitProductID) {
            resolvedPlan = .lifetime
        } else if activeProductIDs.contains(SubscriptionPlan.annual.storeKitProductID) {
            resolvedPlan = .annual
        } else if activeProductIDs.contains(SubscriptionPlan.monthly.storeKitProductID) {
            resolvedPlan = .monthly
        } else {
            resolvedPlan = nil
        }

        activePlan = resolvedPlan
        isPremium = resolvedPlan != nil

        if let resolvedPlan {
            defaults.set(resolvedPlan.rawValue, forKey: "loom.subscription_plan")
        }
        defaults.set(isPremium, forKey: UserSessionStore.Keys.isSubscribed)
        session?.setIsSubscribed(isPremium)
    }

    private func log(_ message: String) {
        print("[PurchaseManager] \(message)")
    }
}
