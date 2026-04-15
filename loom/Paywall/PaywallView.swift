import SwiftUI

struct PaywallView: View {
    enum Mode {
        case standard
        case manageSubscription
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
    @AppStorage("account_email") private var accountEmail = ""
    @State private var selectedPlan: SubscriptionPlan = .lifetime
    @State private var presentedLegalDocument: LegalDocument?
    @State private var isShowingTrialDetails = false
    @State private var previewIndex: Int = 0
    @State private var previewCycleTask: Task<Void, Never>?
    @State private var didLogPaywallViewed = false
    @State private var headerHeight: CGFloat = 0
    @State private var lowerContentHeight: CGFloat = 0
    @State private var activeLoadingAction: PaywallLoadingAction?
    @State private var restoreStatusMessage: String?
    @State private var purchaseStatusMessage: String?
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

    private var isManageSubscriptionMode: Bool {
        mode == .manageSubscription
    }

    private var usesManageHeader: Bool {
        switch mode {
        case .standard:
            return false
        case .manageSubscription, .managePaywall:
            return true
        }
    }

    private var selectedPlanAction: PurchaseManager.PlanAction {
        purchaseManager.planAction(for: selectedPlan)
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

    var body: some View {
        Group {
            if isManageSubscriptionMode {
                manageSubscriptionBody
            } else {
                standardPaywallBody
            }
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .sheet(isPresented: $isShowingTrialDetails) {
            NavigationStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        if let manageText = selectedPlan.manageOrCancelText {
                            Text(manageText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        if let detailText = selectedPlan.disclosureDetailText {
                            Text(detailText)
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .padding(20)
                }
                .navigationTitle(selectedPlan.detailSheetTitle)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingTrialDetails = false
                        }
                    }
                }
            }
            .presentationDetents([.height(250)])
            .presentationDragIndicator(.visible)
        }
        .alert(
            "Purchase Founding Member (Lifetime)?",
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
                    if let activePlan = purchaseManager.activePlan {
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
        .onAppear {
            purchaseManager.configure(session: session)
            if purchaseManager.products.isEmpty {
                Task {
                    await purchaseManager.loadProducts()
                }
            }
            initializeSelectedPlanIfNeeded()
            if !didLogPaywallViewed {
                didLogPaywallViewed = true
                AnalyticsLogger.log(.paywallViewed())
                AnalyticsLogger.log(.paywallPlanSelected(plan: selectedPlan.rawValue))
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
            if !purchaseManager.isPremium {
                AnalyticsLogger.log(.paywallAbandoned(reason: "dismissed"))
            }
        }
        .onChange(of: selectedPlan) { _, newPlan in
            AnalyticsLogger.log(.paywallPlanSelected(plan: newPlan.rawValue))
        }
        .onChange(of: purchaseManager.activePlan) { _, newPlan in
            if usesManageHeader, let newPlan {
                selectedPlan = newPlan
            }
            initializeSelectedPlanIfNeeded()
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
    }

    private var standardPaywallBody: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let verticalSpacing = paywallVerticalSpacing(for: availableHeight)
            let bottomClearance: CGFloat = 20
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
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .frame(width: geo.size.width, height: availableHeight, alignment: .topLeading)
        }
    }

    private var manageSubscriptionBody: some View {
        ZStack(alignment: .topTrailing) {
            Color(.systemBackground)
                .ignoresSafeArea()

            ScrollView(showsIndicators: false) {
                VStack(spacing: 22) {
                    manageCloseButton

                    VStack(spacing: 14) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .padding(10)
                        }
                        .frame(width: 64, height: 64)

                        Text("Available Plans")
                            .font(.title.weight(.bold))
                    }
                    .padding(.top, 8)

                    VStack(spacing: 12) {
                        ForEach(manageSubscriptionPlans, id: \.self) { plan in
                            managePlanRow(for: plan)
                        }
                    }
                    .padding(.top, 6)

                    if let purchaseStatusMessage, !purchaseStatusMessage.isEmpty {
                        Text(purchaseStatusMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    if let actionMessage = selectedPlanActionMessage {
                        Text(actionMessage)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Text("Purchases are billed to the Apple ID currently signed in to the App Store on this device. Monthly and annual plan changes should be configured in the same subscription group in App Store Connect.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 4)
                }
                .padding(.horizontal, 20)
                .padding(.top, 18)
                .padding(.bottom, 28)
            }
        }
    }

    private var paywallHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            if usesManageHeader {
                Text("Manage Your Plan")
                    .font(.largeTitle.weight(.bold))
            } else {
                Text("No Free Lunch")
                    .font(.largeTitle.weight(.bold))
                Text("Join the movement to end stress and live fulfilled.")
                    .font(.body)
                    .foregroundStyle(.secondary)
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
                planCard(for: .lifetime)
                    .accessibilityIdentifier("paywall_plan_lifetime")
                planCard(for: .annual)
                    .accessibilityIdentifier("paywall_plan_annual")
                planCard(for: .monthly)
                    .accessibilityIdentifier("paywall_plan_monthly")
            }
            .padding(.top, planTopPadding)

            if usesManageHeader {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Purchases are billed to the Apple ID currently signed in to the App Store on this device.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Button {
                AnalyticsLogger.log(.purchaseStarted(plan: selectedPlan.rawValue))
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
            .disabled(purchaseManager.isProcessing || !selectedPlanAction.allowsPurchase)
            .accessibilityIdentifier("paywall_primaryCTA")

            Button {
                Task {
                    restoreStatusMessage = nil
                    activeLoadingAction = .restore
                    let outcome = await purchaseManager.restorePurchases(session: session)
                    switch outcome {
                    case .restoredActiveEntitlement:
                        restoreStatusMessage = "Purchases restored."
                    case .noActivePurchasesFound:
                        restoreStatusMessage = "No active purchases were found for this Apple ID."
                    case .failed:
                        restoreStatusMessage = "Restore failed. Please try again."
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

            if let actionMessage = selectedPlanActionMessage {
                Text(actionMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let summaryText = selectedPlan.summaryText {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(summaryText)
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    if selectedPlan.disclosureDetailText != nil {
                        Button("Show more") {
                            isShowingTrialDetails = true
                        }
                        .font(.footnote.weight(.semibold))
                        .buttonStyle(.plain)
                    }
                }
            }

            HStack(spacing: 16) {
                Button("Terms of Use") { presentedLegalDocument = .terms }
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
        let isLockedByLifetimeSelection = isManageSubscriptionMode && purchaseManager.activePlan == .lifetime && plan != .lifetime

        return Button {
            guard !isLockedByLifetimeSelection else { return }
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 8) {
                        Text(plan.title)
                            .font(.headline)
                            .foregroundStyle(.primary)
                        if usesManageHeader && isCurrentPlan {
                            Text("Current")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.accentColor.opacity(0.14))
                                )
                                .foregroundStyle(Color.accentColor)
                        } else if usesManageHeader && isIncludedWithLifetime {
                            Text("Included")
                                .font(.caption2.weight(.semibold))
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(
                                    Capsule(style: .continuous)
                                        .fill(Color.green.opacity(0.12))
                                )
                                .foregroundStyle(Color.green)
                        }
                    }
                    HStack(spacing: 6) {
                        if let originalPriceText = plan.originalPriceText {
                            Text(originalPriceText)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .strikethrough()
                        }
                        Text(plan.priceText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    if let tierText = plan.tierText {
                        Text(tierText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let tierDetailText = plan.tierDetailText {
                            Text(tierDetailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let trialText = plan.trialText {
                        Text(trialText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        if let trialDetailText = plan.trialDetailText {
                            Text(trialDetailText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .font(.title3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .opacity(isLockedByLifetimeSelection ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(isLockedByLifetimeSelection)
    }

    private var manageSubscriptionPlans: [SubscriptionPlan] {
        [.monthly, .annual, .lifetime]
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

    private func managePlanRow(for plan: SubscriptionPlan) -> some View {
        let selected = selectedPlan == plan
        let isCurrentPlan = purchaseManager.activePlan == plan
        let isIncludedWithLifetime = purchaseManager.activePlan == .lifetime && plan != .lifetime
        let isLockedByLifetimeSelection = purchaseManager.activePlan == .lifetime && plan != .lifetime
        let isLoadingThisPlan = activeLoadingAction == .purchase && selected

        return Button {
            handleManagePlanSelection(plan)
        } label: {
            HStack(spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.plainTitle)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(plan.priceText)
                        .font(.body)
                        .foregroundStyle(.primary.opacity(0.78))
                }

                Spacer(minLength: 0)

                ZStack {
                    if isLoadingThisPlan {
                        ProgressView()
                    } else {
                        Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(selected ? .blue : .secondary)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.vertical, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(selected ? Color.blue : Color(.separator), lineWidth: selected ? 2 : 1)
            )
            .opacity(isLockedByLifetimeSelection ? 0.55 : 1)
        }
        .buttonStyle(.plain)
        .disabled(purchaseManager.isProcessing || isIncludedWithLifetime || isLockedByLifetimeSelection || isCurrentPlan)
    }

    private var primaryCTAButtonTitle: String {
        switch selectedPlanAction {
        case .purchaseNew:
            return selectedPlan.plainCTATitle
        case .currentPlan:
            return "Current Plan"
        case .switchAutoRenewable(_, let to):
            return "Switch to \(to.plainTitle)"
        case .purchaseLifetimeAlongsideAutoRenewing:
            return "Purchase Lifetime Access"
        case .includedWithLifetime:
            return "Included with Lifetime"
        }
    }

    private var selectedPlanActionMessage: String? {
        switch selectedPlanAction {
        case .purchaseNew:
            return nil
        case .currentPlan:
            if selectedPlan == .lifetime { return nil }
            return "This Apple ID already has this auto-renewing plan."
        case .switchAutoRenewable:
            return "Apple will show when the plan change takes effect before you confirm. Monthly and annual changes should be configured in the same subscription group in App Store Connect."
        case .purchaseLifetimeAlongsideAutoRenewing(let current):
            return "Lifetime does not automatically cancel your current \(current.plainTitle.lowercased()) subscription. After purchase, cancel the subscription separately in Apple Account Settings to avoid future renewal charges."
        case .includedWithLifetime:
            return nil
        }
    }

    private func initializeSelectedPlanIfNeeded() {
        guard !hasInitializedPlanSelection else { return }
        if usesManageHeader {
            if let activePlan = purchaseManager.activePlan {
                selectedPlan = activePlan
            } else {
                selectedPlan = .monthly
            }
        }
        hasInitializedPlanSelection = true
    }

    private func handleManagePlanSelection(_ plan: SubscriptionPlan) {
        let previousSelection = selectedPlan
        selectedPlan = plan
        purchaseStatusMessage = nil
        restoreStatusMessage = nil

        switch purchaseManager.planAction(for: plan) {
        case .currentPlan, .includedWithLifetime:
            return
        case .purchaseLifetimeAlongsideAutoRenewing:
            pendingLifetimeConfirmationPlan = plan
        case .purchaseNew, .switchAutoRenewable:
            Task {
                await performPurchase(for: plan, dismissOnSuccess: true, fallbackSelection: previousSelection)
            }
        }
    }

    private func handlePrimaryCTA() {
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
        case .currentPlan, .includedWithLifetime:
            return
        }
    }

    private func performPurchase(
        for plan: SubscriptionPlan,
        dismissOnSuccess: Bool = false,
        fallbackSelection: SubscriptionPlan? = nil
    ) async {
        purchaseStatusMessage = nil
        restoreStatusMessage = nil
        activeLoadingAction = .purchase
        defer { activeLoadingAction = nil }

        let previousSelection = fallbackSelection ?? purchaseManager.activePlan
        let outcome = await purchaseManager.purchase(plan: plan, session: session)
        switch outcome {
        case .success:
            AnalyticsLogger.log(.purchaseCompleted(plan: plan.rawValue))
            purchaseStatusMessage = nil
            if dismissOnSuccess {
                dismiss()
            }
        case .pending:
            AnalyticsLogger.log(.purchaseFailed(plan: plan.rawValue, errorType: "pending"))
            purchaseStatusMessage = "Purchase is pending approval."
        case .userCancelled:
            purchaseStatusMessage = nil
            if let previousSelection {
                selectedPlan = previousSelection
            }
        case .failed(let errorType):
            AnalyticsLogger.log(.purchaseFailed(plan: plan.rawValue, errorType: errorType))
            purchaseStatusMessage = purchaseFailureMessage(for: errorType)
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
        case "included_with_lifetime":
            return "No additional purchase is needed."
        case "product_missing":
            if let error = purchaseManager.productCatalogErrorDescription, !error.isEmpty {
                return "The App Store purchase sheet could not be prepared. \(error)"
            }
            if purchaseManager.missingProductIDs.contains(selectedPlan.storeKitProductID) {
                return "This purchase option is not currently available from App Store Connect for this build or Apple ID."
            }
            return "The App Store purchase sheet could not be prepared. Please try again."
        case "unverified":
            return "Apple could not verify this purchase."
        case "purchase_error":
            if let error = purchaseManager.productCatalogErrorDescription, !error.isEmpty {
                return "The purchase sheet did not complete. \(error)"
            }
            return "The purchase sheet did not complete. Make sure this device is signed in to the App Store and try again."
        case "unknown_result":
            return "The App Store returned an unknown purchase result."
        default:
            return "The purchase could not be completed. Please try again."
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
