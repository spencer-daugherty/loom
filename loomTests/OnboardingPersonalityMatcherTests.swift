import Testing
@testable import loom

struct OnboardingPersonalityMatcherTests {
    @Test
    func rawAndNormalizedTraitsMatchSpec() {
        let responses = OnboardingQuestionnaireResponses(
            stressSource: .workPressure,
            breakPoint: .dontFinish,
            selectedAreas: ["Career & Business", "Wealth & Finance", "Home & Life"],
            planningReality: .reactToUrgent,
            desiredChange: .inControl
        )

        let raw = OnboardingPersonalityMatcher.rawTraitVector(for: responses)
        let normalized = OnboardingPersonalityMatcher.normalizedTraitVector(from: raw)

        expectClose(raw.ER, 0.9833333333)
        expectClose(raw.XP, -0.7583333333)
        expectClose(raw.SF, 0.8583333333)
        expectClose(raw.HD, -0.2583333333)
        expectClose(raw.ID, 1.35)
        expectClose(raw.FT, -0.7583333333)
        expectClose(raw.UB, 2.75)
        expectClose(raw.MB, -1.375)

        expectClose(normalized.ER, 0.3933333333)
        expectClose(normalized.XP, -0.1685185185)
        expectClose(normalized.SF, 0.1560606061)
        expectClose(normalized.HD, -0.0574074074)
        expectClose(normalized.ID, 0.3)
        expectClose(normalized.FT, -0.1378787879)
        expectClose(normalized.UB, 0.5)
        expectClose(normalized.MB, -0.25)
    }

    @Test
    func lifeAreaAggregationUsesMeanAndBreadthOnlyNudgesHarmonyAndMeaning() {
        let base = OnboardingPersonalityMatcher.lifeAreaContribution(
            for: ["Career & Business", "Wealth & Finance", "Home & Life"]
        )
        expectClose(base.ER, 0.0833333333)
        expectClose(base.XP, -0.4583333333)
        expectClose(base.SF, 0.9583333333)
        expectClose(base.HD, 0.0416666667)
        expectClose(base.ID, 0.25)
        expectClose(base.FT, 0.5416666667)
        expectClose(base.UB, 0.25)
        expectClose(base.MB, -0.375)

        let expanded = OnboardingPersonalityMatcher.lifeAreaContribution(
            for: [
                "Career & Business",
                "Wealth & Finance",
                "Home & Life",
                "Learning & Education",
                "Love & Relationships"
            ]
        )

        expectClose(expanded.ER, 0.05)
        expectClose(expanded.XP, -0.025)
        expectClose(expanded.SF, 0.675)
        expectClose(expanded.ID, 0.175)
        expectClose(expanded.FT, 0.375)
        expectClose(expanded.UB, 0.025)
        expectClose(expanded.HD, 0.35)
        expectClose(expanded.MB, 0.2)
    }

    @Test
    func customLifeAreaKeywordMappingHandlesSplitIntentDeterministically() {
        let vector = OnboardingPersonalityMatcher.customAreaVector(
            for: "career leadership and community impact"
        )

        expectClose(vector.ER, 0.1875)
        expectClose(vector.XP, 0.0375)
        expectClose(vector.SF, 0.3375)
        expectClose(vector.HD, 0.3)
        expectClose(vector.ID, 0.1125)
        expectClose(vector.FT, 0.225)
        expectClose(vector.UB, 0.1125)
        expectClose(vector.MB, 0.15)
    }

    @Test
    func urgencyHeavyCaseRanksCrisisNavigatorFirst() {
        let result = OnboardingPersonalityMatcher.match(
            responses: .init(
                stressSource: .workPressure,
                breakPoint: .dontFinish,
                selectedAreas: ["Career & Business", "Service & Impact", "Home & Life"],
                planningReality: .reactToUrgent,
                desiredChange: .fasterProgress
            )
        )

        #expect(result.winner.profileID == .crisisNavigator)
        #expect(result.topProfiles.map(\.profileID).contains(.operationalCommander))
    }

