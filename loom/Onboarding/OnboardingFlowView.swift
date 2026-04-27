import SwiftUI
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif

struct OnboardingFlowView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("has_seen_content_quickstart_v1") private var hasSeenContentQuickstart = false
    @AppStorage("force_show_content_quickstart_once") private var forceShowContentQuickstartOnce = false
    @AppStorage("return_to_onboarding_last_page_once") private var returnToOnboardingLastPageOnce = false

    @State private var currentIndex = 0
    @State private var didLogOnboardingStarted = false
    @State private var didLogOnboardingCompleted = false
    @State private var onboardingStartDate: Date?

    private var pages: [OnboardingPage] { OnboardingCopy.pages }
    private var isLastPage: Bool { currentIndex == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar
                .reviewPathColumn(maxWidth: 720, horizontalPadding: 20, alignment: .top)

            TabView(selection: $currentIndex) {
                ForEach(Array(pages.enumerated()), id: \.offset) { index, page in
                    OnboardingSlideView(page: page)
                        .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))

            VStack(spacing: 18) {
                progressDots

                Button {
                    primaryTapped()
                } label: {
                    Text(isLastPage ? lastPagePrimaryLabel : OnboardingCopy.next)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(isLastPage ? (session.hasAccount ? "onboarding_continue" : "onboarding_createAccount") : "onboarding_next")
            }
            .padding(.top, 20)
            .padding(.bottom, 26)
            .reviewPathColumn(maxWidth: 720, horizontalPadding: 20, alignment: .top)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            if returnToOnboardingLastPageOnce {
                currentIndex = max(0, pages.count - 1)
                returnToOnboardingLastPageOnce = false
            }
            if !didLogOnboardingStarted {
                didLogOnboardingStarted = true
                onboardingStartDate = Date()
                AnalyticsLogger.log(.onboardingStarted())
            }
        }
        .onDisappear {
            if didLogOnboardingStarted && !didLogOnboardingCompleted && !session.hasSeenOnboarding {
                let duration = max(0, Int(Date().timeIntervalSince(onboardingStartDate ?? Date())))
                AnalyticsLogger.log(.onboardingAbandoned(lastSlideIndex: currentIndex, durationSeconds: duration))
            }
        }
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
            if isLastPage && session.hasAccount {
                Button {
                    signOut()
                } label: {
                    Text("Sign out")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
            } else {
                Spacer(minLength: 0)
            }

            Spacer(minLength: 0)

            if !isLastPage {
                Button {
                    jumpToLastPage()
                } label: {
                    Text(OnboardingCopy.skip)
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityIdentifier("onboarding_skip")
            }
        }
        .padding(.top, 14)
    }

    private var progressDots: some View {
        HStack(spacing: 8) {
            ForEach(0..<pages.count, id: \.self) { idx in
                Capsule()
                    .fill(idx == currentIndex ? Color.accentColor : Color.secondary.opacity(0.25))
                    .frame(width: idx == currentIndex ? 20 : 8, height: 8)
            }
        }
        .animation(reduceMotion ? nil : .easeInOut(duration: 0.2), value: currentIndex)
    }

    private var lastPagePrimaryLabel: LocalizedStringKey {
        session.hasAccount ? OnboardingCopy.continueText : OnboardingCopy.createAccount
    }

    private func primaryTapped() {
        if isLastPage {
            hasSeenContentQuickstart = false
            forceShowContentQuickstartOnce = true
            let duration = max(0, Int(Date().timeIntervalSince(onboardingStartDate ?? Date())))
            AnalyticsLogger.log(
                .onboardingCompleted(
                    totalSlides: pages.count,
                    durationSeconds: duration,
                    source: "onboarding"
                )
            )
            didLogOnboardingCompleted = true
            session.markOnboardingSeen()
            return
        }

        let nextIndex = min(currentIndex + 1, pages.count - 1)
        if reduceMotion {
            currentIndex = nextIndex
        } else {
            withAnimation(.easeInOut(duration: 0.2)) {
                currentIndex = nextIndex
            }
        }
    }

    @MainActor
    private func signOut() {
#if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
#endif
#if canImport(GoogleSignIn)
        GIDSignIn.sharedInstance.signOut()
#endif
        session.clearAccountSession()
    }

    private func jumpToLastPage() {
        let target = pages.count - 1
        if reduceMotion {
            currentIndex = target
        } else {
            withAnimation(.easeInOut(duration: 0.22)) {
                currentIndex = target
            }
        }
    }
}

#Preview {
    OnboardingFlowView()
        .environmentObject(UserSessionStore())
}
