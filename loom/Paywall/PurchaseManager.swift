import Foundation
import StoreKit

@MainActor
final class PurchaseManager: ObservableObject {
    struct PlanPresentation: Equatable {
        let title: String
        let priceText: String
        let originalPriceText: String?
        let tierText: String?
        let tierDetailText: String?
        let trialText: String?
        let trialDetailText: String?
        let summaryText: String?
        let manageOrCancelText: String?
        let disclosureDetailText: String?
        let detailSheetTitle: String
        let ctaTitle: String
    }

    enum PlanAction: Equatable {
        case purchaseNew
        case currentPlan
        case scheduledAutoRenewChange(from: SubscriptionPlan, to: SubscriptionPlan, effectiveDate: Date?)
        case switchAutoRenewable(from: SubscriptionPlan, to: SubscriptionPlan)
        case purchaseLifetimeAlongsideAutoRenewing(current: SubscriptionPlan)
        case includedWithLifetime

        var allowsPurchase: Bool {
            switch self {
            case .purchaseNew, .switchAutoRenewable, .purchaseLifetimeAlongsideAutoRenewing:
                return true
            case .currentPlan, .scheduledAutoRenewChange, .includedWithLifetime:
                return false
            }
        }
    }

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
    @Published private(set) var activePlanPeriodEndDate: Date?
    @Published private(set) var activePlanWillAutoRenew: Bool?
    @Published private(set) var pendingAutoRenewPlan: SubscriptionPlan?
    @Published private(set) var pendingAutoRenewEffectiveDate: Date?
    @Published private(set) var isProcessing = false
    @Published private(set) var hasLoadedEntitlements = false
    @Published private(set) var isLoadingProducts = false
    @Published private(set) var missingProductIDs: Set<String> = []
    @Published private(set) var productCatalogErrorDescription: String?

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

    func presentation(for plan: SubscriptionPlan) -> PlanPresentation {
        let product = product(for: plan)
        let introOffer = introductoryOffer(for: plan, product: product)
        let trialLabel = introOffer.flatMap(freeTrialLabel(for:))

        return PlanPresentation(
            title: plan.title,
            priceText: displayPriceText(for: plan, product: product),
            originalPriceText: originalComparisonPriceText(for: plan),
            tierText: plan.tierText,
            tierDetailText: plan.tierDetailText,
            trialText: trialText(for: plan, introOfferLabel: trialLabel),
            trialDetailText: trialDetailText(for: plan),
            summaryText: summaryText(for: plan, product: product),
            manageOrCancelText: plan.manageOrCancelText,
            disclosureDetailText: disclosureDetailText(for: plan, introOfferLabel: trialLabel),
            detailSheetTitle: plan.detailSheetTitle,
            ctaTitle: ctaTitle(for: plan, introOfferLabel: trialLabel)
        )
    }

    func planAction(for plan: SubscriptionPlan) -> PlanAction {
        guard let activePlan else { return .purchaseNew }
        if activePlan == plan {
            return .currentPlan
        }
        if let pendingAutoRenewPlan, pendingAutoRenewPlan == plan {
            return .scheduledAutoRenewChange(
                from: activePlan,
                to: plan,
                effectiveDate: pendingAutoRenewEffectiveDate
            )
        }
        if activePlan == .lifetime {
            return .includedWithLifetime
        }
        if plan == .lifetime {
            return .purchaseLifetimeAlongsideAutoRenewing(current: activePlan)
        }
        return .switchAutoRenewable(from: activePlan, to: plan)
    }

    func loadProducts() async {
        guard !isLoadingProducts else { return }
        isLoadingProducts = true
        defer { isLoadingProducts = false }

        do {
            let fetchedProducts = try await Product.products(for: SubscriptionPlan.allCases.map(\.storeKitProductID))
            let mappedProducts = Dictionary(uniqueKeysWithValues: fetchedProducts.map { ($0.id, $0) })
            let missingProductIDs = Set(SubscriptionPlan.allCases.map(\.storeKitProductID)).subtracting(mappedProducts.keys)
            if !missingProductIDs.isEmpty {
                log("Missing products from App Store Connect: \(missingProductIDs.sorted().joined(separator: ", "))")
            }

            self.missingProductIDs = missingProductIDs
            productCatalogErrorDescription = nil
            productsByID = mappedProducts
            products = SubscriptionPlan.allCases.compactMap { mappedProducts[$0.storeKitProductID] }
        } catch {
            log("Failed to load products: \(error.localizedDescription)")
            missingProductIDs = Set(SubscriptionPlan.allCases.map(\.storeKitProductID))
            productCatalogErrorDescription = error.localizedDescription
            productsByID = [:]
            products = []
        }
    }

