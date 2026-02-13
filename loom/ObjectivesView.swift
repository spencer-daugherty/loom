import SwiftUI
import SwiftData

struct ObjectivesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outcomes.rank, order: .forward) private var outcomes: [Outcomes]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomeMeasures: [OutcomesMeasure]
    @State private var isShowingSortSheet = false
    @State private var sortByDaysLeft = false
    @State private var sortDaysAscending = true
    @State private var navigationAction: NavigationAction?
    @State private var showUpcoming = true

    enum NavigationAction: Identifiable {
        case addOutcome
        case editOutcome(Outcomes)

        var id: String {
            switch self {
            case .addOutcome:
                return "addOutcome"
            case .editOutcome(let outcome):
                return "editOutcome_\(outcome.outcome_id.uuidString)"
            }
        }
    }

    private var filteredOutcomes: [Outcomes] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        let filtered = outcomes.filter { outcome in
            let startOfStartDate = calendar.startOfDay(for: outcome.start)
            return showUpcoming ? startOfStartDate <= today : startOfStartDate > today
        }
        
        if sortByDaysLeft {
            return filtered.sorted { outcome1, outcome2 in
                let days1 = daysUntil(outcome1.end)
                let days2 = daysUntil(outcome2.end)
                return sortDaysAscending ? days1 < days2 : days1 > days2
            }
        }
        return filtered
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(.systemGray6))
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    // Outcomes Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Outcomes")
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack {
                                Text("Arrange by:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button(action: { isShowingSortSheet = true }) {
                                    Text("Focus")
                                        .font(.subheadline)
                                        .foregroundColor(showUpcoming ? .blue : .gray)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                                .disabled(!showUpcoming)
                                Button(action: {
                                    sortByDaysLeft = true
                                    sortDaysAscending.toggle()
                                }) {
                                    Text("Days")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                                Button(action: { showUpcoming.toggle() }) {
                                    Text(showUpcoming ? "Upcoming" : "Active")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Outcomes List
                    OutcomesSectionCard {
                        VStack(spacing: 8) {
                            ForEach(filteredOutcomes) { outcome in
                                Button(action: { navigationAction = .editOutcome(outcome) }) {
                                    OutcomeRow(outcome: outcome, measure: latestMeasure(for: outcome))
                                }
                            }
                            Button(action: { navigationAction = .addOutcome }) {
                                Text("Add Outcome")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // Projects Header
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Projects")
                                .font(.title2)
                                .fontWeight(.bold)
                            HStack {
                                Text("Arrange by:")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Button(action: {}) {
                                    Text("Focus")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                                Button(action: {}) {
                                    Text("Days left")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Projects Placeholder
                    OutcomesSectionCard {
                        VStack(spacing: 8) {
                            Button(action: {}) {
                                Text("Add Project")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Objectives")
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture { hideKeyboard() }
        )
        .sheet(item: $navigationAction) { action in
            switch action {
            case .addOutcome:
                ObjectivesAddView()
            case .editOutcome(let outcome):
                ObjectivesAddView(outcome: outcome, outcomeMeasure: latestMeasure(for: outcome))
            }
        }
        .sheet(isPresented: $isShowingSortSheet) {
            SortOutcomesView(outcomes: outcomes)
                .environment(\.modelContext, modelContext)
        }
        .onAppear { showUpcoming = true }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
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

    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
        return max(0, components.day ?? 0)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.direction != nil && measure.format != nil
    }

    private func latestMeasure(for outcome: Outcomes) -> OutcomesMeasure? {
        outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

// MARK: - Subviews

struct OutcomeRow: View {
    let outcome: Outcomes
    let measure: OutcomesMeasure?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                let isUpcoming = Calendar.current.startOfDay(for: outcome.start) > Calendar.current.startOfDay(for: .now)
                if isUpcoming {
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("starts on \(formattedDate(outcome.start))")
                            .font(.caption)
                            .foregroundColor(.gray)
                    }
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color(.systemGray5))
                    )
                    .padding(.bottom, 4)
                }
                Text(outcome.outcome)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor(for: outcome.category))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Text(outcome.reasons)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .padding(.bottom, 2)
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text("\(isUpcoming ? daysBetween(outcome.start, outcome.end) : daysUntil(outcome.end))")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Text(isUpcoming ? "days long" : "days left")
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lightenedCategoryColor(for: outcome.category))
                    )
                    .frame(height: 44)

                    if let measure, isOutcomeMeasurable(measure) {
                        MeasurableOutcomeBox(
                            measure: measure.measure,
                            measuredAt: measure.measuredAt,
                            measureAmt: measure.measure_amt,
                            endDate: outcome.end,
                            format: measure.format ?? "Number"
                        )
                        .frame(height: 44)

                        ProgressCircleView(
                            measure: measure.measure,
                            measureAmt: measure.measure_amt,
                            direction: measure.direction ?? MeasureDirection.up.rawValue
                        )
                        .frame(width: 40, height: 40)
                    }
                }
                Divider()
                    .background(Color.gray.opacity(0.3))
                    .padding(.top, 20)
            }
            Spacer()
            Image(systemName: "chevron.right")
                .foregroundColor(.gray)
                .padding(.trailing, 8)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
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

    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
        return max(0, components.day ?? 0)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.direction != nil && measure.format != nil
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct MeasurableOutcomeBox: View {
    @Environment(\.colorScheme) private var colorScheme

    let measure: Double
    let measuredAt: Date
    let measureAmt: Double
    let endDate: Date
    let format: String

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let isSameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let formatter = DateFormatter()
        formatter.dateFormat = isSameYear ? "M/d" : "M/d/yy"
        return formatter.string(from: date)
    }

    private func formattedValue(_ value: Double, format: String) -> String {
        let roundedValue = String(format: "%.0f", value)
        switch format {
        case "Dollars": return "$\(roundedValue)"
        case "Percentage": return "\(roundedValue)%"
        default: return roundedValue
        }
    }

    var body: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(formattedValue(measure, format: format))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("updated \(formattedDate(measuredAt))")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(colorScheme == .dark ? Color.white.opacity(0.2) : Color.gray.opacity(0.3))
                .frame(width: 1)

            VStack(spacing: 2) {
                Text(formattedValue(measureAmt, format: format))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("\(formattedDate(endDate)) goal")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemGray5))
        )
    }
}

struct ProgressCircleView: View {
    @Environment(\.colorScheme) private var colorScheme

    let measure: Double
    let measureAmt: Double
    let direction: String

    private var progress: Double {
        guard measureAmt != 0 else { return 0 }
        let isUpDirection = direction == MeasureDirection.up.rawValue
        if isUpDirection {
            return min(max(measure / measureAmt, 0), 1)
        } else {
            return min(max((measure - measureAmt) / (0 - measureAmt), 0), 1)
        }
    }

    private var percentageText: String {
        String(format: "%.0f%%", progress * 100)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(colorScheme == .dark ? Color.white.opacity(0.25) : Color(.systemGray3), lineWidth: 4)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 4)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            Text(percentageText)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(colorScheme == .dark ? .white : .black)
        }
    }
}

