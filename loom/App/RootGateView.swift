import SwiftUI

enum RootGatePresentationStyle {
    case fullScreen
    case halfSheet
}

struct RootGateView<MainContent: View>: View {
    private let presentationStyle: RootGatePresentationStyle
    private let mainContent: MainContent

    @StateObject private var session = UserSessionStore()
    @StateObject private var purchaseManager = PurchaseManager()

    @AppStorage(UserSessionStore.Keys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.hasCompletedDiagnostic) private var hasCompletedDiagnostic = false
    @AppStorage(UserSessionStore.Keys.hasSeenDiagnosticInsights) private var hasSeenDiagnosticInsights = false
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @AppStorage("onboarding_reset_on_next_launch") private var onboardingResetOnNextLaunch = false
    @AppStorage("blank_homepage_mode") private var blankHomepageMode = false
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    @AppStorage("return_to_onboarding_last_page_once") private var returnToOnboardingLastPageOnce = false
    @AppStorage("analytics_install_date") private var analyticsInstallDate = ""
    @AppStorage("analytics_last_active_date") private var analyticsLastActiveDate = ""
    @AppStorage("analytics_did_log_retention_day_1") private var analyticsDidLogRetentionDay1 = false
    @AppStorage("analytics_did_log_retention_day_7") private var analyticsDidLogRetentionDay7 = false
    @AppStorage("analytics_did_log_first_activation") private var analyticsDidLogFirstActivation = false

    @State private var isGatePresented = false
    @State private var hasAppliedOnboardingResetForLaunch = false
    @State private var hasLoggedCoreOpenedThisSession = false
    @StateObject private var personalizationStore = PersonalizationStore()
    @State private var gatePath: [GateRoute] = []
    @State private var isSyncingGatePath = false
    @State private var diagnosticPrefillDraft: PersonalizationDraft?

    private enum GateRoute: Hashable {
        case account
        case diagnostic
        case insights
        case paywall
    }

    init(
        presentationStyle: RootGatePresentationStyle = .fullScreen,
        @ViewBuilder content: () -> MainContent
    ) {
        self.presentationStyle = presentationStyle
        self.mainContent = content()
    }

