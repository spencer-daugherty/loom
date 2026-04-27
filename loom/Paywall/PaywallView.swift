import SwiftUI
import StoreKit
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

struct PaywallView: View {
    enum Mode {
        case standard
        case managePaywall
    }

    let bannerMessage: String?
    let mode: Mode

    private enum PaywallLoadingAction {
        case purchase
        case restore
    }

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var session: UserSessionStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("account_email") private var accountEmail = ""
    @State private var selectedPlan: SubscriptionPlan = .lifetime
    @State private var presentedLegalDocument: LegalDocument?
    @State private var currentDate = Date()
    @State private var previewIndex: Int = 0
    @State private var previewCycleTask: Task<Void, Never>?
    @State private var availabilityRefreshTask: Task<Void, Never>?
    @State private var didLogPaywallViewed = false
    @State private var headerHeight: CGFloat = 0
    @State private var lowerContentHeight: CGFloat = 0
    @State private var activeLoadingAction: PaywallLoadingAction?
    @State private var restoreStatusMessage: String?
    @State private var restoreFailureAlertMessage: String?
    @State private var purchaseFailureAlertMessage: String?
    @State private var purchaseStatusMessage: String?
    @State private var paywallReminderStatusMessage: String?
    @State private var pendingAvailabilityReminderPlan: SubscriptionPlan?
    @State private var armedAvailabilityReminderPlans: Set<SubscriptionPlan> = []
    @State private var hasInitializedPlanSelection = false
    @State private var pendingLifetimeConfirmationPlan: SubscriptionPlan?
    @State private var queuedPurchaseAfterLifetimeConfirmation: QueuedPurchaseAfterConfirmation?
    private let paywallPreviewBaseScale: CGFloat = 0.7

    private struct QueuedPurchaseAfterConfirmation: Equatable {
        let plan: SubscriptionPlan
        let dismissOnSuccess: Bool
        let fallbackSelection: SubscriptionPlan?
    }

    init(bannerMessage: String? = nil, mode: Mode = .standard) {
        self.bannerMessage = bannerMessage
        self.mode = mode
    }

    private var showsInactiveSubscriptionBanner: Bool {
        if let bannerMessage, !bannerMessage.isEmpty {
            return true
        }
        return false
    }

    private var effectivePaywallPreviewBaseScale: CGFloat {
        let bannerAdjustedScale = showsInactiveSubscriptionBanner
            ? paywallPreviewBaseScale * 0.75
            : paywallPreviewBaseScale
        return bannerAdjustedScale
    }

    private var usesManageHeader: Bool {
        switch mode {
        case .standard:
            return false
        case .managePaywall:
            return true
        }
    }

    private var analyticsMode: String {
        switch mode {
        case .standard:
            return "standard"
        case .managePaywall:
            return "manage"
        }
    }

    private var selectedPlanAction: PurchaseManager.PlanAction {
        purchaseManager.planAction(for: selectedPlan)
    }

    private var visiblePlans: [SubscriptionPlan] {
        SubscriptionPlan.launchVisiblePlans
    }

    private var shouldShowPreviewBox: Bool {
        mode == .standard
    }

    private var shouldDismissAfterSuccessfulPurchase: Bool {
        usesManageHeader
    }

