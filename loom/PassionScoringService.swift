import Foundation
import SwiftData

enum PassionType: String, CaseIterable, Codable, Identifiable, Sendable {
    case love = "Love"
    case vows = "Vows"
    case thrill = "Thrill"
    case hate = "Hate"

    var id: String { rawValue }
}

@Model
final class PassionScoreSnapshot {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var monthPassionKey: String

    var monthStartDate: Date
    var passionTypeRaw: String

    var score: Double
    var evidence: Double
    var evidenceStable: Double
    var momentum: Double

    var structure: Double
    var actionCoverage: Double
    var carryoverPenalty: Double
    var littleWinsCoverage: Double
    var outcomeCoverage: Double?
    var consistency: Double

    var targetScore: Double
    var emaTarget: Double

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = .init(),
        monthStartDate: Date,
        passionType: PassionType,
        score: Double,
        evidence: Double,
        evidenceStable: Double,
        momentum: Double,
        structure: Double,
        actionCoverage: Double,
        carryoverPenalty: Double,
        littleWinsCoverage: Double,
        outcomeCoverage: Double?,
        consistency: Double,
        targetScore: Double,
        emaTarget: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.monthStartDate = monthStartDate
        self.passionTypeRaw = passionType.rawValue
        self.monthPassionKey = PassionScoreSnapshot.makeKey(monthStartDate: monthStartDate, passionType: passionType)
        self.score = score
        self.evidence = evidence
        self.evidenceStable = evidenceStable
        self.momentum = momentum
        self.structure = structure
        self.actionCoverage = actionCoverage
        self.carryoverPenalty = carryoverPenalty
        self.littleWinsCoverage = littleWinsCoverage
        self.outcomeCoverage = outcomeCoverage
        self.consistency = consistency
        self.targetScore = targetScore
        self.emaTarget = emaTarget
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    var passionType: PassionType {
        get { PassionType(rawValue: passionTypeRaw) ?? .love }
        set {
            passionTypeRaw = newValue.rawValue
            monthPassionKey = PassionScoreSnapshot.makeKey(monthStartDate: monthStartDate, passionType: newValue)
        }
    }

    static func makeKey(monthStartDate: Date, passionType: PassionType) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return "\(formatter.string(from: monthStartDate))|\(passionType.rawValue)"
    }
}

struct PassionMonthWindow: Equatable, Sendable {
    let monthStart: Date
    let monthEnd: Date
}

struct PassionBlockSignal: Sendable {
    var blockCompleted: Bool
    var actionCompletionRate: Double
    var carryoverRate: Double
}

struct PassionOutcomeSignal: Sendable {
    enum NonMeasurableAnswer: String, Codable, Sendable {
        case regressedSignificantly
        case regressedSlightly
        case partiallyAchieved
        case fullyAchieved
        case overachieved
    }

    var id: UUID
    var isMeasurable: Bool

    var startDate: Date
    var endDate: Date
    var completionDate: Date?

    var startValue: Double?
    var targetValue: Double?
    var actualValueAtEvaluation: Double?
    var originalDurationDays: Double?
    var totalDaysPushed: Double?
    var pushCount: Int?

    var nonMeasurableAnswer: NonMeasurableAnswer?
}

struct PassionMonthlySignals: Sendable {
    var passionItemCount: Int = 0
    var fulfillmentLinkCount: Int = 0

    var blocks: [PassionBlockSignal] = []

    var littleWinsCompletedCount: Int = 0
    var littleWinsScheduledCount: Int = 0

    var outcomes: [PassionOutcomeSignal] = []
    var vacationCredit: Double = 0

    var isEmptyForBootstrap: Bool {
        passionItemCount == 0 &&
        fulfillmentLinkCount == 0 &&
        blocks.isEmpty &&
        littleWinsCompletedCount == 0 &&
        littleWinsScheduledCount == 0 &&
        outcomes.isEmpty &&
        vacationCredit <= 0
    }
}

struct PassionScoreBreakdown: Sendable, Equatable {
    var structure: Double
    var actionCoverage: Double
    var carryoverPenalty: Double
    var littleWinsCoverage: Double
    var outcomeCoverage: Double?
    var consistency: Double
    var evidence: Double
    var evidenceStable: Double
    var targetScore: Double
    var emaTarget: Double
    var momentum: Double
}

struct PassionScoreComputationResult: Sendable, Equatable {
    var score: Double
    var breakdown: PassionScoreBreakdown
}

enum PassionScoringMath {
    static func monthWindow(for anyDate: Date, calendar: Calendar = .current) -> PassionMonthWindow {
        let start = calendar.date(from: calendar.dateComponents([.year, .month], from: anyDate)) ?? anyDate
        let end = calendar.date(byAdding: .month, value: 1, to: start) ?? start
        return PassionMonthWindow(monthStart: start, monthEnd: end)
    }

    static func clamped01(_ value: Double) -> Double {
        min(1, max(0, value))
    }

    static func clamp(_ value: Double, min minValue: Double, max maxValue: Double) -> Double {
        Swift.min(maxValue, Swift.max(minValue, value))
    }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func measurableOnTrackScore(
        startValue: Double,
        targetValue: Double,
        actualValue: Double,
        startDate: Date,
        endDate: Date,
        evaluationDate: Date,
        toleranceFraction: Double = 0.20
    ) -> Double {
        let totalRange = targetValue - startValue
        if abs(totalRange) < 0.000_001 { return 0.5 }

        let totalDuration = max(1.0, endDate.timeIntervalSince(startDate))
        let elapsed = clamp(evaluationDate.timeIntervalSince(startDate), min: 0, max: totalDuration)
        let progressFraction = elapsed / totalDuration
        let expectedValue = startValue + (totalRange * progressFraction)

        let toleranceBand = max(abs(totalRange) * toleranceFraction, 0.000_001)
        let normalizedDelta = clamp((actualValue - expectedValue) / toleranceBand, min: -1, max: 1)
        return clamped01((normalizedDelta + 1) / 2)
    }

