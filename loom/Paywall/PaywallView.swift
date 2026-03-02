import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorScheme) private var colorScheme

    @StateObject private var purchaseManager = PurchaseManager()
    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var presentedLegalDocument: LegalDocument?
    @State private var previewIndex: Int = 0
    @State private var previewCycleTask: Task<Void, Never>?
    @State private var didLogPaywallViewed = false

    var body: some View {
        GeometryReader { geo in
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("No Free Lunch")
                        .font(.largeTitle.weight(.bold))
                    Text("Join the project to end stress and live fulfilled.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                onboardingAnimationPreviewBox

                VStack(spacing: 10) {
                    planCard(for: .annual)
                        .accessibilityIdentifier("paywall_plan_annual")
                    planCard(for: .monthly)
                        .accessibilityIdentifier("paywall_plan_monthly")
                }
                .padding(.top, 6)

                Button {
                    AnalyticsLogger.log(.purchaseStarted(plan: selectedPlan.rawValue))
                    Task {
                        let outcome = await purchaseManager.purchase(plan: selectedPlan, session: session)
                        switch outcome {
                        case .success:
                            AnalyticsLogger.log(.purchaseCompleted(plan: selectedPlan.rawValue))
                        case .failed(let errorType):
                            AnalyticsLogger.log(.purchaseFailed(plan: selectedPlan.rawValue, errorType: errorType))
                        }
                    }
                } label: {
                    if purchaseManager.isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(selectedPlan.ctaText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchaseManager.isProcessing)
                .accessibilityIdentifier("paywall_primaryCTA")

                Text("Annual includes a 10-day free trial. Payment is charged to your Apple ID after confirmation (or after the trial ends). Subscription renews automatically unless canceled at least 24 hours before renewal. Manage or cancel anytime in Apple ID Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await purchaseManager.restorePurchases(session: session) }
                } label: {
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(purchaseManager.isProcessing)
                .accessibilityIdentifier("paywall_restore")

                HStack(spacing: 16) {
                    Button("Terms of Use") { presentedLegalDocument = .terms }
                    Button("Privacy Policy") { presentedLegalDocument = .privacy }
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
            }
            .padding(20)
            .frame(width: geo.size.width, height: geo.size.height, alignment: .topLeading)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .onAppear {
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
            if !session.isSubscribed {
                AnalyticsLogger.log(.paywallAbandoned(reason: "dismissed"))
            }
        }
        .onChange(of: selectedPlan) { _, newPlan in
            AnalyticsLogger.log(.paywallPlanSelected(plan: newPlan.rawValue))
        }
    }

    private var onboardingAnimationPreviewBox: some View {
        let page = OnboardingCopy.pages[previewIndex % max(1, OnboardingCopy.pages.count)]
        return ZStack {
            switch page.visualKind {
            case .strands:
                StrandAnimationPlaceholderView(
                    reduceMotion: reduceMotion,
                    colors: [.blue, .indigo, .green, .purple, .red, .orange]
                )
            case .weave:
                LoomSplashBoxPlaceholderView(reduceMotion: reduceMotion)
            case .identity:
                IdentityVisionPlaceholderView(reduceMotion: reduceMotion)
            case .balance:
                FulfillmentBalancePlaceholderView(reduceMotion: reduceMotion)
            case .execution:
                TodayMockPlaceholderView(reduceMotion: reduceMotion)
            case .radar:
                LittleWinsDeckPlaceholderView(reduceMotion: reduceMotion)
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
        .frame(height: 250)
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

#Preview {
    PaywallView()
        .environmentObject(UserSessionStore())
}
