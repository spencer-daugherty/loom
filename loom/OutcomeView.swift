import SwiftUI
import SwiftData

struct OutcomeView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

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
    @State private var isShowingCompletedActionSheet = false
    @State private var filterConnectedBlocksOnly = true
    @State private var selectedCompletedArchiveActionIDs: Set<UUID> = []
    @State private var isMeasurable = false
    @State private var measureGoal: String = ""
    @State private var measureCurrent: String = ""
    @State private var measureFormat: ObjectivesAddView.MeasureFormat = .number
    @State private var measureUnit: String = ObjectivesAddView.UnitOption.defaultUnit
    @State private var measureDecimalPlaces: Int = 0

    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]
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
        let measureChanged = if let outcomeMeasure {
            isMeasurable != (outcomeMeasure.measure_amt != 0) ||
            (isMeasurable && measureGoal != String(outcomeMeasure.measure_amt)) ||
            (isMeasurable && measureFormat.rawValue != (outcomeMeasure.format ?? ObjectivesAddView.MeasureFormat.number.rawValue)) ||
            (isMeasurable && measureUnit != (outcomeMeasure.unit ?? ObjectivesAddView.UnitOption.defaultUnit)) ||
            (isMeasurable && measureDecimalPlaces != (outcomeMeasure.decimalPlaces ?? 0))
        } else {
            isMeasurable
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
        goal.isEmpty || selectedCategory == .placeholder || (isMeasurable && (measureGoal.isEmpty || Double(measureGoal) == nil))
    }

    private var daysLeft: Int {
        let components = Calendar.current.dateComponents([.day], from: .now, to: endDate)
        return max(0, components.day ?? 0)
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
                            .foregroundColor(.black)
                        Text("days left")
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lightenedCategoryColor(for: selectedCategory.rawValue))
                    )
                    .frame(height: 44)

                    if isMeasurable, let current = Double(measureCurrent), let goalAmount = Double(measureGoal), goalAmount != 0 {
                        let startMeasure = allMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id })?.measure ?? current
                        MeasurableOutcomeBox(
                            measure: current,
                            measuredAt: latestMeasureDate(),
                            measureAmt: goalAmount,
                            endDate: endDate,
                            format: measureFormat.rawValue
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
                ForEach(contributingActionsForOutcome, id: \.id) { item in
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
            }
        }
    }

    private var formContent: some View {
        Form {
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
                effectiveStartDate: effectiveStartDate
            )
            MeasureSection(
                isMeasurable: $isMeasurable,
                measureGoal: $measureGoal,
                measureFormat: $measureFormat,
                measureDecimalPlaces: $measureDecimalPlaces
            )
            contributingActionsSection
            CategorySection(selectedCategory: $selectedCategory)
            DeleteOutcomeSection(
                isShowingDeleteOutcomeAlert: $isShowingDeleteOutcomeAlert,
                showCompleteButton: showCompleteButton
            )
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
                Text("Are you sure you want to delete this outcome? It will be available for 30 days in account management.")
            }
            .onChange(of: isMeasurable) { _, newValue in
                guard newValue else { return }
                if measureGoal.isEmpty {
                    measureGoal = "100"
                }
            }
            .onAppear {
                hydrateMeasureFromLatestEntry()
            }
            .onDisappear {
                if hasChanges && !isSaveDisabled {
                    saveOutcome()
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") {
                        hideKeyboard()
                    }
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
        .onChange(of: isShowingAddMeasureSheet) { _, showing in
            if !showing {
                hydrateMeasureFromLatestEntry()
            }
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

    private func saveOutcome() {
        let previousEndDate = outcome.end
        let start = Calendar.current.startOfDay(for: startNow ? .now : startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        let measureValue = isMeasurable ? (Double(measureGoal) ?? 0.0) : 0.0
        let formatValue = isMeasurable ? measureFormat.rawValue : nil
        let unitValue = isMeasurable ? measureUnit : nil
        let decimalPlacesValue = isMeasurable ? (measureFormat == .dollars ? 2 : measureDecimalPlaces) : nil

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
                    let day = Calendar.current.startOfDay(for: .now)
                    let duplicateExists = allMeasureEntries.contains {
                        $0.outcome_id == outcome.outcome_id &&
                        Calendar.current.isDate($0.measuredAt, inSameDayAs: day) &&
                        $0.measure == existingMeasure.measure &&
                        $0.measure_amt == measureValue
                    }
                    if !duplicateExists {
                        modelContext.insert(
                            OutcomesMeasureEntry(
                                outcome_id: outcome.outcome_id,
                                measure: existingMeasure.measure,
                                measure_amt: measureValue,
                                measuredAt: day,
                                createdAt: .now,
                                format: formatValue,
                                unit: unitValue,
                                decimalPlaces: decimalPlacesValue
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

    private func hydrateMeasureFromLatestEntry() {
        let entries = allMeasureEntries.filter { $0.outcome_id == outcome.outcome_id }
        let latest = entries.max(by: { $0.measuredAt < $1.measuredAt })
        let snapshot = outcomeMeasure

        let goalSource = snapshot?.measure_amt ?? latest?.measure_amt ?? 0
        let currentSource = latest?.measure ?? snapshot?.measure ?? 0
        let formatSource = snapshot?.format ?? latest?.format
        let unitSource = snapshot?.unit ?? latest?.unit
        let decimalSource = snapshot?.decimalPlaces ?? latest?.decimalPlaces ?? 0

        if goalSource != 0 {
            let places = min(3, max(0, decimalSource))
            measureGoal = String(format: "%.\(places)f", goalSource)
                .replacingOccurrences(of: places == 0 ? ".0" : "", with: "")
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

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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
    @State private var isShowingDatePicker = false

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