    static func goalPushPenalty(pushCount: Int, totalDaysPushed: Double, originalDurationDays: Double) -> Double {
        let safeOriginal = max(1.0, originalDurationDays)
        let pushRatio = max(0, totalDaysPushed) / safeOriginal
        let penalty = 0.15 * Double(max(0, pushCount)) + 0.6 * max(0, pushRatio)
        return clamp(penalty, min: 0, max: 0.6)
    }

    static func earlyLateBonus(plannedEndDate: Date, actualCompletionDate: Date?) -> Double {
        guard let actualCompletionDate else { return 0 }
        let dayDelta = actualCompletionDate.timeIntervalSince(plannedEndDate) / 86_400.0
        let absDays = abs(dayDelta)
        let normalized = clamp(absDays / 30.0, min: 0, max: 1)
        let magnitude = 0.1 + (0.1 * normalized)
        return dayDelta < 0 ? magnitude : (dayDelta > 0 ? -magnitude : 0)
    }

    static func questionnaireScore(_ answer: PassionOutcomeSignal.NonMeasurableAnswer) -> Double {
        switch answer {
        case .regressedSignificantly: return 0.0
        case .regressedSlightly: return 0.25
        case .partiallyAchieved: return 0.5
        case .fullyAchieved: return 0.8
        case .overachieved: return 1.0
        }
    }

    static func normalizedVolatility(_ values: [Double], scale: Double = 0.35) -> Double {
        guard values.count >= 2 else { return 0 }
        let meanValue = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { partial, v in
            let d = v - meanValue
            return partial + d * d
        } / Double(values.count)
        let stddev = sqrt(variance)
        return clamped01(stddev / max(0.000_001, scale))
    }

    static func consistency(lastEvidenceValues: [Double]) -> Double {
        1.0 - normalizedVolatility(lastEvidenceValues)
    }

    static func emaTarget(alpha: Double = 0.30, target: Double, previousEMA: Double) -> Double {
        (alpha * target) + ((1 - alpha) * previousEMA)
    }

    static func scoreUpdate(scorePrev: Double, emaTarget: Double, maxDelta: Double = 1.0) -> Double {
        let proposedDelta = emaTarget - scorePrev
        let clampedDelta = clamp(proposedDelta, min: -maxDelta, max: maxDelta)
        return clamp(scorePrev + clampedDelta, min: 0, max: 4)
    }

    static func discretizeHalfStep(_ value: Double) -> Double {
        (value * 2).rounded() / 2
    }

    static func normalizedSlopeMomentum(values: [Double], slopeScale: Double = 0.12) -> Double {
        guard values.count >= 2 else { return 0 }
        let n = Double(values.count)
        let xs = Array(0..<values.count).map(Double.init)
        let meanX = xs.reduce(0, +) / n
        let meanY = values.reduce(0, +) / n

        let numerator = zip(xs, values).reduce(0.0) { partial, pair in
            let (x, y) = pair
            return partial + ((x - meanX) * (y - meanY))
        }
        let denominator = xs.reduce(0.0) { partial, x in
            partial + pow(x - meanX, 2)
        }
        guard denominator > 0 else { return 0 }
        let slope = numerator / denominator
        return clamp(slope / max(0.000_001, slopeScale), min: -1, max: 1)
    }
}

protocol PassionScoringSignalProvider {
    func monthlySignals(
        for passion: PassionType,
        window: PassionMonthWindow,
        modelContext: ModelContext
    ) throws -> PassionMonthlySignals
}

struct SwiftDataPassionScoringSignalProvider: PassionScoringSignalProvider {
    func monthlySignals(
        for passion: PassionType,
        window: PassionMonthWindow,
        modelContext: ModelContext
    ) throws -> PassionMonthlySignals {
        let passions = try modelContext.fetch(FetchDescriptor<Passion>())
        let passionJoins = try modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())
        let fulfillments = try modelContext.fetch(FetchDescriptor<Fulfillment>())
        let littleWins = try modelContext.fetch(FetchDescriptor<FulfillmentFocus>())
        let littleWinsCompletions = try modelContext.fetch(FetchDescriptor<LittleWinsDailyCompletion>())

