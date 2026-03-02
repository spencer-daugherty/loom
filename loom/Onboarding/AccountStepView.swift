import SwiftUI
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif
#if canImport(UIKit)
import UIKit
#endif
#if canImport(GoogleSignIn)
import GoogleSignIn
#endif
#if canImport(FirebaseAuth)
import FirebaseAuth
#endif
#if canImport(FirebaseCore)
import FirebaseCore
#endif
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(Security)
import Security
#endif

struct AccountStepView: View {
    @EnvironmentObject private var session: UserSessionStore
    @Environment(\.colorScheme) private var colorScheme
    @AppStorage("return_to_onboarding_last_page_once") private var returnToOnboardingLastPageOnce = false
    @AppStorage("developer_launch_paywall_once") private var developerLaunchPaywallOnce = false

    @State private var appleSignInError: String?
    @State private var googleSignInError: String?
    @State private var isGoogleSignInInProgress = false
    @State private var appleSignInNonce: String?
    @State private var showMoreOptions = false
    @State private var didLogSignupStarted = false
    @State private var didCompleteSignup = false
    @State private var developerPaywallLaunchTask: Task<Void, Never>?

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("End Stress. Live Fulfilled.")
                    .font(.system(size: 39, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Join the project.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                #if canImport(AuthenticationServices)
                SignInWithAppleButton(.continue) { request in
                    request.requestedScopes = [.fullName, .email]
                    let nonce = randomNonceString()
                    appleSignInNonce = nonce
                    request.nonce = sha256(nonce)
                } onCompletion: { result in
                    switch result {
                    case .success(let authorization):
                        guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                            appleSignInError = "Unable to complete Apple sign in."
                            return
                        }
                        startAppleSignIn(credential: credential)
                    case .failure(let error):
                        if let authError = error as? ASAuthorizationError {
                            if authError.code == .canceled {
                                // User dismissed the sheet; don't show as an error.
                                appleSignInError = nil
                            } else if authError.code == .failed {
                                appleSignInError = "Apple sign in failed. Please try again."
                            } else if authError.code == .invalidResponse {
                                appleSignInError = "Apple sign in returned an invalid response."
                            } else if authError.code == .notHandled {
                                appleSignInError = "Apple sign in could not be completed on this device."
                            } else if authError.code == .unknown {
                                appleSignInError = "Apple sign in encountered an unknown error."
                            } else {
                                appleSignInError = "Apple sign in failed with an unsupported error."
                            }
                        } else {
                            appleSignInError = error.localizedDescription
                        }
                    }
                }
                .signInWithAppleButtonStyle(colorScheme == .dark ? .white : .black)
                .frame(maxWidth: .infinity)
                .frame(height: 52)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .overlay {
                    ZStack {
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark ? Color.white : Color.black)
                        HStack(spacing: 10) {
                            Image(systemName: "applelogo")
                                .font(.system(size: 30, weight: .semibold))
                            Text("Continue with Apple")
                                .font(.headline)
                        }
                        .foregroundStyle(colorScheme == .dark ? .black : .white)
                    }
                    .allowsHitTesting(false)
                }
                .accessibilityIdentifier("account_continueWithApple")
                #else
                Button {
                    appleSignInError = "Sign in with Apple is unavailable on this platform."
                } label: {
                    HStack(spacing: 10) {
                        Image(systemName: "applelogo")
                            .font(.system(size: 18, weight: .semibold))
                        Text("Continue with Apple")
                            .font(.headline)
                        Spacer(minLength: 0)
                    }
                    .foregroundStyle(colorScheme == .dark ? .black : .white)
                    .padding(.horizontal, 14)
                    .frame(maxWidth: .infinity, minHeight: 52, alignment: .leading)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(colorScheme == .dark ? .white : .black)
                    )
                }
                .buttonStyle(.plain)
                .accessibilityIdentifier("account_continueWithApple")
                #endif

                if !showMoreOptions {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showMoreOptions = true
                        }
                    } label: {
                        Text("Continue with more options")
                            .font(.system(size: 12.75, weight: .regular))
                            .underline()
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                }

                if showMoreOptions {
                    Button {
                        startGoogleSignIn()
                    } label: {
                        HStack(spacing: 10) {
                            Spacer(minLength: 0)
                            googleGIcon
                            Text("Continue with Google")
                                .font(.headline)
                            Spacer(minLength: 0)
                        }
                        .foregroundStyle(.primary)
                        .padding(.horizontal, 14)
                        .frame(maxWidth: .infinity, minHeight: 52, alignment: .center)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.systemGray5))
                        )
                    }
                    .buttonStyle(.plain)
                    .accessibilityIdentifier("account_continueWithGoogle")
                    .disabled(isGoogleSignInInProgress)
                }
            }
            .padding(.top, 6)

            if let appleSignInError, !appleSignInError.isEmpty {
                Text(appleSignInError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }
            if let googleSignInError, !googleSignInError.isEmpty {
                Text(googleSignInError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            Text("By continuing you agree to Loom's Terms of Service and Privacy Policy.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground).ignoresSafeArea())
        .safeAreaInset(edge: .top, spacing: 0) {
            HStack(spacing: 12) {
                Button {
                    returnToOnboardingEnd()
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 36, height: 36)
                        .background(Color(.secondarySystemBackground), in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Back")

                Spacer(minLength: 0)

                Group {
                    if colorScheme == .dark {
                        Image("logo")
                            .resizable()
                            .renderingMode(.template)
                            .foregroundStyle(.white)
                    } else {
                        Image("logo")
                            .resizable()
                    }
                }
                .scaledToFit()
                .frame(height: 40)

                Spacer(minLength: 0)

                Color.clear
                    .frame(width: 36, height: 36)
            }
            .padding(.top, 8)
            .padding(.horizontal, 4)
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .onAppear {
            if developerLaunchPaywallOnce {
                developerPaywallLaunchTask?.cancel()
                developerPaywallLaunchTask = Task { @MainActor in
                    try? await Task.sleep(nanoseconds: 450_000_000)
                    guard !Task.isCancelled, developerLaunchPaywallOnce else { return }
                    developerLaunchPaywallOnce = false
                    session.setHasSeenOnboarding(true)
                    session.setHasAccount(true)
                    session.setIsSubscribed(false)
                }
            }
            if !didLogSignupStarted {
                didLogSignupStarted = true
                AnalyticsLogger.log(.signupStarted())
            }
        }
        .onDisappear {
            developerPaywallLaunchTask?.cancel()
            developerPaywallLaunchTask = nil
            if didLogSignupStarted && !didCompleteSignup && !session.hasAccount {
                AnalyticsLogger.log(.signupAbandoned(reason: "dismissed"))
            }
        }
        .highPriorityGesture(
            DragGesture(minimumDistance: 18)
                .onEnded { value in
                    let startedFromLeadingEdge = value.startLocation.x <= 28
                    let isHorizontalBackSwipe = value.translation.width > 80 && abs(value.translation.height) < 80
                    if startedFromLeadingEdge && isHorizontalBackSwipe {
                        returnToOnboardingEnd()
                    }
                }
        )
    }

    private var googleGIcon: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40, alignment: .center)
    }

    private func startGoogleSignIn() {
#if canImport(GoogleSignIn) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(UIKit)
        guard !isGoogleSignInInProgress else { return }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            googleSignInError = "Google sign in is not configured. Missing Firebase client ID."
            return
        }
        guard let presentingController = topViewController() else {
            googleSignInError = "Unable to present Google sign in."
            return
        }

        appleSignInError = nil
        googleSignInError = nil
        isGoogleSignInInProgress = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        Task { @MainActor in
            defer { isGoogleSignInInProgress = false }
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingController)
                guard let idToken = result.user.idToken?.tokenString else {
                    googleSignInError = "Google sign in failed to provide credentials."
                    return
                }

                let accessToken = result.user.accessToken.tokenString
                let credential = GoogleAuthProvider.credential(withIDToken: idToken, accessToken: accessToken)
                let authResult = try await Auth.auth().signIn(with: credential)
                let user = authResult.user
                session.completeSignInWithGoogle(
                    userID: user.uid,
                    email: user.email ?? result.user.profile?.email,
                    fullName: user.displayName ?? result.user.profile?.name
                )
                didCompleteSignup = true
                AnalyticsLogger.log(.signupCompleted(method: "google"))
            } catch {
                googleSignInError = error.localizedDescription
            }
        }
#else
        googleSignInError = "Google sign in SDK is not available in this build."
#endif
    }

    private func returnToOnboardingEnd() {
        returnToOnboardingLastPageOnce = true
        session.setHasSeenOnboarding(false)
    }

    private func startAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
