import SwiftUI
import Charts
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif
#if canImport(UIKit)
import UIKit
#endif

private enum OutcomeMeasureEntrySourceStore {
    private static let defaultsKey = "outcome_measure_entry_sources_v1"

    private static func loadMap() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveMap(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func source(for measureEntryID: UUID) -> String? {
        loadMap()[measureEntryID.uuidString]
    }

    static func setSource(_ source: String?, for measureEntryID: UUID) {
        var map = loadMap()
        let key = measureEntryID.uuidString
        if let source, !source.isEmpty {
            map[key] = source
        } else {
            map.removeValue(forKey: key)
        }
        saveMap(map)
    }

    static func removeSource(for measureEntryID: UUID) {
        setSource(nil, for: measureEntryID)
    }
}

#Preview {
    NavigationStack {
        ObjectivesAddViewChart(
            outcome_id: UUID(),
            formatRaw: "number",
            unitRaw: "",
            decimalPlaces: 0
        )
    }
    .loomPreviewContainer()
}

private enum OutcomeHealthIntegrationStore {
    struct Snapshot: Codable {
        var isEnabled: Bool
        var metricIdentifierRaw: String?
        var lastSyncUnix: Double?
    }

    private static let defaultsKey = "outcome_health_integration_v1"

    private static func loadMap() -> [String: Snapshot] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: Snapshot].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func saveMap(_ map: [String: Snapshot]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    static func snapshot(for outcomeID: UUID) -> Snapshot {
        loadMap()[outcomeID.uuidString] ?? Snapshot(isEnabled: false, metricIdentifierRaw: nil, lastSyncUnix: nil)
    }

    static func setSnapshot(_ snapshot: Snapshot, for outcomeID: UUID) {
        var map = loadMap()
        let key = outcomeID.uuidString
        map[key] = snapshot
        saveMap(map)
    }
}

#if canImport(HealthKit)
private enum OutcomeHealthKitBridge {
    struct MetricOption: Identifiable, Hashable {
        let identifierRaw: String
        let displayName: String
        var id: String { identifierRaw }
    }

    struct DailyValue: Hashable {
        let day: Date
        let value: Double
    }

    private static let store = HKHealthStore()
    private static let initialAuthorizationCompleteDefaultsKey = "outcome.healthkit.initialAuthorizationComplete.v1"

    private enum BridgeError: LocalizedError {
        case unavailable
        case invalidIdentifier
        case authorizationDenied

        var errorDescription: String? {
            switch self {
            case .unavailable:
                return "Apple Health is not available on this device."
            case .invalidIdentifier:
                return "Selected Apple Health metric is unavailable."
            case .authorizationDenied:
                return "Apple Health access was denied. Open Health app > Sharing > Apps > Loom and allow data access."
            }
        }
    }

    // Order defines the exact order shown in the Outcome Apple Health metric picker.
    private static let quantityIdentifiers: [HKQuantityTypeIdentifier] = [
        .stepCount,
        .appleExerciseTime,
        .activeEnergyBurned,
        .distanceWalkingRunning,
        .distanceCycling,
        .flightsClimbed,
        .bodyMass,
        .bodyFatPercentage,
        .heartRate,
        .restingHeartRate,
        .heartRateVariabilitySDNN,
        .vo2Max,
        .appleStandTime,
        .dietaryWater,
        .dietaryEnergyConsumed,
        .dietaryProtein
    ]

    static func availableMetricOptions() -> [MetricOption] {
        return quantityIdentifiers
            .map { identifier in
                return MetricOption(
                    identifierRaw: identifier.rawValue,
                    displayName: displayName(for: identifier)
                )
            }
    }

    private static func displayName(for identifier: HKQuantityTypeIdentifier) -> String {
        if identifier == .activeEnergyBurned {
            return "Apple Energy Burned"
        }
        if identifier == .bodyMass {
            return "Weight"
        }
        var raw = identifier.rawValue
        let prefix = "HKQuantityTypeIdentifier"
        if raw.hasPrefix(prefix) {
            raw.removeFirst(prefix.count)
        }
        while raw.first == "." || raw.first == "_" {
            raw.removeFirst()
        }
        if raw.isEmpty {
            raw = identifier.rawValue
        }
        var spaced = ""
        spaced.reserveCapacity(raw.count + 8)
        for char in raw {
            if char.isUppercase, !spaced.isEmpty {
                spaced.append(" ")
            }
            spaced.append(char)
        }
        var label = spaced.capitalized
        label = label.replacingOccurrences(of: "S D N N", with: "")
        label = label.replacingOccurrences(of: "V O2", with: "VO2")
        label = label.replacingOccurrences(of: "  ", with: " ")
        return label.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func requestAuthorization(
        for identifierRaw: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(.failure(BridgeError.unavailable))
            return
        }
        guard let selectedType = quantityType(from: identifierRaw) else {
            completion(.failure(BridgeError.invalidIdentifier))
            return
        }
        let shouldRequestInitialScope = !UserDefaults.standard.bool(forKey: initialAuthorizationCompleteDefaultsKey)
        let readTypes: Set<HKObjectType> = shouldRequestInitialScope
            ? allReadableQuantityTypes()
            : [selectedType]
        guard !readTypes.isEmpty else {
            completion(.failure(BridgeError.invalidIdentifier))
            return
        }

        store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
            if let error {
                completion(.failure(error))
            } else if success {
                if shouldRequestInitialScope {
                    UserDefaults.standard.set(true, forKey: initialAuthorizationCompleteDefaultsKey)
                }
                completion(.success(()))
            } else {
                completion(.failure(BridgeError.authorizationDenied))
            }
        }
    }

    static func isAuthorizationDenied(_ error: Error) -> Bool {
        if let bridgeError = error as? BridgeError, case .authorizationDenied = bridgeError {
            return true
        }
        if containsHealthKitAuthorizationDenied(error) {
            return true
        }
        return false
    }

    private static func containsHealthKitAuthorizationDenied(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == HKErrorDomain,
           nsError.code == HKError.Code.errorAuthorizationDenied.rawValue {
            return true
        }
        if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
            return containsHealthKitAuthorizationDenied(underlying)
        }
        return false
    }

    static func readLatestPerDay(
        identifierRaw: String,
        start: Date,
        end: Date,
        completion: @escaping (Result<[DailyValue], Error>) -> Void
    ) {
        guard let type = quantityType(from: identifierRaw) else {
            completion(.failure(BridgeError.invalidIdentifier))
            return
        }

        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: start)
        let endDay = calendar.startOfDay(for: end)
        guard startDay <= endDay else {
            completion(.success([]))
            return
        }

        store.preferredUnits(for: [type]) { preferredUnits, unitError in
            if let unitError {
                completion(.failure(unitError))
                return
            }
            let unit = preferredUnits[type] ?? defaultUnit(for: identifierRaw)
            let usesCumulativeSum = type.aggregationStyle == .cumulative
            var rows: [DailyValue] = []
            var day = startDay
            let group = DispatchGroup()
            let lock = NSLock()
            var capturedError: Error?

            while day <= endDay {
                let currentDay = day
                let nextDay = calendar.date(byAdding: .day, value: 1, to: currentDay) ?? currentDay.addingTimeInterval(86_400)
                let predicate = HKQuery.predicateForSamples(withStart: currentDay, end: nextDay, options: .strictStartDate)
                group.enter()
                if usesCumulativeSum {
                    let query = HKStatisticsQuery(
                        quantityType: type,
                        quantitySamplePredicate: predicate,
                        options: .cumulativeSum
                    ) { _, result, error in
                        defer { group.leave() }
                        if let error {
                            lock.lock()
                            capturedError = error
                            lock.unlock()
                            return
                        }
                        guard let quantity = result?.sumQuantity() else { return }
                        let value = quantity.doubleValue(for: unit)
                        lock.lock()
                        rows.append(DailyValue(day: currentDay, value: value))
                        lock.unlock()
                    }
                    store.execute(query)
                } else {
                    let sort = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
                    let query = HKSampleQuery(
                        sampleType: type,
                        predicate: predicate,
                        limit: 1,
                        sortDescriptors: [sort]
                    ) { _, samples, error in
                        defer { group.leave() }
                        if let error {
                            lock.lock()
                            capturedError = error
                            lock.unlock()
                            return
                        }
                        guard let sample = (samples as? [HKQuantitySample])?.first else { return }
                        let value = sample.quantity.doubleValue(for: unit)
                        lock.lock()
                        rows.append(DailyValue(day: currentDay, value: value))
                        lock.unlock()
                    }
                    store.execute(query)
                }
                day = nextDay
            }

            group.notify(queue: .main) {
                if let capturedError {
                    completion(.failure(capturedError))
                } else {
                    completion(.success(rows.sorted { $0.day < $1.day }))
                }
            }
        }
    }

    private static func quantityType(from raw: String) -> HKQuantityType? {
        HKQuantityType.quantityType(forIdentifier: HKQuantityTypeIdentifier(rawValue: raw))
    }

    private static func allReadableQuantityTypes() -> Set<HKObjectType> {
        Set(quantityIdentifiers.compactMap { HKQuantityType.quantityType(forIdentifier: $0) })
    }

    private static func defaultUnit(for identifierRaw: String) -> HKUnit {
        switch identifierRaw {
        case HKQuantityTypeIdentifier.stepCount.rawValue,
             HKQuantityTypeIdentifier.flightsClimbed.rawValue,
             HKQuantityTypeIdentifier.appleExerciseTime.rawValue,
             HKQuantityTypeIdentifier.appleStandTime.rawValue,
             HKQuantityTypeIdentifier.numberOfTimesFallen.rawValue:
            return .count()
        case HKQuantityTypeIdentifier.activeEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.basalEnergyBurned.rawValue,
             HKQuantityTypeIdentifier.dietaryEnergyConsumed.rawValue:
            return .kilocalorie()
        case HKQuantityTypeIdentifier.heartRate.rawValue,
             HKQuantityTypeIdentifier.restingHeartRate.rawValue,
             HKQuantityTypeIdentifier.walkingHeartRateAverage.rawValue:
            return HKUnit.count().unitDivided(by: .minute())
        case HKQuantityTypeIdentifier.distanceWalkingRunning.rawValue,
             HKQuantityTypeIdentifier.distanceCycling.rawValue,
             HKQuantityTypeIdentifier.distanceSwimming.rawValue,
             HKQuantityTypeIdentifier.height.rawValue,
             HKQuantityTypeIdentifier.walkingStepLength.rawValue:
            return .meter()
        case HKQuantityTypeIdentifier.bodyMass.rawValue,
             HKQuantityTypeIdentifier.leanBodyMass.rawValue:
            return .gramUnit(with: .kilo)
        case HKQuantityTypeIdentifier.vo2Max.rawValue:
            return HKUnit(from: "ml/kg*min")
        case HKQuantityTypeIdentifier.bodyFatPercentage.rawValue,
             HKQuantityTypeIdentifier.oxygenSaturation.rawValue:
            return .percent()
        default:
            return .count()
        }
    }
}
#else
private enum OutcomeHealthKitBridge {
    struct MetricOption: Identifiable, Hashable {
        let identifierRaw: String
        let displayName: String
        var id: String { identifierRaw }
    }

