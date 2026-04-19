import SwiftUI
import SwiftData
import Charts

private enum CompletedOutcomePassionsDetailStore {
    struct Snapshot: Codable, Identifiable {
        var id: UUID { passionID }
        let passionID: UUID
        let emotion: String
        let passion: String
    }

    private static let defaultsKey = "completed_outcome_passions_v1"

    static func snapshots(for completedArchiveID: UUID) -> [Snapshot] {
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              let decoded = try? JSONDecoder().decode([String: [Snapshot]].self, from: data) else {
            return []
        }
        return decoded[completedArchiveID.uuidString] ?? []
    }
}

#Preview {
    NavigationStack {
        ObjectivesView(autoOpenAddOutcome: false)
    }
    .loomPreviewContainer()
}

private func displayEmotionLabelObjectives(_ raw: String) -> String {
    switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
    case "just": return "Hate"
    case "vows": return "Vow"
    default: return raw.capitalized
    }
}

struct ObjectivesView: View {
    let autoOpenAddOutcome: Bool
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage("enable_projects_feature") private var enableProjectsFeatureStorage = false
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
    @State private var hasAutoOpenedAddOutcome = false

    private var enableProjectsFeature: Bool {
        LoomDeveloperBuild.enabled(enableProjectsFeatureStorage)
    }

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

    private var hasUpcomingOutcomes: Bool {
        let today = Calendar.current.startOfDay(for: .now)
        return outcomes.contains { Calendar.current.startOfDay(for: $0.start) > today }
    }

    init(autoOpenAddOutcome: Bool = false) {
        self.autoOpenAddOutcome = autoOpenAddOutcome
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
                            Text("Goals")
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
                                if hasUpcomingOutcomes {
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
                        }
                        Spacer()
                    }
                    .padding(.horizontal)

