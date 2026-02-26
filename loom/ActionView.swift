import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif
#if canImport(EventKit)
import EventKit
#endif

private struct PlannedActionDueSnapshot: Codable {
    let dueDate: Date
    let attentionDays: Int
}

private struct ActionViewSourceDueDateOverrideRecord: Codable {
    let hasDueDate: Bool
    let dueDateUnix: TimeInterval
}

struct ActionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query private var allChunks: [PlannedChunk]
    @Query private var allActions: [PlannedChunkAction]
    @Query private var stepFourStates: [PlannedChunkStepFourState]
    @Query private var outcomeLinks: [PlannedChunkOutcomeLink]

    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    @Query private var defineStates: [PlannedChunkActionDefineState]
    @Query private var executionStates: [PlannedChunkActionExecutionState]
    @Query private var leverageSelections: [PlannedChunkActionLeverageSelection]

    @Query(sort: \LeverageResource.createdAt, order: .forward)
    private var leverageCatalog: [LeverageResource]

    @Query private var placeLinks: [PlannedChunkActionSensitivityPlaceLink]

    @Query(sort: \SensitivityPlaceCatalogItem.place, order: .forward)
    private var placesCatalog: [SensitivityPlaceCatalogItem]

    @Query private var notes: [PlannedChunkActionNote]
    @Query private var attachments: [PlannedChunkActionAttachment]
    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse)
    private var weeklyMindsetEntries: [WeeklyMindsetEntry.Fields]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var captureItems: [RollingCaptureItem]
    @Query(sort: \RecurringCaptureRule.createdAt, order: .reverse)
    private var recurringRules: [RecurringCaptureRule]
    @Query(sort: \RecurringCaptureDispatch.sentAt, order: .reverse)
    private var recurringDispatches: [RecurringCaptureDispatch]
    @Query(sort: \ActivePlanState.id, order: .forward)
    private var activePlanStates: [ActivePlanState]
    @AppStorage("capture_default_due_date_attention_days")
    private var dueDateAttentionDays: Int = 7
    @AppStorage("capture_source_due_date_overrides_json")
    private var sourceDueDateOverridesJSON: String = "{}"
    @AppStorage("action_collapsed_metrics_use_percentage")
    private var collapsedMetricsUsePercentage: Bool = false
    @AppStorage("dev_manual_warning_cards_enabled")
    private var devManualWarningCardsEnabled: Bool = false
    @AppStorage("dev_action_blocks_warning_old_blocks")
    private var devActionBlocksWarningOldBlocks: Bool = false

    @State private var isShowingInstructions: Bool = false
    @State private var openFilter: FilterMenu? = nil
    @State private var selectedPlaceIDs: Set<UUID> = []
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var selectedToolIDs: Set<UUID> = []
    @State private var selectedTimeOfDay: Set<TimeOfDayChoice> = []
    @State private var selectedDurations: Set<Int> = []
    @State private var selectedAttachmentKinds: Set<ActionAttachmentFilterKind> = []
    @State private var onlyMusts: Bool = false

    @State private var inactiveOnly: Bool = false
    @State private var leveragedOnly: Bool = false
    @State private var inProgressOnly: Bool = false

    @State private var durationActionID: ActionSheetID? = nil
    @State private var leverageActionID: ActionSheetID? = nil
    @State private var sensitivityActionID: ActionSheetID? = nil
    @State private var attachmentsActionID: ActionSheetID? = nil
    @State private var actionStatusActionID: ActionSheetID? = nil
    @State private var leverageDueDatePromptActionID: UUID? = nil
    @State private var pendingLeveragedStatusActionID: UUID? = nil
    @State private var showCheckmarkLimitAlert: Bool = false
    @State private var autosaveTask: Task<Void, Never>? = nil
    @State private var isHeaderCollapsed: Bool = false
    @State private var dismissActionBlocksCautionCard: Bool = false
    @State private var lastScrollY: CGFloat = 0
    @State private var lastScrollTimestamp: TimeInterval = Date().timeIntervalSinceReferenceDate
    @State private var isKeyboardVisible: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var focusedActionID: UUID? = nil
    @State private var scrollTargetActionID: UUID? = nil
    @State private var pendingChunkScrollAnchor: String? = nil
    @State private var pendingExpandChunkTopAnchor: String? = nil
    @State private var pendingFocusActionID: UUID? = nil
    @State private var pendingNewActionIDs: Set<UUID> = []
    @State private var pendingDurationDefaultActionID: UUID? = nil
    @State private var addActionChunkID: ChunkActionAddSheetID? = nil
    @State private var rearrangeActionsSheetID: RearrangeActionsSheetID? = nil
    @State private var areAllActionBlocksCollapsed: Bool = false
    @State private var localChunkOrderIDs: [UUID] = []
    @State private var draggedChunkID: UUID? = nil
    @State private var draggedActionID: UUID? = nil
    @State private var draggedActionChunkID: UUID? = nil
    @State private var localActionOrderIDs: [UUID] = []
    @State private var highlightedStatusActionIDs: Set<UUID> = []
    @State private var showCompleteHint: Bool = false
    @State private var showReflectionFlow: Bool = false
    @State private var dismissActionViewAfterReflect: Bool = false
    @State private var deferredPersistor = ActionDeferredPersistor()
    @State private var carriedProfileAppliedActionIDs: Set<UUID> = []
    private let weekStart: Date

    init() {
        let ws = WeeklyMindsetEntry.weekStart(for: Date())
        let we = Calendar.current.date(byAdding: .day, value: 1, to: ws) ?? ws
        weekStart = ws

        _allChunks = Query(
            filter: #Predicate<PlannedChunk> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunk.chunkIndex, order: .forward)]
        )
        _allActions = Query(
            filter: #Predicate<PlannedChunkAction> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkAction.sortOrder, order: .forward)]
        )
        _stepFourStates = Query(
            filter: #Predicate<PlannedChunkStepFourState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkStepFourState.updatedAt, order: .reverse)]
        )
        _outcomeLinks = Query(
            filter: #Predicate<PlannedChunkOutcomeLink> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkOutcomeLink.createdAt, order: .forward)]
        )
        _defineStates = Query(
            filter: #Predicate<PlannedChunkActionDefineState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionDefineState.updatedAt, order: .reverse)]
        )
        _executionStates = Query(
            filter: #Predicate<PlannedChunkActionExecutionState> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionExecutionState.updatedAt, order: .reverse)]
        )
        _leverageSelections = Query(
            filter: #Predicate<PlannedChunkActionLeverageSelection> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionLeverageSelection.updatedAt, order: .reverse)]
        )
        _placeLinks = Query(
            filter: #Predicate<PlannedChunkActionSensitivityPlaceLink> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionSensitivityPlaceLink.createdAt, order: .forward)]
        )
        _notes = Query(
            filter: #Predicate<PlannedChunkActionNote> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionNote.updatedAt, order: .reverse)]
        )
        _attachments = Query(
            filter: #Predicate<PlannedChunkActionAttachment> { $0.weekStart >= ws && $0.weekStart < we },
            sort: [SortDescriptor(\PlannedChunkActionAttachment.createdAt, order: .forward)]
        )
    }

    private var currentWeekStart: Date {
        weekStart
    }

    struct DueDateEditorState {
        var hasDueDate: Bool
        var dueDate: Date
        var attentionDays: Int
        var minimumDate: Date
    }

    private var weekChunks: [PlannedChunk] {
        allChunks
    }

    private var orderedWeekChunksForDisplay: [PlannedChunk] {
        let sortedByIndex = weekChunks.sorted { $0.chunkIndex < $1.chunkIndex }
        let baseOrder: [PlannedChunk] = {
            guard !localChunkOrderIDs.isEmpty else { return sortedByIndex }
            let byID = Dictionary(uniqueKeysWithValues: sortedByIndex.map { ($0.id, $0) })
            let ordered = localChunkOrderIDs.compactMap { byID[$0] }
            if ordered.count == sortedByIndex.count { return ordered }
            let missing = sortedByIndex.filter { chunk in
                !localChunkOrderIDs.contains(chunk.id)
            }
            return ordered + missing
        }()

        let activeBlocks = baseOrder.filter { chunkHasAnyActiveActions($0.id) }
        let completedBlocks = baseOrder.filter { !chunkHasAnyActiveActions($0.id) }
        return activeBlocks + completedBlocks
    }

    private func chunkHasAnyActiveActions(_ chunkID: UUID) -> Bool {
        weekActions.contains { action in
            guard action.plannedChunkId == chunkID else { return false }
            let status = executionStateByActionID[action.id]?.status ?? .noAction
            return isActiveStatus(status)
        }
    }

    private var weekActions: [PlannedChunkAction] {
        allActions
    }

    private var actionIDsInView: Set<UUID> {
        Set(weekActions.map(\.id))
    }

    private var weekStepFourStatesByChunkID: [UUID: PlannedChunkStepFourState] {
        Dictionary(uniqueKeysWithValues: stepFourStates.map { ($0.plannedChunkId, $0) })
    }

    private var weekOutcomeIDsByChunkID: [UUID: [UUID]] {
        let grouped = Dictionary(grouping: outcomeLinks, by: \.plannedChunkId)
        return grouped.mapValues { links in links.map(\.outcomeId) }
    }

    private var defineStateByActionID: [UUID: PlannedChunkActionDefineState] {
        let meaningful: (PlannedChunkActionDefineState) -> Bool = { row in
            row.isMust ||
            row.timeEstimateMinutes != nil ||
            !(row.sensitiveMorning && row.sensitiveAfternoon && row.sensitiveEvening)
        }
        var result: [UUID: PlannedChunkActionDefineState] = [:]
        for row in defineStates where actionIDsInView.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = result[key] else {
                result[key] = row
                continue
            }

            let rowMeaningful = meaningful(row)
            let existingMeaningful = meaningful(existing)

            if rowMeaningful && !existingMeaningful {
                result[key] = row
            } else if rowMeaningful == existingMeaningful && row.updatedAt > existing.updatedAt {
                result[key] = row
            }
        }
        return result
    }

    private var executionStateByActionID: [UUID: PlannedChunkActionExecutionState] {
        var result: [UUID: PlannedChunkActionExecutionState] = [:]
        for row in executionStates where actionIDsInView.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            if let existing = result[key] {
                if row.updatedAt > existing.updatedAt { result[key] = row }
            } else {
                result[key] = row
            }
        }
        return result
    }

    private var notesByActionID: [UUID: PlannedChunkActionNote] {
        var result: [UUID: PlannedChunkActionNote] = [:]
        for row in notes where actionIDsInView.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            let rowMeaningful = !row.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

            guard let existing = result[key] else {
                result[key] = row
                continue
            }

            let existingMeaningful = !existing.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if rowMeaningful && !existingMeaningful {
                result[key] = row
            } else if rowMeaningful == existingMeaningful && row.updatedAt > existing.updatedAt {
                result[key] = row
            }
        }
        return result
    }

    private var attachmentsByActionID: [UUID: [PlannedChunkActionAttachment]] {
        Dictionary(grouping: attachments.filter { actionIDsInView.contains($0.plannedChunkActionId) }, by: \.plannedChunkActionId)
    }

    private var selectedResourceByActionID: [UUID: UUID] {
        var result: [UUID: UUID] = [:]
        var seenUpdatedAtByActionId: [UUID: Date] = [:]
        for sel in leverageSelections where actionIDsInView.contains(sel.plannedChunkActionId) {
            if let resourceId = sel.resourceId {
                let key = sel.plannedChunkActionId
                if let existingUpdatedAt = seenUpdatedAtByActionId[key] {
                    if sel.updatedAt > existingUpdatedAt {
                        seenUpdatedAtByActionId[key] = sel.updatedAt
                        result[key] = resourceId
                    }
                } else {
                    seenUpdatedAtByActionId[key] = sel.updatedAt
                    result[sel.plannedChunkActionId] = resourceId
                }
            }
        }
        return result
    }

    private var placeIDsByActionID: [UUID: Set<UUID>] {
        let grouped = Dictionary(grouping: placeLinks.filter { actionIDsInView.contains($0.plannedChunkActionId) }, by: \.plannedChunkActionId)
        return grouped.mapValues { Set($0.map(\.placeId)) }
    }

    private var resourceByID: [UUID: LeverageResource] {
        Dictionary(uniqueKeysWithValues: leverageCatalog.map { ($0.id, $0) })
    }

    private var availablePersonResources: [LeverageResource] {
        let chosen = Set(selectedResourceByActionID.values)
        return leverageCatalog
            .filter { $0.kind == .person && chosen.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var availableToolResources: [LeverageResource] {
        let chosen = Set(selectedResourceByActionID.values)
        return leverageCatalog
            .filter { $0.kind == .tool && chosen.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var availablePlaceItems: [SensitivityPlaceCatalogItem] {
        let selected = Set(placeIDsByActionID.values.flatMap { $0 })
        return placesCatalog
            .filter { selected.contains($0.id) }
            .sorted { $0.place.localizedCaseInsensitiveCompare($1.place) == .orderedAscending }
    }

    private var availableDurations: [Int] {
        let mins = Set(weekActions.compactMap { defineStateByActionID[$0.id]?.timeEstimateMinutes })
        return mins.sorted()
    }

    private var availableAttachmentKinds: [ActionAttachmentFilterKind] {
        var kinds = Set<ActionAttachmentFilterKind>()
        if notesByActionID.values.contains(where: { !$0.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }) {
            kinds.insert(.note)
        }
        if attachmentsByActionID.values.flatMap({ $0 }).contains(where: { $0.kind == .link }) {
            kinds.insert(.link)
        }
        if attachmentsByActionID.values.flatMap({ $0 }).contains(where: { $0.kind == .file }) {
            kinds.insert(.file)
        }
        return ActionAttachmentFilterKind.allCases.filter { kinds.contains($0) }
    }

    private var inProgressCount: Int {
        weekActions.filter { status(for: $0.id) == .inProgress }.count
    }

    private var blocksAgeDays: Int? {
        guard let earliest = weekActions.map(\.createdAt).min() else { return nil }
        let start = Calendar.current.startOfDay(for: earliest)
        let now = Calendar.current.startOfDay(for: Date())
        return max(0, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)
    }
    private var canCompleteActions: Bool {
        guard !weekActions.isEmpty else { return false }
        return weekActions.allSatisfy { action in
            let s = status(for: action.id)
            return s == .done || s == .carriedToCapture || s == .notNeeded
        }
    }

    private var hasUncompletedActions: Bool {
        weekActions.contains { action in
            let s = status(for: action.id)
            return s == .noAction || s == .leveraged || s == .inProgress
        }
    }
    private var showInactiveOnlyFilterButton: Bool { inactiveOnly || inactiveOnlyCandidateCount > 0 }
    private var showLeveragedOnlyFilterButton: Bool { leveragedOnly || leveragedOnlyCandidateCount > 0 }
    private var showInProgressOnlyFilterButton: Bool { inProgressOnly || inProgressOnlyCandidateCount > 0 }
    private var hasMustsFilterButton: Bool { onlyMusts || mustsOnlyCandidateCount > 0 }

    private enum FilterFacet: Hashable {
        case place, person, tool, timeOfDay, musts, duration, attachments
        case activeOnly, leveragedOnly, inProgressOnly
    }

    private func filteredActionsForVisibility(excluding excluded: Set<FilterFacet>) -> [PlannedChunkAction] {
        let defineByAction = defineStateByActionID
        let executionByAction = executionStateByActionID
        let resourcesByAction = selectedResourceByActionID
        let placesByAction = placeIDsByActionID
        let notesByAction = notesByActionID
        let attachmentsByAction = attachmentsByActionID
        let resourcesCatalogByID = resourceByID

        return weekActions.filter {
            actionMatchesFilters(
                $0,
                defineByAction: defineByAction,
                executionByAction: executionByAction,
                resourcesByAction: resourcesByAction,
                placesByAction: placesByAction,
                notesByAction: notesByAction,
                attachmentsByAction: attachmentsByAction,
                resourceCatalogByID: resourcesCatalogByID,
                excludedFacets: excluded
            )
        }
    }

    private var currentlyVisibleActionCount: Int {
        filteredActionsForVisibility(excluding: []).count
    }

    private var contextualPlaceItems: [SensitivityPlaceCatalogItem] {
        let base = filteredActionsForVisibility(excluding: [.place])
        let idsFromBase = Set(base.flatMap { Array(placeIDsByActionID[$0.id] ?? []) })
        let ids = idsFromBase.union(selectedPlaceIDs)
        return placesCatalog
            .filter { ids.contains($0.id) }
            .sorted { $0.place.localizedCaseInsensitiveCompare($1.place) == .orderedAscending }
    }

    private var contextualPersonResources: [LeverageResource] {
        let base = filteredActionsForVisibility(excluding: [.person])
        let idsFromBase = Set(base.compactMap { selectedResourceByActionID[$0.id] })
        let ids = idsFromBase.union(selectedPersonIDs)
        return leverageCatalog
            .filter { $0.kind == .person && ids.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var contextualToolResources: [LeverageResource] {
        let base = filteredActionsForVisibility(excluding: [.tool])
        let idsFromBase = Set(base.compactMap { selectedResourceByActionID[$0.id] })
        let ids = idsFromBase.union(selectedToolIDs)
        return leverageCatalog
            .filter { $0.kind == .tool && ids.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var contextualTimeOfDayOptions: [TimeOfDayChoice] {
        let base = filteredActionsForVisibility(excluding: [.timeOfDay])
        var options = Set<TimeOfDayChoice>()
        for action in base {
            let st = defineStateByActionID[action.id]
            let hasMorning = st?.sensitiveMorning ?? true
            let hasAfternoon = st?.sensitiveAfternoon ?? true
            let hasEvening = st?.sensitiveEvening ?? true
            let isAnytime = hasMorning && hasAfternoon && hasEvening
            if isAnytime {
                options.insert(.any)
            } else {
                if hasMorning { options.insert(.morning) }
                if hasAfternoon { options.insert(.afternoon) }
                if hasEvening { options.insert(.evening) }
            }
        }
        options.formUnion(selectedTimeOfDay)
        return TimeOfDayChoice.allCases.filter { options.contains($0) }
    }

    private var contextualDurations: [Int] {
        let base = filteredActionsForVisibility(excluding: [.duration])
        var values = Set(base.compactMap { defineStateByActionID[$0.id]?.timeEstimateMinutes })
        values.formUnion(selectedDurations)
        return values.sorted()
    }

    private var contextualAttachmentKinds: [ActionAttachmentFilterKind] {
        let base = filteredActionsForVisibility(excluding: [.attachments])
        var kinds = Set<ActionAttachmentFilterKind>()
        for action in base {
            let note = notesByActionID[action.id]?.noteText ?? ""
            let atts = attachmentsByActionID[action.id] ?? []
            if !note.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { kinds.insert(.note) }
            if atts.contains(where: { $0.kind == .link }) { kinds.insert(.link) }
            if atts.contains(where: { $0.kind == .file }) { kinds.insert(.file) }
        }
        kinds.formUnion(selectedAttachmentKinds)
        return ActionAttachmentFilterKind.allCases.filter { kinds.contains($0) }
    }

    private var canExpandPlaceSelection: Bool {
        contextualPlaceItems.contains { !selectedPlaceIDs.contains($0.id) }
    }
    private var hasPlaceFilterButton: Bool {
        !selectedPlaceIDs.isEmpty || canExpandPlaceSelection
    }

    private var canExpandPersonSelection: Bool {
        contextualPersonResources.contains { !selectedPersonIDs.contains($0.id) }
    }
    private var hasPersonFilterButton: Bool {
        !selectedPersonIDs.isEmpty || canExpandPersonSelection
    }

    private var canExpandToolSelection: Bool {
        contextualToolResources.contains { !selectedToolIDs.contains($0.id) }
    }
    private var hasToolFilterButton: Bool {
        !selectedToolIDs.isEmpty || canExpandToolSelection
    }

    private var canExpandTimeOfDaySelection: Bool {
        contextualTimeOfDayOptions.contains { !selectedTimeOfDay.contains($0) }
    }
    private var hasTimeOfDayFilterButton: Bool {
        !selectedTimeOfDay.isEmpty || canExpandTimeOfDaySelection
    }
    private var canExpandDurationSelection: Bool {
        contextualDurations.contains { !selectedDurations.contains($0) }
    }
    private var hasDurationFilterButton: Bool {
        !selectedDurations.isEmpty || canExpandDurationSelection
    }

    private var canExpandAttachmentSelection: Bool {
        contextualAttachmentKinds.contains { !selectedAttachmentKinds.contains($0) }
    }
    private var hasAttachmentsFilterButton: Bool {
        !selectedAttachmentKinds.isEmpty || canExpandAttachmentSelection
    }
    var body: some View {
        let defineByAction = defineStateByActionID
        let executionByAction = executionStateByActionID
        let notesByAction = notesByActionID
        let attachmentsByAction = attachmentsByActionID
        let resourcesByAction = selectedResourceByActionID
        let placesByAction = placeIDsByActionID
        let resourcesCatalogByID = resourceByID
        let allByChunk = Dictionary(grouping: weekActions, by: \.plannedChunkId)
        let rolesByID = Dictionary(uniqueKeysWithValues: roles.map { ($0.id, $0.role) })
        let outcomesByID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
        let filteredByChunk = buildFilteredActionsByChunk(
            defineByAction: defineByAction,
            executionByAction: executionByAction,
            resourcesByAction: resourcesByAction,
            placesByAction: placesByAction,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            resourceCatalogByID: resourcesCatalogByID
        )

        VStack(spacing: 0) {
            collapsibleHeader

            ScrollViewReader { proxy in
                ScrollView {
                    GeometryReader { geo in
                        Color.clear
                            .preference(
                                key: ActionScrollOffsetPreferenceKey.self,
                                value: geo.frame(in: .named("action-scroll")).minY
                            )
                    }
                    .frame(height: 0)

                    LazyVStack(alignment: .leading, spacing: 12) {
                        if weekChunks.isEmpty {
                            Text("No action blocks yet.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.top, 24)
                        } else {
                            ForEach(orderedWeekChunksForDisplay) { chunk in
                                chunkCard(
                                    chunk,
                                    allActions: allByChunk[chunk.id] ?? [],
                                    filteredActions: filteredByChunk[chunk.id] ?? [],
                                    defineByAction: defineByAction,
                                    executionByAction: executionByAction,
                                    resourcesByAction: resourcesByAction,
                                    placesByAction: placesByAction,
                                    notesByAction: notesByAction,
                                    attachmentsByAction: attachmentsByAction,
                                    rolesByID: rolesByID,
                                    outcomesByID: outcomesByID
                                )
                                .id("chunk-\(chunk.id.uuidString)")
                                .onDrag {
                                    if localChunkOrderIDs.isEmpty {
                                        localChunkOrderIDs = weekChunks
                                            .sorted { $0.chunkIndex < $1.chunkIndex }
                                            .map(\.id)
                                    }
                                    draggedChunkID = chunk.id
                                    return NSItemProvider(object: chunk.id.uuidString as NSString)
                                }
                                .onDrop(
                                    of: [UTType.text],
                                    delegate: AnimatedChunkDropDelegate(
                                        targetChunkID: chunk.id,
                                        localChunkOrderIDs: $localChunkOrderIDs,
                                        draggedChunkID: $draggedChunkID,
                                        onCommit: commitChunkOrder
                                    )
                                )
                            }
                        }
                    }
                    .onDrop(
                        of: [UTType.text],
                        delegate: ResetChunkDragStateDropDelegate(
                            draggedChunkID: $draggedChunkID,
                            localChunkOrderIDs: $localChunkOrderIDs,
                            onCommit: commitChunkOrder
                        )
                    )
                    .animation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12), value: localChunkOrderIDs)
                    .padding(.bottom, max(12, keyboardHeight + 8))
                }
                .onChange(of: focusedActionID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: scrollTargetActionID) { _, id in
                    guard let id else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: .bottom)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            focusedActionID = id
                            scrollTargetActionID = nil
                        }
                    }
                }
                .onChange(of: pendingChunkScrollAnchor) { _, anchor in
                    guard let anchor else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(anchor, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: pendingExpandChunkTopAnchor) { _, anchor in
                    guard let anchor else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(anchor, anchor: .top)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                            pendingExpandChunkTopAnchor = nil
                        }
                    }
                }
            }

            Spacer(minLength: 0)

            Color.clear
                .frame(height: 12)

            HStack(spacing: 10) {
                Button {
                    if isKeyboardVisible {
                        dismissKeyboardAndCommit()
                    } else {
                        dismiss()
                    }
                } label: {
                    Group {
                        if isKeyboardVisible {
                            Text("Enter")
                                .font(.system(size: 17, weight: .semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.white)
                        } else {
                            Text("Back")
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                        }
                    }
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(isKeyboardVisible ? Color.blue : Color(.systemGray5))
                )

                if !isKeyboardVisible {
                    Button {
                        if canCompleteActions {
                            persistNow()
                            showReflectionFlow = true
                        } else {
                            showCompleteActionsHint()
                        }
                    } label: {
                        Text("Complete")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .foregroundStyle(.white)
                    }
                    .background(
                        Capsule()
                            .fill(!canCompleteActions ? Color(.systemGray3) : Color.accentColor)
                    )
                }
            }
            .padding(.bottom, 2)
        }
        .overlay(alignment: .bottom) {
            if showCompleteHint {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You cannot complete if any actions are active.")
                        .font(.footnote)
                        .fontWeight(.bold)

                    (
                        Text("Please mark all of your actions to ")
                        + Text(Image(systemName: "xmark")) + Text(" Done, ")
                        + Text(Image(systemName: "arrow.right")) + Text(" Carried to new capture list, or ")
                        + Text(Image(systemName: "square")) + Text(" Didn't need to be done to acheive outcome (Delete).")
                    )
                    .font(.footnote)
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
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color(.systemBackground))
        .coordinateSpace(name: "action-scroll")
        .sheet(
            isPresented: Binding(
                get: { isShowingInstructions && hasMotivationContent },
                set: { isShowingInstructions = $0 }
            )
        ) {
            ActionInstructionsPopup()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .fullScreenCover(isPresented: $showReflectionFlow, onDismiss: {
            if dismissActionViewAfterReflect {
                dismissActionViewAfterReflect = false
                var transaction = Transaction()
                transaction.disablesAnimations = true
                withTransaction(transaction) {
                    dismiss()
                }
            }
        }) {
            ReflectView(
                weekStart: currentWeekStart,
                onFinish: {
                    dismissActionViewAfterReflect = true
                    var transaction = Transaction()
                    transaction.disablesAnimations = true
                    withTransaction(transaction) {
                        showReflectionFlow = false
                    }
                }
            )
        }
        .sheet(item: $addActionChunkID) { wrapper in
            AddActionFromCaptureSheet(
                captureItems: availableCaptureActions,
                onDone: { selection in
                    guard
                        let selection,
                        let chunk = weekChunks.first(where: { $0.id == wrapper.id })
                    else { return }
                    if let captureId = selection.captureItemID,
                       let capture = captureItems.first(where: { $0.id == captureId }) {
                        RecentlyDeletedStore.trash(capture, in: modelContext)
                    }
                    insertAction(
                        to: chunk,
                        initialText: selection.text,
                        focusAfterInsert: false,
                        isPendingBlank: false,
                        openDurationAfterInsert: true
                    )
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $durationActionID, onDismiss: handleDurationSheetDismiss) { wrapper in
            TimeEstimateSheet(
                currentMinutes: defineStateByActionID[wrapper.id]?.timeEstimateMinutes,
                onSelect: { minutes in
                    upsertDefineState(forActionId: wrapper.id) { st in
                        st.timeEstimateMinutes = minutes
                        st.updatedAt = .now
                    }
                    if pendingDurationDefaultActionID == wrapper.id {
                        pendingDurationDefaultActionID = nil
                    }
                    scheduleAutosave()
                }
            )
            .presentationDetents([.height(340), .medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $leverageActionID) { wrapper in
            LeverageSheet(
                leverageCatalog: leverageCatalog,
                selectedResourceId: selectedResourceByActionID[wrapper.id],
                onAdd: { kind, value in
                    let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    let key = "\(kind.rawValue.lowercased())|\(trimmed.lowercased())"
                    if leverageCatalog.first(where: { $0.kindValueKey == key }) == nil {
                        modelContext.insert(LeverageResource(kindRaw: kind.rawValue, value: trimmed))
                    }
                    scheduleAutosave()
                },
                onDeleteCatalogItems: { ids in
                    var affectedActionIDs: Set<UUID> = []
                    for it in leverageCatalog where ids.contains(it.id) {
                        for sel in leverageSelections where sel.resourceId == it.id {
                            sel.resourceId = nil
                            sel.updatedAt = .now
                            affectedActionIDs.insert(sel.plannedChunkActionId)
                        }
                        RecentlyDeletedStore.trash(it, in: modelContext)
                    }
                    for actionID in affectedActionIDs {
                        clearLeveragedStatusIfNoSelection(for: actionID)
                    }
                    scheduleAutosave()
                },
                onSelectResource: { resourceID in
                    upsertLeverageSelection(forActionId: wrapper.id) { sel in
                        sel.resourceId = resourceID
                        sel.updatedAt = .now
                    }
                    clearLeveragedStatusIfNoSelection(for: wrapper.id)
                    scheduleAutosave()
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $sensitivityActionID, onDismiss: {
            leverageDueDatePromptActionID = nil
            pendingLeveragedStatusActionID = nil
        }) { wrapper in
            let dueEditor = dueDateEditorState(forActionId: wrapper.id)
            SensitivitySheet(
                defineState: Binding(
                    get: { defineStateByActionID[wrapper.id] ?? makeBlankDefineState(actionId: wrapper.id) },
                    set: { newValue in
                        upsertDefineState(forActionId: wrapper.id) { st in
                            st.sensitiveMorning = newValue.sensitiveMorning
                            st.sensitiveAfternoon = newValue.sensitiveAfternoon
                            st.sensitiveEvening = newValue.sensitiveEvening
                            st.updatedAt = .now
                        }
                        scheduleAutosave()
                    }
                ),
                placesCatalog: placesCatalog,
                selectedPlaceIDs: placeIDsByActionID[wrapper.id] ?? [],
                onAddPlaceToCatalog: { place in
                    let trimmed = place.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    if placesCatalog.contains(where: { $0.normalizedKey == trimmed.lowercased() }) {
                        return
                    }
                    modelContext.insert(SensitivityPlaceCatalogItem(place: trimmed))
                    scheduleAutosave()
                },
                onDeleteCatalogPlaces: { ids in
                    for p in placesCatalog where ids.contains(p.id) {
                        for link in placeLinks where link.placeId == p.id {
                            RecentlyDeletedStore.trash(link, in: modelContext)
                        }
                        RecentlyDeletedStore.trash(p, in: modelContext)
                    }
                    scheduleAutosave()
                },
                onTogglePlaceSelected: { placeId in
                    togglePlaceSelection(actionId: wrapper.id, placeId: placeId)
                    scheduleAutosave()
                },
                dueDateEditor: dueEditor,
                highlightDueDateRequirementOnAppear: leverageDueDatePromptActionID == wrapper.id,
                onSaveDueDateEditor: { updated in
                    updateDueDateEditor(forActionId: wrapper.id, with: updated)
                    if !updated.hasDueDate, status(for: wrapper.id) == .leveraged {
                        setStatus(for: wrapper.id, to: .noAction)
                    }
                    if pendingLeveragedStatusActionID == wrapper.id {
                        if updated.hasDueDate {
                            setStatus(for: wrapper.id, to: .leveraged)
                            pendingLeveragedStatusActionID = nil
                            leverageDueDatePromptActionID = nil
                        }
                    }
                }
            )
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $attachmentsActionID) { wrapper in
            AttachmentsSheet(
                attachments: attachmentsByActionID[wrapper.id] ?? [],
                initialNoteText: notesByActionID[wrapper.id]?.noteText ?? "",
                onSaveNote: { newValue in
                    upsertNote(forActionId: wrapper.id) { n in
                        n.noteText = newValue
                        n.updatedAt = .now
                    }
                    scheduleAutosave()
                },
                onAddLink: { link in
                    let trimmed = link.trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !trimmed.isEmpty else { return }
                    modelContext.insert(PlannedChunkActionAttachment(
                        weekStart: currentWeekStart,
                        plannedChunkActionId: wrapper.id,
                        kindRaw: ActionAttachmentKind.link.rawValue,
                        urlString: trimmed,
                        fileName: nil,
                        fileBookmarkData: nil,
                        createdAt: .now
                    ))
                    scheduleAutosave()
                },
                onAddFile: { _, bookmarkData, fileName in
                    modelContext.insert(PlannedChunkActionAttachment(
                        weekStart: currentWeekStart,
                        plannedChunkActionId: wrapper.id,
                        kindRaw: ActionAttachmentKind.file.rawValue,
                        urlString: nil,
                        fileName: fileName,
                        fileBookmarkData: bookmarkData,
                        createdAt: .now
                    ))
                    scheduleAutosave()
                },
                onDeleteAttachment: { attachmentId in
                    if let a = attachmentsByActionID.values.flatMap({ $0 }).first(where: { $0.id == attachmentId }) {
                        RecentlyDeletedStore.trash(a, in: modelContext)
                        scheduleAutosave()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $actionStatusActionID) { wrapper in
            let selectedResource = selectedResourceByActionID[wrapper.id].flatMap { resourceByID[$0] }
            let leveragedStatusIconName = {
                guard let selectedResource else { return "circle" }
                return selectedResource.kind == .tool ? "wrench.and.screwdriver" : "person"
            }()
            ActionStatusPickerSheet(
                current: status(for: wrapper.id),
                includeLeveragedOption: selectedResource != nil,
                leveragedIconName: leveragedStatusIconName,
                onSelect: { status in
                    if status == .leveraged {
                        if let due = dueDateEditorState(forActionId: wrapper.id), due.hasDueDate {
                            setStatus(for: wrapper.id, to: .leveraged)
                        } else {
                            pendingLeveragedStatusActionID = wrapper.id
                            leverageDueDatePromptActionID = wrapper.id
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.14) {
                                sensitivityActionID = ActionSheetID(id: wrapper.id)
                            }
                        }
                    } else {
                        setStatus(for: wrapper.id, to: status)
                    }
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
        .alert("Only 3 In Progress actions are allowed.", isPresented: $showCheckmarkLimitAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            dismissActionBlocksCautionCard = false
            ensureStateRowsExistForWeek()
            applyCarriedProfilesToWeekActionsIfNeeded()
            cleanupAllBlankActions()
            deactivatePlanIfNoActionBlocks()
            syncLocalChunkOrderIfNeeded(force: true)
        }
        .onChange(of: weekChunks.map(\.id)) { _, _ in
            deactivatePlanIfNoActionBlocks()
            syncLocalChunkOrderIfNeeded(force: false)
        }
        .onChange(of: weekActions.map(\.id)) { _, ids in
            ensureStateRowsExistForWeek()
            carriedProfileAppliedActionIDs = carriedProfileAppliedActionIDs.intersection(Set(ids))
            applyCarriedProfilesToWeekActionsIfNeeded()
            cleanupAllBlankActions()
            deactivatePlanIfNoActionBlocks()
            if let pending = pendingFocusActionID, ids.contains(pending) {
                scrollTargetActionID = pending
                pendingFocusActionID = nil
            }
        }
        .onPreferenceChange(ActionScrollOffsetPreferenceKey.self) { y in
            handleScrollOffsetChange(y)
        }
        .onDisappear {
            let pending = deferredPersistor.takePendingAndCancel()
            applyDeferredWrites(statuses: pending.statuses, musts: pending.musts)
            autosaveTask?.cancel()
            persistNow()
        }
        #if canImport(UIKit)
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
            isKeyboardVisible = true
            if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                keyboardHeight = max(0, frame.height - 34)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            isKeyboardVisible = false
            keyboardHeight = 0
            focusedActionID = nil
            cleanupPendingBlankActions()
            cleanupAllBlankActions()
        }
        #endif
    }

    private var collapsibleHeader: some View {
        VStack(spacing: 8) {
            Text("Action Blocks")
                .font(isHeaderCollapsed ? .title3 : .largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)
                .animation(.spring(response: 0.24, dampingFraction: 0.86), value: isHeaderCollapsed)

            if !isHeaderCollapsed {
                instructionsRow
                if shouldShowActionBlocksOldCautionCard && !dismissActionBlocksCautionCard {
                    cautionRow
                }
                if !areAllActionBlocksCollapsed {
                    filterChipsRow
                }
                if !areAllActionBlocksCollapsed, let openFilter, isFilterMenuAvailable(openFilter) {
                    filterDropdown(for: openFilter)
                }
            }
        }
        .padding(.bottom, 6)
    }

    private var shouldShowActionBlocksOldCautionCard: Bool {
        let autoShow = (blocksAgeDays ?? 0) >= 8
        let manualShow = devManualWarningCardsEnabled && devActionBlocksWarningOldBlocks
        return manualShow || autoShow
    }

    private var currentWeekStartForMotivation: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var currentMotivationEntry: WeeklyMindsetEntry.Fields? {
        weeklyMindsetEntries.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStartForMotivation)
        }
    }

    private var currentMotivationGratitude: String {
        currentMotivationEntry?.morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var currentMotivationPhrase: String {
        currentMotivationEntry?.incantation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var hasMotivationContent: Bool {
        !currentMotivationGratitude.isEmpty || !currentMotivationPhrase.isEmpty
    }

    @ViewBuilder
    private var instructionsRow: some View {
        if hasMotivationContent {
            Button { isShowingInstructions = true } label: {
                HStack(alignment: .center, spacing: 10) {
                    Spacer(minLength: 0)
                    Image(systemName: "bolt.square")
                        .foregroundStyle(.secondary)
                        .accessibilityHidden(true)
                    Text("Motivation")
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Text("Tap to read")
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
        }
    }

    @ViewBuilder
    private var cautionRow: some View {
        let cautionAgeDays = blocksAgeDays ?? (devManualWarningCardsEnabled && devActionBlocksWarningOldBlocks ? 8 : 0)
        let cautionForeground = Color.black.opacity(0.7)
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(cautionForeground)
                .font(.subheadline)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                (
                    Text("Caution: ").fontWeight(.bold)
                    + Text("Action Blocks created \(cautionAgeDays) days ago. Mark uncompleted actions ")
                    + Text(Image(systemName: "arrow.right"))
                    + Text(" to a new capture list and start a new plan to keep it fresh.")
                )
                .font(.subheadline)
                .foregroundStyle(cautionForeground)

                if hasUncompletedActions {
                    Button("Click here") {
                        markAllUncompletedAsRecapture()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .fontWeight(.regular)
                    .foregroundStyle(.blue)
                }
            }

            Spacer(minLength: 0)

            Button {
                dismissActionBlocksCautionCard = true
            } label: {
                Image(systemName: "xmark")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(cautionForeground)
                    .frame(width: 22, height: 22)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
    }

    private var filterChipsRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                Button {
                    resetAllFilters()
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.clockwise")
                        Text("refresh")
                    }
                }
                .buttonStyle(.plain)
                .font(.subheadline)
                .foregroundStyle(.gray)
                .padding(.trailing, 2)

                ForEach(orderedVisibleFilterChips, id: \.self) { chip in
                    filterChipView(chip)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var orderedVisibleFilterChips: [FilterChipKind] {
        let visible = defaultFilterChipOrder.filter { isFilterChipVisible($0) || isFilterChipSelected($0) }
        let selected = visible.filter { isFilterChipSelected($0) }
        let nonSelected = visible.filter { !isFilterChipSelected($0) }
        return selected + nonSelected
    }

    private var defaultFilterChipOrder: [FilterChipKind] {
        [
            .activeOnly, .musts, .place, .person, .duration,
            .tool, .timeOfDay, .leveragedOnly, .attachments, .inProgressOnly
        ]
    }

    private func isFilterChipVisible(_ chip: FilterChipKind) -> Bool {
        switch chip {
        case .activeOnly: return showInactiveOnlyFilterButton
        case .musts: return hasMustsFilterButton
        case .place: return hasPlaceFilterButton
        case .person: return hasPersonFilterButton
        case .duration: return hasDurationFilterButton
        case .tool: return hasToolFilterButton
        case .timeOfDay: return hasTimeOfDayFilterButton
        case .leveragedOnly: return showLeveragedOnlyFilterButton
        case .attachments: return hasAttachmentsFilterButton
        case .inProgressOnly: return showInProgressOnlyFilterButton
        }
    }

    private var inactiveOnlyCandidateCount: Int {
        let base = filteredActionsForVisibility(excluding: [.activeOnly])
        return base.filter { isInactiveStatus(status(for: $0.id)) }.count
    }

    private var leveragedOnlyCandidateCount: Int {
        let base = filteredActionsForVisibility(excluding: [.leveragedOnly])
        return base.filter { status(for: $0.id) == .leveraged }.count
    }

    private var inProgressOnlyCandidateCount: Int {
        let base = filteredActionsForVisibility(excluding: [.inProgressOnly])
        return base.filter { status(for: $0.id) == .inProgress }.count
    }

    private var mustsOnlyCandidateCount: Int {
        let defineByAction = defineStateByActionID
        let base = filteredActionsForVisibility(excluding: [.musts])
        return base.filter { isMust(for: $0.id, defineByAction: defineByAction) }.count
    }

    private func isFilterChipSelected(_ chip: FilterChipKind) -> Bool {
        switch chip {
        case .activeOnly: return inactiveOnly
        case .musts: return onlyMusts
        case .place: return !selectedPlaceIDs.isEmpty
        case .person: return !selectedPersonIDs.isEmpty
        case .duration: return !selectedDurations.isEmpty
        case .tool: return !selectedToolIDs.isEmpty
        case .timeOfDay: return !selectedTimeOfDay.isEmpty
        case .leveragedOnly: return leveragedOnly
        case .attachments: return !selectedAttachmentKinds.isEmpty
        case .inProgressOnly: return inProgressOnly
        }
    }

    @ViewBuilder
    private func filterChipView(_ chip: FilterChipKind) -> some View {
        switch chip {
        case .activeOnly:
            filterChip(
                title: "Inactive Only",
                iconName: "line.3.horizontal.decrease.circle",
                isActive: inactiveOnly,
                showsChevron: false
            ) {
                inactiveOnly.toggle()
            }
        case .musts:
            filterChip(
                title: "Musts",
                iconName: "star.square",
                isActive: onlyMusts,
                showsChevron: false
            ) {
                onlyMusts.toggle()
            }
        case .place:
            filterChip(
                title: placeFilterTitle,
                iconName: "mappin.and.ellipse",
                isActive: !selectedPlaceIDs.isEmpty,
                isOpen: openFilter == .place
            ) {
                toggleFilterMenu(.place)
            }
        case .person:
            filterChip(
                title: personFilterTitle,
                iconName: "person",
                isActive: !selectedPersonIDs.isEmpty,
                isOpen: openFilter == .person
            ) {
                toggleFilterMenu(.person)
            }
        case .duration:
            filterChip(
                title: durationFilterTitle,
                iconName: "clock.fill",
                isActive: !selectedDurations.isEmpty,
                isOpen: openFilter == .duration
            ) {
                toggleFilterMenu(.duration)
            }
        case .tool:
            filterChip(
                title: toolFilterTitle,
                iconName: "wrench.and.screwdriver",
                isActive: !selectedToolIDs.isEmpty,
                isOpen: openFilter == .tool
            ) {
                toggleFilterMenu(.tool)
            }
        case .timeOfDay:
            filterChip(
                title: timeOfDayFilterTitle,
                iconName: "clock",
                isActive: !selectedTimeOfDay.isEmpty,
                isOpen: openFilter == .timeOfDay
            ) {
                toggleFilterMenu(.timeOfDay)
            }
        case .leveragedOnly:
            filterChip(
                title: "Leveraged Only",
                iconName: "circle",
                isActive: leveragedOnly,
                showsChevron: false
            ) {
                leveragedOnly.toggle()
            }
        case .attachments:
            filterChip(
                title: attachmentsFilterTitle,
                iconName: "paperclip",
                isActive: !selectedAttachmentKinds.isEmpty,
                isOpen: openFilter == .attachments
            ) {
                toggleFilterMenu(.attachments)
            }
        case .inProgressOnly:
            filterChip(
                title: "In Progress Only",
                iconName: "checkmark",
                isActive: inProgressOnly,
                showsChevron: false
            ) {
                inProgressOnly.toggle()
            }
        }
    }

    @ViewBuilder
    private func filterDropdown(for menu: FilterMenu) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch menu {
            case .place:
                wrapSelectablePills(
                    options: contextualPlaceItems,
                    isSelected: { selectedPlaceIDs.contains($0.id) },
                    label: { $0.place },
                    onTap: { item in
                        if selectedPlaceIDs.contains(item.id) { selectedPlaceIDs.remove(item.id) }
                        else { selectedPlaceIDs.insert(item.id) }
                    }
                )
            case .person:
                wrapSelectablePills(
                    options: contextualPersonResources,
                    isSelected: { selectedPersonIDs.contains($0.id) },
                    label: { $0.value },
                    onTap: { item in
                        if selectedPersonIDs.contains(item.id) { selectedPersonIDs.remove(item.id) }
                        else { selectedPersonIDs.insert(item.id) }
                    }
                )
            case .tool:
                wrapSelectablePills(
                    options: contextualToolResources,
                    isSelected: { selectedToolIDs.contains($0.id) },
                    label: { $0.value },
                    onTap: { item in
                        if selectedToolIDs.contains(item.id) { selectedToolIDs.remove(item.id) }
                        else { selectedToolIDs.insert(item.id) }
                    }
                )
            case .timeOfDay:
                wrapSelectablePills(
                    options: contextualTimeOfDayOptions,
                    isSelected: { selectedTimeOfDay.contains($0) },
                    label: { $0.title },
                    onTap: { item in
                        if selectedTimeOfDay.contains(item) { selectedTimeOfDay.remove(item) }
                        else { selectedTimeOfDay.insert(item) }
                    }
                )
            case .duration:
                wrapSelectablePills(
                    options: contextualDurations,
                    isSelected: { selectedDurations.contains($0) },
                    label: { "\($0)m" },
                    onTap: { value in
                        if selectedDurations.contains(value) { selectedDurations.remove(value) }
                        else { selectedDurations.insert(value) }
                    }
                )
            case .attachments:
                wrapSelectablePills(
                    options: contextualAttachmentKinds,
                    isSelected: { selectedAttachmentKinds.contains($0) },
                    label: { $0.title },
                    onTap: { item in
                        if selectedAttachmentKinds.contains(item) { selectedAttachmentKinds.remove(item) }
                        else { selectedAttachmentKinds.insert(item) }
                    }
                )
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private func chunkCard(
        _ chunk: PlannedChunk,
        allActions: [PlannedChunkAction],
        filteredActions: [PlannedChunkAction],
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        rolesByID: [UUID: String],
        outcomesByID: [UUID: Outcomes]
    ) -> some View {
        let filtered = filteredActions
        let allForChunk = allActions
        let fill = categoryFillColor(for: chunk.category)
        let accent = categoryAccentColor(for: chunk.category)
        let step4 = weekStepFourStatesByChunkID[chunk.id]
        let roleName = step4?.connectedRoleId.flatMap { rolesByID[$0] } ?? ""
        let selectedOutcomeIDs = weekOutcomeIDsByChunkID[chunk.id] ?? []
        let outcomesForChunk = selectedOutcomeIDs.compactMap { outcomesByID[$0] }
        let isCollapsed = areAllActionBlocksCollapsed
        let canShowFooterControls = !isAnyFilterApplied
        let showNoApplicableActionsPlaceholder = filtered.isEmpty && isAnyFilterApplied
        let showCompletedInactiveHeader = !isAnyFilterApplied && filtered.isEmpty && !allForChunk.isEmpty
        let canReorderDisplayedActions = !isAnyFilterApplied && filtered.count > 1
        let canonicalFilteredIDs = filtered.map(\.id)
        let displayedFiltered: [PlannedChunkAction] = {
            guard canReorderDisplayedActions, draggedActionChunkID == chunk.id, !localActionOrderIDs.isEmpty else {
                return filtered
            }
            let canonicalSet = Set(canonicalFilteredIDs)
            let normalizedIDs =
                localActionOrderIDs.filter { canonicalSet.contains($0) } +
                canonicalFilteredIDs.filter { !localActionOrderIDs.contains($0) }
            let byID = Dictionary(uniqueKeysWithValues: filtered.map { ($0.id, $0) })
            let ordered = normalizedIDs.compactMap { byID[$0] }
            return ordered.count == filtered.count ? ordered : filtered
        }()

        let cardBody = AnyView(
            chunkCardBody(
            chunk: chunk,
            allForChunk: allForChunk,
            filtered: filtered,
            displayedFiltered: displayedFiltered,
            defineByAction: defineByAction,
            executionByAction: executionByAction,
            resourcesByAction: resourcesByAction,
            placesByAction: placesByAction,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            accent: accent,
            roleName: roleName,
            outcomesForChunk: outcomesForChunk,
            step4: step4,
            showNoApplicableActionsPlaceholder: showNoApplicableActionsPlaceholder,
            isCollapsed: isCollapsed,
            showCompletedInactiveHeader: showCompletedInactiveHeader,
            canShowFooterControls: canShowFooterControls,
            canReorderDisplayedActions: canReorderDisplayedActions
            )
        )

        let padded = AnyView(
            cardBody
                .padding(12)
                .background(fill, in: RoundedRectangle(cornerRadius: 14))
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
                )
                .contentShape(Rectangle())
        )

        let tappable = AnyView(
            padded
                .onTapGesture {
                    if areAllActionBlocksCollapsed {
                        expandAllActionBlocksAndScrollToTop(anchor: "chunk-\(chunk.id.uuidString)")
                    }
                }
        )

        return tappable
            .sheet(item: $rearrangeActionsSheetID) { sheet in
                let sheetChunkActions = allActions.filter {
                    $0.plannedChunkId == sheet.id &&
                    isActiveStatus(executionStateByActionID[$0.id]?.status ?? .noAction)
                }
                RearrangeActionsSheet(
                    items: sheetChunkActions.map { .init(id: $0.id, text: $0.text) },
                    onSave: { reorderedIDs in
                        commitActionOrder(in: sheet.id, visibleOrderedIDs: reorderedIDs)
                    }
                )
            }
    }

    @ViewBuilder
    private func chunkCardBody(
        chunk: PlannedChunk,
        allForChunk: [PlannedChunkAction],
        filtered: [PlannedChunkAction],
        displayedFiltered: [PlannedChunkAction],
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        accent: Color,
        roleName: String,
        outcomesForChunk: [Outcomes],
        step4: PlannedChunkStepFourState?,
        showNoApplicableActionsPlaceholder: Bool,
        isCollapsed: Bool,
        showCompletedInactiveHeader: Bool,
        canShowFooterControls: Bool,
        canReorderDisplayedActions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if showNoApplicableActionsPlaceholder {
                noApplicableActionsPlaceholder()
            } else if isCollapsed {
                collapsedChunkContent(
                    resultText: step4?.resultText ?? "",
                    roleNoteText: step4?.roleNoteText ?? "",
                    actions: allForChunk,
                    defineByAction: defineByAction,
                    executionByAction: executionByAction
                )
            } else {
                expandedChunkContent(
                    chunk: chunk,
                    allForChunk: allForChunk,
                    filtered: filtered,
                    displayedFiltered: displayedFiltered,
                    defineByAction: defineByAction,
                    executionByAction: executionByAction,
                    resourcesByAction: resourcesByAction,
                    placesByAction: placesByAction,
                    notesByAction: notesByAction,
                    attachmentsByAction: attachmentsByAction,
                    accent: accent,
                    roleName: roleName,
                    outcomesForChunk: outcomesForChunk,
                    showCompletedInactiveHeader: showCompletedInactiveHeader,
                    canShowFooterControls: canShowFooterControls,
                    canReorderDisplayedActions: canReorderDisplayedActions
                )
            }
        }
    }

    private func noApplicableActionsPlaceholder() -> some View {
        Text("Block has no applicable actions")
            .font(.subheadline)
            .italic()
            .foregroundStyle(Color.black.opacity(0.6))
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func collapsedChunkContent(
        resultText: String,
        roleNoteText: String,
        actions: [PlannedChunkAction],
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState]
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                compactSummaryRow(label: "RESULT", text: resultText)

                Divider().opacity(0.4)

                compactSummaryRow(label: "PURPOSE", text: roleNoteText)

                Divider().opacity(0.4)

                compactActionsSummary(
                    actions: actions,
                    executionByAction: executionByAction
                )

                Divider().opacity(0.35)

                collapsedFooterRow(
                    actions: actions,
                    executionByAction: executionByAction,
                    defineByAction: defineByAction
                )
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.up.chevron.down")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.gray)
        }
    }

    @ViewBuilder
    private func expandedChunkContent(
        chunk: PlannedChunk,
        allForChunk: [PlannedChunkAction],
        filtered: [PlannedChunkAction],
        displayedFiltered: [PlannedChunkAction],
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        accent: Color,
        roleName: String,
        outcomesForChunk: [Outcomes],
        showCompletedInactiveHeader: Bool,
        canShowFooterControls: Bool,
        canReorderDisplayedActions: Bool
    ) -> some View {
        let activeActionsForRearrange = allForChunk.filter {
            isActiveStatus(executionByAction[$0.id]?.status ?? .noAction)
        }

        if showCompletedInactiveHeader {
            HStack(spacing: 6) {
                Image(systemName: "star")
                    .font(.caption)
                Text("Block Completed")
                    .font(.system(size: 16))
                    .italic()
                Image(systemName: "star")
                    .font(.caption)
            }
            .foregroundStyle(Color.black.opacity(0.58))
            .frame(maxWidth: .infinity, alignment: .center)
        }

        if canShowFooterControls {
            HStack(alignment: .center, spacing: 8) {
                addActionButton(for: chunk)
                collapseButton()
                rearrangeActionsButton(for: chunk, actions: activeActionsForRearrange, isEnabled: !isAnyFilterApplied)
                Spacer(minLength: 0)
            }
        }

        resultSection(resultText: weekStepFourStatesByChunkID[chunk.id]?.resultText ?? "")

        if !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            smallPill(icon: "trophy", text: roleName)
        }

        if !outcomesForChunk.isEmpty {
            ForEach(outcomesForChunk, id: \.outcome_id) { outcome in
                outcomePill(outcome)
            }
        }

        Divider().opacity(0.4)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("ACTIONS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("How can I best acheive it now?")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.58))
            }

            if showCompletedInactiveHeader {
                HStack(alignment: .center, spacing: 8) {
                    Text("All Actions are Inactive")
                        .font(.footnote)
                        .foregroundStyle(colorScheme == .dark ? Color.white : Color.black.opacity(0.72))
                    Spacer(minLength: 8)
                    Button("Show Inactive") {
                        inactiveOnly = true
                    }
                    .buttonStyle(.plain)
                    .font(.footnote)
                    .foregroundStyle(.blue)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }

            LazyVStack(spacing: 8) {
                ForEach(displayedFiltered) { action in
                    let defineState = defineByAction[action.id]
                    let status = executionByAction[action.id]?.status ?? .noAction
                    let selectedResource = resourcesByAction[action.id].flatMap { resourceByID[$0] }
                    let hasLeverage = selectedResource != nil
                    let leverageIconName = {
                        guard let selectedResource else { return "person" }
                        return selectedResource.kind == .tool ? "wrench.and.screwdriver.fill" : "person.fill"
                    }()
                    let placeIDs = placesByAction[action.id] ?? []
                    let hasSensitivity = hasAnySensitivity(
                        actionId: action.id,
                        defineState: defineState,
                        placeIDs: placeIDs
                    )
                    let hasAttachments = hasAnyAttachments(
                        note: notesByAction[action.id],
                        attachments: attachmentsByAction[action.id] ?? []
                    )

                    if canReorderDisplayedActions {
                        actionRow(
                            action: action,
                            accent: accent,
                            defineState: defineState,
                            status: status,
                            hasLeverage: hasLeverage,
                            leverageIconName: leverageIconName,
                            hasSensitivity: hasSensitivity,
                            hasAttachments: hasAttachments,
                            highlightStatusBox: highlightedStatusActionIDs.contains(action.id),
                            showsReorderHandle: true
                        )
                        .id(action.id)
                        .onDrag {
                            let startingOrder = displayedFiltered.map(\.id)
                            draggedActionChunkID = chunk.id
                            localActionOrderIDs = startingOrder
                            draggedActionID = action.id
                            return NSItemProvider(object: action.id.uuidString as NSString)
                        }
                        .onDrop(
                            of: [.text],
                            delegate: AnimatedActionRowDropDelegate(
                                targetID: action.id,
                                draggedID: $draggedActionID,
                                draggedChunkID: $draggedActionChunkID,
                                localActionOrderIDs: $localActionOrderIDs,
                                enabled: true,
                                onCommit: { reorderedIDs in
                                    commitActionOrder(in: chunk.id, visibleOrderedIDs: reorderedIDs)
                                }
                            )
                        )
                    } else {
                        actionRow(
                            action: action,
                            accent: accent,
                            defineState: defineState,
                            status: status,
                            hasLeverage: hasLeverage,
                            leverageIconName: leverageIconName,
                            hasSensitivity: hasSensitivity,
                            hasAttachments: hasAttachments,
                            highlightStatusBox: highlightedStatusActionIDs.contains(action.id),
                            showsReorderHandle: false
                        )
                        .id(action.id)
                    }
                }
            }
            .onDrop(
                of: [.text],
                delegate: ResetActionRowDragStateDropDelegate(
                    ownerChunkID: chunk.id,
                    draggedID: $draggedActionID,
                    draggedChunkID: $draggedActionChunkID,
                    localActionOrderIDs: $localActionOrderIDs,
                    onCommit: { reorderedIDs in
                        commitActionOrder(in: chunk.id, visibleOrderedIDs: reorderedIDs)
                    }
                )
            )

            let isFilterApplied = isAnyFilterApplied
            let useFilterTotalsLabel = isFilterApplied && !isOnlyInactiveOnlyFilterApplied
            let totalSource = isFilterApplied ? filtered : allForChunk
            let activeActions = totalSource.filter { isActiveStatus(executionByAction[$0.id]?.status ?? .noAction) }
            let totalMinutes = activeActions.reduce(0) { partial, action in
                partial + (defineByAction[action.id]?.timeEstimateMinutes ?? 0)
            }
            let totalMustMinutes = activeActions.reduce(0) { partial, action in
                let st = defineByAction[action.id]
                guard isMust(for: action.id, defineByAction: defineByAction) else { return partial }
                return partial + (st?.timeEstimateMinutes ?? 0)
            }

            Divider().opacity(0.35)
            HStack(alignment: .bottom) {
                Spacer(minLength: 8)

                if !activeActions.isEmpty {
                    VStack(alignment: .trailing, spacing: 4) {
                        (
                            Text(useFilterTotalsLabel ? "Filter Total Time: " : "Total Time: ")
                                .font(.footnote)
                            + Text(formatMinutes(totalMinutes))
                                .font(.footnote)
                                .fontWeight(.bold)
                        )
                        .italic(useFilterTotalsLabel)
                        .foregroundStyle(Color.black.opacity(0.58))

                        (
                            Text(useFilterTotalsLabel ? "Filter Total Must Time: " : "Total Must Time: ")
                                .font(.footnote)
                            + Text(formatMinutes(totalMustMinutes))
                                .font(.footnote)
                                .fontWeight(.bold)
                        )
                        .italic(useFilterTotalsLabel)
                        .foregroundStyle(Color.black.opacity(0.58))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .multilineTextAlignment(.trailing)
                }
            }
        }
    }

    private func resultSection(resultText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("What do I want? Why do I want it?")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.58))
            }

            Text(resultText.isEmpty ? "-" : resultText)
                .font(.subheadline)
                .foregroundColor(resultText.isEmpty ? .secondary : .black)
        }
    }

    private func smallPill(icon: String, text: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
            Text(text)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func outcomePill(_ outcome: Outcomes) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "scope")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
            Text("\(daysUntil(outcome.end))d")
                .font(.system(size: 12, weight: .bold))
                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
            Text(outcome.outcome)
                .font(.system(size: 12, weight: .regular))
                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15), lineWidth: 1)
        )
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func daysUntil(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }

    private func actionRow(
        action: PlannedChunkAction,
        accent: Color,
        defineState: PlannedChunkActionDefineState?,
        status: ActionExecutionStatus,
        hasLeverage: Bool,
        leverageIconName: String,
        hasSensitivity: Bool,
        hasAttachments: Bool,
        highlightStatusBox: Bool,
        showsReorderHandle: Bool
    ) -> some View {
        ActionSwipeRow(
            actionId: action.id,
            text: action.text,
            dueStatusText: dueDateStatusTextForAction(action.id),
            dueStatusColor: dueDateStatusColorForAction(action.id),
            status: status,
            accent: accent,
            colorScheme: colorScheme,
            isMust: isMust(for: action.id, defineState: defineState),
            minutes: defineState?.timeEstimateMinutes,
            hasLeverage: hasLeverage,
            leverageIconName: leverageIconName,
            hasSensitivity: hasSensitivity,
            hasAttachments: hasAttachments,
            highlightStatusBox: highlightStatusBox,
            showsReorderHandle: showsReorderHandle,
            focusedActionID: $focusedActionID,
            onCommitText: { newValue in
                handleActionTextCommit(action: action, newValue: newValue)
            },
            onOpenStatus: {
                actionStatusActionID = ActionSheetID(id: action.id)
            },
            onToggleMust: { nextMust in
                scheduleMustPersist(for: action.id, isMust: nextMust)
            },
            onOpenClock: {
                durationActionID = ActionSheetID(id: action.id)
            },
            onOpenLeverage: {
                leverageActionID = ActionSheetID(id: action.id)
            },
            onOpenSensitivity: {
                sensitivityActionID = ActionSheetID(id: action.id)
            },
            onOpenAttachments: {
                attachmentsActionID = ActionSheetID(id: action.id)
            }
        )
    }

    private func addActionButton(for chunk: PlannedChunk) -> some View {
        Button {
            addActionChunkID = ChunkActionAddSheetID(id: chunk.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "plus")
                    .font(.caption2.weight(.semibold))
                Text("Add Action")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : .black)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func collapseButton() -> some View {
        Button {
            areAllActionBlocksCollapsed = true
            openFilter = nil
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "arrow.up.right.and.arrow.down.left")
                    .font(.caption2.weight(.semibold))
                Text("Collapse")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : .black)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func rearrangeActionsButton(for chunk: PlannedChunk, actions: [PlannedChunkAction], isEnabled: Bool) -> some View {
        let canRearrange = isEnabled && actions.count > 1
        return Button {
            guard canRearrange else { return }
            rearrangeActionsSheetID = RearrangeActionsSheetID(id: chunk.id)
        } label: {
            HStack(spacing: 6) {
                Image(systemName: "line.3.horizontal")
                    .font(.caption2.weight(.semibold))
                Text("Rearrange Actions")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(canRearrange ? (colorScheme == .dark ? Color.white.opacity(0.68) : .black) : .secondary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .disabled(!canRearrange)
    }

    private func tapToExpandLabel() -> some View {
        HStack(spacing: 6) {
            Image(systemName: "arrow.down.left.and.arrow.up.right")
                .font(.caption2)
            Text("Tap to Expand")
                .font(.caption2)
        }
        .foregroundStyle(Color(red: 0.42, green: 0.42, blue: 0.45))
        .padding(.top, 2)
    }

    private func collapsedFooterRow(
        actions: [PlannedChunkAction],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        defineByAction: [UUID: PlannedChunkActionDefineState]
    ) -> some View {
        let statuses = actions.map { executionByAction[$0.id]?.status ?? .noAction }
        let totalActionsCount = actions.count
        let inactiveActionsCount = statuses.filter { isCompletedForCollapsedMetrics($0) }.count
        let totalEstimatedMinutes = actions.reduce(0) { partial, action in
            partial + max(0, defineByAction[action.id]?.timeEstimateMinutes ?? 0)
        }
        let inactiveEstimatedMinutes = actions.reduce(0) { partial, action in
            let status = executionByAction[action.id]?.status ?? .noAction
            guard isCompletedForCollapsedMetrics(status) else { return partial }
            return partial + max(0, defineByAction[action.id]?.timeEstimateMinutes ?? 0)
        }

        return HStack(alignment: .center, spacing: 8) {
            tapToExpandLabel()
            Spacer(minLength: 8)

            HStack(alignment: .center, spacing: 8) {
                compactMetricChip(
                    label: "actions",
                    completed: inactiveActionsCount,
                    remaining: totalActionsCount,
                    total: totalActionsCount,
                    usePercentage: collapsedMetricsUsePercentage
                )

                compactMetricChip(
                    label: "time",
                    completed: inactiveEstimatedMinutes,
                    remaining: totalEstimatedMinutes,
                    total: totalEstimatedMinutes,
                    fractionSuffix: "m",
                    usePercentage: collapsedMetricsUsePercentage
                )

                Button(collapsedMetricsUsePercentage ? "fraction" : "percentage") {
                    collapsedMetricsUsePercentage.toggle()
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(Color.blue)
            }
            .layoutPriority(1)
        }
    }

    private func expandAllActionBlocksAndScrollToTop(anchor: String) {
        areAllActionBlocksCollapsed = false
        openFilter = nil
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.02) {
            pendingExpandChunkTopAnchor = anchor
        }
    }

    private func syncLocalChunkOrderIfNeeded(force: Bool) {
        let canonical = weekChunks
            .sorted { $0.chunkIndex < $1.chunkIndex }
            .map(\.id)
        if force || draggedChunkID == nil {
            if localChunkOrderIDs != canonical {
                localChunkOrderIDs = canonical
            }
        }
    }

    private func commitChunkOrder(_ orderedIDs: [UUID]) {
        let canonical = weekChunks
            .sorted { $0.chunkIndex < $1.chunkIndex }
            .map(\.id)
        let appendedMissing = orderedIDs + canonical.filter { !orderedIDs.contains($0) }
        let finalIDs = Array(appendedMissing.prefix(canonical.count))
        let byID = Dictionary(uniqueKeysWithValues: weekChunks.map { ($0.id, $0) })

        var changed = false
        for (newIndex, id) in finalIDs.enumerated() {
            guard let chunk = byID[id] else { continue }
            if chunk.chunkIndex != newIndex {
                chunk.chunkIndex = newIndex
                chunk.updatedAt = .now
                changed = true
            }
            for action in weekActions where action.plannedChunkId == chunk.id {
                if action.chunkIndex != newIndex {
                    action.chunkIndex = newIndex
                    changed = true
                }
            }
        }

        if changed {
            scheduleAutosave()
        }
    }

    private func commitActionOrder(in chunkID: UUID, visibleOrderedIDs: [UUID]) {
        guard !visibleOrderedIDs.isEmpty else { return }
        let visibleSet = Set(visibleOrderedIDs)
        let allInChunk = weekActions
            .filter { $0.plannedChunkId == chunkID }
            .sorted {
                if $0.sortOrder != $1.sortOrder { return $0.sortOrder < $1.sortOrder }
                return $0.id.uuidString < $1.id.uuidString
            }

        guard !allInChunk.isEmpty else { return }

        let hidden = allInChunk.filter { !visibleSet.contains($0.id) }
        let byID = Dictionary(uniqueKeysWithValues: allInChunk.map { ($0.id, $0) })
        let visibleOrdered = visibleOrderedIDs.compactMap { byID[$0] }
        let final = visibleOrdered + hidden

        var didChange = false
        for (index, action) in final.enumerated() {
            if action.sortOrder != index {
                action.sortOrder = index
                didChange = true
            }
        }
        if didChange {
            scheduleAutosave()
        }
    }

    private func compactSummaryRow(label: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.black)
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : text)
                .font(.subheadline)
                .foregroundStyle(.black)
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func compactActionsSummary(
        actions: [PlannedChunkAction],
        executionByAction: [UUID: PlannedChunkActionExecutionState]
    ) -> some View {
        let statuses = actions.map { executionByAction[$0.id]?.status ?? .noAction }
        let leveragedCount = statuses.filter { $0 == .leveraged }.count
        let inProgressCount = statuses.filter { $0 == .inProgress }.count
        let doneCount = statuses.filter { $0 == .done }.count
        let carriedCount = statuses.filter { $0 == .carriedToCapture }.count
        let notNeededCount = statuses.filter { $0 == .notNeeded }.count
        let noActionCount = statuses.filter { $0 == .noAction }.count

        return HStack(alignment: .center, spacing: 8) {
            Text("ACTIONS")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.black)

            if leveragedCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.leveraged.icon, count: leveragedCount)
            }
            if inProgressCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.inProgress.icon, count: inProgressCount)
            }
            if doneCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.done.icon, count: doneCount)
            }
            if carriedCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.carriedToCapture.icon, count: carriedCount)
            }
            if notNeededCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.notNeeded.icon, count: notNeededCount)
            }

            noActionCountChip(count: noActionCount)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactStatusCount(icon: String, count: Int) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(Color.black.opacity(0.72))
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
    }

    private func noActionCountChip(count: Int) -> some View {
        (
            Text("No action ")
                .font(.caption)
            + Text("\(count)")
                .font(.caption.weight(.bold))
        )
        .foregroundStyle(Color.black.opacity(0.72))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(Color.black.opacity(0.15), lineWidth: 1)
        )
    }

    private func compactMetricChip(
        label: String,
        completed: Int,
        remaining: Int,
        total: Int? = nil,
        fractionUsesRemainingOverTotal: Bool = false,
        fractionSuffix: String = "",
        usePercentage: Bool
    ) -> some View {
        let totalForPercent = total ?? max(completed + remaining, 0)
        let formattedValue: (Int) -> String = { value in
            guard fractionSuffix == "m" else {
                return fractionSuffix.isEmpty ? "\(value)" : "\(value)\(fractionSuffix)"
            }
            let minutes = max(0, value)
            guard minutes >= 60 else { return "\(minutes)m" }
            let hours = minutes / 60
            let mins = minutes % 60
            if mins == 0 { return "\(hours)h" }
            return "\(hours)h \(mins)m"
        }
        let leadText: String = {
            if usePercentage {
                let percent = totalForPercent > 0 ? Int((Double(completed) / Double(totalForPercent) * 100.0).rounded()) : 0
                return "\(percent)%"
            }
            let lhsCompleted = formattedValue(completed)
            let lhsRemaining = formattedValue(remaining)
            let rhsTotal = formattedValue(totalForPercent)
            if fractionUsesRemainingOverTotal {
                return "\(lhsRemaining)/\(rhsTotal)"
            }
            return "\(lhsCompleted)/\(lhsRemaining)"
        }()
        return HStack(spacing: 0) {
            Text(leadText)
                .font(.caption.weight(.bold))
            Text(" \(label)")
                .font(.caption)
        }
        .foregroundStyle(Color.black.opacity(0.72))
        .lineLimit(1)
        .truncationMode(.tail)
    }

    private func isCompletedForCollapsedMetrics(_ status: ActionExecutionStatus) -> Bool {
        status == .done || status == .carriedToCapture || status == .notNeeded
    }

    private var availableCaptureActions: [RollingCaptureItem] {
        captureItems.filter {
            !$0.isGhost && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var recurringRuleByID: [UUID: RecurringCaptureRule] {
        Dictionary(uniqueKeysWithValues: recurringRules.map { ($0.id, $0) })
    }

    private var recurringDispatchByItemID: [UUID: RecurringCaptureDispatch] {
        var result: [UUID: RecurringCaptureDispatch] = [:]
        for dispatch in recurringDispatches where result[dispatch.captureItemID] == nil {
            result[dispatch.captureItemID] = dispatch
        }
        return result
    }

    private func normalizedActionText(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == currentYear {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("E MMM d, yyyy")
        }
        return formatter.string(from: date)
    }

    private func dueDate(for captureItem: RollingCaptureItem) -> Date? {
        if let explicit = captureItem.dueDate {
            return Calendar.current.startOfDay(for: explicit)
        }
        guard let dispatch = recurringDispatchByItemID[captureItem.id],
              let rule = recurringRuleByID[dispatch.ruleID] else {
            return nil
        }
        let leadDays = max(7, rule.captureDaysBeforeDueDate)
        let due = Calendar.current.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
        return Calendar.current.startOfDay(for: due)
    }

    private func dueDateStatusText(for captureItem: RollingCaptureItem) -> String? {
        guard let due = dueDate(for: captureItem) else { return nil }
        let attention = min(max(captureItem.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        return dueDateStatusText(for: due, attentionDays: attention)
    }

    private func dueDateStatusColor(for captureItem: RollingCaptureItem) -> Color {
        guard let due = dueDate(for: captureItem) else { return .secondary }
        let dayDelta = Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: Date()), to: due).day ?? 0
        if dayDelta < 0 { return .red }
        if dayDelta == 0 { return .blue }
        return .secondary
    }

    private var dueSnapshotsByActionText: [String: PlannedActionDueSnapshot] {
        loadActionDueSnapshots(for: currentWeekStart)
    }

    private func loadActionDueSnapshots(for weekStart: Date) -> [String: PlannedActionDueSnapshot] {
        let key = actionDueSnapshotStorageKey(for: weekStart)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: PlannedActionDueSnapshot].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func actionDueSnapshotStorageKey(for weekStart: Date) -> String {
        "planned_action_due_snapshots_\(dayKey(for: weekStart))"
    }

    private func dayKey(for date: Date) -> String {
        let comps = Calendar.current.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func dueDateStatusText(for dueDate: Date, attentionDays: Int) -> String? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let due = cal.startOfDay(for: dueDate)
        let dayDelta = cal.dateComponents([.day], from: today, to: due).day ?? 0
        guard dayDelta <= attentionDays else { return nil }
        if dayDelta < 0 {
            let overdueDays = abs(dayDelta)
            let dayWord = overdueDays == 1 ? "day" : "days"
            return "Due \(overdueDays) \(dayWord) ago on \(formatDueDate(due))"
        } else if dayDelta == 0 {
            return "Due Today on \(formatDueDate(due))"
        } else {
            let dayWord = dayDelta == 1 ? "day" : "days"
            return "Due in \(dayDelta) \(dayWord) on \(formatDueDate(due))"
        }
    }

    private func dueDateStatusColor(for dueDate: Date) -> Color {
        let dayDelta = Calendar.current.dateComponents(
            [.day],
            from: Calendar.current.startOfDay(for: Date()),
            to: Calendar.current.startOfDay(for: dueDate)
        ).day ?? 0
        if dayDelta < 0 { return .red }
        if dayDelta == 0 { return .blue }
        return .secondary
    }

    private func captureItemForPlannedActionID(_ actionId: UUID) -> RollingCaptureItem? {
        guard let action = weekActions.first(where: { $0.id == actionId }) else { return nil }
        let actionText = normalizedActionText(action.text)
        return captureItems.first { normalizedActionText($0.text) == actionText }
    }

    private func dueDateStatusTextForAction(_ actionId: UUID) -> String? {
        if let item = captureItemForPlannedActionID(actionId) {
            return dueDateStatusText(for: item)
        }
        guard let action = weekActions.first(where: { $0.id == actionId }) else { return nil }
        let key = normalizedActionText(action.text)
        guard let snapshot = dueSnapshotsByActionText[key] else { return nil }
        return dueDateStatusText(for: snapshot.dueDate, attentionDays: snapshot.attentionDays)
    }

    private func dueDateStatusColorForAction(_ actionId: UUID) -> Color {
        if let item = captureItemForPlannedActionID(actionId) {
            return dueDateStatusColor(for: item)
        }
        guard let action = weekActions.first(where: { $0.id == actionId }) else { return .secondary }
        let key = normalizedActionText(action.text)
        guard let snapshot = dueSnapshotsByActionText[key] else { return .secondary }
        return dueDateStatusColor(for: snapshot.dueDate)
    }

    private func dueDateEditorState(forActionId actionId: UUID) -> DueDateEditorState? {
        guard let item = captureItemForPlannedActionID(actionId) else { return nil }
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        let resolvedDue = cal.startOfDay(
            for: item.dueDate
                ?? dueDate(for: item)
                ?? cal.date(byAdding: .day, value: 7, to: today)
                ?? today
        )
        let attention = min(max(item.dueDateAttentionDays ?? dueDateAttentionDays, 7), 30)
        return DueDateEditorState(
            hasDueDate: item.dueDate != nil,
            dueDate: resolvedDue,
            attentionDays: attention,
            minimumDate: today
        )
    }

    private func updateDueDateEditor(forActionId actionId: UUID, with updated: DueDateEditorState) {
        guard let item = captureItemForPlannedActionID(actionId) else { return }
        let normalizedDue = Calendar.current.startOfDay(for: updated.dueDate)
        let resolvedDue = updated.hasDueDate ? normalizedDue : nil
        item.dueDate = resolvedDue
        item.dueDateAttentionDays = min(max(updated.attentionDays, 7), 30)
        persistSourceDueDateOverrideIfNeeded(for: item, dueDate: resolvedDue)
        applyAppleReminderDueDateUpdateIfNeeded(for: item, dueDate: resolvedDue)
        scheduleAutosave()
    }

    private func sourceOverrideKey(sourceType: String, sourceID: String) -> String {
        "\(sourceType)|\(sourceID)"
    }

    private func decodedSourceDueDateOverrides() -> [String: ActionViewSourceDueDateOverrideRecord] {
        guard let data = sourceDueDateOverridesJSON.data(using: .utf8),
              let decoded = try? JSONDecoder().decode([String: ActionViewSourceDueDateOverrideRecord].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func saveSourceDueDateOverrides(_ map: [String: ActionViewSourceDueDateOverrideRecord]) {
        guard let data = try? JSONEncoder().encode(map),
              let json = String(data: data, encoding: .utf8) else { return }
        sourceDueDateOverridesJSON = json
    }

    private func persistSourceDueDateOverrideIfNeeded(for item: RollingCaptureItem, dueDate: Date?) {
        guard let sourceType = item.sourceType,
              let sourceID = item.sourceExternalID,
              !sourceID.isEmpty else { return }
        var map = decodedSourceDueDateOverrides()
        let normalizedDate = dueDate.map { Calendar.current.startOfDay(for: $0) }
        map[sourceOverrideKey(sourceType: sourceType, sourceID: sourceID)] = .init(
            hasDueDate: normalizedDate != nil,
            dueDateUnix: normalizedDate?.timeIntervalSince1970 ?? 0
        )
        saveSourceDueDateOverrides(map)
    }

    private func applyAppleReminderDueDateUpdateIfNeeded(for item: RollingCaptureItem, dueDate: Date?) {
        guard item.sourceType == "apple_reminder" else { return }
        guard let externalID = item.sourceExternalID, !externalID.isEmpty else { return }
        #if canImport(EventKit)
        let store = EKEventStore()
        let runUpdate: (Bool) -> Void = { granted in
            guard granted else { return }
            guard let reminder = store.calendarItem(withIdentifier: externalID) as? EKReminder else { return }
            do {
                if let dueDate {
                    var comps = Calendar.current.dateComponents([.year, .month, .day], from: dueDate)
                    comps.calendar = Calendar.current
                    reminder.dueDateComponents = comps
                } else {
                    reminder.dueDateComponents = nil
                }
                try store.save(reminder, commit: true)
            } catch { }
        }
        if #available(iOS 17.0, *) {
            store.requestFullAccessToReminders { granted, _ in runUpdate(granted) }
        } else {
            store.requestAccess(to: .reminder) { granted, _ in runUpdate(granted) }
        }
        #endif
    }

    private func insertAction(
        to chunk: PlannedChunk,
        initialText: String,
        focusAfterInsert: Bool,
        isPendingBlank: Bool,
        openDurationAfterInsert: Bool
    ) {
        let nextSort = (weekActions.filter { $0.plannedChunkId == chunk.id }.map(\.sortOrder).max() ?? -1) + 1
        let action = PlannedChunkAction(
            weekStart: currentWeekStart,
            chunkIndex: chunk.chunkIndex,
            plannedChunkId: chunk.id,
            text: initialText,
            sortOrder: nextSort,
            createdAt: .now
        )
        modelContext.insert(action)
        modelContext.insert(
            PlannedChunkActionAdHocMarker(
                weekStart: currentWeekStart,
                plannedChunkActionId: action.id
            )
        )
        if isPendingBlank {
            pendingNewActionIDs.insert(action.id)
        }
        scheduleAutosave()
        let chunkAnchor = "chunk-\(chunk.id.uuidString)"
        pendingChunkScrollAnchor = chunkAnchor
        if focusAfterInsert {
            pendingFocusActionID = action.id
        }
        if openDurationAfterInsert {
            pendingDurationDefaultActionID = action.id
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                durationActionID = ActionSheetID(id: action.id)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
            pendingChunkScrollAnchor = nil
        }
    }

    private func handleActionTextCommit(action: PlannedChunkAction, newValue: String) {
        if action.text != newValue {
            action.text = newValue
            scheduleAutosave()
        }

        let trimmed = newValue.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty, focusedActionID != action.id, !isKeyboardVisible, !pendingNewActionIDs.contains(action.id) {
            deleteActionAndLinkedData(action.id)
            return
        }

        if pendingNewActionIDs.contains(action.id), !trimmed.isEmpty {
            pendingNewActionIDs.remove(action.id)
            pendingDurationDefaultActionID = action.id
            durationActionID = ActionSheetID(id: action.id)
        }
    }

    private func markAllUncompletedAsRecapture() {
        for action in weekActions {
            let current = status(for: action.id)
            if current == .noAction || current == .leveraged || current == .inProgress {
                setStatus(for: action.id, to: .carriedToCapture)
            }
        }
    }

    private func buildFilteredActionsByChunk(
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        resourceCatalogByID: [UUID: LeverageResource]
    ) -> [UUID: [PlannedChunkAction]] {
        var result: [UUID: [PlannedChunkAction]] = [:]
        for action in weekActions {
            if actionMatchesFilters(
                action,
                defineByAction: defineByAction,
                executionByAction: executionByAction,
                resourcesByAction: resourcesByAction,
                placesByAction: placesByAction,
                notesByAction: notesByAction,
                attachmentsByAction: attachmentsByAction,
                resourceCatalogByID: resourceCatalogByID
            ) {
                result[action.plannedChunkId, default: []].append(action)
            }
        }
        // Display-only ordering rule:
        // - "In progress" actions are pinned to the top inside each chunk.
        // - Closed actions are pinned to the bottom inside each chunk.
        //   (Done, Carried to capture, Didn't need to be done)
        // - Base order remains `sortOrder`, so when status changes away from these
        //   pinned statuses the action naturally returns to its previous list position.
        for chunkId in result.keys {
            result[chunkId]?.sort { lhs, rhs in
                let lhsStatus = executionByAction[lhs.id]?.status ?? .noAction
                let rhsStatus = executionByAction[rhs.id]?.status ?? .noAction

                let lhsRank: Int
                switch lhsStatus {
                case .inProgress:
                    lhsRank = 0
                case .done, .carriedToCapture, .notNeeded:
                    lhsRank = 2
                default:
                    lhsRank = 1
                }

                let rhsRank: Int
                switch rhsStatus {
                case .inProgress:
                    rhsRank = 0
                case .done, .carriedToCapture, .notNeeded:
                    rhsRank = 2
                default:
                    rhsRank = 1
                }

                if lhsRank != rhsRank {
                    return lhsRank < rhsRank
                }
                if lhs.sortOrder != rhs.sortOrder {
                    return lhs.sortOrder < rhs.sortOrder
                }
                return lhs.id.uuidString < rhs.id.uuidString
            }
        }
        return result
    }

    private func actionMatchesFilters(
        _ action: PlannedChunkAction,
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        resourceCatalogByID: [UUID: LeverageResource],
        excludedFacets: Set<FilterFacet> = []
    ) -> Bool {
        let define = defineByAction[action.id]
        let status = executionByAction[action.id]?.status ?? .noAction

        if !excludedFacets.contains(.musts) && onlyMusts && !isMust(for: action.id, defineByAction: defineByAction) { return false }

        if !excludedFacets.contains(.place) && !selectedPlaceIDs.isEmpty {
            let selected = placesByAction[action.id] ?? []
            if selectedPlaceIDs.isDisjoint(with: selected) { return false }
        }

        let enforcePersonFilter = !excludedFacets.contains(.person) && !selectedPersonIDs.isEmpty
        let enforceToolFilter = !excludedFacets.contains(.tool) && !selectedToolIDs.isEmpty
        if enforcePersonFilter || enforceToolFilter {
            guard let resourceId = resourcesByAction[action.id], let resource = resourceCatalogByID[resourceId] else {
                return false
            }
            if enforcePersonFilter && enforceToolFilter {
                let matchesPerson = resource.kind == .person && selectedPersonIDs.contains(resource.id)
                let matchesTool = resource.kind == .tool && selectedToolIDs.contains(resource.id)
                if !(matchesPerson || matchesTool) { return false }
            } else if enforcePersonFilter {
                if resource.kind != .person || !selectedPersonIDs.contains(resource.id) { return false }
            } else if enforceToolFilter {
                if resource.kind != .tool || !selectedToolIDs.contains(resource.id) { return false }
            }
        }

        if !excludedFacets.contains(.timeOfDay) && !selectedTimeOfDay.isEmpty {
            let hasMorning = define?.sensitiveMorning ?? true
            let hasAfternoon = define?.sensitiveAfternoon ?? true
            let hasEvening = define?.sensitiveEvening ?? true
            let isAnytime = hasMorning && hasAfternoon && hasEvening

            var matchesAny = false
            if selectedTimeOfDay.contains(.any) && isAnytime { matchesAny = true }
            if selectedTimeOfDay.contains(.morning) && !isAnytime && hasMorning { matchesAny = true }
            if selectedTimeOfDay.contains(.afternoon) && !isAnytime && hasAfternoon { matchesAny = true }
            if selectedTimeOfDay.contains(.evening) && !isAnytime && hasEvening { matchesAny = true }
            if !matchesAny { return false }
        }

        if !excludedFacets.contains(.duration) && !selectedDurations.isEmpty {
            guard let minutes = define?.timeEstimateMinutes else { return false }
            if !selectedDurations.contains(minutes) { return false }
        }

        if !excludedFacets.contains(.attachments) && !selectedAttachmentKinds.isEmpty {
            if !matchesAttachmentKinds(
                note: notesByAction[action.id]?.noteText ?? "",
                attachments: attachmentsByAction[action.id] ?? [],
                selected: selectedAttachmentKinds
            ) {
                return false
            }
        }

        if !excludedFacets.contains(.activeOnly) {
            if inactiveOnly {
                if !isInactiveStatus(status) { return false }
            } else if isInactiveStatus(status) {
                return false
            }
        }
        if !excludedFacets.contains(.leveragedOnly) && leveragedOnly && status != .leveraged { return false }
        if !excludedFacets.contains(.inProgressOnly) && inProgressOnly && status != .inProgress { return false }

        return true
    }

    private func matchesAttachmentKinds(
        note: String,
        attachments: [PlannedChunkActionAttachment],
        selected: Set<ActionAttachmentFilterKind>
    ) -> Bool {
        let actionNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        for kind in selected {
            switch kind {
            case .note:
                if !actionNote.isEmpty { return true }
            case .link:
                if attachments.contains(where: { $0.kind == .link }) { return true }
            case .file:
                if attachments.contains(where: { $0.kind == .file }) { return true }
            }
        }
        return false
    }

    private func status(for actionId: UUID) -> ActionExecutionStatus {
        return executionStateByActionID[actionId]?.status ?? .noAction
    }

    private func isMust(for actionId: UUID, defineByAction: [UUID: PlannedChunkActionDefineState]) -> Bool {
        return defineByAction[actionId]?.isMust ?? false
    }

    private func isMust(for actionId: UUID, defineState: PlannedChunkActionDefineState?) -> Bool {
        return defineState?.isMust ?? false
    }

    private func setStatus(for actionId: UUID, to newStatus: ActionExecutionStatus) {
        if newStatus == .leveraged, selectedResourceByActionID[actionId] == nil {
            scheduleStatusPersist(for: actionId, status: .noAction)
            return
        }
        if newStatus == .inProgress {
            let current = status(for: actionId)
            if current != .inProgress && inProgressCount >= 3 {
                showCheckmarkLimitAlert = true
                return
            }
        }
        scheduleStatusPersist(for: actionId, status: newStatus)
    }

    private func scheduleStatusPersist(for actionId: UUID, status newStatus: ActionExecutionStatus) {
        deferredPersistor.enqueueStatus(for: actionId, status: newStatus, delayNanos: 220_000_000) { @MainActor statuses, musts in
            self.applyDeferredWrites(statuses: statuses, musts: musts)
        }
    }

    private func scheduleMustPersist(for actionId: UUID, isMust: Bool) {
        deferredPersistor.enqueueMust(for: actionId, isMust: isMust, delayNanos: 220_000_000) { @MainActor statuses, musts in
            self.applyDeferredWrites(statuses: statuses, musts: musts)
        }
    }

    private func clearLeveragedStatusIfNoSelection(for actionId: UUID) {
        guard status(for: actionId) == .leveraged else { return }
        guard selectedResourceByActionID[actionId] == nil else { return }
        scheduleStatusPersist(for: actionId, status: .noAction)
    }

    private func applyDeferredWrites(statuses: [UUID: ActionExecutionStatus], musts: [UUID: Bool]) {
        if !statuses.isEmpty {
            for (actionId, newStatus) in statuses {
                upsertExecutionState(forActionId: actionId) { state in
                    state.status = newStatus
                    state.updatedAt = .now
                }
            }
        }
        if !musts.isEmpty {
            for (actionId, isMust) in musts {
                upsertDefineState(forActionId: actionId) { st in
                    st.isMust = isMust
                    st.updatedAt = .now
                }
            }
        }
        if !statuses.isEmpty || !musts.isEmpty {
            scheduleAutosave()
        }
    }

    private func actionFont(status: ActionExecutionStatus) -> Font {
        switch status {
        case .leveraged:
            return .subheadline.italic()
        case .inProgress:
            return .subheadline.weight(.bold)
        default:
            return .subheadline
        }
    }

    private func actionTextColor(status: ActionExecutionStatus, accent: Color) -> Color {
        switch status {
        case .leveraged:
            return Color.primary.opacity(0.45)
        case .done, .carriedToCapture, .notNeeded:
            return Color.primary.opacity(0.25)
        case .inProgress:
            return accent
        case .noAction:
            return colorScheme == .dark ? Color.white.opacity(0.85) : .black
        }
    }

    private func isStrikeThrough(status: ActionExecutionStatus) -> Bool {
        status == .done || status == .carriedToCapture || status == .notNeeded
    }

    private func isInactiveStatus(_ status: ActionExecutionStatus) -> Bool {
        status == .done || status == .carriedToCapture || status == .notNeeded
    }

    private var isAnyFilterApplied: Bool {
        onlyMusts ||
        inactiveOnly ||
        leveragedOnly ||
        inProgressOnly ||
        !selectedPlaceIDs.isEmpty ||
        !selectedPersonIDs.isEmpty ||
        !selectedToolIDs.isEmpty ||
        !selectedTimeOfDay.isEmpty ||
        !selectedDurations.isEmpty ||
        !selectedAttachmentKinds.isEmpty
    }

    private var isOnlyInactiveOnlyFilterApplied: Bool {
        inactiveOnly &&
        !onlyMusts &&
        !leveragedOnly &&
        !inProgressOnly &&
        selectedPlaceIDs.isEmpty &&
        selectedPersonIDs.isEmpty &&
        selectedToolIDs.isEmpty &&
        selectedTimeOfDay.isEmpty &&
        selectedDurations.isEmpty &&
        selectedAttachmentKinds.isEmpty
    }

    private func isActiveStatus(_ status: ActionExecutionStatus) -> Bool {
        status == .noAction || status == .leveraged || status == .inProgress
    }

    private func formatMinutes(_ minutes: Int) -> String {
        let safe = max(0, minutes)
        if safe < 60 { return "\(safe)m" }
        let h = safe / 60
        let m = safe % 60
        return m == 0 ? "\(h)h" : "\(h)h \(m)m"
    }

    private func clockColor(minutes: Int?, accent: Color) -> Color {
        minutes == nil ? Color(.systemGray) : accent
    }

    private func hasAnySensitivity(
        actionId: UUID,
        defineState st: PlannedChunkActionDefineState?,
        placeIDs: Set<UUID>
    ) -> Bool {
        let hasTimePrefs = !(st?.sensitiveMorning ?? true) || !(st?.sensitiveAfternoon ?? true) || !(st?.sensitiveEvening ?? true)
        let hasPlaces = !placeIDs.isEmpty
        let hasDueDate = dueDateEditorState(forActionId: actionId)?.hasDueDate ?? false
        return hasTimePrefs || hasPlaces || hasDueDate
    }

    private func hasAnyAttachments(note: PlannedChunkActionNote?, attachments: [PlannedChunkActionAttachment]) -> Bool {
        let hasList = !attachments.isEmpty
        let hasNote = !(note?.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true)
        return hasList || hasNote
    }

    private func upsertDefineState(forActionId actionId: UUID, mutate: (PlannedChunkActionDefineState) -> Void) {
        if let existing = defineStateByActionID[actionId] {
            mutate(existing)
        } else {
            let st = makeBlankDefineState(actionId: actionId)
            mutate(st)
            modelContext.insert(st)
        }
    }

    private func makeBlankDefineState(actionId: UUID) -> PlannedChunkActionDefineState {
        PlannedChunkActionDefineState(
            weekStart: currentWeekStart,
            plannedChunkActionId: actionId,
            rank: 0,
            isMust: false,
            timeEstimateMinutes: nil,
            sensitiveMorning: true,
            sensitiveAfternoon: true,
            sensitiveEvening: true,
            updatedAt: .now
        )
    }

    private func upsertExecutionState(forActionId actionId: UUID, mutate: (PlannedChunkActionExecutionState) -> Void) {
        if let existing = executionStateByActionID[actionId] {
            mutate(existing)
        } else {
            let row = PlannedChunkActionExecutionState(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                statusRaw: ActionExecutionStatus.noAction.rawValue,
                updatedAt: .now
            )
            mutate(row)
            modelContext.insert(row)
        }
    }

    private func upsertLeverageSelection(forActionId actionId: UUID, mutate: (PlannedChunkActionLeverageSelection) -> Void) {
        if let existing = leverageSelections.first(where: { $0.plannedChunkActionId == actionId }) {
            mutate(existing)
        } else {
            let sel = PlannedChunkActionLeverageSelection(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                resourceId: nil,
                updatedAt: .now
            )
            mutate(sel)
            modelContext.insert(sel)
        }
    }

    private func upsertNote(forActionId actionId: UUID, mutate: (PlannedChunkActionNote) -> Void) {
        if let existing = notesByActionID[actionId] {
            mutate(existing)
        } else {
            let n = PlannedChunkActionNote(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                noteText: "",
                updatedAt: .now
            )
            mutate(n)
            modelContext.insert(n)
        }
    }

    private func togglePlaceSelection(actionId: UUID, placeId: UUID) {
        if let existing = placeLinks.first(where: { $0.plannedChunkActionId == actionId && $0.placeId == placeId }) {
            RecentlyDeletedStore.trash(existing, in: modelContext)
        } else {
            modelContext.insert(PlannedChunkActionSensitivityPlaceLink(
                weekStart: currentWeekStart,
                plannedChunkActionId: actionId,
                placeId: placeId,
                createdAt: .now
            ))
        }
    }

    private func ensureStateRowsExistForWeek() {
        var insertedAny = false
        for action in weekActions {
            if !defineStates.contains(where: { $0.plannedChunkActionId == action.id }) {
                modelContext.insert(PlannedChunkActionDefineState(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    rank: action.sortOrder,
                    isMust: false,
                    timeEstimateMinutes: nil,
                    sensitiveMorning: true,
                    sensitiveAfternoon: true,
                    sensitiveEvening: true,
                    updatedAt: .now
                ))
                insertedAny = true
            }
            if !executionStates.contains(where: { $0.plannedChunkActionId == action.id }) {
                modelContext.insert(PlannedChunkActionExecutionState(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    statusRaw: ActionExecutionStatus.noAction.rawValue,
                    updatedAt: .now
                ))
                insertedAny = true
            }
            if !leverageSelections.contains(where: { $0.plannedChunkActionId == action.id }) {
                modelContext.insert(PlannedChunkActionLeverageSelection(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    resourceId: nil,
                    updatedAt: .now
                ))
                insertedAny = true
            }
            if !notes.contains(where: { $0.plannedChunkActionId == action.id }) {
                modelContext.insert(PlannedChunkActionNote(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    noteText: "",
                    updatedAt: .now
                ))
                insertedAny = true
            }
        }
        if insertedAny {
            persistNow()
        }
    }

    private func applyCarriedProfilesToWeekActionsIfNeeded() {
        var didMutate = false

        for action in weekActions {
            guard !carriedProfileAppliedActionIDs.contains(action.id) else { continue }
            guard let profile = ActionCarryProfileStore.load(for: action.text) else { continue }

            upsertDefineState(forActionId: action.id) { st in
                st.isMust = profile.isMust
                st.timeEstimateMinutes = profile.timeEstimateMinutes
                st.sensitiveMorning = profile.sensitiveMorning
                st.sensitiveAfternoon = profile.sensitiveAfternoon
                st.sensitiveEvening = profile.sensitiveEvening
                st.updatedAt = .now
            }

            if let kindRaw = profile.leverageKindRaw,
               let kind = ActionLeverageKind(rawValue: kindRaw),
               let value = profile.leverageValue?.trimmingCharacters(in: .whitespacesAndNewlines),
               !value.isEmpty {
                let key = "\(kind.rawValue.lowercased())|\(value.lowercased())"
                let resource: LeverageResource
                if let existing = leverageCatalog.first(where: { $0.kindValueKey == key }) {
                    resource = existing
                } else {
                    let created = LeverageResource(kindRaw: kind.rawValue, value: value)
                    modelContext.insert(created)
                    resource = created
                }
                upsertLeverageSelection(forActionId: action.id) { sel in
                    sel.resourceId = resource.id
                    sel.updatedAt = .now
                }
            } else {
                upsertLeverageSelection(forActionId: action.id) { sel in
                    sel.resourceId = nil
                    sel.updatedAt = .now
                }
            }

            let trimmedPlaces = profile.placeNames
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
            let targetPlaceIDs: Set<UUID> = Set(trimmedPlaces.map { placeName in
                let normalized = placeName.lowercased()
                if let existing = placesCatalog.first(where: { $0.normalizedKey == normalized }) {
                    return existing.id
                }
                let created = SensitivityPlaceCatalogItem(place: placeName)
                modelContext.insert(created)
                return created.id
            })

            let existingLinks = placeLinks.filter { $0.plannedChunkActionId == action.id }
            let existingIDs = Set(existingLinks.map(\.placeId))
            for link in existingLinks where !targetPlaceIDs.contains(link.placeId) {
                RecentlyDeletedStore.trash(link, in: modelContext)
            }
            for placeID in targetPlaceIDs where !existingIDs.contains(placeID) {
                modelContext.insert(PlannedChunkActionSensitivityPlaceLink(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    placeId: placeID,
                    createdAt: .now
                ))
            }

            upsertNote(forActionId: action.id) { n in
                n.noteText = profile.noteText
                n.updatedAt = .now
            }

            let existingAttachments = attachments.filter { $0.plannedChunkActionId == action.id }
            for attachment in existingAttachments {
                RecentlyDeletedStore.trash(attachment, in: modelContext)
            }
            for attachment in profile.attachments {
                modelContext.insert(PlannedChunkActionAttachment(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    kindRaw: attachment.kindRaw,
                    urlString: attachment.urlString,
                    fileName: attachment.fileName,
                    fileBookmarkData: attachment.fileBookmarkData,
                    createdAt: .now
                ))
            }

            carriedProfileAppliedActionIDs.insert(action.id)
            didMutate = true
        }

        if didMutate {
            persistNow()
        }
    }

    private func toggleFilterMenu(_ menu: FilterMenu) {
        if openFilter == menu {
            openFilter = nil
        } else {
            openFilter = menu
        }
    }

    private func resetAllFilters() {
        selectedPlaceIDs.removeAll()
        selectedPersonIDs.removeAll()
        selectedToolIDs.removeAll()
        selectedTimeOfDay.removeAll()
        selectedDurations.removeAll()
        selectedAttachmentKinds.removeAll()
        onlyMusts = false
        inactiveOnly = false
        leveragedOnly = false
        inProgressOnly = false
        openFilter = nil
    }

    private func isFilterMenuAvailable(_ menu: FilterMenu) -> Bool {
        switch menu {
        case .place: return hasPlaceFilterButton
        case .person: return hasPersonFilterButton
        case .tool: return hasToolFilterButton
        case .timeOfDay: return hasTimeOfDayFilterButton
        case .duration: return hasDurationFilterButton
        case .attachments: return hasAttachmentsFilterButton
        }
    }

    private func handleScrollOffsetChange(_ y: CGFloat) {
        let now = Date().timeIntervalSinceReferenceDate
        let dy = y - lastScrollY
        let dt = max(0.016, now - lastScrollTimestamp)
        let velocity = dy / CGFloat(dt)

        // Scrolling down collapses the header quickly.
        if dy < -6, !isHeaderCollapsed {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isHeaderCollapsed = true
                openFilter = nil
            }
        }

        // A quick upward scroll expands it.
        if dy > 10, velocity > 700, isHeaderCollapsed {
            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                isHeaderCollapsed = false
            }
        }

        lastScrollY = y
        lastScrollTimestamp = now
    }

    private func dismissKeyboardAndCommit() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        persistNow()
    }

    private func handleDurationSheetDismiss() {
        guard let actionId = pendingDurationDefaultActionID else { return }
        pendingDurationDefaultActionID = nil

        if defineStateByActionID[actionId]?.timeEstimateMinutes == nil {
            upsertDefineState(forActionId: actionId) { st in
                st.timeEstimateMinutes = 5
                st.updatedAt = .now
            }
            scheduleAutosave()
        }
    }
    private func showCompleteActionsHint() {
        let active = Set(weekActions.filter { isActiveStatus(status(for: $0.id)) }.map(\.id))
        highlightedStatusActionIDs = active
        withAnimation(.easeInOut(duration: 0.18)) {
            showCompleteHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.4) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCompleteHint = false
            }
            highlightedStatusActionIDs = []
        }
    }

    private func deleteActionAndLinkedData(_ actionId: UUID) {
        if let st = defineStateByActionID[actionId] { RecentlyDeletedStore.trash(st, in: modelContext) }
        if let st = executionStateByActionID[actionId] { RecentlyDeletedStore.trash(st, in: modelContext) }
        if let sel = leverageSelections.first(where: { $0.plannedChunkActionId == actionId }) { RecentlyDeletedStore.trash(sel, in: modelContext) }
        if let note = notesByActionID[actionId] { RecentlyDeletedStore.trash(note, in: modelContext) }
        for link in placeLinks where link.plannedChunkActionId == actionId { RecentlyDeletedStore.trash(link, in: modelContext) }
        for a in attachments where a.plannedChunkActionId == actionId { RecentlyDeletedStore.trash(a, in: modelContext) }
        if let action = weekActions.first(where: { $0.id == actionId }) {
            RecentlyDeletedStore.trash(action, in: modelContext)
        }
        pendingNewActionIDs.remove(actionId)
        if pendingDurationDefaultActionID == actionId { pendingDurationDefaultActionID = nil }
        if scrollTargetActionID == actionId { scrollTargetActionID = nil }
        if focusedActionID == actionId { focusedActionID = nil }
        scheduleAutosave()
    }

    private func cleanupAllBlankActions() {
        if isKeyboardVisible { return }
        let focused = focusedActionID
        for action in weekActions {
            let trimmed = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty, focused != action.id, !pendingNewActionIDs.contains(action.id) {
                deleteActionAndLinkedData(action.id)
            }
        }
    }

    private func cleanupPendingBlankActions() {
        guard !pendingNewActionIDs.isEmpty else { return }
        let pending = pendingNewActionIDs
        for id in pending {
            guard let action = weekActions.first(where: { $0.id == id }) else {
                pendingNewActionIDs.remove(id)
                continue
            }
            let trimmed = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                deleteActionAndLinkedData(id)
            } else {
                pendingNewActionIDs.remove(id)
            }
        }
    }

    private var placeFilterTitle: String {
        switch selectedPlaceIDs.count {
        case 0: return "Place"
        case 1:
            guard let id = selectedPlaceIDs.first else { return "Place" }
            return availablePlaceItems.first(where: { $0.id == id })?.place ?? "Place"
        default:
            return "\(selectedPlaceIDs.count)"
        }
    }

    private var personFilterTitle: String {
        switch selectedPersonIDs.count {
        case 0: return "Person"
        case 1:
            guard let id = selectedPersonIDs.first else { return "Person" }
            return availablePersonResources.first(where: { $0.id == id })?.value ?? "Person"
        default:
            return "\(selectedPersonIDs.count)"
        }
    }

    private var toolFilterTitle: String {
        switch selectedToolIDs.count {
        case 0: return "Tool"
        case 1:
            guard let id = selectedToolIDs.first else { return "Tool" }
            return availableToolResources.first(where: { $0.id == id })?.value ?? "Tool"
        default:
            return "\(selectedToolIDs.count)"
        }
    }

    private var timeOfDayFilterTitle: String {
        switch selectedTimeOfDay.count {
        case 0: return "Time of Day"
        case 1: return selectedTimeOfDay.first?.title ?? "Time of Day"
        default: return "\(selectedTimeOfDay.count)"
        }
    }

    private var durationFilterTitle: String {
        switch selectedDurations.count {
        case 0: return "Duration"
        case 1:
            guard let only = selectedDurations.first else { return "Duration" }
            return "\(only)m"
        default:
            return "\(selectedDurations.count)"
        }
    }

    private var attachmentsFilterTitle: String {
        switch selectedAttachmentKinds.count {
        case 0: return "Has Attachments"
        case 1: return selectedAttachmentKinds.first?.title ?? "Has Attachments"
        default: return "\(selectedAttachmentKinds.count)"
        }
    }

    private func filterChip(
        title: String,
        iconName: String,
        isActive: Bool,
        showsChevron: Bool = true,
        isOpen: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.subheadline.weight(.semibold))
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if showsChevron {
                    Image(systemName: isOpen ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.primary)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(isActive ? Color.accentColor : Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(isActive ? Color.accentColor : Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }

    private func wrapSelectablePills<T>(
        options: [T],
        isSelected: @escaping (T) -> Bool,
        label: @escaping (T) -> String,
        onTap: @escaping (T) -> Void
    ) -> some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: 8)], spacing: 8) {
            ForEach(Array(options.enumerated()), id: \.offset) { _, item in
                Button {
                    onTap(item)
                } label: {
                    Text(label(item))
                        .font(.footnote)
                        .foregroundStyle(isSelected(item) ? Color.white : Color.primary)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .frame(maxWidth: .infinity)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(isSelected(item) ? Color.accentColor : Color(.systemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(isSelected(item) ? Color.accentColor : Color.black.opacity(0.15), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func persistNow() {
        try? modelContext.save()
    }

    private func deactivatePlanIfNoActionBlocks() {
        guard weekChunks.isEmpty else { return }
        let state = activePlanStates.first ?? ActivePlanState.fetchOrCreate(in: modelContext)
        guard state.isActive || state.weekStart != nil else { return }
        state.isActive = false
        state.weekStart = nil
        try? modelContext.save()
    }

    private func scheduleAutosave() {
        autosaveTask?.cancel()
        autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            persistNow()
        }
    }

    private func categoryFillColor(for category: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: category)
    }

    private func categoryAccentColor(for category: String) -> Color {
        FulfillmentCategoryTheme.color(for: category)
    }
}

private enum FilterMenu: String, Identifiable {
    case place
    case person
    case tool
    case timeOfDay
    case duration
    case attachments

    var id: String { rawValue }
}

private enum FilterChipKind: Hashable {
    case activeOnly
    case musts
    case place
    case person
    case duration
    case tool
    case timeOfDay
    case leveragedOnly
    case attachments
    case inProgressOnly
}

private final class ActionDeferredPersistor {
    private var pendingStatuses: [UUID: ActionExecutionStatus] = [:]
    private var pendingMusts: [UUID: Bool] = [:]
    private var flushTask: Task<Void, Never>? = nil

    func enqueueStatus(
        for actionId: UUID,
        status: ActionExecutionStatus,
        delayNanos: UInt64,
        flush: @escaping @MainActor (_ statuses: [UUID: ActionExecutionStatus], _ musts: [UUID: Bool]) -> Void
    ) {
        pendingStatuses[actionId] = status
        scheduleFlush(delayNanos: delayNanos, flush: flush)
    }

    func enqueueMust(
        for actionId: UUID,
        isMust: Bool,
        delayNanos: UInt64,
        flush: @escaping @MainActor (_ statuses: [UUID: ActionExecutionStatus], _ musts: [UUID: Bool]) -> Void
    ) {
        pendingMusts[actionId] = isMust
        scheduleFlush(delayNanos: delayNanos, flush: flush)
    }

    func takePendingAndCancel() -> (statuses: [UUID: ActionExecutionStatus], musts: [UUID: Bool]) {
        flushTask?.cancel()
        flushTask = nil
        let snapshot = (pendingStatuses, pendingMusts)
        pendingStatuses.removeAll()
        pendingMusts.removeAll()
        return snapshot
    }

    private func scheduleFlush(
        delayNanos: UInt64,
        flush: @escaping @MainActor (_ statuses: [UUID: ActionExecutionStatus], _ musts: [UUID: Bool]) -> Void
    ) {
        flushTask?.cancel()
        flushTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: delayNanos)
            guard let self, !Task.isCancelled else { return }
            let statuses = self.pendingStatuses
            let musts = self.pendingMusts
            self.pendingStatuses.removeAll()
            self.pendingMusts.removeAll()
            await flush(statuses, musts)
        }
    }
}

private struct ActionSheetID: Identifiable, Hashable {
    let id: UUID
}

private struct ChunkActionAddSheetID: Identifiable, Hashable {
    let id: UUID
}

private struct RearrangeActionsSheetID: Identifiable, Hashable {
    let id: UUID
}

private struct ActionScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum TimeOfDayChoice: String, CaseIterable, Hashable {
    case any
    case morning
    case afternoon
    case evening

    var title: String {
        switch self {
        case .any: return "Any"
        case .morning: return "Morning"
        case .afternoon: return "Afternoon"
        case .evening: return "Evening"
        }
    }
}

private enum ActionAttachmentFilterKind: String, CaseIterable, Hashable {
    case note
    case link
    case file

    var title: String {
        switch self {
        case .note: return "Notes"
        case .link: return "Links"
        case .file: return "Files"
        }
    }
}

private struct AddActionFromCaptureSheet: View {
    let captureItems: [RollingCaptureItem]
    let onDone: (AddActionSelection?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var selectedID: UUID? = nil
    @State private var isNewActionMode: Bool = false
    @State private var newActionText: String = ""
    @FocusState private var isNewActionFocused: Bool

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        Button {
                            isNewActionMode = true
                            selectedID = nil
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                                isNewActionFocused = true
                            }
                        } label: {
                            HStack(spacing: 10) {
                                if isNewActionMode {
                                    TextField("Action", text: $newActionText, axis: .vertical)
                                        .lineLimit(2)
                                        .focused($isNewActionFocused)
                                } else {
                                    Text("+ New Action")
                                        .fontWeight(.semibold)
                                        .foregroundStyle(.blue)
                                }
                                Spacer()
                                if isNewActionMode {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }

                    Section("Capture") {
                        if captureItems.isEmpty {
                            Text("No capture actions available.")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(captureItems) { item in
                                Button {
                                    if isNewActionMode {
                                        isNewActionMode = false
                                        newActionText = ""
                                        isNewActionFocused = false
                                    }
                                    selectedID = (selectedID == item.id) ? nil : item.id
                                } label: {
                                    HStack(spacing: 10) {
                                        Text(item.text)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .foregroundStyle(.primary)
                                        if selectedID == item.id {
                                            Image(systemName: "checkmark.circle.fill")
                                                .foregroundStyle(.blue)
                                        }
                                    }
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                HStack {
                    Spacer()
                    Button("Done") {
                        let typed = newActionText.trimmingCharacters(in: .whitespacesAndNewlines)
                        let selection: AddActionSelection?
                        if isNewActionMode {
                            selection = typed.isEmpty ? nil : AddActionSelection(text: typed, captureItemID: nil)
                        } else if let selectedID, let item = captureItems.first(where: { $0.id == selectedID }) {
                            selection = AddActionSelection(text: item.text, captureItemID: item.id)
                        } else {
                            selection = nil
                        }
                        dismiss()
                        onDone(selection)
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(isDoneDisabled)
                }
                .padding(.horizontal)
                .padding(.vertical, 10)
            }
            .navigationTitle("Add Action")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var isDoneDisabled: Bool {
        if isNewActionMode {
            return newActionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return selectedID == nil
    }
}

private struct AddActionSelection {
    let text: String
    let captureItemID: UUID?
}

private struct ActionInstructionsPopup: View {
    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse)
    private var allWeeklyMindsetEntries: [WeeklyMindsetEntry.Fields]

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var currentEntry: WeeklyMindsetEntry.Fields? {
        allWeeklyMindsetEntries.first {
            Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart)
        }
    }

    private var gratitudeValue: String {
        currentEntry?.morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    private var inspirationValue: String {
        currentEntry?.incantation.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if !gratitudeValue.isEmpty {
                        motivationRow(
                            title: "What am I happy for or grateful about in life right now?",
                            subtitle: nil,
                            value: gratitudeValue
                        )
                    }
                    if !inspirationValue.isEmpty {
                        motivationRow(
                            title: "What’s a simple phrase that inspires you?",
                            subtitle: nil,
                            value: inspirationValue
                        )
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Motivation")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func motivationRow(title: String, subtitle: String?, value: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            if let subtitle, !subtitle.isEmpty {
                Text(subtitle)
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(.secondary)
            }
            Text(value)
                .font(.body)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct TimeEstimateSheet: View {
    let currentMinutes: Int?
    let onSelect: (Int) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [Int] = [5, 10, 15, 20, 30, 45, 60, 90, 120, 180, 240]
    @State private var selection: Int = 15

    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                Text("Estimate minutes to complete action")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)

                Picker("Minutes", selection: $selection) {
                    ForEach(options, id: \.self) { m in
                        Text("\(m)").tag(m)
                    }
                }
                .pickerStyle(.wheel)
                .frame(height: 160)

                Button("Set") {
                    onSelect(selection)
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
            .padding()
            .onAppear { selection = currentMinutes ?? 15 }
            .navigationTitle("Duration")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct LeverageSheet: View {
    let leverageCatalog: [LeverageResource]
    let selectedResourceId: UUID?
    let onAdd: (ActionLeverageKind, String) -> Void
    let onDeleteCatalogItems: (Set<UUID>) -> Void
    let onSelectResource: (UUID?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var localSelection: UUID? = nil
    @State private var isNewResourceMode: Bool = false
    @State private var kind: ActionLeverageKind = .person
    @State private var value: String = ""
    @FocusState private var isNewResourceFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Leverage action to someone or something else")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Section("Resources") {
                    Button {
                        isNewResourceMode = true
                        localSelection = nil
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewResourceFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewResourceMode {
                                TextField(kind == .person ? "Add person…" : "Add tool…", text: $value)
                                    .focused($isNewResourceFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlineResource()
                                    }
                            } else {
                                Text("+ Add Resource")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewResourceMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if leverageCatalog.isEmpty {
                        Text("None yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(leverageCatalog.sorted(by: { $0.createdAt < $1.createdAt })) { item in
                            Button {
                                if isNewResourceMode {
                                    isNewResourceMode = false
                                    value = ""
                                    isNewResourceFocused = false
                                }
                                localSelection = (localSelection == item.id) ? nil : item.id
                            } label: {
                                HStack {
                                    Text(item.kind == .person ? "Person" : "Tool")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                        .frame(width: 60, alignment: .leading)

                                    Text(item.value)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if localSelection == item.id {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteCatalogItems([item.id])
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Leverage")
            .navigationBarTitleDisplayMode(.inline)
            .safeAreaInset(edge: .bottom) {
                if isNewResourceMode && isNewResourceFocused {
                    VStack(spacing: 8) {
                        Picker("Type", selection: $kind) {
                            ForEach(ActionLeverageKind.allCases) { k in
                                Text(k.title).tag(k)
                            }
                        }
                        .pickerStyle(.segmented)
                    }
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                }
            }
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitInlineResource()
                        onSelectResource(localSelection)
                        dismiss()
                    }
                }
            }
            .onAppear { localSelection = selectedResourceId }
        }
    }

    private func commitInlineResource() {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewResourceMode, !trimmed.isEmpty else { return }
        onAdd(kind, trimmed)
        value = ""
        isNewResourceMode = false
        isNewResourceFocused = false
    }
}

private struct SensitivitySheet: View {
    @Binding var defineState: PlannedChunkActionDefineState
    let placesCatalog: [SensitivityPlaceCatalogItem]
    let selectedPlaceIDs: Set<UUID>
    let onAddPlaceToCatalog: (String) -> Void
    let onDeleteCatalogPlaces: (Set<UUID>) -> Void
    let onTogglePlaceSelected: (UUID) -> Void
    let dueDateEditor: ActionView.DueDateEditorState?
    let highlightDueDateRequirementOnAppear: Bool
    let onSaveDueDateEditor: (ActionView.DueDateEditorState) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var newPlace: String = ""
    @State private var isNewPlaceMode: Bool = false
    @FocusState private var isNewPlaceFocused: Bool
    @State private var localHasDueDate: Bool = false
    @State private var localDueDate: Date = .now
    @State private var localAttentionDays: Int = 7
    @State private var localMinimumDate: Date = Calendar.current.startOfDay(for: Date())
    @State private var showLeverageDueDateError: Bool = false
    private let dueDateScrollAnchorID: String = "sensitivity_due_date_anchor"
    private var isAnytimeOfDay: Bool {
        defineState.sensitiveMorning && defineState.sensitiveAfternoon && defineState.sensitiveEvening
    }

    var body: some View {
        NavigationStack {
            ScrollViewReader { proxy in
                List {
                Section("Time of Day") {
                    HStack {
                        Text("Can be completed anytime")
                        Spacer()
                        Menu {
                            Button("Yes") { setAnytimeOfDay(true) }
                            Button("No") { setAnytimeOfDay(false) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(isAnytimeOfDay ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if !isAnytimeOfDay {
                        Toggle("Morning", isOn: bindingForTimeOfDay(\.sensitiveMorning))
                        Toggle("Afternoon", isOn: bindingForTimeOfDay(\.sensitiveAfternoon))
                        Toggle("Evening", isOn: bindingForTimeOfDay(\.sensitiveEvening))
                    }
                }

                if dueDateEditor != nil {
                    Section("Due Date") {
                        HStack {
                            Text("Due Date")
                            Spacer()
                            Menu {
                                Button("No") { localHasDueDate = false }
                                Button("Yes") { localHasDueDate = true }
                            } label: {
                                HStack(spacing: 4) {
                                    Text(localHasDueDate ? "Yes" : "No")
                                    Image(systemName: "chevron.up.chevron.down")
                                }
                                .foregroundStyle(.blue)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(showLeverageDueDateError && !localHasDueDate ? Color.red : Color.clear, lineWidth: 2)
                        )

                        if localHasDueDate {
                            HStack {
                                Text("Set Due Date")
                                Spacer()
                                DatePicker(
                                    "",
                                    selection: $localDueDate,
                                    in: localMinimumDate...,
                                    displayedComponents: .date
                                )
                                .labelsHidden()
                                .datePickerStyle(.compact)
                            }

                            HStack {
                                Text("Attention")
                                Spacer()
                                Menu {
                                    ForEach(7...30, id: \.self) { value in
                                        Button("\(value) days") {
                                            localAttentionDays = value
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text("\(min(max(localAttentionDays, 7), 30)) days")
                                        Image(systemName: "chevron.up.chevron.down")
                                    }
                                    .foregroundStyle(.blue)
                                }
                            }

                            Text("Attention triggers countdown to display.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                    }
                    .id(dueDateScrollAnchorID)
                }

                Section("Places") {
                    Button {
                        isNewPlaceMode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewPlaceFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewPlaceMode {
                                TextField("Add place…", text: $newPlace)
                                    .focused($isNewPlaceFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlinePlace()
                                    }
                            } else {
                                Text("+ New Place")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewPlaceMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if placesCatalog.isEmpty {
                        Text("No places yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(placesCatalog) { p in
                            Button {
                                if isNewPlaceMode {
                                    isNewPlaceMode = false
                                    newPlace = ""
                                    isNewPlaceFocused = false
                                }
                                onTogglePlaceSelected(p.id)
                            } label: {
                                HStack {
                                    Text(p.place)
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if selectedPlaceIDs.contains(p.id) {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.blue)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteCatalogPlaces([p.id])
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }

                }
                .navigationTitle("Sensitivities")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            commitInlinePlace()
                            if dueDateEditor != nil {
                                onSaveDueDateEditor(
                                    ActionView.DueDateEditorState(
                                        hasDueDate: localHasDueDate,
                                        dueDate: localDueDate,
                                        attentionDays: min(max(localAttentionDays, 7), 30),
                                        minimumDate: localMinimumDate
                                    )
                                )
                            }
                            dismiss()
                        }
                    }
                }
                .onAppear {
                    if let dueDateEditor {
                        localHasDueDate = dueDateEditor.hasDueDate
                        localDueDate = dueDateEditor.dueDate
                        localAttentionDays = dueDateEditor.attentionDays
                        localMinimumDate = dueDateEditor.minimumDate
                    }
                    showLeverageDueDateError = highlightDueDateRequirementOnAppear
                    if highlightDueDateRequirementOnAppear {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                proxy.scrollTo(dueDateScrollAnchorID, anchor: .center)
                            }
                        }
                    }
                }
                .onChange(of: localHasDueDate) { _, hasDueDate in
                    if hasDueDate {
                        showLeverageDueDateError = false
                    }
                }
                .onDisappear {
                    normalizeTimeOfDayIfNoneSelected()
                }
                .overlay(alignment: .bottom) {
                    if showLeverageDueDateError && !localHasDueDate {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("You must add a due date to leverage action to hold your resources accountable")
                                .font(.footnote)
                                .fontWeight(.bold)
                            Text("If not completed in this action block, the Resource and due date will be saved to your Capture list and future Action Blocks.")
                                .font(.footnote)
                        }
                        .multilineTextAlignment(.leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color.black.opacity(0.12), lineWidth: 1)
                        )
                        .padding(.horizontal, 8)
                        .padding(.bottom, 8)
                        .transition(.opacity)
                    }
                }
            }
        }
    }

    private func commitInlinePlace() {
        let trimmed = newPlace.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewPlaceMode, !trimmed.isEmpty else { return }
        onAddPlaceToCatalog(trimmed)
        newPlace = ""
        isNewPlaceMode = false
        isNewPlaceFocused = false
    }

    private func bindingForTimeOfDay(_ keyPath: WritableKeyPath<PlannedChunkActionDefineState, Bool>) -> Binding<Bool> {
        Binding(
            get: { defineState[keyPath: keyPath] },
            set: { newValue in
                let current = (
                    morning: defineState.sensitiveMorning,
                    afternoon: defineState.sensitiveAfternoon,
                    evening: defineState.sensitiveEvening
                )

                var proposed = current
                if keyPath == \.sensitiveMorning { proposed.morning = newValue }
                if keyPath == \.sensitiveAfternoon { proposed.afternoon = newValue }
                if keyPath == \.sensitiveEvening { proposed.evening = newValue }

                let onCount = [proposed.morning, proposed.afternoon, proposed.evening].filter { $0 }.count
                guard onCount <= 2 else { return }

                defineState[keyPath: keyPath] = newValue
            }
        )
    }

    private func setAnytimeOfDay(_ enabled: Bool) {
        if enabled {
            defineState.sensitiveMorning = true
            defineState.sensitiveAfternoon = true
            defineState.sensitiveEvening = true
            return
        }

        if isAnytimeOfDay {
            defineState.sensitiveMorning = false
            defineState.sensitiveAfternoon = false
            defineState.sensitiveEvening = false
        }
    }

    private func normalizeTimeOfDayIfNoneSelected() {
        let onCount = [
            defineState.sensitiveMorning,
            defineState.sensitiveAfternoon,
            defineState.sensitiveEvening
        ].filter { $0 }.count
        if onCount == 0 {
            setAnytimeOfDay(true)
        }
    }
}

private struct AttachmentsSheet: View {
    let attachments: [PlannedChunkActionAttachment]
    let initialNoteText: String
    let onSaveNote: (String) -> Void
    let onAddLink: (String) -> Void
    let onAddFile: (URL, Data, String) -> Void
    let onDeleteAttachment: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var linkText: String = ""
    @State private var isNewLinkMode: Bool = false
    @FocusState private var isNewLinkFocused: Bool
    @State private var isFileImporterPresented: Bool = false
    @State private var noteText: String = ""
    @State private var hasSavedNote: Bool = false

    var body: some View {
        NavigationStack {
            List {
                Section("Notes") {
                    TextEditor(text: $noteText)
                        .frame(height: 120)
                }

                Section("Files and Links") {
                    Button {
                        isNewLinkMode = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isNewLinkFocused = true
                        }
                    } label: {
                        HStack(spacing: 10) {
                            if isNewLinkMode {
                                TextField("Add link…", text: $linkText)
                                    .focused($isNewLinkFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlineLink()
                                    }
                            } else {
                                Text("+ New Link")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                            }
                            Spacer()
                            if isNewLinkMode {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    Button("Attach file…") {
                        isFileImporterPresented = true
                    }

                    if attachments.isEmpty {
                        Text("No attachments yet.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(attachments) { a in
                            Button {
                                openAttachment(a)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image(systemName: iconName(for: a))
                                        .foregroundStyle(.secondary)

                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(titleText(for: a))
                                            .font(.subheadline)
                                            .foregroundStyle(.primary)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .swipeActions(edge: .trailing) {
                                Button(role: .destructive) {
                                    onDeleteAttachment(a.id)
                                } label: {
                                    Text("Delete")
                                }
                                .tint(.red)
                            }
                        }
                    }
                }
            }
            .fileImporter(
                isPresented: $isFileImporterPresented,
                allowedContentTypes: [.item],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    do {
                        #if os(macOS)
                        let bookmark = try url.bookmarkData(
                            options: .withSecurityScope,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #else
                        let bookmark = try url.bookmarkData(
                            options: .minimalBookmark,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        #endif
                        onAddFile(url, bookmark, url.lastPathComponent)
                    } catch { }
                case .failure:
                    break
                }
            }
            .navigationTitle("Attachments")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNoteIfNeeded()
                        commitInlineLink()
                        dismiss()
                    }
                }
            }
            .onAppear {
                noteText = initialNoteText
                hasSavedNote = false
            }
            .onDisappear {
                commitNoteIfNeeded()
            }
        }
    }

    private func commitNoteIfNeeded() {
        guard !hasSavedNote else { return }
        hasSavedNote = true
        onSaveNote(noteText)
    }

    private func commitInlineLink() {
        let trimmed = linkText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard isNewLinkMode, !trimmed.isEmpty else { return }
        onAddLink(trimmed)
        linkText = ""
        isNewLinkMode = false
        isNewLinkFocused = false
    }

    private func iconName(for a: PlannedChunkActionAttachment) -> String {
        switch a.kind {
        case .link: return "link"
        case .note: return "note.text"
        case .file: return "doc"
        }
    }

    private func titleText(for a: PlannedChunkActionAttachment) -> String {
        switch a.kind {
        case .link:
            return a.urlString ?? "(link)"
        case .note:
            return "Note"
        case .file:
            return a.fileName ?? "(file)"
        }
    }

    private func openAttachment(_ a: PlannedChunkActionAttachment) {
        switch a.kind {
        case .link:
            if let urlString = a.urlString, let url = URL(string: urlString) {
                openURL(url)
            }
        case .file:
            guard let data = a.fileBookmarkData else { return }
            var isStale = false
            #if os(macOS)
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI, .withSecurityScope],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if let url = try? URL(
                resolvingBookmarkData: data,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                openURL(url)
            }
            #else
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            } else if let url = try? URL(
                resolvingBookmarkData: data,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                let didAccess = url.startAccessingSecurityScopedResource()
                openURL(url)
                if didAccess {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                        url.stopAccessingSecurityScopedResource()
                    }
                }
            }
            #endif
        case .note:
            break
        }
    }
}

private struct InlineActionEditor: View {
    let actionId: UUID
    let sourceText: String
    let font: Font
    let textColor: Color
    let strike: Bool
    @Binding var focusedActionID: UUID?
    let onCommit: (String) -> Void

    @State private var text: String
    @FocusState private var isFocused: Bool

    init(
        actionId: UUID,
        sourceText: String,
        font: Font,
        textColor: Color,
        strike: Bool,
        focusedActionID: Binding<UUID?>,
        onCommit: @escaping (String) -> Void
    ) {
        self.actionId = actionId
        self.sourceText = sourceText
        self.font = font
        self.textColor = textColor
        self.strike = strike
        self._focusedActionID = focusedActionID
        self.onCommit = onCommit
        _text = State(initialValue: sourceText)
    }

    var body: some View {
        Group {
            if focusedActionID == actionId || isFocused {
                TextField("Action", text: $text, axis: .vertical)
                    .font(font)
                    .foregroundStyle(textColor)
                    .strikethrough(strike, color: textColor)
                    .lineLimit(3)
                    .focused($isFocused)
                    .submitLabel(.done)
                    .onSubmit { onCommit(text) }
            } else {
                Text(text)
                    .font(font)
                    .foregroundStyle(textColor)
                    .strikethrough(strike, color: textColor)
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        focusedActionID = actionId
                        DispatchQueue.main.async {
                            isFocused = true
                        }
                    }
            }
        }
        .onChange(of: sourceText) { _, newValue in
            if newValue != text { text = newValue }
        }
        .onChange(of: focusedActionID) { _, newValue in
            isFocused = (newValue == actionId)
        }
        .onChange(of: isFocused) { _, nowFocused in
            if nowFocused {
                if focusedActionID != actionId { focusedActionID = actionId }
            } else {
                onCommit(text)
                if focusedActionID == actionId { focusedActionID = nil }
            }
        }
        .onAppear {
            if focusedActionID == actionId {
                DispatchQueue.main.async { isFocused = true }
            }
        }
        .onDisappear {
            onCommit(text)
        }
    }
}

private struct ActionSwipeRow: View {
    let actionId: UUID
    let text: String
    let dueStatusText: String?
    let dueStatusColor: Color
    let status: ActionExecutionStatus
    let accent: Color
    let colorScheme: ColorScheme
    let isMust: Bool
    let minutes: Int?
    let hasLeverage: Bool
    let leverageIconName: String
    let hasSensitivity: Bool
    let hasAttachments: Bool
    let highlightStatusBox: Bool
    let showsReorderHandle: Bool
    @Binding var focusedActionID: UUID?
    let onCommitText: (String) -> Void
    let onOpenStatus: () -> Void
    let onToggleMust: (Bool) -> Void
    let onOpenClock: () -> Void
    let onOpenLeverage: () -> Void
    let onOpenSensitivity: () -> Void
    let onOpenAttachments: () -> Void

    @State private var localIsMust: Bool

    init(
        actionId: UUID,
        text: String,
        dueStatusText: String?,
        dueStatusColor: Color,
        status: ActionExecutionStatus,
        accent: Color,
        colorScheme: ColorScheme,
        isMust: Bool,
        minutes: Int?,
        hasLeverage: Bool,
        leverageIconName: String,
        hasSensitivity: Bool,
        hasAttachments: Bool,
        highlightStatusBox: Bool,
        showsReorderHandle: Bool,
        focusedActionID: Binding<UUID?>,
        onCommitText: @escaping (String) -> Void,
        onOpenStatus: @escaping () -> Void,
        onToggleMust: @escaping (Bool) -> Void,
        onOpenClock: @escaping () -> Void,
        onOpenLeverage: @escaping () -> Void,
        onOpenSensitivity: @escaping () -> Void,
        onOpenAttachments: @escaping () -> Void
    ) {
        self.actionId = actionId
        self.text = text
        self.dueStatusText = dueStatusText
        self.dueStatusColor = dueStatusColor
        self.status = status
        self.accent = accent
        self.colorScheme = colorScheme
        self.isMust = isMust
        self.minutes = minutes
        self.hasLeverage = hasLeverage
        self.leverageIconName = leverageIconName
        self.hasSensitivity = hasSensitivity
        self.hasAttachments = hasAttachments
        self.highlightStatusBox = highlightStatusBox
        self.showsReorderHandle = showsReorderHandle
        self._focusedActionID = focusedActionID
        self.onCommitText = onCommitText
        self.onOpenStatus = onOpenStatus
        self.onToggleMust = onToggleMust
        self.onOpenClock = onOpenClock
        self.onOpenLeverage = onOpenLeverage
        self.onOpenSensitivity = onOpenSensitivity
        self.onOpenAttachments = onOpenAttachments
        _localIsMust = State(initialValue: isMust)
    }

    private var rowAccent: Color {
        minutes == nil ? Color(.systemGray) : accent
    }

    private var isSwipeInteracting: Bool { false }

    private var effectiveStatus: ActionExecutionStatus {
        status
    }

    private var effectiveIsMust: Bool {
        localIsMust
    }

    private var isInactive: Bool {
        effectiveStatus == .done || effectiveStatus == .carriedToCapture || effectiveStatus == .notNeeded
    }

    private var inactiveTint: Color {
        switch effectiveStatus {
        case .leveraged:
            return Color.primary.opacity(0.45)
        case .done, .carriedToCapture, .notNeeded:
            return Color.primary.opacity(0.25)
        case .inProgress:
            return rowAccent
        case .noAction:
            return colorScheme == .dark ? Color.white.opacity(0.85) : .black
        }
    }

    private var iconTint: Color {
        isInactive ? inactiveTint : accent
    }

    private var statusMarkerIconName: String {
        if effectiveStatus == .leveraged, hasLeverage {
            if leverageIconName == "person.fill" { return "person" }
            if leverageIconName == "wrench.and.screwdriver.fill" { return "wrench.and.screwdriver" }
            return leverageIconName
        }
        return effectiveStatus.icon
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                guard !isSwipeInteracting else { return }
                onOpenStatus()
            } label: {
                Group {
                    if statusMarkerIconName.isEmpty {
                        Color.clear.frame(width: 14, height: 14)
                    } else {
                        Image(systemName: statusMarkerIconName)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(.gray)
                    }
                }
                .frame(width: 30, height: 30)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(highlightStatusBox ? Color.red.opacity(0.25) : Color(.tertiarySystemFill))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(highlightStatusBox ? Color.red : Color.clear, lineWidth: 2)
                )
            }
            .buttonStyle(.plain)

            VStack(alignment: .leading, spacing: 8) {
                if let dueStatusText {
                    Text(dueStatusText)
                        .font(.caption)
                        .foregroundStyle(dueStatusColor)
                }
                InlineActionEditor(
                    actionId: actionId,
                    sourceText: text,
                    font: actionFont(status: effectiveStatus),
                    textColor: inactiveTint,
                    strike: effectiveStatus == .done || effectiveStatus == .carriedToCapture || effectiveStatus == .notNeeded,
                    focusedActionID: $focusedActionID,
                    onCommit: onCommitText
                )

                HStack(spacing: 18) {
                    iconButton(
                        systemName: effectiveIsMust ? "star.square.fill" : "star.square",
                        isOn: effectiveIsMust,
                        tint: iconTint,
                        isEnabled: !isInactive,
                        onTap: {
                            let next = !effectiveIsMust
                            localIsMust = next
                            onToggleMust(next)
                        }
                    )

                    clockButton(
                        minutes: minutes,
                        tint: isInactive ? inactiveTint : rowAccent,
                        isEnabled: !isInactive,
                        onTap: onOpenClock
                    )

                    iconButton(
                        systemName: leverageIconName,
                        isOn: hasLeverage,
                        tint: iconTint,
                        isEnabled: !isInactive,
                        onTap: onOpenLeverage
                    )

                    iconButton(
                        systemName: hasSensitivity ? "gearshape.fill" : "gearshape",
                        isOn: hasSensitivity,
                        tint: iconTint,
                        isEnabled: !isInactive,
                        onTap: onOpenSensitivity
                    )

                    iconButton(
                        systemName: hasAttachments ? "paperclip.badge.ellipsis" : "paperclip",
                        isOn: hasAttachments,
                        tint: iconTint,
                        isEnabled: !isInactive,
                        onTap: onOpenAttachments
                    )
                }
                .font(.system(size: 19, weight: .semibold))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsReorderHandle {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 22, alignment: .center)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(effectiveStatus == .inProgress ? rowAccent : Color.black.opacity(0.12), lineWidth: effectiveStatus == .inProgress ? 3 : 1)
        )
        .contentShape(Rectangle())
        .onChange(of: isMust) { _, newValue in
            localIsMust = newValue
        }
    }

    private func actionFont(status: ActionExecutionStatus) -> Font {
        switch status {
        case .leveraged:
            return .subheadline.italic()
        case .inProgress:
            return .subheadline.weight(.bold)
        default:
            return .subheadline
        }
    }

    private func iconButton(
        systemName: String,
        isOn: Bool,
        tint: Color,
        isEnabled: Bool = true,
        onTap: @escaping () -> Void
    ) -> some View {
        Button {
            guard !isSwipeInteracting else { return }
            onTap()
        } label: {
            Image(systemName: systemName)
                .foregroundStyle(isEnabled ? (isOn ? tint : Color(.systemGray)) : tint)
                .frame(width: 26, height: 26)
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private func clockButton(minutes: Int?, tint: Color, isEnabled: Bool = true, onTap: @escaping () -> Void) -> some View {
        Button {
            guard !isSwipeInteracting else { return }
            onTap()
        } label: {
            HStack(spacing: 6) {
                Image(systemName: minutes == nil ? "clock" : "clock.fill")
                    .foregroundStyle(isEnabled ? (minutes == nil ? Color(.systemGray) : tint) : tint)
                    .frame(width: 26, height: 26)
                if let minutes {
                    Text("\(minutes)m")
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(tint)
                }
            }
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }
}

private struct RearrangeActionsSheet: View {
    struct Item: Identifiable, Hashable {
        let id: UUID
        var text: String
    }

    let items: [Item]
    let onSave: ([UUID]) -> Void

    @State private var localItems: [Item]
    @State private var originalIDs: [UUID]
    @State private var editMode: EditMode = .active

    init(items: [Item], onSave: @escaping ([UUID]) -> Void) {
        self.items = items
        self.onSave = onSave
        _localItems = State(initialValue: items)
        _originalIDs = State(initialValue: items.map(\.id))
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(localItems) { item in
                    Text(item.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "Untitled Action" : item.text)
                        .foregroundStyle(.primary)
                }
                .onMove(perform: move)
            }
            .navigationTitle("Rearrange Actions")
            .navigationBarTitleDisplayMode(.inline)
            .environment(\.editMode, $editMode)
            .onDisappear {
                let updated = localItems.map(\.id)
                guard updated != originalIDs else { return }
                onSave(updated)
            }
        }
    }

    private func move(from source: IndexSet, to destination: Int) {
        localItems.move(fromOffsets: source, toOffset: destination)
    }
}

private struct ActionStatusPickerSheet: View {
    let current: ActionExecutionStatus
    let includeLeveragedOption: Bool
    let leveragedIconName: String
    let onSelect: (ActionExecutionStatus) -> Void

    @Environment(\.dismiss) private var dismiss

    private var options: [ActionExecutionStatus] {
        if includeLeveragedOption {
            return [.noAction, .leveraged, .inProgress, .done, .carriedToCapture, .notNeeded]
        }
        return [.noAction, .inProgress, .done, .carriedToCapture, .notNeeded]
    }

    private func iconName(for status: ActionExecutionStatus) -> String {
        if status == .leveraged {
            return leveragedIconName
        }
        return status.icon
    }

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.self) { status in
                    Button {
                        onSelect(status)
                        dismiss()
                    } label: {
                        HStack(spacing: 10) {
                            Group {
                                let iconName = iconName(for: status)
                                if iconName.isEmpty {
                                    Color.clear.frame(width: 18, height: 18)
                                } else {
                                    Image(systemName: iconName)
                                        .frame(width: 18)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text(status.title)
                            Spacer()
                            if status == current {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(Color.accentColor)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .navigationTitle("Action Status")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

private struct AnimatedChunkDropDelegate: DropDelegate {
    let targetChunkID: UUID
    @Binding var localChunkOrderIDs: [UUID]
    @Binding var draggedChunkID: UUID?
    let onCommit: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard let draggedChunkID, draggedChunkID != targetChunkID else { return }
        guard
            let fromIndex = localChunkOrderIDs.firstIndex(of: draggedChunkID),
            let toIndex = localChunkOrderIDs.firstIndex(of: targetChunkID)
        else { return }
        guard fromIndex != toIndex else { return }

        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12)) {
            let moved = localChunkOrderIDs.remove(at: fromIndex)
            localChunkOrderIDs.insert(moved, at: toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        draggedChunkID = nil
        onCommit(localChunkOrderIDs)
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        DropProposal(operation: .move)
    }

    func dropExited(info: DropInfo) {}
}

private struct ResetChunkDragStateDropDelegate: DropDelegate {
    @Binding var draggedChunkID: UUID?
    @Binding var localChunkOrderIDs: [UUID]
    let onCommit: ([UUID]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        draggedChunkID = nil
        onCommit(localChunkOrderIDs)
        return true
    }

    func dropExited(info: DropInfo) {
        draggedChunkID = nil
    }
}

private struct AnimatedActionRowDropDelegate: DropDelegate {
    let targetID: UUID
    @Binding var draggedID: UUID?
    @Binding var draggedChunkID: UUID?
    @Binding var localActionOrderIDs: [UUID]
    let enabled: Bool
    let onCommit: ([UUID]) -> Void

    func dropEntered(info: DropInfo) {
        guard enabled else { return }
        guard let draggedID, draggedID != targetID else { return }
        guard
            let fromIndex = localActionOrderIDs.firstIndex(of: draggedID),
            let toIndex = localActionOrderIDs.firstIndex(of: targetID)
        else { return }
        guard fromIndex != toIndex else { return }
        withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.88, blendDuration: 0.12)) {
            let moved = localActionOrderIDs.remove(at: fromIndex)
            localActionOrderIDs.insert(moved, at: toIndex)
        }
    }

    func performDrop(info: DropInfo) -> Bool {
        if enabled, !localActionOrderIDs.isEmpty {
            onCommit(localActionOrderIDs)
        }
        draggedID = nil
        draggedChunkID = nil
        localActionOrderIDs = []
        return true
    }

    func dropUpdated(info: DropInfo) -> DropProposal? {
        enabled ? DropProposal(operation: .move) : DropProposal(operation: .cancel)
    }

    func dropExited(info: DropInfo) { }
}

private struct ResetActionRowDragStateDropDelegate: DropDelegate {
    let ownerChunkID: UUID
    @Binding var draggedID: UUID?
    @Binding var draggedChunkID: UUID?
    @Binding var localActionOrderIDs: [UUID]
    let onCommit: ([UUID]) -> Void

    func performDrop(info: DropInfo) -> Bool {
        if draggedChunkID == ownerChunkID, !localActionOrderIDs.isEmpty {
            onCommit(localActionOrderIDs)
        }
        draggedID = nil
        draggedChunkID = nil
        localActionOrderIDs = []
        return true
    }

    func dropExited(info: DropInfo) {
        draggedID = nil
        draggedChunkID = nil
        localActionOrderIDs = []
    }
}

private extension ActionExecutionStatus {
    var icon: String {
        switch self {
        case .noAction:
            return ""
        case .leveraged:
            return "circle"
        case .inProgress:
            return "progress.indicator"
        case .done:
            return "xmark"
        case .carriedToCapture:
            return "arrow.right"
        case .notNeeded:
            return "square"
        }
    }

    var title: String {
        switch self {
        case .noAction:
            return "No action"
        case .leveraged:
            return "Leveraged"
        case .inProgress:
            return "In progress"
        case .done:
            return "Done"
        case .carriedToCapture:
            return "Carried to new capture list"
        case .notNeeded:
            return "Didn't need to be done to acheive outcome (Delete)"
        }
    }
}

#Preview {
    NavigationStack { ActionView() }
}
