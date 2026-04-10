import Foundation
import SwiftData

@Model
final class FulfillmentCategoryScoreSnapshot {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var weekCategoryKey: String

    var weekStartDate: Date
    var categoryID: UUID
    var categoryTitleSnapshot: String

    var score: Double           // final displayed weekly score (1...5)
    var smoothedScore: Double   // same persisted for explainability/UI
    var targetScore: Double
    var evidence: Double        // 0...1
    var momentum: Double        // -1...1

    var structure: Double       // 0...1
    var outcomes: Double        // 0...1
    var actionBlocks: Double    // 0...1
    var carryoverPenalty: Double // 0...1
    var littleWins: Double      // 0...1
    var engagement: Double      // 0...1
    var strategicBalance: Double // 0...1
    var consistency: Double     // 0...1

    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = .init(),
        weekStartDate: Date,
        categoryID: UUID,
        categoryTitleSnapshot: String,
        score: Double,
        smoothedScore: Double,
        targetScore: Double,
        evidence: Double,
        momentum: Double,
        structure: Double,
        outcomes: Double,
        actionBlocks: Double,
        carryoverPenalty: Double,
        littleWins: Double,
        engagement: Double,
        strategicBalance: Double,
        consistency: Double,
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStartDate = weekStartDate
        self.categoryID = categoryID
        self.categoryTitleSnapshot = categoryTitleSnapshot
        self.weekCategoryKey = Self.makeKey(weekStartDate: weekStartDate, categoryID: categoryID)
        self.score = score
        self.smoothedScore = smoothedScore
        self.targetScore = targetScore
        self.evidence = evidence
        self.momentum = momentum
        self.structure = structure
        self.outcomes = outcomes
        self.actionBlocks = actionBlocks
        self.carryoverPenalty = carryoverPenalty
        self.littleWins = littleWins
        self.engagement = engagement
        self.strategicBalance = strategicBalance
        self.consistency = consistency
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    static func makeKey(weekStartDate: Date, categoryID: UUID) -> String {
        let f = DateFormatter()
        f.calendar = Calendar.current
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return "\(f.string(from: weekStartDate))|\(categoryID.uuidString)"
    }
}

struct FulfillmentWeekWindow: Equatable, Sendable {
    let weekStart: Date
    let weekEnd: Date
}

struct FulfillmentCategoryScoreBreakdown: Equatable, Sendable {
    var structure: Double
    var outcomes: Double
    var actionBlocks: Double
    var carryoverPenalty: Double
    var littleWins: Double
    var engagement: Double
    var strategicBalance: Double
    var consistency: Double
    var evidence: Double
    var targetScore: Double
    var smoothedScore: Double
    var momentum: Double
}

struct FulfillmentCategoryScoreResult: Equatable, Sendable {
    var score: Double
    var breakdown: FulfillmentCategoryScoreBreakdown
}

struct FulfillmentCategorySignals: Sendable {
    var hasVision: Bool
    var hasPurpose: Bool
    var rolesCount: Int
    var resourcesCount: Int
    var passionsLinkedCount: Int
    var littleWinsDefinedCount: Int

    var actionBlockCompletionMean: Double?
    var actionBlockCarryoverMean: Double?
    var strategicCompletionShare: Double?
    var reactiveCarryoverMean: Double?

    var littleWinsCompletedCount: Int
    var littleWinsScheduledCount: Int

    var outcomeScores: [Double]

    var engagedDaysCount: Int
}

enum FulfillmentScoringMath {
    static func weekWindow(for date: Date, calendar: Calendar = .current) -> FulfillmentWeekWindow {
        let start = calendar.date(from: calendar.dateComponents([.yearForWeekOfYear, .weekOfYear], from: date)) ?? date
        let end = calendar.date(byAdding: .day, value: 7, to: start) ?? start
        return FulfillmentWeekWindow(weekStart: start, weekEnd: end)
    }

    static func latestCompletedWeekStart(for date: Date, calendar: Calendar = .current) -> Date {
        let currentWeekStart = weekWindow(for: date, calendar: calendar).weekStart
        return calendar.date(byAdding: .day, value: -7, to: currentWeekStart) ?? currentWeekStart
    }

    static func clamp(_ value: Double, _ minValue: Double, _ maxValue: Double) -> Double {
        Swift.min(maxValue, Swift.max(minValue, value))
    }

