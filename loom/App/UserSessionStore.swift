import Foundation

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

    func reloadFromDefaults() {
        hasSeenOnboarding = defaults.bool(forKey: Keys.hasSeenOnboarding)
        hasAccount = defaults.bool(forKey: Keys.hasAccount)
        isSubscribed = defaults.bool(forKey: Keys.isSubscribed)
    }
}
