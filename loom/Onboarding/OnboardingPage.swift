import SwiftUI

enum OnboardingVisualKind {
    case strands
    case weave
    case identity
    case balance
    case execution
    case radar
    case summary
}

struct OnboardingPage: Identifiable {
    let id: Int
    let headline: LocalizedStringKey
    let body: LocalizedStringKey
    let visualKind: OnboardingVisualKind
}
