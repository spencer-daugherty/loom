import SwiftUI
import SwiftData

private func sanitizeDecimalInput(_ input: String, maxFractionDigits: Int = 4) -> String {
    var out = ""
    var seenDot = false
    var fractionCount = 0
    for ch in input {
        if ch.isWholeNumber {
            if seenDot {
                if fractionCount < maxFractionDigits {
                    out.append(ch)
                    fractionCount += 1
                }
            } else {
                out.append(ch)
            }
        } else if ch == "." && !seenDot {
            seenDot = true
            out.append(ch)
        }
    }
    return out
}

private func parseFormattedDecimal(_ input: String) -> Double? {
    Double(input.replacingOccurrences(of: ",", with: ""))
}

private func groupedDecimalString(_ value: Double, fractionDigits: Int) -> String {
    let places = max(0, min(3, fractionDigits))
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.minimumFractionDigits = places
    formatter.maximumFractionDigits = places
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)
}

private func sanitizeAndFormatDecimalInput(_ input: String, maxFractionDigits: Int = 4) -> String {
    let clean = sanitizeDecimalInput(input.replacingOccurrences(of: ",", with: ""), maxFractionDigits: maxFractionDigits)
    guard !clean.isEmpty else { return "" }
    let hasDot = clean.contains(".")
    let parts = clean.split(separator: ".", omittingEmptySubsequences: false)
    let intPartRaw = String(parts.first ?? "")
    let fractionPart = parts.count > 1 ? String(parts[1]) : ""
    let intValue = Int(intPartRaw) ?? 0
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.minimumFractionDigits = 0
    formatter.maximumFractionDigits = 0
    let groupedInt = formatter.string(from: NSNumber(value: intValue)) ?? intPartRaw
    if hasDot {
        return groupedInt + "." + fractionPart
    }
    return groupedInt
}

