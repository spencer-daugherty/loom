import SwiftUI
import SwiftData
import Charts
import UIKit
#if canImport(EventKit)
import EventKit
#endif

private struct ReflectDarkModeInvertImage: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            content
                .colorInvert()
                .compositingGroup()
        } else {
            content
        }
    }
}

#Preview {
    NavigationStack {
        ReflectView(weekStart: .now) {}
    }
    .loomPreviewContainer()
}

struct ReflectView: View {
    let weekStart: Date
    let onFinish: () -> Void

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query private var allChunks: [PlannedChunk]
    @Query private var allActions: [PlannedChunkAction]
    @Query private var allDefineStates: [PlannedChunkActionDefineState]
    @Query private var allExecutionStates: [PlannedChunkActionExecutionState]
    @Query private var allLeverageSelections: [PlannedChunkActionLeverageSelection]
    @Query(sort: \LeverageResource.createdAt, order: .forward) private var allLeverageResources: [LeverageResource]
    @Query private var allPlaceLinks: [PlannedChunkActionSensitivityPlaceLink]
    @Query(sort: \SensitivityPlaceCatalogItem.place, order: .forward) private var allPlaces: [SensitivityPlaceCatalogItem]
    @Query private var allNotes: [PlannedChunkActionNote]
    @Query private var allAttachments: [PlannedChunkActionAttachment]
    @Query private var allStepFourStates: [PlannedChunkStepFourState]
    @Query private var allOutcomeLinks: [PlannedChunkOutcomeLink]
    @Query private var allChunkSelections: [PlanChunkSelection]
    @Query(sort: \Outcomes.rank, order: .forward) private var outcomes: [Outcomes]
    @Query(sort: \Fulfillment.updatedAt, order: .forward) private var fulfillments: [Fulfillment]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomeMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var outcomeMeasureEntries: [OutcomesMeasureEntry]
    @Query private var allMindsetRows: [WeeklyMindsetEntry.Fields]
    @Query private var allAdHocMarkers: [PlannedChunkActionAdHocMarker]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse) private var captureItems: [RollingCaptureItem]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @AppStorage("capture_google_tasks_access_token") private var googleTasksAccessToken: String = ""
    @AppStorage("capture_microsoft_todo_access_token") private var microsoftTodoAccessToken: String = ""

    @State private var step: Int = 1
    @State private var showCelebration: Bool = true

    @State private var achievementsText: String = ""
    @State private var magicMomentsText: String = ""
    @State private var powerQuestionText: String = ""
    @State private var showSaveHint: Bool = false
    @State private var highlightedMissingJournalFields: Set<JournalField> = []
    @State private var showContributionPrompt: Bool = false
    @State private var contributionOutcomeIndex: Int = 0
    @State private var contributionTempSelection: Set<UUID> = []
    @State private var contributionSelectionsByOutcome: [UUID: Set<UUID>] = [:]
    @State private var contributionOutcomeQueue: [Outcomes] = []
    @State private var contributionDoneActionsByOutcomeID: [UUID: [PlannedChunkAction]] = [:]
    @State private var showOtherContributionPrompt: Bool = false
    @State private var otherContributionChunkQueue: [PlannedChunk] = []
    @State private var otherContributionChunkIndex: Int = 0
    @State private var otherContributionTempSelection: Set<UUID> = []
    @State private var otherContributionSelectionsByChunkID: [UUID: Set<UUID>] = [:]
    @State private var selectedReflectionPassionIDs: Set<UUID> = []
    @State private var isShowingReflectionPassionsSheet: Bool = false
    @State private var isShowingNoPassionsSaveConfirm: Bool = false
    @State private var hasScheduledCelebrationDismiss = false
    @State private var shouldRenderHeavyInsights = false
    @State private var shouldRenderInsightsCharts = false
    @State private var insightsSnapshot: InsightsSnapshot?
    @State private var celebrationAnimationStartDate: Date = .now
    @State private var readableInsightsText: String?
    @State private var readableInsightsLoading = false
    @State private var readableInsightsRequestKey: String?
    private enum JournalField: Hashable {
        case journal
    }

    private struct InsightsSnapshot {
        struct ProductiveSignalRow: Hashable {
            let id: String
            let label: String
            let count: Int
            let typeLabel: String
        }
        struct FulfillmentAreaRow: Hashable {
            let title: String
            let doneCount: Int
            let color: Color
            let actionBlockProjectedDelta: Double?
        }
        struct OutcomeRow: Hashable {
            let id: UUID
            let title: String
            let category: String
            let color: Color
        }
        let doneCount: Int
        let totalActions: Int
        let completionRatio: Double
        let carriedCount: Int
        let carriedRatio: Double
        let doneEstimatedCount: Int
        let startedAt: Date
        let completedAt: Date
        let completionDayCount: Int
        let productiveSignals: [ProductiveSignalRow]
        let productiveDayRows: [ProductiveDayRow]
        let flowProfileRows: [(String, Int, Color)]
        let fulfillmentAreaRows: [FulfillmentAreaRow]
        let outcomeRows: [OutcomeRow]
        let carriedActionTexts: [String]
    }

    private var stepTitle: String {
        step == 1 ? "Insights" : "Journal"
    }

    init(weekStart: Date, onFinish: @escaping () -> Void) {
        let ws = WeeklyMindsetEntry.weekStart(for: weekStart)
        let we = Calendar.current.date(byAdding: .day, value: 7, to: ws) ?? ws
        self.weekStart = ws
        self.onFinish = onFinish

        _allChunks = Query(
            filter: #Predicate<PlannedChunk> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunk.chunkIndex, order: .forward)]
        )
        _allActions = Query(
            filter: #Predicate<PlannedChunkAction> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkAction.sortOrder, order: .forward)]
        )
        _allDefineStates = Query(
            filter: #Predicate<PlannedChunkActionDefineState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionDefineState.updatedAt, order: .reverse)]
        )
        _allExecutionStates = Query(
            filter: #Predicate<PlannedChunkActionExecutionState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionExecutionState.updatedAt, order: .reverse)]
        )
        _allLeverageSelections = Query(
            filter: #Predicate<PlannedChunkActionLeverageSelection> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionLeverageSelection.updatedAt, order: .reverse)]
        )
        _allPlaceLinks = Query(
            filter: #Predicate<PlannedChunkActionSensitivityPlaceLink> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionSensitivityPlaceLink.createdAt, order: .forward)]
        )
        _allNotes = Query(
            filter: #Predicate<PlannedChunkActionNote> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionNote.updatedAt, order: .reverse)]
        )
        _allAttachments = Query(
            filter: #Predicate<PlannedChunkActionAttachment> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionAttachment.createdAt, order: .forward)]
        )
        _allStepFourStates = Query(
            filter: #Predicate<PlannedChunkStepFourState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkStepFourState.updatedAt, order: .reverse)]
        )
        _allOutcomeLinks = Query(
            filter: #Predicate<PlannedChunkOutcomeLink> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkOutcomeLink.createdAt, order: .forward)]
        )
        _allChunkSelections = Query(
            filter: #Predicate<PlanChunkSelection> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlanChunkSelection.updatedAt, order: .reverse)]
        )
        _allMindsetRows = Query(
            filter: #Predicate<WeeklyMindsetEntry.Fields> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\WeeklyMindsetEntry.Fields.createdAt, order: .reverse)]
        )
        _allAdHocMarkers = Query(
            filter: #Predicate<PlannedChunkActionAdHocMarker> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionAdHocMarker.createdAt, order: .forward)]
        )
    }

    private var weekChunks: [PlannedChunk] {
        allChunks
    }

    private var weekActions: [PlannedChunkAction] {
        allActions
    }

    private var actionIDs: Set<UUID> {
        Set(weekActions.map(\.id))
    }

    private var chunkByID: [UUID: PlannedChunk] {
        Dictionary(uniqueKeysWithValues: weekChunks.map { ($0.id, $0) })
    }

    private var defineByActionID: [UUID: PlannedChunkActionDefineState] {
        var map: [UUID: PlannedChunkActionDefineState] = [:]
        for row in allDefineStates where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = map[key] else { map[key] = row; continue }
            if row.updatedAt > existing.updatedAt { map[key] = row }
        }
        return map
    }

    private var executionByActionID: [UUID: PlannedChunkActionExecutionState] {
        var map: [UUID: PlannedChunkActionExecutionState] = [:]
        for row in allExecutionStates where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = map[key] else { map[key] = row; continue }
            if row.updatedAt > existing.updatedAt { map[key] = row }
        }
        return map
    }

    private var leverageByActionID: [UUID: PlannedChunkActionLeverageSelection] {
        var map: [UUID: PlannedChunkActionLeverageSelection] = [:]
        for row in allLeverageSelections where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = map[key] else { map[key] = row; continue }
            if row.updatedAt > existing.updatedAt { map[key] = row }
        }
        return map
    }

    private var resourceByID: [UUID: LeverageResource] {
        Dictionary(uniqueKeysWithValues: allLeverageResources.map { ($0.id, $0) })
    }

    private var placeByID: [UUID: SensitivityPlaceCatalogItem] {
        Dictionary(uniqueKeysWithValues: allPlaces.map { ($0.id, $0) })
    }

    private var placeIDsByActionID: [UUID: [UUID]] {
        Dictionary(grouping: allPlaceLinks.filter { actionIDs.contains($0.plannedChunkActionId) }, by: \.plannedChunkActionId)
            .mapValues { $0.map(\.placeId) }
    }

    private var noteByActionID: [UUID: PlannedChunkActionNote] {
        var map: [UUID: PlannedChunkActionNote] = [:]
        for row in allNotes where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = map[key] else { map[key] = row; continue }
            if row.updatedAt > existing.updatedAt { map[key] = row }
        }
        return map
    }

    private var attachmentsByActionID: [UUID: [PlannedChunkActionAttachment]] {
        Dictionary(grouping: allAttachments.filter { actionIDs.contains($0.plannedChunkActionId) }, by: \.plannedChunkActionId)
    }

    private var weekOutcomeLinks: [PlannedChunkOutcomeLink] {
        allOutcomeLinks
    }

    private var adHocMarkerActionIDs: Set<UUID> {
        Set(allAdHocMarkers.map(\.plannedChunkActionId))
    }

    private var startedAt: Date {
        weekActions.map(\.createdAt).min() ?? .now
    }

    private var completedAt: Date {
        .now
    }

    private var completionDayCount: Int {
        let start = Calendar.current.startOfDay(for: startedAt)
        let end = Calendar.current.startOfDay(for: completedAt)
        let span = (Calendar.current.dateComponents([.day], from: start, to: end).day ?? 0) + 1
        return max(1, span)
    }

    private var closedStatuses: Set<ActionExecutionStatus> {
        [.done, .carriedToCapture, .notNeeded]
    }

    private var doneCount: Int {
        weekActions.filter { status(for: $0.id) == .done }.count
    }

    private var carriedActions: [PlannedChunkAction] {
        weekActions.filter { status(for: $0.id) == .carriedToCapture }
    }

    private var notNeededCount: Int {
        weekActions.filter { status(for: $0.id) == .notNeeded }.count
    }

    private var mustCount: Int {
        weekActions.filter { defineByActionID[$0.id]?.isMust == true }.count
    }

    private var leveragedCount: Int {
        var leveragedIDs = Set<UUID>()
        for row in allLeverageSelections where actionIDs.contains(row.plannedChunkActionId) {
            guard let resourceID = row.resourceId, resourceByID[resourceID] != nil else { continue }
            leveragedIDs.insert(row.plannedChunkActionId)
        }
        return leveragedIDs.count
    }

    private var adHocCount: Int {
        weekActions.filter { adHocMarkerActionIDs.contains($0.id) }.count
    }

    private var durations: [Int] {
        weekActions.compactMap { defineByActionID[$0.id]?.timeEstimateMinutes }
    }

    private var averageDurationMinutes: Int {
        guard !durations.isEmpty else { return 0 }
        return Int(Double(durations.reduce(0, +)) / Double(durations.count))
    }

    private var noteCount: Int {
        noteByActionID.values.filter { !$0.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }.count
    }

    private var linkCount: Int {
        attachmentsByActionID.values.flatMap { $0 }.filter { $0.kind == .link }.count
    }

    private var fileCount: Int {
        attachmentsByActionID.values.flatMap { $0 }.filter { $0.kind == .file }.count
    }

    private var totalActions: Int {
        weekActions.count
    }

    private var completionRatio: Double {
        guard totalActions > 0 else { return 0 }
        return Double(doneCount) / Double(totalActions)
    }

    private var topPerson: String? {
        topResource(of: .person)
    }

    private var topTool: String? {
        topResource(of: .tool)
    }

    private var topPlace: String? {
        var counts: [String: Int] = [:]
        for action in weekActions where closedStatuses.contains(status(for: action.id)) {
            for placeId in placeIDsByActionID[action.id] ?? [] {
                if let place = placeByID[placeId]?.place {
                    counts[place, default: 0] += 1
                }
            }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var topTimeOfDay: String? {
        var counts: [String: Int] = ["Morning": 0, "Afternoon": 0, "Evening": 0]
        for action in weekActions where closedStatuses.contains(status(for: action.id)) {
            guard let define = defineByActionID[action.id] else { continue }
            if define.sensitiveMorning { counts["Morning", default: 0] += 1 }
            if define.sensitiveAfternoon { counts["Afternoon", default: 0] += 1 }
            if define.sensitiveEvening { counts["Evening", default: 0] += 1 }
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private var productiveSignalRows: [InsightsSnapshot.ProductiveSignalRow] {
        let doneActions = weekActions.filter { status(for: $0.id) == .done }
        var counts: [String: (label: String, count: Int, typeLabel: String)] = [:]

        for action in doneActions {
            for placeId in placeIDsByActionID[action.id] ?? [] {
                guard let place = placeByID[placeId]?.place, !place.isEmpty else { continue }
                let key = "place:\(place.lowercased())"
                let existing = counts[key] ?? (place, 0, "Place")
                counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
            }

            if let leverage = leverageByActionID[action.id],
               let resourceID = leverage.resourceId,
               let resource = resourceByID[resourceID]
            {
                let label = resource.value.trimmingCharacters(in: .whitespacesAndNewlines)
                if !label.isEmpty {
                    let kindLabel = resource.kind == .person ? "Person" : (resource.kind == .tool ? "Tool" : "Resource")
                    let key = "\(kindLabel.lowercased()):\(label.lowercased())"
                    let existing = counts[key] ?? (label, 0, kindLabel)
                    counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                }
            }

            if let define = defineByActionID[action.id] {
                let allTimesSelected = define.sensitiveMorning && define.sensitiveAfternoon && define.sensitiveEvening
                if !allTimesSelected {
                    if define.sensitiveMorning {
                        let key = "time:morning"
                        let existing = counts[key] ?? ("Morning", 0, "Time")
                        counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                    }
                    if define.sensitiveAfternoon {
                        let key = "time:afternoon"
                        let existing = counts[key] ?? ("Afternoon", 0, "Time")
                        counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                    }
                    if define.sensitiveEvening {
                        let key = "time:evening"
                        let existing = counts[key] ?? ("Evening", 0, "Time")
                        counts[key] = (existing.label, existing.count + 1, existing.typeLabel)
                    }
                }
            }
        }

        return counts.map { key, row in
            InsightsSnapshot.ProductiveSignalRow(id: key, label: row.label, count: row.count, typeLabel: row.typeLabel)
        }
        .sorted { lhs, rhs in
            if lhs.count == rhs.count { return lhs.label < rhs.label }
            return lhs.count > rhs.count
        }
        .prefix(5)
        .map { $0 }
    }

    private var categoryBreakdown: [(String, Int)] {
        let doneActions = weekActions.filter { status(for: $0.id) == .done }
        let grouped = Dictionary(grouping: doneActions, by: \.plannedChunkId)
        let pairs = grouped.compactMap { chunkID, actions -> (String, Int)? in
            guard let chunk = chunkByID[chunkID] else { return nil }
            return (chunk.category, actions.count)
        }
        let merged = Dictionary(grouping: pairs, by: { $0.0 }).mapValues { rows in rows.reduce(0) { $0 + $1.1 } }
        return merged.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    private func actionBlockOnlyProjectedDeltaByCategory() -> [String: Double] {
        let grouped = Dictionary(grouping: weekActions) { action in
            (chunkByID[action.plannedChunkId]?.category ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        }

        var result: [String: Double] = [:]
        for (category, actions) in grouped {
            let title = category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }

            let blocks = Dictionary(grouping: actions, by: \.plannedChunkId).map(\.value)

            let blockCompletionScores = blocks.compactMap { rows -> Double? in
                let total = rows.count
                guard total > 0 else { return nil }
                let statuses = rows.map { status(for: $0.id) }
                let done = statuses.filter { $0 == .done || $0 == .notNeeded }.count
                let actionRate = Double(done) / Double(total)
                return FulfillmentScoringMath.clamped01(0.6 * 1.0 + 0.4 * actionRate)
            }
            let blockCarryovers = blocks.compactMap { rows -> Double? in
                let total = rows.count
                guard total > 0 else { return nil }
                let carry = rows.map { status(for: $0.id) }.filter { $0 == .carriedToCapture }.count
                return FulfillmentScoringMath.clamped01(Double(carry) / Double(total))
            }
            let strategicShare = blocks.compactMap { rows -> Double? in
                let mustRows = rows.filter { defineByActionID[$0.id]?.isMust == true }
                guard !mustRows.isEmpty else { return 0.5 }
                let doneFlags = mustRows.filter {
                    let s = status(for: $0.id)
                    return s == .done || s == .notNeeded
                }.count
                return Double(doneFlags) / Double(mustRows.count)
            }
            let reactiveCarry = blocks.compactMap { rows -> Double? in
                let reactiveRows = rows.filter { defineByActionID[$0.id]?.isMust != true }
                guard !reactiveRows.isEmpty else { return nil }
                let carry = reactiveRows.filter { status(for: $0.id) == .carriedToCapture }.count
                return Double(carry) / Double(reactiveRows.count)
            }

            let actionBlocks = FulfillmentScoringMath.mean(blockCompletionScores) ?? 0.5
            let carryPenalty = FulfillmentScoringMath.mean(blockCarryovers) ?? 0.0
            let strategic = strategicShare.isEmpty ? 0.5 : (FulfillmentScoringMath.mean(strategicShare) ?? 0.5)
            let reactivePenalty = FulfillmentScoringMath.mean(reactiveCarry) ?? 0.0
            let strategicBalance = FulfillmentScoringMath.clamped01(0.65 * strategic + 0.35 * (1 - reactivePenalty))

            // Action-Blocks-only projected contribution to the 1...5 score relative to neutral 0.5.
            let projected = 4.0 * (
                (0.22 * (actionBlocks - 0.5)) +
                (0.12 * ((1.0 - carryPenalty) - 0.5)) +
                (0.15 * (strategicBalance - 0.5))
            )
            let rounded = (projected * 10).rounded() / 10
            result[title] = abs(rounded) < 0.05 ? 0 : rounded
        }
        return result
    }

    private var outcomesForWeek: [Outcomes] {
        let ids = Set(weekOutcomeLinks.map(\.outcomeId))
        return outcomes.filter { ids.contains($0.outcome_id) }
    }

    private var outcomesForContributionFlow: [Outcomes] { contributionOutcomeQueue }

    private var currentContributionOutcome: Outcomes? {
        guard contributionOutcomeIndex >= 0, contributionOutcomeIndex < outcomesForContributionFlow.count else { return nil }
        return outcomesForContributionFlow[contributionOutcomeIndex]
    }

    private var currentContributionDoneActions: [PlannedChunkAction] {
        guard let outcome = currentContributionOutcome else { return [] }
        return contributionDoneActionsByOutcomeID[outcome.outcome_id] ?? []
    }

    private var currentContributionActionIDs: Set<UUID> {
        Set(currentContributionDoneActions.map(\.id))
    }

    private var areAllCurrentContributionActionsSelected: Bool {
        let ids = currentContributionActionIDs
        guard !ids.isEmpty else { return false }
        return ids.isSubset(of: contributionTempSelection)
    }

    private var currentOtherContributionChunk: PlannedChunk? {
        guard otherContributionChunkIndex >= 0, otherContributionChunkIndex < otherContributionChunkQueue.count else { return nil }
        return otherContributionChunkQueue[otherContributionChunkIndex]
    }

    private var currentOtherContributionFulfillmentRows: [Fulfillment] {
        fulfillments.sorted { lhs, rhs in
            lhs.category.localizedCaseInsensitiveCompare(rhs.category) == .orderedAscending
        }
    }

    private var productiveDayRows: [ProductiveDayRow] {
        let cal = Calendar.current
        let firstDay = cal.startOfDay(for: weekStart)
        let days: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: firstDay) }

        var doneByDay: [Date: Int] = [:]
        var notNeededByDay: [Date: Int] = [:]

        for action in weekActions {
            guard let execution = executionByActionID[action.id] else { continue }

            let day = cal.startOfDay(for: execution.updatedAt)
            switch execution.status {
            case .done:
                doneByDay[day, default: 0] += 1
            case .notNeeded:
                notNeededByDay[day, default: 0] += 1
            default:
                break
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return days.map { day in
            ProductiveDayRow(
                dayLabel: formatter.string(from: day),
                done: doneByDay[day, default: 0],
                notNeeded: notNeededByDay[day, default: 0]
            )
        }
    }

    private var weekMindsetRow: WeeklyMindsetEntry.Fields? {
        allMindsetRows.first
    }

    private var flowProfileRows: [(String, Int, Color)] {
        [
            ("Musts", mustCount, .yellow),
            ("Recapture for later", carriedActions.count, .blue),
            ("Didn't need to be done", notNeededCount, .gray),
            ("Assigned", leveragedCount, .mint),
            ("New actions added", adHocCount, .purple),
        ]
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
            return lhs.1 > rhs.1
        }
    }

    private var journalIsValid: Bool {
        true
    }

    private var selectedReflectionPassions: [Passion] {
        passions.filter { selectedReflectionPassionIDs.contains($0.passion_id) }
    }

    private var celebrationSplashMetrics: [(String, Color, Double)] {
        let actionBlockCategories = Array(Set(weekChunks.map(\.category))).sorted()
        let colors = actionBlockCategories.map { FulfillmentCategoryTheme.color(for: $0) }
        let palette = colors.isEmpty ? [Color.blue, .indigo, .green, .purple, .red, .orange] : colors
        return palette.enumerated().map { idx, color in
            ("Area \(idx + 1)", color, 20)
        }
    }

    private func pulsedCelebrationMetrics(at time: TimeInterval) -> [(String, Color, Double)] {
        celebrationSplashMetrics.enumerated().map { idx, tuple in
            let base = tuple.2
            let seed1 = Double((idx * 127 + 311) % 100) / 100.0
            let seed2 = Double((idx * 73 + 97) % 100) / 100.0
            let localAmp = 180.0 * (0.9 + seed1 * 0.8)
            let localSpeed = 1.6 * (0.8 + seed2 * 1.2)
            let phase1 = Double(idx) * 0.8 + seed1 * .pi * 2
            let phase2 = Double(idx) * 1.3 + seed2 * .pi
            let delta1 = sin(time * localSpeed + phase1) * localAmp * 0.7
            let delta2 = sin(time * localSpeed * 0.47 + phase2) * localAmp * 0.3
            let value = max(50, min(100, base + delta1 + delta2))
            return (tuple.0, tuple.1, value)
        }
    }

    private func buildInsightsSnapshot() -> InsightsSnapshot {
        let carried = carriedActions
        let projectedDeltas = actionBlockOnlyProjectedDeltaByCategory()
        let doneEstimatedCount = weekActions.filter {
            status(for: $0.id) == .done && (defineByActionID[$0.id]?.timeEstimateMinutes != nil)
        }.count
        return InsightsSnapshot(
            doneCount: doneCount,
            totalActions: totalActions,
            completionRatio: completionRatio,
            carriedCount: carried.count,
            carriedRatio: totalActions > 0 ? Double(carried.count) / Double(totalActions) : 0,
            doneEstimatedCount: doneEstimatedCount,
            startedAt: startedAt,
            completedAt: completedAt,
            completionDayCount: completionDayCount,
            productiveSignals: productiveSignalRows,
            productiveDayRows: productiveDayRows,
            flowProfileRows: flowProfileRows,
            fulfillmentAreaRows: categoryBreakdown.map {
                InsightsSnapshot.FulfillmentAreaRow(
                    title: $0.0,
                    doneCount: $0.1,
                    color: FulfillmentCategoryTheme.color(for: $0.0),
                    actionBlockProjectedDelta: projectedDeltas[$0.0]
                )
            },
            outcomeRows: outcomesForWeek.map {
                InsightsSnapshot.OutcomeRow(
                    id: $0.outcome_id,
                    title: $0.outcome,
                    category: $0.category,
                    color: FulfillmentCategoryTheme.color(for: $0.category)
                )
            },
            carriedActionTexts: carried.map(\.text)
        )
    }

    private var readableInsightsCardMessage: String {
        if let text = readableInsightsText?.trimmingCharacters(in: .whitespacesAndNewlines), !text.isEmpty {
            return text
        }
        return ""
    }

    private var shouldShowReadableInsightsCard: Bool {
        readableInsightsLoading || !(readableInsightsText?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
    }

    private var readableInsightsRequestSignature: String {
        [
            weekStart.ISO8601Format(),
            String(weekActions.count),
            String(doneCount),
            String(carriedActions.count),
            String(notNeededCount)
        ].joined(separator: "|")
    }

    @MainActor
    private func requestReadableInsightsIfNeeded() async {
        guard shouldRenderHeavyInsights else { return }
        let signature = readableInsightsRequestSignature
        guard readableInsightsRequestKey != signature else { return }
        readableInsightsRequestKey = signature
        readableInsightsLoading = true
        readableInsightsText = nil

        do {
            let loomBuilder = LoomAIViewModel()
            let contextSnapshot = try loomBuilder.buildContextSnapshot(in: modelContext)
            let service = LoomAIService()
            let prompt = reflectReadableInsightsPrompt()
            let response = try await service.sendChat(
                messages: [
                    .init(role: "user", content: prompt)
                ],
                context: contextSnapshot,
                intent: "readable_insights_reflect",
                screen: "reflect_readable_insights"
            )
            let text = response.message.trimmingCharacters(in: .whitespacesAndNewlines)
            readableInsightsText = text.isEmpty ? nil : limitedReadableInsightsText(text, maxCharacters: 200)
        } catch {
            readableInsightsText = nil
        }

        readableInsightsLoading = false
    }

    private func reflectReadableInsightsPrompt() -> String {
        let rows = weekActions.map { action -> String in
            let status = status(for: action.id).rawValue
            let define = defineByActionID[action.id]
            let execution = executionByActionID[action.id]
            let chunk = chunkByID[action.plannedChunkId]
            let step4 = allStepFourStates
                .filter { $0.plannedChunkId == action.plannedChunkId }
                .sorted { $0.updatedAt > $1.updatedAt }
                .first
            let leverage = leverageByActionID[action.id].flatMap { sel -> String? in
                guard let rid = sel.resourceId, let r = resourceByID[rid] else { return nil }
                return "\(r.kind.rawValue): \(r.value)"
            } ?? "none"
            let places = (placeIDsByActionID[action.id] ?? []).compactMap { placeByID[$0]?.place }
            let placeText = places.isEmpty ? "none" : places.joined(separator: ", ")
            let durationText = define?.timeEstimateMinutes.map(String.init) ?? "nil"
            let resultText = step4?.resultText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let identityText = step4?.roleNoteText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            let completedAt = execution?.updatedAt.ISO8601Format() ?? "nil"
            return """
            - action: \(action.text)
              status: \(status)
              chunkCategory: \(chunk?.category ?? "")
              chunkLabel: \(chunk?.label ?? "")
              result: \(resultText)
              identity: \(identityText)
              isMust: \(define?.isMust == true)
              durationMinutes: \(durationText)
              leverage: \(leverage)
              places: \(placeText)
              completedAt: \(completedAt)
            """
        }.joined(separator: "\n")

        let outcomeLines = outcomesForWeek.map { "- \($0.outcome) [\($0.category)]" }.joined(separator: "\n")
        let summary = """
        Create a readable insights summary for a completed Loom Action Blocks session.

        Requirements:
        - Base the insight on ALL available information in APP_CONTEXT plus the session details below.
        - Return exactly ONE high-signal insight sentence (not a recap/summary of visible stats).
        - Prioritize patterns, implications, or mismatches over repeating totals/counts already shown in the UI.
        - Use practical, plain-language wording (no filler).
        - Mention fulfillment areas or outcomes only when relevant to the actual insight.
        - Keep the message under 200 characters and end as a complete sentence.
        - Do not return actions/CTAs. Return only the readable insights text in the message.

        Session summary:
        weekStart: \(weekStart.ISO8601Format())
        startedAt: \(startedAt.ISO8601Format())
        completedAt: \(completedAt.ISO8601Format())
        totalActions: \(totalActions)
        doneCount: \(doneCount)
        carriedCount: \(carriedActions.count)
        notNeededCount: \(notNeededCount)
        leveragedCount: \(leveragedCount)
        adHocCount: \(adHocCount)
        averageDurationMinutes: \(averageDurationMinutes)
        noteCount: \(noteCount)
        linkCount: \(linkCount)
        fileCount: \(fileCount)
        topSignals: \(productiveSignalRows.map { "\($0.label)=\($0.count)" }.joined(separator: ", "))

        Fulfillment areas (done actions):
        \(categoryBreakdown.map { "- \($0.0): \($0.1)" }.joined(separator: "\n"))

        Outcomes connected:
        \(outcomeLines.isEmpty ? "- none" : outcomeLines)

        Actions:
        \(rows)
        """
        return summary
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if !showCelebration {
                mainContent
            }

            if showCelebration {
                celebrationView
            }
        }
        .navigationTitle(showCelebration ? "" : stepTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            if !showCelebration {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        handleHeaderBackTapped()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .sheet(isPresented: $showContributionPrompt) {
            contributionPromptSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showOtherContributionPrompt) {
            otherContributionPromptSheet
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingReflectionPassionsSheet) {
            reflectionPassionsSheet
        }
        .alert("Save without passions connected?", isPresented: $isShowingNoPassionsSaveConfirm) {
            Button("Cancel", role: .cancel) {}
            Button("Save") {
                saveArchiveAndExit()
            }
        } message: {
            Text("No passions are connected to this reflection. Do you want to save anyway?")
        }
        .overlay(alignment: .bottom) {
            if showSaveHint {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Please enter all items.")
                        .font(.footnote)
                        .fontWeight(.bold)
                }
                .multilineTextAlignment(.leading)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
                .padding(.horizontal, 4)
                .padding(.bottom, 56)
                .transition(.opacity)
            }
        }
        .onAppear {
            guard !hasScheduledCelebrationDismiss else { return }
            hasScheduledCelebrationDismiss = true
            shouldRenderHeavyInsights = false
            shouldRenderInsightsCharts = false
            insightsSnapshot = nil
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                showCelebration = false
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    insightsSnapshot = buildInsightsSnapshot()
                    shouldRenderHeavyInsights = true
                    Task { await requestReadableInsightsIfNeeded() }
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.6) {
                    shouldRenderInsightsCharts = true
                }
            }
        }
        .onDisappear {
            hasScheduledCelebrationDismiss = false
            shouldRenderHeavyInsights = false
            shouldRenderInsightsCharts = false
            insightsSnapshot = nil
            readableInsightsText = nil
            readableInsightsLoading = false
            readableInsightsRequestKey = nil
            showCelebration = true
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            if step == 1 {
                if shouldRenderHeavyInsights {
                    insightsStep
                } else {
                    insightsSkeletonStep
                }
            } else {
                journalStep
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.bottom)
    }

    private var insightsSkeletonStep: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 10) {
                    skeletonTile
                    skeletonTile
                }
                HStack(spacing: 10) {
                    skeletonTile
                    skeletonTile
                }

                VStack(alignment: .leading, spacing: 10) {
                    RoundedRectangle(cornerRadius: 5, style: .continuous)
                        .fill(Color.primary.opacity(0.08))
                        .frame(width: 130, height: 14)
                    ForEach(0..<4, id: \.self) { _ in
                        HStack(spacing: 10) {
                            Circle()
                                .fill(Color.primary.opacity(0.08))
                                .frame(width: 20, height: 20)
                            RoundedRectangle(cornerRadius: 5, style: .continuous)
                                .fill(Color.primary.opacity(0.08))
                                .frame(height: 14)
                        }
                    }
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
                    .frame(height: 210)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.primary.opacity(0.06), lineWidth: 1)
                    )
            }
            .redacted(reason: .placeholder)
            .padding(.top, 2)
        }
        .scrollIndicators(.hidden)
    }

    private var skeletonTile: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 88, height: 12)
            RoundedRectangle(cornerRadius: 6, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 92, height: 18)
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color.primary.opacity(0.08))
                .frame(width: 70, height: 11)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var celebrationView: some View {
        ZStack {
            WindLinesBackground(
                colors: celebrationSplashMetrics.map { $0.1 },
                animationStartDate: celebrationAnimationStartDate
            )
            .ignoresSafeArea()

            GeometryReader { geo in
                // Align with WindLinesBackground, which renders in full-screen coordinates.
                let animationCenterY = (geo.size.height - geo.safeAreaInsets.top + geo.safeAreaInsets.bottom) * 0.5

                ZStack {
                    TimelineView(.animation) { context in
                        let t = context.date.timeIntervalSinceReferenceDate
                        let animatedMetrics = pulsedCelebrationMetrics(at: t * 0.45)
                        let rotationDegrees = t * Double(337.5)
                        let startupElapsed = context.date.timeIntervalSince(celebrationAnimationStartDate)
                        let radarIntroDelay: Double = 1.0
                        let radarGrowDuration: Double = 0.26
                        let radarPopDuration: Double = 0.24

                        let introRaw = (startupElapsed - radarIntroDelay) / radarGrowDuration
                        let intro = max(0.0, min(introRaw, 1.0))
                        let easedIntro = 1.0 - pow(1.0 - intro, 3.0)

                        let baseScale = CGFloat(0.05 + (0.95 * easedIntro))
                        let popStart = radarIntroDelay + radarGrowDuration
                        let popRaw = (startupElapsed - popStart) / radarPopDuration
                        let pop = max(0.0, min(popRaw, 1.0))
                        let popPulse = sin(pop * .pi) * 0.10
                        let radarScale = baseScale * CGFloat(1.0 + popPulse)
                        let radarOpacity = easedIntro

                        HStack(spacing: 12) {
                            Color.clear
                                .frame(width: 45, height: 45)

                            Image("logo")
                                .resizable()
                                .scaledToFit()
                                .frame(height: 48)
                                .opacity(0.95)
                                .modifier(ReflectDarkModeInvertImage())

                            ZStack {
                                FulfillmentInteractiveRadar(
                                    metrics: animatedMetrics,
                                    selectedIndex: .constant(0),
                                    onManualSelect: {},
                                    enableInteraction: false,
                                    customDotDiameter: 10,
                                    showOutline: false,
                                    emphasizeSelectedSlice: false
                                )
                                .rotationEffect(.degrees(rotationDegrees))
                            }
                            .frame(width: 45, height: 45)
                            .scaleEffect(radarScale)
                            .opacity(radarOpacity)
                        }
                        .position(x: geo.size.width / 2, y: animationCenterY)
                    }
                }
            }
        }
        .onAppear {
            celebrationAnimationStartDate = .now
        }
    }

    private var insightsStep: some View {
        guard let snapshot = insightsSnapshot else {
            return AnyView(insightsSkeletonStep)
        }
        return AnyView(
        VStack(spacing: 12) {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        summaryTile(title: "Tasks Done", value: "\(Int(snapshot.completionRatio * 100))%", detail: "\(snapshot.doneCount)/\(max(snapshot.totalActions, 1)) done")
                        summaryTile(title: "Carried Actions", value: "\(Int(snapshot.carriedRatio * 100))%", detail: "\(snapshot.carriedCount)/\(max(snapshot.totalActions, 1)) carried")
                    }

                    HStack(spacing: 10) {
                        summaryTile(title: "Started", value: shortDate(snapshot.startedAt), detail: "Completed: \(shortDate(snapshot.completedAt))")
                        summaryTile(title: "Elapsed", value: "\(snapshot.completionDayCount)d", detail: "from start to complete")
                    }

                    if shouldShowReadableInsightsCard {
                        ReflectReadableInsightsCallout(
                            message: readableInsightsCardMessage,
                            isLoading: readableInsightsLoading,
                            fulfillmentHighlights: snapshot.fulfillmentAreaRows.map { ($0.title, $0.color) },
                            outcomeHighlights: snapshot.outcomeRows.map { ($0.title, $0.color) }
                        )
                    }

                    if snapshot.productiveSignals.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Productive signals")
                                .font(.headline)
                            ForEach(snapshot.productiveSignals, id: \.id) { row in
                                productiveSignalCountRow(row)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Productive days")
                            .font(.headline)
                        HStack(spacing: 12) {
                            chartLegendChip(color: .blue, label: "Done")
                            chartLegendChip(color: .gray, label: "Didn't need to be done")
                        }
                        .font(.caption)

                        if shouldRenderInsightsCharts {
                            Chart(snapshot.productiveDayRows) { row in
                                BarMark(
                                    x: .value("Day", row.dayLabel),
                                    y: .value("Done", row.done)
                                )
                                .foregroundStyle(Color.blue.gradient)

                                BarMark(
                                    x: .value("Day", row.dayLabel),
                                    y: .value("Didn't need", row.notNeeded)
                                )
                                .foregroundStyle(Color.gray.gradient)
                            }
                            .frame(height: 180)
                        } else {
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .fill(Color.primary.opacity(0.05))
                                .frame(height: 180)
                                .overlay {
                                    ProgressView()
                                        .tint(.secondary)
                                }
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Characteristics")
                            .font(.headline)
                        ForEach(snapshot.flowProfileRows, id: \.0) { row in
                            metricCapsuleRow(title: row.0, value: row.1, tint: row.2)
                        }
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    if !snapshot.fulfillmentAreaRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Fulfillment Areas")
                                .font(.headline)
                            Text("Projection score impact from Action Plan completion.")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            ForEach(snapshot.fulfillmentAreaRows, id: \.self) { row in
                                fulfillmentAreaMetricRow(
                                    title: row.title,
                                    value: row.doneCount,
                                    textColor: row.color,
                                    tint: row.color.opacity(0.22),
                                    delta: row.actionBlockProjectedDelta
                                )
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !snapshot.outcomeRows.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Outcomes Connected")
                                .font(.headline)
                            ForEach(snapshot.outcomeRows, id: \.id) { outcome in
                                Text(outcome.title)
                                    .font(.subheadline.weight(.bold))
                                    .foregroundStyle(outcome.color)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !snapshot.carriedActionTexts.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Recapture for later")
                                .font(.headline)
                            Text("These will be moved back to your Capture list.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ForEach(snapshot.carriedActionTexts, id: \.self) { actionText in
                                Text("• \(actionText)")
                                    .font(.subheadline)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }
                }
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button {
                    beginContributionFlowOrProceed()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
            }
            .padding(.bottom, 2)
        }
        )
    }

    private var journalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Any thought, feeling, emotion or behavior that is constantly reinforced will become habit. Keep score of your wins. You can be winning when you think you're losing if you don't keep score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Journal (Optional)")
                        .font(.headline)
                    journalTextEditor(
                        text: $achievementsText,
                        placeholder: "What happened? What did I learn? What felt meaningful?",
                        isHighlighted: highlightedMissingJournalFields.contains(.journal)
                    )

                    reflectionPassionsSectionCard
                }
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button {
                    if journalIsValid {
                        handleJournalSaveTapped()
                    } else {
                        showJournalValidationHint()
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(journalIsValid ? .accentColor : Color(.systemGray3))
            }
            .padding(.bottom, 2)
        }
    }

    private func handleHeaderBackTapped() {
        if step == 2 {
            step = 1
        } else {
            onFinish()
        }
    }

    private func handleJournalSaveTapped() {
        if selectedReflectionPassions.isEmpty {
            isShowingNoPassionsSaveConfirm = true
            return
        }
        saveArchiveAndExit()
    }

    private var reflectionPassionsSectionCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passion")
                .font(.headline)

            VStack(spacing: 0) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("What passions were involved?")
                        .foregroundStyle(.primary)
                    Spacer(minLength: 8)
                    Button("Connect Passions") {
                        isShowingReflectionPassionsSheet = true
                    }
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 12)

                if !selectedReflectionPassions.isEmpty {
                    Divider()
                        .padding(.leading, 14)

                    VStack(spacing: 0) {
                        ForEach(Array(selectedReflectionPassions.enumerated()), id: \.element.passion_id) { index, passion in
                            HStack(spacing: 10) {
                                Text("\(displayEmotionLabelReflect(for: passion.emotion)): \(passion.passion)")
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 8)
                                Image(systemName: "checkmark")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.blue)
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 11)

                            if index < selectedReflectionPassions.count - 1 {
                                Divider()
                                    .padding(.leading, 14)
                            }
                        }
                    }
                }
            }
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(colorScheme == .dark ? Color(.secondarySystemGroupedBackground) : Color(.systemGray6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color(.separator).opacity(0.22), lineWidth: 1)
            )
        }
    }

    private var reflectionPassionsSheet: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select 1 or more passions that were involved")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                        .listRowSeparator(.hidden)
                }

                ForEach(passions, id: \.passion_id) { passion in
                    Button {
                        if selectedReflectionPassionIDs.contains(passion.passion_id) {
                            selectedReflectionPassionIDs.remove(passion.passion_id)
                        } else {
                            selectedReflectionPassionIDs.insert(passion.passion_id)
                        }
                    } label: {
                        HStack {
                            Text("\(displayEmotionLabelReflect(for: passion.emotion)): \(passion.passion)")
                                .foregroundStyle(.primary)
                            Spacer()
                            if selectedReflectionPassionIDs.contains(passion.passion_id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Connect Passions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { isShowingReflectionPassionsSheet = false }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var contributionPromptSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 12) {
                    if outcomesForContributionFlow.count > 1 {
                        ProgressView(value: Double(contributionOutcomeIndex + 1), total: Double(outcomesForContributionFlow.count))
                            .tint(.accentColor)
                        Text("\(contributionOutcomeIndex + 1) of \(outcomesForContributionFlow.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Did any of these actions contribute to your outcome progress?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.horizontal, 10)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        if let outcome = currentContributionOutcome {
                            contributionOutcomeCard(outcome)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                        }

                        if !currentContributionDoneActions.isEmpty {
                            HStack {
                                Button(areAllCurrentContributionActionsSelected ? "Unselect All" : "Select All") {
                                    toggleSelectAllCurrentContributionActions()
                                }
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 10)
                        }

                        ForEach(currentContributionDoneActions, id: \.id) { action in
                            Button {
                                if contributionTempSelection.contains(action.id) {
                                    contributionTempSelection.remove(action.id)
                                } else {
                                    contributionTempSelection.insert(action.id)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: contributionTempSelection.contains(action.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(contributionTempSelection.contains(action.id) ? Color.accentColor : Color(.systemGray3))
                                    Text(action.text)
                                        .foregroundStyle(.primary)
                                        .multilineTextAlignment(.leading)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        advanceContributionFlow()
                    } label: {
                        Text("Skip")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                    )

                    Button {
                        saveCurrentContributionSelection()
                        advanceContributionFlow()
                    } label: {
                        Text(contributionOutcomeIndex + 1 < outcomesForContributionFlow.count ? "Next" : "Continue")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Contributing Actions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var otherContributionPromptSheet: some View {
        NavigationStack {
            VStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 10) {
                    if otherContributionChunkQueue.count > 1 {
                        ProgressView(value: Double(otherContributionChunkIndex + 1), total: Double(otherContributionChunkQueue.count))
                            .tint(.accentColor)
                        Text("\(otherContributionChunkIndex + 1) of \(otherContributionChunkQueue.count)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Text("Did this \"Other\" block contribute to any Fulfillment Areas?")
                        .font(.headline)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Text("Select one or more areas, or choose none.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                ScrollView {
                    VStack(alignment: .leading, spacing: 10) {
                        if let chunk = currentOtherContributionChunk {
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Other")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                let actionTexts = weekActions
                                    .filter { $0.plannedChunkId == chunk.id && status(for: $0.id) == .done }
                                    .map(\.text)
                                if actionTexts.isEmpty {
                                    Text("No actions in this block.")
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                } else {
                                    ForEach(actionTexts, id: \.self) { text in
                                        Text("• \(text)")
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                    }
                                }
                            }
                            .padding(10)
                            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                        }

                        ForEach(currentOtherContributionFulfillmentRows, id: \.category_id) { area in
                            Button {
                                if otherContributionTempSelection.contains(area.category_id) {
                                    otherContributionTempSelection.remove(area.category_id)
                                } else {
                                    otherContributionTempSelection.insert(area.category_id)
                                }
                            } label: {
                                HStack(spacing: 10) {
                                    Image(systemName: otherContributionTempSelection.contains(area.category_id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(otherContributionTempSelection.contains(area.category_id) ? Color.accentColor : Color(.systemGray3))
                                    Text(area.category)
                                        .foregroundStyle(.primary)
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .padding(10)
                                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }

                HStack(spacing: 12) {
                    Button {
                        otherContributionTempSelection.removeAll()
                        saveCurrentOtherContributionSelection()
                        advanceOtherContributionFlow()
                    } label: {
                        Text("None")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                    )

                    Button {
                        saveCurrentOtherContributionSelection()
                        advanceOtherContributionFlow()
                    } label: {
                        Text(otherContributionChunkIndex + 1 < otherContributionChunkQueue.count
                             ? "Next"
                             : (otherContributionTempSelection.isEmpty ? "Skip" : "Continue"))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                }
            }
            .padding()
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            .navigationTitle("Other Contribution")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func summaryTile(title: String, value: String, detail: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title3)
                .fontWeight(.bold)
            Text(detail)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func signalRow(icon: String, title: String, value: String) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.secondary)
                .frame(width: 18)
            Text("\(title):")
                .fontWeight(.semibold)
            Text(value)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .font(.subheadline)
    }

    private func productiveSignalCountRow(_ row: InsightsSnapshot.ProductiveSignalRow) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 1) {
                Text(row.label)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(row.typeLabel)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer(minLength: 8)
            HStack(spacing: 8) {
                Text("\(row.count)")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 3)
                    .background(Color(.systemGray5), in: Capsule())
            }
        }
        .padding(.vertical, 2)
    }

    private func metricCapsuleRow(title: String, value: Int, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(tint.opacity(0.2), in: Capsule())
        }
    }

    private func metricCapsuleRowColoredTitle(title: String, value: Int, textColor: Color, tint: Color) -> some View {
        HStack {
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(textColor)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(tint, in: Capsule())
        }
    }

    private func fulfillmentAreaMetricRow(title: String, value: Int, textColor: Color, tint: Color, delta: Double?) -> some View {
        HStack {
            if let delta {
                HStack(spacing: 4) {
                    Text(fulfillmentDeltaGlyph(delta))
                    Text(fulfillmentDeltaText(delta))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(fulfillmentDeltaColor(delta))
            }
            Text(title)
                .font(.subheadline.weight(.bold))
                .foregroundStyle(textColor)
            Spacer()
            Text("\(value)")
                .font(.subheadline)
                .fontWeight(.bold)
                .padding(.horizontal, 10)
                .padding(.vertical, 3)
                .background(tint, in: Capsule())
        }
    }

    private func fulfillmentDeltaText(_ delta: Double) -> String {
        if abs(delta) < 0.05 { return "0.0" }
        return String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
    }

    private func fulfillmentDeltaGlyph(_ delta: Double) -> String {
        if abs(delta) < 0.05 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private func fulfillmentDeltaColor(_ delta: Double) -> Color {
        if abs(delta) < 0.05 { return .secondary }
        return delta > 0 ? .green : .red
    }

    private func chartLegendChip(color: Color, label: String) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(color)
                .frame(width: 8, height: 8)
            Text(label)
                .foregroundStyle(.secondary)
        }
    }

    private func journalTextEditor(text: Binding<String>, placeholder: String, isHighlighted: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(
                    (colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemGray6)),
                    in: RoundedRectangle(cornerRadius: 10)
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isHighlighted ? Color.red : Color.black.opacity(0.12), lineWidth: isHighlighted ? 2 : 1)
                )

            if text.wrappedValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(placeholder)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
    }

    private func showJournalValidationHint() {
        highlightedMissingJournalFields = []
        showSaveHint = false
    }

    private func loadingStylePulsedMetrics(at time: TimeInterval) -> [(String, Color, Double)] {
        let base: [(String, Color, Double)] = [
            ("Area 1", FulfillmentCategoryTheme.color(for: "Career & Business"), 80),
            ("Area 2", FulfillmentCategoryTheme.color(for: "Leadership & Impact"), 65),
            ("Area 3", FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"), 90),
            ("Area 4", FulfillmentCategoryTheme.color(for: "Mind & Meaning"), 75),
            ("Area 5", FulfillmentCategoryTheme.color(for: "Love & Relationships"), 85),
            ("Area 6", FulfillmentCategoryTheme.color(for: "Health & Vitality"), 70),
        ]
        let amplitude: Double = 180
        let speed: Double = 1.6

        return base.enumerated().map { idx, tuple in
            let seed1 = Double((idx * 127 + 311) % 100) / 100.0
            let seed2 = Double((idx * 73 + 97) % 100) / 100.0
            let localAmp = amplitude * (0.9 + seed1 * 0.8)
            let localSpeed = speed * (0.8 + seed2 * 1.2)
            let phase1 = Double(idx) * 0.8 + seed1 * .pi * 2
            let phase2 = Double(idx) * 1.3 + seed2 * .pi
            let delta1 = sin(time * localSpeed + phase1) * localAmp * 0.7
            let delta2 = sin(time * localSpeed * 0.47 + phase2) * localAmp * 0.3
            let value = max(50, min(100, tuple.2 + delta1 + delta2))
            return (tuple.0, tuple.1, value)
        }
    }

    private func status(for actionId: UUID) -> ActionExecutionStatus {
        executionByActionID[actionId]?.status ?? .noAction
    }

    private func topResource(of kind: ActionLeverageKind) -> String? {
        var counts: [String: Int] = [:]
        for action in weekActions where closedStatuses.contains(status(for: action.id)) {
            guard
                let sel = leverageByActionID[action.id],
                let resourceId = sel.resourceId,
                let resource = resourceByID[resourceId],
                resource.kind == kind
            else { continue }
            counts[resource.value, default: 0] += 1
        }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func shortDate(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "EEE, MMM d"
        return fmt.string(from: date)
    }

    private func formatMinutes(_ mins: Int) -> String {
        guard mins > 0 else { return "0m" }
        let hours = mins / 60
        let minutes = mins % 60
        if hours == 0 { return "\(minutes)m" }
        if minutes == 0 { return "\(hours)h" }
        return "\(hours)h \(minutes)m"
    }

    private func saveArchiveAndExit() {
        let stepFourByChunkID: [UUID: PlannedChunkStepFourState] = {
            var map: [UUID: PlannedChunkStepFourState] = [:]
            for row in allStepFourStates {
                if let existing = map[row.plannedChunkId] {
                    if row.updatedAt > existing.updatedAt { map[row.plannedChunkId] = row }
                } else {
                    map[row.plannedChunkId] = row
                }
            }
            return map
        }()

        let archive = ActionBlocksReflectionArchive(
            weekStart: weekStart,
            startedAt: startedAt,
            completedAt: completedAt,
            achievementsText: achievementsText.trimmingCharacters(in: .whitespacesAndNewlines),
            magicMomentsText: "",
            powerQuestionText: ""
        )
        modelContext.insert(archive)
        let reflectionPassionSnapshots = passions
            .filter { selectedReflectionPassionIDs.contains($0.passion_id) }
            .map {
                ReflectionPassionsStore.Snapshot(
                    passionID: $0.passion_id,
                    emotion: $0.emotion,
                    passion: $0.passion
                )
            }
        ReflectionPassionsStore.setSnapshots(reflectionPassionSnapshots, for: archive.id)

        for action in weekActions {
            let define = defineByActionID[action.id]
            let execution = executionByActionID[action.id]
            let leverage = leverageByActionID[action.id]
            let resource = leverage.flatMap { $0.resourceId.flatMap { resourceByID[$0] } }
            let places = (placeIDsByActionID[action.id] ?? []).compactMap { placeByID[$0]?.place }
            let note = noteByActionID[action.id]
            let filesAndLinks = attachmentsByActionID[action.id] ?? []
            let chunk = chunkByID[action.plannedChunkId]
            let step4 = stepFourByChunkID[action.plannedChunkId]

            modelContext.insert(
                ActionBlocksReflectionArchiveAction(
                    archiveId: archive.id,
                    weekStart: weekStart,
                    plannedChunkId: action.plannedChunkId,
                    plannedChunkActionId: action.id,
                    chunkLabel: chunk?.label ?? "",
                    chunkCategory: chunk?.category ?? "",
                    resultText: step4?.resultText,
                    purposeText: step4?.roleNoteText,
                    actionText: action.text,
                    statusRaw: (execution?.status ?? .noAction).rawValue,
                    isMust: define?.isMust ?? false,
                    durationMinutes: define?.timeEstimateMinutes,
                    leverageKindRaw: resource?.kind.rawValue,
                    leverageValue: resource?.value,
                    placeNamesCSV: places.joined(separator: ", "),
                    hasNote: !(note?.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                    linkAttachmentCount: filesAndLinks.filter { $0.kind == .link }.count,
                    fileAttachmentCount: filesAndLinks.filter { $0.kind == .file }.count
                )
            )
            if let chunkCategory = chunk?.category, !chunkCategory.isEmpty {
                FulfillmentCategoryTheme.saveCompletedActionBlockChunkColorKey(
                    FulfillmentCategoryTheme.colorKey(for: chunkCategory),
                    archiveId: archive.id,
                    chunkId: action.plannedChunkId
                )
            }
        }

        let outcomeByID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
        for link in weekOutcomeLinks {
            if let outcome = outcomeByID[link.outcomeId] {
                modelContext.insert(
                    ActionBlocksReflectionArchiveOutcome(
                        archiveId: archive.id,
                        weekStart: weekStart,
                        plannedChunkId: link.plannedChunkId,
                        outcomeId: link.outcomeId,
                        outcomeText: outcome.outcome,
                        category: outcome.category
                    )
                )
            }
        }

        let executionByID = executionByActionID
        let actionByID = Dictionary(uniqueKeysWithValues: weekActions.map { ($0.id, $0) })
        for (outcomeId, selectedActionIDs) in contributionSelectionsByOutcome {
            for actionId in selectedActionIDs {
                guard let action = actionByID[actionId] else { continue }
                let actionCompletedAt = executionByID[actionId]?.updatedAt ?? self.completedAt
                modelContext.insert(
                    ActionBlocksReflectionOutcomeContribution(
                        archiveId: archive.id,
                        weekStart: weekStart,
                        outcomeId: outcomeId,
                        plannedChunkActionId: actionId,
                        actionText: action.text,
                        completedAt: actionCompletedAt
                    )
                )
            }
        }

        let fulfillmentByCategoryID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        for (chunkID, categoryIDs) in otherContributionSelectionsByChunkID {
            for categoryID in categoryIDs {
                guard let fulfillment = fulfillmentByCategoryID[categoryID] else { continue }
                modelContext.insert(
                    ActionBlocksReflectionOtherContribution(
                        archiveId: archive.id,
                        weekStart: weekStart,
                        plannedChunkId: chunkID,
                        categoryId: categoryID,
                        category: fulfillment.category
                    )
                )
            }
        }

        persistCarriedActionProfiles()
        applyIntegratedCaptureFinalStatuses()
        recaptureCarriedActions()
        clearWeekPlanningStateAfterArchive()

        if let active = activePlanStates.first {
            active.isActive = false
            active.weekStart = nil
        }
        ActivePlanSessionStore.setWeekStart(nil)

        try? modelContext.save()
        onFinish()
    }

    private func displayEmotionLabelReflect(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "just": return "Hate"
        case "vows": return "Vow"
        case "thrill": return "Thrill"
        case "love": return "Love"
        default: return raw.capitalized
        }
    }

    private func beginContributionFlowOrProceed() {
        let contributionData = buildContributionFlowData()
        contributionDoneActionsByOutcomeID = contributionData.doneActionsByOutcomeID
        contributionOutcomeQueue = contributionData.queue

        let queue = contributionOutcomeQueue
        guard !queue.isEmpty else {
            beginOtherContributionFlowOrProceed()
            return
        }
        contributionOutcomeIndex = 0
        let firstId = queue[0].outcome_id
        contributionTempSelection = contributionSelectionsByOutcome[firstId] ?? []
        showContributionPrompt = true
    }

    private func saveCurrentContributionSelection() {
        guard let outcome = currentContributionOutcome else { return }
        contributionSelectionsByOutcome[outcome.outcome_id] = contributionTempSelection
    }

    private func advanceContributionFlow() {
        if contributionOutcomeIndex + 1 < outcomesForContributionFlow.count {
            contributionOutcomeIndex += 1
            let nextId = outcomesForContributionFlow[contributionOutcomeIndex].outcome_id
            contributionTempSelection = contributionSelectionsByOutcome[nextId] ?? []
        } else {
            showContributionPrompt = false
            beginOtherContributionFlowOrProceed()
        }
    }

    private func beginOtherContributionFlowOrProceed() {
        let queue = otherLabeledChunksForContribution
        guard !queue.isEmpty else {
            step = 2
            return
        }
        otherContributionChunkQueue = queue
        otherContributionChunkIndex = 0
        let firstChunkID = queue[0].id
        otherContributionTempSelection = otherContributionSelectionsByChunkID[firstChunkID] ?? []
        showOtherContributionPrompt = true
    }

    private var otherLabeledChunksForContribution: [PlannedChunk] {
        let selections = Dictionary(grouping: allChunkSelections, by: \.chunkIndex)
            .compactMapValues { rows in rows.max(by: { $0.updatedAt < $1.updatedAt }) }
        return weekChunks.filter { chunk in
            guard let selection = selections[chunk.chunkIndex] else { return false }
            return selection.labelId == PlanOtherLabel.id ||
                selection.label?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
        }
        .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private func saveCurrentOtherContributionSelection() {
        guard let chunk = currentOtherContributionChunk else { return }
        otherContributionSelectionsByChunkID[chunk.id] = otherContributionTempSelection
    }

    private func advanceOtherContributionFlow() {
        if otherContributionChunkIndex + 1 < otherContributionChunkQueue.count {
            otherContributionChunkIndex += 1
            let nextChunkID = otherContributionChunkQueue[otherContributionChunkIndex].id
            otherContributionTempSelection = otherContributionSelectionsByChunkID[nextChunkID] ?? []
        } else {
            showOtherContributionPrompt = false
            step = 2
        }
    }

    private func buildContributionFlowData() -> (queue: [Outcomes], doneActionsByOutcomeID: [UUID: [PlannedChunkAction]]) {
        let executionByID = executionByActionID
        let doneActions = weekActions.filter { executionByID[$0.id]?.status == .done }
        let doneActionsByChunkID = Dictionary(grouping: doneActions, by: \.plannedChunkId)
        let linksByOutcome = Dictionary(grouping: weekOutcomeLinks, by: \.outcomeId)

        var queue: [Outcomes] = []
        var map: [UUID: [PlannedChunkAction]] = [:]

        for outcome in outcomesForWeek {
            let links = linksByOutcome[outcome.outcome_id] ?? []
            var seenActionIDs: Set<UUID> = []
            var actions: [PlannedChunkAction] = []
            for link in links {
                for action in doneActionsByChunkID[link.plannedChunkId] ?? [] {
                    if seenActionIDs.insert(action.id).inserted {
                        actions.append(action)
                    }
                }
            }

            if !actions.isEmpty {
                queue.append(outcome)
                map[outcome.outcome_id] = actions
            }
        }

        return (queue, map)
    }

    private func toggleSelectAllCurrentContributionActions() {
        let ids = currentContributionActionIDs
        guard !ids.isEmpty else { return }
        if areAllCurrentContributionActionsSelected {
            contributionTempSelection.subtract(ids)
        } else {
            contributionTempSelection.formUnion(ids)
        }
    }

    private func categoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.color(for: category)
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: category)
    }

    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
        return components.day ?? 0
    }

    private func latestMeasure(for outcome: Outcomes) -> OutcomesMeasure? {
        outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
    }

    private func startMeasure(for outcome: Outcomes, latestMeasure: OutcomesMeasure?) -> Double? {
        if let first = outcomeMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id }) {
            return first.measure
        }
        return latestMeasure?.measure
    }

    private func startMeasuredAt(for outcome: Outcomes, latestMeasure: OutcomesMeasure?) -> Date? {
        if let first = outcomeMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id }) {
            return first.measuredAt
        }
        return latestMeasure?.measuredAt
    }

    @ViewBuilder
    private func contributionOutcomeCard(_ outcome: Outcomes) -> some View {
        let measure = latestMeasure(for: outcome)
        let start = startMeasure(for: outcome, latestMeasure: measure)
        let startDate = startMeasuredAt(for: outcome, latestMeasure: measure)

        VStack(alignment: .leading, spacing: 8) {
            Text(outcome.outcome)
                .font(.title3)
                .fontWeight(.semibold)
                .foregroundStyle(categoryColor(for: outcome.category))
                .lineLimit(3)

            if !outcome.reasons.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(outcome.reasons)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(4)
                    .padding(.bottom, 2)
            }

            HStack(spacing: 8) {
                let remainingDays = daysUntil(outcome.end)
                VStack(spacing: 2) {
                    Text("\(remainingDays)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(remainingDays < 0 ? .red : .black)
                    Text("days left")
                        .font(.caption2)
                        .foregroundColor(remainingDays < 0 ? .red : .black)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lightenedCategoryColor(for: outcome.category))
                )
                .frame(height: 44)

                if let measure, measure.measure_amt != 0, measure.format != nil {
                    let isStarting = startDate.map {
                        Calendar.current.isDate($0, inSameDayAs: measure.measuredAt)
                    } ?? false
                    MeasurableOutcomeBox(
                        measure: measure.measure,
                        measuredAt: measure.measuredAt,
                        measureAmt: measure.measure_amt,
                        endDate: outcome.end,
                        format: measure.format ?? "Number",
                        statusPrefix: isStarting ? "started" : "updated"
                    )
                    .frame(height: 44)

                    ProgressCircleView(
                        measure: measure.measure,
                        measureAmt: measure.measure_amt,
                        startMeasure: start
                    )
                    .frame(width: 40, height: 40)
                }
            }
        }
    }

    private func recaptureCarriedActions() {
        var existingByKey: [String: RollingCaptureItem] = [:]
        for item in captureItems {
            let key = normalized(item.text)
            if !key.isEmpty, existingByKey[key] == nil {
                existingByKey[key] = item
            }
        }
        var seen = Set(existingByKey.keys)
        for action in carriedActions {
            let text = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = normalized(text)
            let profile = ActionCarryProfileStore.load(for: text)
            if let existing = existingByKey[key] {
                existing.leverageKindRaw = profile?.leverageKindRaw
                existing.leverageValue = profile?.leverageValue
                seen.insert(key)
                continue
            }
            guard !seen.contains(key) else { continue }
            modelContext.insert(
                RollingCaptureItem(
                    text: text,
                    isGhost: false,
                    createdAt: .now,
                    sourceType: action.sourceType,
                    leverageKindRaw: profile?.leverageKindRaw,
                    leverageValue: profile?.leverageValue
                )
            )
            seen.insert(key)
        }
    }

    private func persistCarriedActionProfiles() {
        for action in weekActions {
            let actionText = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !actionText.isEmpty else { continue }
            let finalStatus = status(for: action.id)

            switch finalStatus {
            case .carriedToCapture:
                ActionCarryProfileStore.save(
                    for: actionText,
                    profile: carriedProfile(for: action.id)
                )
            case .notNeeded:
                ActionCarryProfileStore.remove(for: actionText)
            default:
                continue
            }
        }
    }

    private func carriedProfile(for actionId: UUID) -> CarriedActionProfile {
        let define = defineByActionID[actionId]
        let leverage = leverageByActionID[actionId]
        let resource = leverage.flatMap { $0.resourceId.flatMap { resourceByID[$0] } }
        let placeNames = (placeIDsByActionID[actionId] ?? [])
            .compactMap { placeByID[$0]?.place.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let noteText = noteByActionID[actionId]?.noteText ?? ""
        let attachments = (attachmentsByActionID[actionId] ?? []).map { attachment in
            CarriedActionAttachmentSnapshot(
                kindRaw: attachment.kindRaw,
                urlString: attachment.urlString,
                fileName: attachment.fileName,
                fileBookmarkData: attachment.fileBookmarkData
            )
        }

        return CarriedActionProfile(
            isMust: define?.isMust ?? false,
            timeEstimateMinutes: define?.timeEstimateMinutes,
            sensitiveMorning: define?.sensitiveMorning ?? true,
            sensitiveAfternoon: define?.sensitiveAfternoon ?? true,
            sensitiveEvening: define?.sensitiveEvening ?? true,
            leverageKindRaw: resource?.kind.rawValue,
            leverageValue: resource?.value,
            placeNames: placeNames,
            noteText: noteText,
            attachments: attachments,
            updatedAtUnix: Date().timeIntervalSince1970
        )
    }

    private enum ExternalMutationAction {
        case complete
        case delete
    }

    private func applyIntegratedCaptureFinalStatuses() {
        var actionByNormalizedText: [String: PlannedChunkAction] = [:]
        for action in weekActions {
            let key = normalized(action.text)
            if actionByNormalizedText[key] == nil {
                actionByNormalizedText[key] = action
            }
        }

        for item in captureItems {
            guard let sourceType = item.sourceType, !sourceType.isEmpty else { continue }
            let key = normalized(item.text)
            guard let action = actionByNormalizedText[key] else { continue }
            let finalStatus = status(for: action.id)

            switch finalStatus {
            case .done:
                applyExternalSourceMutationIfNeeded(for: item, action: .complete)
                RecentlyDeletedStore.trash(item, in: modelContext)
            case .notNeeded:
                applyExternalSourceMutationIfNeeded(for: item, action: .delete)
                RecentlyDeletedStore.trash(item, in: modelContext)
            case .carriedToCapture:
                item.isGhost = false
                item.unhideDate = nil
                item.unhiddenAt = .now
            default:
                break
            }
        }
    }

    private func applyExternalSourceMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let sourceType = item.sourceType else { return }
        switch sourceType {
        case "apple_reminder":
            applyAppleReminderMutationIfNeeded(for: item, action: action)
        case "google_tasks":
            applyGoogleTaskMutationIfNeeded(for: item, action: action)
        case "microsoft_todo":
            applyMicrosoftTodoMutationIfNeeded(for: item, action: action)
        default:
            break
        }
    }

    private func applyAppleReminderMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard let externalID = item.sourceExternalID, !externalID.isEmpty else { return }
        #if canImport(EventKit)
        let store = EKEventStore()
        let runMutation: (Bool) -> Void = { granted in
            guard granted else { return }
            guard let reminder = store.calendarItem(withIdentifier: externalID) as? EKReminder else { return }
            do {
                switch action {
                case .complete:
                    reminder.isCompleted = true
                    reminder.completionDate = Date()
                    try store.save(reminder, commit: true)
                case .delete:
                    try store.remove(reminder, commit: true)
                }
            } catch {
                // Best-effort write-back.
            }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in
                runMutation(granted)
            }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in
                runMutation(granted)
            }
        }
        #endif
    }

    private func applyGoogleTaskMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard !googleTasksAccessToken.isEmpty else { return }
        guard let externalID = item.sourceExternalID else { return }
        let parts = externalID.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let listID = parts[0]
        let taskID = parts[1]
        Task { await performGoogleTaskMutation(accessToken: googleTasksAccessToken, listID: listID, taskID: taskID, action: action) }
    }

    private func performGoogleTaskMutation(
        accessToken: String,
        listID: String,
        taskID: String,
        action: ExternalMutationAction
    ) async {
        guard
            let listEncoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let taskEncoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://tasks.googleapis.com/tasks/v1/lists/\(listEncoded)/tasks/\(taskEncoded)")
        else { return }

        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        switch action {
        case .complete:
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = [
                "status": "completed",
                "completed": ISO8601DateFormatter().string(from: Date())
            ]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        case .delete:
            request.httpMethod = "DELETE"
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    private func applyMicrosoftTodoMutationIfNeeded(for item: RollingCaptureItem, action: ExternalMutationAction) {
        guard !microsoftTodoAccessToken.isEmpty else { return }
        guard let externalID = item.sourceExternalID else { return }
        let parts = externalID.split(separator: "|", maxSplits: 1).map(String.init)
        guard parts.count == 2 else { return }
        let listID = parts[0]
        let taskID = parts[1]
        Task {
            await performMicrosoftTodoMutation(
                accessToken: microsoftTodoAccessToken,
                listID: listID,
                taskID: taskID,
                action: action
            )
        }
    }

    private func performMicrosoftTodoMutation(
        accessToken: String,
        listID: String,
        taskID: String,
        action: ExternalMutationAction
    ) async {
        guard
            let listEncoded = listID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let taskEncoded = taskID.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
            let url = URL(string: "https://graph.microsoft.com/v1.0/me/todo/lists/\(listEncoded)/tasks/\(taskEncoded)")
        else { return }
        var request = URLRequest(url: url)
        request.setValue("Bearer \(accessToken)", forHTTPHeaderField: "Authorization")

        switch action {
        case .complete:
            request.httpMethod = "PATCH"
            request.setValue("application/json", forHTTPHeaderField: "Content-Type")
            let body: [String: String] = ["status": "completed"]
            request.httpBody = try? JSONSerialization.data(withJSONObject: body)
            _ = try? await URLSession.shared.data(for: request)
        case .delete:
            request.httpMethod = "DELETE"
            _ = try? await URLSession.shared.data(for: request)
        }
    }

    /// Archive is persisted first, then active-week planning/action rows are cleared
    /// so a fresh PlanView session does not reuse completed Action Blocks data.
    private func clearWeekPlanningStateAfterArchive() {
        for row in allChunkSelections { RecentlyDeletedStore.trash(row, in: modelContext) }
        for row in allStepFourStates { RecentlyDeletedStore.trash(row, in: modelContext) }
        for row in allOutcomeLinks { RecentlyDeletedStore.trash(row, in: modelContext) }
        for row in allAdHocMarkers { RecentlyDeletedStore.trash(row, in: modelContext) }

        for row in allActions { RecentlyDeletedStore.trash(row, in: modelContext) }
        for row in allChunks { RecentlyDeletedStore.trash(row, in: modelContext) }
    }

    private func normalized(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func limitedReadableInsightsText(_ text: String, maxCharacters: Int) -> String {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count > maxCharacters else { return trimmed }
        let cutoffIndex = trimmed.index(trimmed.startIndex, offsetBy: maxCharacters)
        let prefix = String(trimmed[..<cutoffIndex]).trimmingCharacters(in: .whitespacesAndNewlines)

        // Prefer a complete sentence within the limit.
        if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
            let sentence = String(prefix[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !sentence.isEmpty {
                return sentence
            }
        }

        // Otherwise trim at natural punctuation/word boundary and close the sentence.
        if let naturalBreak = prefix.lastIndex(where: { ",;:".contains($0) }) {
            let base = String(prefix[..<naturalBreak]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty { return base + "." }
        }
        if let lastSpace = prefix.lastIndex(of: " "), lastSpace > prefix.startIndex {
            let base = String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
            if !base.isEmpty { return base + "." }
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines) + "."
    }
}

private struct ProductiveDayRow: Identifiable {
    let id = UUID()
    let dayLabel: String
    let done: Int
    let notNeeded: Int
}

private struct ReflectReadableInsightsCallout: View {
    let message: String
    let isLoading: Bool
    let fulfillmentHighlights: [(name: String, color: Color)]
    let outcomeHighlights: [(name: String, color: Color)]
    @State private var outlineAngle: Double = 0

    private var outlineGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(outlineAngle)
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("LoomAI")
                .resizable()
                .scaledToFit()
                .frame(width: 28, height: 28)

            if isLoading {
                ReflectLoomTypingDotsIndicator()
                    .frame(height: 20)
            } else {
                Text(styledMessage)
                    .font(.subheadline)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(outlineGradient.opacity(0.95), lineWidth: 2)
        )
        .onAppear {
            guard outlineAngle == 0 else { return }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                outlineAngle = 360
            }
        }
    }

    private var styledMessage: AttributedString {
        var attributed = AttributedString(message)
        let source = message

        func applyHighlights(_ items: [(name: String, color: Color)]) {
            for item in items
                .map({ ($0.name.trimmingCharacters(in: .whitespacesAndNewlines), $0.color) })
                .filter({ !$0.0.isEmpty })
                .sorted(by: { $0.0.count > $1.0.count }) {
                var searchRange = source.startIndex..<source.endIndex
                while let found = source.range(
                    of: item.0,
                    options: [.caseInsensitive, .diacriticInsensitive],
                    range: searchRange
                ) {
                    if let attrRange = Range(found, in: attributed) {
                        attributed[attrRange].font = .subheadline.bold()
                        attributed[attrRange].foregroundColor = item.1
                    }
                    searchRange = found.upperBound..<source.endIndex
                }
            }
        }

        // Outcomes first so more specific titles win if they overlap area names.
        applyHighlights(outcomeHighlights)
        applyHighlights(fulfillmentHighlights)
        return attributed
    }
}

private struct ReflectLoomTypingDotsIndicator: View {
    @State private var activeIndex: Int = 0

    private let colors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95)
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { idx, color in
                Circle()
                    .fill(color.opacity(activeIndex == idx ? 1 : 0.35))
                    .frame(width: 6, height: 6)
                    .scaleEffect(activeIndex == idx ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
            }
        }
        .onAppear {
            guard activeIndex == 0 else { return }
            animate()
        }
    }

    private func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            activeIndex = (activeIndex + 1) % colors.count
            animate()
        }
    }
}

