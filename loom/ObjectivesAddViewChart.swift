import SwiftUI
import Charts
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

struct ObjectivesAddViewChart: View {
    let outcome_id: UUID
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int

    @Environment(\.modelContext) private var modelContext
    @Query private var entries: [OutcomesMeasureEntry]
    @Query private var legacyMeasures: [OutcomesMeasure]
    @Query private var outcomes: [Outcomes]
    @State private var selectedTimeRange: String = "M"
    @State private var selectedEntryID: UUID? = nil
    @State private var selectedDate: Date? = nil
    @State private var showSuccessPaths: Bool = false
    private let allTimeRanges = ["W", "M", "3M", "6M", "Y"]

    private var availableTimeRanges: [String] {
        guard let outcome = outcomes.first else { return allTimeRanges }
        let start = Calendar.current.startOfDay(for: outcome.start)
        let end = Calendar.current.startOfDay(for: outcome.end)
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)

        let maxIndex: Int
        if days <= 7 { maxIndex = 0 }
        else if days <= 30 { maxIndex = 1 }
        else if days <= 90 { maxIndex = 2 }
        else if days <= 180 { maxIndex = 3 }
        else { maxIndex = 4 }

        return Array(allTimeRanges.prefix(maxIndex + 1))
    }

    init(outcome_id: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcome_id = outcome_id
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let entryPredicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcome_id }
        _entries = Query(filter: entryPredicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .forward)])
        let legacyPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcome_id }
        _legacyMeasures = Query(filter: legacyPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .forward)])
        let outcomePredicate = #Predicate<Outcomes> { $0.outcome_id == outcome_id }
        _outcomes = Query(filter: outcomePredicate)
    }

    private var chartRows: [OutcomesMeasureEntry] {
        if !entries.isEmpty { return entries }
        guard let legacy = legacyMeasures.first else { return [] }
        return [
            OutcomesMeasureEntry(
                outcome_id: legacy.outcome_id,
                measure: legacy.measure,
                measure_amt: legacy.measure_amt,
                measuredAt: legacy.measuredAt,
                createdAt: legacy.measure_updated,
                format: legacy.format,
                unit: legacy.unit,
                decimalPlaces: legacy.decimalPlaces
            )
        ]
    }

    private var visibleRows: [OutcomesMeasureEntry] {
        let range = fullDateRange()
        return chartRows.filter {
            let day = Calendar.current.startOfDay(for: $0.measuredAt)
            return range.contains(day)
        }
    }

    private var selectedEntry: OutcomesMeasureEntry? {
        if let selectedEntryID {
            return chartRows.first(where: { $0.id == selectedEntryID })
        }
        return chartRows.last
    }

    private var outcomeStartDate: Date? {
        outcomes.first.map { Calendar.current.startOfDay(for: $0.start) }
    }

    private var outcomeEndDate: Date? {
        outcomes.first.map { Calendar.current.startOfDay(for: $0.end) }
    }

    private var startValue: Double? {
        chartRows.first?.measure
    }

    private var goalValue: Double? {
        chartRows.last?.measure_amt
    }

    private var latestValue: Double? {
        chartRows.last?.measure
    }

    private var latestDate: Date? {
        chartRows.last.map { Calendar.current.startOfDay(for: $0.measuredAt) }
    }

    private var isBehindGoalPath: Bool? {
        guard
            let start = startValue,
            let goal = goalValue,
            let latest = latestValue,
            let startDate = outcomeStartDate,
            let endDate = outcomeEndDate,
            let currentDate = latestDate
        else { return nil }

        if endDate <= startDate { return nil }

        let total = endDate.timeIntervalSince(startDate)
        let elapsed = min(max(0, currentDate.timeIntervalSince(startDate)), total)
        let progress = elapsed / total
        let expected = start + (goal - start) * progress
        let directionUp = goal >= start

        if directionUp {
            return latest < expected
        } else {
            return latest > expected
        }
    }

    private var latestLoggedDate: Date {
        Calendar.current.startOfDay(for: (chartRows.last?.measuredAt ?? .now))
    }

    private var initialScrollX: Date {
        let halfWindow = visibleDomainLength() / 2
        let proposed = latestLoggedDate.addingTimeInterval(-halfWindow)
        let range = fullDateRange()
        if proposed < range.lowerBound { return range.lowerBound }
        if proposed > range.upperBound { return range.upperBound }
        return proposed
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker("Time Range", selection: $selectedTimeRange) {
                ForEach(availableTimeRanges, id: \.self) { range in
                    Text(range).tag(range)
                }
            }
            .pickerStyle(.segmented)
            .onAppear {
                if !availableTimeRanges.contains(selectedTimeRange) {
                    selectedTimeRange = availableTimeRanges.last ?? "M"
                }
            }
            .onChange(of: availableTimeRanges) { _, newRanges in
                if !newRanges.contains(selectedTimeRange) {
                    selectedTimeRange = newRanges.last ?? "M"
                }
            }

            if let selectedEntry {
                VStack(alignment: .leading, spacing: 2) {
                    Text(formatMeasure(selectedEntry.measure))
                        .foregroundStyle(.blue)
                        .font(.title3.weight(.semibold))
                    Text(selectedEntry.measuredAt, format: .dateTime.month(.abbreviated).day().year())
                        .foregroundStyle(.gray)
                        .font(.caption)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            Chart {
                if let latestGoal = chartRows.last?.measure_amt, latestGoal != 0 {
                    RuleMark(y: .value("Goal", latestGoal))
                        .foregroundStyle(.gray)
                        .lineStyle(.init(lineWidth: 4.5, dash: [6, 4]))
                }

                if let outcome = outcomes.first {
                    RuleMark(
                        x: .value("Start Date", Calendar.current.startOfDay(for: outcome.start))
                    )
                    .foregroundStyle(.green)
                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))

                    RuleMark(
                        x: .value("End Date", Calendar.current.startOfDay(for: outcome.end))
                    )
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))
                }

                ForEach(visibleRows) { row in
                    LineMark(
                        x: .value("Date", Calendar.current.startOfDay(for: row.measuredAt)),
                        y: .value("Measure", row.measure)
                    )
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(.blue)

                    PointMark(
                        x: .value("Date", Calendar.current.startOfDay(for: row.measuredAt)),
                        y: .value("Measure", row.measure)
                    )
                    .symbol(.circle)
                    .symbolSize(selectedEntryID == row.id ? 140 : 70)
                    .foregroundStyle(selectedEntryID == row.id ? .blue : .blue.opacity(0.7))
                }

                if let selectedEntry {
                    RuleMark(x: .value("Selected Date", Calendar.current.startOfDay(for: selectedEntry.measuredAt)))
                        .foregroundStyle(.blue)
                        .lineStyle(.init(lineWidth: 2))
                }
            }
            .chartScrollableAxes(.horizontal)
            .chartXScale(domain: fullDateRange())
            .chartXVisibleDomain(length: visibleDomainLength())
            .chartScrollPosition(initialX: initialScrollX)
            .chartYScale(domain: yAxisRange())
            .chartXAxis {
                AxisMarks(values: xAxisValues()) { value in
                    AxisGridLine(stroke: .init(dash: [2, 2]))
                        .foregroundStyle(.gray.opacity(0.5))
                    AxisTick()
                    AxisValueLabel(format: xAxisLabelFormat())
                }
            }
            .chartYAxis {
                AxisMarks(position: .trailing, values: .automatic) { _ in
                    AxisGridLine()
                    AxisTick()
                    AxisValueLabel()
                }
            }
            .chartXSelection(value: $selectedDate)
            .onChange(of: selectedDate) { _, newValue in
                guard let newValue, let nearest = nearestEntry(to: newValue) else { return }
                selectedEntryID = nearest.id
            }
            .chartOverlay { proxy in
                GeometryReader { geo in
                    if showSuccessPaths, let frame = proxy.plotFrame {
                        let plot = geo[frame]
                        if
                            let startPoint = chartPoint(proxy: proxy, plot: plot, date: outcomeStartDate, value: startValue),
                            let goalPoint = chartPoint(proxy: proxy, plot: plot, date: outcomeEndDate, value: goalValue),
                            let latestPoint = chartPoint(proxy: proxy, plot: plot, date: latestDate, value: latestValue)
                        {
                            Path { p in
                                p.move(to: startPoint)
                                p.addLine(to: goalPoint)
                                p.addLine(to: latestPoint)
                                p.closeSubpath()
                            }
                            .fill(((isBehindGoalPath ?? false) ? Color.red : Color.green).opacity(0.18))
                            .mask(
                                Rectangle()
                                    .frame(width: plot.width, height: plot.height)
                                    .offset(x: plot.minX, y: plot.minY)
                            )

                            Path { p in
                                p.move(to: startPoint)
                                p.addLine(to: goalPoint)
                            }
                            .stroke(.gray, lineWidth: 2.2)
                            .mask(
                                Rectangle()
                                    .frame(width: plot.width, height: plot.height)
                                    .offset(x: plot.minX, y: plot.minY)
                            )

                            Path { p in
                                p.move(to: latestPoint)
                                p.addLine(to: goalPoint)
                            }
                            .stroke((isBehindGoalPath ?? false) ? .red : .green, lineWidth: 2.2)
                            .mask(
                                Rectangle()
                                    .frame(width: plot.width, height: plot.height)
                                    .offset(x: plot.minX, y: plot.minY)
                            )
                        }
                    }
                }
            }
            .onAppear {
                selectedEntryID = chartRows.last?.id
            }
            .frame(height: 260)

            Toggle("Show Success Paths", isOn: $showSuccessPaths)
                .font(.subheadline)
                .tint(.blue)
                .padding(.top, 2)

        }
    }

    private func nearestEntry(to date: Date) -> OutcomesMeasureEntry? {
        guard !chartRows.isEmpty else { return nil }
        let target = Calendar.current.startOfDay(for: date)
        return chartRows.min(by: {
            abs($0.measuredAt.timeIntervalSince(target)) < abs($1.measuredAt.timeIntervalSince(target))
        })
    }

    private func formatMeasure(_ value: Double) -> String {
        let places = min(3, max(0, decimalPlaces))
        let rounded = roundedValue(value, places: places)
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return String(format: "$%.\(places)f", rounded)
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return String(format: "%.\(places)f%%", rounded)
        default:
            let num = String(format: "%.\(places)f", rounded)
            if unitRaw != ObjectivesAddView.UnitOption.defaultUnit {
                return "\(num) \(unitRaw)"
            }
            return num
        }
    }

    private func fullDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let allDatesFromEntries = chartRows.map { calendar.startOfDay(for: $0.measuredAt) }
        let startMarker = outcomes.first.map { calendar.startOfDay(for: $0.start) }
        let endMarker = outcomes.first.map { calendar.startOfDay(for: $0.end) }
        let allDates = allDatesFromEntries + [startMarker, endMarker].compactMap { $0 }
        let minDate = allDates.min() ?? calendar.startOfDay(for: .now)
        let maxDate = allDates.max() ?? calendar.startOfDay(for: .now)
        let paddedStart = calendar.date(byAdding: .day, value: -30, to: minDate) ?? minDate
        let paddedEnd = calendar.date(byAdding: .day, value: 30, to: maxDate) ?? maxDate
        return paddedStart...paddedEnd
    }

    private func yAxisRange() -> ClosedRange<Double> {
        let values = chartRows.flatMap { [$0.measure, $0.measure_amt] }.filter { $0 != 0 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let padding = max(1, (maxValue - minValue) * 0.12)
        return (minValue - padding)...(maxValue + padding)
    }

    private func xAxisValues() -> [Date] {
        let calendar = Calendar.current
        let range = fullDateRange()
        let step: DateComponents = switch selectedTimeRange {
        case "W": DateComponents(day: 1)
        case "M": DateComponents(day: 7)
        case "3M": DateComponents(month: 1)
        case "6M": DateComponents(month: 1)
        case "Y": DateComponents(month: 2)
        default: DateComponents(month: 1)
        }

        var values: [Date] = []
        var current = range.lowerBound
        while current <= range.upperBound {
            values.append(current)
            current = calendar.date(byAdding: step, to: current) ?? range.upperBound.addingTimeInterval(1)
        }
        return values
    }

    private func xAxisLabelFormat() -> Date.FormatStyle {
        switch selectedTimeRange {
        case "W":
            return .dateTime.weekday(.abbreviated)
        case "M":
            return .dateTime.month(.defaultDigits).day()
        default:
            return .dateTime.month(.abbreviated)
        }
    }

    private func visibleDomainLength() -> TimeInterval {
        switch selectedTimeRange {
        case "W": return 60 * 60 * 24 * 7
        case "M": return 60 * 60 * 24 * 31
        case "3M": return 60 * 60 * 24 * 92
        case "6M": return 60 * 60 * 24 * 184
        case "Y": return 60 * 60 * 24 * 366
        default: return 60 * 60 * 24 * 31
        }
    }

    private func roundedValue(_ value: Double, places: Int) -> Double {
        let p = pow(10.0, Double(places))
        return (value * p).rounded() / p
    }

    private func chartPoint(
        proxy: ChartProxy,
        plot: CGRect,
        date: Date?,
        value: Double?
    ) -> CGPoint? {
        guard
            let date, let value,
            let x = proxy.position(forX: Calendar.current.startOfDay(for: date)),
            let y = proxy.position(forY: value)
        else { return nil }
        return CGPoint(x: plot.minX + x, y: plot.minY + y)
    }
}

