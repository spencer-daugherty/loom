import SwiftUI
import SwiftData
import Charts

struct ObjectivesView: View {
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Outcomes.rank, order: .forward) private var outcomes: [Outcomes]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomeMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var outcomeMeasureEntries: [OutcomesMeasureEntry]
    @Query(sort: \CompletedOutcomeArchive.completedAt, order: .reverse) private var completedOutcomeArchives: [CompletedOutcomeArchive]
    @State private var isShowingSortSheet = false
    @State private var sortByDaysLeft = false
    @State private var sortDaysAscending = true
    @State private var navigationAction: NavigationAction?
    @State private var pendingSavedOutcomeID: UUID?
    @State private var showUpcoming = false
    @State private var showCompletedOutcomesPlaceholder = false
    private let oneTimeTargetPassedDemoFlag = "one_time_outcome_target_passed_demo_v1_done"
    private let oneTimeUnmeasurablePassedDemoFlag = "one_time_outcome_unmeasurable_target_passed_demo_v1_done"
    private var sortSheetHeight: CGFloat {
        let rows = CGFloat(activeOutcomesForSort.count)
        return min(max(260, rows * 56 + 140), 620)
    }

    private var activeOutcomesForSort: [Outcomes] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        return outcomes.filter { calendar.startOfDay(for: $0.start) <= today }
    }

    enum NavigationAction: Identifiable {
        case addOutcome
        case editOutcome(Outcomes)
        case completedOutcome(CompletedOutcomeArchive)

        var id: String {
            switch self {
            case .addOutcome:
                return "addOutcome"
            case .editOutcome(let outcome):
                return "editOutcome_\(outcome.outcome_id.uuidString)"
            case .completedOutcome(let archive):
                return "completedOutcome_\(archive.id.uuidString)"
            }
        }
    }

    private var filteredOutcomes: [Outcomes] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        
        let filtered = outcomes.filter { outcome in
            let startOfStartDate = calendar.startOfDay(for: outcome.start)
            return showUpcoming ? startOfStartDate > today : startOfStartDate <= today
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

    private var sortedCompletedOutcomes: [CompletedOutcomeArchive] {
        completedOutcomeArchives.sorted { $0.completedAt > $1.completedAt }
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
                                Button(action: {
                                    sortByDaysLeft = false
                                    isShowingSortSheet = true
                                }) {
                                    Text("Prioritize")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                                Button(action: {
                                    sortByDaysLeft = true
                                    sortDaysAscending.toggle()
                                }) {
                                    Text("Sort by Days")
                                        .font(.subheadline)
                                        .foregroundColor(.blue)
                                        .padding(.vertical, 4)
                                        .padding(.horizontal, 8)
                                }
                                HStack(spacing: 6) {
                                    Text("Upcoming")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                    Toggle("", isOn: $showUpcoming)
                                        .labelsHidden()
                                        .toggleStyle(.switch)
                                        .tint(.blue)
                                }
                                .frame(maxWidth: .infinity, alignment: .trailing)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Outcomes List
                    OutcomesSectionCard {
                        VStack(spacing: 8) {
                            ForEach(filteredOutcomes) { outcome in
                                let latest = latestMeasure(for: outcome)
                                Button(action: { navigationAction = .editOutcome(outcome) }) {
                                    OutcomeRow(
                                        outcome: outcome,
                                        measure: latest,
                                        startMeasure: startMeasure(for: outcome, latestMeasure: latest)
                                    )
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

                    VStack(alignment: .leading, spacing: 4) {
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showCompletedOutcomesPlaceholder.toggle()
                            }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: showCompletedOutcomesPlaceholder ? "chevron.up" : "chevron.down")
                                    .font(.caption2.weight(.semibold))
                                Text("Outcomes Completed")
                                    .font(.caption2.weight(.semibold))
                            }
                            .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : .black)
                            .padding(.vertical, 5)
                            .padding(.horizontal, 8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color(.systemGray4))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if showCompletedOutcomesPlaceholder {
                            if sortedCompletedOutcomes.isEmpty {
                                Text("No completed outcomes yet.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.leading, 2)
                            } else {
                                ForEach(sortedCompletedOutcomes) { archive in
                                    Button {
                                        navigationAction = .completedOutcome(archive)
                                    } label: {
                                        CompletedOutcomeRow(archive: archive)
                                    }
                                    .buttonStyle(.plain)
                                }
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
                                Button(action: {}) {
                                    Text("Prioritize")
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
        .sheet(item: $navigationAction, onDismiss: {
            guard let savedID = pendingSavedOutcomeID else { return }
            pendingSavedOutcomeID = nil
            if let savedOutcome = outcomes.first(where: { $0.outcome_id == savedID }) {
                DispatchQueue.main.async {
                    navigationAction = .editOutcome(savedOutcome)
                }
            }
        }) { action in
            switch action {
            case .addOutcome:
                ObjectivesAddView(onSaved: { savedID in
                    pendingSavedOutcomeID = savedID
                })
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            case .editOutcome(let outcome):
                OutcomeView(outcome: outcome, outcomeMeasure: latestMeasure(for: outcome))
                    .id(outcome.outcome_id)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            case .completedOutcome(let archive):
                CompletedOutcomeDetailView(archive: archive)
                    .id(archive.id)
                    .presentationDetents([.large])
                    .presentationContentInteraction(.scrolls)
                    .presentationDragIndicator(.visible)
            }
        }
        .sheet(isPresented: $isShowingSortSheet) {
            SortOutcomesView(outcomes: outcomes)
                .environment(\.modelContext, modelContext)
                .presentationDetents([.height(sortSheetHeight)])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isShowingSortSheet) { _, isShowing in
            if !isShowing {
                // Ensure list returns to rank-based order after prioritize flow closes.
                sortByDaysLeft = false
            }
        }
        .onAppear {
            showUpcoming = false
            seedOneTimeTargetPassedDemoOutcomeIfNeeded()
            seedOneTimeUnmeasurablePassedDemoOutcomeIfNeeded()
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func seedOneTimeTargetPassedDemoOutcomeIfNeeded() {
        guard UserDefaults.standard.bool(forKey: oneTimeTargetPassedDemoFlag) == false else { return }

        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -20, to: now) ?? now)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -3, to: now) ?? now)

        let existing = outcomes.contains {
            $0.outcome == "Demo: Target Passed (Goal Not Met)" && $0.reasons == "One-time seeded demo outcome."
        }
        guard !existing else {
            UserDefaults.standard.set(true, forKey: oneTimeTargetPassedDemoFlag)
            return
        }

        let newOutcomeID = UUID()
        let newOutcome = Outcomes(
            outcome_id: newOutcomeID,
            category: "Health & Vitality",
            updatedAt: .now,
            outcome: "Demo: Target Passed (Goal Not Met)",
            reasons: "One-time seeded demo outcome.",
            start: start,
            end: end,
            rank: (outcomes.map(\.rank).max() ?? 0) + 1,
            format: ObjectivesAddView.MeasureFormat.number.rawValue
        )
        modelContext.insert(newOutcome)

        let goal: Double = 200
        let startMeasure: Double = 150
        let latestMeasure: Double = 170 // not met yet (direction is up from 150 -> 200)

        modelContext.insert(
            OutcomesMeasure(
                outcome_id: newOutcomeID,
                measure: latestMeasure,
                measuredAt: .now,
                measure_amt: goal,
                measure_updated: .now,
                direction: nil,
                format: ObjectivesAddView.MeasureFormat.number.rawValue,
                unit: ObjectivesAddView.UnitOption.defaultUnit,
                decimalPlaces: 0
            )
        )

        modelContext.insert(
            OutcomesMeasureEntry(
                outcome_id: newOutcomeID,
                measure: startMeasure,
                measure_amt: goal,
                measuredAt: start,
                createdAt: start,
                format: ObjectivesAddView.MeasureFormat.number.rawValue,
                unit: ObjectivesAddView.UnitOption.defaultUnit,
                decimalPlaces: 0
            )
        )

        modelContext.insert(
            OutcomesMeasureEntry(
                outcome_id: newOutcomeID,
                measure: latestMeasure,
                measure_amt: goal,
                measuredAt: calendar.startOfDay(for: calendar.date(byAdding: .day, value: -1, to: now) ?? now),
                createdAt: .now,
                format: ObjectivesAddView.MeasureFormat.number.rawValue,
                unit: ObjectivesAddView.UnitOption.defaultUnit,
                decimalPlaces: 0
            )
        )

        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: oneTimeTargetPassedDemoFlag)
    }

    private func seedOneTimeUnmeasurablePassedDemoOutcomeIfNeeded() {
        guard UserDefaults.standard.bool(forKey: oneTimeUnmeasurablePassedDemoFlag) == false else { return }

        let calendar = Calendar.current
        let now = Date()
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -35, to: now) ?? now)
        let end = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -5, to: now) ?? now)

        let existing = outcomes.contains {
            $0.outcome == "Demo: Past Target (Unmeasurable)" && $0.reasons == "One-time seeded unmeasurable demo outcome."
        }
        guard !existing else {
            UserDefaults.standard.set(true, forKey: oneTimeUnmeasurablePassedDemoFlag)
            return
        }

        let newOutcome = Outcomes(
            outcome_id: UUID(),
            category: "Mind & Meaning",
            updatedAt: .now,
            outcome: "Demo: Past Target (Unmeasurable)",
            reasons: "One-time seeded unmeasurable demo outcome.",
            start: start,
            end: end,
            rank: (outcomes.map(\.rank).max() ?? 0) + 2,
            format: nil
        )
        modelContext.insert(newOutcome)
        try? modelContext.save()
        UserDefaults.standard.set(true, forKey: oneTimeUnmeasurablePassedDemoFlag)
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
        return components.day ?? 0
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.format != nil
    }

    private func latestMeasure(for outcome: Outcomes) -> OutcomesMeasure? {
        outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
    }

    private func startMeasure(for outcome: Outcomes, latestMeasure: OutcomesMeasure?) -> Double? {
        if let first = outcomeMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id }) {
            return first.measure
        }
        return latestMeasure?.measure
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
    let startMeasure: Double?

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
                    let dayValue = isUpcoming ? daysBetween(outcome.start, outcome.end) : daysUntil(outcome.end)
                    let shouldShowRed = !isUpcoming && dayValue < 0
                    VStack(spacing: 2) {
                        Text("\(dayValue)")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(shouldShowRed ? .red : .black)
                        Text(isUpcoming ? "days long" : "days left")
                            .font(.caption2)
                            .foregroundColor(shouldShowRed ? .red : .black)
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
                            startMeasure: startMeasure
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
        return components.day ?? 0
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.format != nil
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }
}