struct ReflectionLoadingStyleLinesBackground: View {
    let colors: [Color]
    let focusXFraction: CGFloat
    let focusYFraction: CGFloat
    let radarDiameter: CGFloat
    let rightSideTargetBandFraction: Double

    private let lineCount: Int = 25
    private let leftInset: CGFloat = -40
    private let verticalBandFraction: Double = 0.342
    private let verticalShift: CGFloat = 0

    private let funnelMinScale: CGFloat = 0.44
    private let funnelCurve: CGFloat = 1.55
    private let radarCircleExtraDiameter: CGFloat = 18

    init(
        colors: [Color],
        focusXFraction: CGFloat,
        focusYFraction: CGFloat,
        radarDiameter: CGFloat,
        rightSideTargetBandFraction: Double = 0
    ) {
        self.colors = colors
        self.focusXFraction = focusXFraction
        self.focusYFraction = focusYFraction
        self.radarDiameter = radarDiameter
        self.rightSideTargetBandFraction = rightSideTargetBandFraction
    }

    private func rand(_ seed: Int, _ a: Double, _ b: Double) -> Double {
        let seedD = Double(seed)
        let x = sin(seedD * 12.9898) * 43758.5453
        let u = x - floor(x)
        return a + (b - a) * u
    }

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                let size = geo.size
                let focusX = size.width * focusXFraction
                let centerPoint = CGPoint(x: focusX, y: size.height * focusYFraction)

