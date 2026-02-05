import SwiftUI
import Charts
import SwiftData

struct ObjectivesAddViewChart: View {
    let outcome_id: UUID
    @State private var selectedTimeRange: String = "W"
    @Environment(\.modelContext) private var modelContext
    @Query private var measures: [OutcomesMeasure]
    
    private let timeRanges = ["W", "M", "3M", "6M", "Y"]
    
    init(outcome_id: UUID) {
        self.outcome_id = outcome_id
        let predicate = #Predicate<OutcomesMeasure> { measure in
            measure.outcome_id == outcome_id
        }
        _measures = Query(filter: predicate, sort: [SortDescriptor(\OutcomesMeasure.measuredAt, order: .forward)])
    }
    
    var body: some View {
        GeometryReader { geometry in
            VStack(spacing: 0) {
                Picker("Time Range", selection: $selectedTimeRange) {
                    ForEach(timeRanges, id: \.self) { range in
                        Text(range).tag(range)
                    }
                }
                .pickerStyle(.segmented)
                
                if let latestMeasure = measures.filter({ $0.measure != 0 }).max(by: { $0.measuredAt < $1.measuredAt }) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(formatMeasure(latestMeasure.measure))
                            .foregroundStyle(.blue)
                            .font(.headline)
                        Text(latestMeasure.measuredAt, format: .dateTime.weekday(.abbreviated).month(.wide).day().year())
                            .foregroundStyle(.gray)
                            .font(.caption)
                    }
                    .padding(.top, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
                
                Chart {
                    ForEach(measures.filter { $0.measure_amt != 0 }) { measure in
                        RuleMark(
                            y: .value("Measure Amount", measure.measure_amt)
                        )
                        .lineStyle(.init(dash: [5, 5]))
                        .foregroundStyle(.gray)
                    }
                    
                    ForEach(measures.filter { $0.measure != 0 }) { measure in
                        PointMark(
                            x: .value("Date", Calendar.current.startOfDay(for: measure.measuredAt)),
                            y: .value("Measure", measure.measure)
                        )
                        .symbol(.circle)
                        .symbolSize(100)
                        .foregroundStyle(.blue)
                        
                        LineMark(
                            x: .value("Date", Calendar.current.startOfDay(for: measure.measuredAt)),
                            y: .value("Measure", measure.measure)
                        )
                        .foregroundStyle(.blue)
                    }
                    
                    if let outcome = fetchOutcome() {
                        RuleMark(
                            x: .value("Start Date", Calendar.current.startOfDay(for: outcome.start))
                        )
                        .foregroundStyle(.green)
                        .lineStyle(.init(dash: [5, 5]))
                        
                        RuleMark(
                            x: .value("End Date", Calendar.current.startOfDay(for: outcome.end))
                        )
                        .foregroundStyle(.red)
                        .lineStyle(.init(dash: [5, 5]))
                    }
                }
                .chartScrollableAxes([])
                .chartXScale(domain: coreDateRange())
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
                    AxisMarks(position: .trailing, values: .automatic) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: geometry.size.height - 80)
            }
        }
        .frame(height: UIScreen.main.bounds.height / 3)
    }
    
    private func formatMeasure(_ value: Double) -> String {
        if value.truncatingRemainder(dividingBy: 1) == 0 {
            return String(format: "%.0f", value)
        } else {
            return String(format: "%.2f", value)
        }
    }
    
    private func fetchOutcome() -> Outcomes? {
        let descriptor = FetchDescriptor<Outcomes>(
            predicate: #Predicate { outcome in
                outcome.outcome_id == outcome_id
            }
        )
        return try? modelContext.fetch(descriptor).first
    }
    
    private func coreDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let latestMeasureDate = measures
            .filter { $0.measure != 0 }
            .map { calendar.startOfDay(for: $0.measuredAt) }
            .max() ?? calendar.startOfDay(for: Date())
        
        let days: Int = switch selectedTimeRange {
        case "W": 7
        case "M": 30
        case "3M": 60
        case "6M": 120
        case "Y": 270 // Changed from 365 to 270 for 9 months back
        default: 7
        }
        
        let startDate = calendar.date(byAdding: .day, value: -(days - 1), to: latestMeasureDate)!
        let endDate = extendedEndDate(from: latestMeasureDate)
        
        return startDate...endDate
    }
    
    private func extendedEndDate(from baseDate: Date) -> Date {
        let calendar = Calendar.current
        return switch selectedTimeRange {
        case "W":
            calendar.date(byAdding: .day, value: 1, to: baseDate)!
        case "M":
            calendar.date(byAdding: .day, value: 7, to: baseDate)!
        case "3M":
            calendar.date(byAdding: .month, value: 1, to: baseDate)!
        case "6M":
            calendar.date(byAdding: .month, value: 2, to: baseDate)!
        case "Y":
            calendar.date(byAdding: .month, value: 3, to: baseDate)! // Already set to 3 months forward
        default:
            calendar.date(byAdding: .day, value: 1, to: baseDate)!
        }
    }
    
    private func yAxisRange() -> ClosedRange<Double> {
        let measures = measures.filter { $0.measure != 0 || $0.measure_amt != 0 }
        let values = measures.flatMap { [$0.measure, $0.measure_amt] }.filter { $0 != 0 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 100
        let padding = (maxValue - minValue) * 0.1
        return (minValue - padding)...(maxValue + padding)
    }
    
    private func xAxisValues() -> [Date] {
        let calendar = Calendar.current
        let range = coreDateRange()
        let startDate = range.lowerBound
        let endDate = range.upperBound
        
        var dates: [Date] = []
        var currentDate = startDate
        
        switch selectedTimeRange {
        case "W":
            while currentDate <= endDate {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        case "M":
            while currentDate <= endDate {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 7, to: currentDate)!
            }
        case "3M", "6M", "Y":
            while currentDate <= endDate {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .month, value: 1, to: currentDate)!
            }
        default:
            while currentDate <= endDate {
                dates.append(currentDate)
                currentDate = calendar.date(byAdding: .day, value: 1, to: currentDate)!
            }
        }
        
        return dates
    }
    
    private func xAxisLabelFormat() -> Date.FormatStyle {
        switch selectedTimeRange {
        case "W":
            return .dateTime.weekday(.abbreviated)
        case "M":
            return .dateTime.month(.defaultDigits).day()
        case "3M", "6M", "Y":
            return .dateTime.month(.abbreviated)
        default:
            return .dateTime.weekday(.abbreviated)
        }
    }
}
