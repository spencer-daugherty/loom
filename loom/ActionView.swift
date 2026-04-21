import SwiftUI
import SwiftData
import UniformTypeIdentifiers
import LinkPresentation
import CoreImage
import os
#if canImport(PhotosUI)
import PhotosUI
#endif
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

private struct ActionDuePresentation {
    let text: String?
    let color: Color
    let hasDueDate: Bool
}

private struct ActionFilterContext {
    let fullyFilteredActions: [PlannedChunkAction]
    let contextualPlaceItems: [SensitivityPlaceCatalogItem]
    let contextualPersonResources: [LeverageResource]
    let contextualToolResources: [LeverageResource]
    let contextualTimeOfDayOptions: [TimeOfDayChoice]
    let contextualDurations: [Int]
    let contextualAttachmentKinds: [ActionAttachmentFilterKind]
    let orderedVisibleFilterChips: [FilterChipKind]
    let hasPlaceFilterButton: Bool
    let hasPersonFilterButton: Bool
    let hasToolFilterButton: Bool
    let hasTimeOfDayFilterButton: Bool
    let hasDurationFilterButton: Bool
    let hasAttachmentsFilterButton: Bool
}

private struct ActionAttachmentPresence {
    let hasNote: Bool
    let hasLink: Bool
    let hasFile: Bool
}

private func actionAttachmentRelativePath(for fileName: String) -> String {
    "ActionAttachmentFiles/\(fileName)"
}

private struct ActionRowRenderContext: Identifiable {
    let action: PlannedChunkAction
    let defineState: PlannedChunkActionDefineState?
    let status: ActionExecutionStatus
    let duePresentation: ActionDuePresentation?
    let hasLeverage: Bool
    let leverageIconName: String
    let hasSensitivity: Bool
    let hasAttachments: Bool
    let highlightStatusBox: Bool

    var id: UUID { action.id }
}

private struct ActionLookupData {
    let defineByAction: [UUID: PlannedChunkActionDefineState]
    let executionByAction: [UUID: PlannedChunkActionExecutionState]
    let notesByAction: [UUID: PlannedChunkActionNote]
    let attachmentsByAction: [UUID: [PlannedChunkActionAttachment]]
    let resourcesByAction: [UUID: UUID]
    let placesByAction: [UUID: Set<UUID>]
    let resourcesCatalogByID: [UUID: LeverageResource]
}

private final class ActionViewRuntimeState {
    var lastScrollY: CGFloat = 0
    var lastScrollTimestamp: TimeInterval = Date().timeIntervalSinceReferenceDate
    var autosaveTask: Task<Void, Never>? = nil
}

private struct ActionChromeMaterialLayer<S: Shape>: View {
    let shape: S
    var shadowRadius: CGFloat = 0
    var shadowY: CGFloat = 0
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        shape
            .fill(.ultraThinMaterial)
            .overlay {
                LinearGradient(
                    colors: [
                        Color.white.opacity(colorScheme == .dark ? 0.10 : 0.16),
                        Color.clear,
                        Color.black.opacity(colorScheme == .dark ? 0.10 : 0.06)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .clipShape(shape)
                .allowsHitTesting(false)
            }
            .shadow(
                color: Color.black.opacity(shadowRadius > 0 ? (colorScheme == .dark ? 0.22 : 0.10) : 0),
                radius: shadowRadius,
                x: 0,
                y: shadowY
            )
    }
}

struct ActionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

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
    @State private var actionBlocksSimpleViewEnabled: Bool = false
    @State private var isSearchPresented: Bool = false
    @State private var actionSearchText: String = ""

    private var developerWarningCardsEnabled: Bool {
        LoomDeveloperBuild.enabled(devManualWarningCardsEnabled)
    }

    private var developerOldActionBlocksWarningEnabled: Bool {
        LoomDeveloperBuild.enabled(devActionBlocksWarningOldBlocks)
    }

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
    @State private var runtimeState = ActionViewRuntimeState()
    @State private var isHeaderCollapsed: Bool = false
    @State private var dismissActionBlocksCautionCard: Bool = false
    @State private var isKeyboardVisible: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var focusedActionID: UUID? = nil
    @State private var liveActionDraftByID: [UUID: String] = [:]
    @State private var scrollTargetActionID: UUID? = nil
    @State private var pendingChunkScrollAnchor: String? = nil
    @State private var pendingExpandChunkTopAnchor: String? = nil
    @State private var pendingFocusActionID: UUID? = nil
    @State private var pendingNewActionIDs: Set<UUID> = []
    @State private var pendingDurationDefaultActionID: UUID? = nil
    @State private var addActionChunkID: ChunkActionAddSheetID? = nil
    @State private var rearrangeActionsSheetPayload: RearrangeActionsSheetPayload? = nil
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
    @State private var pendingStatusOverridesByActionID: [UUID: ActionExecutionStatus] = [:]
    @State private var carriedProfileAppliedActionIDs: Set<UUID> = []
    @State private var dueSnapshotsCache: [String: PlannedActionDueSnapshot] = [:]
    @FocusState private var isSearchFieldFocused: Bool
    @FocusState private var isActionEditorFocused: Bool
    private let weekStart: Date
    private static let signposter = OSSignposter(subsystem: "loom", category: "ActionView")

