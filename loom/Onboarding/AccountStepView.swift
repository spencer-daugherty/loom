import SwiftUI
import SwiftData
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

private struct AccountStepDarkModeInvertImage: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .colorInvert()
                .compositingGroup()
        } else {
            content
        }
    }
}

struct AccountStepView: View {
    @EnvironmentObject private var session: UserSessionStore
    @EnvironmentObject private var personalizationStore: PersonalizationStore
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Environment(\.openURL) private var openURL
    @AppStorage("developer_launch_paywall_once") private var developerLaunchPaywallOnce = false
    @AppStorage("has_seen_content_quickstart_v1") private var hasSeenContentQuickstart = false
    @AppStorage("force_show_content_quickstart_once") private var forceShowContentQuickstartOnce = false
    @FocusState private var focusedField: ReviewAuthField?

    @State private var appleSignInError: String?
    @State private var googleSignInError: String?
    @State private var reviewSignInError: String?
    @State private var isGoogleSignInInProgress = false
    @State private var isReviewSignInInProgress = false
    @State private var appleSignInNonce: String?
    @State private var showMoreOptions = false
    @State private var showReviewSignIn = false
    @State private var didLogSignupStarted = false
    @State private var didCompleteSignup = false
    @State private var developerPaywallLaunchTask: Task<Void, Never>?
    @State private var authTapCooldownTask: Task<Void, Never>?
    @State private var isAuthTapCoolingDown = false
    @State private var presentedLegalDocument: LegalDocument?
    @State private var reviewEmail = ""
    @State private var reviewPassword = ""
    @State private var isReviewPasswordVisible = false
    @State private var isShowingReviewSignInNote = false

    private struct PendingReviewSignInSuccess {
        let userID: String
        let email: String
        let fullName: String?
        let workspace: LoomSpecialAccountWorkspace
    }

    @State private var pendingReviewSignInSuccess: PendingReviewSignInSuccess?

    private enum ReviewAuthField: Hashable {
        case email
        case password
    }

    private var canSubmitReviewSignIn: Bool {
        !reviewEmail.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !reviewPassword.isEmpty
    }

