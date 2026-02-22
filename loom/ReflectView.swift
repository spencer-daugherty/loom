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
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomeMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var outcomeMeasureEntries: [OutcomesMeasureEntry]
    @Query private var allMindsetRows: [WeeklyMindsetEntry.Fields]
    @Query private var allAdHocMarkers: [PlannedChunkActionAdHocMarker]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse) private var captureItems: [RollingCaptureItem]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @AppStorage("capture_google_tasks_access_token") private var googleTasksAccessToken: String = ""
    @AppStorage("capture_microsoft_todo_access_token") private var microsoftTodoAccessToken: String = ""

    @State private var step: Int = 1
    @State private var showInstructions: Bool = false
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
    @State private var celebrationRadarSelectedIndex: Int = 0

    @Namespace private var reflectionNamespace

    private let palette: [Color] = [.blue, .indigo, .green, .purple, .red, .orange]

    private enum JournalField: Hashable {
        case achievements
        case magicMoments
        case powerQuestion
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
        weekActions.filter {
            if status(for: $0.id) == .leveraged { return true }
            guard let sel = leverageByActionID[$0.id], let resourceID = sel.resourceId else { return false }
            return resourceByID[resourceID] != nil
        }.count
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

    private var categoryBreakdown: [(String, Int)] {
        let grouped = Dictionary(grouping: weekActions, by: \.plannedChunkId)
        let pairs = grouped.compactMap { chunkID, actions -> (String, Int)? in
            guard let chunk = chunkByID[chunkID] else { return nil }
            return (chunk.category, actions.count)
        }
        let merged = Dictionary(grouping: pairs, by: { $0.0 }).mapValues { rows in rows.reduce(0) { $0 + $1.1 } }
        return merged.map { ($0.key, $0.value) }.sorted { $0.1 > $1.1 }
    }

    private var outcomesForWeek: [Outcomes] {
        let ids = Set(weekOutcomeLinks.map(\.outcomeId))
        return outcomes.filter { ids.contains($0.outcome_id) }
    }

    private var outcomesForContributionFlow: [Outcomes] {
        outcomesForWeek.filter { outcome in
            !(doneActionsByOutcomeId[outcome.outcome_id] ?? []).isEmpty
        }
    }

    private var doneActionsByOutcomeId: [UUID: [PlannedChunkAction]] {
        let linksByOutcome = Dictionary(grouping: weekOutcomeLinks, by: \.outcomeId)
        var map: [UUID: [PlannedChunkAction]] = [:]
        for (outcomeId, links) in linksByOutcome {
            let chunkIds = Set(links.map(\.plannedChunkId))
            let done = weekActions.filter {
                chunkIds.contains($0.plannedChunkId) && status(for: $0.id) == .done
            }
            map[outcomeId] = done
        }
        return map
    }

    private var currentContributionOutcome: Outcomes? {
        guard contributionOutcomeIndex >= 0, contributionOutcomeIndex < outcomesForContributionFlow.count else { return nil }
        return outcomesForContributionFlow[contributionOutcomeIndex]
    }

    private var currentContributionDoneActions: [PlannedChunkAction] {
        guard let outcome = currentContributionOutcome else { return [] }
        return doneActionsByOutcomeId[outcome.outcome_id] ?? []
    }

    private var productiveDayRows: [ProductiveDayRow] {
        let cal = Calendar.current
        let firstDay = cal.startOfDay(for: weekStart)
        let days: [Date] = (0..<7).compactMap { cal.date(byAdding: .day, value: $0, to: firstDay) }

        var doneByDay: [Date: Int] = [:]
        var mustByDay: [Date: Int] = [:]

        for action in weekActions {
            guard
                let execution = executionByActionID[action.id],
                closedStatuses.contains(execution.status)
            else { continue }

            let day = cal.startOfDay(for: execution.updatedAt)
            doneByDay[day, default: 0] += 1
            if defineByActionID[action.id]?.isMust == true {
                mustByDay[day, default: 0] += 1
            }
        }

        let formatter = DateFormatter()
        formatter.dateFormat = "E"

        return days.map { day in
            ProductiveDayRow(
                dayLabel: formatter.string(from: day),
                completed: doneByDay[day, default: 0],
                mustCompleted: mustByDay[day, default: 0]
            )
        }
    }

    private var weekMindsetRow: WeeklyMindsetEntry.Fields? {
        allMindsetRows.first
    }

    private var flowProfileRows: [(String, Int, Color)] {
        [
            ("Musts", mustCount, .yellow),
            ("Carried to new capture list", carriedActions.count, .blue),
            ("Didn't need to be done (Delete)", notNeededCount, .gray),
            ("Leveraged", leveragedCount, .mint),
            ("New ad hoc actions", adHocCount, .purple),
            ("Attachments", noteCount + linkCount + fileCount, .teal),
        ]
        .sorted { lhs, rhs in
            if lhs.1 == rhs.1 { return lhs.0 < rhs.0 }
            return lhs.1 > rhs.1
        }
    }

    private var journalIsValid: Bool {
        !achievementsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !magicMomentsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !powerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        ZStack {
            Color(.systemBackground).ignoresSafeArea()

            if showCelebration {
                celebrationView
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            } else {
                mainContent
                    .transition(.opacity)
            }
        }
        .sheet(isPresented: $showInstructions) {
            instructionsSheet
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $showContributionPrompt) {
            contributionPromptSheet
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
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
            DispatchQueue.main.asyncAfter(deadline: .now() + 2.6) {
                withAnimation(.easeInOut(duration: 0.35)) {
                    showCelebration = false
                }
            }
        }
    }

    private var mainContent: some View {
        VStack(spacing: 10) {
            Text(step == 1 ? "Insights" : "Journal")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            Button {
                showInstructions = true
            } label: {
                HStack(spacing: 8) {
                    Spacer(minLength: 0)
                    Image(systemName: "info.circle")
                        .foregroundStyle(.secondary)
                    Text("Instructions")
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    Text("Tap to read")
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .font(.subheadline)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if step == 1 {
                insightsStep
            } else {
                journalStep
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
    }

    private var celebrationView: some View {
        ZStack {
            GeometryReader { geo in
                let radarDiameter: CGFloat = 72
                let focusYFraction: CGFloat = 0.50
                let radarX: CGFloat = geo.size.width * 0.76
                let radarY: CGFloat = geo.size.height * focusYFraction

                WindLinesBackground(colors: palette)
                .ignoresSafeArea()

                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let pulse = loadingStylePulsedMetrics(at: t * 0.45)
                    ZStack {
                        FulfillmentInteractiveRadar(
                            metrics: pulse,
                            selectedIndex: $celebrationRadarSelectedIndex,
                            onManualSelect: {},
                            enableInteraction: false,
                            customDotDiameter: 10
                        )
                        .matchedGeometryEffect(id: "reflect-radar", in: reflectionNamespace)
                        .frame(width: radarDiameter, height: radarDiameter)
                        .rotationEffect(.degrees(t * 168.75))
                        .background(
                            Circle()
                                .fill(Color(.systemBackground))
                                .frame(width: radarDiameter + 18, height: radarDiameter + 18)
                        )
                        .position(x: radarX, y: radarY)

                        let titleColor: Color = colorScheme == .dark ? .white : .black
                        let titleBlockWidth: CGFloat = 206
                        let actionFont = UIFont.systemFont(ofSize: 28, weight: .bold)
                        let doneFont = UIFont.systemFont(ofSize: 50, weight: .black)
                        let actionWidth = ("Action Blocks" as NSString).size(withAttributes: [.font: actionFont]).width
                        let doneWidth = ("DONE!" as NSString).size(withAttributes: [.font: doneFont]).width
                        let doneScaleX = max(0.1, actionWidth / max(doneWidth, 1))

                        VStack(spacing: 0) {
                            Text("Action Blocks")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(titleColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                                .frame(width: titleBlockWidth, alignment: .center)
                            Text("DONE!")
                                .font(.system(size: 50, weight: .black))
                                .kerning(1.2)
                                .foregroundStyle(titleColor)
                                .lineLimit(1)
                                .minimumScaleFactor(0.6)
                                .scaleEffect(x: doneScaleX, y: 1.0, anchor: .center)
                                .frame(width: titleBlockWidth, alignment: .center)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 3)
                        .overlay(
                            RoundedRectangle(cornerRadius: 16)
                                .stroke(titleColor, lineWidth: 4)
                        )
                        .position(
                            x: geo.size.width * 0.5,
                            y: max(geo.safeAreaInsets.top + 62, geo.size.height * 0.16)
                        )

                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
                            .modifier(ReflectDarkModeInvertImage())
                            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.92)
                    }
                }
            }
        }
    }

    private var insightsStep: some View {
        VStack(spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    HStack(spacing: 10) {
                        summaryTile(title: "Tasks Closed", value: "\(doneCount)/\(max(totalActions, 1))", detail: "\(Int(completionRatio * 100))% done")
                        summaryTile(title: "Average Duration", value: formatMinutes(averageDurationMinutes), detail: "\(durations.count) estimated")
                    }

                    HStack(spacing: 10) {
                        summaryTile(title: "Started", value: shortDate(startedAt), detail: "Complete: \(shortDate(completedAt))")
                        summaryTile(title: "Elapsed", value: "\(completionDayCount)d", detail: "from start to complete")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Productive signals")
                            .font(.headline)

                        signalRow(icon: "mappin.and.ellipse", title: "Place", value: topPlace ?? "No pattern yet")
                        signalRow(icon: "person.fill", title: "Person", value: topPerson ?? "No pattern yet")
                        signalRow(icon: "wrench.and.screwdriver.fill", title: "Tool", value: topTool ?? "No pattern yet")
                        signalRow(icon: "clock.fill", title: "Time", value: topTimeOfDay ?? "No pattern yet")
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Productive days")
                            .font(.headline)

                        Chart(productiveDayRows) { row in
                            BarMark(
                                x: .value("Day", row.dayLabel),
                                y: .value("Completed", row.completed)
                            )
                            .foregroundStyle(Color.accentColor.gradient)

                            BarMark(
                                x: .value("Day", row.dayLabel),
                                y: .value("Must", row.mustCompleted)
                            )
                            .foregroundStyle(Color.orange.gradient)
                        }
                        .frame(height: 180)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Flow profile")
                            .font(.headline)
                        ForEach(flowProfileRows, id: \.0) { row in
                            metricCapsuleRow(title: row.0, value: row.1, tint: row.2)
                        }

                        Text("Notes: \(noteCount)  Links: \(linkCount)  Files: \(fileCount)")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                    if !categoryBreakdown.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Categories")
                                .font(.headline)
                            ForEach(categoryBreakdown, id: \.0) { row in
                                HStack {
                                    Text(row.0)
                                    Spacer()
                                    Text("\(row.1)")
                                        .fontWeight(.bold)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !outcomesForWeek.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Outcomes connected")
                                .font(.headline)
                            ForEach(outcomesForWeek, id: \.outcome_id) { outcome in
                                Text("• \(outcome.outcome)")
                                    .font(.subheadline)
                                .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                    }

                    if !carriedActions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Carried to new capture list")
                                .font(.headline)
                            Text("These will be moved back to Rolling Capture.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                            ForEach(carriedActions, id: \.id) { action in
                                Text("• \(action.text)")
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
                    onFinish()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                )

                Button {
                    beginContributionFlowOrProceed()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
        }
    }

    private var journalStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Text("Any thought, feeling, emotion or behavior that is constantly reinforced will become habit. Keep score of your wins. You can be winning when you think you're losing if you don't keep score.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Text("Achievements")
                        .font(.headline)
                    journalTextEditor(
                        text: $achievementsText,
                        placeholder: "What did I accomplish that I'm proud of? What progress did I make?",
                        isHighlighted: highlightedMissingJournalFields.contains(.achievements)
                    )

                    Text("Magic Moments")
                    .font(.headline)
                    journalTextEditor(
                        text: $magicMomentsText,
                        placeholder: "What did I enjoy? Who did I impact? What were some magic moments?",
                        isHighlighted: highlightedMissingJournalFields.contains(.magicMoments)
                    )

                    Text("Power Question: What have I given?")
                        .font(.headline)
                    journalTextEditor(
                        text: $powerQuestionText,
                        placeholder: "What did I give today?",
                        isHighlighted: highlightedMissingJournalFields.contains(.powerQuestion)
                    )
                }
                .padding(.top, 4)
            }

            HStack(spacing: 12) {
                Button {
                    step = 1
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(colorScheme == .dark ? Color(.secondaryLabel) : .black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5))
                )

                Button {
                    if journalIsValid {
                        saveArchiveAndExit()
                    } else {
                        showJournalValidationHint()
                    }
                } label: {
                    Text("Save")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(journalIsValid ? .accentColor : Color(.systemGray3))
            }
        }
    }

    private var instructionsSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Text("Instructions")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Placeholder text for reflection instructions.")
                        .foregroundStyle(.secondary)

                    if let row = weekMindsetRow {
                        Divider().padding(.vertical, 4)
                        Text("What am I happy for or grateful about in life right now?")
                            .font(.headline)
                        Text(row.morningPowerQuestion)
                            .foregroundStyle(.secondary)
                        Text("What’s a simple phrase that inspires you?")
                            .font(.headline)
                            .padding(.top, 6)
                        Text(row.incantation)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
            }
        }
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

    private func journalTextEditor(text: Binding<String>, placeholder: String, isHighlighted: Bool) -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: text)
                .frame(minHeight: 110)
                .padding(8)
                .scrollContentBackground(.hidden)
                .background(Color.clear, in: RoundedRectangle(cornerRadius: 10))
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
        var missing: Set<JournalField> = []
        if achievementsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.achievements) }
        if magicMomentsText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.magicMoments) }
        if powerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty { missing.insert(.powerQuestion) }
        highlightedMissingJournalFields = missing

        withAnimation(.easeInOut(duration: 0.2)) {
            showSaveHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showSaveHint = false
            }
            highlightedMissingJournalFields.removeAll()
        }
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
        fmt.dateStyle = .medium
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
            magicMomentsText: magicMomentsText.trimmingCharacters(in: .whitespacesAndNewlines),
            powerQuestionText: powerQuestionText.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(archive)

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

        persistCarriedActionProfiles()
        applyIntegratedCaptureFinalStatuses()
        recaptureCarriedActions()
        clearWeekPlanningStateAfterArchive()

        if let active = activePlanStates.first {
            active.isActive = false
            active.weekStart = nil
        }

        try? modelContext.save()
        onFinish()
    }

    private func beginContributionFlowOrProceed() {
        let queue = outcomesForContributionFlow
        guard !queue.isEmpty else {
            step = 2
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
            step = 2
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
}

private struct ProductiveDayRow: Identifiable {
    let id = UUID()
    let dayLabel: String
    let completed: Int
    let mustCompleted: Int
}

private struct ReflectionLoadingStyleLinesBackground: View {
    let colors: [Color]
    let focusXFraction: CGFloat
    let focusYFraction: CGFloat
    let radarDiameter: CGFloat

    private let lineCount: Int = 102
    private let leftInset: CGFloat = -40
    private let verticalBandFraction: Double = 0.82
    private let verticalShift: CGFloat = 0

    private let funnelMinScale: CGFloat = 0.08
    private let funnelCurve: CGFloat = 1.55
    private let radarCircleExtraDiameter: CGFloat = 18

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
                let startX = leftInset
                let circleRadius = (radarDiameter + radarCircleExtraDiameter) / 2
                let endX = max(startX + 40, focusX - circleRadius)

                Canvas { ctx, sz in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let colorCount = max(1, colors.count)
                    let centerY: CGFloat = sz.height * focusYFraction

                    func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
                        let tt = min(max((x - a) / (b - a), 0), 1)
                        return tt * tt * (3 - 2 * tt)
                    }

                    for i in 0..<lineCount {
                        let band = max(0.05, min(verticalBandFraction, 1.0))
                        let bandStart = 0.5 - band / 2.0
                        let localFracBase = (Double(i) + 0.5) / Double(lineCount)
                        let jitter = rand(i * 19 + 7, -0.03, 0.03)
                        let localFrac = min(max(localFracBase + jitter, 0.0), 1.0)
                        let clampedFrac = bandStart + band * localFrac
                        let baseY: CGFloat = CGFloat(clampedFrac) * sz.height + verticalShift

                        let endY: CGFloat = centerY

                        let color = colors[i % colorCount]
                        let L = endX - startX
                        if L <= 1 { continue }

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
                        let samples = 96
                        for j in 0...samples {
                            let twoPi = 2.0 * Double.pi
                            let s = Double(j) / Double(samples)
                            let x = startX + CGFloat(s) * L

                            let diff = (s - posFrac) / sigma
                            let envelope = exp(-pow(diff, 2) * 2)
                            let pulseArg = twoPi * (s * freq - t * speed * 0.6) + wobblePhase
                            let pulse = sin(pulseArg) * amp * envelope
                            let swellArg = twoPi * (s * (freq * 0.45) + t * speed * 0.25) + wobblePhase * 0.7
                            let swell = sin(swellArg) * (amp * 0.6)
                            let wiggle = (pulse + swell) * sin(Double.pi * s) * 0.62

                            let baseLineY = baseY + (endY - baseY) * CGFloat(s)
                            var y = baseLineY + CGFloat(wiggle)

                            let rawBendT = smoothstep(0.05, 0.82, CGFloat(s))
                            let bendT = pow(rawBendT, 0.55)
                            let steerY = y + (centerY - y) * (bendT * 0.45)
                            let pinchT = smoothstep(0.84, 1.0, CGFloat(s))
                            let pinchCurve = pow(pinchT, funnelCurve)
                            let attractT = smoothstep(0.78, 1.0, CGFloat(s))
                            let attractorY = centerY + (endY - centerY) * attractT
                            let lateScale = (1.0 - pinchCurve) + pinchCurve * funnelMinScale
                            y = attractorY + (steerY - attractorY) * lateScale
                            if j == 0 { y = baseY }

                            let point = CGPoint(x: x, y: y)
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
                                startPoint: CGPoint(x: startX, y: baseY),
                                endPoint: CGPoint(x: endX, y: endY)
                            ),
                            lineWidth: 10
                        )

                        let tailFactorAtGlow = pow(max(0, 1.0 - smoothstepD(Double(tailStartFrac), 1.0, posFrac)), 2.8)
                        let glowPeak = 0.45 * tailFactorAtGlow
                        let glowHalfWidth = sigma * 0.8
                        let startStop = max(0.0, posFrac - glowHalfWidth)
                        let endStop = min(1.0, posFrac + glowHalfWidth)
                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(0.0), location: startStop),
                            .init(color: color.opacity(glowPeak), location: posFrac),
                            .init(color: color.opacity(0.0), location: endStop),
                        ])
                        let gradStart = CGPoint(x: startX, y: baseY)
                        let gradEnd = CGPoint(x: endX, y: endY)
                        let clipRect = CGRect(x: startX, y: 0, width: L, height: sz.height)

                        ctx.drawLayer { layer in
                            layer.clip(to: Path(clipRect))
                            layer.addFilter(.blur(radius: 7))
                            layer.stroke(path, with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd), lineWidth: 12)
                        }
                        ctx.drawLayer { layer in
                            layer.clip(to: Path(clipRect))
                            layer.addFilter(.blur(radius: 2))
                            layer.stroke(path, with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd), lineWidth: 6)
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .mask {
            GeometryReader { geo in
                let w = max(1, geo.size.width)
                let focusX = w * focusXFraction
                let circleRadius = (radarDiameter + radarCircleExtraDiameter) / 2
                let startX = leftInset
                let endX = max(startX + 40, focusX - circleRadius)
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