    init() {
        let ws = ActivePlanSessionStore.weekStart() ?? WeeklyMindsetEntry.weekStart(for: Date())
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

    private var weekActionsByID: [UUID: PlannedChunkAction] {
        Dictionary(uniqueKeysWithValues: weekActions.map { ($0.id, $0) })
    }

    private var weekActionsByChunkID: [UUID: [PlannedChunkAction]] {
        Dictionary(grouping: weekActions, by: \.plannedChunkId)
    }

    private func orderedWeekChunksForDisplay(
        executionByAction: [UUID: PlannedChunkActionExecutionState]
    ) -> [PlannedChunk] {
        let activeActionIDs = Set(
            weekActions.compactMap { action in
                let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
                return isActiveStatus(status) ? action.id : nil
            }
        )
        let activeChunkIDs = Set(weekActions.compactMap { activeActionIDs.contains($0.id) ? $0.plannedChunkId : nil })
        let sortedByIndex = weekChunks.sorted { $0.chunkIndex < $1.chunkIndex }
        let chunkOrderSet = Set(localChunkOrderIDs)
        let baseOrder: [PlannedChunk] = {
            guard !localChunkOrderIDs.isEmpty else { return sortedByIndex }
            let byID = Dictionary(uniqueKeysWithValues: sortedByIndex.map { ($0.id, $0) })
            let ordered = localChunkOrderIDs.compactMap { byID[$0] }
            if ordered.count == sortedByIndex.count { return ordered }
            let missing = sortedByIndex.filter { chunk in
                !chunkOrderSet.contains(chunk.id)
            }
            return ordered + missing
        }()

        let activeBlocks = baseOrder.filter { activeChunkIDs.contains($0.id) }
        let completedBlocks = baseOrder.filter { !activeChunkIDs.contains($0.id) }
        return activeBlocks + completedBlocks
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

    private func effectiveExecutionStatus(
        for actionId: UUID,
        persisted executionByAction: [UUID: PlannedChunkActionExecutionState]
    ) -> ActionExecutionStatus {
        pendingStatusOverridesByActionID[actionId] ?? executionByAction[actionId]?.status ?? .noAction
    }

    private func effectiveExecutionStatus(for actionId: UUID) -> ActionExecutionStatus {
        effectiveExecutionStatus(for: actionId, persisted: executionStateByActionID)
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

    private var placesCatalogByID: [UUID: SensitivityPlaceCatalogItem] {
        Dictionary(uniqueKeysWithValues: placesCatalog.map { ($0.id, $0) })
    }

    private var availableDurations: [Int] {
        let defineByAction = defineStateByActionID
        let mins = Set(weekActions.compactMap { defineByAction[$0.id]?.timeEstimateMinutes })
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
        let executionByAction = executionStateByActionID
        return weekActions.filter { effectiveExecutionStatus(for: $0.id, persisted: executionByAction) == .inProgress }.count
    }

    private var blocksAgeDays: Int? {
        guard let earliest = weekActions.map(\.createdAt).min() else { return nil }
        let start = Calendar.current.startOfDay(for: earliest)
        let now = Calendar.current.startOfDay(for: Date())
        return max(0, Calendar.current.dateComponents([.day], from: start, to: now).day ?? 0)
    }
    private var canCompleteActions: Bool {
        guard !weekActions.isEmpty else { return false }
        let executionByAction = executionStateByActionID
        return weekActions.allSatisfy { action in
            let s = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
            return s == .done || s == .carriedToCapture || s == .notNeeded
        }
    }

    private var hasUncompletedActions: Bool {
        let executionByAction = executionStateByActionID
        return weekActions.contains { action in
            let s = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
            return s == .noAction || s == .leveraged || s == .inProgress
        }
    }
    private enum FilterFacet: Hashable {
        case place, person, tool, timeOfDay, musts, duration, attachments
        case activeOnly, leveragedOnly, inProgressOnly
    }

    private func signposted<T>(_ name: StaticString, _ work: () -> T) -> T {
        let state = Self.signposter.beginInterval(name)
        let result = work()
        Self.signposter.endInterval(name, state)
        return result
    }

    private func withBodySignpost<Content: View>(
        @ViewBuilder _ content: () -> Content
    ) -> some View {
        let state = Self.signposter.beginInterval("body_eval")
        let view = content()
        Self.signposter.endInterval("body_eval", state)
        return view
    }

    private func buildFilterContext(
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        resourcesByAction: [UUID: UUID],
        placesByAction: [UUID: Set<UUID>],
        attachmentPresenceByActionID: [UUID: ActionAttachmentPresence],
        resourceCatalogByID: [UUID: LeverageResource]
    ) -> ActionFilterContext {
        var visibilityCache: [Set<FilterFacet>: [PlannedChunkAction]] = [:]
        func filtered(excluding excluded: Set<FilterFacet>) -> [PlannedChunkAction] {
            if let cached = visibilityCache[excluded] { return cached }
            let rows = weekActions.filter {
                actionMatchesFilters(
                    $0,
                    defineByAction: defineByAction,
                    executionByAction: executionByAction,
                    resourcesByAction: resourcesByAction,
                    placesByAction: placesByAction,
                    attachmentPresenceByActionID: attachmentPresenceByActionID,
                    resourceCatalogByID: resourceCatalogByID,
                    excludedFacets: excluded
                )
            }
            visibilityCache[excluded] = rows
            return rows
        }

        let placeBase = filtered(excluding: [.place])
        let placeIDs = Set(placeBase.flatMap { Array(placesByAction[$0.id] ?? []) }).union(selectedPlaceIDs)
        let contextualPlaceItems = placesCatalog
            .filter { placeIDs.contains($0.id) }
            .sorted { $0.place.localizedCaseInsensitiveCompare($1.place) == .orderedAscending }

        let personBase = filtered(excluding: [.person])
        let personIDs = Set(personBase.compactMap { resourcesByAction[$0.id] }).union(selectedPersonIDs)
        let contextualPersonResources = leverageCatalog
            .filter { $0.kind == .person && personIDs.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }

        let toolBase = filtered(excluding: [.tool])
        let toolIDs = Set(toolBase.compactMap { resourcesByAction[$0.id] }).union(selectedToolIDs)
        let contextualToolResources = leverageCatalog
            .filter { $0.kind == .tool && toolIDs.contains($0.id) }
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }

        let timeBase = filtered(excluding: [.timeOfDay])
        var timeOptions = Set<TimeOfDayChoice>()
        for action in timeBase {
            let st = defineByAction[action.id]
            let hasMorning = st?.sensitiveMorning ?? true
            let hasAfternoon = st?.sensitiveAfternoon ?? true
            let hasEvening = st?.sensitiveEvening ?? true
            let isAnytime = hasMorning && hasAfternoon && hasEvening
            if isAnytime {
                timeOptions.insert(.any)
            } else {
                if hasMorning { timeOptions.insert(.morning) }
                if hasAfternoon { timeOptions.insert(.afternoon) }
                if hasEvening { timeOptions.insert(.evening) }
            }
        }
        timeOptions.formUnion(selectedTimeOfDay)
        let contextualTimeOfDayOptions = TimeOfDayChoice.allCases.filter { timeOptions.contains($0) }

        let durationBase = filtered(excluding: [.duration])
        var durationValues = Set(durationBase.compactMap { defineByAction[$0.id]?.timeEstimateMinutes })
        durationValues.formUnion(selectedDurations)
        let contextualDurations = durationValues.sorted()

        let attachmentBase = filtered(excluding: [.attachments])
        var attachmentKinds = Set<ActionAttachmentFilterKind>()
        for action in attachmentBase {
            let presence = attachmentPresenceByActionID[action.id]
            if presence?.hasNote == true { attachmentKinds.insert(.note) }
            if presence?.hasLink == true { attachmentKinds.insert(.link) }
            if presence?.hasFile == true { attachmentKinds.insert(.file) }
        }
        attachmentKinds.formUnion(selectedAttachmentKinds)
        let contextualAttachmentKinds = ActionAttachmentFilterKind.allCases.filter { attachmentKinds.contains($0) }

        let inactiveOnlyCandidateCount = filtered(excluding: [.activeOnly]).filter {
            isInactiveStatus(effectiveExecutionStatus(for: $0.id, persisted: executionByAction))
        }.count
        let leveragedOnlyCandidateCount = filtered(excluding: [.leveragedOnly]).filter {
            effectiveExecutionStatus(for: $0.id, persisted: executionByAction) == .leveraged
        }.count
        let inProgressOnlyCandidateCount = filtered(excluding: [.inProgressOnly]).filter {
            effectiveExecutionStatus(for: $0.id, persisted: executionByAction) == .inProgress
        }.count
        let mustsOnlyCandidateCount = filtered(excluding: [.musts]).filter {
            isMust(for: $0.id, defineByAction: defineByAction)
        }.count

        let hasPlaceFilterButton = !selectedPlaceIDs.isEmpty || contextualPlaceItems.contains { !selectedPlaceIDs.contains($0.id) }
        let hasPersonFilterButton = !selectedPersonIDs.isEmpty || contextualPersonResources.contains { !selectedPersonIDs.contains($0.id) }
        let hasToolFilterButton = !selectedToolIDs.isEmpty || contextualToolResources.contains { !selectedToolIDs.contains($0.id) }
        let hasOnlyAnytimeOption = !contextualTimeOfDayOptions.isEmpty && contextualTimeOfDayOptions.allSatisfy { $0 == .any }
        let hasTimeOfDayFilterButton: Bool
        if hasOnlyAnytimeOption && selectedTimeOfDay.isEmpty {
            hasTimeOfDayFilterButton = false
        } else {
            hasTimeOfDayFilterButton = !selectedTimeOfDay.isEmpty || contextualTimeOfDayOptions.contains { !selectedTimeOfDay.contains($0) }
        }
        let hasDurationFilterButton = !selectedDurations.isEmpty || contextualDurations.contains { !selectedDurations.contains($0) }
        let hasAttachmentsFilterButton = !selectedAttachmentKinds.isEmpty || contextualAttachmentKinds.contains { !selectedAttachmentKinds.contains($0) }
        let showInactiveOnlyFilterButton = inactiveOnly || inactiveOnlyCandidateCount > 0
        let showLeveragedOnlyFilterButton = leveragedOnly || leveragedOnlyCandidateCount > 0
        let showInProgressOnlyFilterButton = inProgressOnly || inProgressOnlyCandidateCount > 0
        let hasMustsFilterButton = onlyMusts || mustsOnlyCandidateCount > 0

        func isVisible(_ chip: FilterChipKind) -> Bool {
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

        let visible = defaultFilterChipOrder.filter { isVisible($0) || isFilterChipSelected($0) }
        let selected = visible.filter { isFilterChipSelected($0) }
        let nonSelected = visible.filter { !isFilterChipSelected($0) }
        let fullyFilteredActions = filtered(excluding: [])

        return ActionFilterContext(
            fullyFilteredActions: fullyFilteredActions,
            contextualPlaceItems: contextualPlaceItems,
            contextualPersonResources: contextualPersonResources,
            contextualToolResources: contextualToolResources,
            contextualTimeOfDayOptions: contextualTimeOfDayOptions,
            contextualDurations: contextualDurations,
            contextualAttachmentKinds: contextualAttachmentKinds,
            orderedVisibleFilterChips: selected + nonSelected,
            hasPlaceFilterButton: hasPlaceFilterButton,
            hasPersonFilterButton: hasPersonFilterButton,
            hasToolFilterButton: hasToolFilterButton,
            hasTimeOfDayFilterButton: hasTimeOfDayFilterButton,
            hasDurationFilterButton: hasDurationFilterButton,
            hasAttachmentsFilterButton: hasAttachmentsFilterButton
        )
    }

    private func buildActionLookupData() -> ActionLookupData {
        let actionIDs = Set(weekActions.map(\.id))

        let meaningfulDefineState: (PlannedChunkActionDefineState) -> Bool = { row in
            row.isMust ||
            row.timeEstimateMinutes != nil ||
            !(row.sensitiveMorning && row.sensitiveAfternoon && row.sensitiveEvening)
        }

        var defineByAction: [UUID: PlannedChunkActionDefineState] = [:]
        for row in defineStates where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            guard let existing = defineByAction[key] else {
                defineByAction[key] = row
                continue
            }
            let rowMeaningful = meaningfulDefineState(row)
            let existingMeaningful = meaningfulDefineState(existing)
            if rowMeaningful && !existingMeaningful {
                defineByAction[key] = row
            } else if rowMeaningful == existingMeaningful && row.updatedAt > existing.updatedAt {
                defineByAction[key] = row
            }
        }

        var executionByAction: [UUID: PlannedChunkActionExecutionState] = [:]
        for row in executionStates where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            if let existing = executionByAction[key] {
                if row.updatedAt > existing.updatedAt { executionByAction[key] = row }
            } else {
                executionByAction[key] = row
            }
        }

        var notesByAction: [UUID: PlannedChunkActionNote] = [:]
        for row in notes where actionIDs.contains(row.plannedChunkActionId) {
            let key = row.plannedChunkActionId
            let rowMeaningful = !row.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            guard let existing = notesByAction[key] else {
                notesByAction[key] = row
                continue
            }
            let existingMeaningful = !existing.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            if rowMeaningful && !existingMeaningful {
                notesByAction[key] = row
            } else if rowMeaningful == existingMeaningful && row.updatedAt > existing.updatedAt {
                notesByAction[key] = row
            }
        }

        let attachmentsByAction = Dictionary(
            grouping: attachments.filter { actionIDs.contains($0.plannedChunkActionId) },
            by: \.plannedChunkActionId
        )

        var resourcesByAction: [UUID: UUID] = [:]
        var seenUpdatedAtByActionID: [UUID: Date] = [:]
        for selection in leverageSelections where actionIDs.contains(selection.plannedChunkActionId) {
            guard let resourceID = selection.resourceId else { continue }
            let key = selection.plannedChunkActionId
            if let existingUpdatedAt = seenUpdatedAtByActionID[key] {
                if selection.updatedAt > existingUpdatedAt {
                    seenUpdatedAtByActionID[key] = selection.updatedAt
                    resourcesByAction[key] = resourceID
                }
            } else {
                seenUpdatedAtByActionID[key] = selection.updatedAt
                resourcesByAction[key] = resourceID
            }
        }

        let placesByAction = Dictionary(
            grouping: placeLinks.filter { actionIDs.contains($0.plannedChunkActionId) },
            by: \.plannedChunkActionId
        ).mapValues { Set($0.map(\.placeId)) }

        let resourcesCatalogByID = Dictionary(uniqueKeysWithValues: leverageCatalog.map { ($0.id, $0) })

        return ActionLookupData(
            defineByAction: defineByAction,
            executionByAction: executionByAction,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            resourcesByAction: resourcesByAction,
            placesByAction: placesByAction,
            resourcesCatalogByID: resourcesCatalogByID
        )
    }

    private func buildAttachmentPresenceByActionID(
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]]
    ) -> [UUID: ActionAttachmentPresence] {
        var result: [UUID: ActionAttachmentPresence] = [:]
        result.reserveCapacity(weekActions.count)
        for action in weekActions {
            let noteText = notesByAction[action.id]?.noteText ?? ""
            let hasNote = !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let actionAttachments = attachmentsByAction[action.id] ?? []
            let hasLink = actionAttachments.contains { $0.kind == .link }
            let hasFile = actionAttachments.contains { $0.kind == .file }
            result[action.id] = ActionAttachmentPresence(
                hasNote: hasNote,
                hasLink: hasLink,
                hasFile: hasFile
            )
        }
        return result
    }

    private struct RenderState {
        let defineByAction: [UUID: PlannedChunkActionDefineState]
        let executionByAction: [UUID: PlannedChunkActionExecutionState]
        let notesByAction: [UUID: PlannedChunkActionNote]
        let attachmentsByAction: [UUID: [PlannedChunkActionAttachment]]
        let resourcesByAction: [UUID: UUID]
        let placesByAction: [UUID: Set<UUID>]
        let duePresentationByActionID: [UUID: ActionDuePresentation]
        let resourcesCatalogByID: [UUID: LeverageResource]
        let allByChunk: [UUID: [PlannedChunkAction]]
        let filterContext: ActionFilterContext
        let rolesByID: [UUID: String]
        let outcomesByID: [UUID: Outcomes]
        let orderedChunksForDisplay: [PlannedChunk]
        let visibleChunksForDisplay: [PlannedChunk]
        let filteredByChunk: [UUID: [PlannedChunkAction]]
    }

    private func buildRenderState() -> RenderState {
        let lookupData = signposted("build_action_lookup_data") { buildActionLookupData() }
        let defineByAction = lookupData.defineByAction
        let executionByAction = lookupData.executionByAction
        let notesByAction = lookupData.notesByAction
        let attachmentsByAction = lookupData.attachmentsByAction
        let attachmentPresenceByActionID = signposted("build_attachment_presence_by_action") {
            buildAttachmentPresenceByActionID(
                notesByAction: notesByAction,
                attachmentsByAction: attachmentsByAction
            )
        }
        let resourcesByAction = lookupData.resourcesByAction
        let placesByAction = lookupData.placesByAction
        let duePresentationByActionID = signposted("build_due_presentation") {
            buildDuePresentationByActionID()
        }
        let resourcesCatalogByID = lookupData.resourcesCatalogByID
        let allByChunk = signposted("compute_actions_by_chunk") { weekActionsByChunkID }
        let filterContext = signposted("build_filter_context") {
            buildFilterContext(
                defineByAction: defineByAction,
                executionByAction: executionByAction,
                resourcesByAction: resourcesByAction,
                placesByAction: placesByAction,
                attachmentPresenceByActionID: attachmentPresenceByActionID,
                resourceCatalogByID: resourcesCatalogByID
            )
        }
        let rolesByID = Dictionary(uniqueKeysWithValues: roles.map { ($0.id, $0.role) })
        let outcomesByID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
        let orderedChunksForDisplay = signposted("compute_ordered_chunks_for_display") {
            orderedWeekChunksForDisplay(executionByAction: executionByAction)
        }
        let searchedActions = searchFilteredActions(
            from: filterContext.fullyFilteredActions,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            resourcesByAction: resourcesByAction,
            resourceCatalogByID: resourcesCatalogByID,
            placesByAction: placesByAction
        )
        let filteredByChunk = signposted("build_filtered_by_chunk") {
            buildFilteredActionsByChunk(
                filteredActions: searchedActions,
                executionByAction: executionByAction
            )
        }
        let visibleChunksForDisplay: [PlannedChunk] = searchQueryTrimmed.isEmpty
            ? orderedChunksForDisplay
            : orderedChunksForDisplay.filter { !(filteredByChunk[$0.id] ?? []).isEmpty }
        let renderState = RenderState(
            defineByAction: defineByAction,
            executionByAction: executionByAction,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            resourcesByAction: resourcesByAction,
            placesByAction: placesByAction,
            duePresentationByActionID: duePresentationByActionID,
            resourcesCatalogByID: resourcesCatalogByID,
            allByChunk: allByChunk,
            filterContext: filterContext,
            rolesByID: rolesByID,
            outcomesByID: outcomesByID,
            orderedChunksForDisplay: orderedChunksForDisplay,
            visibleChunksForDisplay: visibleChunksForDisplay,
            filteredByChunk: filteredByChunk
        )
        return renderState
    }

    var body: some View {
        actionBodyView()
    }

    private func actionBodyView() -> some View {
        let render = buildRenderState()
        let core = actionMainStack(render: render)
        let chrome = actionBodyChrome(core)
        let presented = actionBodyPresentations(chrome)
        return actionBodyObservers(presented)
    }

    private func actionBodyChrome<Content: View>(_ content: Content) -> some View {
        let chromeBase = ZStack(alignment: .bottom) {
            content
                .padding(.horizontal)
                .safeAreaPadding(.top)
                .loomAdaptiveConstrainedFrame(maxWidth: 860, alignment: .topLeading)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .overlay(alignment: .top) {
                    completeHintOverlay
                }

            actionBottomInset
                .frame(maxWidth: .infinity, alignment: .bottom)
        }
        .ignoresSafeArea(edges: .bottom)
        .navigationTitle("Action Plan")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbarBackground(Color.clear, for: .navigationBar)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    dismiss()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                headerTrailingControls
            }

            ToolbarItemGroup(placement: .keyboard) {
                Spacer()
                if isKeyboardVisible && !isSearchPresented {
                    keyboardAccessoryButton
                }
            }
        }
        .coordinateSpace(name: "action-scroll")

        return chromeBase
            .navigationDestination(item: $rearrangeActionsSheetPayload) { sheet in
                RearrangeActionsSheet(
                    items: sheet.items,
                    onSave: { reorderedIDs in
                        commitActionOrder(in: sheet.id, visibleOrderedIDs: reorderedIDs)
                    }
                )
            }
    }

    @ViewBuilder
    private var completeHintOverlay: some View {
        if showCompleteHint {
            VStack(alignment: .leading, spacing: 6) {
                Text("You cannot complete if any actions are active.")
                    .font(.footnote)
                    .fontWeight(.bold)

                (
                    Text("Please mark all of your actions to ")
                    + Text(Image(systemName: "xmark")) + Text(" Done, ")
                    + Text(Image(systemName: "arrow.right")) + Text(" Recapture for later, or ")
                    + Text(Image(systemName: "square")) + Text(" Wasn't needed to acheive result (Delete).")
                )
                .font(.footnote)
                .fixedSize(horizontal: false, vertical: true)
            }
            .multilineTextAlignment(.leading)
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.black.opacity(0.12), lineWidth: 1)
            )
            .padding(.horizontal, 4)
            .padding(.top, 8)
            .transition(.opacity)
        }
    }

    private var headerTrailingControls: some View {
        HStack(spacing: 0) {
            if isSearchPresented {
                Button {
                    actionSearchText = ""
                    isSearchPresented = false
                    isSearchFieldFocused = false
                    dismissKeyboardOnly()
                } label: {
                    Image(systemName: "xmark")
                        .font(.body.weight(.semibold))
                        .offset(x: 0.5)
                        .frame(width: 28, height: 28, alignment: .center)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            } else {
                if !areAllActionBlocksCollapsed {
                    Color.clear
                        .frame(width: 6)

                    Button {
                        actionBlocksSimpleViewEnabled.toggle()
                    } label: {
                        Text(actionBlocksSimpleViewEnabled ? "Full" : "Simple")
                            .font(.footnote.weight(.medium))
                            .frame(height: 28, alignment: .center)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.blue)

                    Divider()
                        .frame(width: 1, height: 18)
                        .padding(.horizontal, 8)
                }

                Button {
                    isSearchPresented = true
                    openFilter = nil
                    DispatchQueue.main.async {
                        isSearchFieldFocused = true
                    }
                } label: {
                    Image(systemName: "magnifyingglass")
                        .font(.body.weight(.semibold))
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .foregroundStyle(.blue)
            }

            Color.clear
                .frame(width: 6)
        }
    }

    private func actionBodyPresentations<Content: View>(_ content: Content) -> some View {
        content
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
                NavigationStack {
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
                            // Moving from Capture into an Action Block is a transfer, not a user delete.
                            modelContext.delete(capture)
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
                        let localPath = actionAttachmentRelativePath(for: fileName)
                        modelContext.insert(PlannedChunkActionAttachment(
                            weekStart: currentWeekStart,
                            plannedChunkActionId: wrapper.id,
                            kindRaw: ActionAttachmentKind.file.rawValue,
                            urlString: localPath,
                            fileName: fileName,
                            fileBookmarkData: bookmarkData,
                            createdAt: .now
                        ))
                        persistNow()
                    },
                    onDeleteAttachment: { attachmentId in
                        if let a = attachmentsByActionID.values.flatMap({ $0 }).first(where: { $0.id == attachmentId }) {
                            RecentlyDeletedStore.trash(a, in: modelContext)
                            persistNow()
                        }
                    }
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
            .sheet(item: $actionStatusActionID) { wrapper in
                let selectedResource = selectedResourceByActionID[wrapper.id].flatMap { resourceByID[$0] }
                let hasAnyPeopleOrTools = leverageCatalog.contains { $0.kind == .person || $0.kind == .tool }
                let leveragedStatusIconName = {
                    guard let selectedResource else { return "circle" }
                    return selectedResource.kind == .tool ? "wrench.and.screwdriver" : "person"
                }()
                ActionStatusPickerSheet(
                    current: status(for: wrapper.id),
                    includeLeveragedOption: hasAnyPeopleOrTools && selectedResource != nil,
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
    }

    private func actionBodyObservers<Content: View>(_ content: Content) -> some View {
        content
            .onAppear {
                actionBlocksSimpleViewEnabled = false
                dismissActionBlocksCautionCard = false
                dueSnapshotsCache = loadActionDueSnapshots(for: currentWeekStart)
                ensureStateRowsExistForWeek()
                applyCarriedProfilesToWeekActionsIfNeeded()
                cleanupAllBlankActions()
                deactivatePlanIfNoActionBlocks()
                syncLocalChunkOrderIfNeeded(force: true)
            }
            .onChange(of: weekChunks.map(\.id)) { _, _ in
                signposted("on_change_week_chunk_ids") {
                    deactivatePlanIfNoActionBlocks()
                    syncLocalChunkOrderIfNeeded(force: false)
                }
            }
            .onChange(of: weekActions.map(\.id)) { _, ids in
                signposted("on_change_week_action_ids") {
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
            }
            .onPreferenceChange(ActionScrollOffsetPreferenceKey.self) { y in
                signposted("on_change_scroll_offset") {
                    handleScrollOffsetChange(y)
                }
            }
            .onDisappear {
                flushPendingWritesAndPersist()
            }
            .onChange(of: scenePhase) { _, newPhase in
                if newPhase == .inactive || newPhase == .background {
                    flushPendingWritesAndPersist()
                }
            }
        #if canImport(UIKit)
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillShowNotification)) { note in
                isKeyboardVisible = true
                if let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect {
                    keyboardHeight = max(0, frame.height - 34)
                }
                if let focusedActionID {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) {
                        scrollTargetActionID = focusedActionID
                    }
                }
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                commitFocusedActionDraftIfNeeded()
                isKeyboardVisible = false
                keyboardHeight = 0
                isActionEditorFocused = false
                focusedActionID = nil
                cleanupPendingBlankActions()
                cleanupAllBlankActions()
            }
        #endif
    }

    private func actionMainStack(render: RenderState) -> some View {
        VStack(spacing: 0) {
            collapsibleHeader(filterContext: render.filterContext)
            actionScrollSection(render: render)
        }
    }

    private func actionScrollSection(render: RenderState) -> some View {
        ScrollViewReader { proxy in
            ScrollView(.vertical, showsIndicators: true) {
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
                        Text("No action plans yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else if !searchQueryTrimmed.isEmpty && render.visibleChunksForDisplay.isEmpty {
                        Text("No matching actions found.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(render.visibleChunksForDisplay) { chunk in
                            chunkCard(
                                chunk,
                                allActions: render.allByChunk[chunk.id] ?? [],
                                filteredActions: render.filteredByChunk[chunk.id] ?? [],
                                defineByAction: render.defineByAction,
                                executionByAction: render.executionByAction,
                                resourcesByAction: render.resourcesByAction,
                                resourceCatalogByID: render.resourcesCatalogByID,
                                placesByAction: render.placesByAction,
                                notesByAction: render.notesByAction,
                                attachmentsByAction: render.attachmentsByAction,
                                duePresentationByActionID: render.duePresentationByActionID,
                                rolesByID: render.rolesByID,
                                outcomesByID: render.outcomesByID
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
                .padding(.bottom, scrollContentBottomPadding)
            }
            .scrollIndicators(.visible)
            .onChange(of: focusedActionID) { _, id in
                signposted("on_change_focused_action_id") {
                    guard let id else {
                        isActionEditorFocused = false
                        return
                    }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: editingActionScrollAnchor)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isActionEditorFocused = true
                        }
                    }
                }
            }
            .onChange(of: scrollTargetActionID) { _, id in
                signposted("on_change_scroll_target_action_id") {
                    guard let id else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: editingActionScrollAnchor)
                        }
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.18) {
                            focusedActionID = id
                            scrollTargetActionID = nil
                        }
                    }
                }
            }
            .onChange(of: pendingChunkScrollAnchor) { _, anchor in
                signposted("on_change_pending_chunk_anchor") {
                    guard let anchor else { return }
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.22)) {
                            proxy.scrollTo(anchor, anchor: .bottom)
                        }
                    }
                }
            }
            .onChange(of: pendingExpandChunkTopAnchor) { _, anchor in
                signposted("on_change_pending_expand_anchor") {
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
            .onChange(of: keyboardHeight) { _, height in
                signposted("on_change_keyboard_height") {
                    guard height > 0, let id = focusedActionID else { return }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo(id, anchor: editingActionScrollAnchor)
                        }
                    }
                }
            }
        }
    }

    private var editingActionScrollAnchor: UnitPoint {
        UnitPoint(x: 0.5, y: 0.82)
    }

    private var scrollContentBottomPadding: CGFloat {
        if isSearchPresented || isEditingActionPresented {
            return 12
        }
        if !isKeyboardVisible {
            return 96 + actionBottomSafeAreaInset
        }
        return 8
    }

    private var isEditingActionPresented: Bool {
        focusedActionID != nil && !isSearchPresented
    }

    private var actionFooterPrimaryControl: some View {
        Group {
            if !isKeyboardVisible && !isSearchPresented {
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
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .tint(canCompleteActions ? .accentColor : Color(.systemGray3))
            }
        }
        .padding(.bottom, 2)
    }

    private var actionBottomInset: some View {
        VStack(spacing: 0) {
            if isEditingActionPresented {
                actionEditorBar
                    .zIndex(1)
            } else if !isKeyboardVisible && !isSearchPresented {
                actionFooterPrimaryControl
                    .padding(.horizontal)
                    .padding(.top, 10)
                    .padding(.bottom, 8)
                    .zIndex(1)
            } else if isSearchPresented {
                searchBar
                    .zIndex(1)
            }
        }
        .padding(.bottom, actionBottomOverlayInset)
        .background(alignment: .bottom) {
            if !isSearchPresented && !isEditingActionPresented {
                actionBottomToolbarBackdrop
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    private var actionBottomToolbarBackdrop: some View {
        ActionChromeMaterialLayer(
            shape: Rectangle(),
            shadowRadius: 12,
            shadowY: -2
        )
        .frame(height: 94 + actionBottomSafeAreaInset)
        .mask(
            LinearGradient(
                stops: [
                    .init(color: .clear, location: 0),
                    .init(color: .black.opacity(0.22), location: 0.58),
                    .init(color: .black, location: 1)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        )
        .ignoresSafeArea(edges: .bottom)
        .allowsHitTesting(false)
    }

    private var actionBottomSafeAreaInset: CGFloat {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first(where: \.isKeyWindow)?
            .safeAreaInsets.bottom ?? 0
    }

    private var actionBottomOverlayInset: CGFloat {
        isKeyboardVisible ? keyboardHeight : actionBottomSafeAreaInset
    }

    private var keyboardAccessoryShowsCheckmark: Bool {
        guard isKeyboardVisible, let focusedActionID else { return false }
        let text = liveActionDraftByID[focusedActionID] ?? weekActionsByID[focusedActionID]?.text ?? ""
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var keyboardAccessoryButton: some View {
        Button {
            if keyboardAccessoryShowsCheckmark {
                dismissKeyboardAndCommit()
            } else {
                dismissKeyboardOnly()
            }
        } label: {
            Image(systemName: keyboardAccessoryShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardAccessoryShowsCheckmark ? Color.white : Color.primary.opacity(0.85))
                .frame(width: 44, height: 44)
                .background(
                    Circle().fill(keyboardAccessoryShowsCheckmark ? Color.blue : Color(.secondarySystemBackground))
                )
                .overlay(
                    Circle()
                        .stroke(
                            keyboardAccessoryShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var searchQueryTrimmed: String {
        actionSearchText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var searchBar: some View {
        HStack(spacing: 10) {
            HStack(spacing: 8) {
                Image(systemName: "magnifyingglass")
                    .foregroundStyle(.secondary)
                TextField("Search actions", text: $actionSearchText)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.search)
                    .focused($isSearchFieldFocused)
                    .onSubmit {
                        dismissKeyboardOnly()
                    }
            }
            .padding(.horizontal, 12)
            .frame(height: 44)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), lineWidth: 1)
            )

            Button {
                actionSearchText = ""
                isSearchPresented = false
                isSearchFieldFocused = false
                dismissKeyboardOnly()
            } label: {
                Image(systemName: "xmark")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(Color.primary.opacity(0.78))
                    .frame(width: 44, height: 44)
                    .background(
                        Circle()
                            .fill(Color(.secondarySystemBackground))
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .padding(.bottom, max(8, keyboardHeight > 0 ? 8 : 12))
    }

    private var actionEditorBar: some View {
        HStack(alignment: .bottom, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                TextField("Edit action", text: focusedActionDraftBinding, axis: .vertical)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.return)
                    .lineLimit(1 ... 6)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .multilineTextAlignment(.leading)
                    .focused($isActionEditorFocused)
                    .onSubmit {
                        dismissKeyboardAndCommit()
                    }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(Color.black.opacity(colorScheme == .dark ? 0.22 : 0.08), lineWidth: 1)
            )

            keyboardAccessoryButton
        }
        .padding(.horizontal)
        .padding(.top, 2)
        .padding(.bottom, max(8, keyboardHeight > 0 ? 8 : 12))
        .onAppear {
            DispatchQueue.main.async {
                isActionEditorFocused = true
            }
        }
    }

    private var focusedActionDraftBinding: Binding<String> {
        Binding(
            get: {
                guard let focusedActionID else { return "" }
                return liveActionDraftByID[focusedActionID] ?? weekActionsByID[focusedActionID]?.text ?? ""
            },
            set: { newValue in
                guard let focusedActionID else { return }
                liveActionDraftByID[focusedActionID] = newValue
            }
        )
    }

    private func collapsibleHeader(filterContext: ActionFilterContext) -> some View {
        VStack(spacing: 8) {
            if !isHeaderCollapsed {
                instructionsRow
                if shouldShowActionBlocksOldCautionCard && !dismissActionBlocksCautionCard {
                    cautionRow
                }
                if !isSearchPresented && !areAllActionBlocksCollapsed && !filterContext.orderedVisibleFilterChips.isEmpty {
                    filterChipsRow(filterContext: filterContext)
                }
                if !isSearchPresented,
                   !areAllActionBlocksCollapsed,
                   !filterContext.orderedVisibleFilterChips.isEmpty,
                   let openFilter,
                   isFilterMenuAvailable(openFilter, filterContext: filterContext) {
                    filterDropdown(for: openFilter, filterContext: filterContext)
                }
            }
        }
        .padding(.bottom, 6)
    }

    private var shouldShowActionBlocksOldCautionCard: Bool {
        let autoShow = (blocksAgeDays ?? 0) >= 8
        let manualShow = developerWarningCardsEnabled && developerOldActionBlocksWarningEnabled
        return manualShow || autoShow
    }

    private var currentWeekStartForMotivation: Date {
        currentWeekStart
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
        let cautionAgeDays = blocksAgeDays ?? (developerWarningCardsEnabled && developerOldActionBlocksWarningEnabled ? 8 : 0)
        let cautionForeground = Color.black.opacity(0.7)
        let accentBlue = Color.blue
        let lightBlueSurface = Color(red: 0.89, green: 0.95, blue: 1.0)
        HStack(alignment: .top, spacing: 8) {
            ZStack {
                Circle()
                    .fill(accentBlue)
                Image(systemName: "play.fill")
                    .foregroundStyle(.white)
                    .font(.caption.weight(.bold))
                    .offset(x: 0.5)
            }
            .frame(width: 22, height: 22)
            .overlay(
                Circle()
                    .stroke(accentBlue, lineWidth: 1.5)
            )
            .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                (
                    Text("Caution: ").fontWeight(.bold)
                    + Text("Action Plans created \(cautionAgeDays) days ago. Mark uncompleted actions ")
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
                .fill(lightBlueSurface)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(accentBlue, lineWidth: 1.2)
        )
    }

    private func filterChipsRow(filterContext: ActionFilterContext) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if isAnyFilterApplied {
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
                }

                ForEach(filterContext.orderedVisibleFilterChips, id: \.self) { chip in
                    filterChipView(chip)
                }
            }
            .padding(.vertical, 4)
        }
    }

    private static let defaultFilterChipOrderValues: [FilterChipKind] = [
        .activeOnly, .musts, .place, .person, .duration,
        .tool, .timeOfDay, .leveragedOnly, .attachments, .inProgressOnly
    ]

    private var defaultFilterChipOrder: [FilterChipKind] {
        Self.defaultFilterChipOrderValues
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
                title: "Assigned Only",
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
                iconName: "progress.indicator",
                isActive: inProgressOnly,
                showsChevron: false
            ) {
                inProgressOnly.toggle()
            }
        }
    }

    @ViewBuilder
    private func filterDropdown(for menu: FilterMenu, filterContext: ActionFilterContext) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            switch menu {
            case .place:
                wrapSelectablePills(
                    options: filterContext.contextualPlaceItems,
                    isSelected: { selectedPlaceIDs.contains($0.id) },
                    label: { $0.place },
                    onTap: { item in
                        if selectedPlaceIDs.contains(item.id) { selectedPlaceIDs.remove(item.id) }
                        else { selectedPlaceIDs.insert(item.id) }
                    }
                )
            case .person:
                wrapSelectablePills(
                    options: filterContext.contextualPersonResources,
                    isSelected: { selectedPersonIDs.contains($0.id) },
                    label: { $0.value },
                    onTap: { item in
                        if selectedPersonIDs.contains(item.id) { selectedPersonIDs.remove(item.id) }
                        else { selectedPersonIDs.insert(item.id) }
                    }
                )
            case .tool:
                wrapSelectablePills(
                    options: filterContext.contextualToolResources,
                    isSelected: { selectedToolIDs.contains($0.id) },
                    label: { $0.value },
                    onTap: { item in
                        if selectedToolIDs.contains(item.id) { selectedToolIDs.remove(item.id) }
                        else { selectedToolIDs.insert(item.id) }
                    }
                )
            case .timeOfDay:
                wrapSelectablePills(
                    options: filterContext.contextualTimeOfDayOptions,
                    isSelected: { selectedTimeOfDay.contains($0) },
                    label: { $0.title },
                    onTap: { item in
                        if selectedTimeOfDay.contains(item) { selectedTimeOfDay.remove(item) }
                        else { selectedTimeOfDay.insert(item) }
                    }
                )
            case .duration:
                wrapSelectablePills(
                    options: filterContext.contextualDurations,
                    isSelected: { selectedDurations.contains($0) },
                    label: { "\($0)m" },
                    onTap: { value in
                        if selectedDurations.contains(value) { selectedDurations.remove(value) }
                        else { selectedDurations.insert(value) }
                    }
                )
            case .attachments:
                wrapSelectablePills(
                    options: filterContext.contextualAttachmentKinds,
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
        resourceCatalogByID: [UUID: LeverageResource],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        duePresentationByActionID: [UUID: ActionDuePresentation],
        rolesByID: [UUID: String],
        outcomesByID: [UUID: Outcomes]
    ) -> some View {
        let filtered = filteredActions
        let allForChunk = allActions
        let isOtherChunk = chunk.labelId == PlanOtherLabel.id ||
            chunk.label.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == PlanOtherLabel.title.lowercased()
        // Keep "Other" visually stable across light/dark appearances.
        let fill: Color = isOtherChunk ? Color(red: 0.92, green: 0.92, blue: 0.94) : categoryFillColor(for: chunk.category)
        let accent: Color = isOtherChunk ? .black : categoryAccentColor(for: chunk.category)
        let step4 = weekStepFourStatesByChunkID[chunk.id]
        let step4ResultText = step4?.resultText ?? ""
        let roleName = step4?.connectedRoleId.flatMap { rolesByID[$0] } ?? ""
        let selectedOutcomeIDs = weekOutcomeIDsByChunkID[chunk.id] ?? []
        let outcomesForChunk = selectedOutcomeIDs.compactMap { outcomesByID[$0] }
        let isCollapsed = areAllActionBlocksCollapsed
        let canShowFooterControls = !isAnyFilterApplied
        let showNoApplicableActionsPlaceholder = filtered.isEmpty && isAnyFilterApplied && !actionBlocksSimpleViewEnabled
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

        let cardBody = chunkCardBody(
            chunk: chunk,
            allForChunk: allForChunk,
            filtered: filtered,
            displayedFiltered: displayedFiltered,
            defineByAction: defineByAction,
            executionByAction: executionByAction,
            resourcesByAction: resourcesByAction,
            resourceCatalogByID: resourceCatalogByID,
            placesByAction: placesByAction,
            notesByAction: notesByAction,
            attachmentsByAction: attachmentsByAction,
            duePresentationByActionID: duePresentationByActionID,
            blockFill: fill,
            accent: accent,
            roleName: roleName,
            outcomesForChunk: outcomesForChunk,
            step4ResultText: step4ResultText,
            step4: step4,
            isOtherChunk: isOtherChunk,
            showNoApplicableActionsPlaceholder: showNoApplicableActionsPlaceholder,
            isCollapsed: isCollapsed,
            showCompletedInactiveHeader: showCompletedInactiveHeader,
            canShowFooterControls: canShowFooterControls,
            canReorderDisplayedActions: canReorderDisplayedActions
            )
        
        return cardBody
            .padding(12)
            .background(
                RoundedRectangle(cornerRadius: 14)
                    .fill(actionBlocksSimpleViewEnabled ? Color.clear : fill)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        actionBlocksSimpleViewEnabled
                        ? fill.opacity(isOtherChunk ? 0.72 : (colorScheme == .dark ? 0.92 : 1.0))
                        : (colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12)),
                        lineWidth: actionBlocksSimpleViewEnabled ? 1.5 : 1
                    )
            )
            .contentShape(Rectangle())
            .onTapGesture {
                if areAllActionBlocksCollapsed {
                    expandAllActionBlocksAndScrollToTop(anchor: "chunk-\(chunk.id.uuidString)")
                }
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
        resourceCatalogByID: [UUID: LeverageResource],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        duePresentationByActionID: [UUID: ActionDuePresentation],
        blockFill: Color,
        accent: Color,
        roleName: String,
        outcomesForChunk: [Outcomes],
        step4ResultText: String,
        step4: PlannedChunkStepFourState?,
        isOtherChunk: Bool,
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
                    actions: allForChunk,
                    defineByAction: defineByAction,
                    executionByAction: executionByAction,
                    isOtherChunk: isOtherChunk
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
                    resourceCatalogByID: resourceCatalogByID,
                    placesByAction: placesByAction,
                    notesByAction: notesByAction,
                    attachmentsByAction: attachmentsByAction,
                    duePresentationByActionID: duePresentationByActionID,
                    blockFill: blockFill,
                    accent: accent,
                    roleName: roleName,
                    outcomesForChunk: outcomesForChunk,
                    step4ResultText: step4ResultText,
                    isOtherChunk: isOtherChunk,
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
        actions: [PlannedChunkAction],
        defineByAction: [UUID: PlannedChunkActionDefineState],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        isOtherChunk: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 10) {
                compactSummaryRow(label: "RESULT", text: resultText)

                Divider().opacity(0.4)

                compactActionsSummary(
                    actions: actions,
                    executionByAction: executionByAction,
                    isOtherChunk: isOtherChunk
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
        resourceCatalogByID: [UUID: LeverageResource],
        placesByAction: [UUID: Set<UUID>],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        duePresentationByActionID: [UUID: ActionDuePresentation],
        blockFill: Color,
        accent: Color,
        roleName: String,
        outcomesForChunk: [Outcomes],
        step4ResultText: String,
        isOtherChunk: Bool,
        showCompletedInactiveHeader: Bool,
        canShowFooterControls: Bool,
        canReorderDisplayedActions: Bool
    ) -> some View {
        let activeActionsForRearrange = signposted("build_rearrangeable_actions") {
            allForChunk.filter {
                isActiveStatus(effectiveExecutionStatus(for: $0.id, persisted: executionByAction))
            }
        }
        let rowContexts = signposted("build_row_render_contexts") {
            displayedFiltered.map { action in
                let defineState = defineByAction[action.id]
                let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
                let selectedResource = resourcesByAction[action.id].flatMap { resourceCatalogByID[$0] }
                let hasLeverage = selectedResource != nil
                let leverageIconName: String = {
                    guard let selectedResource else { return "person" }
                    return selectedResource.kind == .tool ? "wrench.and.screwdriver.fill" : "person.fill"
                }()
                let placeIDs = placesByAction[action.id] ?? []
                let hasSensitivity = hasAnySensitivity(
                    defineState: defineState,
                    placeIDs: placeIDs,
                    hasDueDate: duePresentationByActionID[action.id]?.hasDueDate ?? false
                )
                let hasAttachments = hasAnyAttachments(
                    note: notesByAction[action.id],
                    attachments: attachmentsByAction[action.id] ?? []
                )
                return ActionRowRenderContext(
                    action: action,
                    defineState: defineState,
                    status: status,
                    duePresentation: duePresentationByActionID[action.id],
                    hasLeverage: hasLeverage,
                    leverageIconName: leverageIconName,
                    hasSensitivity: hasSensitivity,
                    hasAttachments: hasAttachments,
                    highlightStatusBox: highlightedStatusActionIDs.contains(action.id)
                )
            }
        }
        let chunkTotals = signposted("build_chunk_totals") {
            let isFilterApplied = isAnyFilterApplied
            let useFilterTotalsLabel = isFilterApplied && !isOnlyInactiveOnlyFilterApplied
            let totalSource = isFilterApplied ? filtered : allForChunk
            var totalMinutes = 0
            var totalMustMinutes = 0
            var hasActiveActions = false
            for action in totalSource {
                guard isActiveStatus(effectiveExecutionStatus(for: action.id, persisted: executionByAction)) else { continue }
                hasActiveActions = true
                let minutes = defineByAction[action.id]?.timeEstimateMinutes ?? 0
                totalMinutes += minutes
                if isMust(for: action.id, defineByAction: defineByAction) {
                    totalMustMinutes += minutes
                }
            }
            return (
                useFilterTotalsLabel: useFilterTotalsLabel,
                hasActiveActions: hasActiveActions,
                totalMinutes: totalMinutes,
                totalMustMinutes: totalMustMinutes
            )
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
                if !actionBlocksSimpleViewEnabled {
                    collapseButton()
                }
                if !actionBlocksSimpleViewEnabled {
                    rearrangeActionsButton(for: chunk, actions: activeActionsForRearrange, isEnabled: !isAnyFilterApplied)
                }
                Spacer(minLength: 0)
            }
        }

        resultSection(
            resultText: step4ResultText,
            showsPrompt: !actionBlocksSimpleViewEnabled
        )

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
            let usesFullViewPalette = !actionBlocksSimpleViewEnabled
            HStack {
                Text("ACTIONS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        usesFullViewPalette
                            ? Color.black
                            : (colorScheme == .dark ? Color.white : .black)
                    )
                Spacer()
                if !actionBlocksSimpleViewEnabled {
                    Text("How can I best acheive it now?")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            }

            if showCompletedInactiveHeader {
                HStack(alignment: .center, spacing: 8) {
                    Text("All Actions are Inactive")
                        .font(.footnote)
                        .foregroundStyle(
                            usesFullViewPalette
                                ? Color.black.opacity(0.72)
                                : (colorScheme == .dark ? Color.white : Color.black.opacity(0.72))
                        )
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

            if actionBlocksSimpleViewEnabled {
                LazyVStack(spacing: 8) {
                    ForEach(rowContexts) { row in
                        actionRow(
                            action: row.action,
                            accent: accent,
                            isOtherChunk: isOtherChunk,
                            duePresentation: row.duePresentation,
                            defineState: row.defineState,
                            status: row.status,
                            hasLeverage: row.hasLeverage,
                            leverageIconName: row.leverageIconName,
                            hasSensitivity: row.hasSensitivity,
                            hasAttachments: row.hasAttachments,
                            highlightStatusBox: row.highlightStatusBox,
                            showsReorderHandle: false,
                            simpleMode: true,
                            blockFill: blockFill
                        )
                        .id(row.id)
                    }
                }
            } else {
                LazyVStack(spacing: 8) {
                    ForEach(rowContexts) { row in
                        if canReorderDisplayedActions {
                            actionRow(
                                action: row.action,
                                accent: accent,
                                isOtherChunk: isOtherChunk,
                                duePresentation: row.duePresentation,
                                defineState: row.defineState,
                                status: row.status,
                                hasLeverage: row.hasLeverage,
                                leverageIconName: row.leverageIconName,
                                hasSensitivity: row.hasSensitivity,
                                hasAttachments: row.hasAttachments,
                                highlightStatusBox: row.highlightStatusBox,
                                showsReorderHandle: true,
                                simpleMode: false,
                                blockFill: blockFill
                            )
                            .id(row.id)
                            .onDrag {
                                let startingOrder = displayedFiltered.map(\.id)
                                draggedActionChunkID = chunk.id
                                localActionOrderIDs = startingOrder
                                draggedActionID = row.id
                                return NSItemProvider(object: row.id.uuidString as NSString)
                            }
                            .onDrop(
                                of: [.text],
                                delegate: AnimatedActionRowDropDelegate(
                                    targetID: row.id,
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
                                action: row.action,
                                accent: accent,
                                isOtherChunk: isOtherChunk,
                                duePresentation: row.duePresentation,
                                defineState: row.defineState,
                                status: row.status,
                                hasLeverage: row.hasLeverage,
                                leverageIconName: row.leverageIconName,
                                hasSensitivity: row.hasSensitivity,
                                hasAttachments: row.hasAttachments,
                                highlightStatusBox: row.highlightStatusBox,
                                showsReorderHandle: false,
                                simpleMode: false,
                                blockFill: blockFill
                            )
                            .id(row.id)
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
            }

            if !actionBlocksSimpleViewEnabled {
                Divider().opacity(0.35)
                HStack(alignment: .bottom) {
                    Spacer(minLength: 8)

                    if chunkTotals.hasActiveActions {
                        VStack(alignment: .trailing, spacing: 4) {
                            (
                                Text(chunkTotals.useFilterTotalsLabel ? "Filter Total Time: " : "Total Time: ")
                                    .font(.footnote)
                                + Text(formatMinutes(chunkTotals.totalMinutes))
                                    .font(.footnote)
                                    .fontWeight(.bold)
                            )
                            .italic(chunkTotals.useFilterTotalsLabel)
                            .foregroundStyle(Color.black.opacity(0.58))

                            (
                                Text(chunkTotals.useFilterTotalsLabel ? "Filter Total Must Time: " : "Total Must Time: ")
                                    .font(.footnote)
                                + Text(formatMinutes(chunkTotals.totalMustMinutes))
                                    .font(.footnote)
                                    .fontWeight(.bold)
                            )
                            .italic(chunkTotals.useFilterTotalsLabel)
                            .foregroundStyle(Color.black.opacity(0.58))
                        }
                        .frame(maxWidth: .infinity, alignment: .trailing)
                        .multilineTextAlignment(.trailing)
                    }
                }
            }

        }
    }

    private func resultSection(resultText: String, showsPrompt: Bool) -> some View {
        let usesFullViewPalette = showsPrompt
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(
                        usesFullViewPalette
                            ? Color.black
                            : (colorScheme == .dark ? Color.white : .black)
                    )
                Spacer()
                if showsPrompt {
                    Text("What do I want? Why do I want it?")
                        .font(.footnote)
                        .italic()
                        .foregroundStyle(Color.black.opacity(0.58))
                }
            }

            Text(resultText.isEmpty ? "-" : resultText)
                .font(.subheadline)
                .foregroundStyle(
                    usesFullViewPalette
                        ? (resultText.isEmpty ? Color.secondary : .black)
                        : (
                            colorScheme == .dark
                                ? Color.white
                                : (resultText.isEmpty ? Color.secondary : .black)
                        )
                )
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
        isOtherChunk: Bool,
        duePresentation: ActionDuePresentation?,
        defineState: PlannedChunkActionDefineState?,
        status: ActionExecutionStatus,
        hasLeverage: Bool,
        leverageIconName: String,
        hasSensitivity: Bool,
        hasAttachments: Bool,
        highlightStatusBox: Bool,
        showsReorderHandle: Bool,
        simpleMode: Bool,
        blockFill: Color
    ) -> some View {
        signposted("build_action_row") {
            ActionSwipeRow(
                actionId: action.id,
                text: action.text,
                dueStatusText: duePresentation?.text,
                dueStatusColor: duePresentation?.color ?? .secondary,
                status: status,
                accent: accent,
                isOtherChunk: isOtherChunk,
                colorScheme: colorScheme,
                isMust: isMust(for: action.id, defineState: defineState),
                minutes: defineState?.timeEstimateMinutes,
                hasLeverage: hasLeverage,
                leverageIconName: leverageIconName,
                hasSensitivity: hasSensitivity,
                hasAttachments: hasAttachments,
                highlightStatusBox: highlightStatusBox,
                showsReorderHandle: showsReorderHandle,
                simpleMode: simpleMode,
                simpleModeFillColor: blockFill,
                onTapText: {
                    beginEditingAction(action)
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
            let ordered = actions.sorted(by: { (lhs: PlannedChunkAction, rhs: PlannedChunkAction) in
                if lhs.sortOrder != rhs.sortOrder { return lhs.sortOrder < rhs.sortOrder }
                if lhs.createdAt != rhs.createdAt { return lhs.createdAt > rhs.createdAt }
                return lhs.id.uuidString < rhs.id.uuidString
            })
            rearrangeActionsSheetPayload = RearrangeActionsSheetPayload(
                id: chunk.id,
                items: ordered.map { .init(id: $0.id, text: $0.text) }
            )
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
        let statuses = actions.map { effectiveExecutionStatus(for: $0.id, persisted: executionByAction) }
        let totalActionsCount = actions.count
        let inactiveActionsCount = statuses.filter { isCompletedForCollapsedMetrics($0) }.count
        let totalEstimatedMinutes = actions.reduce(0) { partial, action in
            partial + max(0, defineByAction[action.id]?.timeEstimateMinutes ?? 0)
        }
        let inactiveEstimatedMinutes = actions.reduce(0) { partial, action in
            let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
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
        let actionsByChunk = weekActionsByChunkID

        var changed = false
        for (newIndex, id) in finalIDs.enumerated() {
            guard let chunk = byID[id] else { continue }
            if chunk.chunkIndex != newIndex {
                chunk.chunkIndex = newIndex
                chunk.updatedAt = .now
                changed = true
            }
            for action in actionsByChunk[chunk.id] ?? [] {
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
        let usesFullViewPalette = !actionBlocksSimpleViewEnabled
        return HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(label)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(
                    usesFullViewPalette
                        ? Color.black
                        : (colorScheme == .dark ? Color.white : .black)
                )
            Text(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : text)
                .font(.subheadline)
                .foregroundStyle(
                    usesFullViewPalette
                        ? Color.black
                        : (colorScheme == .dark ? Color.white : .black)
                )
                .lineLimit(1)
                .truncationMode(.tail)
        }
    }

    private func compactActionsSummary(
        actions: [PlannedChunkAction],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
        isOtherChunk: Bool
    ) -> some View {
        let usesFullViewPalette = !actionBlocksSimpleViewEnabled
        let usesOtherDarkIconTint = false
        let statuses = actions.map { effectiveExecutionStatus(for: $0.id, persisted: executionByAction) }
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
                .foregroundStyle(
                    usesFullViewPalette
                        ? Color.black
                        : (colorScheme == .dark ? Color.white : .black)
                )

            if leveragedCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.leveraged.icon, count: leveragedCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
            }
            if inProgressCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.inProgress.icon, count: inProgressCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
            }
            if doneCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.done.icon, count: doneCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
            }
            if carriedCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.carriedToCapture.icon, count: carriedCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
            }
            if notNeededCount > 0 {
                compactStatusCount(icon: ActionExecutionStatus.notNeeded.icon, count: notNeededCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
            }

            noActionCountChip(count: noActionCount, usesOtherDarkIconTint: usesOtherDarkIconTint)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func compactStatusCount(icon: String, count: Int, usesOtherDarkIconTint: Bool) -> some View {
        HStack(spacing: 3) {
            Image(systemName: icon)
                .font(.caption.weight(.semibold))
            Text("\(count)")
                .font(.caption.weight(.bold))
        }
        .foregroundStyle(usesOtherDarkIconTint ? Color.white.opacity(0.85) : Color.black.opacity(0.72))
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(usesOtherDarkIconTint ? Color.white.opacity(0.22) : Color.black.opacity(0.15), lineWidth: 1)
        )
    }

    private func noActionCountChip(count: Int, usesOtherDarkIconTint: Bool) -> some View {
        (
            Text("No action ")
                .font(.caption)
            + Text("\(count)")
                .font(.caption.weight(.bold))
        )
        .foregroundStyle(usesOtherDarkIconTint ? Color.white.opacity(0.85) : Color.black.opacity(0.72))
        .lineLimit(1)
        .truncationMode(.tail)
        .padding(.vertical, 3)
        .padding(.horizontal, 6)
        .overlay(
            RoundedRectangle(cornerRadius: 7)
                .stroke(usesOtherDarkIconTint ? Color.white.opacity(0.22) : Color.black.opacity(0.15), lineWidth: 1)
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

    private var captureItemByNormalizedActionText: [String: RollingCaptureItem] {
        var result: [String: RollingCaptureItem] = [:]
        for item in captureItems {
            let key = normalizedActionText(item.text)
            if result[key] == nil {
                result[key] = item
            }
        }
        return result
    }

    private static let sharedDateFormatterCurrentYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("E MMM d")
        return formatter
    }()

    private static let sharedDateFormatterWithYear: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        formatter.setLocalizedDateFormatFromTemplate("E MMM d, yyyy")
        return formatter
    }()

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private func formatDueDate(_ date: Date) -> String {
        let cal = Calendar.current
        let currentYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        if year == currentYear {
            return Self.sharedDateFormatterCurrentYear.string(from: date)
        } else {
            return Self.sharedDateFormatterWithYear.string(from: date)
        }
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

    private func loadActionDueSnapshots(for weekStart: Date) -> [String: PlannedActionDueSnapshot] {
        let key = actionDueSnapshotStorageKey(for: weekStart)
        guard let data = UserDefaults.standard.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: PlannedActionDueSnapshot].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private func persistActionDueSnapshots(_ snapshots: [String: PlannedActionDueSnapshot], weekStart: Date) {
        let key = actionDueSnapshotStorageKey(for: weekStart)
        if snapshots.isEmpty {
            UserDefaults.standard.removeObject(forKey: key)
            dueSnapshotsCache = [:]
            return
        }
        guard let data = try? JSONEncoder().encode(snapshots) else { return }
        UserDefaults.standard.set(data, forKey: key)
        dueSnapshotsCache = snapshots
    }

    private func actionDueSnapshotStorageKey(for weekStart: Date) -> String {
        "planned_action_due_snapshots_\(dayKey(for: weekStart))"
    }

    private func dayKey(for date: Date) -> String {
        Self.dayKeyFormatter.string(from: date)
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
        guard let action = weekActionsByID[actionId] else { return nil }
        let actionText = normalizedActionText(action.text)
        return captureItemByNormalizedActionText[actionText]
    }

    private func buildDuePresentationByActionID() -> [UUID: ActionDuePresentation] {
        let snapshots = dueSnapshotsCache.isEmpty ? loadActionDueSnapshots(for: currentWeekStart) : dueSnapshotsCache
        let captureByText = captureItemByNormalizedActionText
        let dispatchByItemID = recurringDispatchByItemID
        let ruleByID = recurringRuleByID
        let calendar = Calendar.current
        let defaultAttention = min(max(dueDateAttentionDays, 7), 30)
        var result: [UUID: ActionDuePresentation] = [:]
        result.reserveCapacity(weekActions.count)

        for action in weekActions {
            let key = normalizedActionText(action.text)
            if let item = captureByText[key] {
                let resolvedDue: Date? = {
                    if let explicit = item.dueDate {
                        return calendar.startOfDay(for: explicit)
                    }
                    guard let dispatch = dispatchByItemID[item.id],
                          let rule = ruleByID[dispatch.ruleID] else {
                        return nil
                    }
                    let leadDays = max(7, rule.captureDaysBeforeDueDate)
                    let due = calendar.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
                    return calendar.startOfDay(for: due)
                }()
                let attention = min(max(item.dueDateAttentionDays ?? defaultAttention, 7), 30)
                result[action.id] = ActionDuePresentation(
                    text: resolvedDue.flatMap { dueDateStatusText(for: $0, attentionDays: attention) },
                    color: resolvedDue.map { dueDateStatusColor(for: $0) } ?? .secondary,
                    hasDueDate: resolvedDue != nil
                )
                continue
            }

            if let snapshot = snapshots[key] {
                result[action.id] = ActionDuePresentation(
                    text: dueDateStatusText(for: snapshot.dueDate, attentionDays: snapshot.attentionDays),
                    color: dueDateStatusColor(for: snapshot.dueDate),
                    hasDueDate: true
                )
            } else {
                result[action.id] = ActionDuePresentation(text: nil, color: .secondary, hasDueDate: false)
            }
        }

        return result
    }

    private func dueDateEditorState(forActionId actionId: UUID) -> DueDateEditorState? {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())

        if let item = captureItemForPlannedActionID(actionId) {
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

        guard let action = weekActionsByID[actionId] else { return nil }
        let snapshots = dueSnapshotsCache.isEmpty ? loadActionDueSnapshots(for: currentWeekStart) : dueSnapshotsCache
        let key = normalizedActionText(action.text)
        let existing = snapshots[key]
        let resolvedDue = cal.startOfDay(
            for: existing?.dueDate
                ?? cal.date(byAdding: .day, value: 7, to: today)
                ?? today
        )
        let attention = min(max(existing?.attentionDays ?? dueDateAttentionDays, 7), 30)
        return DueDateEditorState(
            hasDueDate: existing != nil,
            dueDate: resolvedDue,
            attentionDays: attention,
            minimumDate: today
        )
    }

    private func updateDueDateEditor(forActionId actionId: UUID, with updated: DueDateEditorState) {
        let normalizedDue = Calendar.current.startOfDay(for: updated.dueDate)
        let resolvedDue = updated.hasDueDate ? normalizedDue : nil
        let normalizedAttention = min(max(updated.attentionDays, 7), 30)

        if let item = captureItemForPlannedActionID(actionId) {
            item.dueDate = resolvedDue
            item.dueDateAttentionDays = normalizedAttention
            persistSourceDueDateOverrideIfNeeded(for: item, dueDate: resolvedDue)
            applyAppleReminderDueDateUpdateIfNeeded(for: item, dueDate: resolvedDue)
            scheduleAutosave()
            return
        }

        guard let action = weekActionsByID[actionId] else { return }
        var snapshots = dueSnapshotsCache.isEmpty ? loadActionDueSnapshots(for: currentWeekStart) : dueSnapshotsCache
        let key = normalizedActionText(action.text)
        if let resolvedDue {
            snapshots[key] = PlannedActionDueSnapshot(dueDate: resolvedDue, attentionDays: normalizedAttention)
        } else {
            snapshots.removeValue(forKey: key)
        }
        persistActionDueSnapshots(snapshots, weekStart: currentWeekStart)
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

    private func beginEditingAction(_ action: PlannedChunkAction) {
        actionSearchText = ""
        isSearchPresented = false
        isSearchFieldFocused = false
        liveActionDraftByID[action.id] = action.text
        focusedActionID = action.id
        DispatchQueue.main.async {
            isActionEditorFocused = true
        }
    }

    private func markAllUncompletedAsRecapture() {
        let executionByAction = executionStateByActionID
        for action in weekActions {
            let current = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
            if current == .noAction || current == .leveraged || current == .inProgress {
                setStatus(for: action.id, to: .carriedToCapture)
            }
        }
    }

    private func buildFilteredActionsByChunk(
        filteredActions: [PlannedChunkAction],
        executionByAction: [UUID: PlannedChunkActionExecutionState],
    ) -> [UUID: [PlannedChunkAction]] {
        var result: [UUID: [PlannedChunkAction]] = [:]
        let statusRankByActionID: [UUID: Int] = signposted("build_status_rank_by_filtered_action") {
            var map: [UUID: Int] = [:]
            map.reserveCapacity(filteredActions.count)
            for action in filteredActions {
                let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
                let rank: Int
                switch status {
                case .inProgress:
                    rank = 0
                case .done, .carriedToCapture, .notNeeded:
                    rank = 2
                default:
                    rank = 1
                }
                map[action.id] = rank
            }
            return map
        }

        signposted("group_prefiltered_actions_by_chunk") {
            for action in filteredActions {
                result[action.plannedChunkId, default: []].append(action)
            }
        }
        // Display-only ordering rule:
        // - "In progress" actions are pinned to the top inside each chunk.
        // - Closed actions are pinned to the bottom inside each chunk.
        //   (Done, Carried to capture, Didn't need to be done)
        // - Base order remains `sortOrder`, so when status changes away from these
        //   pinned statuses the action naturally returns to its previous list position.
        signposted("sort_filtered_actions_by_chunk") {
            for chunkId in result.keys {
                result[chunkId]?.sort { lhs, rhs in
                    let lhsRank = statusRankByActionID[lhs.id] ?? 1
                    let rhsRank = statusRankByActionID[rhs.id] ?? 1

                    if lhsRank != rhsRank {
                        return lhsRank < rhsRank
                    }
                    if lhs.sortOrder != rhs.sortOrder {
                        return lhs.sortOrder < rhs.sortOrder
                    }
                    return lhs.id.uuidString < rhs.id.uuidString
                }
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
        attachmentPresenceByActionID: [UUID: ActionAttachmentPresence],
        resourceCatalogByID: [UUID: LeverageResource],
        excludedFacets: Set<FilterFacet> = []
    ) -> Bool {
        let define = defineByAction[action.id]
        let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)

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
            let presence = attachmentPresenceByActionID[action.id]
            if !matchesAttachmentKinds(presence: presence, selected: selectedAttachmentKinds) {
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
        presence: ActionAttachmentPresence?,
        selected: Set<ActionAttachmentFilterKind>
    ) -> Bool {
        for kind in selected {
            switch kind {
            case .note:
                if presence?.hasNote == true { return true }
            case .link:
                if presence?.hasLink == true { return true }
            case .file:
                if presence?.hasFile == true { return true }
            }
        }
        return false
    }

    private func searchFilteredActions(
        from actions: [PlannedChunkAction],
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        resourcesByAction: [UUID: UUID],
        resourceCatalogByID: [UUID: LeverageResource],
        placesByAction: [UUID: Set<UUID>]
    ) -> [PlannedChunkAction] {
        let query = searchQueryTrimmed
        guard !query.isEmpty else { return actions }
        let normalizedQuery = normalizedActionSearchText(query)

        return actions.filter { action in
            actionMatchesSearch(
                action,
                normalizedQuery: normalizedQuery,
                notesByAction: notesByAction,
                attachmentsByAction: attachmentsByAction,
                resourcesByAction: resourcesByAction,
                resourceCatalogByID: resourceCatalogByID,
                placesByAction: placesByAction
            )
        }
    }

    private func actionMatchesSearch(
        _ action: PlannedChunkAction,
        normalizedQuery: String,
        notesByAction: [UUID: PlannedChunkActionNote],
        attachmentsByAction: [UUID: [PlannedChunkActionAttachment]],
        resourcesByAction: [UUID: UUID],
        resourceCatalogByID: [UUID: LeverageResource],
        placesByAction: [UUID: Set<UUID>]
    ) -> Bool {
        guard !normalizedQuery.isEmpty else { return true }

        var haystacks: [String] = [action.text]

        if let note = notesByAction[action.id]?.noteText, !note.isEmpty {
            haystacks.append(note)
        }

        if let resourceID = resourcesByAction[action.id],
           let resource = resourceCatalogByID[resourceID] {
            haystacks.append(resource.value)
            haystacks.append(resource.kind == .person ? "person" : "tool")
        }

        if let placeIDs = placesByAction[action.id] {
            for id in placeIDs {
                if let place = placesCatalogByID[id]?.place, !place.isEmpty {
                    haystacks.append(place)
                }
            }
        }

        for attachment in attachmentsByAction[action.id] ?? [] {
            haystacks.append(attachment.fileName ?? "")
            haystacks.append(attachment.urlString ?? "")
            haystacks.append(attachment.kindRaw)
        }

        return haystacks.contains { value in
            normalizedActionSearchText(value).contains(normalizedQuery)
        }
    }

    private func normalizedActionSearchText(_ value: String) -> String {
        value
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .lowercased()
    }

    private func status(for actionId: UUID) -> ActionExecutionStatus {
        return effectiveExecutionStatus(for: actionId)
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
        pendingStatusOverridesByActionID[actionId] = newStatus
        signposted("enqueue_status_persist") {
            deferredPersistor.enqueueStatus(for: actionId, status: newStatus, delayNanos: 220_000_000) { @MainActor statuses, musts in
                self.applyDeferredWrites(statuses: statuses, musts: musts)
            }
        }
    }

    private func scheduleMustPersist(for actionId: UUID, isMust: Bool) {
        signposted("enqueue_must_persist") {
            deferredPersistor.enqueueMust(for: actionId, isMust: isMust, delayNanos: 220_000_000) { @MainActor statuses, musts in
                self.applyDeferredWrites(statuses: statuses, musts: musts)
            }
        }
    }

    private func clearLeveragedStatusIfNoSelection(for actionId: UUID) {
        guard status(for: actionId) == .leveraged else { return }
        guard selectedResourceByActionID[actionId] == nil else { return }
        scheduleStatusPersist(for: actionId, status: .noAction)
    }

    private func applyDeferredWrites(
        statuses: [UUID: ActionExecutionStatus],
        musts: [UUID: Bool],
        persistImmediately: Bool = false
    ) {
        signposted("apply_deferred_writes") {
            if !statuses.isEmpty {
                for (actionId, newStatus) in statuses {
                    upsertExecutionState(forActionId: actionId) { state in
                        state.status = newStatus
                        state.updatedAt = .now
                    }
                }
                for actionId in statuses.keys {
                    pendingStatusOverridesByActionID.removeValue(forKey: actionId)
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
                if persistImmediately {
                    runtimeState.autosaveTask?.cancel()
                    persistNow()
                } else {
                    scheduleAutosave()
                }
            }
        }
    }

    private func flushPendingWritesAndPersist() {
        let pending = deferredPersistor.takePendingAndCancel()
        runtimeState.autosaveTask?.cancel()
        applyDeferredWrites(
            statuses: pending.statuses,
            musts: pending.musts,
            persistImmediately: true
        )
        persistNow()
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
        defineState st: PlannedChunkActionDefineState?,
        placeIDs: Set<UUID>,
        hasDueDate: Bool
    ) -> Bool {
        let hasTimePrefs = !(st?.sensitiveMorning ?? true) || !(st?.sensitiveAfternoon ?? true) || !(st?.sensitiveEvening ?? true)
        let hasPlaces = !placeIDs.isEmpty
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
        let defineIDs = Set(defineStates.map(\.plannedChunkActionId))
        let executionIDs = Set(executionStates.map(\.plannedChunkActionId))
        let leverageIDs = Set(leverageSelections.map(\.plannedChunkActionId))
        let noteIDs = Set(notes.map(\.plannedChunkActionId))

        for action in weekActions {
            if !defineIDs.contains(action.id) {
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
            if !executionIDs.contains(action.id) {
                modelContext.insert(PlannedChunkActionExecutionState(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    statusRaw: ActionExecutionStatus.noAction.rawValue,
                    updatedAt: .now
                ))
                insertedAny = true
            }
            if !leverageIDs.contains(action.id) {
                modelContext.insert(PlannedChunkActionLeverageSelection(
                    weekStart: currentWeekStart,
                    plannedChunkActionId: action.id,
                    resourceId: nil,
                    updatedAt: .now
                ))
                insertedAny = true
            }
            if !noteIDs.contains(action.id) {
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
        var leverageByKindValue = Dictionary(uniqueKeysWithValues: leverageCatalog.map { ($0.kindValueKey, $0) })
        var placesByNormalizedKey = Dictionary(uniqueKeysWithValues: placesCatalog.map { ($0.normalizedKey, $0) })
        let defineByActionID = Dictionary(grouping: defineStates, by: \.plannedChunkActionId)
        let executionByActionID = Dictionary(grouping: executionStates, by: \.plannedChunkActionId)
        let leverageByActionID = Dictionary(grouping: leverageSelections, by: \.plannedChunkActionId)
        let notesByActionID = Dictionary(grouping: notes, by: \.plannedChunkActionId)
        let placeLinksByActionID = Dictionary(grouping: placeLinks, by: \.plannedChunkActionId)
        let attachmentsByActionID = Dictionary(grouping: attachments, by: \.plannedChunkActionId)

        for action in weekActions {
            guard !carriedProfileAppliedActionIDs.contains(action.id) else { continue }
            guard let profile = ActionCarryProfileStore.load(for: action.text) else { continue }
            guard shouldApplyCarriedProfile(
                to: action.id,
                defineByActionID: defineByActionID,
                executionByActionID: executionByActionID,
                leverageByActionID: leverageByActionID,
                notesByActionID: notesByActionID,
                placeLinksByActionID: placeLinksByActionID,
                attachmentsByActionID: attachmentsByActionID
            ) else {
                carriedProfileAppliedActionIDs.insert(action.id)
                continue
            }

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
                if let existing = leverageByKindValue[key] {
                    resource = existing
                } else {
                    let created = LeverageResource(kindRaw: kind.rawValue, value: value)
                    modelContext.insert(created)
                    resource = created
                    leverageByKindValue[key] = created
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
                if let existing = placesByNormalizedKey[normalized] {
                    return existing.id
                }
                let created = SensitivityPlaceCatalogItem(place: placeName)
                modelContext.insert(created)
                placesByNormalizedKey[normalized] = created
                return created.id
            })

            let existingLinks = placeLinksByActionID[action.id] ?? []
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

            let existingAttachments = attachmentsByActionID[action.id] ?? []
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

    private func shouldApplyCarriedProfile(
        to actionId: UUID,
        defineByActionID: [UUID: [PlannedChunkActionDefineState]],
        executionByActionID: [UUID: [PlannedChunkActionExecutionState]],
        leverageByActionID: [UUID: [PlannedChunkActionLeverageSelection]],
        notesByActionID: [UUID: [PlannedChunkActionNote]],
        placeLinksByActionID: [UUID: [PlannedChunkActionSensitivityPlaceLink]],
        attachmentsByActionID: [UUID: [PlannedChunkActionAttachment]]
    ) -> Bool {
        if let define = defineByActionID[actionId]?.max(by: { $0.updatedAt < $1.updatedAt }) {
            let isDefaultDefine =
                define.isMust == false &&
                define.timeEstimateMinutes == nil &&
                define.sensitiveMorning == true &&
                define.sensitiveAfternoon == true &&
                define.sensitiveEvening == true
            if !isDefaultDefine {
                return false
            }
        }

        if let execution = executionByActionID[actionId]?.max(by: { $0.updatedAt < $1.updatedAt }),
           execution.status != .noAction {
            return false
        }

        if let selection = leverageByActionID[actionId]?.max(by: { $0.updatedAt < $1.updatedAt }),
           selection.resourceId != nil {
            return false
        }

        if let note = notesByActionID[actionId]?.max(by: { $0.updatedAt < $1.updatedAt }),
           !note.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return false
        }

        if !(placeLinksByActionID[actionId] ?? []).isEmpty {
            return false
        }

        if !(attachmentsByActionID[actionId] ?? []).isEmpty {
            return false
        }

        return true
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

    private func isFilterMenuAvailable(_ menu: FilterMenu, filterContext: ActionFilterContext) -> Bool {
        switch menu {
        case .place: return filterContext.hasPlaceFilterButton
        case .person: return filterContext.hasPersonFilterButton
        case .tool: return filterContext.hasToolFilterButton
        case .timeOfDay: return filterContext.hasTimeOfDayFilterButton
        case .duration: return filterContext.hasDurationFilterButton
        case .attachments: return filterContext.hasAttachmentsFilterButton
        }
    }

    private func handleScrollOffsetChange(_ y: CGFloat) {
        let now = Date().timeIntervalSinceReferenceDate
        let dy = y - runtimeState.lastScrollY
        let dt = max(0.016, now - runtimeState.lastScrollTimestamp)
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

        runtimeState.lastScrollY = y
        runtimeState.lastScrollTimestamp = now
    }

    private func dismissKeyboardAndCommit() {
        commitFocusedActionDraftIfNeeded()
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
        persistNow()
    }

    private func dismissKeyboardOnly() {
        #if canImport(UIKit)
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
        #endif
    }

    private func commitFocusedActionDraftIfNeeded() {
        guard let focusedActionID, let action = weekActionsByID[focusedActionID] else { return }
        let draft = liveActionDraftByID[focusedActionID] ?? action.text
        handleActionTextCommit(action: action, newValue: draft)
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
        let executionByAction = executionStateByActionID
        let active = Set(
            weekActions.compactMap { action in
                let status = effectiveExecutionStatus(for: action.id, persisted: executionByAction)
                return isActiveStatus(status) ? action.id : nil
            }
        )
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
        let leverageSelectionByActionID = Dictionary(grouping: leverageSelections, by: \.plannedChunkActionId)
            .compactMapValues { $0.max(by: { $0.updatedAt < $1.updatedAt }) }
        if let sel = leverageSelectionByActionID[actionId] { RecentlyDeletedStore.trash(sel, in: modelContext) }
        if let note = notesByActionID[actionId] { RecentlyDeletedStore.trash(note, in: modelContext) }
        let placeLinksByActionID = Dictionary(grouping: placeLinks, by: \.plannedChunkActionId)
        for link in placeLinksByActionID[actionId] ?? [] { RecentlyDeletedStore.trash(link, in: modelContext) }
        for a in attachmentsByActionID[actionId] ?? [] { RecentlyDeletedStore.trash(a, in: modelContext) }
        if let action = weekActionsByID[actionId] {
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
        let actionsByID = weekActionsByID
        for id in pending {
            guard let action = actionsByID[id] else {
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
        ActivePlanSessionStore.setWeekStart(nil)
        try? modelContext.save()
    }

    private func scheduleAutosave() {
        runtimeState.autosaveTask?.cancel()
        runtimeState.autosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 700_000_000)
            signposted("autosave_persist") {
                persistNow()
            }
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
    private static let signposter = OSSignposter(subsystem: "loom", category: "ActionDeferredPersistor")
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
            let state = Self.signposter.beginInterval("deferred_flush_wait")
            try? await Task.sleep(nanoseconds: delayNanos)
            Self.signposter.endInterval("deferred_flush_wait", state)
            guard let self, !Task.isCancelled else { return }
            let statuses = self.pendingStatuses
            let musts = self.pendingMusts
            self.pendingStatuses.removeAll()
            self.pendingMusts.removeAll()
            let flushState = Self.signposter.beginInterval("deferred_flush_apply")
            await flush(statuses, musts)
            Self.signposter.endInterval("deferred_flush_apply", flushState)
        }
    }
}

private struct ActionSheetID: Identifiable, Hashable {
    let id: UUID
}

private struct ChunkActionAddSheetID: Identifiable, Hashable {
    let id: UUID
}

private struct RearrangeActionsSheetPayload: Identifiable, Hashable {
    let id: UUID
    let items: [RearrangeActionsSheet.Item]
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
            leverageContent
        }
    }

    private var leverageContent: some View {
        List {
            introSection
            resourcesSection
        }
        .navigationTitle("Assign")
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
            ToolbarItemGroup(placement: .keyboard) {
                if isNewResourceMode && isNewResourceFocused {
                    Spacer(minLength: 0)
                    Button {
                        if trimmedInlineResourceValue.isEmpty {
                            isNewResourceFocused = false
                        } else {
                            commitInlineResource()
                        }
                    } label: {
                        Image(systemName: trimmedInlineResourceValue.isEmpty ? "keyboard.chevron.compact.down" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(trimmedInlineResourceValue.isEmpty ? Color.primary.opacity(0.85) : Color.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    trimmedInlineResourceValue.isEmpty
                                        ? Color(.secondarySystemBackground)
                                        : Color.blue
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(trimmedInlineResourceValue.isEmpty ? 0.08 : 0),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .onAppear { localSelection = selectedResourceId }
        .onChange(of: isNewResourceFocused) { _, isFocused in
            guard !isFocused else { return }
            guard trimmedInlineResourceValue.isEmpty else { return }
            isNewResourceMode = false
            value = ""
        }
    }

    private var introSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text("Assign action to someone or something else")
                Text("NOTE: Does not alert who you assign to, for personal tracking only to hold people accountable.")
            }
            .font(.subheadline)
            .foregroundStyle(.secondary)
        }
    }

    private var resourcesSection: some View {
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

    private var trimmedInlineResourceValue: String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitInlineResource() {
        guard isNewResourceMode, !trimmedInlineResourceValue.isEmpty else { return }
        onAdd(kind, trimmedInlineResourceValue)
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
                sensitivityContent(proxy: proxy)
            }
        }
    }

    private func sensitivityContent(proxy: ScrollViewProxy) -> some View {
        List {
            timeOfDaySection

            if dueDateEditor != nil {
                dueDateSection
                    .id(dueDateScrollAnchorID)
            }

            placesSection
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
            ToolbarItemGroup(placement: .keyboard) {
                if isNewPlaceMode && isNewPlaceFocused {
                    Spacer(minLength: 0)
                    Button {
                        if trimmedInlinePlaceValue.isEmpty {
                            isNewPlaceFocused = false
                        } else {
                            commitInlinePlace()
                        }
                    } label: {
                        Image(systemName: trimmedInlinePlaceValue.isEmpty ? "keyboard.chevron.compact.down" : "checkmark")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(trimmedInlinePlaceValue.isEmpty ? Color.primary.opacity(0.85) : Color.white)
                            .frame(width: 30, height: 30)
                            .background(
                                Circle().fill(
                                    trimmedInlinePlaceValue.isEmpty
                                        ? Color(.secondarySystemBackground)
                                        : Color.blue
                                )
                            )
                            .overlay(
                                Circle()
                                    .stroke(
                                        Color.black.opacity(trimmedInlinePlaceValue.isEmpty ? 0.08 : 0),
                                        lineWidth: 1
                                    )
                            )
                    }
                    .buttonStyle(.plain)
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
        .onChange(of: isNewPlaceFocused) { _, isFocused in
            guard !isFocused else { return }
            guard trimmedInlinePlaceValue.isEmpty else { return }
            isNewPlaceMode = false
            newPlace = ""
        }
        .onDisappear {
            normalizeTimeOfDayIfNoneSelected()
        }
        .overlay(alignment: .bottom) {
            if showLeverageDueDateError && !localHasDueDate {
                VStack(alignment: .leading, spacing: 6) {
                    Text("You must add a due date to assign this action so resources stay accountable")
                        .font(.footnote)
                        .fontWeight(.bold)
                    Text("If not completed in this action plan, the Resource and due date will be saved to your Capture list and future Action Plans.")
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

    private var timeOfDaySection: some View {
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
    }

    private var dueDateSection: some View {
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
                    Text("Reminder")
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

                Text("Reminder starts the countdown before the due date and brings it into view at the right time.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
    }

    private var placesSection: some View {
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

    private var trimmedInlinePlaceValue: String {
        newPlace.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func commitInlinePlace() {
        guard isNewPlaceMode, !trimmedInlinePlaceValue.isEmpty else { return }
        onAddPlaceToCatalog(trimmedInlinePlaceValue)
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
    private enum AttachmentImportKind {
        case file
        case photo
    }

    #if canImport(UIKit)
    private struct FileAttachmentCardPreview {
        let thumbnail: UIImage?
        let tint: Color
    }
    #endif

    private struct AttachmentPreviewTarget: Identifiable {
        enum Kind {
            case link(String)
            case image(URL)
            case file(URL)
            case unavailable(String)
        }

        let id = UUID()
        let title: String
        let kind: Kind
        var stopAccess: (() -> Void)? = nil
    }

    let attachments: [PlannedChunkActionAttachment]
    let initialNoteText: String
    let onSaveNote: (String) -> Void
    let onAddLink: (String) -> Void
    let onAddFile: (URL, Data, String) -> Void
    let onDeleteAttachment: (UUID) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var linkText: String = ""
    @State private var isNewLinkMode: Bool = false
    @FocusState private var isNoteFocused: Bool
    @FocusState private var isNewLinkFocused: Bool
    @State private var isAttachmentOptionsPresented: Bool = false
    @State private var isFileImporterPresented: Bool = false
    @State private var attachmentImportKind: AttachmentImportKind = .file
    #if canImport(PhotosUI)
    @State private var isPhotoPickerPresented: Bool = false
    @State private var selectedPhotoItem: PhotosPickerItem? = nil
    #endif
    @State private var noteText: String = ""
    @State private var hasSavedNote: Bool = false
    @State private var previewTarget: AttachmentPreviewTarget? = nil
    @ObservedObject private var previewStore = LoomLinkPreviewStore.shared
    #if canImport(UIKit)
    @State private var fileAttachmentCardPreviews: [UUID: FileAttachmentCardPreview] = [:]
    #endif

    var body: some View {
        NavigationStack {
            List {
                Section("Notes") {
                    VStack(alignment: .leading, spacing: 12) {
                        TextEditor(text: $noteText)
                            .focused($isNoteFocused)
                            .frame(height: 120)

                        if isNewLinkMode {
                            HStack(spacing: 10) {
                                TextField("Add link…", text: $linkText)
                                    .focused($isNewLinkFocused)
                                    .submitLabel(.done)
                                    .onSubmit {
                                        commitInlineLink()
                                    }
                                Spacer()
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            }
                        }

                        if !linkAttachments.isEmpty || !fileAttachments.isEmpty {
                            VStack(spacing: 10) {
                                ForEach(linkAttachments) { attachment in
                                    attachmentCard(
                                        for: attachment,
                                        content: {
                                            LoomLinkBannerCard(
                                                urlString: attachment.urlString ?? "",
                                                preview: previewStore.preview(for: attachment.urlString)
                                            )
                                        }
                                    )
                                }

                                ForEach(fileAttachments) { attachment in
                                    attachmentCard(
                                        for: attachment,
                                        content: {
                                            fileAttachmentCard(for: attachment)
                                        }
                                    )
                                }
                            }
                        }

                        Button {
                            isAttachmentOptionsPresented = true
                        } label: {
                            HStack(spacing: 10) {
                                Text("Add Attachment")
                                    .fontWeight(.semibold)
                                    .foregroundStyle(.blue)
                                Spacer()
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(.vertical, 2)
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
                        let imported = try importAttachmentFile(from: url)
                        let bookmark = try imported.bookmarkData(
                            options: .minimalBookmark,
                            includingResourceValuesForKeys: nil,
                            relativeTo: nil
                        )
                        onAddFile(imported, bookmark, imported.lastPathComponent)
                    } catch { }
                case .failure:
                    break
                }
            }
            #if canImport(PhotosUI)
            .photosPicker(
                isPresented: $isPhotoPickerPresented,
                selection: $selectedPhotoItem,
                matching: .images,
                preferredItemEncoding: .current
            )
            .onChange(of: selectedPhotoItem) { _, item in
                guard let item else { return }
                Task {
                    await importSelectedPhoto(item)
                    await MainActor.run {
                        selectedPhotoItem = nil
                    }
                }
            }
            #endif
            .confirmationDialog("", isPresented: $isAttachmentOptionsPresented, titleVisibility: .hidden) {
                Button("Link") {
                    isNewLinkMode = true
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                        isNewLinkFocused = true
                    }
                }
                Button("File") {
                    attachmentImportKind = .file
                    isFileImporterPresented = true
                }
                Button("Photo") {
                    #if canImport(PhotosUI)
                    isPhotoPickerPresented = true
                    #else
                    attachmentImportKind = .file
                    isFileImporterPresented = true
                    #endif
                }
                Button("Cancel", role: .cancel) {}
            }
            .navigationTitle("Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        commitNoteIfNeeded()
                        commitInlineLink()
                        dismiss()
                    }
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isNoteFocused {
                        Spacer(minLength: 0)
                        keyboardAccessoryButton(
                            showsCheckmark: !trimmedNoteText.isEmpty,
                            action: {
                                if trimmedNoteText.isEmpty {
                                    isNoteFocused = false
                                } else {
                                    isNoteFocused = false
                                    commitNoteIfNeeded()
                                    dismiss()
                                }
                            }
                        )
                    } else if isNewLinkMode && isNewLinkFocused {
                        Spacer(minLength: 0)
                        keyboardAccessoryButton(
                            showsCheckmark: !trimmedInlineLinkValue.isEmpty,
                            action: {
                                if trimmedInlineLinkValue.isEmpty {
                                    isNewLinkFocused = false
                                } else {
                                    commitInlineLink()
                                }
                            }
                        )
                    }
                }
            }
            .onAppear {
                noteText = initialNoteText
                hasSavedNote = false
                previewStore.load(urlStrings: linkAttachments.compactMap(\.urlString))
                #if canImport(UIKit)
                preloadFileAttachmentCards(for: fileAttachments)
                #endif
            }
            .onChange(of: isNewLinkFocused) { _, isFocused in
                guard !isFocused else { return }
                guard trimmedInlineLinkValue.isEmpty else { return }
                isNewLinkMode = false
                linkText = ""
            }
            .onChange(of: linkAttachmentURLs) { _, urls in
                previewStore.load(urlStrings: urls)
            }
            #if canImport(UIKit)
            .onChange(of: fileAttachments.map(\.id)) { _, _ in
                preloadFileAttachmentCards(for: fileAttachments)
            }
            #endif
            .onDisappear {
                commitNoteIfNeeded()
            }
        }
        .sheet(item: $previewTarget, onDismiss: clearPreviewTarget) { preview in
            switch preview.kind {
            case .link(let urlString):
                LoomLinkAttachmentPreviewSheet(urlString: urlString)
            case .image(let url):
                #if canImport(UIKit)
                LoomImageAttachmentPreviewSheet(url: url)
                    .onDisappear {
                        preview.stopAccess?()
                    }
                #else
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: "Preview is not available on this device."
                )
                .onDisappear {
                    preview.stopAccess?()
                }
                #endif
            case .file(let url):
                #if canImport(PDFKit) && canImport(UIKit)
                if url.pathExtension.lowercased() == "pdf" {
                    LoomPDFPreviewSheet(url: url, title: preview.title)
                        .onDisappear {
                            preview.stopAccess?()
                        }
                } else {
                    #if canImport(QuickLook)
                    LoomQuickLookPreviewSheet(url: url)
                        .onDisappear {
                            preview.stopAccess?()
                        }
                    #else
                    LoomAttachmentUnavailableSheet(
                        title: preview.title,
                        message: "Preview is not available on this device."
                    )
                    .onDisappear {
                        preview.stopAccess?()
                    }
                    #endif
                }
                #elseif canImport(QuickLook) && canImport(UIKit)
                LoomQuickLookPreviewSheet(url: url)
                    .onDisappear {
                        preview.stopAccess?()
                    }
                #else
                LoomAttachmentUnavailableSheet(
                    title: preview.title,
                    message: "Preview is not available on this device."
                )
                .onDisappear {
                    preview.stopAccess?()
                }
                #endif
            case .unavailable(let message):
                LoomAttachmentUnavailableSheet(title: preview.title, message: message)
            }
        }
    }

    private func commitNoteIfNeeded() {
        guard !hasSavedNote else { return }
        hasSavedNote = true
        onSaveNote(noteText)
    }

    private func commitInlineLink() {
        guard isNewLinkMode, !trimmedInlineLinkValue.isEmpty else { return }
        onAddLink(trimmedInlineLinkValue)
        linkText = ""
        isNewLinkMode = false
        isNewLinkFocused = false
    }

    private var trimmedNoteText: String {
        noteText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var trimmedInlineLinkValue: String {
        linkText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var linkAttachments: [PlannedChunkActionAttachment] {
        attachments.filter { $0.kind == .link }
    }

    private var fileAttachments: [PlannedChunkActionAttachment] {
        attachments.filter { $0.kind == .file }
    }

    private var linkAttachmentURLs: [String] {
        linkAttachments.compactMap(\.urlString)
    }

    @ViewBuilder
    private func attachmentCard<Content: View>(
        for attachment: PlannedChunkActionAttachment,
        @ViewBuilder content: () -> Content
    ) -> some View {
        ZStack(alignment: .topTrailing) {
            Button {
                previewTarget = previewTarget(for: attachment)
            } label: {
                content()
            }
            .buttonStyle(.plain)

            Button(role: .destructive) {
                onDeleteAttachment(attachment.id)
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundStyle(Color.white)
                    .frame(width: 28, height: 28)
                    .background(Circle().fill(Color.black.opacity(0.58)))
            }
            .buttonStyle(.plain)
            .contentShape(Rectangle())
            .padding(8)
        }
    }

    private func keyboardAccessoryButton(
        showsCheckmark: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Image(systemName: showsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(
                    showsCheckmark
                        ? Color.white
                        : Color.primary.opacity(0.85)
                )
                .frame(width: 30, height: 30)
                .background(
                    Circle().fill(
                        showsCheckmark
                            ? Color.blue
                            : Color(.secondarySystemBackground)
                    )
                )
                .overlay(
                    Circle()
                        .stroke(
                            showsCheckmark
                                ? Color.blue.opacity(0.9)
                                : Color.black.opacity(0.08),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func fileAttachmentCard(for attachment: PlannedChunkActionAttachment) -> some View {
        #if canImport(UIKit)
        let cachedPreview = fileAttachmentCardPreviews[attachment.id]
        LoomFileBannerCard(
            title: fileDisplayTitle(for: attachment),
            subtitle: fileSubtitle(for: attachment),
            tint: fileTint(for: attachment, cachedPreview: cachedPreview),
            systemName: fileIconName(for: attachment),
            thumbnail: cachedPreview?.thumbnail
        )
        #else
        LoomFileBannerCard(
            title: fileDisplayTitle(for: attachment),
            subtitle: fileSubtitle(for: attachment),
            tint: fileTint(for: attachment),
            systemName: fileIconName(for: attachment)
        )
        #endif
    }

    private func fileDisplayTitle(for attachment: PlannedChunkActionAttachment) -> String {
        if let fileName = attachment.fileName?.trimmingCharacters(in: .whitespacesAndNewlines), !fileName.isEmpty {
            return fileName
        }
        if let resolved = resolvedAttachmentFileURL(attachment, startAccess: true) {
            defer { resolved.stopAccess?() }
            let name = resolved.url.lastPathComponent.trimmingCharacters(in: .whitespacesAndNewlines)
            if !name.isEmpty {
                return name
            }
        }
        return "Attachment"
    }

    private func fileSubtitle(for attachment: PlannedChunkActionAttachment) -> String {
        if attachmentIsImageFile(attachment.fileName) {
            return "Photo"
        }
        let ext = fileExtension(for: attachment)
        if ext.isEmpty { return "Attached file" }
        return ext.uppercased() + " file"
    }

    private func fileIconName(for attachment: PlannedChunkActionAttachment) -> String {
        let ext = fileExtension(for: attachment)
        switch ext {
        case "pdf":
            return "doc.richtext"
        case "png", "jpg", "jpeg", "heic", "gif", "webp":
            return "photo"
        case "mov", "mp4", "m4v":
            return "film"
        case "zip":
            return "archivebox"
        default:
            return "doc"
        }
    }

    private func fileTint(
        for attachment: PlannedChunkActionAttachment,
        cachedPreview: FileAttachmentCardPreview? = nil
    ) -> Color {
        #if canImport(UIKit)
        if let cachedPreview {
            return cachedPreview.tint
        }
        #endif
        let ext = fileExtension(for: attachment)
        switch ext {
        case "pdf":
            return .red
        case "png", "jpg", "jpeg", "heic", "gif", "webp":
            return .blue
        case "mov", "mp4", "m4v":
            return .purple
        case "zip":
            return .orange
        default:
            return Color(.secondaryLabel)
        }
    }

    private func previewTarget(for a: PlannedChunkActionAttachment) -> AttachmentPreviewTarget {
        switch a.kind {
        case .link:
            if let urlString = a.urlString?.trimmingCharacters(in: .whitespacesAndNewlines), !urlString.isEmpty {
                return AttachmentPreviewTarget(title: "Attachment", kind: .link(urlString))
            }
            return AttachmentPreviewTarget(title: a.fileName ?? "Attachment", kind: .unavailable("This link could not be opened."))
        case .file:
            guard let resolved = resolvedAttachmentFileURL(a, startAccess: true) else {
                return AttachmentPreviewTarget(title: a.fileName ?? "Attachment", kind: .unavailable("The selected file is no longer available."))
            }
            if attachmentIsImageFile(a) {
                return AttachmentPreviewTarget(
                    title: fileDisplayTitle(for: a),
                    kind: .image(resolved.url),
                    stopAccess: resolved.stopAccess
                )
            }
            return AttachmentPreviewTarget(
                title: fileDisplayTitle(for: a),
                kind: .file(resolved.url),
                stopAccess: resolved.stopAccess
            )
        case .note:
            return AttachmentPreviewTarget(title: "Attachment", kind: .unavailable("Preview is not available for notes."))
        }
    }

    private func resolvedAttachmentFileURL(
        _ attachment: PlannedChunkActionAttachment,
        startAccess: Bool
    ) -> (url: URL, stopAccess: (() -> Void)?)? {
        if let data = attachment.fileBookmarkData {
            var isStale = false
            if let url = try? URL(
                resolvingBookmarkData: data,
                options: [.withoutUI],
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) {
                guard startAccess else {
                    return (url, nil)
                }

                let didAccess = url.startAccessingSecurityScopedResource()
                let stopAccess = didAccess ? { url.stopAccessingSecurityScopedResource() } : nil
                return (url, stopAccess)
            }
        }

        if let localURL = resolvedAppOwnedAttachmentURL(for: attachment), FileManager.default.fileExists(atPath: localURL.path) {
            return (localURL, nil)
        }

        return nil
    }

    private func clearPreviewTarget() {
        previewTarget?.stopAccess?()
        previewTarget = nil
    }

    private func importAttachmentFile(from sourceURL: URL) throws -> URL {
        let startedAccess = sourceURL.startAccessingSecurityScopedResource()
        defer {
            if startedAccess {
                sourceURL.stopAccessingSecurityScopedResource()
            }
        }

        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let attachmentsDirectory = baseDirectory.appendingPathComponent("ActionAttachmentFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        let sanitizedFileName = sanitizedAttachmentFileName(sourceURL.lastPathComponent)
        let destinationURL = uniqueAttachmentDestinationURL(
            in: attachmentsDirectory,
            originalFileName: sanitizedFileName
        )

        if FileManager.default.fileExists(atPath: destinationURL.path) {
            try FileManager.default.removeItem(at: destinationURL)
        }
        try FileManager.default.copyItem(at: sourceURL, to: destinationURL)
        return destinationURL
    }

    private func resolvedAppOwnedAttachmentURL(for attachment: PlannedChunkActionAttachment) -> URL? {
        if let path = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
           !path.isEmpty,
           let url = appOwnedAttachmentURL(relativePath: path) {
            return url
        }
        if let fileName = attachment.fileName?.trimmingCharacters(in: .whitespacesAndNewlines),
           !fileName.isEmpty,
           let url = appOwnedAttachmentURL(relativePath: actionAttachmentRelativePath(for: fileName)) {
            return url
        }
        return nil
    }

    private func appOwnedAttachmentURL(relativePath: String) -> URL? {
        let trimmed = relativePath.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let components = trimmed.split(separator: "/").map(String.init)
        guard !components.isEmpty else { return nil }
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        var url = baseDirectory
        for component in components {
            url.appendPathComponent(component, isDirectory: false)
        }
        return url
    }

    #if canImport(PhotosUI)
    private func importSelectedPhoto(_ item: PhotosPickerItem) async {
        guard let data = try? await item.loadTransferable(type: Data.self),
              let imported = try? importAttachmentData(
                data,
                preferredFileName: preferredPhotoFileName(for: item)
              ),
              let bookmark = try? imported.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
              ) else {
            return
        }
        await MainActor.run {
            onAddFile(imported, bookmark, imported.lastPathComponent)
        }
    }

    private func preferredPhotoFileName(for item: PhotosPickerItem) -> String {
        let suggested = item.supportedContentTypes.first?.preferredFilenameExtension
        let ext = (suggested?.isEmpty == false ? suggested! : "jpg")
        return "Photo.\(ext)"
    }
    #endif

    private func importAttachmentData(_ data: Data, preferredFileName: String) throws -> URL {
        let baseDirectory = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let attachmentsDirectory = baseDirectory.appendingPathComponent("ActionAttachmentFiles", isDirectory: true)
        try FileManager.default.createDirectory(at: attachmentsDirectory, withIntermediateDirectories: true)

        let sanitizedFileName = sanitizedAttachmentFileName(preferredFileName)
        let destinationURL = uniqueAttachmentDestinationURL(
            in: attachmentsDirectory,
            originalFileName: sanitizedFileName
        )
        try data.write(to: destinationURL, options: .atomic)
        return destinationURL
    }

    private func uniqueAttachmentDestinationURL(in directory: URL, originalFileName: String) -> URL {
        let ext = (originalFileName as NSString).pathExtension
        let baseName = ((originalFileName as NSString).deletingPathExtension).nilIfEmpty ?? "Attachment"
        let suffix = UUID().uuidString.prefix(8)
        let finalName = ext.isEmpty ? "\(baseName)-\(suffix)" : "\(baseName)-\(suffix).\(ext)"
        return directory.appendingPathComponent(finalName, isDirectory: false)
    }

    private func sanitizedAttachmentFileName(_ value: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Attachment" }
        let invalid = CharacterSet(charactersIn: "/:\\?%*|\"<>")
        let components = trimmed.components(separatedBy: invalid)
        let sanitized = components.joined(separator: "-").nilIfEmpty ?? "Attachment"
        return sanitized
    }

    private func attachmentIsImageFile(_ fileName: String?) -> Bool {
        let ext = ((fileName as NSString?)?.pathExtension ?? "").lowercased()
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"]
        return imageExtensions.contains(ext)
    }

    private func attachmentIsImageFile(_ attachment: PlannedChunkActionAttachment) -> Bool {
        let imageExtensions: Set<String> = ["jpg", "jpeg", "png", "gif", "heic", "heif", "webp", "bmp", "tif", "tiff"]
        return imageExtensions.contains(fileExtension(for: attachment))
    }

    private func fileExtension(for attachment: PlannedChunkActionAttachment) -> String {
        let direct = ((attachment.fileName as NSString?)?.pathExtension ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        if !direct.isEmpty {
            return direct
        }
        if let resolved = resolvedAttachmentFileURL(attachment, startAccess: true) {
            defer { resolved.stopAccess?() }
            return resolved.url.pathExtension.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        }
        return ""
    }

    #if canImport(UIKit)
    private func fileThumbnail(for attachment: PlannedChunkActionAttachment) -> UIImage? {
        guard attachmentIsImageFile(attachment),
              let resolved = resolvedAttachmentFileURL(attachment, startAccess: true) else { return nil }
        defer { resolved.stopAccess?() }
        return UIImage(contentsOfFile: resolved.url.path)
    }

    private func preloadFileAttachmentCards(for attachments: [PlannedChunkActionAttachment]) {
        let liveIDs = Set(attachments.map(\.id))
        fileAttachmentCardPreviews = fileAttachmentCardPreviews.filter { liveIDs.contains($0.key) }

        let uncached = attachments.filter { fileAttachmentCardPreviews[$0.id] == nil }
        guard !uncached.isEmpty else { return }

        for attachment in uncached {
            let preview = makeFileAttachmentCardPreview(for: attachment)
            fileAttachmentCardPreviews[attachment.id] = preview
        }
    }

    private func makeFileAttachmentCardPreview(for attachment: PlannedChunkActionAttachment) -> FileAttachmentCardPreview {
        if attachmentIsImageFile(attachment),
           let thumbnail = fileThumbnail(for: attachment) {
            let tint = dominantColor(from: thumbnail).map(Color.init) ?? .blue
            return FileAttachmentCardPreview(thumbnail: thumbnail, tint: tint)
        }

        return FileAttachmentCardPreview(
            thumbnail: nil,
            tint: fileTint(for: attachment, cachedPreview: nil)
        )
    }

    private func dominantColor(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard !extent.isEmpty,
              let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [
                    kCIInputImageKey: ciImage,
                    kCIInputExtentKey: CIVector(cgRect: extent)
                ]
              ),
              let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
    #endif
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}

private struct ActionSwipeRow: View {
    let actionId: UUID
    let text: String
    let dueStatusText: String?
    let dueStatusColor: Color
    let status: ActionExecutionStatus
    let accent: Color
    let isOtherChunk: Bool
    let colorScheme: ColorScheme
    let isMust: Bool
    let minutes: Int?
    let hasLeverage: Bool
    let leverageIconName: String
    let hasSensitivity: Bool
    let hasAttachments: Bool
    let highlightStatusBox: Bool
    let showsReorderHandle: Bool
    let simpleMode: Bool
    let simpleModeFillColor: Color
    let onTapText: () -> Void
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
        isOtherChunk: Bool,
        colorScheme: ColorScheme,
        isMust: Bool,
        minutes: Int?,
        hasLeverage: Bool,
        leverageIconName: String,
        hasSensitivity: Bool,
        hasAttachments: Bool,
        highlightStatusBox: Bool,
        showsReorderHandle: Bool,
        simpleMode: Bool,
        simpleModeFillColor: Color,
        onTapText: @escaping () -> Void,
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
        self.isOtherChunk = isOtherChunk
        self.colorScheme = colorScheme
        self.isMust = isMust
        self.minutes = minutes
        self.hasLeverage = hasLeverage
        self.leverageIconName = leverageIconName
        self.hasSensitivity = hasSensitivity
        self.hasAttachments = hasAttachments
        self.highlightStatusBox = highlightStatusBox
        self.showsReorderHandle = showsReorderHandle
        self.simpleMode = simpleMode
        self.simpleModeFillColor = simpleModeFillColor
        self.onTapText = onTapText
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

    private var rowBorderAccent: Color {
        accent
    }

    private var usesOtherDarkIconTint: Bool {
        isOtherChunk && colorScheme == .dark
    }

    private var iconAccent: Color {
        usesOtherDarkIconTint ? .white : accent
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
        let baseColor: Color = usesOtherDarkIconTint ? .white : .black
        switch effectiveStatus {
        case .leveraged:
            return baseColor.opacity(0.45)
        case .done, .carriedToCapture, .notNeeded:
            return baseColor.opacity(0.25)
        case .inProgress:
            return iconAccent
        case .noAction:
            return usesOtherDarkIconTint ? .white : .black
        }
    }

    private var iconTint: Color {
        isInactive ? inactiveTint : iconAccent
    }

    private var actionTextColor: Color {
        // Simple View should retain the existing darker text treatment in dark mode.
        if simpleMode {
            if isOtherChunk {
                switch effectiveStatus {
                case .leveraged:
                    return Color.black.opacity(0.45)
                case .done, .carriedToCapture, .notNeeded:
                    return Color.black.opacity(0.25)
                case .inProgress:
                    return accent
                case .noAction:
                    return .black
                }
            }
            return inactiveTint
        }
        guard colorScheme == .dark else { return inactiveTint }
        return isInactive ? Color.white.opacity(0.72) : Color.white
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
                if !simpleMode, let dueStatusText {
                    Text(dueStatusText)
                        .font(.caption)
                        .foregroundStyle(dueStatusColor)
                }
                Text(text)
                    .font(actionFont(status: effectiveStatus))
                    .foregroundStyle(actionTextColor)
                    .strikethrough(
                        effectiveStatus == .done || effectiveStatus == .carriedToCapture || effectiveStatus == .notNeeded,
                        color: actionTextColor
                    )
                    .lineLimit(3)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .onTapGesture(perform: onTapText)

                if !simpleMode {
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
                            tint: isInactive ? inactiveTint : (usesOtherDarkIconTint ? .white : rowAccent),
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
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if showsReorderHandle && !simpleMode {
                Image(systemName: "chevron.up.chevron.down")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color(.systemGray))
                    .frame(width: 22, alignment: .center)
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(simpleMode ? simpleModeFillColor : Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    simpleMode
                        ? Color.clear
                        : (effectiveStatus == .inProgress ? rowBorderAccent : Color.black.opacity(0.12)),
                    lineWidth: simpleMode
                        ? 0
                        : (effectiveStatus == .inProgress ? 3 : 1)
                )
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
            return "Assigned"
        case .inProgress:
            return "In progress"
        case .done:
            return "Done"
        case .carriedToCapture:
            return "Recapture for later"
        case .notNeeded:
            return "Wasn't needed to acheive result (Delete)"
        }
    }
}

#Preview {
    NavigationStack { ActionView() }
}