#if canImport(AuthenticationServices) && canImport(FirebaseAuth)
        guard let nonce = appleSignInNonce else {
            appleSignInError = "Apple sign in is missing security state. Please try again."
            return
        }
        guard let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else {
            appleSignInError = "Apple sign in returned an invalid identity token."
            return
        }

        appleSignInError = nil
        let firebaseCredential = OAuthProvider.credential(
            providerID: AuthProviderID.apple,
            idToken: idToken,
            rawNonce: nonce
        )

        Task { @MainActor in
            do {
                let authResult = try await Auth.auth().signIn(with: firebaseCredential)
                let user = authResult.user
                let displayName = user.displayName?.trimmingCharacters(in: .whitespacesAndNewlines)
                let fallbackName = {
                    let formatter = PersonNameComponentsFormatter()
                    return formatter.string(from: credential.fullName ?? PersonNameComponents())
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                }()
                session.completeSignInWithApple(credential)
                if let email = user.email, !email.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    UserDefaults.standard.set(email, forKey: UserSessionStore.Keys.accountEmail)
                }
                let resolvedName = [displayName, fallbackName].compactMap { $0 }.first { !$0.isEmpty }
                if let resolvedName {
                    UserDefaults.standard.set(resolvedName, forKey: UserSessionStore.Keys.accountName)
                }
                didCompleteSignup = true
                AnalyticsLogger.log(.signupCompleted(method: "apple"))
            } catch {
                appleSignInError = error.localizedDescription
            }
            appleSignInNonce = nil
        }
