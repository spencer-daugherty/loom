import SwiftUI
import SwiftData
import Charts

struct ReflectAchievementsView: View {
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
    @Query private var allMindsetRows: [WeeklyMindsetEntry.Fields]
    @Query private var allAdHocMarkers: [PlannedChunkActionAdHocMarker]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse) private var captureItems: [RollingCaptureItem]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]

    @State private var step: Int = 1
    @State private var showInstructions: Bool = false
    @State private var showCelebration: Bool = true

    @State private var achievementsText: String = ""
    @State private var magicMomentsText: String = ""
    @State private var powerQuestionText: String = ""
    @State private var showSaveHint: Bool = false
    @State private var highlightedMissingJournalFields: Set<JournalField> = []

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

                ReflectionLoadingStyleLinesBackground(
                    colors: palette,
                    focusXFraction: 0.76,
                    focusYFraction: focusYFraction,
                    radarDiameter: radarDiameter
                )
                .ignoresSafeArea()

                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let pulse = loadingStylePulsedMetrics(at: t * 0.45)
                    ZStack {
                        FulfillmentRadarGraph(
                            metrics: pulse,
                            showOutline: false,
                            dotDiameter: 12,
                            showDotOutline: false,
                            showDotShadow: true
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

                        Text("Action Blocks, DONE!")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(.black)
                            .position(x: geo.size.width * 0.5, y: geo.size.height * 0.10)

                        Image("logo")
                            .resizable()
                            .scaledToFit()
                            .frame(height: 44)
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
                    step = 2
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
                        Text("Power Question")
                            .font(.headline)
                        Text(row.morningPowerQuestion)
                            .foregroundStyle(.secondary)
                        Text("What am I grateful for?")
                            .font(.headline)
                            .padding(.top, 6)
                        Text(row.gratitude)
                            .foregroundStyle(.secondary)
                        Text("Incantation")
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
            ("Career & Business", .blue, 80),
            ("Leadership & Impact", .indigo, 65),
            ("Wealth & Lifestyle", .green, 90),
            ("Mind & Meaning", .purple, 75),
            ("Love & Relationships", .red, 85),
            ("Health & Vitality", .orange, 70),
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

        recaptureCarriedActions()
        clearWeekPlanningStateAfterArchive()

        if let active = activePlanStates.first {
            active.isActive = false
            active.weekStart = nil
        }

        try? modelContext.save()
        onFinish()
    }

    private func recaptureCarriedActions() {
        let existing = Set(captureItems.map { normalized($0.text) })
        var seen = existing
        for action in carriedActions {
            let text = action.text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            let key = normalized(text)
            guard !seen.contains(key) else { continue }
            modelContext.insert(
                RollingCaptureItem(
                    text: text,
                    isGhost: false,
                    createdAt: .now
                )
            )
            seen.insert(key)
        }
    }

    /// Archive is persisted first, then active-week planning/action rows are cleared
    /// so a fresh PlanView session does not reuse completed Action Blocks data.
    private func clearWeekPlanningStateAfterArchive() {
        for row in allChunkSelections { modelContext.delete(row) }
        for row in allStepFourStates { modelContext.delete(row) }
        for row in allOutcomeLinks { modelContext.delete(row) }
        for row in allAdHocMarkers { modelContext.delete(row) }

        for row in allActions { modelContext.delete(row) }
        for row in allChunks { modelContext.delete(row) }
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

                        let amp = rand(i * 23 + 5, 24.0, 64.0) // exaggerated waves
                        let freq = rand(i * 29 + 9, 1.8, 4.8)
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
                            let wiggle = (pulse + swell) * sin(Double.pi * s) * 0.5

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

                        let tailStartFrac: CGFloat = 0.85
                        let baseOpacity: Double = 0.11
                        let tailGradient = Gradient(stops: [
                            .init(color: color.opacity(baseOpacity), location: 0.0),
                            .init(color: color.opacity(baseOpacity * 0.75), location: Double(tailStartFrac)),
                            .init(color: color.opacity(baseOpacity * 0.18), location: 0.90),
                            .init(color: color.opacity(baseOpacity * 0.03), location: 0.95),
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
                let fadeStartX = endX - (lineLength * 0.25) // last 25% of line run

                let fadeStart = max(0, min(1, fadeStartX / w))
                let fadeMid = max(fadeStart, min(1, (endX - (lineLength * 0.08)) / w))
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
