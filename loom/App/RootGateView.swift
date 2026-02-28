import SwiftUI

enum RootGatePresentationStyle {
    case fullScreen
    case halfSheet
}

struct RootGateView<MainContent: View>: View {
    private let presentationStyle: RootGatePresentationStyle
    private let mainContent: MainContent

    @StateObject private var session = UserSessionStore()

    @AppStorage(UserSessionStore.Keys.hasSeenOnboarding) private var hasSeenOnboarding = false
    @AppStorage(UserSessionStore.Keys.hasAccount) private var hasAccount = false
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @AppStorage("onboarding_reset_on_next_launch") private var onboardingResetOnNextLaunch = false
    @AppStorage("blank_homepage_mode") private var blankHomepageMode = false
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    @AppStorage("analytics_install_date") private var analyticsInstallDate = ""
    @AppStorage("analytics_last_active_date") private var analyticsLastActiveDate = ""
    @AppStorage("analytics_did_log_retention_day_1") private var analyticsDidLogRetentionDay1 = false
    @AppStorage("analytics_did_log_retention_day_7") private var analyticsDidLogRetentionDay7 = false
    @AppStorage("analytics_did_log_first_activation") private var analyticsDidLogFirstActivation = false

    @State private var isGatePresented = false
    @State private var hasAppliedOnboardingResetForLaunch = false
    @State private var hasLoggedCoreOpenedThisSession = false

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
            .onAppear {
                consumePendingOnboardingResetIfNeeded()
                initializeInstallDateIfNeeded()
                syncSessionFromStorage()
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .task {
                #if canImport(AuthenticationServices)
                await session.refreshAppleCredentialStateIfNeeded()
                #endif
            }
            .onChange(of: hasSeenOnboarding) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: hasAccount) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: isSubscribed) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.hasSeenOnboarding) { _, value in
                hasSeenOnboarding = value
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.hasAccount) { _, value in
                hasAccount = value
                syncGatePresentationState()
                trackCoreEntryIfNeeded()
            }
            .onChange(of: session.isSubscribed) { _, value in
                isSubscribed = value
                syncGatePresentationState()
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
        NavigationStack {
            switch session.currentGateStep {
            case .onboarding:
                OnboardingFlowView()
            case .account:
                AccountStepView()
            case .paywall:
                PaywallView()
            case .done:
                EmptyView()
            }
        }
        .environmentObject(session)
    }

    private func syncSessionFromStorage() {
        session.setHasSeenOnboarding(hasSeenOnboarding)
        session.setHasAccount(hasAccount)
        session.setIsSubscribed(isSubscribed)
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
        isSubscribed = false
        blankHomepageMode = true
        setupHomepageMode = false
        hasAppliedOnboardingResetForLaunch = true
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
