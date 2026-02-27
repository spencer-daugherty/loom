import SwiftUI

enum OnboardingCopy {
    static let pages: [OnboardingPage] = [
        .init(
            id: 0,
            headline: "Life runs on too many timelines.",
            body: "Work, health, relationships, goals—pulling you in every direction. Loom turns the noise into one clear direction.",
            visualKind: .strands
        ),
        .init(
            id: 1,
            headline: "Loom weaves it all into one plan.",
            body: "Like a loom weaves countless strands into fabric, Loom weaves your life into one direction—today, tomorrow, and long-term.",
            visualKind: .weave
        ),
        .init(
            id: 2,
            headline: "Start with who you are.",
            body: "Capture your Driving Force—what you love, what thrills you, what you vow, and what you refuse to tolerate.",
            visualKind: .identity
        ),
        .init(
            id: 3,
            headline: "Balance what matters most.",
            body: "Choose Fulfillment Categories so your time reflects your priorities, not your stress.",
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