                    // Outcomes List
                    OutcomesSectionCard {
                        VStack(spacing: 8) {
                            ForEach(filteredOutcomes) { outcome in
                                let latest = latestMeasure(for: outcome)
                                let startDate = startMeasuredAt(for: outcome, latestMeasure: latest)
                                Button(action: { navigationAction = .editOutcome(outcome) }) {
                                    OutcomeRow(
                                        outcome: outcome,
                                        measure: latest,
                                        startMeasure: startMeasure(for: outcome, latestMeasure: latest),
                                        startMeasuredAt: startDate
                                    )
                                }
                            }
                            Button(action: { navigationAction = .addOutcome }) {
                                Text("Add Goal")
                                    .font(.body)
                                    .foregroundColor(.blue)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 4)
                            }
                        }
                    }
                    .padding(.horizontal)

                    if !sortedCompletedOutcomes.isEmpty {
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
                        .padding(.horizontal)
                    }

                    if enableProjectsFeature {
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
                }
                .padding(.bottom, 20)
            }
        }
        .navigationTitle("Goals")
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
            if autoOpenAddOutcome && !hasAutoOpenedAddOutcome {
                hasAutoOpenedAddOutcome = true
                DispatchQueue.main.async {
                    navigationAction = .addOutcome
                }
            }
        }
    }

    private func hideKeyboard() {
        UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
    }

    private func categoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.color(for: category)
    }

    private func categoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.color(forKey: key)
        }
        return FulfillmentCategoryTheme.color(for: archive.category)
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: category)
    }

    private func lightenedCategoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.lightColor(forKey: key)
        }
        return FulfillmentCategoryTheme.lightColor(for: archive.category)
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
        let snapshot = outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
        let latestEntry = outcomeMeasureEntries
            .filter { $0.outcome_id == outcome.outcome_id }
            .max(by: { $0.measuredAt < $1.measuredAt })

        guard snapshot != nil || latestEntry != nil else { return nil }

        return OutcomesMeasure(
            outcome_id: outcome.outcome_id,
            measure: latestEntry?.measure ?? snapshot?.measure ?? 0,
            measuredAt: latestEntry?.measuredAt ?? snapshot?.measuredAt ?? .now,
            measure_amt: snapshot?.measure_amt ?? latestEntry?.measure_amt ?? 0,
            measure_updated: snapshot?.measure_updated ?? .now,
            direction: nil,
            format: snapshot?.format ?? latestEntry?.format,
            unit: snapshot?.unit ?? latestEntry?.unit,
            decimalPlaces: snapshot?.decimalPlaces ?? latestEntry?.decimalPlaces
        )
    }

    private func startMeasure(for outcome: Outcomes, latestMeasure: OutcomesMeasure?) -> Double? {
        if let entryID = OutcomeStartingValueStore.entryID(for: outcome.outcome_id),
           let storedEntry = outcomeMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id && $0.id == entryID }) {
            return storedEntry.measure
        }
        return outcomeMeasureEntries
            .filter { $0.outcome_id == outcome.outcome_id }
            .min(by: { $0.measuredAt < $1.measuredAt })?
            .measure
    }

    private func startMeasuredAt(for outcome: Outcomes, latestMeasure: OutcomesMeasure?) -> Date? {
        if let entryID = OutcomeStartingValueStore.entryID(for: outcome.outcome_id),
           let storedEntry = outcomeMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id && $0.id == entryID }) {
            return storedEntry.measuredAt
        }
        return outcomeMeasureEntries
            .filter { $0.outcome_id == outcome.outcome_id }
            .min(by: { $0.measuredAt < $1.measuredAt })?
            .measuredAt
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
    let startMeasuredAt: Date?

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                let isUpcoming = Calendar.current.startOfDay(for: outcome.start) > Calendar.current.startOfDay(for: .now)
                if isUpcoming {
                    let daysToStart = daysUntilStart(outcome.start)
                    HStack(spacing: 8) {
                        Image(systemName: "clock")
                            .foregroundColor(.gray)
                            .font(.caption)
                        Text("starts in \(daysToStart) day\(daysToStart == 1 ? "" : "s") on \(formattedDate(outcome.start))")
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
                        let isStarting = startMeasuredAt.map {
                            Calendar.current.isDate($0, inSameDayAs: measure.measuredAt)
                        } ?? false
                        MeasurableOutcomeBox(
                            measure: measure.measure,
                            measuredAt: measure.measuredAt,
                            measureAmt: measure.measure_amt,
                            endDate: outcome.end,
                            format: measure.format ?? "Number",
                            statusPrefix: isStarting ? "started" : "updated"
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
        FulfillmentCategoryTheme.color(for: category)
    }

    private func categoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.color(forKey: key)
        }
        return FulfillmentCategoryTheme.color(for: archive.category)
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: category)
    }

    private func lightenedCategoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.lightColor(forKey: key)
        }
        return FulfillmentCategoryTheme.lightColor(for: archive.category)
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

    private func daysUntilStart(_ date: Date) -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let start = calendar.startOfDay(for: date)
        return max(1, calendar.dateComponents([.day], from: today, to: start).day ?? 1)
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
    @Environment(\.colorScheme) private var colorScheme
    let archive: CompletedOutcomeArchive
    var showsChevron: Bool = true
    var showDates: Bool = true

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                if showDates {
                    HStack {
                        Spacer()
                        Text("\(formattedDate(archive.start)) - \(formattedDate(archive.completedAt))")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(.secondary)
                    }
                }
                Text(archive.outcome)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .foregroundColor(categoryColor(for: archive))
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
                            .fill(lightenedCategoryColor(for: archive))
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
                                .foregroundColor(colorScheme == .dark ? .white : .black)
                        }
                        .padding(.vertical, 6)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemGray5))
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
                                .fill(colorScheme == .dark ? Color(.tertiarySystemBackground) : Color(.systemGray5))
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
        FulfillmentCategoryTheme.color(for: category)
    }

    private func categoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.color(forKey: key)
        }
        return FulfillmentCategoryTheme.color(for: archive.category)
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.lightColor(for: category)
    }

    private func lightenedCategoryColor(for archive: CompletedOutcomeArchive) -> Color {
        if let key = FulfillmentCategoryTheme.completedOutcomeColorKey(archiveId: archive.id) {
            return FulfillmentCategoryTheme.lightColor(forKey: key)
        }
        return FulfillmentCategoryTheme.lightColor(for: archive.category)
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
    @Query(sort: \OutcomeAnalyticsEvent.occurredAt, order: .reverse) private var allOutcomeEvents: [OutcomeAnalyticsEvent]
    @Query(sort: \Passion.date, order: .forward) private var allPassions: [Passion]
    @Query(sort: \CompletedOutcomePassionLinkArchive.createdAt, order: .forward) private var completedOutcomePassionLinks: [CompletedOutcomePassionLinkArchive]
    @State private var isShowingDeleteAlert = false
    @State private var insightDetailSheet: InsightDetailSheetType? = nil

    private enum InsightDetailSheetType: String, Identifiable {
        case goalChanges
        case targetPushes
        var id: String { rawValue }
    }
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

    private var outcomeEvents: [OutcomeAnalyticsEvent] {
        allOutcomeEvents.filter { $0.outcome_id == archive.originalOutcomeId }
    }

    private var goalChangeEvents: [OutcomeAnalyticsEvent] {
        outcomeEvents.filter { $0.eventType == "goal_changed" }
    }

    private var targetPushEvents: [OutcomeAnalyticsEvent] {
        outcomeEvents.filter { $0.eventType == "target_changed" }
    }

    private var connectedPassionRows: [String] {
        let archivedLinks = completedOutcomePassionLinks.filter { $0.completedOutcomeArchiveId == archive.id }
        if !archivedLinks.isEmpty {
            return archivedLinks.map {
                "\(displayEmotionLabelObjectives($0.emotionSnapshot)): \($0.passionSnapshot)"
            }
        }

        let snapshots = CompletedOutcomePassionsDetailStore.snapshots(for: archive.id)
        let liveByID = Dictionary(uniqueKeysWithValues: allPassions.map { ($0.passion_id, $0) })
        return snapshots.map { snap in
            if let live = liveByID[snap.passionID] {
                return "\(displayEmotionLabelObjectives(live.emotion)): \(live.passion)"
            }
            return "\(displayEmotionLabelObjectives(snap.emotion)): \(snap.passion)"
        }
    }

    private var contributingLittleWinSnapshots: [CompletedOutcomeContributingLittleWinsStore.Snapshot] {
        CompletedOutcomeContributingLittleWinsStore.snapshots(for: archive.id)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    CompletedOutcomeRow(archive: archive, showsChevron: false, showDates: false)
                }

                if archive.isMeasurable {
                    Section {
                        CompletedOutcomeArchiveChart(
                            rows: measures,
                            startDate: archive.start,
                            endDate: archive.end,
                            formatRaw: archive.format ?? ObjectivesAddView.MeasureFormat.number.rawValue
                        )
                    }
                }

                if archive.isMeasurable {
                    Section {
                        NavigationLink {
                            CompletedOutcomeAllDataView(
                                archiveID: archive.id,
                                formatRaw: archive.format ?? ObjectivesAddView.MeasureFormat.number.rawValue
                            )
                        } label: {
                            Text("Show All Data")
                        }
                    }
                }

                Section("Contributing Little Wins") {
                    if contributingLittleWinSnapshots.isEmpty {
                        Text("No contributing little wins connected.")
                            .foregroundStyle(.secondary)
                    } else {
                        ForEach(contributingLittleWinSnapshots) { snap in
                            HStack(alignment: .top, spacing: 10) {
                                Text(snap.focusTitle)
                                    .font(.body)
                                Spacer()
                                Text(completedLittleWinSummaryText(for: snap))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.trailing)
                            }
                            .padding(.vertical, 2)
                        }
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

                Section("Goal") {
                    Text(archive.outcome)
                        .font(.body)
                }

                Section("Reasons") {
                    Text(archive.reasons)
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                Section("Start") {
                    HStack {
                        Text("Started")
                        Spacer()
                        Text(archive.start, format: .dateTime.month().day().year())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Target") {
                    HStack {
                        Text("Ended")
                        Spacer()
                        Text(archive.end, format: .dateTime.month().day().year())
                            .foregroundStyle(.secondary)
                    }
                }

                Section("Category of Improvement") {
                    Text(archive.category)
                        .font(.body)
                }

                Section("Insights") {
                    if archive.isMeasurable {
                        insightRow("Data entered", "\(archive.dataEntryCount)")
                        insightDetailRow(
                            title: "Goal changes",
                            value: "\(archive.goalPushCount)",
                            isEnabled: archive.goalPushCount > 0
                        ) {
                            insightDetailSheet = .goalChanges
                        }
                        insightDetailRow(
                            title: "Target date pushes",
                            value: "\(archive.targetChangeCount)",
                            isEnabled: archive.targetChangeCount > 0
                        ) {
                            insightDetailSheet = .targetPushes
                        }
                    } else {
                        insightRow("Target date pushes", "\(archive.targetChangeCount)")
                    }
                    if !contributionByDay.isEmpty {
                        Chart(contributionByDay, id: \.0) { row in
                            BarMark(
                                x: .value("Date", row.0),
                                y: .value("Count", row.1)
                            )
                            .foregroundStyle(Color.accentColor.gradient)
                        }
                        .frame(height: 160)
                    }
                }

                Section("Journal") {
                    journalBox(title: "", text: combinedJournalText(for: archive))
                }

                Section("Passions") {
                    if connectedPassionRows.isEmpty {
                        Text("No passions connected.")
                            .foregroundStyle(.secondary)
                    } else {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(Array(connectedPassionRows.enumerated()), id: \.offset) { _, row in
                                Text(row)
                                    .font(.subheadline)
                                    .padding(.vertical, 8)
                                    .padding(.horizontal, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                            }
                        }
                        .padding(.vertical, 2)
                    }
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
                Text("Are you sure you want to delete this outcome? It will be available for 30 days in Account Manager.")
            }
            .sheet(item: $insightDetailSheet) { sheet in
                switch sheet {
                case .goalChanges:
                    CompletedOutcomeInsightDetailSheet(
                        title: "Goal changes",
                        rows: goalChangeRows
                    )
                case .targetPushes:
                    CompletedOutcomeInsightDetailSheet(
                        title: "Target date pushes",
                        rows: targetPushRows
                    )
                }
            }
        }
    }

    private func insightRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value).fontWeight(.semibold)
        }
    }

    private func insightDetailRow(
        title: String,
        value: String,
        isEnabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            if isEnabled { action() }
        } label: {
            HStack {
                Text(title)
                    .foregroundStyle(.primary)
                Spacer()
                Text(value)
                    .fontWeight(.semibold)
                    .foregroundStyle(.primary)
                if isEnabled {
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!isEnabled)
    }

    private var goalChangeRows: [String] {
        if goalChangeEvents.isEmpty {
            return ["No detailed goal-change history is available for this outcome."]
        }
        return goalChangeEvents.compactMap { event in
            guard let oldGoal = event.oldGoal, let newGoal = event.newGoal else { return nil }
            return "\(shortDate(event.occurredAt)): goal changes \(compactNumber(oldGoal)) to \(compactNumber(newGoal))"
        }
    }

    private var targetPushRows: [String] {
        if targetPushEvents.isEmpty {
            return ["No detailed target-date history is available for this outcome."]
        }
        return targetPushEvents.compactMap { event in
            guard let oldDate = event.oldTargetDate, let newDate = event.newTargetDate else { return nil }
            return "\(shortDate(event.occurredAt)): \(shortDate(oldDate)) to \(shortDate(newDate))"
        }
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "MM/dd/yyyy"
        return formatter.string(from: date)
    }

    private func compactNumber(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        return formatter.string(from: NSNumber(value: value)) ?? "\(value)"
    }

    private func combinedJournalText(for archive: CompletedOutcomeArchive) -> String {
        let wins = archive.journalWins.trimmingCharacters(in: .whitespacesAndNewlines)
        let learned = archive.journalLearned.trimmingCharacters(in: .whitespacesAndNewlines)
        let next = archive.journalNext.trimmingCharacters(in: .whitespacesAndNewlines)

        // New records store the unified journal in journalWins and leave others blank.
        if !wins.isEmpty && learned.isEmpty && next.isEmpty {
            return wins
        }

        // Migration display for older records that used 3 fields.
        var lines: [String] = []
        if !wins.isEmpty { lines.append("Wins: \(wins)") }
        if !learned.isEmpty { lines.append("Learned: \(learned)") }
        if !next.isEmpty { lines.append("Next: \(next)") }
        return lines.isEmpty ? "—" : lines.joined(separator: "\n\n")
    }

    private func completedLittleWinSummaryText(for snapshot: CompletedOutcomeContributingLittleWinsStore.Snapshot) -> String {
        let count = snapshot.completedCountInOutcomeWindow
        let countText = "\(count) \(count == 1 ? "completed" : "completed")"
        return "\(countText) from \(compactMonthDay(archive.start)) to \(compactMonthDay(archive.completedAt))"
    }

    private func compactMonthDay(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d"
        return formatter.string(from: date)
    }

    private func journalBox(title: String, text: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            if !title.isEmpty {
                Text(title)
                    .font(.subheadline.weight(.semibold))
            }
            Text(text)
                .font(.body)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 2)
    }

}