    static func clamped01(_ value: Double) -> Double { clamp(value, 0, 1) }

    static func mean(_ values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        return values.reduce(0, +) / Double(values.count)
    }

    static func ema(alpha: Double, target: Double, previous: Double) -> Double {
        alpha * target + (1 - alpha) * previous
    }

    static func normalizedVolatility(_ values: [Double], scale: Double = 0.25) -> Double {
        guard values.count >= 2 else { return 0 }
        let m = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - m, 2) } / Double(values.count)
        let s = sqrt(variance)
        return clamped01(s / max(0.0001, scale))
    }

    static func consistency(lastEvidence: [Double]) -> Double {
        1.0 - normalizedVolatility(lastEvidence)
    }

    static func momentum(lastEvidence: [Double], slopeScale: Double = 0.10) -> Double {
        guard lastEvidence.count >= 2 else { return 0 }
        let n = Double(lastEvidence.count)
        let xs = Array(0..<lastEvidence.count).map(Double.init)
        let meanX = xs.reduce(0, +) / n
        let meanY = lastEvidence.reduce(0, +) / n
        let num = zip(xs, lastEvidence).reduce(0.0) { $0 + (($1.0 - meanX) * ($1.1 - meanY)) }
        let den = xs.reduce(0.0) { $0 + pow($1 - meanX, 2) }
        guard den > 0 else { return 0 }
        return clamp((num / den) / slopeScale, -1, 1)
    }
}

struct FulfillmentScoringService {
    struct Config {
        var emaAlpha: Double = 0.28
        var maxWeeklyDelta: Double = 1.0
    }

    let config: Config
    let calendar: Calendar

    init(config: Config = .init(), calendar: Calendar = .current) {
        self.config = config
        self.calendar = calendar
    }

    @discardableResult
    func computeAndPersistCurrentWeek(in context: ModelContext, now: Date = .now) throws -> [FulfillmentCategoryScoreSnapshot] {
        let latestCompletedWeekStart = FulfillmentScoringMath.latestCompletedWeekStart(for: now, calendar: calendar)
        return try computeAndPersist(weekStartDate: latestCompletedWeekStart, in: context)
    }

    @discardableResult
    func computeAndBackfillWeeklySnapshots(in context: ModelContext, now: Date = .now, maxLookbackWeeks: Int = 104) throws -> [FulfillmentCategoryScoreSnapshot] {
        let latestCompletedWeekStart = FulfillmentScoringMath.latestCompletedWeekStart(for: now, calendar: calendar)
        let earliestCandidate = try earliestRelevantDate(in: context) ?? latestCompletedWeekStart
        let earliestWeekStart = FulfillmentScoringMath.weekWindow(for: earliestCandidate, calendar: calendar).weekStart
        let boundedStart = calendar.date(byAdding: .day, value: -(maxLookbackWeeks - 1) * 7, to: latestCompletedWeekStart) ?? earliestWeekStart
        let startWeek = max(earliestWeekStart, boundedStart)
        guard startWeek <= latestCompletedWeekStart else { return [] }
        let existingSnapshots = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>())
        let existingWeekStarts = Set(existingSnapshots.map { calendar.startOfDay(for: $0.weekStartDate) })