#else
        session.completeSignInWithApple(credential)
        appleSignInError = nil
#endif
    }

#if canImport(CryptoKit)
    private func sha256(_ input: String) -> String {
        let inputData = Data(input.utf8)
        let hashed = SHA256.hash(data: inputData)
        return hashed.map { String(format: "%02x", $0) }.joined()
    }
#else
    private func sha256(_ input: String) -> String { input }
#endif

    private func randomNonceString(length: Int = 32) -> String {
        precondition(length > 0)
        let charset = Array("0123456789ABCDEFGHIJKLMNOPQRSTUVXYZabcdefghijklmnopqrstuvwxyz-._")
        var result = ""
        var remainingLength = length

        while remainingLength > 0 {
            var randoms: [UInt8] = (0..<16).map { _ in 0 }
            let errorCode = SecRandomCopyBytes(kSecRandomDefault, randoms.count, &randoms)
            if errorCode != errSecSuccess {
                return UUID().uuidString.replacingOccurrences(of: "-", with: "")
            }
            randoms.forEach { random in
                if remainingLength == 0 {
                    return
                }
                if Int(random) < charset.count {
                    result.append(charset[Int(random)])
                    remainingLength -= 1
                }
            }
        }

        return result
    }

#if canImport(UIKit)
    private func topViewController(
        from root: UIViewController? = UIApplication.shared
            .connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .first(where: { $0.activationState == .foregroundActive })?
            .windows
            .first(where: \.isKeyWindow)?
            .rootViewController
    ) -> UIViewController? {
        if let nav = root as? UINavigationController {
            return topViewController(from: nav.visibleViewController)
        }
        if let tab = root as? UITabBarController {
            return topViewController(from: tab.selectedViewController)
        }
        if let presented = root?.presentedViewController {
            return topViewController(from: presented)
        }
        return root
    }
#endif
}

#Preview {
    AccountStepView()
        .environmentObject(UserSessionStore())
}
