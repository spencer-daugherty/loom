//
//  loomTests.swift
//  loomTests
//
//  Created by Spencer Daugherty on 4/28/25.
//

import Testing
import Foundation
@testable import loom

struct loomTests {

    @Test func example() async throws {
        // Write your test here and use APIs like `#expect(...)` to check expected conditions.
    }

    @Test func insightPromptContextIncludesSurfaceAndGuideContext() {
        let snapshot = sampleContextSnapshot()

        let json = AppleIntelligenceInsightPromptBuilder.contextJSON(
            surfaceID: "purpose_header_readable_insight",
            context: snapshot
        )

        #expect(json.contains("\"surfaceID\":\"purpose_header_readable_insight\""))
        #expect(json.contains("\"title\":\"Purpose Onboarding\""))
        #expect(json.contains("\"summary\":\"Purpose onboarding guides users"))
    }

    @Test func readableInsightContextUsesCompactReadableShape() {
        let snapshot = sampleContextSnapshot()

        let json = AppleIntelligenceInsightPromptBuilder.readableInsightContextJSON(
            surfaceID: "fulfillment_trends_readable_insight",
            context: snapshot
        )

        #expect(json.contains("\"surfaceID\":\"fulfillment_trends_readable_insight\""))
        #expect(json.contains("\"fulfillmentCategories\""))
        #expect(json.contains("\"currentWeekActionBlocks\""))
        #expect(!json.contains("\"shareAttachmentPreview\""))
    }

    @Test func purposeFormulaGuideIncludesBaselineAndWeights() {
        let guide = AppleIntelligenceInsightPromptBuilder.purposeFormulaGuide()

        #expect(guide.contains("0.0 to 4.0"))
        #expect(guide.contains("2.0 baseline"))
        #expect(guide.contains("Structure (0.15)"))
        #expect(guide.contains("Action Blocks (0.25)"))
        #expect(guide.contains("Outcomes (0.30)"))
    }

    @Test func fulfillmentFormulaGuideIncludesStrategicBehaviorAndBaseline() {
        let guide = AppleIntelligenceInsightPromptBuilder.fulfillmentFormulaGuide()

        #expect(guide.contains("1.0 to 5.0"))
        #expect(guide.contains("3.0 baseline"))
        #expect(guide.contains("Strategic Behavior"))
        #expect(guide.contains("Structure (0.18)"))
        #expect(guide.contains("Action Blocks (0.22)"))
        #expect(guide.contains("optional Outcomes (0.25)"))
    }

    @Test func readableInsightNormalizerSplitsPlainTextFallback() {
        let result = AppleIntelligenceReadableInsightNormalizer.fromPlainText(
            "Baseline week only, so the signal is still broad.\n\nComplete one small Action Plan to establish support."
        )

        #expect(result.insight == "Baseline week only, so the signal is still broad.")
        #expect(result.action == "Complete one small Action Plan to establish support.")
    }

    @Test func readableInsightLeveragePrefersHigherRealOpportunity() {
        let structure = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .structure,
            currentValue: 0.72,
            weight: 0.15,
            reason: "Structure is decent but still has room.",
            recommendedAction: "Clarify the setup.",
            actionabilityPriority: 1
        )
        let carryover = AppleIntelligenceReadableInsightLeverageEngine.dragCandidate(
            metric: .carryoverPenalty,
            currentPenalty: 0.52,
            weight: 0.10,
            reason: "Carryover drag is suppressing the score.",
            recommendedAction: "Shrink one overloaded plan.",
            actionabilityPriority: 2
        )