struct AddOutcomeMeasureSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let outcomeID: UUID
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int

    @Query private var snapshots: [OutcomesMeasure]
    @Query private var entries: [OutcomesMeasureEntry]
    @State private var measureText: String = ""
    @State private var measuredDate: Date = Calendar.current.startOfDay(for: .now)

    init(outcomeID: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcomeID = outcomeID
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let snapshotPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcomeID }
        _snapshots = Query(filter: snapshotPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .reverse)])
        let entriesPredicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID }
        _entries = Query(filter: entriesPredicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)])
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $measuredDate, displayedComponents: [.date])
                TextField("Current", text: $measureText)
                    .keyboardType(.decimalPad)
                    .onChange(of: measureText) { _, newValue in
                        measureText = sanitizeDecimalInput(newValue, maxFractionDigits: min(3, max(0, decimalPlaces)))
                    }
            }
            .navigationTitle("Add Measure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let current = Double(measureText) ?? 0
                        let goal = goalValue
                        modelContext.insert(
                            OutcomesMeasureEntry(
                                outcome_id: outcomeID,
                                measure: current,
                                measure_amt: goal,
                                measuredAt: Calendar.current.startOfDay(for: measuredDate),
                                createdAt: .now,
                                format: formatRaw,
                                unit: unitRaw,
                                decimalPlaces: decimalPlaces
                            )
                        )
                        if let snapshot = snapshots.first {
                            snapshot.measure = current
                            snapshot.measure_amt = goal
                            snapshot.measuredAt = measuredDate
                            snapshot.measure_updated = .now
                            snapshot.format = formatRaw
                            snapshot.unit = unitRaw
                            snapshot.direction = nil
                            snapshot.decimalPlaces = decimalPlaces
                        } else {
                            modelContext.insert(
                                OutcomesMeasure(
                                    outcome_id: outcomeID,
                                    measure: current,
                                    measuredAt: measuredDate,
                                    measure_amt: goal,
                                    measure_updated: .now,
                                    direction: nil,
                                    format: formatRaw,
                                    unit: unitRaw,
                                    decimalPlaces: decimalPlaces
                                )
                            )
                        }
                        try? modelContext.save()
                        dismiss()
                    }
                }
            }
        }
    }

    private var goalValue: Double {
        if let snapshot = snapshots.first, snapshot.measure_amt != 0 {
            return snapshot.measure_amt
        }
        if let latestEntry = entries.first, latestEntry.measure_amt != 0 {
            return latestEntry.measure_amt
        }
        return 0
    }
}

