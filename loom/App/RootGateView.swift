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

    @State private var isGatePresented = false
    @State private var hasAppliedOnboardingResetForLaunch = false

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
                syncSessionFromStorage()
                syncGatePresentationState()
            }
            .task {
                #if canImport(AuthenticationServices)
                await session.refreshAppleCredentialStateIfNeeded()
                #endif
            }
            .onChange(of: hasSeenOnboarding) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
            }
            .onChange(of: hasAccount) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
            }
            .onChange(of: isSubscribed) { _, _ in
                syncSessionFromStorage()
                syncGatePresentationState()
            }
            .onChange(of: session.hasSeenOnboarding) { _, value in
                hasSeenOnboarding = value
                syncGatePresentationState()
            }
            .onChange(of: session.hasAccount) { _, value in
                hasAccount = value
                syncGatePresentationState()
            }
            .onChange(of: session.isSubscribed) { _, value in
                isSubscribed = value
                syncGatePresentationState()
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