struct ObjectivesAddView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var goal: String
    @State private var reasons: String
    @State private var selectedDuration: Int
    @State private var startNow: Bool
    @State private var startDate: Date
    @State private var endDate: Date
    @State private var selectedCategory: Category
    @State private var isShowingDeleteAlert = false
    @State private var isShowingDeleteOutcomeAlert = false
    @State private var isShowingAddMeasureSheet = false
    @State private var isMeasurable = false
    @State private var measureGoal: String = ""
    @State private var measureCurrent: String = ""
    @State private var measureFormat: MeasureFormat = .number
    @State private var measureUnit: String = UnitOption.defaultUnit
    @State private var measureDecimalPlaces: Int = 0
    let onSaved: ((UUID) -> Void)?
    
    private let outcome: Outcomes?
    private let outcomeMeasure: OutcomesMeasure?
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]

    private var hasChanges: Bool {
        if let outcome {
            let measureChanged = if let outcomeMeasure {
                isMeasurable != (outcomeMeasure.measure_amt != 0) ||
                (isMeasurable && measureGoal != String(outcomeMeasure.measure_amt)) ||
                (isMeasurable && measureFormat.rawValue != (outcomeMeasure.format ?? MeasureFormat.number.rawValue)) ||
                (isMeasurable && measureUnit != (outcomeMeasure.unit ?? UnitOption.defaultUnit)) ||
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
        return !goal.isEmpty || !reasons.isEmpty || selectedDuration != 30 || !startNow || startDate != .now || endDate != Calendar.current.date(byAdding: .day, value: 30, to: .now)! || selectedCategory != .placeholder || isMeasurable
    }

    private var showDeleteButton: Bool {
        outcome != nil ? hasChanges : (!goal.isEmpty || !reasons.isEmpty || isMeasurable)
    }

    private var isSaveDisabled: Bool {
        goal.isEmpty || selectedCategory == .placeholder || (isMeasurable && (measureGoal.isEmpty || parseFormattedDecimal(measureGoal) == nil))
    }

    private var effectiveStartDate: Date {
        Calendar.current.startOfDay(for: startNow ? .now : startDate)
    }

    private var isStartEditable: Bool {
        if let outcome {
            return Calendar.current.startOfDay(for: outcome.start) > Calendar.current.startOfDay(for: .now)
        }
        return true
    }

    private var showCompleteButton: Bool {
        if let outcome {
            return Calendar.current.startOfDay(for: outcome.start) <= Calendar.current.startOfDay(for: .now)
        }
        return false
    }

    enum Category: String, CaseIterable, Identifiable {
        case placeholder = "select fulfillment category"
        case career = "Career & Business"
        case leadership = "Leadership & Impact"
        case wealth = "Wealth & Lifestyle"
        case mind = "Mind & Meaning"
        case love = "Love & Relationships"
        case health = "Health & Vitality"

        var id: String { rawValue }

        var color: Color {
            switch self {
            case .placeholder: return .gray
            case .career: return .blue
            case .leadership: return .indigo
            case .wealth: return .green
            case .mind: return .purple
            case .love: return .red
            case .health: return .orange
            }
        }
    }
    
    enum MeasureFormat: String, CaseIterable, Identifiable {
        case number = "Number"
        case percentage = "Percentage"
        case dollars = "Dollars"
        
        var id: String { rawValue }
        
        var displayName: String {
            switch self {
            case .number: return "123"
            case .percentage: return "%"
            case .dollars: return "$"
            }
        }
        
        var prefix: String {
            switch self {
            case .number, .percentage: return ""
            case .dollars: return "$"
            }
        }
        
        var suffix: String {
            switch self {
            case .number, .dollars: return ""
            case .percentage: return "%"
            }
        }
    }

    struct UnitOption: Identifiable, Hashable {
        let id: String
        let display: String

        static let all: [UnitOption] = [
            .init(id: "none", display: "None"),
            .init(id: "lbs", display: "lbs"),
            .init(id: "oz", display: "oz"),
            .init(id: "tons", display: "tons"),
            .init(id: "in", display: "in"),
            .init(id: "ft", display: "ft"),
            .init(id: "yd", display: "yd"),
            .init(id: "mi", display: "mi"),
            .init(id: "sq ft", display: "sq ft"),
            .init(id: "acres", display: "acres"),
            .init(id: "fl oz", display: "fl oz"),
            .init(id: "cups", display: "cups"),
            .init(id: "pt", display: "pt"),
            .init(id: "qt", display: "qt"),
            .init(id: "gal", display: "gal"),
            .init(id: "mph", display: "mph"),
            .init(id: "bpm", display: "bpm"),
            .init(id: "steps", display: "steps"),
            .init(id: "cal", display: "cal"),
            .init(id: "hours", display: "hours"),
            .init(id: "minutes", display: "minutes"),
            .init(id: "days", display: "days"),
            .init(id: "weeks", display: "weeks"),
            .init(id: "months", display: "months"),
            .init(id: "years", display: "years"),
            .init(id: "reps", display: "reps"),
            .init(id: "sessions", display: "sessions"),
            .init(id: "visits", display: "visits"),
            .init(id: "clients", display: "clients"),
            .init(id: "sales", display: "sales"),
            .init(id: "leads", display: "leads"),
            .init(id: "calls", display: "calls"),
            .init(id: "emails", display: "emails"),
            .init(id: "tasks", display: "tasks"),
            .init(id: "books", display: "books"),
            .init(id: "pages", display: "pages"),
            .init(id: "courses", display: "courses"),
            .init(id: "projects", display: "projects"),
            .init(id: "deliverables", display: "deliverables"),
            .init(id: "followers", display: "followers"),
            .init(id: "subscribers", display: "subscribers"),
            .init(id: "views", display: "views"),
            .init(id: "downloads", display: "downloads"),
            .init(id: "streak days", display: "streak days")
        ]

        static let defaultUnit = "none"
    }

    init(outcome: Outcomes? = nil, outcomeMeasure: OutcomesMeasure? = nil, onSaved: ((UUID) -> Void)? = nil) {
        self.outcome = outcome
        self.outcomeMeasure = outcomeMeasure
        self.onSaved = onSaved
        if let outcome {
            _goal = State(initialValue: outcome.outcome)
            _reasons = State(initialValue: outcome.reasons)
            _selectedDuration = State(initialValue: Calendar.current.dateComponents([.day], from: outcome.start, to: outcome.end).day ?? 30)
            _startNow = State(initialValue: outcome.start == outcome.updatedAt)
            _startDate = State(initialValue: outcome.start)
            _endDate = State(initialValue: outcome.end)
            _selectedCategory = State(initialValue: Category(rawValue: outcome.category) ?? .placeholder)
            if let outcomeMeasure {
                _isMeasurable = State(initialValue: outcomeMeasure.measure_amt != 0)
                _measureGoal = State(initialValue: String(outcomeMeasure.measure_amt))
                _measureCurrent = State(initialValue: String(outcomeMeasure.measure))
                _measureFormat = State(initialValue: MeasureFormat(rawValue: outcomeMeasure.format ?? MeasureFormat.number.rawValue) ?? .number)
                _measureUnit = State(initialValue: outcomeMeasure.unit ?? UnitOption.defaultUnit)
                _measureDecimalPlaces = State(initialValue: outcomeMeasure.decimalPlaces ?? 0)
            } else {
                _isMeasurable = State(initialValue: false)
                _measureGoal = State(initialValue: "")
                _measureCurrent = State(initialValue: "")
                _measureFormat = State(initialValue: .number)
                _measureUnit = State(initialValue: UnitOption.defaultUnit)
                _measureDecimalPlaces = State(initialValue: 0)
            }
        } else {
            _goal = State(initialValue: "")
            _reasons = State(initialValue: "")
            _selectedDuration = State(initialValue: 30)
            _startNow = State(initialValue: true)
            _startDate = State(initialValue: .now)
            _endDate = State(initialValue: Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 30, to: .now)!))
            _selectedCategory = State(initialValue: .placeholder)
            _isMeasurable = State(initialValue: false)
            _measureGoal = State(initialValue: "")
            _measureCurrent = State(initialValue: "")
            _measureFormat = State(initialValue: .number)
            _measureUnit = State(initialValue: UnitOption.defaultUnit)
            _measureDecimalPlaces = State(initialValue: 0)
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                ChartSection(
                    isMeasurable: isMeasurable,
                    hasOutcome: outcome != nil,
                    outcomeId: outcome?.outcome_id,
                    measureGoal: $measureGoal,
                    measureFormat: $measureFormat,
                    measureUnit: $measureUnit,
                    measureDecimalPlaces: $measureDecimalPlaces
                )
                ChartActionsSection(
                    isMeasurable: isMeasurable,
                    hasOutcome: outcome != nil,
                    outcomeId: outcome?.outcome_id,
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
                    StartedOnSection(startDate: outcome!.start)
                } else {
                    StartSection(startNow: $startNow, startDate: $startDate, selectedDuration: selectedDuration, endDate: $endDate)
                }
                TargetSection(selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
                MeasureSection(
                    isMeasurable: $isMeasurable,
                    measureGoal: $measureGoal,
                    measureFormat: $measureFormat,
                    measureDecimalPlaces: $measureDecimalPlaces
                )
                CategorySection(selectedCategory: $selectedCategory)
                if outcome != nil {
                    DeleteOutcomeSection(
                        isShowingDeleteOutcomeAlert: $isShowingDeleteOutcomeAlert,
                        showCompleteButton: showCompleteButton
                    )
                }
            }
            .navigationTitle(outcome == nil ? "Add Outcome" : (goal.isEmpty ? "Outcome" : goal))
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(outcome != nil && !hasChanges ? "Close" : "Cancel") {
                        if showDeleteButton {
                            isShowingDeleteAlert = true
                        } else {
                            dismiss()
                        }
                    }
                    .foregroundColor(showDeleteButton ? .red : .primary)
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(outcome == nil ? "Save" : "Update") {
                        saveOutcome()
                    }
                    .disabled(isSaveDisabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button {
                        hideKeyboard()
                    } label: {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.blue)
                    }
                }
            }
            .alert("Discard Changes?", isPresented: $isShowingDeleteAlert) {
                Button("Discard", role: .destructive) { dismiss() }
                Button("Keep Editing", role: .cancel) {}
            } message: {
                Text("Are you sure you want to discard your changes?")
            }
            .alert("Delete Outcome?", isPresented: $isShowingDeleteOutcomeAlert) {
                Button("Delete", role: .destructive) {
                    if let outcome {
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
                        
                        if let outcomeMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == outcome.outcome_id }) {
                            let archivedMeasure = OutcomesMeasureArchive(
                                outcome_id: outcomeMeasure.outcome_id,
                                measure: outcomeMeasure.measure,
                                measuredAt: outcomeMeasure.measuredAt,
                                measure_amt: outcomeMeasure.measure_amt,
                                measure_updated: outcomeMeasure.measure_updated,
                                archivedAt: .now,
                                direction: outcomeMeasure.direction,
                                format: outcomeMeasure.format,
                                unit: outcomeMeasure.unit,
                                decimalPlaces: outcomeMeasure.decimalPlaces
                            )
                            modelContext.insert(archivedMeasure)
                        }
                        
                        RecentlyDeletedStore.trash(outcome, in: modelContext, source: "Outcome")
                        try? modelContext.save()
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this outcome? It will be available for 30 days in account management.")
            }
        }
        .interactiveDismissDisabled(outcome != nil ? hasChanges : showDeleteButton)
        .onAppear {
            hydrateMeasureFromLatestEntry()
        }
        .sheet(isPresented: $isShowingAddMeasureSheet) {
            if let outcomeID = outcome?.outcome_id {
                AddOutcomeMeasureSheet(
                    outcomeID: outcomeID,
                    formatRaw: measureFormat.rawValue,
                    unitRaw: measureUnit,
                    decimalPlaces: measureDecimalPlaces
                )
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    private func saveOutcome() {
        let start = Calendar.current.startOfDay(for: startNow ? .now : startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        let measureValue = isMeasurable ? (parseFormattedDecimal(measureGoal) ?? 0.0) : 0.0
        let formatValue = isMeasurable ? measureFormat.rawValue : nil
        let unitValue = isMeasurable ? measureUnit : nil
        let decimalPlacesValue = isMeasurable ? (measureFormat == .dollars ? 2 : measureDecimalPlaces) : nil
        var newlyCreatedOutcomeID: UUID?

        if let existingOutcome = outcome {
            let previousEndDate = existingOutcome.end
            if existingOutcome.outcome != goal ||
               existingOutcome.reasons != reasons ||
               existingOutcome.start != start ||
               existingOutcome.end != normalizedEndDate ||
               existingOutcome.category != selectedCategory.rawValue {
                let archivedOutcome = OutcomesArchive(
                    outcome_id: existingOutcome.outcome_id,
                    category: existingOutcome.category,
                    updatedAt: existingOutcome.updatedAt,
                    outcome: existingOutcome.outcome,
                    reasons: existingOutcome.reasons,
                    start: existingOutcome.start,
                    end: existingOutcome.end,
                    rank: existingOutcome.rank,
                    archivedAt: .now,
                    format: existingOutcome.format
                )
                modelContext.insert(archivedOutcome)
            }

            existingOutcome.category = selectedCategory.rawValue
            existingOutcome.updatedAt = .now
            existingOutcome.outcome = goal
            existingOutcome.reasons = reasons
            existingOutcome.start = start
            existingOutcome.end = normalizedEndDate
            existingOutcome.format = formatValue

            if previousEndDate != normalizedEndDate {
                modelContext.insert(
                    OutcomeAnalyticsEvent(
                        outcome_id: existingOutcome.outcome_id,
                        eventType: "target_changed",
                        oldTargetDate: previousEndDate,
                        newTargetDate: normalizedEndDate,
                        source: "ObjectivesAddView"
                    )
                )
            }
            
            if isMeasurable {
                if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == existingOutcome.outcome_id }) {
                    let oldGoal = existingMeasure.measure_amt
                    if oldGoal != measureValue {
                        modelContext.insert(
                            OutcomeAnalyticsEvent(
                                outcome_id: existingOutcome.outcome_id,
                                eventType: "goal_changed",
                                oldMeasure: existingMeasure.measure,
                                oldGoal: oldGoal,
                                newGoal: measureValue,
                                source: "ObjectivesAddView"
                            )
                        )
                    }
                    existingMeasure.measure_amt = measureValue
                    existingMeasure.measure_updated = .now
                    existingMeasure.direction = nil
                    existingMeasure.format = formatValue
                    existingMeasure.unit = unitValue
                    existingMeasure.decimalPlaces = decimalPlacesValue
                } else {
                    let newMeasure = OutcomesMeasure(
                        outcome_id: existingOutcome.outcome_id,
                        measure: 0,
                        measuredAt: existingOutcome.start,
                        measure_amt: measureValue,
                        measure_updated: .now,
                        direction: nil,
                        format: formatValue,
                        unit: unitValue,
                        decimalPlaces: decimalPlacesValue
                    )
                    modelContext.insert(newMeasure)
                }
            } else {
                if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == existingOutcome.outcome_id }) {
                    RecentlyDeletedStore.trash(existingMeasure, in: modelContext)
                }
            }
        } else {
            let newOutcome = Outcomes(
                outcome_id: UUID(),
                category: selectedCategory.rawValue,
                updatedAt: .now,
                outcome: goal,
                reasons: reasons,
                start: start,
                end: normalizedEndDate,
                rank: 0,
                format: formatValue
            )
            newlyCreatedOutcomeID = newOutcome.outcome_id
            modelContext.insert(newOutcome)
            
            if isMeasurable {
                let newMeasure = OutcomesMeasure(
                    outcome_id: newOutcome.outcome_id,
                    measure: 0,
                    measuredAt: start,
                    measure_amt: measureValue,
                    measure_updated: .now,
                    direction: nil,
                    format: formatValue,
                    unit: unitValue,
                    decimalPlaces: decimalPlacesValue
                )
                modelContext.insert(newMeasure)
            }
        }
        
        try? modelContext.save()
        if let newOutcomeID = newlyCreatedOutcomeID {
            onSaved?(newOutcomeID)
        }
        dismiss()
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func hydrateMeasureFromLatestEntry() {
        guard let outcomeID = outcome?.outcome_id else { return }
        guard let latest = allMeasureEntries.filter({ $0.outcome_id == outcomeID }).max(by: { $0.measuredAt < $1.measuredAt }) else { return }
        if latest.measure_amt != 0 {
            let places = min(3, max(0, latest.decimalPlaces ?? measureDecimalPlaces))
            measureGoal = groupedDecimalString(latest.measure_amt, fractionDigits: places)
        }
        if latest.measure != 0 {
            measureCurrent = latest.measure.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(latest.measure)) : String(latest.measure)
        }
        if let formatRaw = latest.format, let format = MeasureFormat(rawValue: formatRaw) {
            measureFormat = format
        }
        if let unit = latest.unit {
            measureUnit = unit
        }
        if let places = latest.decimalPlaces {
            measureDecimalPlaces = min(3, max(0, places))
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }
}