                Canvas { ctx, sz in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let colorCount = max(1, colors.count)
                    let centerX: CGFloat = centerPoint.x
                    let centerY: CGFloat = centerPoint.y
                    let perimeterInset: CGFloat = 44
                    let perimeterRect = CGRect(
                        x: -perimeterInset,
                        y: -perimeterInset,
                        width: sz.width + (perimeterInset * 2),
                        height: sz.height + (perimeterInset * 2)
                    )
                    let perimeterLength = max(1, (perimeterRect.width + perimeterRect.height) * 2)

                    func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
                        let tt = min(max((x - a) / (b - a), 0), 1)
                        return tt * tt * (3 - 2 * tt)
                    }

                    func pointOnPerimeter(_ u: Double) -> CGPoint {
                        let frac = ((u.truncatingRemainder(dividingBy: 1)) + 1).truncatingRemainder(dividingBy: 1)
                        let d = CGFloat(frac) * perimeterLength
                        let top = perimeterRect.width
                        let right = perimeterRect.height
                        let bottom = perimeterRect.width
                        let left = perimeterRect.height

                        switch d {
                        case 0..<top:
                            return CGPoint(x: perimeterRect.minX + d, y: perimeterRect.minY)
                        case top..<(top + right):
                            return CGPoint(x: perimeterRect.maxX, y: perimeterRect.minY + (d - top))
                        case (top + right)..<(top + right + bottom):
                            return CGPoint(x: perimeterRect.maxX - (d - top - right), y: perimeterRect.maxY)
                        default:
                            let rem = min(left, d - top - right - bottom)
                            return CGPoint(x: perimeterRect.minX, y: perimeterRect.maxY - rem)
                        }
                    }

