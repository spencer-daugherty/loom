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
        static let reviewDemoModeEnabled = "review_demo_mode_enabled"
        static let reviewDemoStoreGeneration = "review_demo_store_generation"
        static let isolatedWorkspaceKind = "isolated_workspace_kind"
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

    func setReviewDemoModeEnabled(_ value: Bool) {
        setIsolatedWorkspace(value ? .reviewDemo : nil)
    }

    func bumpReviewDemoStoreGeneration() -> Int {
        return bumpIsolatedWorkspaceStoreGeneration(for: .reviewDemo)
    }

    func setIsolatedWorkspace(_ workspace: LoomSpecialAccountWorkspace?) {
        defaults.set(workspace != nil, forKey: Keys.reviewDemoModeEnabled)
        if let workspace {
            defaults.set(workspace.rawValue, forKey: Keys.isolatedWorkspaceKind)
        } else {
            defaults.removeObject(forKey: Keys.isolatedWorkspaceKind)
        }
    }

    func isolatedWorkspaceStoreGeneration(for workspace: LoomSpecialAccountWorkspace) -> Int {
        let key = workspace.storeGenerationDefaultsKey
        if defaults.object(forKey: key) != nil {
            return defaults.integer(forKey: key)
        }

        // Migrate older installs that used one shared isolated-store generation counter.
        let legacyValue = defaults.integer(forKey: Keys.reviewDemoStoreGeneration)
        if legacyValue > 0, workspace != .reviewDemo {
            defaults.set(legacyValue, forKey: key)
            return legacyValue
        }

        return defaults.integer(forKey: key)
    }

    func bumpIsolatedWorkspaceStoreGeneration(for workspace: LoomSpecialAccountWorkspace? = nil) -> Int {
        let resolvedWorkspace = workspace ?? LoomDefaultsScope.currentWorkspace(defaults: defaults) ?? .reviewDemo
        let key = resolvedWorkspace.storeGenerationDefaultsKey
        let nextValue = isolatedWorkspaceStoreGeneration(for: resolvedWorkspace) + 1
        defaults.set(nextValue, forKey: key)
        return nextValue
    }

    func resetIsolatedWorkspaceForNextSignIn(_ workspace: LoomSpecialAccountWorkspace) {
        let currentWorkspace = LoomDefaultsScope.currentWorkspace(defaults: defaults)
        if currentWorkspace == workspace && hasAccount {
            defaults.set(true, forKey: workspace.pendingResetDefaultsKey)
            return
        }
        clearPersistedWorkspaceState(for: workspace)
    }

    func resetIsolatedWorkspaceImmediately(_ workspace: LoomSpecialAccountWorkspace) {
        clearPersistedWorkspaceState(for: workspace)
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
        let workspace = LoomDefaultsScope.currentWorkspace(defaults: defaults)

        if let workspace {
            let shouldResetWorkspace =
                !workspace.preservesWorkspaceStateAcrossLogout ||
                defaults.bool(forKey: workspace.pendingResetDefaultsKey)
            if shouldResetWorkspace {
                clearPersistedWorkspaceState(for: workspace)
            }
        }
        setHasAccount(false)
        setHasCompletedDiagnostic(false)
        setHasSeenDiagnosticInsights(false)
        setIsSubscribed(false)
        setIsolatedWorkspace(nil)
        defaults.removeObject(forKey: Keys.appleUserID)
        defaults.removeObject(forKey: Keys.googleUserID)
        defaults.removeObject(forKey: Keys.authProvider)
        defaults.removeObject(forKey: Keys.accountName)
        defaults.removeObject(forKey: Keys.accountEmail)
        TestDemoProvisioningService.clearLocalProvisioningState(defaults: defaults)
    }

    private func clearPersistedWorkspaceState(for workspace: LoomSpecialAccountWorkspace) {
        _ = bumpIsolatedWorkspaceStoreGeneration(for: workspace)
        LoomDefaultsScope.clearScopedValues(for: workspace, defaults: defaults)
        defaults.removeObject(forKey: workspace.bootstrapDefaultsKey)
        defaults.removeObject(forKey: workspace.pendingResetDefaultsKey)
    }

    #if canImport(AuthenticationServices)
    func completeSignInWithApple(_ credential: ASAuthorizationAppleIDCredential) {
        setIsolatedWorkspace(nil)
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
        applySuccessfulSignInGateState()
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
        setIsolatedWorkspace(nil)
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

        applySuccessfulSignInGateState()
    }

    func completeSignInWithEmail(
        userID: String?,
        email: String?,
        fullName: String?
    ) {
        defaults.set("email", forKey: Keys.authProvider)
        defaults.removeObject(forKey: Keys.googleUserID)
        defaults.removeObject(forKey: Keys.appleUserID)
        _ = userID

        let trimmedEmail = email?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedEmail.isEmpty {
            defaults.set(trimmedEmail, forKey: Keys.accountEmail)
        }

        let trimmedName = fullName?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedName.isEmpty {
            defaults.set(trimmedName, forKey: Keys.accountName)
        }

        applySuccessfulSignInGateState()
    }

    private func applySuccessfulSignInGateState() {
        let hasExistingPersonalization = hasPersistedProgressForCurrentUser()
        let resolvedHasSeenOnboarding = hasSeenOnboarding || hasExistingPersonalization
        let resolvedHasCompletedDiagnostic = hasCompletedDiagnostic || hasExistingPersonalization
        let resolvedHasSeenDiagnosticInsights = hasSeenDiagnosticInsights || hasExistingPersonalization
        applyGateState(
            hasSeenOnboarding: resolvedHasSeenOnboarding,
            hasAccount: true,
            hasCompletedDiagnostic: resolvedHasCompletedDiagnostic,
            hasSeenDiagnosticInsights: resolvedHasSeenDiagnosticInsights
        )
    }

    private func hasPersistedProgressForCurrentUser() -> Bool {
        let personalizationState = PersonalizationStore.cachedStateForCurrentUser(defaults: defaults)
        return personalizationState.current != nil || !personalizationState.history.isEmpty
    }

    private func applyGateState(
        hasSeenOnboarding: Bool,
        hasAccount: Bool,
        hasCompletedDiagnostic: Bool,
        hasSeenDiagnosticInsights: Bool
    ) {
        let resolvedHasCompletedDiagnostic = hasAccount ? hasCompletedDiagnostic : false
        let resolvedHasSeenDiagnosticInsights =
            (hasAccount && resolvedHasCompletedDiagnostic) ? hasSeenDiagnosticInsights : false

        self.hasSeenOnboarding = hasSeenOnboarding
        self.hasAccount = hasAccount
        self.hasCompletedDiagnostic = resolvedHasCompletedDiagnostic
        self.hasSeenDiagnosticInsights = resolvedHasSeenDiagnosticInsights

        defaults.set(hasSeenOnboarding, forKey: Keys.hasSeenOnboarding)
        defaults.set(hasAccount, forKey: Keys.hasAccount)
        defaults.set(resolvedHasCompletedDiagnostic, forKey: Keys.hasCompletedDiagnostic)
        defaults.set(resolvedHasSeenDiagnosticInsights, forKey: Keys.hasSeenDiagnosticInsights)
    }

    func reloadFromDefaults() {
        hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        hasAccount = defaults.bool(forKey: Keys.hasAccount)
        hasCompletedDiagnostic = defaults.bool(forKey: Keys.hasCompletedDiagnostic)
        hasSeenDiagnosticInsights = defaults.bool(forKey: Keys.hasSeenDiagnosticInsights)
        isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }

}