    struct DailyValue: Hashable {
        let day: Date
        let value: Double
    }

    private enum BridgeError: LocalizedError {
        case unavailable
        var errorDescription: String? { "Apple Health is not available on this device." }
    }

    static func availableMetricOptions() -> [MetricOption] { [] }

    static func requestAuthorization(
        for identifierRaw: String,
        completion: @escaping (Result<Void, Error>) -> Void
    ) {
        completion(.failure(BridgeError.unavailable))
    }

    static func readLatestPerDay(
        identifierRaw: String,
        start: Date,
        end: Date,
        completion: @escaping (Result<[DailyValue], Error>) -> Void
    ) {
        completion(.failure(BridgeError.unavailable))
    }

    static func isAuthorizationDenied(_ error: Error) -> Bool { false }
}
#endif

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

private func parseFormattedDecimalChart(_ input: String) -> Double? {
    Double(input.replacingOccurrences(of: ",", with: ""))
}

private func groupedDecimalStringChart(_ value: Double, fractionDigits: Int) -> String {
    let places = max(0, min(3, fractionDigits))
    let formatter = NumberFormatter()
    formatter.numberStyle = .decimal
    formatter.usesGroupingSeparator = true
    formatter.minimumFractionDigits = places
    formatter.maximumFractionDigits = places
    return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(places)f", value)
}

