import SwiftUI
import SwiftData

private func sanitizeAndFormatDecimalInputOutcome(_ input: String, maxFractionDigits: Int = 3) -> String {
    let sanitized = input.replacingOccurrences(of: ",", with: "")
    var output = ""
    var seenDot = false
    var fractionCount = 0
    for char in sanitized {
        if char.isWholeNumber {
            if seenDot {
                if fractionCount < maxFractionDigits {
                    output.append(char)
                    fractionCount += 1
                }
            } else {
                output.append(char)
            }
        } else if char == "." && !seenDot {
            seenDot = true
            output.append(char)
        }
    }
    guard !output.isEmpty else { return "" }
    let hasDot = output.contains(".")
    let parts = output.split(separator: ".", omittingEmptySubsequences: false)
    let intPart = Int(String(parts.first ?? "")) ?? 0
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.maximumFractionDigits = 0
    formatter.minimumFractionDigits = 0
    let grouped = formatter.string(from: NSNumber(value: intPart)) ?? String(intPart)
    if hasDot {
        let fraction = parts.count > 1 ? String(parts[1]) : ""
        return grouped + "." + fraction
    }
    return grouped
}

private func parseFormattedDecimalOutcome(_ input: String) -> Double? {
    Double(input.replacingOccurrences(of: ",", with: ""))
}

private func groupedDecimalStringOutcome(_ value: Double, fractionDigits: Int) -> String {
    let places = max(0, min(3, fractionDigits))
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.minimumFractionDigits = places
    formatter.maximumFractionDigits = places
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)
}

