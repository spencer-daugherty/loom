import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@MainActor
final class UserSessionStore: ObservableObject {
    enum GateStep {
        case onboarding
        case account
        case diagnostic
        case insights
        case paywall
        case done
    }

    enum Keys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasAccount = "hasAccount"
        static let hasCompletedDiagnostic = "hasCompletedDiagnostic"
        static let hasSeenDiagnosticInsights = "hasSeenDiagnosticInsights"
        static let isSubscribed = "isSubscribed"
        static let appleUserID = "apple_user_id"
        static let googleUserID = "google_user_id"
        static let authProvider = "auth_provider"
        static let accountName = "account_name"
        static let accountEmail = "account_email"
    }

    @Published private(set) var hasSeenOnboarding: Bool
    @Published private(set) var hasAccount: Bool
    @Published private(set) var hasCompletedDiagnostic: Bool
    @Published private(set) var hasSeenDiagnosticInsights: Bool
    @Published private(set) var isSubscribed: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        self.hasAccount = defaults.bool(forKey: Keys.hasAccount)
        let hasCompletedDiagnostic: Bool
        if defaults.object(forKey: Keys.hasCompletedDiagnostic) == nil {
            // Preserve existing user access when this gate is introduced midstream.
            hasCompletedDiagnostic = defaults.bool(forKey: Keys.hasAccount)
            defaults.set(hasCompletedDiagnostic, forKey: Keys.hasCompletedDiagnostic)
        } else {
            hasCompletedDiagnostic = defaults.bool(forKey: Keys.hasCompletedDiagnostic)
        }
        self.hasCompletedDiagnostic = hasCompletedDiagnostic

        let hasSeenDiagnosticInsights: Bool
        if defaults.object(forKey: Keys.hasSeenDiagnosticInsights) == nil {
            // Existing users who already completed diagnostics should not be blocked by a new insights step.
            hasSeenDiagnosticInsights = hasCompletedDiagnostic
            defaults.set(hasSeenDiagnosticInsights, forKey: Keys.hasSeenDiagnosticInsights)
        } else {
            hasSeenDiagnosticInsights = defaults.bool(forKey: Keys.hasSeenDiagnosticInsights)
        }
        let resolvedHasSeenDiagnosticInsights = hasCompletedDiagnostic ? hasSeenDiagnosticInsights : false
        self.hasSeenDiagnosticInsights = resolvedHasSeenDiagnosticInsights
        defaults.set(resolvedHasSeenDiagnosticInsights, forKey: Keys.hasSeenDiagnosticInsights)

        self.isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }

    var currentGateStep: GateStep {
        if !hasSeenOnboarding { return .onboarding }
        if !hasAccount { return .account }
        if !hasCompletedDiagnostic { return .diagnostic }
        if !hasSeenDiagnosticInsights { return .insights }
        if !isSubscribed { return .paywall }
        return .done
    }

    var requiresGate: Bool { currentGateStep != .done }

    func markOnboardingSeen() {
        setHasSeenOnboarding(true)
    }

    func markAccountCreated() {
        setHasAccount(true)
    }

    func markSubscribed() {
        setIsSubscribed(true)
    }

    func markDiagnosticCompleted() {
        setHasCompletedDiagnostic(true)
    }

    func markDiagnosticInsightsSeen() {
        setHasSeenDiagnosticInsights(true)
    }

    func setHasSeenOnboarding(_ value: Bool) {
        hasSeenOnboarding = value
        defaults.set(value, forKey: Keys.hasSeenOnboarding)
    }

    func setHasAccount(_ value: Bool) {
        hasAccount = value
        defaults.set(value, forKey: Keys.hasAccount)
        if !value {
            setHasCompletedDiagnostic(false)
            setHasSeenDiagnosticInsights(false)
        }
    }

    func setHasCompletedDiagnostic(_ value: Bool) {
        let resolvedValue = hasAccount ? value : false
        hasCompletedDiagnostic = resolvedValue
        defaults.set(resolvedValue, forKey: Keys.hasCompletedDiagnostic)
        if !resolvedValue {
            setHasSeenDiagnosticInsights(false)
        }
    }

    func setHasSeenDiagnosticInsights(_ value: Bool) {
        let resolvedValue = (hasAccount && hasCompletedDiagnostic) ? value : false
        hasSeenDiagnosticInsights = resolvedValue
        defaults.set(resolvedValue, forKey: Keys.hasSeenDiagnosticInsights)
    }

    func setIsSubscribed(_ value: Bool) {
        isSubscribed = value
        defaults.set(value, forKey: Keys.isSubscribed)
    }

    func setAppleUserID(_ value: String?) {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmed.isEmpty {
            defaults.removeObject(forKey: Keys.appleUserID)
        } else {
            defaults.set(trimmed, forKey: Keys.appleUserID)
        }
    }

    func clearAccountSession() {
        setHasAccount(false)
        setHasCompletedDiagnostic(false)
        setHasSeenDiagnosticInsights(false)
        setIsSubscribed(false)
        defaults.removeObject(forKey: Keys.appleUserID)
        defaults.removeObject(forKey: Keys.googleUserID)
        defaults.removeObject(forKey: Keys.authProvider)
    }

    #if canImport(AuthenticationServices)
    func completeSignInWithApple(_ credential: ASAuthorizationAppleIDCredential) {
        setAppleUserID(credential.user)
        defaults.set("apple", forKey: Keys.authProvider)
        if let email = credential.email?.trimmingCharacters(in: .whitespacesAndNewlines), !email.isEmpty {
            defaults.set(email, forKey: Keys.accountEmail)
        }
        if let fullName = credential.fullName {
            let formatter = PersonNameComponentsFormatter()
            let rendered = formatter.string(from: fullName).trimmingCharacters(in: .whitespacesAndNewlines)
            if !rendered.isEmpty {
                defaults.set(rendered, forKey: Keys.accountName)
            }
        }
        setHasAccount(true)
    }

    func refreshAppleCredentialStateIfNeeded() async {
        guard hasAccount else { return }
        guard let userID = defaults.string(forKey: Keys.appleUserID), !userID.isEmpty else { return }
        let provider = ASAuthorizationAppleIDProvider()
        do {
            let state = try await credentialState(for: userID, provider: provider)
            switch state {
            case .authorized:
                break
            case .revoked, .notFound, .transferred:
                clearAccountSession()
            @unknown default:
                break
            }
        } catch {
            // Keep existing session if credential check fails transiently.
        }
    }

    private func credentialState(
        for userID: String,
        provider: ASAuthorizationAppleIDProvider
    ) async throws -> ASAuthorizationAppleIDProvider.CredentialState {
        try await withCheckedThrowingContinuation { continuation in
            provider.getCredentialState(forUserID: userID) { state, error in
                if let error {
                    continuation.resume(throwing: error)
                } else {
                    continuation.resume(returning: state)
                }
            }
        }
    }
    #endif

    func completeSignInWithGoogle(
        userID: String?,
        email: String?,
        fullName: String?
    ) {
        let trimmedUserID = userID?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if trimmedUserID.isEmpty {
            defaults.removeObject(forKey: Keys.googleUserID)
        } else {
            defaults.set(trimmedUserID, forKey: Keys.googleUserID)
        }
        defaults.set("google", forKey: Keys.authProvider)

        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedEmail.isEmpty {
            defaults.set(trimmedEmail, forKey: Keys.accountEmail)
        }

        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            defaults.set(trimmedName, forKey: Keys.accountName)
        }

        setHasAccount(true)
    }

    func reloadFromDefaults() {
        hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        hasAccount = defaults.bool(forKey: Keys.hasAccount)
        hasCompletedDiagnostic = defaults.bool(forKey: Keys.hasCompletedDiagnostic)
        hasSeenDiagnosticInsights = defaults.bool(forKey: Keys.hasSeenDiagnosticInsights)
        isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }
}