private func sanitizeAndFormatDecimalInputChart(_ input: String, maxFractionDigits: Int = 4) -> String {
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

struct ObjectivesAddViewChart: View {
    let outcome_id: UUID
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Query private var entries: [OutcomesMeasureEntry]
    @Query private var legacyMeasures: [OutcomesMeasure]
    @Query private var outcomes: [Outcomes]
    @State private var selectedTimeRange: String = "All"
    @State private var selectedEntryID: UUID? = nil
    @State private var selectedDate: Date? = nil
    @State private var showSuccessPaths: Bool = false
    @State private var isAutoSyncingHealthData = false
    private let allTimeRanges = ["All", "W", "M", "3M", "6M", "Y"]
    private let healthAutoSyncTimer = Timer.publish(every: 900, on: .main, in: .common).autoconnect()

    private var availableTimeRanges: [String] {
        guard let outcome = outcomes.first else { return allTimeRanges }
        let start = Calendar.current.startOfDay(for: outcome.start)
        let end = Calendar.current.startOfDay(for: outcome.end)
        let days = max(1, Calendar.current.dateComponents([.day], from: start, to: end).day ?? 1)

        let maxIndex: Int
        if days <= 7 { maxIndex = 1 }
        else if days <= 30 { maxIndex = 2 }
        else if days <= 90 { maxIndex = 3 }
        else if days <= 180 { maxIndex = 4 }
        else { maxIndex = 5 }

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
        if !entries.isEmpty {
            return dailyLatestRowsWithinOutcomeWindow(entries)
        }
        guard let legacy = legacyMeasures.first else { return [] }
        return dailyLatestRowsWithinOutcomeWindow([
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
        ])
    }

    private var visibleRows: [OutcomesMeasureEntry] {
        let range = fullDateRange()
        return chartRows.filter {
            let day = Calendar.current.startOfDay(for: $0.measuredAt)
            return range.contains(day)
        }
    }

    private var selectedEntry: OutcomesMeasureEntry? {
        if let selectedDate, let nearest = nearestEntry(to: selectedDate) {
            return nearest
        }
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
        if let snapshot = legacyMeasures.first, snapshot.measure_amt != 0 {
            return snapshot.measure_amt
        }
        return chartRows.last?.measure_amt
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

    private var unselectedPointFillColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
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
                    selectedTimeRange = availableTimeRanges.first ?? "All"
                }
            }
            .onChange(of: availableTimeRanges) { _, newRanges in
                if !newRanges.contains(selectedTimeRange) {
                    selectedTimeRange = newRanges.first ?? "All"
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
                if let latestGoal = goalValue, latestGoal != 0 {
                    RuleMark(y: .value("Goal", latestGoal))
                        .foregroundStyle(.gray)
                        .lineStyle(.init(lineWidth: 4.5, dash: [6, 4]))
                }

                if let outcome = outcomes.first {
                    RuleMark(
                        x: .value("Start Date", Calendar.current.startOfDay(for: outcome.start))
                    )
                    .foregroundStyle(.green)
                    .lineStyle(todayIsOutcomeStartDate ? .init(lineWidth: 2) : .init(lineWidth: 2, dash: [5, 5]))

                    RuleMark(
                        x: .value("End Date", Calendar.current.startOfDay(for: outcome.end))
                    )
                    .foregroundStyle(.orange)
                    .lineStyle(todayIsOutcomeEndDate ? .init(lineWidth: 2) : .init(lineWidth: 2, dash: [5, 5]))
                }

                if shouldShowTodayMarker {
                    RuleMark(x: .value("Today", Calendar.current.startOfDay(for: .now)))
                        .foregroundStyle(.gray.opacity(0.85))
                        .lineStyle(.init(lineWidth: 2))
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
                    .symbolSize(40)
                    .foregroundStyle(unselectedPointFillColor)
                    .annotation(position: .overlay, alignment: .center) {
                        Circle()
                            .stroke(Color.blue, lineWidth: 1.8)
                            .frame(
                                width: 7,
                                height: 7
                            )
                    }
                }

                if let selectedEntry {
                    PointMark(
                        x: .value("Selected Date Point", Calendar.current.startOfDay(for: selectedEntry.measuredAt)),
                        y: .value("Selected Measure Point", selectedEntry.measure)
                    )
                    .symbol(.circle)
                    .symbolSize(70)
                    .foregroundStyle(Color.blue)
                    .annotation(position: .overlay, alignment: .center) {
                        Circle()
                            .stroke(Color.blue, lineWidth: 2.4)
                            .frame(width: 9, height: 9)
                    }

                    RuleMark(x: .value("Selected Date", Calendar.current.startOfDay(for: selectedEntry.measuredAt)))
                        .foregroundStyle(.blue.opacity(0.5))
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
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(xAxisLabel(for: date))
                        }
                    }
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
                autoSyncFromOutcomeHealthIfNeeded()
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                autoSyncFromOutcomeHealthIfNeeded()
            }
            .onReceive(healthAutoSyncTimer) { _ in
                autoSyncFromOutcomeHealthIfNeeded()
            }
            .frame(height: 260)

            Toggle("Show Success Path", isOn: $showSuccessPaths)
                .font(.subheadline)
                .tint(.blue)
                .padding(.top, 2)

        }
    }

    private func autoSyncFromOutcomeHealthIfNeeded() {
        guard !isAutoSyncingHealthData else { return }
        let integration = OutcomeHealthIntegrationStore.snapshot(for: outcome_id)
        guard integration.isEnabled else { return }
        guard let metricIdentifier = integration.metricIdentifierRaw, !metricIdentifier.isEmpty else { return }

        let nowUnix = Date().timeIntervalSince1970
        if let lastSync = integration.lastSyncUnix, (nowUnix - lastSync) < 900 {
            return
        }

        guard let syncRange = outcomeDateRangeForHealthSync else { return }
        isAutoSyncingHealthData = true

        OutcomeHealthKitBridge.requestAuthorization(for: metricIdentifier) { authResult in
            switch authResult {
            case .failure:
                DispatchQueue.main.async {
                    isAutoSyncingHealthData = false
                }
            case .success:
                OutcomeHealthKitBridge.readLatestPerDay(
                    identifierRaw: metricIdentifier,
                    start: syncRange.lowerBound,
                    end: syncRange.upperBound
                ) { result in
                    DispatchQueue.main.async {
                        defer { isAutoSyncingHealthData = false }
                        guard case .success(let dailyValues) = result else { return }
                        applyAutoSyncedHealthRows(dailyValues, within: syncRange)
                        OutcomeHealthIntegrationStore.setSnapshot(
                            .init(
                                isEnabled: true,
                                metricIdentifierRaw: metricIdentifier,
                                lastSyncUnix: nowUnix
                            ),
                            for: outcome_id
                        )
                    }
                }
            }
        }
    }

    private var outcomeDateRangeForHealthSync: ClosedRange<Date>? {
        guard let outcome = outcomes.first else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: outcome.start)
        let end = min(calendar.startOfDay(for: outcome.end), calendar.startOfDay(for: .now))
        guard start <= end else { return nil }
        return start...end
    }

    private func applyAutoSyncedHealthRows(_ rows: [OutcomeHealthKitBridge.DailyValue], within range: ClosedRange<Date>) {
        let calendar = Calendar.current
        let goalValue = currentGoalValueForAutoSync()
        let syncedDays = Set(rows.map { calendar.startOfDay(for: $0.day) })

        let appleHealthRowsByDay = Dictionary(grouping: entries.filter {
            guard let source = OutcomeMeasureEntrySourceStore.source(for: $0.id) else { return false }
            let day = calendar.startOfDay(for: $0.measuredAt)
            return source == "apple_health" && range.contains(day)
        }) { calendar.startOfDay(for: $0.measuredAt) }

        for row in rows {
            let day = calendar.startOfDay(for: row.day)
            let existingRows = (appleHealthRowsByDay[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            if let keep = existingRows.first {
                keep.measure = row.value
                keep.measure_amt = goalValue
                keep.measuredAt = day
                keep.createdAt = .now
                keep.format = formatRaw
                keep.unit = unitRaw
                keep.decimalPlaces = decimalPlaces
                for extra in existingRows.dropFirst() {
                    OutcomeMeasureEntrySourceStore.removeSource(for: extra.id)
                    RecentlyDeletedStore.trash(extra, in: modelContext)
                }
            } else {
                let inserted = OutcomesMeasureEntry(
                    outcome_id: outcome_id,
                    measure: row.value,
                    measure_amt: goalValue,
                    measuredAt: day,
                    createdAt: .now,
                    format: formatRaw,
                    unit: unitRaw,
                    decimalPlaces: decimalPlaces
                )
                modelContext.insert(inserted)
                OutcomeMeasureEntrySourceStore.setSource("apple_health", for: inserted.id)
            }
        }

        for (day, staleRows) in appleHealthRowsByDay where !syncedDays.contains(day) {
            for stale in staleRows {
                OutcomeMeasureEntrySourceStore.removeSource(for: stale.id)
                RecentlyDeletedStore.trash(stale, in: modelContext)
            }
        }

        syncLatestSnapshotForAutoSync()
        try? modelContext.save()
    }

    private func currentGoalValueForAutoSync() -> Double {
        if let snapshot = legacyMeasures.first, snapshot.measure_amt != 0 {
            return snapshot.measure_amt
        }
        if let latestEntry = entries.max(by: { $0.measuredAt < $1.measuredAt }) {
            return latestEntry.measure_amt
        }
        return 0
    }

    private func syncLatestSnapshotForAutoSync() {
        let descriptor = FetchDescriptor<OutcomesMeasureEntry>(
            predicate: #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcome_id },
            sortBy: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)]
        )
        let latestEntry = (try? modelContext.fetch(descriptor))?.first
        guard let latestEntry else { return }

        if let snapshot = legacyMeasures.first {
            snapshot.measure = latestEntry.measure
            snapshot.measure_amt = latestEntry.measure_amt
            snapshot.measuredAt = latestEntry.measuredAt
            snapshot.measure_updated = .now
            snapshot.direction = nil
            snapshot.format = latestEntry.format ?? formatRaw
            snapshot.unit = latestEntry.unit ?? unitRaw
            snapshot.decimalPlaces = latestEntry.decimalPlaces ?? decimalPlaces
        } else {
            modelContext.insert(
                OutcomesMeasure(
                    outcome_id: outcome_id,
                    measure: latestEntry.measure,
                    measuredAt: latestEntry.measuredAt,
                    measure_amt: latestEntry.measure_amt,
                    measure_updated: .now,
                    direction: nil,
                    format: latestEntry.format ?? formatRaw,
                    unit: latestEntry.unit ?? unitRaw,
                    decimalPlaces: latestEntry.decimalPlaces ?? decimalPlaces
                )
            )
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
            return "$" + groupedDecimalStringChart(rounded, fractionDigits: places)
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return groupedDecimalStringChart(rounded, fractionDigits: places) + "%"
        default:
            let num = groupedDecimalStringChart(rounded, fractionDigits: places)
            if unitRaw != ObjectivesAddView.UnitOption.defaultUnit {
                return "\(num) \(unitRaw)"
            }
            return num
        }
    }

    private func dailyLatestRowsWithinOutcomeWindow(_ rows: [OutcomesMeasureEntry]) -> [OutcomesMeasureEntry] {
        guard let outcome = outcomes.first else {
            return rows.sorted { $0.measuredAt < $1.measuredAt }
        }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: outcome.start)
        let end = calendar.startOfDay(for: outcome.end)

        var latestByDay: [Date: OutcomesMeasureEntry] = [:]
        for row in rows {
            let day = calendar.startOfDay(for: row.measuredAt)
            guard day >= start, day <= end else { continue }
            if let existing = latestByDay[day] {
                if row.createdAt > existing.createdAt {
                    latestByDay[day] = row
                }
            } else {
                latestByDay[day] = row
            }
        }
        return latestByDay.values.sorted { $0.measuredAt < $1.measuredAt }
    }

    private func fullDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        if let outcome = outcomes.first {
            let start = calendar.startOfDay(for: outcome.start)
            let end = calendar.startOfDay(for: outcome.end)
            if start <= end {
                return start...end
            }
        }
        let allDatesFromEntries = chartRows.map { calendar.startOfDay(for: $0.measuredAt) }
        let startMarker = outcomes.first.map { calendar.startOfDay(for: $0.start) }
        let endMarker = outcomes.first.map { calendar.startOfDay(for: $0.end) }
        let allDates = allDatesFromEntries + [startMarker, endMarker].compactMap { $0 }
        let minDate = allDates.min() ?? calendar.startOfDay(for: .now)
        let maxDate = allDates.max() ?? calendar.startOfDay(for: .now)
        return minDate...maxDate
    }

    private var shouldShowTodayMarker: Bool {
        let cal = Calendar.current
        let today = cal.startOfDay(for: .now)
        guard !todayIsOutcomeStartDate, !todayIsOutcomeEndDate else { return false }
        let hasTodayPoint = visibleRows.contains { cal.isDate($0.measuredAt, inSameDayAs: today) }
        guard !hasTodayPoint else { return false }
        let range = fullDateRange()
        return today >= range.lowerBound && today <= range.upperBound
    }

    private var todayIsOutcomeStartDate: Bool {
        guard let outcome = outcomes.first else { return false }
        return Calendar.current.isDate(outcome.start, inSameDayAs: .now)
    }

    private var todayIsOutcomeEndDate: Bool {
        guard let outcome = outcomes.first else { return false }
        return Calendar.current.isDate(outcome.end, inSameDayAs: .now)
    }

    private func yAxisRange() -> ClosedRange<Double> {
        var values: [Double] = visibleRows.flatMap { [$0.measure, $0.measure_amt] }
        if let startValue { values.append(startValue) }
        if let latestValue { values.append(latestValue) }
        if let goalValue { values.append(goalValue) }
        if let selected = selectedEntry?.measure { values.append(selected) }

        guard let minValue = values.min(), let maxValue = values.max() else {
            return 0...10
        }

        let span = maxValue - minValue
        let minSpan = max(1.0, abs(maxValue) * 0.1)
        let effectiveSpan = max(span, minSpan)
        let padding = max(0.5, effectiveSpan * 0.14)
        let mid = (minValue + maxValue) / 2
        let half = (effectiveSpan / 2) + padding
        return (mid - half)...(mid + half)
    }

    private func xAxisValues() -> [Date] {
        let calendar = Calendar.current
        let range = fullDateRange()
        let step: DateComponents = switch selectedTimeRange {
        case "All": DateComponents(month: 1)
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

    private func xAxisLabel(for date: Date) -> String {
        let spanDays = Calendar.current.dateComponents([.day], from: fullDateRange().lowerBound, to: fullDateRange().upperBound).day ?? 0
        let isLongRange = spanDays > 365
        let formatter = DateFormatter()
        switch selectedTimeRange {
        case "W":
            formatter.dateFormat = "EEE"
            return formatter.string(from: date)
        case "M":
            formatter.dateFormat = "M/d"
            return formatter.string(from: date)
        default:
            if isLongRange {
                formatter.dateFormat = "MMMM"
                return String(formatter.string(from: date).prefix(1))
            }
            formatter.dateFormat = "MMM"
            return formatter.string(from: date)
        }
    }

    private func visibleDomainLength() -> TimeInterval {
        if selectedTimeRange == "All" {
            return fullDateRange().upperBound.timeIntervalSince(fullDateRange().lowerBound)
        }
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
    @Query private var outcomes: [Outcomes]
    @State private var measureText: String = ""
    @State private var measuredDate: Date = Calendar.current.startOfDay(for: .now)
    @FocusState private var isMeasureFieldFocused: Bool
    @State private var showOverrideAlert: Bool = false
    @State private var pendingCurrentValue: Double?
    @State private var pendingMeasuredDay: Date?

    private var measureKeyboardShowsCheckmark: Bool {
        !measureText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var canSave: Bool {
        let trimmed = measureText.trimmingCharacters(in: .whitespacesAndNewlines)
        return !trimmed.isEmpty && parseFormattedDecimalChart(measureText) != nil
    }

    init(outcomeID: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcomeID = outcomeID
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let snapshotPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcomeID }
        _snapshots = Query(filter: snapshotPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .reverse)])
        let entriesPredicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID }
        _entries = Query(filter: entriesPredicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)])
        let outcomePredicate = #Predicate<Outcomes> { $0.outcome_id == outcomeID }
        _outcomes = Query(filter: outcomePredicate)
    }

    var body: some View {
        NavigationStack {
            Form {
                DatePicker("Date", selection: $measuredDate, in: allowedDateRange, displayedComponents: [.date])
                TextField("Current", text: $measureText)
                    .keyboardType(.decimalPad)
                    .focused($isMeasureFieldFocused)
                    .onChange(of: measureText) { _, newValue in
                        measureText = sanitizeAndFormatDecimalInputChart(newValue, maxFractionDigits: min(3, max(0, decimalPlaces)))
                    }
            }
            .navigationTitle("Add Measure")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                    isMeasureFieldFocused = true
                }
            }
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    if isMeasureFieldFocused {
                        Spacer(minLength: 0)
                        Button {
                            guard measureKeyboardShowsCheckmark else {
                                isMeasureFieldFocused = false
                                return
                            }
                            isMeasureFieldFocused = false
                            attemptSaveFromInput()
                        } label: {
                            keyboardAccessoryIcon(showCheckmark: measureKeyboardShowsCheckmark)
                        }
                        .buttonStyle(.plain)
                    }
                }
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if canSave {
                        Button("Save") {
                            attemptSaveFromInput()
                        }
                    }
                }
            }
            .alert("Override existing value?", isPresented: $showOverrideAlert) {
                Button("Cancel", role: .cancel) {
                    pendingCurrentValue = nil
                    pendingMeasuredDay = nil
                }
                Button("Override") {
                    guard let current = pendingCurrentValue, let day = pendingMeasuredDay else { return }
                    persistMeasure(current: current, measuredDay: day, overrideExisting: true)
                    pendingCurrentValue = nil
                    pendingMeasuredDay = nil
                    dismiss()
                }
            } message: {
                Text("A value already exists for this date. Would you like to override it?")
            }
        }
    }

    private func attemptSaveFromInput() {
        guard let current = parseFormattedDecimalChart(measureText) else { return }
        let selectedDay = Calendar.current.startOfDay(for: measuredDate)
        let existingSameDay = entries.filter {
            Calendar.current.isDate($0.measuredAt, inSameDayAs: selectedDay)
        }
        if existingSameDay.isEmpty {
            persistMeasure(current: current, measuredDay: selectedDay, overrideExisting: false)
            dismiss()
        } else {
            pendingCurrentValue = current
            pendingMeasuredDay = selectedDay
            showOverrideAlert = true
        }
    }

    @ViewBuilder
    private func keyboardAccessoryIcon(showCheckmark: Bool) -> some View {
        Image(systemName: showCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(showCheckmark ? .white : .primary.opacity(0.85))
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(
                    showCheckmark
                        ? Color.blue
                        : Color(.secondarySystemBackground)
                )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.black.opacity(showCheckmark ? 0 : 0.08),
                        lineWidth: 1
                    )
            )
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

    private var allowedDateRange: ClosedRange<Date> {
        let today = Calendar.current.startOfDay(for: .now)
        let start = Calendar.current.startOfDay(for: outcomes.first?.start ?? today)
        return start...today
    }

    private func persistMeasure(current: Double, measuredDay: Date, overrideExisting: Bool) {
        let goal = goalValue
        let hasExactDuplicateForDay = entries.contains {
            Calendar.current.isDate($0.measuredAt, inSameDayAs: measuredDay) &&
            $0.measure == current &&
            $0.measure_amt == goal
        }

        if hasExactDuplicateForDay {
            if let snapshot = snapshots.first {
                snapshot.measure = current
                snapshot.measure_amt = goal
                snapshot.measuredAt = measuredDay
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
                        measuredAt: measuredDay,
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
            return
        }

        if overrideExisting {
            let sameDayEntries = entries.filter {
                Calendar.current.isDate($0.measuredAt, inSameDayAs: measuredDay)
            }
            if let keep = sameDayEntries.first {
                keep.measure = current
                keep.measure_amt = goal
                keep.measuredAt = measuredDay
                keep.createdAt = .now
                keep.format = formatRaw
                keep.unit = unitRaw
                keep.decimalPlaces = decimalPlaces
                for extra in sameDayEntries.dropFirst() {
                    RecentlyDeletedStore.trash(extra, in: modelContext)
                }
            } else {
                modelContext.insert(
                    OutcomesMeasureEntry(
                        outcome_id: outcomeID,
                        measure: current,
                        measure_amt: goal,
                        measuredAt: measuredDay,
                        createdAt: .now,
                        format: formatRaw,
                        unit: unitRaw,
                        decimalPlaces: decimalPlaces
                    )
                )
            }
        } else {
            modelContext.insert(
                OutcomesMeasureEntry(
                    outcome_id: outcomeID,
                    measure: current,
                    measure_amt: goal,
                    measuredAt: measuredDay,
                    createdAt: .now,
                    format: formatRaw,
                    unit: unitRaw,
                    decimalPlaces: decimalPlaces
                )
            )
        }

        if let snapshot = snapshots.first {
            snapshot.measure = current
            snapshot.measure_amt = goal
            snapshot.measuredAt = measuredDay
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
                    measuredAt: measuredDay,
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
    @Query private var outcomes: [Outcomes]
    @Query(sort: \OutcomeAnalyticsEvent.occurredAt, order: .reverse) private var allEvents: [OutcomeAnalyticsEvent]
    @State private var isEditingStartingValue = false
    @State private var startingValueInput = ""
    @FocusState private var isStartingValueFieldFocused: Bool

    init(outcomeID: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcomeID = outcomeID
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let predicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID }
        _entries = Query(filter: predicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)])
        let legacyPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcomeID }
        _legacyMeasures = Query(filter: legacyPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .reverse)])
        let outcomePredicate = #Predicate<Outcomes> { $0.outcome_id == outcomeID }
        _outcomes = Query(filter: outcomePredicate)
    }

    private var outcomeStartDate: Date {
        Calendar.current.startOfDay(for: outcomes.first?.start ?? .now)
    }

    private var startDayEntries: [OutcomesMeasureEntry] {
        entries
            .filter { Calendar.current.isDate($0.measuredAt, inSameDayAs: outcomeStartDate) }
            .sorted { $0.createdAt > $1.createdAt }
    }

    private var startingValue: Double {
        startDayEntries.first?.measure ?? 0
    }

    private var mergedMeasureRows: [OutcomesMeasureEntry] {
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

    private var nonStartingMeasureRows: [OutcomesMeasureEntry] {
        mergedMeasureRows.filter { !Calendar.current.isDate($0.measuredAt, inSameDayAs: outcomeStartDate) }
    }

    private var goalChangeEvents: [OutcomeAnalyticsEvent] {
        let base = allEvents.filter {
            $0.outcome_id == outcomeID &&
            $0.eventType == "goal_changed" &&
            $0.oldGoal != nil &&
            $0.newGoal != nil &&
            $0.oldGoal != $0.newGoal
        }
        // Build chronologically to remove baseline/original setup and repeated same-goal updates.
        let chronological = base.sorted { $0.occurredAt < $1.occurredAt }
        var result: [OutcomeAnalyticsEvent] = []
        var lastGoal: Double?

        for event in chronological {
            guard let oldGoal = event.oldGoal, let newGoal = event.newGoal else { continue }
            // Skip the original setup transition (ex: 0 -> first configured goal).
            if oldGoal == 0 && lastGoal == nil {
                lastGoal = newGoal
                continue
            }
            // Skip no-op repeats where the resulting goal is unchanged from the latest known goal.
            if let lastGoal, newGoal == lastGoal {
                continue
            }

            result.append(event)
            lastGoal = newGoal
        }
        return result.sorted { $0.occurredAt > $1.occurredAt }
    }

    private var recordedRows: [RecordedRow] {
        var rows: [RecordedRow] = nonStartingMeasureRows.map {
            RecordedRow(id: "measure-\($0.id.uuidString)", date: $0.measuredAt, kind: .measure($0))
        }
        rows.append(contentsOf: goalChangeEvents.map {
            RecordedRow(id: "goal-\($0.id.uuidString)", date: $0.occurredAt, kind: .goalChange($0))
        })
        rows.sort { $0.date > $1.date }
        return rows
    }

    private var hasGoalUpdates: Bool {
        !goalChangeEvents.isEmpty
    }

    private var startingValueKeyboardShowsCheckmark: Bool {
        !startingValueInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var originalGoalValue: Double {
        goalChangeEvents
            .sorted { $0.occurredAt < $1.occurredAt }
            .first?.oldGoal ?? currentGoalValue()
    }

    var body: some View {
        List {
            ForEach(recordedRows) { row in
                NavigationLink {
                    RecordedDataDetailsView(
                        row: row,
                        formatRaw: formatRaw,
                        unitRaw: unitRaw,
                        decimalPlaces: decimalPlaces
                    )
                } label: {
                    recordedRowLabel(row)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                    Button("Delete", role: .destructive) {
                        switch row.kind {
                        case .measure(let measureRow):
                            deleteMeasureRow(measureRow)
                        case .goalChange(let event):
                            deleteGoalChangeRow(event)
                        }
                    }
                    .tint(.red)
                }
            }

            Section {
                HStack(spacing: 10) {
                    Text(hasGoalUpdates ? "Original Goal" : "Goal")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatted(hasGoalUpdates ? originalGoalValue : currentGoalValue()))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 1)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section {
                Button {
                    startingValueInput = sanitizeAndFormatDecimalInputChart(
                        startingValue == 0 ? "" : formatted(startingValue),
                        maxFractionDigits: min(3, max(0, decimalPlaces))
                    )
                    isEditingStartingValue = true
                } label: {
                    HStack(spacing: 10) {
                        Text("Starting Value")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatted(startingValue))
                            .font(.body)
                            .foregroundStyle(.blue)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.caption)
                            .foregroundStyle(.blue)
                    }
                    .padding(.vertical, 1)
                }
                .buttonStyle(.plain)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }
        }
        .navigationTitle("All Recorded Data")
        .navigationBarTitleDisplayMode(.inline)
        .toolbarBackground(.visible, for: .navigationBar)
        .sheet(isPresented: $isEditingStartingValue) {
            NavigationStack {
                Form {
                    HStack {
                        Text("Start Date")
                        Spacer()
                        Text(compactDate(outcomeStartDate))
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Starting Value")
                        Spacer()
                        TextField("0", text: $startingValueInput)
                            .keyboardType(.decimalPad)
                            .focused($isStartingValueFieldFocused)
                            .multilineTextAlignment(.trailing)
                            .frame(width: 120)
                            .onChange(of: startingValueInput) { _, newValue in
                                startingValueInput = sanitizeAndFormatDecimalInputChart(
                                    newValue,
                                    maxFractionDigits: min(3, max(0, decimalPlaces))
                                )
                            }
                    }
                }
                .navigationTitle("Edit Starting Value")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                        isStartingValueFieldFocused = true
                    }
                }
                .toolbar {
                    ToolbarItemGroup(placement: .keyboard) {
                        if isStartingValueFieldFocused {
                            Spacer(minLength: 0)
                            Button {
                                guard startingValueKeyboardShowsCheckmark else {
                                    isStartingValueFieldFocused = false
                                    return
                                }
                                isStartingValueFieldFocused = false
                                saveStartingValue()
                                isEditingStartingValue = false
                            } label: {
                                keyboardAccessoryIcon(showCheckmark: startingValueKeyboardShowsCheckmark)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { isEditingStartingValue = false }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            saveStartingValue()
                            isEditingStartingValue = false
                        }
                    }
                }
            }
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    @ViewBuilder
    private func keyboardAccessoryIcon(showCheckmark: Bool) -> some View {
        Image(systemName: showCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(showCheckmark ? .white : .primary.opacity(0.85))
            .frame(width: 30, height: 30)
            .background(
                Circle().fill(
                    showCheckmark
                        ? Color.blue
                        : Color(.secondarySystemBackground)
                )
            )
            .overlay(
                Circle()
                    .stroke(
                        Color.black.opacity(showCheckmark ? 0 : 0.08),
                        lineWidth: 1
                    )
            )
    }

    @ViewBuilder
    private func recordedRowLabel(_ row: RecordedRow) -> some View {
        switch row.kind {
        case .measure(let measureRow):
            let isAppleHealth = OutcomeMeasureEntrySourceStore.source(for: measureRow.id) == "apple_health"
            HStack(spacing: 10) {
                if isAppleHealth {
                    Image(systemName: "heart")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 34, height: 34)
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.primary.opacity(0.9), lineWidth: 1)
                        )
                } else {
                    Image("logo_appicon_any")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 34, height: 34)
                        .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .stroke(Color.gray.opacity(0.45), lineWidth: 0.6)
                        )
                }
                Text(formatted(measureRow.measure))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(compactDate(measureRow.measuredAt))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 1)
        case .goalChange(let event):
            HStack(spacing: 10) {
                ZStack {
                    Color.clear
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)
                Text(formatted(event.newGoal ?? 0))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(compactDate(event.occurredAt))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 1)
        }
    }

    private func compactDate(_ date: Date) -> String {
        let cal = Calendar.current
        let nowYear = cal.component(.year, from: .now)
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        if year == nowYear {
            formatter.dateFormat = "MMM d"
        } else {
            formatter.dateFormat = "MMM d, yyyy"
        }
        return formatter.string(from: date)
    }

    private func deleteMeasureRow(_ row: OutcomesMeasureEntry) {
        if let persisted = entries.first(where: { $0.id == row.id }) {
            modelContext.insert(
                OutcomeAnalyticsEvent(
                    outcome_id: outcomeID,
                    eventType: "measure_deleted",
                    measuredAt: persisted.measuredAt,
                    oldMeasure: persisted.measure,
                    oldGoal: persisted.measure_amt,
                    source: "All Recorded Data"
                )
            )
            RecentlyDeletedStore.trash(persisted, in: modelContext)
            OutcomeMeasureEntrySourceStore.removeSource(for: persisted.id)
            let remainingEntries = entries.filter { $0.id != row.id }
            syncSnapshot(with: remainingEntries)
        } else if let legacy = legacyMeasures.first(where: { $0.outcome_id == outcomeID }) {
            modelContext.insert(
                OutcomeAnalyticsEvent(
                    outcome_id: outcomeID,
                    eventType: "measure_deleted",
                    measuredAt: legacy.measuredAt,
                    oldMeasure: legacy.measure,
                    oldGoal: legacy.measure_amt,
                    source: "All Recorded Data (Legacy)"
                )
            )
            RecentlyDeletedStore.trash(legacy, in: modelContext)
        }
        try? modelContext.save()
    }

    private func saveStartingValue() {
        let parsed = parseFormattedDecimalChart(startingValueInput) ?? 0
        let goal = currentGoalValue()
        if let existing = startDayEntries.first {
            existing.measure = parsed
            existing.measure_amt = goal
            existing.createdAt = .now
            existing.format = formatRaw
            existing.unit = unitRaw
            existing.decimalPlaces = decimalPlaces
        } else {
            modelContext.insert(
                OutcomesMeasureEntry(
                    outcome_id: outcomeID,
                    measure: parsed,
                    measure_amt: goal,
                    measuredAt: outcomeStartDate,
                    createdAt: .now,
                    format: formatRaw,
                    unit: unitRaw,
                    decimalPlaces: decimalPlaces
                )
            )
        }
        try? modelContext.save()
    }

    private func currentGoalValue() -> Double {
        if let snapshot = legacyMeasures.first, snapshot.measure_amt != 0 {
            return snapshot.measure_amt
        }
        if let latestEntry = entries.max(by: { $0.measuredAt < $1.measuredAt }) {
            return latestEntry.measure_amt
        }
        return 0
    }

    private func deleteGoalChangeRow(_ event: OutcomeAnalyticsEvent) {
        guard let oldGoal = event.oldGoal else {
            modelContext.delete(event)
            try? modelContext.save()
            return
        }

        if let snapshot = legacyMeasures.first(where: { $0.outcome_id == outcomeID }) {
            snapshot.measure_amt = oldGoal
            snapshot.measure_updated = .now
        }

        if let latestEntry = entries.max(by: { $0.measuredAt < $1.measuredAt }) {
            latestEntry.measure_amt = oldGoal
        }

        modelContext.delete(event)
        try? modelContext.save()
    }

    private func formatted(_ value: Double) -> String {
        let places = min(3, max(0, decimalPlaces))
        let p = pow(10.0, Double(places))
        let rounded = (value * p).rounded() / p
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return "$" + groupedDecimalStringChart(rounded, fractionDigits: places)
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return groupedDecimalStringChart(rounded, fractionDigits: places) + "%"
        default:
            let raw = groupedDecimalStringChart(rounded, fractionDigits: places)
            return unitRaw == ObjectivesAddView.UnitOption.defaultUnit ? raw : "\(raw) \(unitRaw)"
        }
    }

    private func syncSnapshot(with remainingEntries: [OutcomesMeasureEntry]) {
        let snapshot = legacyMeasures.first(where: { $0.outcome_id == outcomeID })

        guard let latest = remainingEntries.max(by: { $0.measuredAt < $1.measuredAt }) else {
            if let snapshot {
                RecentlyDeletedStore.trash(snapshot, in: modelContext)
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

private struct RecordedRow: Identifiable {
    enum Kind {
        case measure(OutcomesMeasureEntry)
        case goalChange(OutcomeAnalyticsEvent)
    }
    let id: String
    let date: Date
    let kind: Kind
}

private struct RecordedDataDetailsView: View {
    let row: RecordedRow
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allEntries: [OutcomesMeasureEntry]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .forward) private var allSnapshots: [OutcomesMeasure]

    var body: some View {
        Form {
            switch row.kind {
            case .measure(let measureRow):
                let isAppleHealth = OutcomeMeasureEntrySourceStore.source(for: measureRow.id) == "apple_health"
                detailRow("Value", formatted(measureRow.measure))
                detailRow("Date", fullDate(measureRow.measuredAt))
                detailRow("Source", isAppleHealth ? "Apple Health" : "Loom")
                detailRow("Was User Entered", isAppleHealth ? "No" : "Yes")
            case .goalChange(let event):
                let oldGoal = event.oldGoal ?? 0
                let newGoal = event.newGoal ?? 0
                let diff = newGoal - oldGoal
                detailRow("New Goal", formatted(newGoal))
                detailRow("Old Goal", formatted(oldGoal))
                HStack {
                    Text("Difference")
                    Spacer()
                    Text(formatted(diff))
                        .foregroundStyle(differenceColor(oldGoal: oldGoal, newGoal: newGoal, outcomeId: event.outcome_id))
                }
                detailRow("Date", fullDate(event.occurredAt))
                detailRow("Source", "Loom")
                detailRow("Was User Entered", "Yes")
            }
        }
        .navigationTitle("Details")
        .navigationBarTitleDisplayMode(.inline)
    }

    private func detailRow(_ label: String, _ value: String) -> some View {
        HStack {
            Text(label)
            .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
        }
    }

    private func fullDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func startMeasure(for outcomeId: UUID) -> Double? {
        if let first = allEntries.first(where: { $0.outcome_id == outcomeId }) {
            return first.measure
        }
        return allSnapshots.first(where: { $0.outcome_id == outcomeId })?.measure
    }

    private func differenceColor(oldGoal: Double, newGoal: Double, outcomeId: UUID) -> Color {
        guard let start = startMeasure(for: outcomeId), oldGoal != start else {
            if newGoal > oldGoal { return .green }
            if newGoal < oldGoal { return .red }
            return .primary
        }
        let directionUp = oldGoal > start
        if directionUp {
            if newGoal > oldGoal { return .green }
            if newGoal < oldGoal { return .red }
            return .primary
        } else {
            if newGoal < oldGoal { return .green }
            if newGoal > oldGoal { return .red }
            return .primary
        }
    }

    private func formatted(_ value: Double) -> String {
        let places = min(3, max(0, decimalPlaces))
        let p = pow(10.0, Double(places))
        let rounded = (value * p).rounded() / p
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return "$" + groupedDecimalStringChart(rounded, fractionDigits: places)
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return groupedDecimalStringChart(rounded, fractionDigits: places) + "%"
        default:
            let raw = groupedDecimalStringChart(rounded, fractionDigits: places)
            return unitRaw == ObjectivesAddView.UnitOption.defaultUnit ? raw : "\(raw) \(unitRaw)"
        }
    }
}

struct DataSourcesPlaceholderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext

    let outcomeID: UUID
    let formatRaw: String
    let unitRaw: String
    let decimalPlaces: Int

    @Query private var entries: [OutcomesMeasureEntry]
    @Query private var snapshots: [OutcomesMeasure]
    @Query private var outcomes: [Outcomes]

    @State private var isAppleHealthEnabled = false
    @State private var selectedMetricIdentifierRaw: String = ""
    @State private var metricOptions: [OutcomeHealthKitBridge.MetricOption] = []
    @State private var isSyncing = false
    @State private var syncMessage: String?
    @State private var didHydrate = false
    @State private var isHydratingStoredConfiguration = false
    @State private var showAppleHealthAccessAlert = false
    @State private var appleHealthAccessAlertBody = ""
    @State private var showReturnWithoutAccessOption = false
    @State private var isCheckingAuthorizationBeforeExit = false
    @State private var lastSyncUnix: Double = 0

    init(outcomeID: UUID, formatRaw: String, unitRaw: String, decimalPlaces: Int) {
        self.outcomeID = outcomeID
        self.formatRaw = formatRaw
        self.unitRaw = unitRaw
        self.decimalPlaces = decimalPlaces
        let entriesPredicate = #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID }
        _entries = Query(filter: entriesPredicate, sort: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)])
        let snapshotsPredicate = #Predicate<OutcomesMeasure> { $0.outcome_id == outcomeID }
        _snapshots = Query(filter: snapshotsPredicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .reverse)])
        let outcomePredicate = #Predicate<Outcomes> { $0.outcome_id == outcomeID }
        _outcomes = Query(filter: outcomePredicate)
    }

    var body: some View {
        List {
            Section("Apple Health") {
                HStack(spacing: 10) {
                    Image(systemName: "heart")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                        .frame(width: 24, height: 24)
                        .overlay(
                            RoundedRectangle(cornerRadius: 7)
                                .stroke(Color.primary.opacity(0.9), lineWidth: 1)
                        )
                    Text("Apple Health")
                    Spacer()
                    Toggle("", isOn: $isAppleHealthEnabled)
                        .labelsHidden()
                }

                if isAppleHealthEnabled {
                    Picker("Metric", selection: $selectedMetricIdentifierRaw) {
                        Text("Select...").tag("")
                        ForEach(metricOptions) { option in
                            Text(option.displayName).tag(option.identifierRaw)
                        }
                    }
                    .pickerStyle(.navigationLink)

                    HStack(spacing: 10) {
                        Button(isSyncing ? "Syncing..." : "Sync Now") {
                            syncFromAppleHealth()
                        }
                        .disabled(isSyncing || selectedMetricIdentifierRaw.isEmpty)
                        .foregroundStyle(.blue)

                        Spacer(minLength: 8)

                        if let lastSyncText {
                            Text(lastSyncText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.8)
                        }
                    }
                }
            }

            if let syncMessage, !syncMessage.isEmpty {
                Section {
                    Text(syncMessage)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Connect Apple Health")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(true)
        .toolbar {
            ToolbarItem(placement: .navigationBarLeading) {
                Button {
                    attemptDismissDataSourcesView()
                } label: {
                    Label("Back", systemImage: "chevron.left")
                }
                .disabled(isCheckingAuthorizationBeforeExit)
            }
        }
        .toolbarBackground(.visible, for: .navigationBar)
        .alert("Apple Health Access Needed", isPresented: $showAppleHealthAccessAlert) {
            Button("Open Settings") { openAppSettings() }
            if showReturnWithoutAccessOption {
                Button("Return Without Access", role: .destructive) {
                    showReturnWithoutAccessOption = false
                    dismiss()
                }
                Button("Stay", role: .cancel) {
                    showReturnWithoutAccessOption = false
                }
            } else {
                Button("Cancel", role: .cancel) { }
            }
        } message: {
            Text(appleHealthAccessAlertBody)
        }
        .onAppear {
            guard !didHydrate else { return }
            didHydrate = true
            metricOptions = OutcomeHealthKitBridge.availableMetricOptions()
            hydrateStoredConfiguration()
        }
        .onChange(of: isAppleHealthEnabled) { _, newValue in
            guard !isHydratingStoredConfiguration else { return }
            if newValue {
                requestAuthorizationForToggle()
            } else {
                persistConfiguration()
            }
        }
        .onChange(of: selectedMetricIdentifierRaw) { _, _ in
            guard !isHydratingStoredConfiguration else { return }
            persistConfiguration()
        }
        .onDisappear {
            if isAppleHealthEnabled && selectedMetricIdentifierRaw.isEmpty {
                isAppleHealthEnabled = false
                persistConfiguration()
            }
        }
    }

    private func hydrateStoredConfiguration() {
        isHydratingStoredConfiguration = true
        defer { isHydratingStoredConfiguration = false }
        let snapshot = OutcomeHealthIntegrationStore.snapshot(for: outcomeID)
        isAppleHealthEnabled = snapshot.isEnabled
        lastSyncUnix = snapshot.lastSyncUnix ?? 0
        let stored = snapshot.metricIdentifierRaw ?? ""
        if metricOptions.contains(where: { $0.identifierRaw == stored }) {
            selectedMetricIdentifierRaw = stored
        } else {
            selectedMetricIdentifierRaw = ""
        }
    }

    private func persistConfiguration(lastSyncUnixOverride: Double? = nil) {
        OutcomeHealthIntegrationStore.setSnapshot(
            .init(
                isEnabled: isAppleHealthEnabled,
                metricIdentifierRaw: selectedMetricIdentifierRaw.isEmpty ? nil : selectedMetricIdentifierRaw,
                lastSyncUnix: lastSyncUnixOverride ?? (lastSyncUnix > 0 ? lastSyncUnix : nil)
            ),
            for: outcomeID
        )
    }

    private var lastSyncText: String? {
        guard lastSyncUnix > 0 else { return nil }
        return "Last sync: \(formatSyncTimestamp(Date(timeIntervalSince1970: lastSyncUnix)))"
    }

    private func formatSyncTimestamp(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .short
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private var authorizationProbeMetricIdentifier: String? {
        if !selectedMetricIdentifierRaw.isEmpty {
            return selectedMetricIdentifierRaw
        }
        return metricOptions.first?.identifierRaw
    }

    private func requestAuthorizationForToggle() {
        guard let identifier = authorizationProbeMetricIdentifier else {
            syncMessage = "No Apple Health metrics are available."
            isAppleHealthEnabled = false
            persistConfiguration()
            return
        }
        OutcomeHealthKitBridge.requestAuthorization(for: identifier) { result in
            DispatchQueue.main.async {
                switch result {
                case .success:
                    syncMessage = nil
                    persistConfiguration()
                case .failure(let error):
                    isAppleHealthEnabled = false
                    syncMessage = error.localizedDescription
                    persistConfiguration()
                    if OutcomeHealthKitBridge.isAuthorizationDenied(error) {
                        presentAppleHealthAccessAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func presentAppleHealthAccessAlert(message: String, allowReturnWithoutAccess: Bool = false) {
        appleHealthAccessAlertBody = message
        showReturnWithoutAccessOption = allowReturnWithoutAccess
        showAppleHealthAccessAlert = true
    }

    private func openAppSettings() {
        #if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
        #endif
    }

    private func syncFromAppleHealth() {
        guard isAppleHealthEnabled else { return }
        guard let range = outcomeDateRange else {
            syncMessage = "Outcome dates are unavailable."
            return
        }
        guard !selectedMetricIdentifierRaw.isEmpty else {
            syncMessage = "Select a metric first."
            return
        }

        isSyncing = true
        syncMessage = nil
        let syncRange = normalizedToDayRange(range)
        OutcomeHealthKitBridge.requestAuthorization(for: selectedMetricIdentifierRaw) { authResult in
            switch authResult {
            case .failure(let error):
                DispatchQueue.main.async {
                    isSyncing = false
                    syncMessage = error.localizedDescription
                    if OutcomeHealthKitBridge.isAuthorizationDenied(error) {
                        presentAppleHealthAccessAlert(message: error.localizedDescription)
                    }
                }
            case .success:
                OutcomeHealthKitBridge.readLatestPerDay(
                    identifierRaw: selectedMetricIdentifierRaw,
                    start: syncRange.lowerBound,
                    end: syncRange.upperBound
                ) { result in
                    DispatchQueue.main.async {
                        isSyncing = false
                        switch result {
                        case .failure(let error):
                            syncMessage = error.localizedDescription
                            if OutcomeHealthKitBridge.isAuthorizationDenied(error) {
                                presentAppleHealthAccessAlert(message: error.localizedDescription)
                            }
                        case .success(let dailyValues):
                            applySyncedRows(dailyValues, within: syncRange)
                            let syncedAtUnix = Date().timeIntervalSince1970
                            lastSyncUnix = syncedAtUnix
                            persistConfiguration(lastSyncUnixOverride: syncedAtUnix)
                            let timestamp = formatSyncTimestamp(Date(timeIntervalSince1970: syncedAtUnix))
                            syncMessage = dailyValues.isEmpty
                                ? "No Apple Health data found in the active outcome window. Last sync: \(timestamp)."
                                : "Synced \(dailyValues.count) day\(dailyValues.count == 1 ? "" : "s") from Apple Health. Last sync: \(timestamp)."
                        }
                    }
                }
            }
        }
    }

    private var needsAuthorizationValidationOnExit: Bool {
        isAppleHealthEnabled && !selectedMetricIdentifierRaw.isEmpty
    }

    private func attemptDismissDataSourcesView() {
        guard needsAuthorizationValidationOnExit else {
            dismiss()
            return
        }
        guard !isCheckingAuthorizationBeforeExit else { return }
        isCheckingAuthorizationBeforeExit = true
        OutcomeHealthKitBridge.requestAuthorization(for: selectedMetricIdentifierRaw) { result in
            switch result {
            case .failure(let error):
                DispatchQueue.main.async {
                    isCheckingAuthorizationBeforeExit = false
                    let message = error.localizedDescription
                    syncMessage = message
                    presentAppleHealthAccessAlert(
                        message: message,
                        allowReturnWithoutAccess: true
                    )
                }
            case .success:
                let today = Calendar.current.startOfDay(for: .now)
                OutcomeHealthKitBridge.readLatestPerDay(
                    identifierRaw: selectedMetricIdentifierRaw,
                    start: today,
                    end: today
                ) { readResult in
                    DispatchQueue.main.async {
                        isCheckingAuthorizationBeforeExit = false
                        switch readResult {
                        case .success:
                            dismiss()
                        case .failure(let error):
                            let message = error.localizedDescription
                            syncMessage = message
                            presentAppleHealthAccessAlert(
                                message: message,
                                allowReturnWithoutAccess: true
                            )
                        }
                    }
                }
            }
        }
    }

    private func normalizedToDayRange(_ range: ClosedRange<Date>) -> ClosedRange<Date> {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: range.lowerBound)
        let end = calendar.startOfDay(for: range.upperBound)
        return start...max(start, end)
    }

    private var outcomeDateRange: ClosedRange<Date>? {
        guard let outcome = outcomes.first else { return nil }
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: outcome.start)
        let end = min(calendar.startOfDay(for: outcome.end), calendar.startOfDay(for: .now))
        guard start <= end else { return nil }
        return start...end
    }

    private func applySyncedRows(_ rows: [OutcomeHealthKitBridge.DailyValue], within range: ClosedRange<Date>) {
        let calendar = Calendar.current
        let goalValue = currentGoalValue()
        let syncedDays = Set(rows.map { calendar.startOfDay(for: $0.day) })

        let appleHealthRowsByDay = Dictionary(grouping: entries.filter {
            guard let source = OutcomeMeasureEntrySourceStore.source(for: $0.id) else { return false }
            let day = calendar.startOfDay(for: $0.measuredAt)
            return source == "apple_health" && range.contains(day)
        }) { calendar.startOfDay(for: $0.measuredAt) }

        for row in rows {
            let day = calendar.startOfDay(for: row.day)
            let existingRows = (appleHealthRowsByDay[day] ?? []).sorted { $0.createdAt > $1.createdAt }
            if let keep = existingRows.first {
                keep.measure = row.value
                keep.measure_amt = goalValue
                keep.measuredAt = day
                keep.createdAt = .now
                keep.format = formatRaw
                keep.unit = unitRaw
                keep.decimalPlaces = decimalPlaces
                for extra in existingRows.dropFirst() {
                    OutcomeMeasureEntrySourceStore.removeSource(for: extra.id)
                    RecentlyDeletedStore.trash(extra, in: modelContext)
                }
            } else {
                let inserted = OutcomesMeasureEntry(
                    outcome_id: outcomeID,
                    measure: row.value,
                    measure_amt: goalValue,
                    measuredAt: day,
                    createdAt: .now,
                    format: formatRaw,
                    unit: unitRaw,
                    decimalPlaces: decimalPlaces
                )
                modelContext.insert(inserted)
                OutcomeMeasureEntrySourceStore.setSource("apple_health", for: inserted.id)
            }
        }

        for (day, dayRows) in appleHealthRowsByDay where !syncedDays.contains(day) {
            for stale in dayRows {
                OutcomeMeasureEntrySourceStore.removeSource(for: stale.id)
                RecentlyDeletedStore.trash(stale, in: modelContext)
            }
        }

        syncLatestSnapshot()
        try? modelContext.save()
    }

    private func currentGoalValue() -> Double {
        if let snapshot = snapshots.first, snapshot.measure_amt != 0 {
            return snapshot.measure_amt
        }
        if let latestEntry = entries.max(by: { $0.measuredAt < $1.measuredAt }) {
            return latestEntry.measure_amt
        }
        return 0
    }

    private func syncLatestSnapshot() {
        let descriptor = FetchDescriptor<OutcomesMeasureEntry>(
            predicate: #Predicate<OutcomesMeasureEntry> { $0.outcome_id == outcomeID },
            sortBy: [SortDescriptor(\OutcomesMeasureEntry.measuredAt, order: .reverse)]
        )
        let latestEntry = (try? modelContext.fetch(descriptor))?.first
        guard let latestEntry else { return }

        if let snapshot = snapshots.first {
            snapshot.measure = latestEntry.measure
            snapshot.measure_amt = latestEntry.measure_amt
            snapshot.measuredAt = latestEntry.measuredAt
            snapshot.measure_updated = .now
            snapshot.direction = nil
            snapshot.format = latestEntry.format ?? formatRaw
            snapshot.unit = latestEntry.unit ?? unitRaw
            snapshot.decimalPlaces = latestEntry.decimalPlaces ?? decimalPlaces
        } else {
            modelContext.insert(
                OutcomesMeasure(
                    outcome_id: outcomeID,
                    measure: latestEntry.measure,
                    measuredAt: latestEntry.measuredAt,
                    measure_amt: latestEntry.measure_amt,
                    measure_updated: .now,
                    direction: nil,
                    format: latestEntry.format ?? formatRaw,
                    unit: latestEntry.unit ?? unitRaw,
                    decimalPlaces: latestEntry.decimalPlaces ?? decimalPlaces
                )
            )
        }
    }
}
