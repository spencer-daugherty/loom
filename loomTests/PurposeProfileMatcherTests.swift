import Testing
@testable import loom

struct PurposeProfileMatcherTests {
    @Test
    func specialistProfilesRemainReachable() {
        let cases: [(String, PurposeProfileMatcher.Inputs)] = [
            (
                "Operational Commander",
                .init(
                    stress: "Work pressure",
                    breakPoint: "I don't finish what I start",
                    planning: "React to what's urgent",
                    desired: "I feel in control (less stress)",
                    areas: ["Career & Business", "Home & Life", "Wealth & Finance"],
                    vision: "I operate with clear direction, strong boundaries, and daily action on what matters most.",
                    passions: ["Leading teams"]
                )
            ),
            (
                "Crisis Navigator",
                .init(
                    stress: "Work pressure",
                    breakPoint: "I don't finish what I start",
                    planning: "React to what's urgent",
                    desired: "I make faster progress on big goals",
                    areas: ["Service & Impact", "Career & Business", "Home & Life"],
                    vision: "I operate with clear direction, strong boundaries, and daily action on what matters most.",
                    passions: ["Community building"]
                )
            ),
            (
                "Analytical Architect",
                .init(
                    stress: "Not sure yet",
                    breakPoint: "I overthink it",
                    planning: "Keep a simple to-do list",
                    desired: "I know what matters (clear direction)",
                    areas: ["Learning & Education", "Wealth & Finance", "Career & Business"],
                    vision: "I design each week around my highest priorities so urgent noise does not run my life.",
                    passions: ["Designing systems"]
                )
            ),
            (
                "Reflective Synthesizer",
                .init(
                    stress: "Not sure yet",
                    breakPoint: "I overthink it",
                    planning: "It depends on the day",
                    desired: "I feel balanced across life",
                    areas: ["Faith & Spirituality", "Mindset & Resilience", "Learning & Education"],
                    vision: "I make meaningful progress on long-term goals while keeping balance across my core life areas.",
                    passions: ["Music"]
                )
            ),
            (
                "Independent Pathfinder",
                .init(
                    stress: "Not sure yet",
                    breakPoint: "I don't start",
                    planning: "It depends on the day",
                    desired: "I make faster progress on big goals",
                    areas: ["Learning & Education", "Lifestyle & Experiences", "Career & Business"],
                    vision: "I become the kind of person who starts quickly, follows through, and keeps promises to myself.",
                    passions: ["Travel and exploration"]
                )
            )
        ]

        for (expected, inputs) in cases {
            let match = PurposeProfileMatcher.bestMatch(inputs: inputs)
            #expect(match.profile == expected)
        }
    }

    @Test
    func areasAffectFallbackMatch() {
        let base = (
            stress: "Not sure yet",
            breakPoint: "I overthink it",
            planning: "Keep a simple to-do list",
            desired: "I know what matters (clear direction)",
            vision: "I design each week around my highest priorities so urgent noise does not run my life.",
            passions: ["Designing systems"]
        )

        let analytical = PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: base.stress,
                breakPoint: base.breakPoint,
                planning: base.planning,
                desired: base.desired,
                areas: ["Learning & Education", "Wealth & Finance", "Career & Business"],
                vision: base.vision,
                passions: base.passions
            )
        )
        let reflective = PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: base.stress,
                breakPoint: base.breakPoint,
                planning: base.planning,
                desired: base.desired,
                areas: ["Faith & Spirituality", "Mindset & Resilience", "Love & Relationships"],
                vision: base.vision,
                passions: base.passions
            )
        )

        #expect(analytical.profile == "Analytical Architect")
        #expect(reflective.profile != analytical.profile)
    }
}