struct CompletedOutcomeRow: View {
    let archive: CompletedOutcomeArchive
    var showsChevron: Bool = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Spacer()
                    Text("\(formattedDate(archive.start)) - \(formattedDate(archive.completedAt))")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                }
                Text(archive.outcome)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor(for: archive.category))
                    .multilineTextAlignment(.leading)
                    .lineLimit(3)
                Text(archive.reasons)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .lineLimit(4)
                    .padding(.bottom, 2)
                HStack(spacing: 8) {
                    VStack(spacing: 2) {
                        Text("\(archive.daysElapsed)d")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(.black)
                        Text("elapsed")
                            .font(.caption2)
                            .foregroundColor(.black)
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 10)
                    .background(
                        RoundedRectangle(cornerRadius: 8)
                            .fill(lightenedCategoryColor(for: archive.category))
                    )
                    .frame(height: 44)

                    if archive.isMeasurable {
                        VStack(spacing: 2) {
                            Text(archive.goalMet ? "Met" : "Not Met")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(archive.goalMet ? .green : .red)
                            Text("goal status")
                                .font(.caption2)
                                .foregroundColor(.black)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                        .frame(height: 44)

                        MeasurableOutcomeBox(
                            measure: archive.finalValue ?? 0,
                            measuredAt: archive.completedAt,
                            measureAmt: archive.goalValue ?? 0,
                            endDate: archive.end,
                            format: archive.format ?? ObjectivesAddView.MeasureFormat.number.rawValue
                        )
                        .frame(height: 44)

                        ProgressCircleView(
                            measure: archive.finalValue ?? 0,
                            measureAmt: archive.goalValue ?? 0,
                            startMeasure: 0
                        )
                        .frame(width: 40, height: 40)
                    } else {
                        VStack(spacing: 2) {
                            Text("\(successLevelNumber)/5")
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            Text("success")
                                .font(.caption2)
                                .foregroundColor(.primary)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.systemGray5))
                        )
                        .frame(height: 44)

                        Text(successDescription(for: successLevelNumber))
                            .font(.system(size: 40, weight: .bold))
                            .foregroundStyle(.gray)
                            .lineLimit(1)
                            .minimumScaleFactor(0.1)
                            .allowsTightening(true)
                            .frame(maxWidth: .infinity, minHeight: 44, maxHeight: 44, alignment: .leading)
                            .padding(.horizontal, 10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray, lineWidth: 3)
                            )
                    }
                }
            }
            Spacer()
            if showsChevron {
                Image(systemName: "chevron.right")
                    .foregroundColor(.gray)
                    .padding(.trailing, 8)
            }
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

    private var successLevelNumber: Int {
        max(1, min(5, archive.successLevel ?? 3))
    }

    private func successDescription(for level: Int) -> String {
        switch level {
        case 1: return "Regressed Significantly"
        case 2: return "Regressed Somewhat"
        case 3: return "Partially Acheived"
        case 4: return "Fully Acheived"
        case 5: return "Overacheived"
        default: return "Partially Acheived"
        }
    }

    private func formattedDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yy"
        return formatter.string(from: date)
    }
}

