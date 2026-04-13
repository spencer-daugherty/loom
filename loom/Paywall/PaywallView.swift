import SwiftUI

struct PaywallView: View {
    let bannerMessage: String?

    private enum PaywallLoadingAction {
        case purchase
        case restore
    }

    @EnvironmentObject private var session: UserSessionStore
    @EnvironmentObject private var purchaseManager: PurchaseManager
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

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
    private let paywallPreviewBaseScale: CGFloat = 0.7

    init(bannerMessage: String? = nil) {
        self.bannerMessage = bannerMessage
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

    var body: some View {
        GeometryReader { geo in
            let availableHeight = geo.size.height - geo.safeAreaInsets.top - geo.safeAreaInsets.bottom
            let verticalSpacing = paywallVerticalSpacing(for: availableHeight)
            let bottomClearance: CGFloat = 20
            let previewScale = previewBoxScale(
                for: availableHeight,
                headerHeight: headerHeight,
                lowerContentHeight: lowerContentHeight,
                verticalSpacing: verticalSpacing,
                bottomClearance: bottomClearance
            ) * effectivePaywallPreviewBaseScale
            VStack(alignment: .leading, spacing: verticalSpacing) {
                if let bannerMessage, !bannerMessage.isEmpty {
                    paywallBanner(message: bannerMessage)
                }

                paywallHeader
                    .readHeight { headerHeight = $0 }

                onboardingAnimationPreviewBox(scale: previewScale)

                paywallLowerContent(for: availableHeight, bottomClearance: bottomClearance)
                    .readHeight { lowerContentHeight = $0 }
            }
            .padding(.top, 20)
            .padding(.horizontal, 20)
            .frame(width: geo.size.width, height: availableHeight, alignment: .topLeading)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .sheet(isPresented: $isShowingTrialDetails) {
            NavigationStack {
                ScrollView {
                    if let detailText = selectedPlan.disclosureDetailText {
                        Text(detailText)
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(20)
                    }
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
        .onAppear {
            purchaseManager.configure(session: session)
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
    }

    private var paywallHeader: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(showsInactiveSubscriptionBanner ? "Subscription Required" : "Choose a Plan")
                .font(.largeTitle.weight(.bold))
            Text("Select a subscription or lifetime access option to continue using Loom.")
                .font(.body)
                .foregroundStyle(.secondary)
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

            Button {
                AnalyticsLogger.log(.purchaseStarted(plan: selectedPlan.rawValue))
                Task {
                    restoreStatusMessage = nil
                    activeLoadingAction = .purchase
                    let outcome = await purchaseManager.purchase(plan: selectedPlan, session: session)
                    switch outcome {
                    case .success:
                        AnalyticsLogger.log(.purchaseCompleted(plan: selectedPlan.rawValue))
                    case .pending:
                        AnalyticsLogger.log(.purchaseFailed(plan: selectedPlan.rawValue, errorType: "pending"))
                    case .userCancelled:
                        break
                    case .failed(let errorType):
                        AnalyticsLogger.log(.purchaseFailed(plan: selectedPlan.rawValue, errorType: errorType))
                    }
                    activeLoadingAction = nil
                }
            } label: {
                ZStack {
                    Text(selectedPlan.ctaText)
                        .opacity(activeLoadingAction == .purchase ? 0 : 1)
                    if activeLoadingAction == .purchase {
                        ProgressView()
                    }
                }
                .frame(maxWidth: .infinity, minHeight: 24)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            .disabled(purchaseManager.isProcessing)
            .accessibilityIdentifier("paywall_primaryCTA")

            if showsInactiveSubscriptionBanner {
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
            } else {
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
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(purchaseManager.isProcessing)
                .accessibilityIdentifier("paywall_restore")
            }

            if let restoreStatusMessage, !restoreStatusMessage.isEmpty {
                Text(restoreStatusMessage)
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

            if selectedPlan != .lifetime {
                Text("Manage or cancel subscriptions anytime in Apple Account Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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

        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(plan.priceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
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
        }
        .buttonStyle(.plain)
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
}