                    func applyDepthPerspective(to point: CGPoint, progress s: CGFloat) -> CGPoint {
                        // Start of each line feels closer (slightly expanded from center),
                        // end of each line feels farther (slightly compressed toward center).
                        let depthT = smoothstep(0.0, 1.0, s)
                        let scale = 1.10 - (depthT * 0.24) // ~1.10 at perimeter -> ~0.86 near center
                        return CGPoint(
                            x: centerX + (point.x - centerX) * scale,
                            y: centerY + (point.y - centerY) * scale
                        )
                    }

                    for i in 0..<lineCount {
                        let band = max(0.05, min(verticalBandFraction, 1.0))
                        let bandStart = 0.5 - band / 2.0
                        let localFracBase = (Double(i) + 0.5) / Double(lineCount)
                        let jitter = rand(i * 19 + 7, -0.03, 0.03)
                        let localFrac = min(max(localFracBase + jitter, 0.0), 1.0)
                        _ = bandStart + band * localFrac

                        let startPerimeterFrac = localFracBase + rand(i * 41 + 21, -0.08, 0.08)
                        let startPoint = pointOnPerimeter(startPerimeterFrac)

                        let centerBand = max(0.0, min(rightSideTargetBandFraction, 1.0))
                        let centerRingRadius = min(
                            min(sz.width, sz.height) * 0.49,
                            max(
                                8,
                                (min(sz.width, sz.height) * CGFloat(centerBand) * 0.52) * 12.0
                            )
                        ) * 0.3
                        let endAngle = atan2(
                            Double(startPoint.y - centerY),
                            Double(startPoint.x - centerX)
                        )
                        let endPoint = CGPoint(
                            x: centerX + cos(endAngle) * centerRingRadius,
                            y: centerY + sin(endAngle) * centerRingRadius
                        )

                        let color = colors[i % colorCount]
                        let dx = endPoint.x - startPoint.x
                        let dy = endPoint.y - startPoint.y
                        let distance = max(1, sqrt((dx * dx) + (dy * dy)))
                        let nx = -dy / distance
                        let ny = dx / distance

                        let speed = rand(i * 13 + 1, 0.18, 0.36)
                        let phase = rand(i * 17 + 3, 0.0, 1.0)
                        let posFrac = (t * speed + phase).truncatingRemainder(dividingBy: 1)

                        let amp = rand(i * 23 + 5, 34.0, 82.0) // larger vertical travel for more pronounced waves
                        let freq = rand(i * 29 + 9, 2.4, 6.2)
                        let sigma = rand(i * 31 + 11, 0.08, 0.16)
                        let wobblePhase = rand(i * 37 + 13, 0.0, 2 * .pi)

                        func smoothstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
                            let tt = min(max((x - a) / (b - a), 0), 1)
                            return tt * tt * (3 - 2 * tt)
                        }

