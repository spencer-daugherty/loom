import SwiftUI
import SwiftData

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
    @State private var isMeasurable = false
    @State private var measureGoal: String = ""
    @State private var measureCurrent: String = ""
    @State private var measureDirection: MeasureDirection = .up
    @State private var measureFormat: MeasureFormat = .number
    
    private let outcome: Outcomes?
    private let outcomeMeasure: OutcomesMeasure?

    private var hasChanges: Bool {
        if let outcome {
            let measureChanged = if let outcomeMeasure {
                isMeasurable != (outcomeMeasure.measure_amt != 0) ||
                (isMeasurable && measureGoal != String(outcomeMeasure.measure_amt)) ||
                (isMeasurable && measureCurrent != String(outcomeMeasure.measure)) ||
                (isMeasurable && measureDirection.rawValue != (outcomeMeasure.direction ?? MeasureDirection.up.rawValue)) ||
                (isMeasurable && measureFormat.rawValue != (outcomeMeasure.format ?? MeasureFormat.number.rawValue))
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
        goal.isEmpty || selectedCategory == .placeholder || (isMeasurable && (measureGoal.isEmpty || measureCurrent.isEmpty || Double(measureGoal) == nil || Double(measureCurrent) == nil))
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
    
    enum MeasureDirection: String, CaseIterable, Identifiable {
        case up = "↑"
        case down = "↓"
        
        var id: String { rawValue }
        
        var symbol: String { rawValue }
    }

    init(outcome: Outcomes? = nil, outcomeMeasure: OutcomesMeasure? = nil) {
        self.outcome = outcome
        self.outcomeMeasure = outcomeMeasure
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
                _measureDirection = State(initialValue: MeasureDirection(rawValue: outcomeMeasure.direction ?? MeasureDirection.up.rawValue) ?? .up)
                _measureFormat = State(initialValue: MeasureFormat(rawValue: outcomeMeasure.format ?? MeasureFormat.number.rawValue) ?? .number)
            } else {
                _isMeasurable = State(initialValue: false)
                _measureGoal = State(initialValue: "")
                _measureCurrent = State(initialValue: "")
                _measureDirection = State(initialValue: .up)
                _measureFormat = State(initialValue: .number)
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
            _measureDirection = State(initialValue: .up)
            _measureFormat = State(initialValue: .number)
        }
    }

    var body: some View {
        NavigationView {
            Form {
                ChartSection(
                    isMeasurable: isMeasurable,
                    hasOutcome: outcome != nil,
                    outcomeId: outcome?.outcome_id,
                    measureCurrent: $measureCurrent,
                    measureGoal: $measureGoal,
                    measureFormat: $measureFormat,
                    measureDirection: $measureDirection
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
                    measureCurrent: $measureCurrent,
                    measureDirection: $measureDirection,
                    measureFormat: $measureFormat
                )
                CategorySection(selectedCategory: $selectedCategory)
                if outcome != nil {
                    DeleteOutcomeSection(
                        isShowingDeleteOutcomeAlert: $isShowingDeleteOutcomeAlert,
                        showCompleteButton: showCompleteButton
                    )
                }
            }
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
                                format: outcomeMeasure.format
                            )
                            modelContext.insert(archivedMeasure)
                            modelContext.delete(outcomeMeasure)
                        }
                        
                        modelContext.delete(outcome)
                        try? modelContext.save()
                    }
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to permanently delete this outcome?")
            }
        }
        .interactiveDismissDisabled(outcome != nil ? hasChanges : showDeleteButton)
    }

    private func saveOutcome() {
        let start = Calendar.current.startOfDay(for: startNow ? .now : startDate)
        let normalizedEndDate = Calendar.current.startOfDay(for: endDate)
        let measureValue = isMeasurable ? (Double(measureGoal) ?? 0.0) : 0.0
        let currentValue = isMeasurable ? (Double(measureCurrent) ?? 0.0) : 0.0
        let directionValue = isMeasurable ? measureDirection.rawValue : nil
        let formatValue = isMeasurable ? measureFormat.rawValue : nil

        if let existingOutcome = outcome {
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
            
            if isMeasurable {
                if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == existingOutcome.outcome_id }) {
                    existingMeasure.measure = currentValue
                    existingMeasure.measure_amt = measureValue
                    existingMeasure.measuredAt = .now
                    existingMeasure.measure_updated = .now
                    existingMeasure.direction = directionValue
                    existingMeasure.format = formatValue
                } else {
                    let newMeasure = OutcomesMeasure(
                        outcome_id: existingOutcome.outcome_id,
                        measure: currentValue,
                        measuredAt: .now,
                        measure_amt: measureValue,
                        measure_updated: .now,
                        direction: directionValue,
                        format: formatValue
                    )
                    modelContext.insert(newMeasure)
                }
            } else {
                if let existingMeasure = try? modelContext.fetch(FetchDescriptor<OutcomesMeasure>()).first(where: { $0.outcome_id == existingOutcome.outcome_id }) {
                    modelContext.delete(existingMeasure)
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
            modelContext.insert(newOutcome)
            
            if isMeasurable {
                let newMeasure = OutcomesMeasure(
                    outcome_id: newOutcome.outcome_id,
                    measure: currentValue,
                    measuredAt: .now,
                    measure_amt: measureValue,
                    measure_updated: .now,
                    direction: directionValue,
                    format: formatValue
                )
                modelContext.insert(newMeasure)
            }
        }
        
        try? modelContext.save()
        dismiss()
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
}

