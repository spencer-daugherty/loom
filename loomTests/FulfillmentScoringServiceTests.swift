import Foundation
import SwiftData
import Testing
@testable import loom

struct FulfillmentScoringServiceTests {
    private let service = FulfillmentScoringService()

    @Test func maxWeeklySwingIsClamped() {
        let prev = FulfillmentCategoryScoreSnapshot(
            weekStartDate: FulfillmentScoringMath.weekWindow(for: Date(timeIntervalSince1970: 1_700_000_000)).weekStart,
            categoryID: UUID(),
            categoryTitleSnapshot: "Career & Business",
            score: 2.0,
            smoothedScore: 2.0,
            targetScore: 2.0,
            evidence: 0.5,
            momentum: 0,
            structure: 0.5,
            outcomes: 0.5,
            actionBlocks: 0.5,
            carryoverPenalty: 0.2,
            littleWins: 0.5,
            engagement: 0.5,
            strategicBalance: 0.5,
            consistency: 1.0
        )
        let signals = FulfillmentCategorySignals(
            hasVision: true,
            hasPurpose: true,
            rolesCount: 10,
            resourcesCount: 10,
            passionsLinkedCount: 10,
            littleWinsDefinedCount: 10,
            actionBlockCompletionMean: 1,
            actionBlockCarryoverMean: 0,
            strategicCompletionShare: 1,
            reactiveCarryoverMean: 0,
            littleWinsCompletedCount: 50,
            littleWinsScheduledCount: 50,
            outcomeScores: [1, 1, 1],
            engagedDaysCount: 7
        )
        let result = service.computeScore(signals: signals, history: [prev])
        #expect(abs(result.score - prev.score) <= 1.000_001)
    }

    @Test func noQuantityBiasWhenRatiosSame() {
        let low = FulfillmentCategorySignals(
            hasVision: true,
            hasPurpose: true,
            rolesCount: 2,
            resourcesCount: 2,
            passionsLinkedCount: 2,
            littleWinsDefinedCount: 3,
            actionBlockCompletionMean: 0.7,
            actionBlockCarryoverMean: 0.1,
            strategicCompletionShare: 0.6,
            reactiveCarryoverMean: 0.2,
            littleWinsCompletedCount: 7,
            littleWinsScheduledCount: 10,
            outcomeScores: [0.65],
            engagedDaysCount: 3
        )
        let high = FulfillmentCategorySignals(
            hasVision: true,
            hasPurpose: true,
            rolesCount: 2,
            resourcesCount: 2,
            passionsLinkedCount: 2,
            littleWinsDefinedCount: 3,
            actionBlockCompletionMean: 0.7,
            actionBlockCarryoverMean: 0.1,
            strategicCompletionShare: 0.6,
            reactiveCarryoverMean: 0.2,
            littleWinsCompletedCount: 70,
            littleWinsScheduledCount: 100,
            outcomeScores: [0.65],
            engagedDaysCount: 3
        )
        let r1 = service.computeScore(signals: low, history: [])
        let r2 = service.computeScore(signals: high, history: [])
        #expect(abs(r1.breakdown.littleWins - r2.breakdown.littleWins) < 0.000_001)
        #expect(abs(r1.breakdown.evidence - r2.breakdown.evidence) < 0.000_001)
        #expect(abs(r1.score - r2.score) < 0.000_001)
    }

    @Test func lowVolumeCategoryCanScoreFairly() {
        let signals = FulfillmentCategorySignals(
            hasVision: true,
            hasPurpose: true,
            rolesCount: 1,
            resourcesCount: 1,
            passionsLinkedCount: 1,
            littleWinsDefinedCount: 1,
            actionBlockCompletionMean: 0.9,
            actionBlockCarryoverMean: 0.0,
            strategicCompletionShare: 0.8,
            reactiveCarryoverMean: 0.0,
            littleWinsCompletedCount: 3,
            littleWinsScheduledCount: 3,
            outcomeScores: [0.8],
            engagedDaysCount: 3
        )
        let result = service.computeScore(signals: signals, history: [])
        #expect(result.score >= 3.0)
        #expect(result.score <= 5.0)
    }