struct SortOutcomesView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @State private var outcomes: [Outcomes]

    init(outcomes: [Outcomes]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        _outcomes = State(initialValue: outcomes.filter {
            calendar.startOfDay(for: $0.start) <= today
        })
    }

    var body: some View {
        NavigationStack {
            VStack {
                Text("Sort Outcomes")
                    .font(.title2)
                    .fontWeight(.bold)
                    .padding(.top)

                List {
                    ForEach(outcomes) { outcome in
                        Text(outcome.outcome)
                            .font(.body)
                            .padding(.vertical, 4)
                    }
                    .onMove { indices, newOffset in
                        outcomes.move(fromOffsets: indices, toOffset: newOffset)
                    }
                }
                .environment(\.editMode, .constant(.active))

                Spacer()

                Button(action: {
                    saveRanks()
                    dismiss()
                }) {
                    Text("Done")
                        .font(.body)
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.blue)
                        .cornerRadius(8)
                }
                .padding(.horizontal)
                .padding(.bottom)
            }
        }
    }
    
    private func saveRanks() {
        for (index, outcome) in outcomes.enumerated() {
            outcome.rank = index
        }
        try? modelContext.save()
    }
}

struct OutcomesSectionCard<Content: View>: View {
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            content()
                .padding(.horizontal)
                .padding(.vertical, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: .black.opacity(0.1), radius: 6, x: 0, y: 3)
    }
}

struct ObjectivesView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationStack {
            ObjectivesView()
                .modelContainer(for: [Outcomes.self, OutcomesArchive.self, OutcomesMeasure.self, OutcomesMeasureArchive.self], inMemory: true)
        }
    }
}

enum MeasureDirection: String {
    case up = "↑"
    case down = "↓"
}

// MARK: - Extensions

extension UIColor {
    func adjusted(by factor: CGFloat) -> UIColor {
        var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
        getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        red += (1.0 - red) * factor
        green += (1.0 - green) * factor
        blue += (1.0 - blue) * factor
        return UIColor(red: red, green: green, blue: blue, alpha: alpha)
    }
}