struct ChartSection: View {
    let isMeasurable: Bool
    let hasOutcome: Bool
    let outcomeId: UUID?
    @Binding var measureCurrent: String
    @Binding var measureGoal: String
    @Binding var measureFormat: ObjectivesAddView.MeasureFormat
    @Binding var measureDirection: ObjectivesAddView.MeasureDirection

    var body: some View {
        Group {
            if isMeasurable && hasOutcome && outcomeId != nil {
                VStack(alignment: .leading, spacing: 16) {
                    ObjectivesAddViewChart(outcome_id: outcomeId!)
                }
                .padding(.vertical, 8)
            }
        }
    }
}

struct GoalSection: View {
    @Binding var goal: String

    var body: some View {
        Section("Goal") {
            TextField("Enter your goal", text: $goal)
        }
    }
}

struct ReasonsSection: View {
    @Binding var reasons: String

    var body: some View {
        Section("Reasons") {
            TextField("Why is this important?", text: $reasons)
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
    @Binding var measureCurrent: String
    @Binding var measureDirection: ObjectivesAddView.MeasureDirection
    @Binding var measureFormat: ObjectivesAddView.MeasureFormat

    var body: some View {
        Section("Measure") {
            Toggle("Outcome is measurable", isOn: $isMeasurable)
            
            if isMeasurable {
                Picker("Format", selection: $measureFormat) {
                    ForEach(ObjectivesAddView.MeasureFormat.allCases) { format in
                        Text(format.displayName).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                
                HStack {
                    Text("Goal")
                    Spacer()
                    if measureFormat == .dollars {
                        Text("$")
                    }
                    TextField("Goal", text: $measureGoal)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: measureGoal) { _, newValue in
                            measureGoal = newValue.filter { "0123456789.".contains($0) }
                            if newValue.components(separatedBy: ".").count > 2 {
                                measureGoal = String(newValue.prefix(while: { $0 != "." }) + newValue.drop(while: { $0 != "." }).prefix(2))
                            }
                        }
                    Text(measureFormat.suffix)
                }
                
                HStack {
                    Text("Current")
                    Spacer()
                    if measureFormat == .dollars {
                        Text("$")
                    }
                    TextField("Current", text: $measureCurrent)
                        .keyboardType(.decimalPad)
                        .multilineTextAlignment(.trailing)
                        .frame(width: 100)
                        .onChange(of: measureCurrent) { _, newValue in
                            measureCurrent = newValue.filter { "0123456789.".contains($0) }
                            if newValue.components(separatedBy: ".").count > 2 {
                                measureCurrent = String(newValue.prefix(while: { $0 != "." }) + newValue.drop(while: { $0 != "." }).prefix(2))
                            }
                        }
                    Text(measureFormat.suffix)
                }
                
                HStack {
                    Text("Direction")
                    Spacer()
                    Picker("Direction", selection: $measureDirection) {
                        ForEach(ObjectivesAddView.MeasureDirection.allCases) { direction in
                            Text(direction.symbol).tag(direction)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 100)
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
            .modelContainer(for: [Outcomes.self, OutcomesArchive.self, OutcomesMeasure.self, OutcomesMeasureArchive.self], inMemory: true)
    }
}