struct OutcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    let outcome: Outcomes
    let outcomeMeasure: OutcomesMeasure?

    @State private var goal: String
    @State private var reasons: String
    @State private var selectedDuration: Int
    @State private var startNow: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedCategory: ObjectivesAddView.Category
    @State private var isShowingDeleteOutcomeAlert = false
    @State private var isShowingAddMeasureSheet = false
    @State private var isShowingUpdateGoalSheet = false
    @State private var isShowingCompletedActionSheet = false
    @State private var isShowingCompleteOutcomeSheet = false
    @State private var isShowingChangeTargetSheet = false
    @State private var isShowingGoalMetConfirmAlert = false
    @State private var isShowingMeasureCheckAlert = false
    @State private var isShowingTargetDatePicker = false
    @State private var completionValidationMessage: String = ""
    @State private var filterConnectedBlocksOnly = true
    @State private var selectedCompletedArchiveActionIDs: Set<UUID> = []
    @State private var isShowingAllContributingActions = false
    @State private var isMeasurable = false
    @State private var measureGoal: String = ""
    @State private var measureCurrent: String = ""
    @State private var measureFormat: ObjectivesAddView.MeasureFormat = .number
    @State private var measureUnit: String = ObjectivesAddView.UnitOption.defaultUnit
    @State private var measureDecimalPlaces: Int = 0
    @State private var updateGoalInput: String = ""
    @State private var updateGoalDate: Date = Calendar.current.startOfDay(for: .now)
    @FocusState private var isUpdateGoalFieldFocused: Bool
    @State private var completionSuccessLevel: Int = 3
    @State private var completionJournalText: String = ""
    @State private var completionRecordedDate: Date = Calendar.current.startOfDay(for: .now)
    @FocusState private var isCompletionJournalFocused: Bool
    @State private var changeTargetDateDraft: Date = .now

    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]
    @Query(sort: \OutcomesMeasure.measure_updated, order: .reverse) private var allMeasureSnapshots: [OutcomesMeasure]
    @Query(sort: \OutcomeAnalyticsEvent.occurredAt, order: .forward) private var allOutcomeEvents: [OutcomeAnalyticsEvent]
    @Query(sort: \ActionBlocksReflectionOutcomeContribution.completedAt, order: .reverse) private var allContributingActions: [ActionBlocksReflectionOutcomeContribution]
    @Query(sort: \QuickCompletedCaptureItem.completedAt, order: .reverse) private var quickCompletedCaptureItems: [QuickCompletedCaptureItem]
    @Query private var allReflectionActions: [ActionBlocksReflectionArchiveAction]
    @Query private var allReflectionOutcomes: [ActionBlocksReflectionArchiveOutcome]
    @Query private var allReflectionArchives: [ActionBlocksReflectionArchive]

    private struct CompletedActionCandidate: Identifiable {
        let id: UUID // archive action row id
        let archiveId: UUID
        let weekStart: Date
        let plannedChunkId: UUID
        let plannedChunkActionId: UUID
        let actionText: String
        let completedAt: Date
        let isQuickCompleted: Bool
    }

    private var popupForegroundColor: Color {
        colorScheme == .dark ? .black : .primary
    }

    init(outcome: Outcomes, outcomeMeasure: OutcomesMeasure?) {
        self.outcome = outcome
        self.outcomeMeasure = outcomeMeasure
        _goal = State(initialValue: outcome.outcome)
        _reasons = State(initialValue: outcome.reasons)
        _selectedDuration = State(initialValue: Calendar.current.dateComponents([.day], from: outcome.start, to: outcome.end).day ?? 30)
        _startNow = State(initialValue: outcome.start == outcome.updatedAt)
        _startDate = State(initialValue: outcome.start)
        _endDate = State(initialValue: outcome.end)
        _selectedCategory = State(initialValue: ObjectivesAddView.Category(rawValue: outcome.category) ?? .placeholder)

        if let outcomeMeasure {
            _isMeasurable = State(initialValue: outcomeMeasure.measure_amt != 0)
            _measureGoal = State(initialValue: String(outcomeMeasure.measure_amt))
            _measureCurrent = State(initialValue: String(outcomeMeasure.measure))
            _measureFormat = State(initialValue: ObjectivesAddView.MeasureFormat(rawValue: outcomeMeasure.format ?? ObjectivesAddView.MeasureFormat.number.rawValue) ?? .number)
            _measureUnit = State(initialValue: outcomeMeasure.unit ?? ObjectivesAddView.UnitOption.defaultUnit)
            _measureDecimalPlaces = State(initialValue: outcomeMeasure.decimalPlaces ?? 0)
        } else {
            _isMeasurable = State(initialValue: false)
            _measureGoal = State(initialValue: "")
            _measureCurrent = State(initialValue: "")
            _measureFormat = State(initialValue: .number)
            _measureUnit = State(initialValue: ObjectivesAddView.UnitOption.defaultUnit)
            _measureDecimalPlaces = State(initialValue: 0)
        }
    }

    private var hasChanges: Bool {
        let measureChanged: Bool
        if let snapshot = latestOutcomeMeasureSnapshot {
            let snapshotPlaces = min(3, max(0, snapshot.decimalPlaces ?? 0))
            let expectedGoalString = groupedDecimalStringOutcome(snapshot.measure_amt, fractionDigits: snapshotPlaces)
            measureChanged =
            isMeasurable != (snapshot.measure_amt != 0) ||
            (isMeasurable && measureGoal != expectedGoalString) ||
            (isMeasurable && measureFormat.rawValue != (snapshot.format ?? ObjectivesAddView.MeasureFormat.number.rawValue)) ||
            (isMeasurable && measureUnit != (snapshot.unit ?? ObjectivesAddView.UnitOption.defaultUnit)) ||
            (isMeasurable && measureDecimalPlaces != (snapshot.decimalPlaces ?? 0))
        } else {
            measureChanged = isMeasurable
        }

        return goal != outcome.outcome ||
            reasons != outcome.reasons ||
            selectedDuration != daysBetween(outcome.start, outcome.end) ||
            startDate != outcome.start ||
            endDate != outcome.end ||
            startNow != (outcome.start == outcome.updatedAt) ||
            selectedCategory.rawValue != outcome.category ||
            measureChanged
    }

    private var isStartEditable: Bool {
        Calendar.current.startOfDay(for: outcome.start) > Calendar.current.startOfDay(for: .now)
    }

    private var effectiveStartDate: Date {
        Calendar.current.startOfDay(for: startNow ? .now : startDate)
    }

    private var isSaveDisabled: Bool {
        goal.isEmpty || selectedCategory == .placeholder || (isMeasurable && (measureGoal.isEmpty || parseFormattedDecimalOutcome(measureGoal) == nil))
    }

    private var daysLeft: Int {
        let components = Calendar.current.dateComponents([.day], from: .now, to: endDate)
        return components.day ?? 0
    }

    private var contributingActionsForOutcome: [ActionBlocksReflectionOutcomeContribution] {
        allContributingActions.filter { $0.outcomeId == outcome.outcome_id }
    }

    private var archiveById: [UUID: ActionBlocksReflectionArchive] {
        Dictionary(uniqueKeysWithValues: allReflectionArchives.map { ($0.id, $0) })
    }

    private var connectedBlockKeysForOutcome: Set<String> {
        Set(
            allReflectionOutcomes
                .filter { $0.outcomeId == outcome.outcome_id }
                .map { "\($0.archiveId.uuidString)|\($0.plannedChunkId.uuidString)" }
        )
    }

    private var hasContributingActionsOutsideConnectedBlocks: Bool {
        contributingActionsForOutcome.contains {
            guard let blockKey = blockKeyForContribution($0) else { return true }
            return !connectedBlockKeysForOutcome.contains(blockKey)
        }
    }

    private var hasSelectedActionsOutsideConnectedBlocks: Bool {
        let candidateByID = Dictionary(uniqueKeysWithValues: completedActionCandidates.map { ($0.id, $0) })
        for selectedID in selectedCompletedArchiveActionIDs {
            guard let candidate = candidateByID[selectedID] else { continue }
            if candidate.isQuickCompleted {
                return true
            }
            let blockKey = "\(candidate.archiveId.uuidString)|\(candidate.plannedChunkId.uuidString)"
            if !connectedBlockKeysForOutcome.contains(blockKey) {
                return true
            }
        }
        return false
    }

    private var completedActionCandidates: [CompletedActionCandidate] {
        var rows: [CompletedActionCandidate] = allReflectionActions.compactMap { action in
            guard (ActionExecutionStatus(rawValue: action.statusRaw) ?? .noAction) == .done else { return nil }
            let completedAt = archiveById[action.archiveId]?.completedAt ?? action.weekStart
            return CompletedActionCandidate(
                id: action.id,
                archiveId: action.archiveId,
                weekStart: action.weekStart,
                plannedChunkId: action.plannedChunkId,
                plannedChunkActionId: action.plannedChunkActionId,
                actionText: action.actionText,
                completedAt: completedAt,
                isQuickCompleted: false
            )
        }

        let quickRows: [CompletedActionCandidate] = quickCompletedCaptureItems.map { item in
            let ws = WeeklyMindsetEntry.weekStart(for: item.completedAt)
            return CompletedActionCandidate(
                id: item.id,
                archiveId: item.id,
                weekStart: ws,
                plannedChunkId: item.id,
                plannedChunkActionId: item.id,
                actionText: item.text,
                completedAt: item.completedAt,
                isQuickCompleted: true
            )
        }

        if filterConnectedBlocksOnly {
            rows = rows.filter {
                connectedBlockKeysForOutcome.contains("\($0.archiveId.uuidString)|\($0.plannedChunkId.uuidString)")
            }
        } else {
            rows.append(contentsOf: quickRows)
        }

        rows.sort { $0.completedAt > $1.completedAt }
        return rows
    }

    private var showCompleteButton: Bool {
        Calendar.current.startOfDay(for: outcome.start) <= Calendar.current.startOfDay(for: .now)
    }

    private var showGoalAchievedEarlyBanner: Bool {
        guard isMeasurable, isGoalMetNow else { return false }
        return Calendar.current.startOfDay(for: .now) < Calendar.current.startOfDay(for: endDate)
    }

    private var showTargetPassedBanner: Bool {
        let passed = Calendar.current.startOfDay(for: .now) > Calendar.current.startOfDay(for: endDate)
        guard passed else { return false }
        if isMeasurable {
            return !isGoalMetNow
        }
        return true
    }

    private var targetPassedBannerMessage: String {
        if isMeasurable {
            return "Target date has passed, would you like to change your goal amount or target date?"
        }
        return "Target date has passed, would you like to change your target date?"
    }

    private var outcomeMeasureEntries: [OutcomesMeasureEntry] {
        allMeasureEntries.filter { $0.outcome_id == outcome.outcome_id }.sorted { $0.measuredAt < $1.measuredAt }
    }

    private var latestOutcomeMeasureSnapshot: OutcomesMeasure? {
        allMeasureSnapshots.first { $0.outcome_id == outcome.outcome_id }
    }

    private var outcomeEvents: [OutcomeAnalyticsEvent] {
        allOutcomeEvents.filter { $0.outcome_id == outcome.outcome_id }
    }

    private var currentMeasureValue: Double? {
        outcomeMeasureEntries.last?.measure ?? latestOutcomeMeasureSnapshot?.measure
    }

    private var currentGoalValue: Double? {
        outcomeMeasureEntries.last?.measure_amt ?? latestOutcomeMeasureSnapshot?.measure_amt
    }

    private var startMeasureValue: Double? {
        outcomeMeasureEntries.first?.measure ?? latestOutcomeMeasureSnapshot?.measure
    }

    private var isGoalMetNow: Bool {
        guard
            let current = currentMeasureValue,
            let goal = currentGoalValue,
            let start = startMeasureValue
        else { return false }
        if goal == start { return current >= goal }
        if goal > start { return current >= goal }
        return current <= goal
    }

    private var completionFormValid: Bool {
        let universalValid = !completionJournalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        if isMeasurable {
            return universalValid
        }
        return universalValid && (1...5).contains(completionSuccessLevel)
    }

    private var completionDateRange: ClosedRange<Date> {
        let cal = Calendar.current
        let lower = cal.startOfDay(for: outcome.start)
        let upper = cal.startOfDay(for: .now)
        if lower <= upper {
            return lower...upper
        }
        return upper...upper
    }

    private var summarySection: some View {
        Section {
            VStack(alignment: .leading, spacing: 8) {
                Text(goal.isEmpty ? "Goal" : goal)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor(for: selectedCategory.rawValue))
                    .lineLimit(3)
                Text(reasons)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .padding(.bottom, 2)

                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text("\(daysLeft)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(daysLeft < 0 ? .red : .black)
                        Text("days left")
                            .font(.caption2)
                            .foregroundColor(daysLeft < 0 ? .red : .black)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lightenedCategoryColor(for: selectedCategory.rawValue))
                    )
                    .frame(height: 44)

                    if isMeasurable, let current = parseFormattedDecimalOutcome(measureCurrent), let goalAmount = parseFormattedDecimalOutcome(measureGoal), goalAmount != 0 {
                        let startMeasure = allMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id })?.measure ?? current
                        let startMeasuredAt = allMeasureEntries
                            .filter { $0.outcome_id == outcome.outcome_id }
                            .min(by: { $0.measuredAt < $1.measuredAt })?
                            .measuredAt
                        let isStarting = startMeasuredAt.map { Calendar.current.isDate($0, inSameDayAs: latestMeasureDate()) } ?? false
                        MeasurableOutcomeBox(
                            measure: current,
                            measuredAt: latestMeasureDate(),
                            measureAmt: goalAmount,
                            endDate: endDate,
                            format: measureFormat.rawValue,
                            statusPrefix: isStarting ? "started" : "updated"
                        )
                        .frame(height: 44)

                        ProgressCircleView(
                            measure: current,
                            measureAmt: goalAmount,
                            startMeasure: startMeasure
                        )
                        .frame(width: 40, height: 40)
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    private var contributingActionsSection: some View {
        Section("Contributing Actions") {
            Button {
                seedCompletedActionSelection()
                isShowingCompletedActionSheet = true
            } label: {
                Text("+ Completed Actions")
                    .foregroundStyle(.blue)
            }

            if contributingActionsForOutcome.isEmpty {
                Text("No contributing actions logged yet.")
                    .foregroundStyle(.secondary)
            } else {
                let visibleItems = isShowingAllContributingActions ? contributingActionsForOutcome : Array(contributingActionsForOutcome.prefix(10))
                ForEach(visibleItems, id: \.id) { item in
                    HStack(alignment: .top, spacing: 10) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.actionText)
                                .font(.body)
                                .foregroundStyle(.primary)
                        }
                        Spacer(minLength: 8)
                        Text("Completed on \(compactDate(item.completedAt))")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 2)
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button("Unassign") {
                            unassignContributingAction(item)
                        }
                        .tint(.gray)
                    }
                }

                if contributingActionsForOutcome.count > 10 {
                    Button(isShowingAllContributingActions ? "Show Less" : "Show More") {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isShowingAllContributingActions.toggle()
                        }
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
            }
        }
    }

    private var formContent: some View {
        Form {
            if showTargetPassedBanner {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "exclamationmark.triangle.fill")
                            .foregroundStyle(popupForegroundColor)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("Caution: ").fontWeight(.bold) + Text(targetPassedBannerMessage))
                                .font(.subheadline)
                                .foregroundStyle(popupForegroundColor)
                            Button("Change target date") {
                                changeTargetDateDraft = endDate
                                isShowingChangeTargetSheet = true
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
            }

            if showGoalAchievedEarlyBanner {
                Section {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "flag.fill")
                            .foregroundStyle(popupForegroundColor)
                            .padding(.top, 2)
                        VStack(alignment: .leading, spacing: 4) {
                            (Text("Goal Acheived: ").fontWeight(.bold) + Text("Complete your outcome now!"))
                                .font(.subheadline)
                                .foregroundStyle(popupForegroundColor)
                            Button("Complete") {
                                prepareCompletionAttempt()
                            }
                            .font(.subheadline)
                            .foregroundStyle(.blue)
                        }
                        Spacer(minLength: 0)
                    }
                    .padding(8)
                    .background(
                        RoundedRectangle(cornerRadius: 12)
                            .fill(Color(red: 0.82, green: 0.95, blue: 0.84))
                    )
                    .listRowBackground(Color.clear)
                    .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                }
            }

            summarySection

            ChartSection(
                isMeasurable: isMeasurable,
                hasOutcome: true,
                outcomeId: outcome.outcome_id,
                measureGoal: $measureGoal,
                measureFormat: $measureFormat,
                measureUnit: $measureUnit,
                measureDecimalPlaces: $measureDecimalPlaces
            )
            ChartActionsSection(
                isMeasurable: isMeasurable,
                hasOutcome: true,
                outcomeId: outcome.outcome_id,
                measureFormat: $measureFormat,
                measureUnit: $measureUnit,
                measureDecimalPlaces: $measureDecimalPlaces,
                onAddMeasure: {
                    isShowingAddMeasureSheet = true
                }
            )
            contributingActionsSection
            GoalSection(goal: $goal)
            ReasonsSection(reasons: $reasons)
            if !isStartEditable {
                OutcomeStartedOnSection(startDate: outcome.start)
            } else {
                StartSection(startNow: $startNow, startDate: $startDate, selectedDuration: selectedDuration, endDate: $endDate)
            }
            OutcomeTargetSection(
                endDate: $endDate,
                selectedDuration: $selectedDuration,
                effectiveStartDate: effectiveStartDate,
                isShowingDatePicker: $isShowingTargetDatePicker
            )
            outcomeMeasureSection
            CategorySection(selectedCategory: $selectedCategory)
            Section {
                if showCompleteButton {
                    Button("Complete") {
                        prepareCompletionAttempt()
                    }
                    .foregroundColor(.blue)
                }
                Button("Delete") {
                    isShowingDeleteOutcomeAlert = true
                }
                .foregroundColor(.red)
            }
        }
    }

    private var formWithModifiers: some View {
        formContent
            .navigationTitle(goal.isEmpty ? "Outcome" : goal)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .alert("Delete Outcome?", isPresented: $isShowingDeleteOutcomeAlert) {
                Button("Delete", role: .destructive) {
                    let archivedOutcome = OutcomesArchive(
                        outcome_id: outcome.outcome_id,
                        category: outcome.category,
                        updatedAt: outcome.updatedAt,
                        outcome: outcome.outcome,
                        reasons: outcome.reasons,
                        start: outcome.start,
                        end: outcome.end,
                        rank: outcome.rank,
                        archivedAt: .now,
                        format: outcome.format
                    )
                    modelContext.insert(archivedOutcome)

                    if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
                        let archivedMeasure = OutcomesMeasureArchive(
                            outcome_id: existingMeasure.outcome_id,
                            measure: existingMeasure.measure,
                            measuredAt: existingMeasure.measuredAt,
                            measure_amt: existingMeasure.measure_amt,
                            measure_updated: existingMeasure.measure_updated,
                            archivedAt: .now,
                            direction: existingMeasure.direction,
                            format: existingMeasure.format,
                            unit: existingMeasure.unit,
                            decimalPlaces: existingMeasure.decimalPlaces
                        )
                        modelContext.insert(archivedMeasure)
                    }

                    RecentlyDeletedStore.trash(outcome, in: modelContext, source: "Outcome")
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this outcome? It will be available for 30 days in Account Manager.")
            }
            .alert("Goal Met", isPresented: $isShowingGoalMetConfirmAlert) {
                Button("Not Yet", role: .cancel) {}
                Button("Continue") {
                    isShowingCompleteOutcomeSheet = true
                }
            } message: {
                Text(completionValidationMessage)
            }
            .alert("Before Completing", isPresented: $isShowingMeasureCheckAlert) {
                Button("Return", role: .cancel) {
                }
                Button("Continue") {
                    isShowingCompleteOutcomeSheet = true
                }
            } message: {
                Text(completionValidationMessage)
            }
            .onChange(of: isMeasurable) { _, newValue in
                guard newValue else { return }
            }
            .onAppear {
                hydrateMeasureFromLatestEntry()
            }
            .onDisappear {
                if hasChanges && !isSaveDisabled {
                    saveOutcome()
                }
            }
    }

    var body: some View {
        NavigationStack {
            formWithModifiers
        }
        .sheet(isPresented: $isShowingAddMeasureSheet) {
            AddOutcomeMeasureSheet(
                outcomeID: outcome.outcome_id,
                formatRaw: measureFormat.rawValue,
                unitRaw: measureUnit,
                decimalPlaces: measureDecimalPlaces
            )
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingUpdateGoalSheet) {
            NavigationStack {
                Form {
                    HStack {
                        Text("Date")
                        Spacer()
                        Text(updateGoalDate, style: .date)
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("New Goal")
                        Spacer()
                        if measureFormat == .dollars {
                            Text("$")
                                .foregroundStyle(.secondary)
                        }
                        TextField("Goal", text: $updateGoalInput)
                            .keyboardType(.decimalPad)
                            .focused($isUpdateGoalFieldFocused)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: updateGoalInput) { _, newValue in
                                let places = measureFormat == .dollars ? (measureDecimalPlaces == 2 ? 2 : 0) : min(3, max(0, measureDecimalPlaces))
                                updateGoalInput = sanitizeAndFormatDecimalInputOutcome(newValue, maxFractionDigits: places)
                            }
                        if !measureFormat.suffix.isEmpty {
                            Text(measureFormat.suffix)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .navigationTitle("Update Goal")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    updateGoalDate = Calendar.current.startOfDay(for: .now)
                    updateGoalInput = ""
                    isUpdateGoalFieldFocused = true
                    DispatchQueue.main.async {
                        isUpdateGoalFieldFocused = true
                    }
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                        isUpdateGoalFieldFocused = true
                    }
                }
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            isShowingUpdateGoalSheet = false
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        if let newGoalValue = parseFormattedDecimalOutcome(updateGoalInput),
                           newGoalValue != (currentGoalValue ?? 0) {
                            Button("Save") {
                                saveUpdatedGoal(newGoalValue)
                                isShowingUpdateGoalSheet = false
                            }
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: isShowingAddMeasureSheet) { _, showing in
            if !showing {
                hydrateMeasureFromLatestEntry()
            }
        }
        .sheet(isPresented: $isShowingChangeTargetSheet) {
            NavigationStack {
                Form {
                    Section("Target") {
                        DatePicker(
                            "End Date",
                            selection: $changeTargetDateDraft,
                            in: Calendar.current.startOfDay(for: .now)...,
                            displayedComponents: [.date]
                        )
                        .datePickerStyle(.graphical)
                    }
                }
                .navigationTitle("Change Target")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingChangeTargetSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            endDate = changeTargetDateDraft
                            saveOutcome()
                            isShowingChangeTargetSheet = false
                        }
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCompleteOutcomeSheet) {
            NavigationStack {
                Form {
                    Section("Completion") {
                        if isMeasurable {
                            if let current = currentMeasureValue, let goal = currentGoalValue {
                                Text(isGoalMetNow ? "Goal is met" : "Goal is not met")
                                    .fontWeight(.bold)
                                    .foregroundStyle(isGoalMetNow ? .green : .red)
                                Text("Latest value: \(formatMetricValue(current, format: measureFormat.rawValue))")
                                Text("Goal: \(formatMetricValue(goal, format: measureFormat.rawValue))")
                            } else {
                                Text("No measured data found.")
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            Picker("Success Level", selection: $completionSuccessLevel) {
                                Text("Regressed Significantly").tag(1)
                                Text("Regressed Somewhat").tag(2)
                                Text("Partially Acheived").tag(3)
                                Text("Fully Acheived").tag(4)
                                Text("Overacheived").tag(5)
                            }
                            .pickerStyle(.menu)
                        }

                        HStack {
                            Text("Target Date")
                            Spacer()
                            Text(endDate, style: .date)
                                .foregroundStyle(.gray)
                        }

                        DatePicker(
                            "Completed",
                            selection: $completionRecordedDate,
                            in: completionDateRange,
                            displayedComponents: [.date]
                        )
                    }

                    Section("Journal") {
                        TextField(
                            "How was the goal progressed? What did I learn? What will I do next?",
                            text: $completionJournalText,
                            axis: .vertical
                        )
                        .lineLimit(4...8)
                        .focused($isCompletionJournalFocused)
                    }
                }
                .navigationTitle("Complete Outcome")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    completionRecordedDate = Calendar.current.startOfDay(for: .now)
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        Spacer()
                        Button("Done") {
                            isCompletionJournalFocused = false
                            UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
                        }
                        .foregroundStyle(.blue)
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isShowingCompleteOutcomeSheet = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            finalizeOutcomeCompletion()
                        }
                        .disabled(!completionFormValid)
                    }
                }
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isShowingCompletedActionSheet, onDismiss: {
            applySelectedCompletedActions()
        }) {
            NavigationStack {
                VStack(spacing: 0) {
                    HStack {
                        Text("Actions in blocks outcome was connected with")
                            .font(.subheadline)
                        Spacer(minLength: 8)
                        Toggle("", isOn: $filterConnectedBlocksOnly)
                            .labelsHidden()
                    }
                    .opacity(hasSelectedActionsOutsideConnectedBlocks ? 0.45 : 1.0)
                    .disabled(hasSelectedActionsOutsideConnectedBlocks)
                    .padding(.horizontal)
                    .padding(.vertical, 10)

                    List {
                        if completedActionCandidates.isEmpty {
                            Text("This outcome does not have any associated blocks with actions completed. Try switching off toggle to see all completed actions.")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .listRowSeparator(.hidden)
                        } else {
                            ForEach(completedActionCandidates) { candidate in
                                Button {
                                    if selectedCompletedArchiveActionIDs.contains(candidate.id) {
                                        selectedCompletedArchiveActionIDs.remove(candidate.id)
                                    } else {
                                        selectedCompletedArchiveActionIDs.insert(candidate.id)
                                    }
                                } label: {
                                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                                        Image(systemName: selectedCompletedArchiveActionIDs.contains(candidate.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedCompletedArchiveActionIDs.contains(candidate.id) ? Color.accentColor : Color(.systemGray3))
                                        Text(candidate.actionText)
                                            .font(.body.weight(.medium))
                                            .foregroundStyle(.primary)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                        Text("Completed on \(compactDate(candidate.completedAt))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    .padding(8)
                                    .padding(.vertical, 2)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                    .padding(.vertical, 1)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                            }
                        }
                    }
                    .listStyle(.plain)
                }
                .navigationTitle("Completed Actions")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    if hasSelectedActionsOutsideConnectedBlocks || hasContributingActionsOutsideConnectedBlocks {
                        filterConnectedBlocksOnly = false
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func prepareCompletionAttempt() {
        completionRecordedDate = Calendar.current.startOfDay(for: .now)
        completionValidationMessage = ""
        if isMeasurable {
            guard currentMeasureValue != nil, currentGoalValue != nil else {
                completionValidationMessage = "Enter measured data before completing."
                isShowingMeasureCheckAlert = true
                return
            }
            if isGoalMetNow {
                let currentText = formatMetricValue(currentMeasureValue ?? 0, format: measureFormat.rawValue)
                completionValidationMessage = "Latest value \(currentText) meets your goal. Complete now?"
                isShowingGoalMetConfirmAlert = true
            } else {
                let targetNotArrived = Calendar.current.startOfDay(for: .now) < Calendar.current.startOfDay(for: outcome.end)
                if targetNotArrived {
                    completionValidationMessage = "Goal is not met and target date has not arrived. Are you completing outcome not acheived?"
                } else {
                    completionValidationMessage = "Goal is not met. Add any missing data first, or continue if your latest value is final."
                }
                isShowingMeasureCheckAlert = true
            }
            return
        }
        let targetNotArrived = Calendar.current.startOfDay(for: .now) < Calendar.current.startOfDay(for: outcome.end)
        if targetNotArrived {
            completionValidationMessage = "Target date has not arrived. Are you completing outcome early or marking not acheived?"
            isShowingMeasureCheckAlert = true
            return
        }
        isShowingCompleteOutcomeSheet = true
    }

    private func finalizeOutcomeCompletion() {
        let cal = Calendar.current
        let startDay = cal.startOfDay(for: outcome.start)
        let endDay = cal.startOfDay(for: completionRecordedDate)
        let elapsed = max(1, (cal.dateComponents([.day], from: startDay, to: endDay).day ?? 0) + 1)
        let goalPushes = outcomeEvents.filter { $0.eventType == "goal_changed" }.count
        let targetChanges = outcomeEvents.filter { $0.eventType == "target_changed" }.count
        let dataPoints = outcomeMeasureEntries.count

        let archive = CompletedOutcomeArchive(
            originalOutcomeId: outcome.outcome_id,
            category: outcome.category,
            outcome: outcome.outcome,
            reasons: outcome.reasons,
            start: outcome.start,
            end: outcome.end,
            completedAt: completionRecordedDate,
            format: outcome.format,
            isMeasurable: isMeasurable,
            goalValue: currentGoalValue,
            finalValue: currentMeasureValue,
            goalMet: isGoalMetNow,
            successLevel: isMeasurable ? nil : completionSuccessLevel,
            daysElapsed: elapsed,
            goalPushCount: goalPushes,
            dataEntryCount: dataPoints,
            targetChangeCount: targetChanges,
            journalWins: completionJournalText,
            journalLearned: "",
            journalNext: ""
        )
        modelContext.insert(archive)

        for row in contributingActionsForOutcome {
            modelContext.insert(
                CompletedOutcomeContributionArchive(
                    completedOutcomeArchiveId: archive.id,
                    actionText: row.actionText,
                    completedAt: row.completedAt
                )
            )
        }

        for row in outcomeMeasureEntries {
            modelContext.insert(
                CompletedOutcomeMeasurePointArchive(
                    completedOutcomeArchiveId: archive.id,
                    measuredAt: row.measuredAt,
                    measure: row.measure,
                    goal: row.measure_amt
                )
            )
        }

        if let snapshot = latestOutcomeMeasureSnapshot {
            RecentlyDeletedStore.trash(snapshot, in: modelContext)
        }
        for row in outcomeMeasureEntries {
            RecentlyDeletedStore.trash(row, in: modelContext)
        }
        for row in contributingActionsForOutcome {
            RecentlyDeletedStore.trash(row, in: modelContext)
        }
        for event in outcomeEvents {
            RecentlyDeletedStore.trash(event, in: modelContext)
        }
        RecentlyDeletedStore.trash(outcome, in: modelContext, source: "Outcome Completed")
        try? modelContext.save()
        isShowingCompleteOutcomeSheet = false
        dismiss()
    }

    private func formatMetricValue(_ value: Double, format: String) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let base = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        switch format {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return "$\(base)"
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return "\(base)%"
        default:
            return base
        }
    }

    private var outcomeMeasureSection: some View {
        Section("Measure Data") {
            Toggle("Outcome is measurable", isOn: $isMeasurable)

            if isMeasurable {
                Picker("Format", selection: $measureFormat) {
                    ForEach(ObjectivesAddView.MeasureFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: measureFormat) { _, newFormat in
                    if newFormat == .dollars && measureDecimalPlaces != 0 && measureDecimalPlaces != 2 {
                        measureDecimalPlaces = 2
                    }
                    guard let value = parseFormattedDecimalOutcome(measureGoal) else { return }
                    let places = newFormat == .dollars
                        ? (measureDecimalPlaces == 2 ? 2 : 0)
                        : min(3, max(0, measureDecimalPlaces))
                    measureGoal = groupedDecimalStringOutcome(value, fractionDigits: places)
                }

                if measureFormat == .dollars {
                    HStack {
                        Text("Cents")
                        Spacer()
                        Picker("Cents", selection: $measureDecimalPlaces) {
                            Text("No").tag(0)
                            Text("Yes").tag(2)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                } else {
                    HStack {
                        Text("Decimal")
                        Spacer()
                        Picker("Decimal", selection: $measureDecimalPlaces) {
                            Text("No").tag(0)
                            Text("0.0").tag(1)
                            Text("0.00").tag(2)
                            Text("0.000").tag(3)
                        }
                        .labelsHidden()
                        .pickerStyle(.menu)
                    }
                }

                HStack {
                    Text("Goal")
                    Spacer()
                    if measureFormat == .dollars {
                        Text("$")
                            .foregroundStyle(.secondary)
                    }
                    Text(measureGoal.isEmpty ? "Not set" : measureGoal)
                        .foregroundStyle(.secondary)
                    if !measureFormat.suffix.isEmpty {
                        Text(measureFormat.suffix)
                            .foregroundStyle(.secondary)
                    }
                }

                Button {
                    updateGoalDate = Calendar.current.startOfDay(for: .now)
                    updateGoalInput = ""
                    isShowingUpdateGoalSheet = true
                } label: {
                    Text("Update Goal")
                        .foregroundStyle(Color.accentColor)
                }
            }
        }
        .onChange(of: measureDecimalPlaces) { _, _ in
            guard let value = parseFormattedDecimalOutcome(measureGoal) else { return }
            let places = measureFormat == .dollars
                ? (measureDecimalPlaces == 2 ? 2 : 0)
                : min(3, max(0, measureDecimalPlaces))
            measureGoal = groupedDecimalStringOutcome(value, fractionDigits: places)
        }
    }

    private func saveOutcome() {
        let previousEndDate = outcome.end
        let start = Calendar.current.startOfDay(for: startNow ? .now : startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        let measureValue = isMeasurable ? (parseFormattedDecimalOutcome(measureGoal) ?? 0.0) : 0.0
        let formatValue = isMeasurable ? measureFormat.rawValue : nil
        let unitValue = isMeasurable ? measureUnit : nil
        let decimalPlacesValue = isMeasurable
            ? (measureFormat == .dollars ? (measureDecimalPlaces == 2 ? 2 : 0) : measureDecimalPlaces)
            : nil

        outcome.category = selectedCategory.rawValue
        outcome.updatedAt = .now
        outcome.outcome = goal
        outcome.reasons = reasons
        outcome.start = start
        outcome.end = normalizedEndDate
        outcome.format = formatValue

        if previousEndDate != normalizedEndDate {
            modelContext.insert(
                OutcomeAnalyticsEvent(
                    outcome_id: outcome.outcome_id,
                    eventType: "target_changed",
                    oldTargetDate: previousEndDate,
                    newTargetDate: normalizedEndDate,
                    source: "OutcomeView"
                )
            )
        }

        if isMeasurable {
            if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
                let oldGoal = existingMeasure.measure_amt
                let goalChanged = existingMeasure.measure_amt != measureValue
                if goalChanged {
                    let now = Date()
                    let hasDuplicateGoalEvent = allOutcomeEvents.contains {
                        $0.outcome_id == outcome.outcome_id &&
                        $0.eventType == "goal_changed" &&
                        $0.oldGoal == oldGoal &&
                        $0.newGoal == measureValue &&
                        abs($0.occurredAt.timeIntervalSince(now)) < 5
                    }
                    if !hasDuplicateGoalEvent {
                        modelContext.insert(
                            OutcomeAnalyticsEvent(
                                outcome_id: outcome.outcome_id,
                                eventType: "goal_changed",
                                oldMeasure: existingMeasure.measure,
                                oldGoal: oldGoal,
                                newGoal: measureValue,
                                source: "OutcomeView"
                            )
                        )
                    }
                }
                existingMeasure.measure_amt = measureValue
                existingMeasure.measure_updated = .now
                existingMeasure.direction = nil
                existingMeasure.format = formatValue
                existingMeasure.unit = unitValue
                existingMeasure.decimalPlaces = decimalPlacesValue
            } else {
                let newMeasure = OutcomesMeasure(
                    outcome_id: outcome.outcome_id,
                    measure: 0,
                    measuredAt: outcome.start,
                    measure_amt: measureValue,
                    measure_updated: .now,
                    direction: nil,
                    format: formatValue,
                    unit: unitValue,
                    decimalPlaces: decimalPlacesValue
                )
                modelContext.insert(newMeasure)
            }
        } else if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
            RecentlyDeletedStore.trash(existingMeasure, in: modelContext)
        }

        try? modelContext.save()
    }

    private func saveUpdatedGoal(_ newGoalValue: Double) {
        let oldGoal = currentGoalValue ?? 0
        guard oldGoal != newGoalValue else { return }

        if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
            existingMeasure.measure_amt = newGoalValue
            existingMeasure.measure_updated = updateGoalDate
            existingMeasure.format = measureFormat.rawValue
            existingMeasure.unit = measureUnit
            existingMeasure.decimalPlaces = measureDecimalPlaces
        } else {
            modelContext.insert(
                OutcomesMeasure(
                    outcome_id: outcome.outcome_id,
                    measure: currentMeasureValue ?? 0,
                    measuredAt: outcome.start,
                    measure_amt: newGoalValue,
                    measure_updated: updateGoalDate,
                    direction: nil,
                    format: measureFormat.rawValue,
                    unit: measureUnit,
                    decimalPlaces: measureDecimalPlaces
                )
            )
        }

        modelContext.insert(
            OutcomeAnalyticsEvent(
                outcome_id: outcome.outcome_id,
                eventType: "goal_changed",
                oldGoal: oldGoal,
                newGoal: newGoalValue,
                source: "OutcomeView"
            )
        )

        let places = measureFormat == .dollars
            ? (measureDecimalPlaces == 2 ? 2 : 0)
            : min(3, max(0, measureDecimalPlaces))
        measureGoal = groupedDecimalStringOutcome(newGoalValue, fractionDigits: places)

        try? modelContext.save()
        hydrateMeasureFromLatestEntry()
    }

    private func hydrateMeasureFromLatestEntry() {
        let entries = allMeasureEntries.filter { $0.outcome_id == outcome.outcome_id }
        let latest = entries.max(by: { $0.measuredAt < $1.measuredAt })
        let snapshot = latestOutcomeMeasureSnapshot

        let goalSource = snapshot?.measure_amt ?? latest?.measure_amt ?? 0
        let currentSource = latest?.measure ?? snapshot?.measure ?? 0
        let formatSource = snapshot?.format ?? latest?.format
        let unitSource = snapshot?.unit ?? latest?.unit
        let decimalSource = snapshot?.decimalPlaces ?? latest?.decimalPlaces ?? 0

        if goalSource != 0 {
            let places = min(3, max(0, decimalSource))
            measureGoal = groupedDecimalStringOutcome(goalSource, fractionDigits: places)
        }
        if currentSource != 0 {
            let places = min(3, max(0, decimalSource))
            measureCurrent = String(format: "%.\(places)f", currentSource)
                .replacingOccurrences(of: places == 0 ? ".0" : "", with: "")
        }
        if let formatRaw = formatSource, let format = ObjectivesAddView.MeasureFormat(rawValue: formatRaw) {
            measureFormat = format
        }
        if let unit = unitSource {
            measureUnit = unit
        }
        measureDecimalPlaces = min(3, max(0, decimalSource))
    }

    private func latestMeasureDate() -> Date {
        let entries = allMeasureEntries.filter { $0.outcome_id == outcome.outcome_id }
        return entries.max(by: { $0.measuredAt < $1.measuredAt })?.measuredAt ?? outcome.updatedAt
    }

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Career & Business": return .blue
        case "Leadership & Impact": return .indigo
        case "Wealth & Lifestyle": return .green
        case "Mind & Meaning": return .purple
        case "Love & Relationships": return .red
        case "Health & Vitality": return .orange
        default: return .primary
        }
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        let baseColor = UIColor(categoryColor(for: category))
        return Color(baseColor.adjusted(by: 0.8))
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        return formatter.string(from: date)
    }

    private func unassignContributingAction(_ item: ActionBlocksReflectionOutcomeContribution) {
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private func seedCompletedActionSelection() {
        let existingPairs = Set(
            contributingActionsForOutcome.map { "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)" }
        )
        selectedCompletedArchiveActionIDs = Set(
            completedActionCandidates
                .filter { existingPairs.contains("\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)") }
                .map(\.id)
        )
        filterConnectedBlocksOnly = hasContributingActionsOutsideConnectedBlocks ? false : true
    }

    private func applySelectedCompletedActions() {
        let selected = completedActionCandidates.filter { selectedCompletedArchiveActionIDs.contains($0.id) }
        let candidatePairByID = Dictionary(
            uniqueKeysWithValues: completedActionCandidates.map { ($0.id, "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)") }
        )
        let selectedPairs = Set(selected.map { "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)" })
        let candidatePairs = Set(candidatePairByID.values)

        let existingRows = contributingActionsForOutcome
        let existingPairs = Set(existingRows.map { "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)" })

        for row in selected {
            let key = "\(row.archiveId.uuidString)|\(row.plannedChunkActionId.uuidString)"
            guard !existingPairs.contains(key) else { continue }
            modelContext.insert(
                ActionBlocksReflectionOutcomeContribution(
                    archiveId: row.archiveId,
                    weekStart: row.weekStart,
                    outcomeId: outcome.outcome_id,
                    plannedChunkActionId: row.plannedChunkActionId,
                    actionText: row.actionText,
                    completedAt: row.completedAt
                )
            )
        }

        for existing in existingRows {
            let key = "\(existing.archiveId.uuidString)|\(existing.plannedChunkActionId.uuidString)"
            if candidatePairs.contains(key) && !selectedPairs.contains(key) {
                RecentlyDeletedStore.trash(existing, in: modelContext)
            }
        }
        try? modelContext.save()
    }

    private func blockKeyForContribution(_ row: ActionBlocksReflectionOutcomeContribution) -> String? {
        guard let archivedAction = allReflectionActions.first(where: {
            $0.archiveId == row.archiveId && $0.plannedChunkActionId == row.plannedChunkActionId
        }) else { return nil }
        return "\(archivedAction.archiveId.uuidString)|\(archivedAction.plannedChunkId.uuidString)"
    }

    private func compactDate(_ date: Date) -> String {
        let cal = Calendar.current
        let nowYear = cal.component(.year, from: .now)
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == nowYear {
            formatter.setLocalizedDateFormatFromTemplate("Md")
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Mdyy")
        }
        return formatter.string(from: date)
    }

}

struct OutcomeTargetSection: View {
    @Binding var endDate: Date
    @Binding var selectedDuration: Int
    let effectiveStartDate: Date
    @Binding var isShowingDatePicker: Bool

    var body: some View {
        Section("Target") {
            HStack {
                Text("End Date")
                    .foregroundColor(.secondary)
                Spacer()
                Button {
                    isShowingDatePicker = true
                } label: {
                    Text(endDate, style: .date)
                        .foregroundColor(.accentColor)
                }
            }
        }
        .sheet(isPresented: $isShowingDatePicker) {
            NavigationStack {
                DatePicker(
                    "End Date",
                    selection: $endDate,
                    in: Calendar.current.date(byAdding: .day, value: 1, to: effectiveStartDate)!...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
                .padding()
                .navigationTitle("Target Date")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            isShowingDatePicker = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: endDate) { _, newEndDate in
            let start = Calendar.current.startOfDay(for: effectiveStartDate)
            let end = Calendar.current.startOfDay(for: newEndDate)
            selectedDuration = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)
        }
    }
}

private struct OutcomeStartedOnSection: View {
    let startDate: Date

    var body: some View {
        Section("Start") {
            HStack {
                Text("Start Date")
                    .foregroundColor(.secondary)
                Spacer()
                Text(startDate, style: .date)
                    .foregroundColor(.secondary)
            }
        }
    }
}