                        var path = Path()
                        let samples = 64
                        for j in 0...samples {
                            let twoPi = 2.0 * Double.pi
                            let s = Double(j) / Double(samples)

                            let diff = (s - posFrac) / sigma
                            let envelope = exp(-pow(diff, 2) * 2)
                            let pulseArg = twoPi * (s * freq - t * speed * 0.6) + wobblePhase
                            let pulse = sin(pulseArg) * amp * envelope
                            let swellArg = twoPi * (s * (freq * 0.45) + t * speed * 0.25) + wobblePhase * 0.7
                            let swell = sin(swellArg) * (amp * 0.6)
                            let wiggle = (pulse + swell) * sin(Double.pi * s) * 0.62

                            let baseLineX = startPoint.x + dx * CGFloat(s)
                            let baseLineY = startPoint.y + dy * CGFloat(s)
                            var x = baseLineX + nx * CGFloat(wiggle)
                            var y = baseLineY + ny * CGFloat(wiggle)

                            let rawBendT = smoothstep(0.05, 0.82, CGFloat(s))
                            let bendT = pow(rawBendT, 0.55)
                            let steerX = x + (centerX - x) * (bendT * 0.22)
                            let steerY = y + (centerY - y) * (bendT * 0.45)
                            let pinchT = smoothstep(0.84, 1.0, CGFloat(s))
                            let pinchCurve = pow(pinchT, funnelCurve)
                            let attractT = smoothstep(0.78, 1.0, CGFloat(s))
                            let attractorX = centerX + (endPoint.x - centerX) * attractT
                            let attractorY = centerY + (endPoint.y - centerY) * attractT
                            let lateScale = (1.0 - pinchCurve) + pinchCurve * funnelMinScale
                            x = attractorX + (steerX - attractorX) * lateScale
                            y = attractorY + (steerY - attractorY) * lateScale
                            if j == 0 {
                                x = startPoint.x
                                y = startPoint.y
                            }

                            let point = applyDepthPerspective(
                                to: CGPoint(x: x, y: y),
                                progress: CGFloat(s)
                            )
                            if j == 0 { path.move(to: point) } else { path.addLine(to: point) }
                        }