        let analysis = AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: [structure, carryover])

        #expect(analysis?.metric == .carryoverPenalty)
        #expect(analysis?.displayValue == "52%")
        #expect(analysis?.recommendedAction == "Shrink one overloaded plan.")
    }

    @Test func readableInsightLeveragePreservesMissingMetricSignals() {
        let outcomes = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .outcomes,
            currentValue: 0,
            weight: 0.25,
            reason: "Outcomes are not yet connected.",
            recommendedAction: "Connect one outcome milestone.",
            detail: "missing_outcomes",
            isMissing: true,
            actionabilityPriority: 3
        )
        let actionBlocks = AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
            metric: .actionBlocks,
            currentValue: 0.7,
            weight: 0.22,
            reason: "Action Blocks are already fairly solid.",
            recommendedAction: "Finish one more small plan.",
            actionabilityPriority: 1
        )

        let analysis = AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: [outcomes, actionBlocks])

        #expect(analysis?.metric == .outcomes)
        #expect(analysis?.isMissing == true)
        #expect(analysis?.detail == "missing_outcomes")
    }

    @Test func diagnosticsPromptUsesStructuredFieldsAndContext() {
        let snapshot = PersonalizationSnapshot(
            stressSource: "Too many competing priorities",
            breakPoint: "Follow-through collapses first",
            lifeAreasSelected: ["Career & Business", "Health & Vitality"],
            planningReality: "Reactive and behind",
            desiredChange: "More consistency"
        )
        let prompt = SupportedDeviceDiagnosticsInsightsComposer.prompt(
            snapshot: snapshot,
            context: sampleContextSnapshot()
        )

        #expect(prompt.contains("`rootCause`, `fulfillmentAreas`, `nextDirection`"))
        #expect(prompt.contains("APP_CONTEXT JSON"))
        #expect(prompt.contains("diagnostic_insights"))
        #expect(!prompt.contains("Every task, goal, and little win will land in one of these areas"))
    }

    @Test func purposeProfileHashOnlyTracksQuestionnaireAnswers() {
        let diagnostic = DiagnosticAnswers(
            stress: "Overwhelm",
            breaksFirst: "Consistency",
            areas: ["Career & Business"],
            planningStyle: "Reactive",
            firstChange: "More focus"
        )

        let base = PurposeProfileInsightsHasher.hash(diagnostic: diagnostic)
        let sameQuestionnaire = PurposeProfileInsightsHasher.hash(diagnostic: diagnostic)
        let changedQuestionnaire = PurposeProfileInsightsHasher.hash(
            diagnostic: DiagnosticAnswers(
                stress: "Work pressure",
                breaksFirst: "Consistency",
                areas: ["Career & Business"],
                planningStyle: "Reactive",
                firstChange: "More focus"
            )
        )

        #expect(base == sameQuestionnaire)
        #expect(base != changedQuestionnaire)
    }

    private func sampleContextSnapshot() -> LoomAIContextSnapshot {
        LoomAIContextSnapshot(
            generatedAt: .now,
            personalizationHash: "sample",
            diagnostic: .init(
                stress: "Too many priorities",
                breaksFirst: "Consistency",
                areas: ["Career & Business", "Health & Vitality"],
                planningStyle: "Reactive",
                firstChange: "More direction",
                rootCause: "Reactive inputs are crowding out deliberate planning.",
                nextDirection: "Tighten the system around fewer priorities."
            ),
            drivingForce: .init(
                vision: "Build a stable, meaningful life.",
                purpose: "Create clear momentum in the work that matters.",
                passions: [.init(emotion: "love", title: "Family"), .init(emotion: "thrill", title: "Adventure")]
            ),
            fulfillmentCategories: [
                .init(
                    id: UUID().uuidString,
                    name: "Career & Business",
                    colorKey: "blue",
                    mission: "Build focused work.",
                    identity: ["Operator"],
                    littleWins: ["Deep work"],
                    resources: ["Calendar"],
                    connectedPassions: ["thrill: Adventure"],
                    weeklyScore: 3.4
                )
            ],
            activeOutcomes: [
                .init(
                    id: UUID().uuidString,
                    title: "Launch client work",
                    category: "Career & Business",
                    endDate: .now,
                    measurable: true,
                    progressSummary: "Current 2 / Goal 5"
                )
            ],
            currentWeekActionBlocks: [
                .init(
                    category: "Career & Business",
                    title: "Ship the next milestone",
                    completionRatio: 0.75,
                    actions: ["Finish draft", "Send review"]
                )
            ],
            recentActivity: .init(
                quickCompletesLast7Days: 3,
                littleWinsCompletionsLast7Days: 5,
                carryoversLast7Days: 1
            ),
            capture: .init(
                totalCount: 8,
                topItems: ["Book dentist", "Review roadmap"],
                quickCompletionsLast7Days: 3,
                recurringRuleCount: 2
            ),
            recentlyDeleted: nil,
            sectionTimestamps: nil,
            purposeProfile: .init(profile: "Purpose-Led Planner", generatedAt: .now),
            dataInventory: [],
            appGuide: [
                .init(
                    id: "purpose_onboarding",
                    title: "Purpose Onboarding",
                    summary: "Purpose onboarding guides users to create Vision, Purpose, and Passions, then uses passion scoring snapshots and insights to reveal patterns over time.",
                    relatedSections: ["purpose_current"]
                )
            ],
            notes: ["Use the app guide to interpret the system."],
            purposeDraft: nil,
            fulfillmentSetup: .init(
                selectedCategoryIDs: [UUID().uuidString],
                selectedCategoryNames: ["Career & Business"],
                categoryCount: 1,
                focusCategoryNames: ["Career & Business"]
            ),
            personalization: nil,
            reflectionJournal: nil,
            shareAttachmentPreview: nil
        )
    }

}
