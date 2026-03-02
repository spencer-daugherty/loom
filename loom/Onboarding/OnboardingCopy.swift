import SwiftUI

enum OnboardingCopy {
    static let pages: [OnboardingPage] = [
        .init(
            id: 0,
            headline: "Life gets too crazy.",
            body: "Work, health, relationships, finance - pulling you in every direction. Loom turns the chaos into one clear path.",
            visualKind: .strands
        ),
        .init(
            id: 1,
            headline: "Loom brings it all together.",
            body: "Like the device that weaves threads into cloth, Loom continuously refines areas in your life into one clear plan - today, tomorrow, and long-term.",
            visualKind: .weave
        ),
        .init(
            id: 2,
            headline: "Start with who you are.",
            body: "Define your life purpose and passions - what you love, what thrills you, what you vow, and what you refuse to tolerate (hate).",
            visualKind: .identity
        ),
        .init(
            id: 3,
            headline: "Balance what matters most.",
            body: "Personalize 3-7 fulfillment areas so your time, energy, and focus move with intention.",
            visualKind: .balance
        ),
        .init(
            id: 4,
            headline: "Turn plans into action.",
            body: "Make real progress effortless by focusing on what matters now to create the life you want, not an endless to-do list.",
            visualKind: .execution
        ),
        .init(
            id: 5,
            headline: "Create daily momentum.",
            body: "Little Wins make instant gratification and delayed acheivement work together.",
            visualKind: .radar
        ),
        .init(
            id: 6,
            headline: "Your next best move.",
            body: "LoomAI understands your goals and guides your plans.",
            visualKind: .summary
        )
    ]

    static let next: LocalizedStringKey = "Next"
    static let skip: LocalizedStringKey = "Skip"
    static let createAccount: LocalizedStringKey = "Create account"
    static let continueText: LocalizedStringKey = "Continue"
}