private struct CompletedOutcomeInsightDetailSheet: View {
    let title: String
    let rows: [String]

    var body: some View {
        NavigationStack {
            List {
                ForEach(rows, id: \.self) { row in
                    Text(row)
                        .font(.body)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

struct CompletedOutcomeAllDataView: View {
    let archiveID: UUID
    let formatRaw: String
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \CompletedOutcomeMeasurePointArchive.measuredAt, order: .reverse) private var points: [CompletedOutcomeMeasurePointArchive]

    private var sortedRows: [CompletedOutcomeMeasurePointArchive] {
        points
            .filter { $0.completedOutcomeArchiveId == archiveID }
            .sorted { $0.measuredAt < $1.measuredAt }
    }

    private var startRow: CompletedOutcomeMeasurePointArchive? {
        sortedRows.first
    }

    private var hasGoalUpdates: Bool {
        Set(sortedRows.map(\.goal)).count > 1
    }

    private var originalGoal: Double {
        startRow?.goal ?? 0
    }

    private var currentGoal: Double {
        sortedRows.last?.goal ?? originalGoal
    }

    private var nonStartingRows: [CompletedOutcomeMeasurePointArchive] {
        guard let start = startRow else { return [] }
        return sortedRows.filter { !Calendar.current.isDate($0.measuredAt, inSameDayAs: start.measuredAt) }
    }

    private var unselectedPointFillColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
    }

    private var goalChangeRows: [CompletedGoalChangeRecord] {
        guard sortedRows.count > 1 else { return [] }
        var result: [CompletedGoalChangeRecord] = []
        for idx in 1..<sortedRows.count {
            let previous = sortedRows[idx - 1]
            let current = sortedRows[idx]
            if previous.goal != current.goal {
                result.append(
                    CompletedGoalChangeRecord(
                        id: current.id,
                        date: current.measuredAt,
                        oldGoal: previous.goal,
                        newGoal: current.goal,
                        startMeasure: startRow?.measure
                    )
                )
            }
        }
        return result
    }

    private var recordedRows: [CompletedRecordedRow] {
        var rows: [CompletedRecordedRow] = nonStartingRows.map {
            CompletedRecordedRow(id: "measure-\($0.id.uuidString)", date: $0.measuredAt, kind: .measure($0))
        }
        rows.append(contentsOf: goalChangeRows.map {
            CompletedRecordedRow(id: "goal-\($0.id.uuidString)", date: $0.date, kind: .goalChange($0))
        })
        rows.sort { $0.date > $1.date }
        return rows
    }

    var body: some View {
        List {
            ForEach(recordedRows) { row in
                NavigationLink {
                    CompletedRecordedDataDetailsView(row: row, formatRaw: formatRaw)
                } label: {
                    completedRecordedRowLabel(row)
                }
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            Section {
                HStack(spacing: 10) {
                    Text(hasGoalUpdates ? "Original Goal" : "Goal")
                        .font(.body)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatted(hasGoalUpdates ? originalGoal : currentGoal, format: formatRaw))
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 1)
                .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
            }

            if let startRow {
                Section {
                    HStack(spacing: 10) {
                        Text("Starting Value")
                            .font(.body)
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(formatted(startRow.measure, format: formatRaw))
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 1)
                    .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
            }
        }
        .navigationTitle("All Recorded Data")
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private func completedRecordedRowLabel(_ row: CompletedRecordedRow) -> some View {
        switch row.kind {
        case .measure(let measureRow):
            HStack(spacing: 10) {
                Image("logo_appicon_any")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 9, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .stroke(Color.gray.opacity(0.45), lineWidth: 0.6)
                    )
                Text(formatted(measureRow.measure, format: formatRaw))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(compactDate(measureRow.measuredAt))
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 1)
        case .goalChange(let row):
            HStack(spacing: 10) {
                ZStack {
                    Color.clear
                    Image(systemName: "scope")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)
                }
                .frame(width: 34, height: 34)
                Text(formatted(row.newGoal, format: formatRaw))
                    .font(.body)
                    .foregroundStyle(.primary)
                Spacer()
                Text(compactDate(row.date))
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
        formatter.dateFormat = year == nowYear ? "MMM d" : "MMM d, yyyy"
        return formatter.string(from: date)
    }

    private func formatted(_ value: Double, format: String) -> String {
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
}

private struct CompletedGoalChangeRecord: Identifiable {
    let id: UUID
    let date: Date
    let oldGoal: Double
    let newGoal: Double
    let startMeasure: Double?
}

private struct CompletedRecordedRow: Identifiable {
    enum Kind {
        case measure(CompletedOutcomeMeasurePointArchive)
        case goalChange(CompletedGoalChangeRecord)
    }
    let id: String
    let date: Date
    let kind: Kind
}

private struct CompletedRecordedDataDetailsView: View {
    let row: CompletedRecordedRow
    let formatRaw: String

    var body: some View {
        Form {
            switch row.kind {
            case .measure(let measureRow):
                detailRow("Value", formatted(measureRow.measure))
                detailRow("Date", fullDate(measureRow.measuredAt))
                detailRow("Source", "Loom")
                detailRow("Was User Entered", "Yes")
            case .goalChange(let change):
                let diff = change.newGoal - change.oldGoal
                detailRow("New Goal", formatted(change.newGoal))
                detailRow("Old Goal", formatted(change.oldGoal))
                HStack {
                    Text("Difference")
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(formatted(diff))
                        .foregroundStyle(differenceColor(oldGoal: change.oldGoal, newGoal: change.newGoal, startMeasure: change.startMeasure))
                }
                detailRow("Date", fullDate(change.date))
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

    private func differenceColor(oldGoal: Double, newGoal: Double, startMeasure: Double?) -> Color {
        guard let start = startMeasure, oldGoal != start else {
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
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let base = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return "$\(base)"
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return "\(base)%"
        default:
            return base
        }
    }
}

private struct CompletedOutcomeArchiveChart: View {
    let rows: [CompletedOutcomeMeasurePointArchive]
    let startDate: Date
    let endDate: Date
    let formatRaw: String

    @Environment(\.colorScheme) private var colorScheme
    @State private var selectedTimeRange: String = "All"
    @State private var selectedEntryID: UUID? = nil
    @State private var selectedDate: Date? = nil
    @State private var showSuccessPaths: Bool = false
    private let allTimeRanges = ["All", "W", "M", "3M", "6M", "Y"]

    private var sortedRows: [CompletedOutcomeMeasurePointArchive] {
        rows.sorted { $0.measuredAt < $1.measuredAt }
    }

    private var availableTimeRanges: [String] {
        let days = max(1, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: startDate), to: Calendar.current.startOfDay(for: endDate)).day ?? 1)
        let maxIndex: Int
        if days <= 7 { maxIndex = 1 }
        else if days <= 30 { maxIndex = 2 }
        else if days <= 90 { maxIndex = 3 }
        else if days <= 180 { maxIndex = 4 }
        else { maxIndex = 5 }
        return Array(allTimeRanges.prefix(maxIndex + 1))
    }

    private var selectedEntry: CompletedOutcomeMeasurePointArchive? {
        if let selectedDate, let nearest = nearestEntry(to: selectedDate) {
            return nearest
        }
        if let selectedEntryID {
            return sortedRows.first(where: { $0.id == selectedEntryID })
        }
        return sortedRows.last
    }

    private var startValue: Double? { sortedRows.first?.measure }
    private var latestValue: Double? { sortedRows.last?.measure }
    private var latestDate: Date? { sortedRows.last.map { Calendar.current.startOfDay(for: $0.measuredAt) } }
    private var goalValue: Double? { sortedRows.last?.goal }
    private var unselectedPointFillColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground)
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

                RuleMark(x: .value("Start Date", Calendar.current.startOfDay(for: startDate)))
                    .foregroundStyle(.green)
                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))

                RuleMark(x: .value("End Date", Calendar.current.startOfDay(for: endDate)))
                    .foregroundStyle(.red)
                    .lineStyle(.init(lineWidth: 2, dash: [5, 5]))

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
                            let startPoint = chartPoint(proxy: proxy, plot: plot, date: Calendar.current.startOfDay(for: startDate), value: startValue),
                            let goalPoint = chartPoint(proxy: proxy, plot: plot, date: Calendar.current.startOfDay(for: endDate), value: goalValue),
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
                selectedEntryID = sortedRows.last?.id
            }
            .frame(height: 260)

            Toggle("Show Success Path", isOn: $showSuccessPaths)
                .font(.subheadline)
                .tint(.blue)
                .padding(.top, 2)
        }
    }

    private var isBehindGoalPath: Bool? {
        guard
            let start = startValue,
            let goal = goalValue,
            let latest = latestValue,
            let currentDate = latestDate
        else { return nil }

        let startDay = Calendar.current.startOfDay(for: startDate)
        let endDay = Calendar.current.startOfDay(for: endDate)
        if endDay <= startDay { return nil }

        let total = endDay.timeIntervalSince(startDay)
        let elapsed = min(max(0, currentDate.timeIntervalSince(startDay)), total)
        let progress = elapsed / total
        let expected = start + (goal - start) * progress
        let directionUp = goal >= start
        return directionUp ? (latest < expected) : (latest > expected)
    }

    private var visibleRows: [CompletedOutcomeMeasurePointArchive] {
        let range = fullDateRange()
        return sortedRows.filter {
            let day = Calendar.current.startOfDay(for: $0.measuredAt)
            return range.contains(day)
        }
    }

    private var latestLoggedDate: Date {
        Calendar.current.startOfDay(for: (sortedRows.last?.measuredAt ?? .now))
    }

    private var initialScrollX: Date {
        let halfWindow = visibleDomainLength() / 2
        let proposed = latestLoggedDate.addingTimeInterval(-halfWindow)
        let range = fullDateRange()
        if proposed < range.lowerBound { return range.lowerBound }
        if proposed > range.upperBound { return range.upperBound }
        return proposed
    }

    private func nearestEntry(to date: Date) -> CompletedOutcomeMeasurePointArchive? {
        guard !sortedRows.isEmpty else { return nil }
        let target = Calendar.current.startOfDay(for: date)
        return sortedRows.min(by: {
            abs($0.measuredAt.timeIntervalSince(target)) < abs($1.measuredAt.timeIntervalSince(target))
        })
    }

    private func formatMeasure(_ value: Double) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.maximumFractionDigits = 2
        formatter.minimumFractionDigits = 0
        let base = formatter.string(from: NSNumber(value: value)) ?? "\(value)"
        switch formatRaw {
        case ObjectivesAddView.MeasureFormat.dollars.rawValue:
            return "$\(base)"
        case ObjectivesAddView.MeasureFormat.percentage.rawValue:
            return "\(base)%"
        default:
            return base
        }
    }

