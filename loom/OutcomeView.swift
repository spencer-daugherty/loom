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
    @State private var isMeasurable = false
    @State private var measureGoal: String = ""
    @State private var measureCurrent: String = ""
    @State private var measureFormat: ObjectivesAddView.MeasureFormat = .number
    @State private var measureUnit: String = ObjectivesAddView.UnitOption.defaultUnit
    @State private var measureDecimalPlaces: Int = 0

    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]
    @Query(sort: \ActionBlocksReflectionOutcomeContribution.completedAt, order: .reverse) private var allContributingActions: [ActionBlocksReflectionOutcomeContribution]

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

    var body: some View {
        NavigationView {
            Form {
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
                                    startMeasure: allMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id })?.measure ?? current
                                )
                                .frame(width: 40, height: 40)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

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
                    StartedOnSection(startDate: outcome.start)
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
                Section("Contributing Actions") {
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
                                    Text("Completed \(shortDate(item.completedAt))")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer(minLength: 0)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }
                CategorySection(selectedCategory: $selectedCategory)
                DeleteOutcomeSection(
                    isShowingDeleteOutcomeAlert: $isShowingDeleteOutcomeAlert,
                    showCompleteButton: Calendar.current.startOfDay(for: outcome.start) <= Calendar.current.startOfDay(for: .now)
                )
            }
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
                        modelContext.delete(existingMeasure)
                    }

                    modelContext.delete(outcome)
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete this outcome?")
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
        }
    }

    private func saveOutcome() {
        let start = Calendar.current.startOfDay(for: startNow ? .now : startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        let measureValue = isMeasurable ? (Double(measureGoal) ?? 0.0) : 0.0
        let formatValue = isMeasurable ? measureFormat.rawValue : nil
        let unitValue = isMeasurable ? measureUnit : nil
        let decimalPlacesValue = isMeasurable ? measureDecimalPlaces : nil

        outcome.category = selectedCategory.rawValue
        outcome.updatedAt = .now
        outcome.outcome = goal
        outcome.reasons = reasons
        outcome.start = start
        outcome.end = normalizedEndDate
        outcome.format = formatValue

        if isMeasurable {
            if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
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
            modelContext.delete(existingMeasure)
        }

        try? modelContext.save()
    }

    private func hydrateMeasureFromLatestEntry() {
        let entries = allMeasureEntries.filter { $0.outcome_id == outcome.outcome_id }
        guard let latest = entries.max(by: { $0.measuredAt < $1.measuredAt }) else { return }

        if latest.measure_amt != 0 {
            let places = min(3, max(0, latest.decimalPlaces ?? 0))
            measureGoal = String(format: "%.\(places)f", latest.measure_amt).replacingOccurrences(of: places == 0 ? ".0" : "", with: "")
        }
        if latest.measure != 0 {
            let places = min(3, max(0, latest.decimalPlaces ?? 0))
            measureCurrent = String(format: "%.\(places)f", latest.measure).replacingOccurrences(of: places == 0 ? ".0" : "", with: "")
        }
        if let formatRaw = latest.format, let format = ObjectivesAddView.MeasureFormat(rawValue: formatRaw) {
            measureFormat = format
        }
        if let unit = latest.unit {
            measureUnit = unit
        }
        if let places = latest.decimalPlaces {
            measureDecimalPlaces = min(3, max(0, places))
        }
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