struct ChartSection: View {
    let isMeasurable: Bool
    let hasOutcome: Bool
    let outcomeId: UUID?
    @Binding var measureGoal: String
    @Binding var measureFormat: ObjectivesAddView.MeasureFormat
    @Binding var measureUnit: String
    @Binding var measureDecimalPlaces: Int

    var body: some View {
        Group {
            if isMeasurable && hasOutcome && outcomeId != nil {
                Section {
                    VStack(alignment: .leading, spacing: 16) {
                        ObjectivesAddViewChart(
                            outcome_id: outcomeId!,
                            formatRaw: measureFormat.rawValue,
                            unitRaw: measureUnit,
                            decimalPlaces: measureDecimalPlaces
                        )
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
}

struct ChartActionsSection: View {
    let isMeasurable: Bool
    let hasOutcome: Bool
    let outcomeId: UUID?
    @Binding var measureFormat: ObjectivesAddView.MeasureFormat
    @Binding var measureUnit: String
    @Binding var measureDecimalPlaces: Int
    let onAddMeasure: () -> Void
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]

    private var addMeasureTitle: String {
        guard let outcomeId else { return "Add Measure" }
        let hasAnyMeasureEntries = allMeasureEntries.contains { $0.outcome_id == outcomeId }
        return hasAnyMeasureEntries ? "Add Measure" : "Add Starting Measure"
    }

    var body: some View {
        Group {
            if isMeasurable && hasOutcome, let outcomeId {
                Section {
                    Button {
                        onAddMeasure()
                    } label: {
                        Text(addMeasureTitle)
                            .foregroundStyle(Color.accentColor)
                    }

                    NavigationLink {
                        OutcomesAllDataView(
                            outcomeID: outcomeId,
                            formatRaw: measureFormat.rawValue,
                            unitRaw: measureUnit,
                            decimalPlaces: measureDecimalPlaces
                        )
                    } label: {
                        Text("Show All Data")
                    }

                    NavigationLink {
                        DataSourcesPlaceholderView()
                    } label: {
                        Text("Data Sources & Access")
                    }
                }
            }
        }
    }
}

struct GoalSection: View {
    @Binding var goal: String

    var body: some View {
        Section("Goal") {
            TextField("Enter your goal", text: $goal)
                .submitLabel(.done)
        }
    }
}

struct ReasonsSection: View {
    @Binding var reasons: String

    var body: some View {
        Section("Reasons") {
            TextField("Why is this important?", text: $reasons)
                .submitLabel(.done)
        }
    }
}

struct StartedOnSection: View {
    let startDate: Date
    
    var body: some View {
        Section("Start") {
            HStack {
                Text("Start Date")
                    .foregroundColor(.secondary)
                Spacer()
                Text(startDate, style: .date)
                    .foregroundColor(.accentColor)
            }
        }
    }
}

struct StartSection: View {
    @Binding var startNow: Bool
    @Binding var startDate: Date
    let selectedDuration: Int
    @Binding var endDate: Date

    var body: some View {
        Section("Start") {
            Toggle("Today", isOn: $startNow)

            if !startNow {
                DatePicker(
                    "Start Date",
                    selection: $startDate,
                    in: Calendar.current.date(byAdding: .day, value: 1, to: .now)!...,
                    displayedComponents: [.date]
                )
                .datePickerStyle(.graphical)
            }
        }
        .onChange(of: startNow) { _, newValue in
            let newStartDate = newValue ? .now : Calendar.current.startOfDay(for: Calendar.current.date(byAdding: .day, value: 1, to: .now)!)
            startDate = newStartDate
            if let targetDate = Calendar.current.date(byAdding: .day, value: selectedDuration, to: Calendar.current.startOfDay(for: newStartDate)) {
                endDate = Calendar.current.startOfDay(for: targetDate)
            }
        }
        .onChange(of: startDate) { _, newStartDate in
            if let targetDate = Calendar.current.date(byAdding: .day, value: selectedDuration, to: Calendar.current.startOfDay(for: newStartDate)) {
                endDate = Calendar.current.startOfDay(for: targetDate)
            }
        }
    }
}

struct TargetSection: View {
    @Binding var selectedDuration: Int
    @Binding var endDate: Date
    let effectiveStartDate: Date

    var body: some View {
        Section("Target") {
            HStack(spacing: 8) {
                DurationButton(duration: 30, selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
                DurationButton(duration: 60, selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
                DurationButton(duration: 90, selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
                DurationButton(duration: 180, selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
                DurationButton(duration: 365, selectedDuration: $selectedDuration, endDate: $endDate, effectiveStartDate: effectiveStartDate)
            }
            .padding(.vertical, 8)
            
            DatePicker(
                "End Date",
                selection: $endDate,
                in: Calendar.current.date(byAdding: .day, value: 7, to: effectiveStartDate)!...,
                displayedComponents: [.date]
            )
            .datePickerStyle(.graphical)
            .onChange(of: endDate) { _, newEndDate in
                let startOfStartDate = Calendar.current.startOfDay(for: effectiveStartDate)
                let startOfEndDate = Calendar.current.startOfDay(for: newEndDate)
                let daysBetween = Calendar.current.dateComponents([.day], from: startOfStartDate, to: startOfEndDate).day ?? 30
                selectedDuration = [30, 60, 90, 180, 365].contains(daysBetween) ? daysBetween : daysBetween
            }
        }
    }
}

struct MeasureSection: View {
    @Binding var isMeasurable: Bool
    @Binding var measureGoal: String
    @Binding var measureFormat: ObjectivesAddView.MeasureFormat
    @Binding var measureDecimalPlaces: Int

    var body: some View {
        Section("Measure Data") {
            Toggle("Outcome is measurable", isOn: $isMeasurable)
            
            if isMeasurable {
                if measureFormat == .dollars && measureDecimalPlaces != 2 {
                    Color.clear
                        .frame(width: 0, height: 0)
                        .onAppear { measureDecimalPlaces = 2 }
                }
                Picker("Format", selection: $measureFormat) {
                    ForEach(ObjectivesAddView.MeasureFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .onChange(of: measureFormat) { _, newFormat in
                    if newFormat == .dollars {
                        measureDecimalPlaces = 2
                    }
                    guard let value = parseFormattedDecimal(measureGoal) else { return }
                    let places = newFormat == .dollars ? 2 : min(3, max(0, measureDecimalPlaces))
                    measureGoal = groupedDecimalString(value, fractionDigits: places)
                }

                if measureFormat != .dollars {
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
                    }
                    TextField("Goal", text: $measureGoal)
                        .keyboardType(.decimalPad)
                        .submitLabel(.done)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: measureGoal) { _, newValue in
                            let places = measureFormat == .dollars ? 2 : min(3, max(0, measureDecimalPlaces))
                            measureGoal = sanitizeAndFormatDecimalInput(newValue, maxFractionDigits: places)
                        }
                    Text(measureFormat.suffix)
                }
                .onChange(of: measureDecimalPlaces) { _, _ in
                    guard measureFormat != .dollars else { return }
                    guard let value = parseFormattedDecimal(measureGoal) else { return }
                    let places = min(3, max(0, measureDecimalPlaces))
                    measureGoal = groupedDecimalString(value, fractionDigits: places)
                }
                
            }
        }
    }
}

struct DurationButton: View {
    let duration: Int
    @Binding var selectedDuration: Int
    @Binding var endDate: Date
    let effectiveStartDate: Date

    var body: some View {
        Button(action: {
            selectedDuration = duration
            if let targetDate = Calendar.current.date(byAdding: .day, value: duration, to: effectiveStartDate) {
                endDate = Calendar.current.startOfDay(for: targetDate)
            }
        }) {
            VStack {
                Text("\(duration)")
                    .font(.caption)
                    .fontWeight(.semibold)
                Text("days")
                    .font(.caption2)
            }
            .frame(minWidth: 36, minHeight: 36)
        }
        .buttonStyle(.bordered)
        .tint(selectedDuration == duration ? .blue : .gray)
    }
}

struct CategorySection: View {
    @Binding var selectedCategory: ObjectivesAddView.Category

    var body: some View {
        Picker("Category", selection: $selectedCategory) {
            ForEach(ObjectivesAddView.Category.allCases) { category in
                Text(category.rawValue)
                    .foregroundColor(category.color)
                    .fontWeight(category == selectedCategory ? .bold : .regular)
                    .tag(category)
            }
        }
        .pickerStyle(.wheel)
        .frame(maxHeight: 100)
        .listRowBackground(Color.clear)
    }
}

struct DeleteOutcomeSection: View {
    @Binding var isShowingDeleteOutcomeAlert: Bool
    let showCompleteButton: Bool

    var body: some View {
        Section {
            if showCompleteButton {
                Button("Complete") {
                    // Placeholder for future implementation
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

struct ObjectivesAddView_Previews: PreviewProvider {
    static var previews: some View {
        ObjectivesAddView()
            .modelContainer(
                for: [
                    Outcomes.self,
                    OutcomesArchive.self,
                    OutcomesMeasure.self,
                    OutcomesMeasureArchive.self,
                    OutcomesMeasureEntry.self
                ],
                inMemory: true
            )
    }
}