    private func fullDateRange() -> ClosedRange<Date> {
        let calendar = Calendar.current
        let allDatesFromEntries = sortedRows.map { calendar.startOfDay(for: $0.measuredAt) }
        let allDates = allDatesFromEntries + [calendar.startOfDay(for: startDate), calendar.startOfDay(for: endDate)]
        let minDate = allDates.min() ?? calendar.startOfDay(for: .now)
        let maxDate = allDates.max() ?? calendar.startOfDay(for: .now)
        let paddedStart = calendar.date(byAdding: .day, value: -30, to: minDate) ?? minDate
        let paddedEnd = calendar.date(byAdding: .day, value: 30, to: maxDate) ?? maxDate
        return paddedStart...paddedEnd
    }

    private func yAxisRange() -> ClosedRange<Double> {
        var values: [Double] = visibleRows.flatMap { [$0.measure, $0.goal] }
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
                let full = formatter.string(from: date)
                return full.isEmpty ? "" : String(full.prefix(1))
            } else {
                formatter.dateFormat = "MMM"
                return formatter.string(from: date)
            }
        }
    }


    private func visibleDomainLength() -> TimeInterval {
        let day: TimeInterval = 86_400
        switch selectedTimeRange {
        case "W": return day * 7
        case "M": return day * 30
        case "3M": return day * 90
        case "6M": return day * 180
        case "Y": return day * 365
        default:
            let full = fullDateRange()
            return max(day * 30, full.upperBound.timeIntervalSince(full.lowerBound))
        }
    }

    private func chartPoint(
        proxy: ChartProxy,
        plot: CGRect,
        date: Date?,
        value: Double?
    ) -> CGPoint? {
        guard let date, let value else { return nil }
        let xDate = Calendar.current.startOfDay(for: date)
        guard
            let x = proxy.position(forX: xDate),
            let y = proxy.position(forY: value)
        else { return nil }
        return CGPoint(x: plot.minX + x, y: plot.minY + y)
    }
}

struct MeasurableOutcomeBox: View {
    @Environment(\.colorScheme) private var colorScheme

    let measure: Double
    let measuredAt: Date
    let measureAmt: Double
    let endDate: Date
    let format: String
    let statusPrefix: String

    init(
        measure: Double,
        measuredAt: Date,
        measureAmt: Double,
        endDate: Date,
        format: String,
        statusPrefix: String = "updated"
    ) {
        self.measure = measure
        self.measuredAt = measuredAt
        self.measureAmt = measureAmt
        self.endDate = endDate
        self.format = format
        self.statusPrefix = statusPrefix
    }

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
                Text("\(statusPrefix) \(formattedDate(measuredAt))")
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