struct CompletedOutcomeDetailView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    let archive: CompletedOutcomeArchive
    @Query(sort: \CompletedOutcomeContributionArchive.completedAt, order: .forward) private var contributionRows: [CompletedOutcomeContributionArchive]
    @Query(sort: \CompletedOutcomeMeasurePointArchive.measuredAt, order: .forward) private var measureRows: [CompletedOutcomeMeasurePointArchive]
    @State private var isShowingDeleteAlert = false

    private var contributions: [CompletedOutcomeContributionArchive] {
        contributionRows.filter { $0.completedOutcomeArchiveId == archive.id }
    }

    private var measures: [CompletedOutcomeMeasurePointArchive] {
        measureRows.filter { $0.completedOutcomeArchiveId == archive.id }
    }

    private var contributionByDay: [(Date, Int)] {
        let cal = Calendar.current
        let grouped = Dictionary(grouping: contributions) { cal.startOfDay(for: $0.completedAt) }
        return grouped.map { ($0.key, $0.value.count) }.sorted { $0.0 < $1.0 }
    }

    private var progressHighlights: [String] {
        guard measures.count > 1 else { return [] }
        let deltas: [(Date, Double)] = zip(measures.dropFirst(), measures).map { current, prev in
            (current.measuredAt, current.measure - prev.measure)
        }
        let top = deltas.sorted { abs($0.1) > abs($1.1) }.prefix(3)
        let fmt = DateFormatter()
        fmt.dateFormat = "M/d"
        return top.map { date, delta in
            let sign = delta >= 0 ? "+" : ""
            return "\(fmt.string(from: date)): \(sign)\(String(format: "%.1f", delta))"
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CompletedOutcomeRow(archive: archive, showsChevron: false)
                }

                Section("Insights") {
                    insightRow("Goal pushes", "\(archive.goalPushCount)")
                    insightRow("Data entered", "\(archive.dataEntryCount)")
                    insightRow("Target changes", "\(archive.targetChangeCount)")
                    if !progressHighlights.isEmpty {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Times with lots of progress")
                                .font(.subheadline.weight(.semibold))
                            ForEach(progressHighlights, id: \.self) { line in
                                Text("• \(line)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                if !contributionByDay.isEmpty {
                    Section("Contributing Actions Over Time") {
                        Chart(contributionByDay, id: \.0) { row in
                            BarMark(
                                x: .value("Date", row.0),
                                y: .value("Count", row.1)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                        .frame(height: 180)
                    }
                }

                Section("Contributing Actions") {
                    if contributions.isEmpty {
                        Text("No contributing actions logged.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contributions) { row in
                            HStack(alignment: .top, spacing: 10) {
                                Text(row.actionText)
                                    .font(.body)
                                Spacer()
                                Text(row.completedAt, format: .dateTime.month().day().year())
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.vertical, 2)
                        }
                    }
                }

                Section("Journal") {
                    journalBox(title: "Wins", text: archive.journalWins)
                    journalBox(title: "Learned", text: archive.journalLearned)
                    journalBox(title: "Next", text: archive.journalNext)
                }

                Section {
                    Button("Delete") {
                        isShowingDeleteAlert = true
                    }
                    .foregroundColor(.red)
                }
            }
            .navigationTitle("Completed Outcome")
            .navigationBarTitleDisplayMode(.inline)
            .alert("Delete Outcome?", isPresented: $isShowingDeleteAlert) {
                Button("Delete", role: .destructive) {
                    RecentlyDeletedStore.trash(archive, in: modelContext, source: "Completed Outcome")
                    try? modelContext.save()
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("Are you sure you want to delete this outcome? It will be available for 30 days in account management.")
            }
        }
    }

    private func metricPill(value: String, caption: String, valueColor: Color = .primary) -> some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title3.weight(.bold))
                .foregroundStyle(valueColor)
            Text(caption)
                .font(.caption2)
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color(.systemGray5)))
    }

    private func insightRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }

    private func journalBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.usesGroupingSeparator = true
        formatter.maximumFractionDigits = 0
        formatter.minimumFractionDigits = 0
        let grouped = formatter.string(from: NSNumber(value: value)) ?? String(format: "%.0f", value)
        switch format {
        case "Dollars": return "$\(grouped)"
        case "Percentage": return "\(grouped)%"
        default: return grouped
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
    let startMeasure: Double?

    private var progress: Double {
        guard measureAmt != 0 else { return 0 }
        let start = startMeasure ?? measure
        return Self.progressValue(current: measure, goal: measureAmt, start: start)
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

    static func progressValue(current: Double, goal: Double, start: Double) -> Double {
        guard goal != 0 else { return 0 }
        if goal == start {
            return min(max(current / goal, 0), 1)
        }
        if goal > start {
            return min(max((current - start) / (goal - start), 0), 1)
        } else {
            return min(max((start - current) / (start - goal), 0), 1)
        }
    }
}

struct SortOutcomesView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var outcomes: [Outcomes]

    init(outcomes: [Outcomes]) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        _outcomes = State(initialValue: outcomes.filter {
            calendar.startOfDay(for: $0.start) <= today
        })
    }

    var body: some View {
        VStack(spacing: 10) {
            Color.clear.frame(height: 8)

            Text("Prioritize Outcomes")
                .font(.headline)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 6)
            Text("Top 4 will remain visible on home screen")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)

            List {
                ForEach(outcomes.indices, id: \.self) { idx in
                    VStack(spacing: 0) {
                        Text(outcomes[idx].outcome)
                            .font(.body)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 12)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onMove { indices, newOffset in
                    outcomes.move(fromOffsets: indices, toOffset: newOffset)
                }
            }
            .listStyle(.plain)
            .environment(\.editMode, .constant(.active))

        }
        .onDisappear {
            saveRanks()
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
                .modelContainer(for: [Outcomes.self, OutcomesArchive.self, OutcomesMeasure.self, OutcomesMeasureArchive.self, CompletedOutcomeArchive.self, CompletedOutcomeContributionArchive.self, CompletedOutcomeMeasurePointArchive.self], inMemory: true)
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
