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
            body: "Personalize your key fulfillment areas so your time, energy, and focus move with intention.",
            visualKind: .balance
        ),
        .init(
            id: 4,
            headline: "Turn intention into execution.",
            body: "Loom transforms goals and messy tasks into small actions you repeat—so progress becomes automatic.",
            visualKind: .execution
        ),
        .init(
            id: 5,
            headline: "See stress before it stacks up.",
            body: "Your radar updates as you execute—so you catch neglect early and stay fulfilled, not overwhelmed.",
            visualKind: .radar
        ),
        .init(
            id: 6,
            headline: "One direction. Less stress. More life.",
            body: "Loom manages the weave—so you spend less time organizing and more time living with purpose.",
            visualKind: .summary
        )
    ]

    static let next: LocalizedStringKey = "Next"
    static let skip: LocalizedStringKey = "Skip"
    static let createAccount: LocalizedStringKey = "Create account"
}