    var body: some View {
        VStack(spacing: 22) {
            Spacer(minLength: 0)

            VStack(spacing: 10) {
                Text("End Stress. Live Fulfilled.")
                    .font(.system(size: 39, weight: .bold))
                    .multilineTextAlignment(.center)

                Text("Join the movement.")
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Spacer(minLength: 0)

            VStack(spacing: 12) {
                if !showReviewSignIn {
                    #if canImport(AuthenticationServices)
                    SignInWithAppleButton(.continue) { request in
                        guard beginAuthTapCooldownIfNeeded() else { return }
                        request.requestedScopes = [.fullName, .email]
                        let nonce = randomNonceString()
                        appleSignInNonce = nonce
                        request.nonce = sha256(nonce)
                    } onCompletion: { result in
                        switch result {
                        case .success(let authorization):
                            guard let credential = authorization.credential as? ASAuthorizationAppleIDCredential else {
                                appleSignInError = "Unable to complete sign in."
                                return
                            }
                            startAppleSignIn(credential: credential)
                        case .failure(let error):
                            if let authError = error as? ASAuthorizationError {
                                if authError.code == .canceled {
                                    appleSignInError = nil
                                } else if authError.code == .failed {
                                    appleSignInError = "Sign in failed. Please try again."
                                } else if authError.code == .invalidResponse {
                                    appleSignInError = "Sign in returned an invalid response."
                                } else if authError.code == .notHandled {
                                    appleSignInError = "Sign in could not be completed on this device."
                                } else if authError.code == .unknown {
                                    appleSignInError = "Sign in encountered an unknown error."
                                } else {
                                    appleSignInError = "Sign in failed. Please try again."
                                }
                            } else {
                                appleSignInError = "Sign in failed. Please try again."
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
                    .disabled(isGoogleSignInInProgress || isReviewSignInInProgress || isAuthTapCoolingDown)
                    #else
                    Button {
                        appleSignInError = "Sign in is unavailable on this device."
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
                    .disabled(isGoogleSignInInProgress || isReviewSignInInProgress || isAuthTapCoolingDown)
                    #endif
                }

                if !showMoreOptions && !showReviewSignIn {
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
                    if !showReviewSignIn {
                        Button {
                            guard beginAuthTapCooldownIfNeeded() else { return }
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
                        .disabled(isGoogleSignInInProgress || isReviewSignInInProgress || isAuthTapCoolingDown)
                    }

                    Button {
                        if showReviewSignIn {
                            reviewSignInError = nil
                            focusedField = nil
                            isReviewPasswordVisible = false
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReviewSignIn = false
                            }
                        } else {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showReviewSignIn = true
                            }
                        }
                    } label: {
                        Text(showReviewSignIn ? "Return" : "Other sign in")
                            .font(.system(size: 12.75, weight: .regular))
                            .underline()
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.plain)
                    .disabled(isReviewSignInInProgress || isAuthTapCoolingDown)

                    if showReviewSignIn {
                        VStack(alignment: .leading, spacing: 10) {
                            TextField("Email", text: $reviewEmail)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled(true)
                                .keyboardType(.emailAddress)
                                .textContentType(.username)
                                .submitLabel(.next)
                                .focused($focusedField, equals: .email)
                                .onSubmit {
                                    focusedField = .password
                                }
                                .padding(.horizontal, 14)
                                .frame(maxWidth: .infinity, minHeight: 52)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(Color(.secondarySystemBackground))
                                )
                                .disabled(isReviewSignInInProgress || isAuthTapCoolingDown)

                            HStack(spacing: 10) {
                                Group {
                                    if isReviewPasswordVisible {
                                        TextField("Passcode", text: $reviewPassword)
                                    } else {
                                        SecureField("Passcode", text: $reviewPassword)
                                    }
                                }
                                .textContentType(.password)
                                .submitLabel(.go)
                                .focused($focusedField, equals: .password)
                                .onSubmit {
                                    startReviewSignIn()
                                }

                                if !reviewPassword.isEmpty {
                                    Button {
                                        isReviewPasswordVisible.toggle()
                                    } label: {
                                        Image(systemName: isReviewPasswordVisible ? "eye.slash" : "eye")
                                            .font(.system(size: 17, weight: .semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 24, height: 24)
                                    }
                                    .buttonStyle(.plain)
                                    .accessibilityLabel(isReviewPasswordVisible ? "Hide passcode" : "View passcode")
                                }
                            }
                            .padding(.horizontal, 14)
                            .frame(maxWidth: .infinity, minHeight: 52)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(Color(.secondarySystemBackground))
                            )
                            .disabled(isReviewSignInInProgress || isAuthTapCoolingDown)

                            Button {
                                startReviewSignIn()
                            } label: {
                                HStack(spacing: 10) {
                                    Spacer(minLength: 0)
                                    if isReviewSignInInProgress {
                                        ProgressView()
                                            .controlSize(.small)
                                    }
                                    Text("Sign in")
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
                            .accessibilityIdentifier("account_signInForAppReview")
                            .disabled(isGoogleSignInInProgress || isReviewSignInInProgress || isAuthTapCoolingDown)
                        }
                    }
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
            if let reviewSignInError, !reviewSignInError.isEmpty {
                Text(reviewSignInError)
                    .font(.footnote)
                    .foregroundStyle(.red)
                    .multilineTextAlignment(.center)
            }

            VStack(spacing: 2) {
                Text("By continuing you agree to Loom's")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)

                HStack(spacing: 4) {
                    Button("Terms of Use") {
                        presentedLegalDocument = .terms
                    }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)

                    Text("and")
                        .font(.footnote)
                        .foregroundStyle(.secondary)

                    Button("Privacy Policy") {
                        presentedLegalDocument = .privacy
                    }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(Color.accentColor)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
        .alert(pendingReviewSignInSuccess?.workspace.alertTitle ?? "Special Account", isPresented: $isShowingReviewSignInNote) {
            Button("Continue") {
                completePendingReviewSignInSuccess()
            }
        } message: {
            Text(pendingReviewSignInSuccess?.workspace.alertMessage ?? "")
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .modifier(AccountStepDarkModeInvertImage())
            }
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
                    session.setHasCompletedDiagnostic(true)
                    session.setHasSeenDiagnosticInsights(true)
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
            authTapCooldownTask?.cancel()
            authTapCooldownTask = nil
            isAuthTapCoolingDown = false
            if didLogSignupStarted && !didCompleteSignup && !session.hasAccount {
                AnalyticsLogger.log(.signupAbandoned(reason: "dismissed"))
            }
        }
    }

    private var googleGIcon: some View {
        Image("GoogleLogo")
            .resizable()
            .scaledToFit()
            .frame(width: 40, height: 40, alignment: .center)
    }

    private func beginAuthTapCooldownIfNeeded() -> Bool {
        guard !isAuthTapCoolingDown else { return false }
        isAuthTapCoolingDown = true
        authTapCooldownTask?.cancel()
        authTapCooldownTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 3_000_000_000)
            guard !Task.isCancelled else { return }
            isAuthTapCoolingDown = false
            authTapCooldownTask = nil
        }
        return true
    }

    private func startGoogleSignIn() {
#if canImport(GoogleSignIn) && canImport(FirebaseAuth) && canImport(FirebaseCore) && canImport(UIKit)
        guard !isGoogleSignInInProgress else { return }
        guard let clientID = FirebaseApp.app()?.options.clientID, !clientID.isEmpty else {
            googleSignInError = "Google sign in is not available right now."
            return
        }
        guard let presentingController = topViewController() else {
            googleSignInError = "Unable to present Google sign in."
            return
        }

        appleSignInError = nil
        googleSignInError = nil
        reviewSignInError = nil
        isGoogleSignInInProgress = true
        GIDSignIn.sharedInstance.configuration = GIDConfiguration(clientID: clientID)

        Task { @MainActor in
            defer { isGoogleSignInInProgress = false }
            do {
                let result = try await GIDSignIn.sharedInstance.signIn(withPresenting: presentingController)
                guard let idToken = result.user.idToken?.tokenString else {
                    googleSignInError = "Google sign in failed. Please try again."
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
                googleSignInError = "Google sign in failed. Please try again."
            }
        }
#else
        googleSignInError = "Google sign in is not available on this device."
#endif
    }

    private func startAppleSignIn(credential: ASAuthorizationAppleIDCredential) {
#if canImport(AuthenticationServices) && canImport(FirebaseAuth)
        guard let nonce = appleSignInNonce else {
            appleSignInError = "Sign in could not be completed. Please try again."
            return
        }
        guard let tokenData = credential.identityToken, let idToken = String(data: tokenData, encoding: .utf8) else {
            appleSignInError = "Sign in returned an invalid response."
            return
        }

        appleSignInError = nil
        googleSignInError = nil
        reviewSignInError = nil
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
                appleSignInError = "Sign in failed. Please try again."
            }
            appleSignInNonce = nil
        }
#else
        session.completeSignInWithApple(credential)
        appleSignInError = nil
#endif
    }

    private func startReviewSignIn() {
#if canImport(FirebaseAuth)
        guard !isGoogleSignInInProgress, !isReviewSignInInProgress else { return }

        let trimmedEmail = reviewEmail.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedEmail.isEmpty else {
            reviewSignInError = "Enter your email address."
            focusedField = .email
            return
        }
        guard !reviewPassword.isEmpty else {
            reviewSignInError = "Enter your passcode."
            focusedField = .password
            return
        }
        guard beginAuthTapCooldownIfNeeded() else { return }

        appleSignInError = nil
        googleSignInError = nil
        reviewSignInError = nil
        focusedField = nil
        isReviewSignInInProgress = true

        Task { @MainActor in
            defer { isReviewSignInInProgress = false }
            do {
                let authResult = try await signInWithEmailAccount(email: trimmedEmail, password: reviewPassword)
                let user = authResult.user
                let resolvedEmail = user.email ?? trimmedEmail
                let workspace = LoomSpecialAccountWorkspace.workspace(for: resolvedEmail)

                if let workspace {
                    pendingReviewSignInSuccess = PendingReviewSignInSuccess(
                        userID: user.uid,
                        email: resolvedEmail,
                        fullName: user.displayName,
                        workspace: workspace
                    )
                    isShowingReviewSignInNote = true
                } else {
                    session.setIsolatedWorkspace(nil)
                    session.completeSignInWithEmail(
                        userID: user.uid,
                        email: resolvedEmail,
                        fullName: user.displayName
                    )
                }
                if workspace == nil {
                    didCompleteSignup = true
                    AnalyticsLogger.log(.signupCompleted(method: "email"))
                }
            } catch {
                AppDebugActivityLog.log(
                    "AccountStepView",
                    "email sign in failed email=\(trimmedEmail.lowercased()) reason=\(reviewSignInDebugReason(error))"
                )
                reviewSignInError = reviewSignInErrorMessage(for: error, email: trimmedEmail)
            }
        }
#else
        reviewSignInError = "Sign in is not available on this device."
#endif
    }

    private func completePendingReviewSignInSuccess() {
        guard let pending = pendingReviewSignInSuccess else { return }
        Task { @MainActor in
            let workspace = pending.workspace
            let defaults = UserDefaults.standard
            let hasCompletedWorkspaceBootstrap = defaults.bool(forKey: workspace.bootstrapDefaultsKey)
            let shouldResetWorkspaceForThisSignIn = !workspace.preservesWorkspaceStateAcrossLogout || !hasCompletedWorkspaceBootstrap
            pendingReviewSignInSuccess = nil

            if shouldResetWorkspaceForThisSignIn {
                LoomDefaultsScope.clearScopedValues(for: workspace)
                resetIsolatedWorkspaceOnboardingProgress(defaults: defaults)
            }
            session.setIsolatedWorkspace(workspace)
            if workspace == .starter {
                session.setIsSubscribed(false)
                SubscriptionAccessGate.setStarterEntitlementAccess(false)
                SubscriptionAccessGate.setStarterPreferredProductID(nil)
            }
            if shouldResetWorkspaceForThisSignIn {
                await personalizationStore.resetCurrentUserState()
            }

            session.completeSignInWithEmail(
                userID: pending.userID,
                email: pending.email,
                fullName: pending.fullName
            )
            if workspace == .reviewOnboardingDemo {
                session.setIsSubscribed(false)
                UserDefaults.standard.removeObject(forKey: "loom.subscription_plan")
            } else if workspace.usesDefaultMonthlySubscription {
                session.setIsSubscribed(true)
                UserDefaults.standard.set(SubscriptionPlan.monthly.rawValue, forKey: "loom.subscription_plan")
            }
            if workspace.shouldSeedDemoWorkspace {
                if shouldResetWorkspaceForThisSignIn {
                    hasSeenContentQuickstart = false
                    forceShowContentQuickstartOnce = true
                }
                if workspace.shouldAutoCompleteGatesAfterSignIn {
                    session.setHasSeenOnboarding(true)
                    session.setHasCompletedDiagnostic(true)
                    session.setHasSeenDiagnosticInsights(true)
                    await LoomDemoWorkspaceSeeder.seedDemoPersonalization(using: personalizationStore)
                }
            }
            defaults.set(true, forKey: workspace.bootstrapDefaultsKey)
            didCompleteSignup = true
            AnalyticsLogger.log(.signupCompleted(method: "email"))
        }
    }

    private func resetIsolatedWorkspaceOnboardingProgress(defaults: UserDefaults = .standard) {
        defaults.set(false, forKey: "blank_homepage_mode")
        defaults.set(false, forKey: "setup_homepage_mode")
        defaults.set(false, forKey: "capture_setup_completed_once_v1")
        defaults.set(false, forKey: "onboarding_capture_notifications_prompted_v1")
        defaults.set(false, forKey: "content_home_objectives_setup_skipped_v1")
        defaults.set(false, forKey: "return_to_onboarding_last_page_once")
    }

    private func cancelPendingReviewSignInSuccess() {
        pendingReviewSignInSuccess = nil
        isShowingReviewSignInNote = false
#if canImport(FirebaseAuth)
        try? Auth.auth().signOut()
#endif
    }

    private func reviewSignInErrorMessage(for error: Error, email: String) -> String {
#if canImport(FirebaseAuth)
        guard let authError = error as NSError? else {
            return "Sign in failed. Check your email and passcode, then try again."
        }

        switch AuthErrorCode(rawValue: authError.code) {
        case .wrongPassword, .invalidCredential:
            return "The email or passcode is incorrect."
        case .invalidEmail:
            return "Enter a valid email address."
        case .userNotFound:
            if LoomDemoWorkspaceSeeder.isDemoAccount(email: email) {
                return "This demo sign-in is not available right now."
            }
            return "No account was found for that email."
        case .operationNotAllowed:
            return "This sign-in method is not available right now."
        case .userDisabled:
            return "This account is currently unavailable."
        case .networkError:
            return "Sign in needs a network connection."
        case .tooManyRequests:
            return "Too many attempts. Please try again in a moment."
        default:
            return "Sign in failed. Check your email and passcode, then try again."
        }
#else
        return "Sign in failed. Check your email and passcode, then try again."
#endif
    }

    private func reviewSignInDebugReason(_ error: Error) -> String {
#if canImport(FirebaseAuth)
        let nsError = error as NSError
        if let authCode = AuthErrorCode(rawValue: nsError.code) {
            return "\(authCode.rawValue):\(authCode)"
        }
        return "nsError=\(nsError.domain):\(nsError.code)"
#else
        return error.localizedDescription
#endif
    }

#if canImport(FirebaseAuth)
    private func signInWithEmailAccount(email: String, password: String) async throws -> AuthDataResult {
        do {
            return try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            guard shouldCreateSpecialWorkspaceAccount(email: email, password: password, error: error) else {
                throw error
            }
            return try await Auth.auth().createUser(withEmail: email, password: password)
        }
    }

    private func shouldCreateSpecialWorkspaceAccount(email: String, password: String, error: Error) -> Bool {
        guard let workspace = LoomSpecialAccountWorkspace.workspace(for: email) else { return false }
        guard workspace.allowsAutoCreate() else { return false }
        let expectedPassword: String
        switch workspace {
        case .starter:
            expectedPassword = "ForAllTime2"
        case .reviewOnboardingDemo:
            expectedPassword = "ForAllTime3"
        case .reviewDemo:
            return false
        }
        guard password == expectedPassword else { return false }
        let nsError = error as NSError
        guard let authCode = AuthErrorCode(rawValue: nsError.code) else { return false }
        return authCode == .userNotFound || authCode == .invalidCredential
    }
#endif

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
        .environmentObject(PersonalizationStore())
        .loomPreviewContainer()
}
