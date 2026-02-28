import Foundation
#if canImport(AuthenticationServices)
import AuthenticationServices
#endif

@MainActor
final class UserSessionStore: ObservableObject {
    enum GateStep {
        case onboarding
        case account
        case paywall
        case done
    }

    enum Keys {
        static let hasSeenOnboarding = "hasSeenOnboarding"
        static let hasAccount = "hasAccount"
        static let isSubscribed = "isSubscribed"
        static let appleUserID = "apple_user_id"
        static let accountName = "account_name"
        static let accountEmail = "account_email"
    }

    @Published private(set) var hasSeenOnboarding: Bool
    @Published private(set) var hasAccount: Bool
    @Published private(set) var isSubscribed: Bool

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        self.hasAccount = defaults.bool(forKey: Keys.hasAccount)
        self.isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }

    var currentGateStep: GateStep {
        if !hasSeenOnboarding { return .onboarding }
        if !hasAccount { return .account }
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

    func setHasSeenOnboarding(_ value: Bool) {
        hasSeenOnboarding = value
        defaults.set(value, forKey: Keys.hasSeenOnboarding)
    }

    func setHasAccount(_ value: Bool) {
        hasAccount = value
        defaults.set(value, forKey: Keys.hasAccount)
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
        setIsSubscribed(false)
        defaults.removeObject(forKey: Keys.appleUserID)
    }

    #if canImport(AuthenticationServices)
    func completeSignInWithApple(_ credential: ASAuthorizationAppleIDCredential) {
        setAppleUserID(credential.user)
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

    func reloadFromDefaults() {
        hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        hasAccount = defaults.bool(forKey: Keys.hasAccount)
        isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }
}
