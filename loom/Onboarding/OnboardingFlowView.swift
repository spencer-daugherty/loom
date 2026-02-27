import SwiftUI

struct OnboardingFlowView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @AppStorage("has_seen_content_quickstart_v1") private var hasSeenContentQuickstart = false
    @AppStorage("force_show_content_quickstart_once") private var forceShowContentQuickstartOnce = false

    @State private var currentIndex = 0

    private var pages: [OnboardingPage] { OnboardingCopy.pages }
    private var isLastPage: Bool { currentIndex == pages.count - 1 }

    var body: some View {
        VStack(spacing: 0) {
            topBar

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
                    Text(isLastPage ? OnboardingCopy.createAccount : OnboardingCopy.next)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .accessibilityIdentifier(isLastPage ? "onboarding_createAccount" : "onboarding_next")
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 26)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
    }

    @ViewBuilder
    private var topBar: some View {
        HStack {
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
        .padding(.horizontal, 20)
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

    private func primaryTapped() {
        if isLastPage {
            hasSeenContentQuickstart = false
            forceShowContentQuickstartOnce = true
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