                        let tailStartFrac: CGFloat = 0.72
                        let baseOpacity: Double = 0.11
                        let tailGradient = Gradient(stops: [
                            .init(color: color.opacity(baseOpacity), location: 0.0),
                            .init(color: color.opacity(baseOpacity * 0.72), location: Double(tailStartFrac)),
                            .init(color: color.opacity(baseOpacity * 0.15), location: 0.84),
                            .init(color: color.opacity(baseOpacity * 0.03), location: 0.92),
                            .init(color: color.opacity(0.0), location: 1.0),
                        ])
                        ctx.stroke(
                            path,
                            with: .linearGradient(
                                tailGradient,
                                startPoint: startPoint,
                                endPoint: endPoint
                            ),
                            lineWidth: 300
                        )

                        let tailFactorAtGlow = pow(max(0, 1.0 - smoothstepD(Double(tailStartFrac), 1.0, posFrac)), 2.8)
                        let glowPeak = 0.08 * tailFactorAtGlow
                        let glowHalfWidth = sigma * 0.8
                        let startStop = max(0.0, posFrac - glowHalfWidth)
                        let endStop = min(1.0, posFrac + glowHalfWidth)
                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(0.0), location: startStop),
                            .init(color: color.opacity(glowPeak), location: posFrac),
                            .init(color: color.opacity(0.0), location: endStop),
                        ])
                        let gradStart = startPoint
                        let gradEnd = endPoint

                        ctx.drawLayer { layer in
                            layer.addFilter(.blur(radius: 5))
                            layer.stroke(path, with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd), lineWidth: 360)
                        }
                        ctx.drawLayer { layer in
                            layer.addFilter(.blur(radius: 1.5))
                            layer.stroke(path, with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd), lineWidth: 180)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .mask {
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                if radarDiameter <= 0 {
                    Rectangle()
                        .fill(Color.white)
                } else {
                let focusX = w * focusXFraction
                let circleRadius = (radarDiameter + radarCircleExtraDiameter) / 2
                let startX = leftInset
                let endX = max(startX + 40, min(w + 24, focusX - circleRadius + 24))
                let lineLength = max(1, endX - startX)
                let fadeStartX = endX - (lineLength * 0.48) // longer fade run before the radar

                let fadeStart = max(0, min(1, fadeStartX / w))
                let fadeMid = max(fadeStart, min(1, (endX - (lineLength * 0.16)) / w))
                let fadeEnd = max(fadeMid, min(1, endX / w))
                LinearGradient(
                    stops: [
                        .init(color: .white, location: 0.0),
                        .init(color: .white, location: fadeStart),
                        .init(color: .white.opacity(0.18), location: fadeMid),
                        .init(color: .clear, location: fadeEnd),
                        .init(color: .clear, location: 1.0),
                    ],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                }
            }
        }
    }
}
