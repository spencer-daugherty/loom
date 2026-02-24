import Foundation
import Testing
@testable import loom

struct PassionScoringServiceTests {
    private let service = PassionScoringService()
    private let calendar = Calendar.current

    @Test func maxSwingEnforcedMonthToMonth() {
        let prev = PassionScoreSnapshot(
            monthStartDate: PassionScoringMath.monthWindow(for: Date(timeIntervalSince1970: 1_700_000_000)).monthStart,
            passionType: .love,
            score: 1.0,
            evidence: 0.2,
            evidenceStable: 0.2,
            momentum: 0,
            structure: 0.2,
            actionCoverage: 0.2,
            carryoverPenalty: 0.5,
            littleWinsCoverage: 0.2,
            outcomeCoverage: nil,
            consistency: 1,
            targetScore: 1.0,
            emaTarget: 1.0
        )
        let month = calendar.date(byAdding: .month, value: 1, to: prev.monthStartDate) ?? prev.monthStartDate
        let signals = PassionMonthlySignals(
            passionItemCount: 20,
            fulfillmentLinkCount: 20,
            blocks: [.init(blockCompleted: true, actionCompletionRate: 1, carryoverRate: 0)],
            littleWinsCompletedCount: 30,
            littleWinsScheduledCount: 30,
            outcomes: [
                PassionOutcomeSignal(
                    id: UUID(),
                    isMeasurable: false,
                    startDate: month,
                    endDate: month,
                    completionDate: month,
                    startValue: nil,
                    targetValue: nil,
                    actualValueAtEvaluation: nil,
                    originalDurationDays: nil,
                    totalDaysPushed: nil,
                    pushCount: nil,
                    nonMeasurableAnswer: .overachieved
                )
            ]
        )
        let result = service.computeMonthlyScore(monthStartDate: month, passion: .love, signals: signals, history: [prev])
        #expect(result.score <= 2.0)
        #expect(abs(result.score - prev.score) <= 1.000_001)
    }

    @Test func noOutcomesPresentUsesNilAndRenormalizes() {
        let month = PassionScoringMath.monthWindow(for: .now).monthStart
        let signals = PassionMonthlySignals(
            passionItemCount: 4,
            fulfillmentLinkCount: 3,
            blocks: [.init(blockCompleted: true, actionCompletionRate: 0.75, carryoverRate: 0.1)],
            littleWinsCompletedCount: 8,
            littleWinsScheduledCount: 10,
            outcomes: []
        )
        let result = service.computeMonthlyScore(monthStartDate: month, passion: .vows, signals: signals, history: [])
        #expect(result.breakdown.outcomeCoverage == nil)
        #expect(result.breakdown.evidence > 0)
        #expect(result.score >= 0 && result.score <= 4)
    }

    @Test func volumeInvarianceForBlockAverages() {
        let month = PassionScoringMath.monthWindow(for: .now).monthStart
        let oneBlock = PassionMonthlySignals(
            passionItemCount: 5,
            fulfillmentLinkCount: 2,
            blocks: [.init(blockCompleted: true, actionCompletionRate: 0.5, carryoverRate: 0.25)],
            littleWinsCompletedCount: 5,
            littleWinsScheduledCount: 10,
            outcomes: []
        )
        let doubledVolumeSameRatios = PassionMonthlySignals(
            passionItemCount: 5,
            fulfillmentLinkCount: 2,
            blocks: [
                .init(blockCompleted: true, actionCompletionRate: 0.5, carryoverRate: 0.25),
                .init(blockCompleted: true, actionCompletionRate: 0.5, carryoverRate: 0.25)
            ],
            littleWinsCompletedCount: 10,
            littleWinsScheduledCount: 20,
            outcomes: []
        )

        let r1 = service.computeMonthlyScore(monthStartDate: month, passion: .thrill, signals: oneBlock, history: [])
        let r2 = service.computeMonthlyScore(monthStartDate: month, passion: .thrill, signals: doubledVolumeSameRatios, history: [])

        #expect(abs(r1.breakdown.actionCoverage - r2.breakdown.actionCoverage) < 0.000_001)
        #expect(abs(r1.breakdown.littleWinsCoverage - r2.breakdown.littleWinsCoverage) < 0.000_001)
        #expect(abs(r1.breakdown.evidence - r2.breakdown.evidence) < 0.000_001)
        #expect(abs(r1.score - r2.score) < 0.000_001)
    }

    @Test func stableBehaviorAcrossMonthsWithSmallChanges() {
        let baseMonth = PassionScoringMath.monthWindow(for: .now).monthStart
        var history: [PassionScoreSnapshot] = []
        var scores: [Double] = []

        for i in 0..<6 {
            let month = calendar.date(byAdding: .month, value: i, to: baseMonth) ?? baseMonth
            let signals = PassionMonthlySignals(
                passionItemCount: 6,
                fulfillmentLinkCount: 4,
                blocks: [.init(blockCompleted: true, actionCompletionRate: 0.72 + (Double(i % 2) * 0.02), carryoverRate: 0.18)],
                littleWinsCompletedCount: 14 + (i % 2),
                littleWinsScheduledCount: 20,
                outcomes: []
            )
            let result = service.computeMonthlyScore(monthStartDate: month, passion: .hate, signals: signals, history: history)
            let snapshot = PassionScoreSnapshot(
                monthStartDate: month,
                passionType: .hate,
                score: result.score,
                evidence: result.breakdown.evidence,
                evidenceStable: result.breakdown.evidenceStable,
                momentum: result.breakdown.momentum,
                structure: result.breakdown.structure,
                actionCoverage: result.breakdown.actionCoverage,
                carryoverPenalty: result.breakdown.carryoverPenalty,
                littleWinsCoverage: result.breakdown.littleWinsCoverage,
                outcomeCoverage: result.breakdown.outcomeCoverage,
                consistency: result.breakdown.consistency,
                targetScore: result.breakdown.targetScore,
                emaTarget: result.breakdown.emaTarget
            )
            history.append(snapshot)
            scores.append(result.score)
        }

        let deltas = zip(scores.dropFirst(), scores).map { abs($0.0 - $0.1) }
        #expect(deltas.allSatisfy { $0 <= 1.000_001 })
        #expect((scores.max() ?? 0) - (scores.min() ?? 0) < 2.5)
    }
}