        let reflectionArchives = try modelContext.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())
        let reflectionActions = try modelContext.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())

        let outcomes = try modelContext.fetch(FetchDescriptor<Outcomes>())
        let outcomeMeasures = try modelContext.fetch(FetchDescriptor<OutcomesMeasure>())
        let outcomeMeasureEntries = try modelContext.fetch(FetchDescriptor<OutcomesMeasureEntry>())
        let outcomeEvents = try modelContext.fetch(FetchDescriptor<OutcomeAnalyticsEvent>())

        let completedOutcomes = try modelContext.fetch(FetchDescriptor<CompletedOutcomeArchive>())
        let completedOutcomePassionLinks = try modelContext.fetch(FetchDescriptor<CompletedOutcomePassionLinkArchive>())
        let completedOutcomeMeasurePoints = try modelContext.fetch(FetchDescriptor<CompletedOutcomeMeasurePointArchive>())
        let vacationArchives = try modelContext.fetch(FetchDescriptor<VacationModeArchive>())

        let emotionKey = emotionRaw(for: passion)
        let passionItems = passions.filter { normalizeEmotion($0.emotion) == emotionKey }
        let passionItemIDs = Set(passionItems.map(\.passion_id))
        let linkedJoins = passionJoins.filter { passionItemIDs.contains($0.passion_id) }
        let linkedCategoryIDs = Set(linkedJoins.map(\.category_id))

        let linkedFulfillments = fulfillments.filter { linkedCategoryIDs.contains($0.category_id) }
        let linkedCategoryNames = Set(linkedFulfillments.map { normalizedCategory($0.category) })
        let linkedLittleWinsByCategory = littleWins.filter { linkedCategoryIDs.contains($0.category_id) }
        let littleWinPassionLinks = LittleWinsPassionsStore.allLinks()
        let explicitlyMappedLittleWinIDs = Set(littleWinPassionLinks.keys)
        let explicitlyMappedLittleWinIDsForPassion = Set(
            littleWinPassionLinks.compactMap { focusID, linkedPassionIDs in
                Set(linkedPassionIDs).intersection(passionItemIDs).isEmpty ? nil : focusID
            }
        )
        let explicitLittleWinsForPassion = littleWins.filter { explicitlyMappedLittleWinIDsForPassion.contains($0.id) }
        let fallbackCategoryLittleWins = linkedLittleWinsByCategory.filter { !explicitlyMappedLittleWinIDs.contains($0.id) }
        let littleWinsForPassion = dedupeLittleWins(explicitLittleWinsForPassion + fallbackCategoryLittleWins)
        let littleWinsForPassionIDs = Set(littleWinsForPassion.map(\.id))

        let blockSignals = monthlyBlockSignals(
            window: window,
            linkedCategoryNames: linkedCategoryNames,
            reflectionArchives: reflectionArchives,
            reflectionActions: reflectionActions
        )

        let littleWinsCompletedCount = littleWinsCompletions.filter { row in
            littleWinsForPassionIDs.contains(row.focusId) &&
            row.completedAt >= window.monthStart && row.completedAt < window.monthEnd
        }.count

        let littleWinsScheduledCount = monthlyScheduledLittleWinsCount(
            window: window,
            littleWins: littleWinsForPassion
        )

        let outcomeSignals = monthlyOutcomeSignals(
            passion: passion,
            window: window,
            linkedCategoryNames: linkedCategoryNames,
            outcomes: outcomes,
            outcomeMeasures: outcomeMeasures,
            outcomeMeasureEntries: outcomeMeasureEntries,
            outcomeEvents: outcomeEvents,
            completedOutcomes: completedOutcomes,
            completedOutcomePassionLinks: completedOutcomePassionLinks,
            completedOutcomeMeasurePoints: completedOutcomeMeasurePoints,
            blockSignals: blockSignals,
            littleWinsCompletedCount: littleWinsCompletedCount,
            littleWinsScheduledCount: littleWinsScheduledCount
        )

        let vacationCredit = monthlyVacationCredit(
            passion: passion,
            window: window,
            vacationArchives: vacationArchives
        )

        return PassionMonthlySignals(
            passionItemCount: passionItems.count,
            fulfillmentLinkCount: linkedJoins.count,
            blocks: blockSignals,
            littleWinsCompletedCount: littleWinsCompletedCount,
            littleWinsScheduledCount: littleWinsScheduledCount,
            outcomes: outcomeSignals,
            vacationCredit: vacationCredit
        )
    }

    private func monthlyVacationCredit(
        passion: PassionType,
        window: PassionMonthWindow,
        vacationArchives: [VacationModeArchive]
    ) -> Double {
        struct VacationPassionSnapshot: Decodable {
            let passionID: UUID
            let emotion: String
            let passion: String
        }

        let cal = Calendar.current
        let targetEmotion = emotionRaw(for: passion)
        let relevantArchives = vacationArchives.filter { archive in
            archive.endedAt >= window.monthStart && archive.endedAt < window.monthEnd
        }

        let credits: [Double] = relevantArchives.compactMap { archive in
            let start = cal.startOfDay(for: archive.startDate)
            let end = cal.startOfDay(for: archive.returnDate)
            let daySpan = max(0, cal.dateComponents([.day], from: start, to: end).day ?? 0)
            let durationDays = daySpan + 1
            guard durationDays > 1 else { return nil }

            guard let data = archive.passionSnapshotsJSON.data(using: .utf8),
                  let snapshots = try? JSONDecoder().decode([VacationPassionSnapshot].self, from: data),
                  snapshots.contains(where: { normalizeEmotion($0.emotion) == targetEmotion }) else {
                return nil
            }

            // Positive-only bonus with saturation by duration; does not reward raw volume.
            return PassionScoringMath.clamped01(Double(durationDays) / 14.0)
        }

        return PassionScoringMath.mean(credits) ?? 0
    }

    private func monthlyBlockSignals(
        window: PassionMonthWindow,
        linkedCategoryNames: Set<String>,
        reflectionArchives: [ActionBlocksReflectionArchive],
        reflectionActions: [ActionBlocksReflectionArchiveAction]
    ) -> [PassionBlockSignal] {
        guard !linkedCategoryNames.isEmpty else { return [] }
        let archiveIDsInMonth = Set(
            reflectionArchives
                .filter { $0.completedAt >= window.monthStart && $0.completedAt < window.monthEnd }
                .map(\.id)
        )
        guard !archiveIDsInMonth.isEmpty else { return [] }

        let relevantActions = reflectionActions.filter {
            archiveIDsInMonth.contains($0.archiveId) &&
            linkedCategoryNames.contains(normalizedCategory($0.chunkCategory))
        }

        let grouped = Dictionary(grouping: relevantActions) { row in
            "\(row.archiveId.uuidString)|\(row.plannedChunkId.uuidString)"
        }

        return grouped.values.compactMap { rows in
            let total = rows.count
            guard total > 0 else { return nil }
            let statuses = rows.map { ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction }
            let completedCount = statuses.filter { $0 == .done || $0 == .notNeeded }.count
            let carryCount = statuses.filter { $0 == .carriedToCapture }.count
            return PassionBlockSignal(
                blockCompleted: true,
                actionCompletionRate: Double(completedCount) / Double(total),
                carryoverRate: Double(carryCount) / Double(total)
            )
        }
    }

    private func monthlyScheduledLittleWinsCount(
        window: PassionMonthWindow,
        littleWins: [FulfillmentFocus]
    ) -> Int {
        guard !littleWins.isEmpty else { return 0 }
        let cal = Calendar.current
        var day = cal.startOfDay(for: window.monthStart)
        let end = window.monthEnd
        var total = 0
        while day < end {
            for focus in littleWins {
                let rule = LittleWinsScheduleStore.rule(for: focus.id)
                if isLittleWinActive(on: day, rule: rule, calendar: cal) {
                    total += 1
                }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    private func dedupeLittleWins(_ rows: [FulfillmentFocus]) -> [FulfillmentFocus] {
        var seen = Set<UUID>()
        return rows.filter { seen.insert($0.id).inserted }
    }

    private func monthlyOutcomeSignals(
        passion: PassionType,
        window: PassionMonthWindow,
        linkedCategoryNames: Set<String>,
        outcomes: [Outcomes],
        outcomeMeasures: [OutcomesMeasure],
        outcomeMeasureEntries: [OutcomesMeasureEntry],
        outcomeEvents: [OutcomeAnalyticsEvent],
        completedOutcomes: [CompletedOutcomeArchive],
        completedOutcomePassionLinks: [CompletedOutcomePassionLinkArchive],
        completedOutcomeMeasurePoints: [CompletedOutcomeMeasurePointArchive],
        blockSignals: [PassionBlockSignal],
        littleWinsCompletedCount: Int,
        littleWinsScheduledCount: Int
    ) -> [PassionOutcomeSignal] {
        var signals: [PassionOutcomeSignal] = []

        let measuresByOutcome = Dictionary(uniqueKeysWithValues: outcomeMeasures.map { ($0.outcome_id, $0) })
        let entriesByOutcome = Dictionary(grouping: outcomeMeasureEntries, by: \.outcome_id)
        let eventsByOutcome = Dictionary(grouping: outcomeEvents, by: \.outcome_id)

        for outcome in outcomes {
            let overlapsMonth = outcome.start < window.monthEnd && outcome.end >= window.monthStart
            guard overlapsMonth else { continue }
            guard linkedCategoryNames.contains(normalizedCategory(outcome.category)) else { continue }

            let isMeasurable = (outcome.format != nil) || measuresByOutcome[outcome.outcome_id] != nil
            if !isMeasurable { continue } // no questionnaire until completion

            let measure = measuresByOutcome[outcome.outcome_id]
            let sortedEntries = (entriesByOutcome[outcome.outcome_id] ?? []).sorted { $0.measuredAt < $1.measuredAt }
            let lastEntryAtOrBeforeMonthEnd = sortedEntries.last { $0.measuredAt < window.monthEnd }
            let firstEntry = sortedEntries.first

            guard let target = measure?.measure_amt ?? lastEntryAtOrBeforeMonthEnd?.measure_amt,
                  let actual = lastEntryAtOrBeforeMonthEnd?.measure ?? measure?.measure else { continue }

            let originalDurationDays = estimatedOriginalDurationDays(
                outcome: outcome,
                events: eventsByOutcome[outcome.outcome_id] ?? [],
                upperBound: window.monthEnd
            )
            let (pushCount, pushedDays) = targetPushStats(
                events: eventsByOutcome[outcome.outcome_id] ?? [],
                upperBound: window.monthEnd
            )

            signals.append(
                PassionOutcomeSignal(
                    id: outcome.outcome_id,
                    isMeasurable: true,
                    startDate: outcome.start,
                    endDate: outcome.end,
                    completionDate: nil,
                    startValue: firstEntry?.measure ?? 0,
                    targetValue: target,
                    actualValueAtEvaluation: actual,
                    originalDurationDays: originalDurationDays,
                    totalDaysPushed: pushedDays,
                    pushCount: pushCount,
                    nonMeasurableAnswer: nil
                )
            )
        }

        let pointsByCompletedArchive = Dictionary(grouping: completedOutcomeMeasurePoints, by: \.completedOutcomeArchiveId)
        for archive in completedOutcomes where archive.completedAt >= window.monthStart && archive.completedAt < window.monthEnd {
            let taggedPassionMatch = completedOutcomeSupportsPassion(archiveID: archive.id, passion: passion)
                || completedOutcomePassionLinks.contains {
                    $0.completedOutcomeArchiveId == archive.id &&
                    normalizeEmotion($0.emotionSnapshot) == emotionRaw(for: passion)
                }
            let categoryMatch = linkedCategoryNames.contains(normalizedCategory(archive.category))
            guard taggedPassionMatch || categoryMatch else { continue }

            if archive.isMeasurable {
                let points = (pointsByCompletedArchive[archive.id] ?? []).sorted { $0.measuredAt < $1.measuredAt }
                let firstPoint = points.first
                let lastPoint = points.last
                let (pushCount, pushedDays) = targetPushStats(
                    events: eventsByOutcome[archive.originalOutcomeId] ?? [],
                    upperBound: archive.completedAt
                )
                let originalDurationDays = estimatedOriginalDurationDaysFromArchive(
                    archive: archive,
                    events: eventsByOutcome[archive.originalOutcomeId] ?? [],
                    upperBound: archive.completedAt
                )

                signals.append(
                    PassionOutcomeSignal(
                        id: archive.id,
                        isMeasurable: true,
                        startDate: archive.start,
                        endDate: archive.end,
                        completionDate: archive.completedAt,
                        startValue: firstPoint?.measure ?? 0,
                        targetValue: archive.goalValue ?? lastPoint?.goal,
                        actualValueAtEvaluation: archive.finalValue ?? lastPoint?.measure,
                        originalDurationDays: originalDurationDays,
                        totalDaysPushed: pushedDays,
                        pushCount: pushCount,
                        nonMeasurableAnswer: nil
                    )
                )
            } else {
                let densityActions = blockSignals.isEmpty ? 0 : blockSignals.map {
                    (Double($0.blockCompleted ? 1 : 0) * 0.6) + (PassionScoringMath.clamped01($0.actionCompletionRate) * 0.4)
                }.reduce(0, +) / Double(max(1, blockSignals.count))
                let densityLittleWins = PassionScoringMath.clamped01(
                    Double(littleWinsCompletedCount) / Double(max(1, littleWinsScheduledCount))
                )
                _ = densityActions
                _ = densityLittleWins

                signals.append(
                    PassionOutcomeSignal(
                        id: archive.id,
                        isMeasurable: false,
                        startDate: archive.start,
                        endDate: archive.end,
                        completionDate: archive.completedAt,
                        startValue: nil,
                        targetValue: nil,
                        actualValueAtEvaluation: nil,
                        originalDurationDays: nil,
                        totalDaysPushed: nil,
                        pushCount: nil,
                        nonMeasurableAnswer: mapSuccessLevelToAnswer(archive.successLevel)
                    )
                )
            }
        }

        return signals
    }

    private func targetPushStats(events: [OutcomeAnalyticsEvent], upperBound: Date) -> (count: Int, totalDaysPushed: Double) {
        let pushes = events.filter { event in
            event.eventType == "target_changed" &&
            event.occurredAt < upperBound &&
            event.oldTargetDate != nil &&
            event.newTargetDate != nil
        }
        let totalDays = pushes.reduce(0.0) { partial, event in
            guard let oldDate = event.oldTargetDate, let newDate = event.newTargetDate else { return partial }
            let delta = newDate.timeIntervalSince(oldDate) / 86_400.0
            return partial + max(0, delta)
        }
        return (pushes.count, totalDays)
    }

    private func estimatedOriginalDurationDays(outcome: Outcomes, events: [OutcomeAnalyticsEvent], upperBound: Date) -> Double {
        let relevant = events.filter {
            $0.eventType == "target_changed" && $0.occurredAt < upperBound && $0.oldTargetDate != nil && $0.newTargetDate != nil
        }
        let earliestOld = relevant.compactMap(\.oldTargetDate).min()
        let originalEnd = earliestOld ?? outcome.end
        return max(1, originalEnd.timeIntervalSince(outcome.start) / 86_400.0)
    }

    private func estimatedOriginalDurationDaysFromArchive(archive: CompletedOutcomeArchive, events: [OutcomeAnalyticsEvent], upperBound: Date) -> Double {
        let relevant = events.filter {
            $0.eventType == "target_changed" && $0.occurredAt < upperBound && $0.oldTargetDate != nil && $0.newTargetDate != nil
        }
        let earliestOld = relevant.compactMap(\.oldTargetDate).min()
        let originalEnd = earliestOld ?? archive.end
        return max(1, originalEnd.timeIntervalSince(archive.start) / 86_400.0)
    }

    private func completedOutcomeSupportsPassion(archiveID: UUID, passion: PassionType) -> Bool {
        // Legacy fallback for pre-SwiftData archived links.
        struct LegacyPassionSnapshot: Codable {
            let passionID: UUID
            let emotion: String
            let passion: String
        }
        let emotion = emotionRaw(for: passion)
        guard let data = UserDefaults.standard.data(forKey: "completed_outcome_passions_v1"),
              let decoded = try? JSONDecoder().decode([String: [LegacyPassionSnapshot]].self, from: data),
              let rows = decoded[archiveID.uuidString] else {
            return false
        }
        return rows.contains { normalizeEmotion($0.emotion) == emotion }
    }

    private func mapSuccessLevelToAnswer(_ successLevel: Int?) -> PassionOutcomeSignal.NonMeasurableAnswer? {
        switch successLevel {
        case 1: return .regressedSignificantly
        case 2: return .regressedSlightly
        case 3: return .partiallyAchieved
        case 4: return .fullyAchieved
        case 5: return .overachieved
        default: return nil
        }
    }

    private func isLittleWinActive(on date: Date, rule: LittleWinsScheduleRule, calendar: Calendar) -> Bool {
        if rule.canCompleteAnyDay { return true }
        let weekday = calendar.component(.weekday, from: date) // 1...7 Sun...Sat
        let bit = 1 << (weekday - 1)
        return (rule.activeWeekdayMask & bit) != 0
    }

    private func emotionRaw(for passion: PassionType) -> String {
        switch passion {
        case .love: return "love"
        case .vows: return "vows"
        case .thrill: return "thrill"
        case .hate: return "just"
        }
    }

    private func normalizeEmotion(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func normalizedCategory(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

struct PassionScoringService {
    struct Config {
        var alpha: Double = 0.30
        var itemSaturationCount: Double = 8
        var linkSaturationCount: Double = 6
        var maxMonthlyDelta: Double = 1.0
        var discretizeToHalfSteps: Bool = true
    }

    let provider: PassionScoringSignalProvider
    let config: Config
    let calendar: Calendar

    init(
        provider: PassionScoringSignalProvider = SwiftDataPassionScoringSignalProvider(),
        config: Config = .init(),
        calendar: Calendar = .current
    ) {
        self.provider = provider
        self.config = config
        self.calendar = calendar
    }

    @discardableResult
    func computeAndPersistSnapshots(
        for monthStartDate: Date,
        in modelContext: ModelContext
    ) throws -> [PassionScoreSnapshot] {
        let window = PassionScoringMath.monthWindow(for: monthStartDate, calendar: calendar)
        let isVacationMonth = VacationModeStore.overlappingConfig(start: window.monthStart, endExclusive: window.monthEnd) != nil
        var persisted: [PassionScoreSnapshot] = []

        for passion in PassionType.allCases {
            let signals = try provider.monthlySignals(for: passion, window: window, modelContext: modelContext)
            let history = try fetchSnapshots(for: passion, before: window.monthStart, in: modelContext)
            let result = isVacationMonth
                ? frozenVacationMonthlyResult(history: history)
                : computeMonthlyScore(monthStartDate: window.monthStart, passion: passion, signals: signals, history: history)
            let snapshot = try upsertSnapshot(
                monthStartDate: window.monthStart,
                passion: passion,
                result: result,
                in: modelContext
            )
            persisted.append(snapshot)
        }

        try modelContext.save()
        return persisted
    }

    @discardableResult
    func computeAndBackfillMonthlySnapshots(in modelContext: ModelContext, now: Date = .now, maxLookbackMonths: Int = 60) throws -> [PassionScoreSnapshot] {
        let currentMonthStart = PassionScoringMath.monthWindow(for: now, calendar: calendar).monthStart
        let earliestCandidate = try earliestRelevantDate(in: modelContext) ?? currentMonthStart
        let earliestMonthStart = PassionScoringMath.monthWindow(for: earliestCandidate, calendar: calendar).monthStart
        let boundedStart = calendar.date(byAdding: .month, value: -(maxLookbackMonths - 1), to: currentMonthStart) ?? earliestMonthStart
        let startMonth = max(earliestMonthStart, boundedStart)
        let existingSnapshots = try modelContext.fetch(FetchDescriptor<PassionScoreSnapshot>())
        let existingMonthStarts = Set(existingSnapshots.map { calendar.startOfDay(for: $0.monthStartDate) })

        var all: [PassionScoreSnapshot] = []
        var cursor = startMonth
        while cursor <= currentMonthStart {
            let normalizedCursor = calendar.startOfDay(for: cursor)
            let shouldCompute = normalizedCursor == calendar.startOfDay(for: currentMonthStart) || !existingMonthStarts.contains(normalizedCursor)
            if shouldCompute {
                let rows = try computeAndPersistSnapshots(for: cursor, in: modelContext)
                all.append(contentsOf: rows)
            }
            guard let next = calendar.date(byAdding: .month, value: 1, to: cursor) else { break }
            cursor = next
        }
        return all
    }

    func computeMonthlyScore(
        monthStartDate: Date,
        passion: PassionType,
        signals: PassionMonthlySignals,
        history: [PassionScoreSnapshot]
    ) -> PassionScoreComputationResult {
        let sortedHistory = history.sorted { $0.monthStartDate < $1.monthStartDate }
        let prev = sortedHistory.last

        if prev == nil && signals.isEmptyForBootstrap {
            let neutralScore = 2.0
            let breakdown = PassionScoreBreakdown(
                structure: 0.0,
                actionCoverage: 0.0,
                carryoverPenalty: 0.0,
                littleWinsCoverage: 0.0,
                outcomeCoverage: nil,
                consistency: 1.0,
                evidence: 0.5,
                evidenceStable: 0.5,
                targetScore: 2.0,
                emaTarget: 2.0,
                momentum: 0.0
            )
            _ = monthStartDate
            _ = passion
            return PassionScoreComputationResult(score: neutralScore, breakdown: breakdown)
        }

        let structure = computeStructure(signals)
        let actionCoverage = computeActionCoverage(signals.blocks)
        let carryoverPenalty = computeCarryoverPenalty(signals.blocks)
        let littleWinsCoverage = computeLittleWinsCoverage(signals)
        let outcomeCoverage = computeOutcomeCoverage(signals: signals, monthStartDate: monthStartDate)

        let evidence = combineEvidence(
            structure: structure,
            actionCoverage: actionCoverage,
            carryoverPenalty: carryoverPenalty,
            littleWinsCoverage: littleWinsCoverage,
            outcomeCoverage: outcomeCoverage,
            vacationCredit: signals.vacationCredit
        )

        let recentEvidence = Array(sortedHistory.suffix(3).map(\.evidenceStable)) + [evidence]
        let consistency = PassionScoringMath.consistency(lastEvidenceValues: recentEvidence)
        let evidenceStable = (0.85 * evidence) + (0.15 * (evidence * consistency))

        var targetScore = 4.0 * evidenceStable
        if config.discretizeToHalfSteps {
            targetScore = PassionScoringMath.discretizeHalfStep(targetScore)
        }
        targetScore = PassionScoringMath.clamp(targetScore, min: 0, max: 4)

        let scorePrev = prev?.score ?? 2.0
        let emaPrev = prev?.emaTarget ?? 2.0
        let emaTarget = PassionScoringMath.emaTarget(alpha: config.alpha, target: targetScore, previousEMA: emaPrev)
        let score = PassionScoringMath.scoreUpdate(scorePrev: scorePrev, emaTarget: emaTarget, maxDelta: config.maxMonthlyDelta)

        let momentumEvidenceSeries = Array(sortedHistory.suffix(3).map(\.evidenceStable)) + [evidenceStable]
        let momentum = PassionScoringMath.normalizedSlopeMomentum(values: momentumEvidenceSeries)

        let breakdown = PassionScoreBreakdown(
            structure: structure,
            actionCoverage: actionCoverage,
            carryoverPenalty: carryoverPenalty,
            littleWinsCoverage: littleWinsCoverage,
            outcomeCoverage: outcomeCoverage,
            consistency: consistency,
            evidence: evidence,
            evidenceStable: evidenceStable,
            targetScore: targetScore,
            emaTarget: emaTarget,
            momentum: momentum
        )
        return PassionScoreComputationResult(score: score, breakdown: breakdown)
    }

    private func frozenVacationMonthlyResult(history: [PassionScoreSnapshot]) -> PassionScoreComputationResult {
        let sortedHistory = history.sorted { $0.monthStartDate < $1.monthStartDate }
        if let prev = sortedHistory.last {
            return PassionScoreComputationResult(
                score: prev.score,
                breakdown: .init(
                    structure: prev.structure,
                    actionCoverage: prev.actionCoverage,
                    carryoverPenalty: prev.carryoverPenalty,
                    littleWinsCoverage: prev.littleWinsCoverage,
                    outcomeCoverage: prev.outcomeCoverage,
                    consistency: prev.consistency,
                    evidence: prev.evidence,
                    evidenceStable: prev.evidenceStable,
                    targetScore: prev.targetScore,
                    emaTarget: prev.emaTarget,
                    momentum: 0
                )
            )
        }
        return PassionScoreComputationResult(
            score: 2.0,
            breakdown: .init(
                structure: 0,
                actionCoverage: 0,
                carryoverPenalty: 0,
                littleWinsCoverage: 0,
                outcomeCoverage: nil,
                consistency: 1,
                evidence: 0.5,
                evidenceStable: 0.5,
                targetScore: 2.0,
                emaTarget: 2.0,
                momentum: 0
            )
        )
    }

    func computeStructure(_ signals: PassionMonthlySignals) -> Double {
        let itemScore = PassionScoringMath.clamped01(Double(signals.passionItemCount) / max(1, config.itemSaturationCount))
        let linkScore = PassionScoringMath.clamped01(Double(signals.fulfillmentLinkCount) / max(1, config.linkSaturationCount))
        return PassionScoringMath.clamped01((0.6 * itemScore) + (0.4 * linkScore))
    }

    func computeActionCoverage(_ blocks: [PassionBlockSignal]) -> Double {
        let perBlock = blocks.map { block in
            let completed = block.blockCompleted ? 1.0 : 0.0
            let completionRate = PassionScoringMath.clamped01(block.actionCompletionRate)
            return PassionScoringMath.clamped01((0.6 * completed) + (0.4 * completionRate))
        }
        return PassionScoringMath.mean(perBlock) ?? 0.0
    }

    func computeCarryoverPenalty(_ blocks: [PassionBlockSignal]) -> Double {
        let values = blocks.map { PassionScoringMath.clamped01($0.carryoverRate) }
        return PassionScoringMath.mean(values) ?? 0.0
    }

    func computeLittleWinsCoverage(_ signals: PassionMonthlySignals) -> Double {
        let denom = max(1, signals.littleWinsScheduledCount)
        return PassionScoringMath.clamped01(Double(max(0, signals.littleWinsCompletedCount)) / Double(denom))
    }

    func computeOutcomeCoverage(signals: PassionMonthlySignals, monthStartDate: Date) -> Double? {
        let monthWindow = PassionScoringMath.monthWindow(for: monthStartDate, calendar: calendar)
        let densityActions = computeActionCoverage(signals.blocks)
        let densityLittleWins = computeLittleWinsCoverage(signals)

        let scores = signals.outcomes.compactMap { outcome -> Double? in
            outcomeScore(outcome, monthWindow: monthWindow, densityActions: densityActions, densityLittleWins: densityLittleWins)
        }
        return PassionScoringMath.mean(scores)
    }

    func outcomeScore(
        _ outcome: PassionOutcomeSignal,
        monthWindow: PassionMonthWindow,
        densityActions: Double,
        densityLittleWins: Double
    ) -> Double? {
        if outcome.isMeasurable {
            guard
                let startValue = outcome.startValue,
                let targetValue = outcome.targetValue,
                let actualValue = outcome.actualValueAtEvaluation
            else { return nil }

            let evalDate = outcome.completionDate.map { min($0, monthWindow.monthEnd) } ?? min(outcome.endDate, monthWindow.monthEnd)
            let onTrack = PassionScoringMath.measurableOnTrackScore(
                startValue: startValue,
                targetValue: targetValue,
                actualValue: actualValue,
                startDate: outcome.startDate,
                endDate: outcome.endDate,
                evaluationDate: evalDate
            )
            let penalty = PassionScoringMath.goalPushPenalty(
                pushCount: outcome.pushCount ?? 0,
                totalDaysPushed: outcome.totalDaysPushed ?? 0,
                originalDurationDays: outcome.originalDurationDays ?? max(1, outcome.endDate.timeIntervalSince(outcome.startDate) / 86_400)
            )
            let bonus = PassionScoringMath.earlyLateBonus(plannedEndDate: outcome.endDate, actualCompletionDate: outcome.completionDate)
            return PassionScoringMath.clamped01(onTrack - penalty + bonus)
        }

        guard let answer = outcome.nonMeasurableAnswer else { return nil }
        let questionnaire = PassionScoringMath.questionnaireScore(answer)
        let density = PassionScoringMath.clamped01((0.5 * densityActions) + (0.5 * densityLittleWins))
        return PassionScoringMath.clamped01((0.7 * questionnaire) + (0.3 * density))
    }

    func combineEvidence(
        structure: Double,
        actionCoverage: Double,
        carryoverPenalty: Double,
        littleWinsCoverage: Double,
        outcomeCoverage: Double?,
        vacationCredit: Double
    ) -> Double {
        var weights: [(Double, Double)] = []
        let structureWeight = 0.15
        let actionWeight = 0.25
        let carryoverWeight = 0.10
        let littleWinsWeight = 0.20
        let outcomeWeight = 0.30

        weights.append((structureWeight, PassionScoringMath.clamped01(structure)))
        weights.append((actionWeight, PassionScoringMath.clamped01(actionCoverage)))
        weights.append((carryoverWeight, PassionScoringMath.clamped01(1 - carryoverPenalty)))
        weights.append((littleWinsWeight, PassionScoringMath.clamped01(littleWinsCoverage)))

        if let outcomeCoverage {
            weights.append((outcomeWeight, PassionScoringMath.clamped01(outcomeCoverage)))
        } else {
            let redistTotal = actionWeight + littleWinsWeight
            let outcomeToAction = outcomeWeight * (actionWeight / redistTotal)
            let outcomeToLittleWins = outcomeWeight * (littleWinsWeight / redistTotal)
            weights[1].0 += outcomeToAction
            weights[3].0 += outcomeToLittleWins
        }

        let totalWeight = weights.reduce(0.0) { $0 + $1.0 }
        guard totalWeight > 0 else { return 0.5 }
        let weighted = weights.reduce(0.0) { partial, pair in partial + (pair.0 * pair.1) }
        let baseEvidence = PassionScoringMath.clamped01(weighted / totalWeight)
        // Vacation credit can only help (never hurt) and stays intentionally small.
        let positiveVacationBoost = 0.08 * PassionScoringMath.clamped01(vacationCredit)
        return PassionScoringMath.clamped01(max(baseEvidence, baseEvidence + positiveVacationBoost))
    }

    private func fetchSnapshots(
        for passion: PassionType,
        before monthStartDate: Date,
        in modelContext: ModelContext
    ) throws -> [PassionScoreSnapshot] {
        let all = try modelContext.fetch(FetchDescriptor<PassionScoreSnapshot>(
            sortBy: [SortDescriptor(\PassionScoreSnapshot.monthStartDate, order: .forward)]
        ))
        return all.filter { $0.passionTypeRaw == passion.rawValue && $0.monthStartDate < monthStartDate }
    }

    private func upsertSnapshot(
        monthStartDate: Date,
        passion: PassionType,
        result: PassionScoreComputationResult,
        in modelContext: ModelContext
    ) throws -> PassionScoreSnapshot {
        let key = PassionScoreSnapshot.makeKey(monthStartDate: monthStartDate, passionType: passion)
        let existing = try modelContext.fetch(FetchDescriptor<PassionScoreSnapshot>()).first { $0.monthPassionKey == key }
        let b = result.breakdown
        if let existing {
            existing.monthStartDate = monthStartDate
            existing.passionType = passion
            existing.score = result.score
            existing.evidence = b.evidence
            existing.evidenceStable = b.evidenceStable
            existing.momentum = b.momentum
            existing.structure = b.structure
            existing.actionCoverage = b.actionCoverage
            existing.carryoverPenalty = b.carryoverPenalty
            existing.littleWinsCoverage = b.littleWinsCoverage
            existing.outcomeCoverage = b.outcomeCoverage
            existing.consistency = b.consistency
            existing.targetScore = b.targetScore
            existing.emaTarget = b.emaTarget
            existing.updatedAt = .now
            return existing
        }

        let snapshot = PassionScoreSnapshot(
            monthStartDate: monthStartDate,
            passionType: passion,
            score: result.score,
            evidence: b.evidence,
            evidenceStable: b.evidenceStable,
            momentum: b.momentum,
            structure: b.structure,
            actionCoverage: b.actionCoverage,
            carryoverPenalty: b.carryoverPenalty,
            littleWinsCoverage: b.littleWinsCoverage,
            outcomeCoverage: b.outcomeCoverage,
            consistency: b.consistency,
            targetScore: b.targetScore,
            emaTarget: b.emaTarget
        )
        modelContext.insert(snapshot)
        return snapshot
    }

    private func earliestRelevantDate(in modelContext: ModelContext) throws -> Date? {
        var dates: [Date] = []
        if let d = try earliestDate(type: Passion.self, sortBy: SortDescriptor(\Passion.date, order: .forward), keyPath: \.date, in: modelContext) { dates.append(d) }
        if let d = try earliestDate(type: LittleWinsDailyCompletion.self, sortBy: SortDescriptor(\LittleWinsDailyCompletion.completedAt, order: .forward), keyPath: \.completedAt, in: modelContext) { dates.append(d) }
        if let d = try earliestDate(type: ActionBlocksReflectionArchive.self, sortBy: SortDescriptor(\ActionBlocksReflectionArchive.completedAt, order: .forward), keyPath: \.completedAt, in: modelContext) { dates.append(d) }
        if let d = try earliestDate(type: Outcomes.self, sortBy: SortDescriptor(\Outcomes.start, order: .forward), keyPath: \.start, in: modelContext) { dates.append(d) }
        if let d = try earliestDate(type: CompletedOutcomeArchive.self, sortBy: SortDescriptor(\CompletedOutcomeArchive.completedAt, order: .forward), keyPath: \.completedAt, in: modelContext) { dates.append(d) }
        if let d = try earliestDate(type: PassionScoreSnapshot.self, sortBy: SortDescriptor(\PassionScoreSnapshot.monthStartDate, order: .forward), keyPath: \.monthStartDate, in: modelContext) { dates.append(d) }
        return dates.min()
    }

    private func earliestDate<T: PersistentModel>(
        type: T.Type,
        sortBy: SortDescriptor<T>,
        keyPath: KeyPath<T, Date>,
        in modelContext: ModelContext
    ) throws -> Date? {
        _ = type
        var descriptor = FetchDescriptor<T>(sortBy: [sortBy])
        descriptor.fetchLimit = 1
        return try modelContext.fetch(descriptor).first.map { $0[keyPath: keyPath] }
    }
}