    private var trimmedAccountEmail: String {
        accountEmail.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var currentPlanLabel: String {
        purchaseManager.activePlan?.plainTitle ?? "Inactive"
    }

    private var selectedPlanPresentation: PurchaseManager.PlanPresentation {
        purchaseManager.presentation(for: selectedPlan)
    }

    private var isSelectedPlanPurchaseReady: Bool {
        purchaseManager.isProductReadyForPurchase(for: selectedPlan)
    }

    private var shouldDisablePrimaryCTA: Bool {
        if LoomDeveloperBuild.isInternalBuild {
            return purchaseManager.isProcessing || !isPlanSelectable(selectedPlan)
        }
        return purchaseManager.isProcessing || !selectedPlanAction.allowsPurchase || !isSelectedPlanPurchaseReady
    }

    private var paywallCatalogMessage: String? {
        guard isPlanSelectable(selectedPlan) else { return nil }
        return purchaseManager.launchPurchaseCatalogMessage
    }

    private var availabilityOverlayTextColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var needsProductRefreshForSelectablePlans: Bool {
        SubscriptionPlan.launchVisiblePlans.contains { plan in
            plan.isSelectable(on: currentDate) && purchaseManager.product(for: plan) == nil
        }
    }

    private func isPlanSelectable(_ plan: SubscriptionPlan) -> Bool {
        guard visiblePlans.contains(plan) else { return false }
        return plan.isSelectable(on: currentDate)
    }

    private func preferredManageSelection() -> SubscriptionPlan {
        if let pendingPlan = purchaseManager.pendingAutoRenewPlan {
            return pendingPlan
        }
        if let activePlan = purchaseManager.activePlan {
            return activePlan
        }
        return visiblePlans.first ?? .lifetime
    }

    var body: some View {
        standardPaywallBody
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .alert(
            "Purchase \(selectedPlanPresentation.detailSheetTitle)?",
            isPresented: Binding(
                get: { pendingLifetimeConfirmationPlan != nil },
                set: { isPresented in
                    if !isPresented {
                        pendingLifetimeConfirmationPlan = nil
                    }
                }
            ),
            actions: {
                Button("Cancel", role: .cancel) {
                    pendingLifetimeConfirmationPlan = nil
                    if let pendingPlan = purchaseManager.pendingAutoRenewPlan {
                        selectedPlan = pendingPlan
                    } else if let activePlan = purchaseManager.activePlan {
                        selectedPlan = activePlan
                    }
                }
                Button("Continue") {
                    guard let pendingLifetimeConfirmationPlan else { return }
                    let confirmedPlan = pendingLifetimeConfirmationPlan
                    let fallbackSelection = purchaseManager.activePlan
                    self.pendingLifetimeConfirmationPlan = nil
                    queuedPurchaseAfterLifetimeConfirmation = QueuedPurchaseAfterConfirmation(
                        plan: confirmedPlan,
                        dismissOnSuccess: shouldDismissAfterSuccessfulPurchase,
                        fallbackSelection: fallbackSelection
                    )
                }
            },
            message: {
                if case .purchaseLifetimeAlongsideAutoRenewing(let current) = selectedPlanAction {
                    Text("Lifetime does not automatically cancel your current \(current.plainTitle.lowercased()) subscription. After purchase, cancel the subscription separately in Apple Account Settings to avoid future renewal charges.")
                }
            }
        )
        .alert(
            "The purchase did not complete",
            isPresented: Binding(
                get: { purchaseFailureAlertMessage != nil },
                set: { isPresented in
                    if !isPresented {
                        purchaseFailureAlertMessage = nil
                    }
                }
            )
        ) {
            Button("OK", role: .cancel) {
                purchaseFailureAlertMessage = nil
            }
        } message: {
            Text(purchaseFailureAlertMessage ?? "")
        }
        .onAppear {
            purchaseManager.configure(session: session)
            if purchaseManager.products.isEmpty {
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            initializeSelectedPlanIfNeeded()
            currentDate = Date()
            Task {
                await refreshPaywallAvailabilityReminders(now: currentDate)
            }
            if needsProductRefreshForSelectablePlans {
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            availabilityRefreshTask?.cancel()
            availabilityRefreshTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 60_000_000_000)
                    guard !Task.isCancelled else { break }
                    currentDate = Date()
                    await refreshPaywallAvailabilityReminders(now: currentDate)
                    if needsProductRefreshForSelectablePlans {
                        await purchaseManager.loadProducts()
                    }
                }
            }
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsLogger.log(.paywallViewed(mode: analyticsMode))
            }
            guard !reduceMotion else { return }
            previewCycleTask?.cancel()
            previewCycleTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_700_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(.easeInOut(duration: 0.28)) {
                        previewIndex = (previewIndex + 1) % max(1, OnboardingCopy.pages.count)
                    }
                }
            }
        }
        .onDisappear {
            previewCycleTask?.cancel()
            previewCycleTask = nil
            availabilityRefreshTask?.cancel()
            availabilityRefreshTask = nil
            if !purchaseManager.isPremium {
                AnalyticsLogger.log(.paywallAbandoned(reason: "dismissed"))
            }
        }
        .onChange(of: purchaseManager.activePlan) { _, newPlan in
            if usesManageHeader {
                if let pendingPlan = purchaseManager.pendingAutoRenewPlan {
                    selectedPlan = pendingPlan
                } else if let newPlan {
                    selectedPlan = newPlan
                } else {
                    selectedPlan = visiblePlans.first ?? .lifetime
                }
            }
            initializeSelectedPlanIfNeeded()
        }
        .onChange(of: purchaseManager.pendingAutoRenewPlan) { _, newPlan in
            guard usesManageHeader else { return }
            if let newPlan {
                selectedPlan = newPlan
            } else if let activePlan = purchaseManager.activePlan {
                selectedPlan = activePlan
            } else {
                selectedPlan = visiblePlans.first ?? .lifetime
            }
        }
        .onChange(of: queuedPurchaseAfterLifetimeConfirmation) { _, queuedPurchase in
            guard let queuedPurchase else { return }
            queuedPurchaseAfterLifetimeConfirmation = nil
            Task { @MainActor in
                try? await Task.sleep(nanoseconds: 350_000_000)
                await performPurchase(
                    for: queuedPurchase.plan,
                    dismissOnSuccess: queuedPurchase.dismissOnSuccess,
                    fallbackSelection: queuedPurchase.fallbackSelection
                )
            }
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard newPhase == .active else { return }
            Task {
                currentDate = Date()
                await refreshPaywallAvailabilityReminders(now: currentDate)
            }
        }
    }

    private var standardPaywallBody: some View {
        GeometryReader { geo in
            let viewportHeight = geo.size.height
            let topInset = geo.safeAreaInsets.top
            let bottomInset = geo.safeAreaInsets.bottom
            let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let verticalSpacing = paywallVerticalSpacing(for: availableHeight)
            let bottomClearance: CGFloat = 20
            ScrollView(showsIndicators: false) {
                VStack(alignment: .leading, spacing: verticalSpacing) {
                    if usesManageHeader {
                        manageCloseButton
                    }

                    if let bannerMessage, !bannerMessage.isEmpty {
                        paywallBanner(message: bannerMessage)
                    }

                    paywallHeader
                        .readHeight { headerHeight = $0 }

                    if shouldShowPreviewBox {
                        let previewScale = previewBoxScale(
                            for: availableHeight,
                            headerHeight: headerHeight,
                            lowerContentHeight: lowerContentHeight,
                            verticalSpacing: verticalSpacing,
                            bottomClearance: bottomClearance
                        ) * effectivePaywallPreviewBaseScale
                        onboardingAnimationPreviewBox(scale: previewScale)
                    }

                    paywallLowerContent(for: availableHeight, bottomClearance: bottomClearance)
                        .readHeight { lowerContentHeight = $0 }
                }
                .padding(.top, topInset + 20)
                .padding(.bottom, bottomInset)
                .frame(maxWidth: 720, alignment: .topLeading)
                .frame(maxWidth: .infinity, minHeight: viewportHeight, alignment: .top)
                .padding(.horizontal, 20)
            }
            .frame(width: geo.size.width, height: viewportHeight, alignment: .topLeading)
        }
    }

    private var paywallHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usesManageHeader {
                Text("Manage Your Plan")
                    .font(.largeTitle.weight(.bold))
                Text("Purchases are billed to the Apple ID currently signed in to the App Store on this device.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Text("No Free Lunch")
                    .font(.largeTitle.weight(.bold))
                Text("Join the movement to end stress and live fulfilled.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func paywallBanner(message: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(Color.black.opacity(0.72))
                .padding(.top, 1)

            Text(message)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(Color.black.opacity(0.76))
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    @ViewBuilder
    private func paywallLowerContent(for screenHeight: CGFloat, bottomClearance: CGFloat) -> some View {
        let planSpacing = planCardSpacing(for: screenHeight)
        let planTopPadding = paywallPlanTopPadding(for: screenHeight)
        let legalTopPadding = paywallLegalTopPadding(for: screenHeight)

        VStack(alignment: .leading, spacing: paywallVerticalSpacing(for: screenHeight)) {
            VStack(spacing: planSpacing) {
                ForEach(visiblePlans) { plan in
                    planCard(for: plan)
                        .accessibilityIdentifier("paywall_plan_\(plan.rawValue)")
                }
            }
            .padding(.top, planTopPadding)

            if let paywallReminderStatusMessage, !paywallReminderStatusMessage.isEmpty {
                Text(paywallReminderStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Button {
                AnalyticsLogger.log(
                    .purchaseStarted(
                        plan: selectedPlan.rawValue,
                        productID: selectedPlan.storeKitProductID
                    )
                )
                handlePrimaryCTA()
            } label: {
                ZStack {
                    Text(primaryCTAButtonTitle)
                        .opacity(activeLoadingAction == .purchase ? 0 : 1)
                    if activeLoadingAction == .purchase {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(shouldDisablePrimaryCTA)
            .accessibilityIdentifier("paywall_primaryCTA")

            if let paywallCatalogMessage {
                VStack(alignment: .leading, spacing: 8) {
                    Text(paywallCatalogMessage)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    if purchaseManager.launchPurchaseCatalogState == .temporarilyUnavailable {
                        Button("Retry App Store Connection") {
                            Task {
                                await purchaseManager.loadProducts()
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                    }
                }
            }

            Button {
                Task {
                    AnalyticsLogger.log(.restoreStarted())
                    restoreStatusMessage = nil
                    restoreFailureAlertMessage = nil
                    activeLoadingAction = .restore
                    let outcome = await purchaseManager.restorePurchases(session: session)
                    switch outcome {
                    case .restoredActiveEntitlement:
                        AnalyticsLogger.log(
                            .restoreCompleted(
                                restoreOutcome: "restored_active_entitlement",
                                plan: purchaseManager.activePlan?.rawValue
                            )
                        )
                        restoreStatusMessage = "Purchases restored."
                    case .noActivePurchasesFound:
                        AnalyticsLogger.log(.restoreCompleted(restoreOutcome: "no_active_purchases_found"))
                        restoreFailureAlertMessage = "Unfortunately, there was nothing to restore."
                    case .failed(let errorType):
                        AnalyticsLogger.log(.restoreCompleted(restoreOutcome: errorType))
                        restoreFailureAlertMessage = "Restore failed. Please try again."
                    }
                    activeLoadingAction = nil
                }
            } label: {
                ZStack {
                    Text("Restore Purchases")
                        .opacity(activeLoadingAction == .restore ? 0 : 1)
                    if activeLoadingAction == .restore {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.plain)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.blue)
            .disabled(purchaseManager.isProcessing)
            .accessibilityIdentifier("paywall_restore")
            .alert(
                "The purchase did not complete",
                isPresented: Binding(
                    get: { restoreFailureAlertMessage != nil },
                    set: { isPresented in
                        if !isPresented {
                            restoreFailureAlertMessage = nil
                        }
                    }
                )
            ) {
                Button("Cancel", role: .cancel) {
                    restoreFailureAlertMessage = nil
                }
            } message: {
                Text(restoreFailureAlertMessage ?? "")
            }

            if let restoreStatusMessage, !restoreStatusMessage.isEmpty {
                Text(restoreStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let purchaseStatusMessage, !purchaseStatusMessage.isEmpty {
                Text(purchaseStatusMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if selectedPlanPresentation.summaryText != nil
                || selectedPlanPresentation.disclosureDetailText != nil
                || !selectedPlanActionDisclosureParagraphs.isEmpty {
                inlineDisclosureSection
            }

            VStack(spacing: 4) {
                Text("Got a code?")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button("Redeem") {
                    Task {
                        await presentOfferCodeRedeemSheet()
                    }
                }
                .buttonStyle(.plain)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .frame(maxWidth: .infinity)

            HStack(spacing: 16) {
                Button("Standard License Agreement") { presentedLegalDocument = .terms }
                Button("Privacy Policy") { presentedLegalDocument = .privacy }
            }
            .font(.footnote.weight(.semibold))
            .padding(.top, legalTopPadding)
            .padding(.bottom, bottomClearance)
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private func onboardingAnimationPreviewBox(scale: CGFloat) -> some View {
        let page = OnboardingCopy.pages[previewIndex % max(1, OnboardingCopy.pages.count)]
        let scaledHeight = 250 * scale

        return ZStack(alignment: .top) {
            ZStack {
            switch page.visualKind {
            case .strands:
                StrandAnimationPlaceholderView(
                    reduceMotion: reduceMotion,
                    colors: [.blue, .indigo, .green, .purple, .red, .orange]
                )
            case .weave:
                LoomSplashBoxPlaceholderView(reduceMotion: reduceMotion)
            case .identity:
                IdentityVisionPlaceholderView(reduceMotion: reduceMotion, showsShadow: false)
            case .balance:
                FulfillmentBalancePlaceholderView(reduceMotion: reduceMotion, showsShadow: false)
            case .execution:
                TodayMockPlaceholderView(reduceMotion: reduceMotion)
            case .radar:
                LittleWinsDeckPlaceholderView(reduceMotion: reduceMotion, showsShadow: false)
            case .summary:
                LoomAIChatPlaceholderView(reduceMotion: reduceMotion)
            }

            Group {
                if colorScheme == .dark {
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.white.opacity(0.95))
                } else {
                    Image("logo")
                        .resizable()
                }
            }
            .scaledToFit()
            .frame(width: 28, height: 28)
            .padding(.trailing, 10)
            .padding(.bottom, 10)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 250, alignment: .top)
            .scaleEffect(scale, anchor: .top)
        }
        .frame(maxWidth: .infinity)
        .frame(height: scaledHeight, alignment: .top)
        .clipped()
    }

    private func previewBoxScale(
        for screenHeight: CGFloat,
        headerHeight: CGFloat,
        lowerContentHeight: CGFloat,
        verticalSpacing: CGFloat,
        bottomClearance: CGFloat
    ) -> CGFloat {
        let verticalPadding: CGFloat = 40
        let reservedHeight = verticalPadding + headerHeight + lowerContentHeight + (verticalSpacing * 2) + bottomClearance
        let remainingHeight = max(60, screenHeight - reservedHeight)
        return min(1, max(0.24, remainingHeight / 250))
    }

    private func paywallVerticalSpacing(for screenHeight: CGFloat) -> CGFloat {
        screenHeight < 700 ? 10 : 18
    }

    private func planCardSpacing(for screenHeight: CGFloat) -> CGFloat {
        screenHeight < 700 ? 8 : 10
    }

    private func paywallPlanTopPadding(for screenHeight: CGFloat) -> CGFloat {
        screenHeight < 700 ? 0 : 6
    }

    private func paywallLegalTopPadding(for screenHeight: CGFloat) -> CGFloat {
        screenHeight < 700 ? 0 : 4
    }

    private func planCard(for plan: SubscriptionPlan) -> some View {
        let selected = selectedPlan == plan
        let isCurrentPlan = purchaseManager.activePlan == plan
        let isIncludedWithLifetime = purchaseManager.activePlan == .lifetime && plan != .lifetime
        let isPendingPlan = purchaseManager.pendingAutoRenewPlan == plan
        let isSelectable = isPlanSelectable(plan)
        let availabilityCountdownText = plan.availabilityCountdownText(on: currentDate)
        let lifetimeCountdownText = plan.lifetimeOfferCountdownText(on: currentDate)
        let presentation = purchaseManager.presentation(for: plan)

        let cardContent = PaywallPlanCardContent(
            presentation: presentation,
            selected: selected,
            isSelectable: isSelectable,
            showsCurrentBadge: usesManageHeader && isCurrentPlan,
            showsPendingBadge: usesManageHeader && isPendingPlan,
            showsIncludedBadge: usesManageHeader && isIncludedWithLifetime,
            lifetimeCountdownText: lifetimeCountdownText
        )

        return ZStack {
            if isSelectable {
                Button {
                    selectedPlan = plan
                    AnalyticsLogger.log(
                        .paywallPlanSelected(
                            mode: analyticsMode,
                            plan: plan.rawValue,
                            productID: plan.storeKitProductID
                        )
                    )
                } label: {
                    cardContent
                }
                .buttonStyle(.plain)
            } else {
                cardContent
            }
        }
        .overlay {
            if !isSelectable, let availabilityCountdownText {
                unavailablePlanOverlay(
                    for: plan,
                    availabilityCountdownText: availabilityCountdownText
                )
            }
        }
    }

    private func unavailablePlanOverlay(
        for plan: SubscriptionPlan,
        availabilityCountdownText: String
    ) -> some View {
        RoundedRectangle(cornerRadius: 14, style: .continuous)
            .fill(Color(.systemBackground).opacity(0.84))
            .overlay {
                HStack(alignment: .center, spacing: 12) {
                    Text(availabilityCountdownText)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(availabilityOverlayTextColor)
                        .multilineTextAlignment(.leading)

                    Spacer(minLength: 0)

                    if pendingAvailabilityReminderPlan == plan {
                        ProgressView()
                            .controlSize(.small)
                    } else if armedAvailabilityReminderPlans.contains(plan) {
                        Button("You'll be reminded") { }
                            .buttonStyle(.plain)
                            .disabled(true)
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.secondary)
                    } else {
                        Button("Notify me") {
                            Task {
                                await handlePaywallAvailabilityReminderTap(for: plan)
                            }
                        }
                        .buttonStyle(.plain)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.blue)
                        .accessibilityIdentifier("paywall_notify_\(plan.rawValue)")
                    }
                }
                .padding(.horizontal, 16)
            }
    }

    private var manageCloseButton: some View {
        HStack {
            Spacer()
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
        }
    }

    private var primaryCTAButtonTitle: String {
        switch selectedPlanAction {
        case .purchaseNew:
            return selectedPlanPresentation.ctaTitle
        case .currentPlan:
            return "Current Plan"
        case .scheduledAutoRenewChange:
            return "Change Scheduled"
        case .switchAutoRenewable(_, let to):
            return "Switch to \(to.title)"
        case .purchaseLifetimeAlongsideAutoRenewing:
            return "Purchase Lifetime Access"
        case .includedWithLifetime:
            return "Included with Lifetime"
        }
    }

    private var selectedPlanActionDisclosureParagraphs: [String] {
        switch selectedPlanAction {
        case .purchaseNew:
            return []
        case .currentPlan:
            if selectedPlan == .lifetime { return [] }
            if let pendingPlan = purchaseManager.pendingAutoRenewPlan,
               pendingPlan != selectedPlan,
               let effectiveDate = purchaseManager.pendingAutoRenewEffectiveDate {
                return [
                    "Your current \(selectedPlan.plainTitle.lowercased()) plan remains active until \(formattedMonthDay(effectiveDate)). \(pendingPlan.title) starts after that."
                ]
            }
            return ["This Apple ID already has this auto-renewing plan."]
        case .scheduledAutoRenewChange(let from, let to, let effectiveDate):
            if let effectiveDate {
                return [
                    "\(to.title) starts \(formattedMonthDay(effectiveDate)) after your current \(from.plainTitle.lowercased()) plan ends."
                ]
            }
            return [
                "\(to.title) is scheduled for your next renewal after your current \(from.plainTitle.lowercased()) plan ends."
            ]
        case .switchAutoRenewable:
            return [
                "Monthly and annual changes take effect at your next renewal date. Apple will confirm the exact start date before you subscribe."
            ]
        case .purchaseLifetimeAlongsideAutoRenewing(let current):
            return [
                "Lifetime does not automatically cancel your current \(current.plainTitle.lowercased()) subscription. After purchase, cancel the subscription separately in Apple Account Settings to avoid future renewal charges."
            ]
        case .includedWithLifetime:
            return []
        }
    }

    @ViewBuilder
    private var inlineDisclosureSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let summaryText = selectedPlanPresentation.summaryText {
                Text(summaryText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if let detailText = selectedPlanPresentation.disclosureDetailText {
                Text(detailText)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }

            if !selectedPlanActionDisclosureParagraphs.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(selectedPlanActionDisclosureParagraphs.enumerated()), id: \.offset) { _, paragraph in
                        Text(paragraph)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }
    }

    private func initializeSelectedPlanIfNeeded() {
        guard !hasInitializedPlanSelection else { return }
        if usesManageHeader {
            selectedPlan = preferredManageSelection()
        } else {
            selectedPlan = visiblePlans.first ?? .lifetime
        }
        hasInitializedPlanSelection = true
    }

    private func handlePrimaryCTA() {
        guard isPlanSelectable(selectedPlan) else {
            selectedPlan = visiblePlans.first ?? .lifetime
            return
        }
        if LoomDeveloperBuild.isInternalBuild {
            purchaseManager.grantDebugAccess(plan: selectedPlan, session: session)
            purchaseStatusMessage = "Debug access granted."
            purchaseFailureAlertMessage = nil
            restoreStatusMessage = nil
            dismiss()
            return
        }
        guard isSelectedPlanPurchaseReady else {
            return
        }
        let previousSelection = purchaseManager.activePlan
        switch selectedPlanAction {
        case .purchaseLifetimeAlongsideAutoRenewing:
            pendingLifetimeConfirmationPlan = selectedPlan
        case .purchaseNew, .switchAutoRenewable:
            Task {
                await performPurchase(
                    for: selectedPlan,
                    dismissOnSuccess: shouldDismissAfterSuccessfulPurchase,
                    fallbackSelection: previousSelection
                )
            }
        case .currentPlan, .scheduledAutoRenewChange, .includedWithLifetime:
            return
        }
    }

    private func performPurchase(
        for plan: SubscriptionPlan,
        dismissOnSuccess: Bool = false,
        fallbackSelection: SubscriptionPlan? = nil
    ) async {
        guard isPlanSelectable(plan) else {
            selectedPlan = visiblePlans.first ?? .lifetime
            return
        }
        purchaseStatusMessage = nil
        purchaseFailureAlertMessage = nil
        restoreStatusMessage = nil
        activeLoadingAction = .purchase
        defer { activeLoadingAction = nil }

        let previousSelection = fallbackSelection ?? purchaseManager.activePlan
        let outcome = await purchaseManager.purchase(plan: plan, session: session)
        switch outcome {
        case .success:
            AnalyticsLogger.log(.purchaseCompleted(plan: plan.rawValue, productID: plan.storeKitProductID))
            purchaseStatusMessage = nil
            if dismissOnSuccess {
                dismiss()
            }
        case .pending:
            AnalyticsLogger.log(.purchaseFailed(plan: plan.rawValue, productID: plan.storeKitProductID, errorType: "pending"))
            purchaseStatusMessage = "Purchase is pending approval."
        case .userCancelled:
            purchaseStatusMessage = nil
            if let previousSelection {
                selectedPlan = previousSelection
            }
        case .failed(let errorType):
            AnalyticsLogger.log(.purchaseFailed(plan: plan.rawValue, productID: plan.storeKitProductID, errorType: errorType))
            purchaseFailureAlertMessage = purchaseFailureMessage(for: errorType)
            if let previousSelection {
                selectedPlan = previousSelection
            }
        }
    }

    private func purchaseFailureMessage(for errorType: String) -> String {
        switch errorType {
        case "busy":
            return "A purchase is already in progress."
        case "already_current_plan":
            return "This Apple ID already has the selected plan."
        case "already_pending_plan_change":
            if let pendingPlan = purchaseManager.pendingAutoRenewPlan {
                return "\(pendingPlan.title) is already scheduled for your next renewal."
            }
            return "This plan change is already scheduled."
        case "included_with_lifetime":
            return "No additional purchase is needed."
        case "not_available":
            return "This plan is not available yet."
        case "product_missing":
            return "The App Store purchase sheet isn't ready right now. Please try again in a moment."
        case "unverified":
            return "Apple could not verify this purchase."
        case "purchase_error":
            return "The purchase could not be completed right now. Please try again."
        case "unknown_result":
            return "The App Store returned an unknown purchase result."
        default:
            return "The purchase could not be completed. Please try again."
        }
    }

    @MainActor
    private func refreshPaywallAvailabilityReminders(now: Date) async {
        let activePlans = await LoomNotificationScheduler.activePaywallAvailabilityReminderPlans(now: now)
        armedAvailabilityReminderPlans = activePlans
        if paywallReminderStatusMessage != nil, !activePlans.isEmpty {
            paywallReminderStatusMessage = nil
        }
    }

    @MainActor
    private func handlePaywallAvailabilityReminderTap(for plan: SubscriptionPlan) async {
        let now = Date()
        currentDate = now
        paywallReminderStatusMessage = nil
        pendingAvailabilityReminderPlan = plan
        defer { pendingAvailabilityReminderPlan = nil }

        let initialAuthorizationStatus = await LoomNotificationScheduler.authorizationStatus()
        AnalyticsLogger.log(
            .paywallNotifyMeTapped(
                mode: analyticsMode,
                plan: plan.rawValue,
                productID: plan.storeKitProductID,
                daysUntilAvailable: plan.availabilityRemainingDays(on: now) ?? 0,
                authorizationStatus: initialAuthorizationStatus.loomAnalyticsValue
            )
        )

        let result = await LoomNotificationScheduler.requestPaywallAvailabilityReminder(for: plan, now: now)
        AnalyticsLogger.log(
            .paywallNotifyMeResult(
                mode: analyticsMode,
                plan: plan.rawValue,
                productID: plan.storeKitProductID,
                daysUntilAvailable: plan.availabilityRemainingDays(on: now) ?? 0,
                authorizationStatus: result.authorizationStatus.loomAnalyticsValue,
                result: result.outcome.rawValue
            )
        )

        await refreshPaywallAvailabilityReminders(now: now)

        switch result.outcome {
        case .scheduled, .alreadyScheduled:
            paywallReminderStatusMessage = nil
        case .permissionDenied, .promptDeclined:
            paywallReminderStatusMessage = "Enable notifications in Settings to get reminded."
        case .noLongerUnavailable:
            paywallReminderStatusMessage = nil
        case .scheduleFailed:
            paywallReminderStatusMessage = "The reminder could not be scheduled right now. Please try again."
        }
    }

    private func formattedMonthDay(_ date: Date) -> String {
        date.formatted(.dateTime.month(.wide).day())
    }

    @MainActor
    private func presentOfferCodeRedeemSheet() async {
#if canImport(UIKit)
        let activeWindowScene = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first { $0.activationState == .foregroundActive }

        if let activeWindowScene {
            do {
                try await AppStore.presentOfferCodeRedeemSheet(in: activeWindowScene)
                await purchaseManager.refreshEntitlements(session: session)
                if purchaseManager.isPremium {
                    purchaseStatusMessage = "Code redeemed. Lifetime access is active."
                    if shouldDismissAfterSuccessfulPurchase {
                        dismiss()
                    }
                } else {
                    purchaseStatusMessage = "If Apple accepted the code, access may take a moment to update. You can also tap Restore Purchases."
                }
                return
            } catch {
                AppDebugActivityLog.log(
                    "PaywallView",
                    "presentOfferCodeRedeemSheet failed error=\(error.localizedDescription)"
                )
            }
        }
#endif
        purchaseStatusMessage = "The redeem sheet could not be opened right now. Please try again."
    }
}

private struct PaywallPlanCardContent: View {
    let presentation: PurchaseManager.PlanPresentation
    let selected: Bool
    let isSelectable: Bool
    let showsCurrentBadge: Bool
    let showsPendingBadge: Bool
    let showsIncludedBadge: Bool
    let lifetimeCountdownText: String?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 3) {
                titleRow
                priceRow
                optionalDetailText(lifetimeCountdownText, weight: .semibold)
                optionalDetailText(presentation.tierText)
                optionalDetailText(presentation.tierDetailText)
                optionalDetailText(presentation.trialText)
                optionalDetailText(presentation.trialDetailText)
            }

            Spacer(minLength: 0)

            Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                .font(.title3)
                .opacity(isSelectable ? 1 : 0)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .opacity(isSelectable ? 1 : 0.42)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
        )
    }

    private var titleRow: some View {
        HStack(spacing: 8) {
            Text(presentation.title)
                .font(.headline)
                .foregroundStyle(.primary)

            if showsCurrentBadge {
                badge("Current", color: .accentColor, opacity: 0.14)
            } else if showsPendingBadge {
                badge("Pending", color: .orange, opacity: 0.14)
            } else if showsIncludedBadge {
                badge("Included", color: .green, opacity: 0.12)
            }
        }
    }

    private var priceRow: some View {
        HStack(spacing: 6) {
            if let originalPriceText = presentation.originalPriceText {
                Text(originalPriceText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .strikethrough()
            }

            Text(presentation.priceText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
        }
    }

    private func badge(_ text: String, color: Color, opacity: Double) -> some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(color.opacity(opacity))
            )
            .foregroundStyle(color)
    }

    @ViewBuilder
    private func optionalDetailText(
        _ text: String?,
        weight: Font.Weight? = nil
    ) -> some View {
        if let text {
            Text(text)
                .font(weight.map { .caption.weight($0) } ?? .caption)
                .foregroundStyle(.secondary)
        }
    }
}

private struct HeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private extension View {
    func readHeight(_ onChange: @escaping (CGFloat) -> Void) -> some View {
        background(
            GeometryReader { geometry in
                Color.clear
                    .preference(key: HeightPreferenceKey.self, value: geometry.size.height)
            }
        )
        .onPreferenceChange(HeightPreferenceKey.self, perform: onChange)
    }
}

#Preview {
    PaywallView()
        .environmentObject(UserSessionStore())
        .environmentObject(PurchaseManager())
}