    var body: some View {
        mainContent
            .environmentObject(session)
            .environmentObject(personalizationStore)
            .environmentObject(purchaseManager)
            .onAppear {
                consumePendingOnboardingResetIfNeeded()
                migrateDiagnosticCompletionIfNeeded()
                initializeInstallDateIfNeeded()
                syncSessionFromStorage()
                purchaseManager.configure(session: session)
                syncGatePresentationState()
                syncGatePathFromSession(animated: false)
                trackCoreEntryIfNeeded()
                Task {
                    await personalizationStore.reloadForCurrentUser()
                }
            }
            .task {
                purchaseManager.configure(session: session)
                await purchaseManager.loadProducts()
                await purchaseManager.refreshEntitlements(session: session)
                #if canImport(AuthenticationServices)
                await session.refreshAppleCredentialStateIfNeeded()
                #endif
            }
            .onChange(of: hasSeenOnboarding) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: hasAccount) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
                Task { await personalizationStore.reloadForCurrentUser() }
            }
            .onChange(of: hasCompletedDiagnostic) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: hasSeenDiagnosticInsights) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: isSubscribed) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.hasSeenOnboarding) { _, value in
                hasSeenOnboarding = value
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.hasAccount) { _, value in
                hasAccount = value
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
                Task {
                    await purchaseManager.refreshEntitlements(session: session)
                }
                Task { await personalizationStore.reloadForCurrentUser() }
            }
            .onChange(of: session.hasCompletedDiagnostic) { _, value in
                hasCompletedDiagnostic = value
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.hasSeenDiagnosticInsights) { _, value in
                hasSeenDiagnosticInsights = value
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.isSubscribed) { _, value in
                isSubscribed = value
                syncGatePresentationState()
                syncGatePathFromSession()
                trackCoreEntryIfNeeded()
            }
            .modifier(
                GatePresentationModifier(
                    presentationStyle: presentationStyle,
                    isPresented: gatePresentationBinding,
                    gateContent: gateContent,
                    onDismiss: handleGateDismiss
                )
            )
            .overlay(alignment: .bottom) {
                LoomAITroubleshootingBannerHost()
            }
            .overlay {
                if !purchaseManager.hasLoadedEntitlements {
                    ZStack {
                        Color(.systemBackground)
                            .ignoresSafeArea()
                        ProgressView()
                    }
                }
            }
    }

    private var gatePresentationBinding: Binding<Bool> {
        Binding(
            get: { isGatePresented },
            set: { newValue in
                isGatePresented = newValue
                if !newValue && session.requiresGate {
                    DispatchQueue.main.async {
                        isGatePresented = true
                    }
                }
            }
        )
    }

    @ViewBuilder
    private var gateContent: some View {
        NavigationStack(path: gatePathBinding) {
            OnboardingFlowView()
                .navigationDestination(for: GateRoute.self) { route in
                    switch route {
                    case .account:
                        AccountStepView()
                    case .diagnostic:
                        DiagnosticFlowView(mode: .onboarding, initialDraft: resolvedDiagnosticPrefillDraft) { draft, _ in
                            let saved = try? await personalizationStore.saveSnapshot(from: draft, source: .onboarding)
                            guard saved != nil else { return }
                            diagnosticPrefillDraft = nil
                            session.markDiagnosticCompleted()
                            session.setHasSeenDiagnosticInsights(false)
                        }
                        .navigationTitle("Quick diagnostic")
                        .navigationBarTitleDisplayMode(.inline)
                    case .insights:
                        DiagnosticInsightsView(
                            onContinue: {
                                session.markDiagnosticInsightsSeen()
                            },
                            onEditAnswers: {
                                diagnosticPrefillDraft = personalizationStore.current.map(PersonalizationDraft.init(snapshot:))
                                session.setHasCompletedDiagnostic(false)
                                session.setHasSeenDiagnosticInsights(false)
                            }
                        )
                        .navigationTitle("Insights")
                        .navigationBarTitleDisplayMode(.inline)
                    case .paywall:
                        PaywallView()
                            .navigationBarTitleDisplayMode(.inline)
                    }
                }
        }
        .environmentObject(session)
        .environmentObject(personalizationStore)
        .environmentObject(purchaseManager)
    }

    private func syncSessionFromStorage() {
        session.setHasSeenOnboarding(hasSeenOnboarding)
        session.setHasAccount(hasAccount)
        if !hasAccount, hasCompletedDiagnostic {
            hasCompletedDiagnostic = false
        }
        if !hasCompletedDiagnostic, hasSeenDiagnosticInsights {
            hasSeenDiagnosticInsights = false
        }
        session.setHasCompletedDiagnostic(hasCompletedDiagnostic)
        session.setHasSeenDiagnosticInsights(hasSeenDiagnosticInsights)
        session.setIsSubscribed(isSubscribed)
    }

    private var resolvedDiagnosticPrefillDraft: PersonalizationDraft? {
        if let diagnosticPrefillDraft {
            return diagnosticPrefillDraft
        }
        guard let workspace = LoomDefaultsScope.currentWorkspace(), workspace.shouldPrefillDiagnosticDuringOnboarding else {
            return nil
        }
        guard session.hasAccount, !session.hasCompletedDiagnostic else { return nil }
        return LoomDemoWorkspaceSeeder.demoPersonalizationDraft()
    }

    private func syncGatePresentationState() {
        isGatePresented = session.requiresGate
        if session.requiresGate {
            hasLoggedCoreOpenedThisSession = false
        }
    }

    private func handleGateDismiss() {
        if session.requiresGate {
            DispatchQueue.main.async {
                isGatePresented = true
            }
        }
    }

    private func consumePendingOnboardingResetIfNeeded() {
        guard onboardingResetOnNextLaunch, !hasAppliedOnboardingResetForLaunch else { return }
        hasSeenOnboarding = false
        hasAccount = false
        hasCompletedDiagnostic = false
        hasSeenDiagnosticInsights = false
        isSubscribed = false
        blankHomepageMode = true
        setupHomepageMode = false
        hasAppliedOnboardingResetForLaunch = true
    }

    private func migrateDiagnosticCompletionIfNeeded() {
        let defaults = UserDefaults.standard
        if defaults.object(forKey: UserSessionStore.Keys.hasCompletedDiagnostic) == nil {
            // Existing account holders should not be forced through a new gate midstream.
            hasCompletedDiagnostic = hasAccount
        }
        if defaults.object(forKey: UserSessionStore.Keys.hasSeenDiagnosticInsights) == nil {
            hasSeenDiagnosticInsights = hasCompletedDiagnostic
        }
    }

    private var desiredGatePath: [GateRoute] {
        guard session.hasSeenOnboarding else { return [] }
        if !session.hasAccount {
            return [.account]
        }
        if !session.hasCompletedDiagnostic {
            return [.diagnostic]
        }
        if !session.hasSeenDiagnosticInsights {
            return [.insights]
        }
        return []
    }

    private var gatePathBinding: Binding<[GateRoute]> {
        Binding(
            get: { gatePath },
            set: { newPath in
                let oldPath = gatePath
                if !isSyncingGatePath, newPath.count < oldPath.count {
                    let removed = oldPath.suffix(oldPath.count - newPath.count)
                    handleGateRoutePop(removed)
                }
                gatePath = newPath
            }
        )
    }

    private func syncGatePathFromSession(animated: Bool = true) {
        let targetPath = desiredGatePath
        guard gatePath != targetPath else { return }
        isSyncingGatePath = true
        if animated {
            withAnimation(.easeInOut(duration: 0.22)) {
                gatePath = targetPath
            }
        } else {
            gatePath = targetPath
        }
        isSyncingGatePath = false
    }

    private func handleGateRoutePop(_ removedRoutes: ArraySlice<GateRoute>) {
        guard !removedRoutes.isEmpty else { return }
        if removedRoutes.contains(.paywall) || removedRoutes.contains(.insights) || removedRoutes.contains(.diagnostic) || removedRoutes.contains(.account) {
            returnToOnboardingLastPageOnce = true
            session.setHasSeenOnboarding(false)
        }
    }

    private func initializeInstallDateIfNeeded() {
        if analyticsInstallDate.isEmpty {
            analyticsInstallDate = Self.analyticsDayString(from: Date())
        }
    }

    private func trackCoreEntryIfNeeded() {
        guard !session.requiresGate else { return }
        if !hasLoggedCoreOpenedThisSession {
            hasLoggedCoreOpenedThisSession = true
            if !analyticsDidLogFirstActivation {
                analyticsDidLogFirstActivation = true
                AnalyticsLogger.log(.firstActivation())
            }
            AnalyticsLogger.log(.coreOpened())
            AnalyticsLogger.featureUsed("main_app_opened", source: "root_gate", step: "content", variant: nil)
            // TODO: Add feature_used events for weekly_reset_started / weekly_reset_completed.
            // TODO: Add feature_used events for action_block_created.
            // TODO: Add feature_used events for radar_viewed.
            // TODO: Add feature_used events for driving_force_saved.
        }
        logDailyActiveIfNeeded()
    }

    private func logDailyActiveIfNeeded() {
        let today = Self.analyticsDayString(from: Date())
        if analyticsLastActiveDate == today {
            return
        }
        initializeInstallDateIfNeeded()
        let daysSinceInstall = Self.daysBetween(analyticsInstallDate, today)
        AnalyticsLogger.log(.dailyActive(sessionDay: daysSinceInstall))

        if daysSinceInstall == 1 && !analyticsDidLogRetentionDay1 {
            analyticsDidLogRetentionDay1 = true
            AnalyticsLogger.log(.retentionDay1())
        }
        if daysSinceInstall == 7 && !analyticsDidLogRetentionDay7 {
            analyticsDidLogRetentionDay7 = true
            AnalyticsLogger.log(.retentionDay7())
        }

        analyticsLastActiveDate = today
    }

    private static func analyticsDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func daysBetween(_ startDay: String, _ endDay: String) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startDate = formatter.date(from: startDay),
              let endDate = formatter.date(from: endDay) else {
            return 0
        }
        let calendar = Calendar(identifier: .gregorian)
        let value = calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0
        return max(0, value)
    }
}

private struct GatePresentationModifier<GateContent: View>: ViewModifier {
    let presentationStyle: RootGatePresentationStyle
    @Binding var isPresented: Bool
    let gateContent: GateContent
    let onDismiss: () -> Void

    func body(content: Content) -> some View {
        switch presentationStyle {
        case .fullScreen:
            content
                .fullScreenCover(isPresented: $isPresented, onDismiss: onDismiss) {
                    gateContent
                }
        case .halfSheet:
            content
                .sheet(isPresented: $isPresented, onDismiss: onDismiss) {
                    gateContent
                }
        }
    }
}

#Preview {
    RootGateView {
        Color.green
    }
}
