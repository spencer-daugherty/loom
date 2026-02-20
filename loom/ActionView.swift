import SwiftUI
import SwiftData
import UniformTypeIdentifiers
#if canImport(UIKit)
import UIKit
#endif

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
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var captureItems: [RollingCaptureItem]
    @Query(sort: \ActivePlanState.id, order: .forward)
    private var activePlanStates: [ActivePlanState]

    @State private var isShowingInstructions: Bool = false
    @State private var openFilter: FilterMenu? = nil
    @State private var selectedPlaceIDs: Set<UUID> = []
    @State private var selectedPersonIDs: Set<UUID> = []
    @State private var selectedToolIDs: Set<UUID> = []
    @State private var selectedTimeOfDay: Set<TimeOfDayChoice> = []
    @State private var selectedDurations: Set<Int> = []
    @State private var selectedAttachmentKinds: Set<ActionAttachmentFilterKind> = []
    @State private var onlyMusts: Bool = false

    @State private var activeOnly: Bool = false
    @State private var leveragedOnly: Bool = false
    @State private var inProgressOnly: Bool = false

    @State private var durationActionID: ActionSheetID? = nil
    @State private var leverageActionID: ActionSheetID? = nil
    @State private var sensitivityActionID: ActionSheetID? = nil
    @State private var attachmentsActionID: ActionSheetID? = nil
    @State private var actionStatusActionID: ActionSheetID? = nil
    @State private var showCheckmarkLimitAlert: Bool = false
    @State private var autosaveTask: Task<Void, Never>? = nil
    @State private var isHeaderCollapsed: Bool = false
    @State private var lastScrollY: CGFloat = 0
    @State private var lastScrollTimestamp: TimeInterval = Date().timeIntervalSinceReferenceDate
    @State private var isKeyboardVisible: Bool = false
    @State private var keyboardHeight: CGFloat = 0
    @State private var focusedActionID: UUID? = nil
    @State private var scrollTargetActionID: UUID? = nil
    @State private var pendingChunkScrollAnchor: String? = nil
    @State private var pendingFocusActionID: UUID? = nil
    @State private var pendingNewActionIDs: Set<UUID> = []
    @State private var pendingDurationDefaultActionID: UUID? = nil
    @State private var addActionChunkID: ChunkActionAddSheetID? = nil
    @State private var highlightedStatusActionIDs: Set<UUID> = []
    @State private var showCompleteHint: Bool = false
    @State private var showReflectionFlow: Bool = false
    @State private var dismissActionViewAfterReflect: Bool = false
    @State private var deferredPersistor = ActionDeferredPersistor()
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

    private var weekChunks: [PlannedChunk] {
        allChunks
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
    private var showActiveOnlyFilterButton: Bool { !weekActions.isEmpty || activeOnly }
    private var showLeveragedOnlyFilterButton: Bool { !weekActions.isEmpty || leveragedOnly }
    private var showInProgressOnlyFilterButton: Bool { !weekActions.isEmpty || inProgressOnly }

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
            if st?.sensitiveMorning ?? true { options.insert(.morning) }
            if st?.sensitiveAfternoon ?? true { options.insert(.afternoon) }
            if st?.sensitiveEvening ?? true { options.insert(.evening) }
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
    private var hasMustsFilterButton: Bool { !weekActions.isEmpty || onlyMusts }
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
                            ForEach(weekChunks) { chunk in
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
                        }
                    }
                    }
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
        .sheet(isPresented: $isShowingInstructions) {
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
            .presentationDetents([.medium, .large])
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
                    for it in leverageCatalog where ids.contains(it.id) {
                        for sel in leverageSelections where sel.resourceId == it.id {
                            sel.resourceId = nil
                            sel.updatedAt = .now
                        }
                        RecentlyDeletedStore.trash(it, in: modelContext)
                    }
                    scheduleAutosave()
                },
                onSelectResource: { resourceID in
                    upsertLeverageSelection(forActionId: wrapper.id) { sel in
                        sel.resourceId = resourceID
                        sel.updatedAt = .now
                    }
                    scheduleAutosave()
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $sensitivityActionID) { wrapper in
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
                }
            )
            .presentationDetents([.medium, .large])
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
            ActionStatusPickerSheet(
                current: status(for: wrapper.id),
                onSelect: { status in
                    setStatus(for: wrapper.id, to: status)
                }
            )
            .presentationDetents([.height(380)])
            .presentationDragIndicator(.visible)
        }
        .alert("Only 3 In Progress actions are allowed.", isPresented: $showCheckmarkLimitAlert) {
            Button("OK", role: .cancel) { }
        }
        .onAppear {
            ensureStateRowsExistForWeek()
            cleanupAllBlankActions()
            deactivatePlanIfNoActionBlocks()
        }
        .onChange(of: weekChunks.map(\.id)) { _, _ in
            deactivatePlanIfNoActionBlocks()
        }
        .onChange(of: weekActions.map(\.id)) { _, ids in
            ensureStateRowsExistForWeek()
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
                if let age = blocksAgeDays, age >= 8 {
                    cautionRow
                }
                filterChipsRow
                if let openFilter, isFilterMenuAvailable(openFilter) {
                    filterDropdown(for: openFilter)
                }
            }
        }
        .padding(.bottom, 6)
    }

    private var instructionsRow: some View {
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

    private var cautionRow: some View {
        HStack(alignment: .top, spacing: 8) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 4) {
                (
                    Text("Caution: ").fontWeight(.bold)
                    + Text("Action Blocks created \(blocksAgeDays ?? 0) days ago. Mark uncompleted actions ")
                    + Text(Image(systemName: "arrow.right"))
                    + Text(" to a new capture list and start a new plan to keep it fresh.")
                )
                .font(.subheadline)
                .foregroundStyle(.secondary)

                if hasUncompletedActions {
                    Button("Click here") {
                        markAllUncompletedAsRecapture()
                    }
                    .buttonStyle(.plain)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color.yellow.opacity(colorScheme == .dark ? 0.22 : 0.28))
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
        // Keep chip layout stable to avoid heavy visibility recomputation while toggling quickly.
        let selected = defaultFilterChipOrder.filter { isFilterChipSelected($0) }
        let nonSelected = defaultFilterChipOrder.filter { !isFilterChipSelected($0) }
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
        case .activeOnly: return showActiveOnlyFilterButton
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

    private func isFilterChipSelected(_ chip: FilterChipKind) -> Bool {
        switch chip {
        case .activeOnly: return activeOnly
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
                title: "Active Only",
                iconName: "line.3.horizontal.decrease.circle",
                isActive: activeOnly,
                showsChevron: false
            ) {
                activeOnly.toggle()
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

        return VStack(alignment: .leading, spacing: 10) {
            if filtered.isEmpty {
                Text("Block has no applicable actions")
                    .font(.subheadline)
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.6))
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
            } else {
                resultSection(resultText: step4?.resultText ?? "")

                if !outcomesForChunk.isEmpty {
                    ForEach(outcomesForChunk, id: \.outcome_id) { outcome in
                        outcomePill(outcome)
                    }
                }

                Divider().opacity(0.4)

                purposeSection(roleName: roleName, purposeText: step4?.roleNoteText ?? "")

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

                    LazyVStack(spacing: 8) {
                        ForEach(filtered) { action in
                            let defineState = defineByAction[action.id]
                            let status = executionByAction[action.id]?.status ?? .noAction
                            let selectedResource = resourcesByAction[action.id].flatMap { resourceByID[$0] }
                            let hasLeverage = selectedResource != nil
                            let leverageIconName = {
                                guard let selectedResource else { return "person" }
                                return selectedResource.kind == .tool ? "wrench.and.screwdriver.fill" : "person.fill"
                            }()
                            let placeIDs = placesByAction[action.id] ?? []
                            let hasSensitivity = hasAnySensitivity(defineState: defineState, placeIDs: placeIDs)
                            let hasAttachments = hasAnyAttachments(
                                note: notesByAction[action.id],
                                attachments: attachmentsByAction[action.id] ?? []
                            )

                            actionRow(
                                action: action,
                                accent: accent,
                                defineState: defineState,
                                status: status,
                                hasLeverage: hasLeverage,
                                leverageIconName: leverageIconName,
                                hasSensitivity: hasSensitivity,
                                hasAttachments: hasAttachments,
                                highlightStatusBox: highlightedStatusActionIDs.contains(action.id)
                            )
                            .id(action.id)
                        }
                    }

                    let isFilterApplied = isAnyFilterApplied
                    let useFilterTotalsLabel = isFilterApplied && !isOnlyActiveOnlyFilterApplied
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
                        if !isAnyFilterApplied || isOnlyActiveOnlyFilterApplied {
                            addActionButton(for: chunk)
                        }

                        Spacer(minLength: 8)

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
        .padding(12)
        .background(fill, in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12), lineWidth: 1)
        )
    }

    private func resultSection(resultText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("What do I want?")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.58))
            }

            Text(resultText.isEmpty ? "-" : resultText)
                .font(.subheadline)
                .foregroundColor(resultText.isEmpty ? .secondary : .black)
        }
    }

    private func purposeSection(roleName: String, purposeText: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("Why do I want it?")
                    .font(.footnote)
                    .italic()
                    .foregroundStyle(Color.black.opacity(0.58))
            }

            if !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                smallPill(icon: "trophy", text: roleName)
            }

            Text(purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : purposeText)
                .font(.subheadline)
                .foregroundColor(purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? .secondary : .black)
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
        highlightStatusBox: Bool
    ) -> some View {
        ActionSwipeRow(
            actionId: action.id,
            text: action.text,
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

    private var availableCaptureActions: [RollingCaptureItem] {
        captureItems.filter {
            !$0.isGhost && !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
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

            var matchesAny = false
            if selectedTimeOfDay.contains(.morning) && hasMorning { matchesAny = true }
            if selectedTimeOfDay.contains(.afternoon) && hasAfternoon { matchesAny = true }
            if selectedTimeOfDay.contains(.evening) && hasEvening { matchesAny = true }
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

        if !excludedFacets.contains(.activeOnly) && activeOnly {
            if !(status == .noAction || status == .leveraged || status == .inProgress) { return false }
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
        activeOnly ||
        leveragedOnly ||
        inProgressOnly ||
        !selectedPlaceIDs.isEmpty ||
        !selectedPersonIDs.isEmpty ||
        !selectedToolIDs.isEmpty ||
        !selectedTimeOfDay.isEmpty ||
        !selectedDurations.isEmpty ||
        !selectedAttachmentKinds.isEmpty
    }

    private var isOnlyActiveOnlyFilterApplied: Bool {
        activeOnly &&
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

    private func hasAnySensitivity(defineState st: PlannedChunkActionDefineState?, placeIDs: Set<UUID>) -> Bool {
        let hasTimePrefs = !(st?.sensitiveMorning ?? true) || !(st?.sensitiveAfternoon ?? true) || !(st?.sensitiveEvening ?? true)
        let hasPlaces = !placeIDs.isEmpty
        return hasTimePrefs || hasPlaces
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
        activeOnly = false
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

private struct ActionScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

private enum TimeOfDayChoice: String, CaseIterable, Hashable {
    case morning
    case afternoon
    case evening

    var title: String {
        switch self {
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

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    motivationRow(
                        title: "Power Question",
                        subtitle: "What am I happy about in life right now?",
                        value: currentEntry?.morningPowerQuestion ?? ""
                    )
                    motivationRow(
                        title: "What am I grateful for?",
                        subtitle: nil,
                        value: currentEntry?.gratitude ?? ""
                    )
                    motivationRow(
                        title: "Incantation",
                        subtitle: "What’s a simple phrase to set your mindset?",
                        value: currentEntry?.incantation ?? ""
                    )
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
            Text(value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : value)
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

    @Environment(\.dismiss) private var dismiss
    @State private var newPlace: String = ""
    @State private var isNewPlaceMode: Bool = false
    @FocusState private var isNewPlaceFocused: Bool

    var body: some View {
        NavigationStack {
            List {
                Section("Time of Day") {
                    Toggle("Morning", isOn: bindingForTimeOfDay(\.sensitiveMorning))
                    Toggle("Afternoon", isOn: bindingForTimeOfDay(\.sensitiveAfternoon))
                    Toggle("Evening", isOn: bindingForTimeOfDay(\.sensitiveEvening))
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
                        dismiss()
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
                guard onCount >= 1 else { return }

                defineState[keyPath: keyPath] = newValue
            }
        )
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
    @Binding var focusedActionID: UUID?
    let onCommitText: (String) -> Void
    let onOpenStatus: () -> Void
    let onToggleMust: (Bool) -> Void
    let onOpenClock: () -> Void
    let onOpenLeverage: () -> Void
    let onOpenSensitivity: () -> Void
    let onOpenAttachments: () -> Void

    @State private var localStatus: ActionExecutionStatus
    @State private var localIsMust: Bool

    init(
        actionId: UUID,
        text: String,
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
        self._focusedActionID = focusedActionID
        self.onCommitText = onCommitText
        self.onOpenStatus = onOpenStatus
        self.onToggleMust = onToggleMust
        self.onOpenClock = onOpenClock
        self.onOpenLeverage = onOpenLeverage
        self.onOpenSensitivity = onOpenSensitivity
        self.onOpenAttachments = onOpenAttachments
        _localStatus = State(initialValue: status)
        _localIsMust = State(initialValue: isMust)
    }

    private var rowAccent: Color {
        minutes == nil ? Color(.systemGray) : accent
    }

    private var isSwipeInteracting: Bool { false }

    private var effectiveStatus: ActionExecutionStatus {
        localStatus
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

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Button {
                guard !isSwipeInteracting else { return }
                onOpenStatus()
            } label: {
                Group {
                    if effectiveStatus.icon.isEmpty {
                        Color.clear.frame(width: 14, height: 14)
                    } else {
                        Image(systemName: effectiveStatus.icon)
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
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(effectiveStatus == .inProgress ? rowAccent : Color.black.opacity(0.12), lineWidth: effectiveStatus == .inProgress ? 3 : 1)
        )
        .contentShape(Rectangle())
        .onChange(of: status) { _, newValue in
            localStatus = newValue
        }
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

private struct ActionStatusPickerSheet: View {
    let current: ActionExecutionStatus
    let onSelect: (ActionExecutionStatus) -> Void

    @Environment(\.dismiss) private var dismiss

    private let options: [ActionExecutionStatus] = [.noAction, .leveraged, .inProgress, .done, .carriedToCapture, .notNeeded]

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
                                if status.icon.isEmpty {
                                    Color.clear.frame(width: 18, height: 18)
                                } else {
                                    Image(systemName: status.icon)
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

private extension ActionExecutionStatus {
    var icon: String {
        switch self {
        case .noAction:
            return ""
        case .leveraged:
            return "circle"
        case .inProgress:
            return "checkmark"
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