        var all: [FulfillmentCategoryScoreSnapshot] = []
        var cursor = startWeek
        while cursor <= latestCompletedWeekStart {
            let normalizedCursor = calendar.startOfDay(for: cursor)
            let shouldCompute = !existingWeekStarts.contains(normalizedCursor)
            if shouldCompute {
                let rows = try computeAndPersist(weekStartDate: cursor, in: context)
                all.append(contentsOf: rows)
            }
            guard let next = calendar.date(byAdding: .day, value: 7, to: cursor) else { break }
            cursor = next
        }
        return all
    }

    @discardableResult
    func computeAndPersist(weekStartDate: Date, in context: ModelContext) throws -> [FulfillmentCategoryScoreSnapshot] {
        let window = FulfillmentScoringMath.weekWindow(for: weekStartDate, calendar: calendar)
        let isVacationWeek = VacationModeStore.overlappingConfig(start: window.weekStart, endExclusive: window.weekEnd) != nil

        let fulfillments = try context.fetch(FetchDescriptor<Fulfillment>())
        let roles = try context.fetch(FetchDescriptor<FulfillmentRoles>())
        let resources = try context.fetch(FetchDescriptor<FulfillmentResources>())
        let foci = try context.fetch(FetchDescriptor<FulfillmentFocus>())
        let passions = try context.fetch(FetchDescriptor<Passion>())
        let passionJoins = try context.fetch(FetchDescriptor<PassionFulfillmentJoin>())
        let littleWinsCompletions = try context.fetch(FetchDescriptor<LittleWinsDailyCompletion>())
        let reflectionArchives = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())
        let reflectionActions = try context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())
        let outcomes = try context.fetch(FetchDescriptor<Outcomes>())
        let outcomeMeasures = try context.fetch(FetchDescriptor<OutcomesMeasure>())
        let outcomeMeasureEntries = try context.fetch(FetchDescriptor<OutcomesMeasureEntry>())
        let outcomeEvents = try context.fetch(FetchDescriptor<OutcomeAnalyticsEvent>())
        let completedOutcomes = try context.fetch(FetchDescriptor<CompletedOutcomeArchive>())
        let scoreHistory = try context.fetch(
            FetchDescriptor<FulfillmentCategoryScoreSnapshot>(
                sortBy: [SortDescriptor(\FulfillmentCategoryScoreSnapshot.weekStartDate, order: .forward)]
            )
        )

        let passionIDs = Set(passions.map(\.passion_id))
        let roleCounts = Dictionary(grouping: roles, by: \.category_id).mapValues { $0.count }
        let resourceCounts = Dictionary(grouping: resources, by: \.category_id).mapValues { $0.count }
        let littleWinsByCategory = Dictionary(grouping: foci, by: \.category_id)
        let joinCounts = passionJoins.reduce(into: [UUID: Int]()) { acc, join in
            if passionIDs.contains(join.passion_id) { acc[join.category_id, default: 0] += 1 }
        }
        let outcomeMeasuresByID = Dictionary(uniqueKeysWithValues: outcomeMeasures.map { ($0.outcome_id, $0) })
        let measureEntriesByOutcome = Dictionary(grouping: outcomeMeasureEntries, by: \.outcome_id)
        let outcomeEventsByOutcome = Dictionary(grouping: outcomeEvents, by: \.outcome_id)

        let archiveIDsThisWeek = Set(reflectionArchives.filter { $0.completedAt >= window.weekStart && $0.completedAt < window.weekEnd }.map(\.id))
        let actionsThisWeek = reflectionActions.filter { archiveIDsThisWeek.contains($0.archiveId) }
        let groupedByBlockKey = Dictionary(grouping: actionsThisWeek) { row in
            let cat = row.chunkCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            return "\(cat)|\(row.archiveId.uuidString)|\(row.plannedChunkId.uuidString)"
        }

        var persisted: [FulfillmentCategoryScoreSnapshot] = []
        for fulfillment in fulfillments {
            let categoryID = fulfillment.category_id
            let categoryTitle = fulfillment.category
            let categoryKey = categoryTitle.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let categoryLittleWins = littleWinsByCategory[categoryID] ?? []
            let categoryLittleWinIDs = Set(categoryLittleWins.map(\.id))

            let weeklyCompletions = littleWinsCompletions.filter {
                categoryLittleWinIDs.contains($0.focusId) && $0.completedAt >= window.weekStart && $0.completedAt < window.weekEnd
            }
            let scheduledCount = scheduledLittleWinsCount(in: window, foci: categoryLittleWins)

            let categoryBlocks = groupedByBlockKey.filter { $0.key.hasPrefix(categoryKey + "|") }.map(\.value)
            let blockCompletionScores = categoryBlocks.compactMap { rows -> Double? in
                let total = rows.count
                guard total > 0 else { return nil }
                let statuses = rows.map { ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction }
                let done = statuses.filter { $0 == .done || $0 == .notNeeded }.count
                let blockCompleted = 1.0
                let actionRate = Double(done) / Double(total)
                return FulfillmentScoringMath.clamped01(0.6 * blockCompleted + 0.4 * actionRate)
            }
            let blockCarryovers = categoryBlocks.compactMap { rows -> Double? in
                let total = rows.count
                guard total > 0 else { return nil }
                let statuses = rows.map { ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction }
                let carry = statuses.filter { $0 == .carriedToCapture }.count
                return FulfillmentScoringMath.clamped01(Double(carry) / Double(total))
            }
            let strategicShare = categoryBlocks.compactMap { rows -> Double? in
                let total = rows.count
                guard total > 0 else { return nil }
                let mustCount = rows.filter(\.isMust).count
                let statuses = rows.map { ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction }
                let doneFlags = zip(rows, statuses).filter { row, status in
                    row.isMust && (status == .done || status == .notNeeded)
                }.count
                if mustCount == 0 { return 0.5 }
                return Double(doneFlags) / Double(mustCount)
            }
            let reactiveCarry = categoryBlocks.compactMap { rows -> Double? in
                let reactiveRows = rows.filter { !$0.isMust }
                guard !reactiveRows.isEmpty else { return nil }
                let statuses = reactiveRows.map { ActionExecutionStatus(rawValue: $0.statusRaw) ?? .noAction }
                let carry = statuses.filter { $0 == .carriedToCapture }.count
                return Double(carry) / Double(reactiveRows.count)
            }

            let activeOutcomes = outcomes.filter {
                $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == categoryKey &&
                $0.start < window.weekEnd && $0.end >= window.weekStart
            }
            let completedOutcomesThisWeek = completedOutcomes.filter {
                $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == categoryKey &&
                $0.completedAt >= window.weekStart && $0.completedAt < window.weekEnd
            }
            let outcomeScores = activeOutcomes.compactMap { outcome -> Double? in
                let measure = outcomeMeasuresByID[outcome.outcome_id]
                let entries = (measureEntriesByOutcome[outcome.outcome_id] ?? []).sorted { $0.measuredAt < $1.measuredAt }
                guard let target = measure?.measure_amt ?? entries.last?.measure_amt else { return nil }
                let actual = entries.last(where: { $0.measuredAt < window.weekEnd })?.measure ?? measure?.measure
                guard let actual else { return nil }
                let startValue = entries.first?.measure ?? 0
                let onTrack = PassionScoringMath.measurableOnTrackScore(
                    startValue: startValue,
                    targetValue: target,
                    actualValue: actual,
                    startDate: outcome.start,
                    endDate: outcome.end,
                    evaluationDate: min(outcome.end, window.weekEnd)
                )
                let targetEvents = (outcomeEventsByOutcome[outcome.outcome_id] ?? []).filter {
                    $0.eventType == "target_changed" && $0.occurredAt < window.weekEnd
                }
                let daysPushed = targetEvents.reduce(0.0) { partial, ev in
                    guard let old = ev.oldTargetDate, let new = ev.newTargetDate else { return partial }
                    return partial + max(0, new.timeIntervalSince(old) / 86_400.0)
                }
                let penalty = PassionScoringMath.goalPushPenalty(
                    pushCount: targetEvents.count,
                    totalDaysPushed: daysPushed,
                    originalDurationDays: max(1, outcome.end.timeIntervalSince(outcome.start) / 86_400.0)
                )
                return FulfillmentScoringMath.clamped01(onTrack - penalty)
            }
            let completedOutcomeScores = completedOutcomesThisWeek.map { archive -> Double in
                if archive.isMeasurable {
                    let score = archive.goalMet ? 0.85 : 0.35
                    let lateness = PassionScoringMath.earlyLateBonus(plannedEndDate: archive.end, actualCompletionDate: archive.completedAt)
                    return FulfillmentScoringMath.clamped01(score + lateness)
                }
                switch archive.successLevel ?? 3 {
                case 1: return 0.0
                case 2: return 0.25
                case 3: return 0.5
                case 4: return 0.8
                case 5: return 1.0
                default: return 0.5
                }
            }

            let engagedDays = engagedDaysCount(
                window: window,
                categoryID: categoryID,
                categoryKey: categoryKey,
                littleWinsCompletions: littleWinsCompletions,
                littleWinIDs: categoryLittleWinIDs,
                reflectionActions: actionsThisWeek,
                outcomes: activeOutcomes,
                completedOutcomes: completedOutcomesThisWeek
            )

            let signals = FulfillmentCategorySignals(
                hasVision: !fulfillment.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                hasPurpose: !fulfillment.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                rolesCount: roleCounts[categoryID] ?? 0,
                resourcesCount: resourceCounts[categoryID] ?? 0,
                passionsLinkedCount: joinCounts[categoryID] ?? 0,
                littleWinsDefinedCount: categoryLittleWins.count,
                actionBlockCompletionMean: FulfillmentScoringMath.mean(blockCompletionScores),
                actionBlockCarryoverMean: FulfillmentScoringMath.mean(blockCarryovers),
                strategicCompletionShare: FulfillmentScoringMath.mean(strategicShare),
                reactiveCarryoverMean: FulfillmentScoringMath.mean(reactiveCarry),
                littleWinsCompletedCount: weeklyCompletions.count,
                littleWinsScheduledCount: scheduledCount,
                outcomeScores: outcomeScores + completedOutcomeScores,
                engagedDaysCount: engagedDays
            )

            let history = scoreHistory.filter { $0.categoryID == categoryID && $0.weekStartDate < window.weekStart }
            let result = isVacationWeek ? frozenVacationResult(history: history) : computeScore(signals: signals, history: history)
            let snapshot = try upsertSnapshot(
                weekStart: window.weekStart,
                category: fulfillment,
                result: result,
                context: context
            )
            persisted.append(snapshot)
        }

        try context.save()
        return persisted
    }

    private func earliestRelevantDate(in context: ModelContext) throws -> Date? {
        var dates: [Date] = []
        if let d = try earliestDate(type: Fulfillment.self, sortBy: SortDescriptor(\Fulfillment.updatedAt, order: .forward), keyPath: \.updatedAt, in: context) { dates.append(d) }
        if let d = try earliestDate(type: LittleWinsDailyCompletion.self, sortBy: SortDescriptor(\LittleWinsDailyCompletion.completedAt, order: .forward), keyPath: \.completedAt, in: context) { dates.append(d) }
        if let d = try earliestDate(type: ActionBlocksReflectionArchive.self, sortBy: SortDescriptor(\ActionBlocksReflectionArchive.completedAt, order: .forward), keyPath: \.completedAt, in: context) { dates.append(d) }
        if let d = try earliestDate(type: Outcomes.self, sortBy: SortDescriptor(\Outcomes.start, order: .forward), keyPath: \.start, in: context) { dates.append(d) }
        if let d = try earliestDate(type: CompletedOutcomeArchive.self, sortBy: SortDescriptor(\CompletedOutcomeArchive.completedAt, order: .forward), keyPath: \.completedAt, in: context) { dates.append(d) }
        if let d = try earliestDate(type: FulfillmentCategoryScoreSnapshot.self, sortBy: SortDescriptor(\FulfillmentCategoryScoreSnapshot.weekStartDate, order: .forward), keyPath: \.weekStartDate, in: context) { dates.append(d) }
        return dates.min()
    }

    private func earliestDate<T: PersistentModel>(
        type: T.Type,
        sortBy: SortDescriptor<T>,
        keyPath: KeyPath<T, Date>,
        in context: ModelContext
    ) throws -> Date? {
        _ = type
        var descriptor = FetchDescriptor<T>(sortBy: [sortBy])
        descriptor.fetchLimit = 1
        return try context.fetch(descriptor).first.map { $0[keyPath: keyPath] }
    }

    func computeScore(signals: FulfillmentCategorySignals, history: [FulfillmentCategoryScoreSnapshot]) -> FulfillmentCategoryScoreResult {
        let sortedHistory = history.sorted { $0.weekStartDate < $1.weekStartDate }
        let prev = sortedHistory.last

        let structure = computeStructure(signals)
        let outcomes = FulfillmentScoringMath.mean(signals.outcomeScores)
        let actionBlocks = signals.actionBlockCompletionMean ?? 0.5
        let carryoverPenalty = signals.actionBlockCarryoverMean ?? 0.0
        let littleWins = computeLittleWins(signals)
        let engagement = FulfillmentScoringMath.clamped01(Double(signals.engagedDaysCount) / 4.0)
        let strategicBalance = computeStrategicBalance(signals)

        var weighted: [(Double, Double)] = [
            (0.18, structure),
            (0.22, actionBlocks),
            (0.12, FulfillmentScoringMath.clamped01(1 - carryoverPenalty)),
            (0.20, littleWins),
            (0.13, engagement),
            (0.15, strategicBalance)
        ]
        if let outcomes {
            weighted.append((0.25, outcomes))
            // shave proportionally from action/littleWins so totals stay balanced
            weighted[1].0 -= 0.10
            weighted[3].0 -= 0.10
            weighted[5].0 -= 0.05
        }

        let totalWeight = weighted.reduce(0.0) { $0 + $1.0 }
        let evidenceRaw = totalWeight > 0 ? weighted.reduce(0.0) { $0 + ($1.0 * FulfillmentScoringMath.clamped01($1.1)) } / totalWeight : 0.5
        let recentEvidence = Array(sortedHistory.suffix(3).map(\.evidence)) + [evidenceRaw]
        let consistency = FulfillmentScoringMath.consistency(lastEvidence: recentEvidence)
        let evidence = (0.85 * evidenceRaw) + (0.15 * (evidenceRaw * consistency))

        let targetScore = FulfillmentScoringMath.clamp((evidence * 4.0) + 1.0, 1.0, 5.0)
        let prevScore = prev?.score ?? 3.0
        let prevEMA = prev?.smoothedScore ?? 3.0
        let smoothedTarget = prev == nil
            ? 3.0
            : FulfillmentScoringMath.ema(alpha: config.emaAlpha, target: targetScore, previous: prevEMA)
        let delta = prev == nil
            ? 0.0
            : FulfillmentScoringMath.clamp(smoothedTarget - prevScore, -config.maxWeeklyDelta, config.maxWeeklyDelta)
        let finalScore = prev == nil
            ? 3.0
            : FulfillmentScoringMath.clamp(prevScore + delta, 1.0, 5.0)

        let momentumSeries = Array(sortedHistory.suffix(3).map(\.evidence)) + [evidence]
        let momentum = FulfillmentScoringMath.momentum(lastEvidence: momentumSeries)

        return FulfillmentCategoryScoreResult(
            score: finalScore,
            breakdown: .init(
                structure: structure,
                outcomes: outcomes ?? 0.5,
                actionBlocks: actionBlocks,
                carryoverPenalty: carryoverPenalty,
                littleWins: littleWins,
                engagement: engagement,
                strategicBalance: strategicBalance,
                consistency: consistency,
                evidence: evidence,
                targetScore: targetScore,
                smoothedScore: smoothedTarget,
                momentum: momentum
            )
        )
    }

    private func frozenVacationResult(history: [FulfillmentCategoryScoreSnapshot]) -> FulfillmentCategoryScoreResult {
        let sortedHistory = history.sorted { $0.weekStartDate < $1.weekStartDate }
        if let prev = sortedHistory.last {
            return FulfillmentCategoryScoreResult(
                score: prev.score,
                breakdown: .init(
                    structure: prev.structure,
                    outcomes: prev.outcomes,
                    actionBlocks: prev.actionBlocks,
                    carryoverPenalty: prev.carryoverPenalty,
                    littleWins: prev.littleWins,
                    engagement: prev.engagement,
                    strategicBalance: prev.strategicBalance,
                    consistency: prev.consistency,
                    evidence: prev.evidence,
                    targetScore: prev.targetScore,
                    smoothedScore: prev.smoothedScore,
                    momentum: 0
                )
            )
        }

        return FulfillmentCategoryScoreResult(
            score: 3.0,
            breakdown: .init(
                structure: 0,
                outcomes: 0.5,
                actionBlocks: 0.5,
                carryoverPenalty: 0,
                littleWins: 0,
                engagement: 0,
                strategicBalance: 0.5,
                consistency: 1,
                evidence: 0.5,
                targetScore: 3.0,
                smoothedScore: 3.0,
                momentum: 0
            )
        )
    }

    private func computeStructure(_ s: FulfillmentCategorySignals) -> Double {
        let v = s.hasVision ? 1.0 : 0.0
        let p = s.hasPurpose ? 1.0 : 0.0
        let roles = FulfillmentScoringMath.clamped01(Double(s.rolesCount) / 4.0)
        let resources = FulfillmentScoringMath.clamped01(Double(s.resourcesCount) / 4.0)
        let passions = FulfillmentScoringMath.clamped01(Double(s.passionsLinkedCount) / 4.0)
        let wins = FulfillmentScoringMath.clamped01(Double(s.littleWinsDefinedCount) / 3.0)
        return FulfillmentScoringMath.clamped01(0.20*v + 0.20*p + 0.18*roles + 0.14*resources + 0.14*passions + 0.14*wins)
    }

    private func computeLittleWins(_ s: FulfillmentCategorySignals) -> Double {
        let denom = max(1, s.littleWinsScheduledCount)
        return FulfillmentScoringMath.clamped01(Double(max(0, s.littleWinsCompletedCount)) / Double(denom))
    }

    private func computeStrategicBalance(_ s: FulfillmentCategorySignals) -> Double {
        let strategic = s.strategicCompletionShare ?? 0.5
        let reactivePenalty = s.reactiveCarryoverMean ?? 0.0
        return FulfillmentScoringMath.clamped01(0.65 * strategic + 0.35 * (1 - reactivePenalty))
    }

    private func scheduledLittleWinsCount(in window: FulfillmentWeekWindow, foci: [FulfillmentFocus]) -> Int {
        guard !foci.isEmpty else { return 0 }
        let cal = calendar
        var day = cal.startOfDay(for: window.weekStart)
        var total = 0
        while day < window.weekEnd {
            for focus in foci {
                let rule = LittleWinsScheduleStore.rule(for: focus.id)
                if isActive(rule: rule, on: day) { total += 1 }
            }
            guard let next = cal.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return total
    }

    private func isActive(rule: LittleWinsScheduleRule, on date: Date) -> Bool {
        if rule.canCompleteAnyDay { return true }
        let weekday = calendar.component(.weekday, from: date)
        let bit = 1 << (weekday - 1)
        return (rule.activeWeekdayMask & bit) != 0
    }

    private func engagedDaysCount(
        window: FulfillmentWeekWindow,
        categoryID: UUID,
        categoryKey: String,
        littleWinsCompletions: [LittleWinsDailyCompletion],
        littleWinIDs: Set<UUID>,
        reflectionActions: [ActionBlocksReflectionArchiveAction],
        outcomes: [Outcomes],
        completedOutcomes: [CompletedOutcomeArchive]
    ) -> Int {
        let cal = calendar
        var days = Set<Date>()
        for row in littleWinsCompletions where littleWinIDs.contains(row.focusId) && row.completedAt >= window.weekStart && row.completedAt < window.weekEnd {
            days.insert(cal.startOfDay(for: row.completedAt))
        }
        for row in reflectionActions where row.chunkCategory.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == categoryKey {
            days.insert(cal.startOfDay(for: row.weekStart))
        }
        for o in outcomes {
            if o.updatedAt >= window.weekStart && o.updatedAt < window.weekEnd {
                days.insert(cal.startOfDay(for: o.updatedAt))
            }
        }
        for o in completedOutcomes where o.completedAt >= window.weekStart && o.completedAt < window.weekEnd {
            days.insert(cal.startOfDay(for: o.completedAt))
        }
        _ = categoryID
        return days.count
    }

    private func upsertSnapshot(
        weekStart: Date,
        category: Fulfillment,
        result: FulfillmentCategoryScoreResult,
        context: ModelContext
    ) throws -> FulfillmentCategoryScoreSnapshot {
        let key = FulfillmentCategoryScoreSnapshot.makeKey(weekStartDate: weekStart, categoryID: category.category_id)
        let existing = try context.fetch(FetchDescriptor<FulfillmentCategoryScoreSnapshot>()).first { $0.weekCategoryKey == key }
        let b = result.breakdown
        if let existing {
            existing.weekStartDate = weekStart
            existing.categoryID = category.category_id
            existing.categoryTitleSnapshot = category.category
            existing.weekCategoryKey = key
            existing.score = result.score
            existing.smoothedScore = b.smoothedScore
            existing.targetScore = b.targetScore
            existing.evidence = b.evidence
            existing.momentum = b.momentum
            existing.structure = b.structure
            existing.outcomes = b.outcomes
            existing.actionBlocks = b.actionBlocks
            existing.carryoverPenalty = b.carryoverPenalty
            existing.littleWins = b.littleWins
            existing.engagement = b.engagement
            existing.strategicBalance = b.strategicBalance
            existing.consistency = b.consistency
            existing.updatedAt = .now
            return existing
        }

        let snapshot = FulfillmentCategoryScoreSnapshot(
            weekStartDate: weekStart,
            categoryID: category.category_id,
            categoryTitleSnapshot: category.category,
            score: result.score,
            smoothedScore: b.smoothedScore,
            targetScore: b.targetScore,
            evidence: b.evidence,
            momentum: b.momentum,
            structure: b.structure,
            outcomes: b.outcomes,
            actionBlocks: b.actionBlocks,
            carryoverPenalty: b.carryoverPenalty,
            littleWins: b.littleWins,
            engagement: b.engagement,
            strategicBalance: b.strategicBalance,
            consistency: b.consistency
        )
        context.insert(snapshot)
        return snapshot
    }
}
