import Foundation
import Testing
@testable import loom

struct LocalDiagnosticInsightsEngineTests {
    @Test
    func overloadNoStartChoosesExpectedCoreCandidate() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Too many priorities competing",
                breaksFirst: "I don’t start",
                areas: ["Career & Business", "Wealth & Finance", "Love & Relationships", "Home & Life"],
                planningStyle: "React to what’s urgent",
                firstChange: "I feel in control (less stress)"
            )
        )

        #expect(result.candidateID == "RC001")
    }

    @Test
    func distractionMomentumLossSelectsMomentumSpecificCandidate() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Distractions are stealing my focus",
                breaksFirst: "I start, then lose momentum",
                areas: ["Career & Business", "Love & Relationships", "Home & Life", "Mindset & Resilience"],
                planningStyle: "Plan, but get off track",
                firstChange: "I follow through (consistency)"
            )
        )

        #expect(result.candidateID == "CORE_AF_06" || result.candidateID == "RC012")
    }

    @Test
    func disorganizedOverthinkingWithSimpleListUsesBridgeCandidate() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Feeling behind or disorganized",
                breaksFirst: "I overthink it",
                areas: ["Career & Business", "Wealth & Finance", "Home & Life"],
                planningStyle: "Keep a simple to-do list",
                firstChange: "I know what matters (clear direction)"
            )
        )

        #expect(result.candidateID == "BRIDGE_02")
    }

    @Test
    func workPressureNoStartStablePlannerPrefersStableOverride() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Work pressure",
                breaksFirst: "I don’t start",
                areas: ["Career & Business", "Wealth & Finance", "Home & Life"],
                planningStyle: "Plan and follow through consistently",
                firstChange: "I make faster progress on big goals"
            )
        )

        #expect(result.candidateID == "BRIDGE_11" || result.candidateID == "CORE_PT_12")
    }

    @Test
    func hiddenBreakUsesKnownStressHiddenBreakCandidate() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Money pressure",
                breaksFirst: "I’m not sure",
                areas: ["Wealth & Finance", "Career & Business", "Home & Life"],
                planningStyle: "It depends on the day",
                firstChange: "I feel in control (less stress)"
            )
        )

        #expect(result.candidateID == "BRIDGE_HB_05" || result.candidateID == "CORE_HB_01")
    }

    @Test
    func fullyAmbiguousAnswersUseFallback() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Not sure yet",
                breaksFirst: "I’m not sure",
                areas: ["Learning & Education", "Mindset & Resilience", "Lifestyle & Experiences"],
                planningStyle: "It depends on the day",
                firstChange: "I feel balanced across life"
            )
        )

        #expect(result.layer == "fallback")
        #expect(result.candidateID == "RF054" || result.candidateID == "RF055")
    }

    @Test
    func selectedCopyRespectsWordCountAndAreaLeakRules() {
        let result = LocalDiagnosticInsightsEngine.matchResult(
            for: .init(
                stress: "Low energy / health",
                breaksFirst: "I get distracted",
                areas: ["Health & Energy", "Career & Business", "Home & Life"],
                planningStyle: "It depends on the day",
                firstChange: "I feel balanced across life"
            )
        )

        #expect(wordCount(result.rootCause) <= 40)
        #expect(wordCount(result.nextDirection) <= 40)
        #expect(!containsAreaLeak(result.rootCause))
        #expect(!containsAreaLeak(result.nextDirection))
    }

    @Test
    func serviceReturnsSameLocalOutputAsEngine() async throws {
        let diagnostic = DiagnosticAnswers(
            stress: "Relationship tension",
            breaksFirst: "I don’t start",
            areas: ["Love & Relationships", "Home & Life", "Mindset & Resilience"],
            planningStyle: "It depends on the day",
            firstChange: "I feel balanced across life"
        )

        let fromEngine = LocalDiagnosticInsightsEngine.generate(diagnostic: diagnostic)
        let fromService = try await LoomAIService().fetchDiagnosticInsights(
            diagnostic: diagnostic,
            client: DiagnosticInsightsClient(screen: "test")
        )

        #expect(fromService.rootCause == fromEngine.rootCause)
        #expect(fromService.nextDirection == fromEngine.nextDirection)
    }

    private func wordCount(_ text: String) -> Int {
        text.split(whereSeparator: \.isWhitespace).count
    }

    private func containsAreaLeak(_ text: String) -> Bool {
        let lower = text.lowercased()
        let areas = [
            "career & business",
            "faith & spirituality",
            "wealth & finance",
            "learning & education",
            "love & relationships",
            "health & energy",
            "lifestyle & experiences",
            "mindset & resilience",
            "service & impact",
            "home & life"
        ]
        return areas.contains(where: { lower.contains($0) })
    }
}