    func refreshEntitlements(session: UserSessionStore? = nil) async {
        if let session {
            configure(session: session)
        }

        if let defaultPlan = SubscriptionAccessGate.defaultPlan() {
            clearPendingAutoRenewChange()
            applyEntitlementSnapshot(activeProductIDs: [defaultPlan.storeKitProductID], expirationDatesByProductID: [:])
            hasLoadedEntitlements = true
            return
        }

        var activeProductIDs = Set<String>()
        var expirationDatesByProductID: [String: Date] = [:]
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
                if let expirationDate = transaction.expirationDate {
                    let currentDate = expirationDatesByProductID[transaction.productID]
                    if currentDate == nil || expirationDate > currentDate! {
                        expirationDatesByProductID[transaction.productID] = expirationDate
                    }
                }
            case .unverified(let transaction, let error):
                log("Ignoring unverified entitlement \(transaction.productID): \(error.localizedDescription)")
            }
        }

        applyEntitlementSnapshot(activeProductIDs: activeProductIDs, expirationDatesByProductID: expirationDatesByProductID)
        await refreshAutoRenewStatusIfNeeded()
        hasLoadedEntitlements = true
    }

    func purchase(plan: SubscriptionPlan, session: UserSessionStore? = nil) async -> PurchaseOutcome {
        if let session {
            configure(session: session)
        }

        guard !isProcessing else { return .failed(errorType: "busy") }
        let action = planAction(for: plan)
        if !action.allowsPurchase {
            switch action {
            case .currentPlan:
                return .failed(errorType: "already_current_plan")
            case .scheduledAutoRenewChange:
                return .failed(errorType: "already_pending_plan_change")
            case .includedWithLifetime:
                return .failed(errorType: "included_with_lifetime")
            case .purchaseNew, .switchAutoRenewable, .purchaseLifetimeAlongsideAutoRenewing:
                return .failed(errorType: "purchase_not_allowed")
            }
        }
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
                    switch action {
                    case .purchaseNew, .purchaseLifetimeAlongsideAutoRenewing:
                        applyOptimisticEntitlementSnapshot(forPurchasedProductID: transaction.productID)
                    case .switchAutoRenewable:
                        clearPendingAutoRenewChange()
                    case .currentPlan, .scheduledAutoRenewChange, .includedWithLifetime:
                        break
                    }
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

    private func applyEntitlementSnapshot(
        activeProductIDs: Set<String>,
        expirationDatesByProductID: [String: Date] = [:]
    ) {
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
        activePlanPeriodEndDate = resolvedPlan.flatMap { expirationDatesByProductID[$0.storeKitProductID] }
        activePlanWillAutoRenew = resolvedPlan == .lifetime ? false : nil
        if resolvedPlan == nil || resolvedPlan == .lifetime {
            clearPendingAutoRenewChange()
        }
        let hasEntitlement = resolvedPlan != nil
        isPremium = hasEntitlement

        if let resolvedPlan {
            defaults.set(resolvedPlan.rawValue, forKey: "loom.subscription_plan")
        } else {
            defaults.removeObject(forKey: "loom.subscription_plan")
        }
        defaults.set(isPremium, forKey: UserSessionStore.Keys.isSubscribed)
        session?.setIsSubscribed(isPremium)
    }

    private func applyOptimisticEntitlementSnapshot(forPurchasedProductID productID: String) {
        guard SubscriptionPlan.from(storeKitProductID: productID) != nil else { return }
        applyEntitlementSnapshot(activeProductIDs: [productID])
        hasLoadedEntitlements = true
    }

    private func refreshAutoRenewStatusIfNeeded() async {
        guard let activePlan, activePlan == .annual || activePlan == .monthly else {
            if activePlan == nil {
                activePlanPeriodEndDate = nil
                activePlanWillAutoRenew = nil
            }
            clearPendingAutoRenewChange()
            return
        }
        if product(for: activePlan) == nil {
            await loadProducts()
        }
        clearPendingAutoRenewChange()
        guard let product = product(for: activePlan), let subscription = product.subscription else { return }

        do {
            let statuses = try await subscription.status
            for status in statuses {
                let verifiedTransaction: Transaction
                switch status.transaction {
                case .verified(let transaction):
                    guard transaction.productID == activePlan.storeKitProductID else { continue }
                    verifiedTransaction = transaction
                    if let expirationDate = transaction.expirationDate {
                        activePlanPeriodEndDate = expirationDate
                    }
                case .unverified:
                    continue
                }

                switch status.renewalInfo {
                case .verified(let renewalInfo):
                    guard renewalInfo.currentProductID == activePlan.storeKitProductID else { continue }
                    activePlanWillAutoRenew = renewalInfo.willAutoRenew
                    if let renewalDate = renewalInfo.renewalDate {
                        activePlanPeriodEndDate = renewalDate
                        pendingAutoRenewEffectiveDate = renewalDate
                    } else {
                        pendingAutoRenewEffectiveDate = verifiedTransaction.expirationDate
                    }
                    if let autoRenewPreference = renewalInfo.autoRenewPreference,
                       autoRenewPreference != renewalInfo.currentProductID,
                       let pendingPlan = SubscriptionPlan.from(storeKitProductID: autoRenewPreference) {
                        pendingAutoRenewPlan = pendingPlan
                    } else {
                        clearPendingAutoRenewChange()
                    }
                    return
                case .unverified(_, let error):
                    log("Ignoring unverified renewal info for \(activePlan.storeKitProductID): \(error.localizedDescription)")
                }
            }
        } catch {
            log("Failed to load subscription status for \(activePlan.storeKitProductID): \(error.localizedDescription)")
        }
    }

    private func clearPendingAutoRenewChange() {
        pendingAutoRenewPlan = nil
        pendingAutoRenewEffectiveDate = nil
    }

    private func displayPriceText(for plan: SubscriptionPlan, product: Product?) -> String {
        guard let product else { return plan.priceText }

        switch plan {
        case .lifetime:
            return "\(product.displayPrice) one-time"
        case .annual:
            return "\(product.displayPrice) / year"
        case .monthly:
            return "\(product.displayPrice) / month"
        }
    }

    private func originalComparisonPriceText(for plan: SubscriptionPlan) -> String? {
        _ = plan
        return nil
    }

    private func introductoryOffer(for plan: SubscriptionPlan, product: Product?) -> Product.SubscriptionOffer? {
        guard plan == .annual, let product else { return nil }
        return product.subscription?.introductoryOffer
    }

    private func trialText(for plan: SubscriptionPlan, introOfferLabel: String?) -> String? {
        switch plan {
        case .annual:
            return introOfferLabel
        case .monthly:
            return plan.trialText
        case .lifetime:
            return nil
        }
    }

    private func trialDetailText(for plan: SubscriptionPlan) -> String? {
        _ = plan
        return nil
    }

    private func summaryText(for plan: SubscriptionPlan, product: Product?) -> String? {
        switch plan {
        case .lifetime:
            let livePrice = product?.displayPrice ?? plan.priceText.replacingOccurrences(of: " one-time", with: "")
            return "\(livePrice) one-time purchase. No subscription renewal."
        case .annual:
            if let product {
                return "\(product.displayPrice) billed yearly. Auto-renewable."
            }
            return plan.summaryText
        case .monthly:
            if let product {
                return "\(product.displayPrice) billed monthly. Auto-renewable."
            }
            return plan.summaryText
        }
    }

    private func disclosureDetailText(for plan: SubscriptionPlan, introOfferLabel: String?) -> String? {
        switch plan {
        case .lifetime:
            return plan.disclosureDetailText
        case .annual:
            if let introOfferLabel {
                return "Annual includes a \(introOfferLabel). Payment will be charged to your Apple ID at the end of the introductory period unless canceled at least 24 hours before it ends. Subscription renews automatically unless canceled at least 24 hours before the end of the current period. Your account will be charged for renewal within 24 hours prior to the end of the current period. You can manage or cancel your subscription anytime in Apple Account Settings."
            }
            return plan.disclosureDetailText
        case .monthly:
            return plan.disclosureDetailText
        }
    }

    private func ctaTitle(for plan: SubscriptionPlan, introOfferLabel: String?) -> String {
        switch plan {
        case .annual:
            if let introOfferLabel {
                return "Start \(titleCased(label: introOfferLabel))"
            }
            return "Subscribe Annual"
        case .lifetime, .monthly:
            return plan.plainCTATitle
        }
    }

    private func freeTrialLabel(for offer: Product.SubscriptionOffer) -> String? {
        guard offer.paymentMode == .freeTrial else { return nil }
        return "\(hyphenated(period: offer.period)) free intro offer"
    }

    private func hyphenated(period: Product.SubscriptionPeriod) -> String {
        let unit: String
        switch period.unit {
        case .day:
            unit = "day"
        case .week:
            unit = "week"
        case .month:
            unit = "month"
        case .year:
            unit = "year"
        @unknown default:
            unit = "period"
        }
        return "\(period.value)-\(unit)"
    }

    private func titleCased(label: String) -> String {
        label
            .split(separator: " ")
            .map { word in
                word
                    .split(separator: "-")
                    .map { component in
                        guard let firstCharacter = component.first else { return "" }
                        return firstCharacter.uppercased() + String(component.dropFirst())
                    }
                    .joined(separator: "-")
            }
            .joined(separator: " ")
    }

    private func log(_ message: String) {
        print("[PurchaseManager] \(message)")
    }
}