struct OutcomesAllDataView: View {
    @Environment(\.modelContext) private var modelContext
    let outcomeID: UUID
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int
    @Query private var entries: [OutcomesMeasureEntry]
    @Query private var legacyMeasures: [OutcomesMeasure]
    @State private var editMode: EditMode = .inactive

    init(outcomeID: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcomeID = outcomeID
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let predicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID }
        _entries = Query(filter: predicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)])
        let legacyPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcomeID }
        _legacyMeasures = Query(filter: legacyPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .reverse)])
    }

    private var mergedRows: [OutcomesMeasureEntry] {
        if !entries.isEmpty { return entries }
        guard let legacy = legacyMeasures.first else { return [] }
        return [
            OutcomesMeasureEntry(
                outcome_id: legacy.outcome_id,
                measure: legacy.measure,
                measure_amt: legacy.measure_amt,
                measuredAt: legacy.measuredAt,
                createdAt: legacy.measure_updated,
                format: legacy.format,
                unit: legacy.unit,
                decimalPlaces: legacy.decimalPlaces
            )
        ]
    }

    var body: some View {
        List {
            ForEach(mergedRows) { row in
                VStack(alignment: .leading, spacing: 2) {
                    Text(row.measuredAt, format: .dateTime.month().day().year())
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Current: \(formatted(row.measure))  Goal: \(formatted(row.measure_amt))")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .onDelete { offsets in
                let deletedIDs = Set(offsets.map { mergedRows[$0].id })
                for idx in offsets {
                    let row = mergedRows[idx]
                    if let persisted = entries.first(where: { $0.id == row.id }) {
                        modelContext.delete(persisted)
                    } else if let legacy = legacyMeasures.first(where: { $0.outcome_id == outcomeID }) {
                        modelContext.delete(legacy)
                    }
                }
                if !entries.isEmpty {
                    let remainingEntries = entries.filter { !deletedIDs.contains($0.id) }
                    syncSnapshot(with: remainingEntries)
                }
                try? modelContext.save()
            }
        }
        .environment(\.editMode, $editMode)
        .navigationTitle("All Measure Data")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(editMode == .active ? "Done" : "Edit") {
                    editMode = editMode == .active ? .inactive : .active
                }
            }
        }
    }

    private func formatted(_ value: Double) -> String {
        let places = min(3, max(0, decimalPlaces))
        let p = pow(10.0, Double(places))
        let rounded = (value * p).rounded() / p
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return String(format: "$%.\(places)f", rounded)
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return String(format: "%.\(places)f%%", rounded)
        default:
            let raw = String(format: "%.\(places)f", rounded)
            return unitRaw == ObjectivesAddView.UnitOption.defaultUnit ? raw : "\(raw) \(unitRaw)"
        }
    }

    private func syncSnapshot(with remainingEntries: [OutcomesMeasureEntry]) {
        let snapshot = legacyMeasures.first(where: { $0.outcome_id == outcomeID })

        guard let latest = remainingEntries.max(by: { $0.measuredAt < $1.measuredAt }) else {
            if let snapshot {
                modelContext.delete(snapshot)
            }
            return
        }

        if let snapshot {
            snapshot.measure = latest.measure
            snapshot.measure_amt = latest.measure_amt
            snapshot.measuredAt = latest.measuredAt
            snapshot.measure_updated = .now
            snapshot.direction = nil
            snapshot.format = latest.format ?? formatRaw
            snapshot.unit = latest.unit ?? unitRaw
            snapshot.decimalPlaces = latest.decimalPlaces ?? decimalPlaces
        } else {
            modelContext.insert(
                OutcomesMeasure(
                    outcome_id: outcomeID,
                    measure: latest.measure,
                    measuredAt: latest.measuredAt,
                    measure_amt: latest.measure_amt,
                    measure_updated: .now,
                    direction: nil,
                    format: latest.format ?? formatRaw,
                    unit: latest.unit ?? unitRaw,
                    decimalPlaces: latest.decimalPlaces ?? decimalPlaces
                )
            )
        }
    }
}

struct DataSourcesPlaceholderView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Not Available Yet")
                .font(.headline)
                .fontWeight(.bold)
            Text("Data source integrations and access controls will be added here.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 20)
            Spacer()
        }
        .padding(.top, 24)
        .navigationTitle("Data Sources & Access")
        .navigationBarTitleDisplayMode(.inline)
    }
}