    @Test func stableAcrossWeeksWithMinorSignalChanges() {
        let calendar = Calendar.current
        let baseWeek = FulfillmentScoringMath.weekWindow(for: .now).weekStart
        let categoryID = UUID()
        var history: [FulfillmentCategoryScoreSnapshot] = []
        var scores: [Double] = []

        for i in 0..<8 {
            let week = calendar.date(byAdding: .day, value: i * 7, to: baseWeek) ?? baseWeek
            let signals = FulfillmentCategorySignals(
                hasVision: true,
                hasPurpose: true,
                rolesCount: 2,
                resourcesCount: 2,
                passionsLinkedCount: 2,
                littleWinsDefinedCount: 3,
                actionBlockCompletionMean: 0.72 + (Double(i % 2) * 0.03),
                actionBlockCarryoverMean: 0.12,
                strategicCompletionShare: 0.60,
                reactiveCarryoverMean: 0.18,
                littleWinsCompletedCount: 10 + (i % 2),
                littleWinsScheduledCount: 14,
                outcomeScores: [],
                engagedDaysCount: 3 + (i % 2)
            )
            let result = service.computeScore(signals: signals, history: history)
            scores.append(result.score)
            history.append(
                FulfillmentCategoryScoreSnapshot(
                    weekStartDate: week,
                    categoryID: categoryID,
                    categoryTitleSnapshot: "Health & Vitality",
                    score: result.score,
                    smoothedScore: result.breakdown.smoothedScore,
                    targetScore: result.breakdown.targetScore,
                    evidence: result.breakdown.evidence,
                    momentum: result.breakdown.momentum,
                    structure: result.breakdown.structure,
                    outcomes: result.breakdown.outcomes,
                    actionBlocks: result.breakdown.actionBlocks,
                    carryoverPenalty: result.breakdown.carryoverPenalty,
                    littleWins: result.breakdown.littleWins,
                    engagement: result.breakdown.engagement,
                    strategicBalance: result.breakdown.strategicBalance,
                    consistency: result.breakdown.consistency
                )
            )
        }

        let deltas = zip(scores.dropFirst(), scores).map { abs($0.0 - $0.1) }
        #expect(deltas.allSatisfy { $0 <= 1.000_001 })
    }

    @Test func swiftDataPersistenceRoundTrip() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Fulfillment.self,
            FulfillmentRoles.self,
            FulfillmentFocus.self,
            FulfillmentResources.self,
            Passion.self,
            PassionFulfillmentJoin.self,
            LittleWinsDailyCompletion.self,
            ActionBlocksReflectionArchive.self,
            ActionBlocksReflectionArchiveAction.self,
            Outcomes.self,
            OutcomesMeasure.self,
            OutcomesMeasureEntry.self,
            OutcomeAnalyticsEvent.self,
            CompletedOutcomeArchive.self,
            FulfillmentCategoryScoreSnapshot.self,
            configurations: config
        )
        let context = ModelContext(container)

        let categoryID = UUID()
        context.insert(Fulfillment(category_id: categoryID, category: "Career & Business", category_identitiy: "", category_vision: "Vision", category_purpose: "Purpose"))
        context.insert(FulfillmentRoles(category_id: categoryID, role: "Builder", rank: 0))
        context.insert(FulfillmentFocus(category_id: categoryID, activity: "Daily outreach", rank: 0))
        try context.save()

        _ = try service.computeAndPersistCurrentWeek(in: context)
        let rows = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>())
        #expect(rows.count == 1)
        #expect(rows[0].score >= 1 && rows[0].score <= 5)
    }

    @Test func schemaMigrationSafetySmoke() throws {
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        let container = try ModelContainer(
            for: Fulfillment.self,
            FulfillmentArchive.self,
            FulfillmentRoles.self,
            FulfillmentRolesArchive.self,
            FulfillmentFocus.self,
            FulfillmentFocusArchive.self,
            FulfillmentResources.self,
            FulfillmentResourcesArchive.self,
            Passion.self,
            PassionArchive.self,
            PassionFulfillmentJoin.self,
            PassionFulfillmentJoinArchive.self,
            LittleWinsDailyCompletion.self,
            Outcomes.self,
            OutcomesMeasure.self,
            OutcomesMeasureEntry.self,
            OutcomeAnalyticsEvent.self,
            CompletedOutcomeArchive.self,
            CompletedOutcomeContributionArchive.self,
            CompletedOutcomePassionLinkArchive.self,
            CompletedOutcomeMeasurePointArchive.self,
            FulfillmentCategoryScoreSnapshot.self,
            PassionScoreSnapshot.self,
            configurations: config
        )
        let context = ModelContext(container)
        let categoryID = UUID()
        context.insert(Fulfillment(category_id: categoryID, category: "Mind & Meaning", category_identitiy: "", category_vision: "", category_purpose: ""))
        try context.save()
        #expect((try context.fetch(FetchDescriptor<Fulfillment>())).count == 1)
    }
}