    @Test
    func structuredPragmaticExecutorCaseSurfacesOperationalProfiles() {
        let result = OnboardingPersonalityMatcher.match(
            responses: .init(
                stressSource: .feelingBehindOrDisorganized,
                breakPoint: .dontFinish,
                selectedAreas: ["Career & Business", "Wealth & Finance", "Home & Life"],
                planningReality: .planAndFollowThrough,
                desiredChange: .followThrough
            )
        )

        let topTwo = Set(result.topProfiles.prefix(2).map(\.profileID))
        #expect(topTwo.contains(.operationalCommander) || topTwo.contains(.qualitySentinel))
        #expect(result.topProfiles.map(\.profileID).contains(.steadyAlignmentBuilder))
    }

    @Test
    func reflectiveStructuredHarmonizingCaseKeepsPurposeLedPlannerNearTop() {
        let result = OnboardingPersonalityMatcher.match(
            responses: .init(
                stressSource: .notSureYet,
                breakPoint: .overthinkIt,
                selectedAreas: ["Faith & Spirituality", "Learning & Education", "Mindset & Resilience"],
                planningReality: .simpleTodo,
                desiredChange: .clearDirection
            )
        )

        #expect(result.topProfiles.prefix(2).map(\.profileID).contains(.purposeLedPlanner))
    }

    @Test
    func reflectiveLowStartCaseStaysWithinExpectedTopBand() {
        let result = OnboardingPersonalityMatcher.match(
            responses: .init(
                stressSource: .notSureYet,
                breakPoint: .dontStart,
                selectedAreas: ["Faith & Spirituality", "Learning & Education", "Mindset & Resilience"],
                planningReality: .simpleTodo,
                desiredChange: .clearDirection
            )
        )

        let expected: Set<LoomPersonalityProfileID> = [.analyticalArchitect, .purposeLedPlanner, .reflectiveSynthesizer]
        let actual = Set(result.topProfiles.map(\.profileID))
        #expect(!expected.intersection(actual).isEmpty)
    }

    @Test
    func tieBreakUsesMostEvidencedTraitAndFallsBackDeterministically() {
        let winner = OnboardingPersonalityMatcher.tieBreakWinner(
            first: .init(
                profileID: .structuredClarityDriver,
                profileName: LoomPersonalityProfileID.structuredClarityDriver.profileName,
                baseMatch: 7.5,
                directBonus: 0.2,
                calibrationOffset: 0,
                rawScore: 7.6
            ),
            second: .init(
                profileID: .strategicIntegrator,
                profileName: LoomPersonalityProfileID.strategicIntegrator.profileName,
                baseMatch: 7.5,
                directBonus: 0.2,
                calibrationOffset: 0,
                rawScore: 7.55
            ),
            normalizedTraits: .init(ER: 0.2, XP: 0.1, SF: 0.8, HD: 0.9, ID: 0.1, FT: 0.3, UB: 0.0, MB: 0.2),
            rawTraits: .init(ER: 0.5, XP: 0.3, SF: 4.4, HD: 3.6, ID: 0.4, FT: 1.5, UB: 0.0, MB: 1.1),
            responses: .init(
                stressSource: .tooManyPrioritiesCompeting,
                breakPoint: .loseMomentum,
                selectedAreas: ["Career & Business", "Love & Relationships", "Mindset & Resilience"],
                planningReality: .planButOffTrack,
                desiredChange: .balancedLife
            )
        )

        #expect(winner == .strategicIntegrator)
    }

    @Test
    func ambiguousAnswersProduceLowConfidence() {
        let result = OnboardingPersonalityMatcher.match(
            responses: .init(
                stressSource: .notSureYet,
                breakPoint: .notSure,
                selectedAreas: ["Learning & Education", "Mindset & Resilience", "Lifestyle & Experiences"],
                planningReality: .dependsOnDay,
                desiredChange: .balancedLife
            )
        )

        #expect(result.lowConfidence)
        #expect(result.confidence < 0.52)
    }

    @Test
    func wrapperMatcherUsesDeterministicWinner() {
        let record = PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: "Work pressure",
                breakPoint: "I don’t finish what I start",
                planning: "React to what’s urgent",
                desired: "I make faster progress on big goals",
                areas: ["Career & Business", "Service & Impact", "Home & Life"],
                vision: "unused in deterministic scoring",
                passions: ["unused"]
            )
        )

        #expect(record.profile == "Crisis Navigator")
    }

    private func expectClose(
        _ actual: Double,
        _ expected: Double,
        tolerance: Double = 0.0001,
        sourceLocation: SourceLocation = #_sourceLocation
    ) {
        #expect(abs(actual - expected) <= tolerance, sourceLocation: sourceLocation)
    }
}
