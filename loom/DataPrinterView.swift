import SwiftUI
import SwiftData

// MARK: - Flattened Display Model
struct DataItem: Identifiable, Hashable {
    let id: String
    let source: String
    let content: String
    let date: Date
    let emotion: String?
    let additionalFields: [String: String]

    static func flatten(
        forces: [DrivingForce],
        forceArch: [DrivingForceArchive],
        passions: [Passion],
        passionArch: [PassionArchive],
        fulfillments: [Fulfillment],
        fulfillmentArch: [FulfillmentArchive],
        fulfillmentRoles: [FulfillmentRoles],
        fulfillmentRolesArch: [FulfillmentRolesArchive],
        fulfillmentFocus: [FulfillmentFocus],
        fulfillmentFocusArch: [FulfillmentFocusArchive],
        fulfillmentResources: [FulfillmentResources],
        fulfillmentResourcesArch: [FulfillmentResourcesArchive],
        passionFulfillmentJoins: [PassionFulfillmentJoin],
        passionFulfillmentJoinArch: [PassionFulfillmentJoinArchive],
        outcomes: [Outcomes],
        outcomesArch: [OutcomesArchive],
        outcomesMeasures: [OutcomesMeasure],
        outcomesMeasuresArch: [OutcomesMeasureArchive]
    ) -> [DataItem] {
        var items: [DataItem] = []

        // DrivingForce
        for df in forces {
            let base = df.id.uuidString
            let ts = df.updatedAt

            items.append(.init(
                id: "vision-\(base)",
                source: "Ultimate Vision",
                content: df.ultimateVision,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": df.ultimatePurpose
                ]
            ))

            items.append(.init(
                id: "purpose-\(base)",
                source: "Ultimate Purpose",
                content: df.ultimatePurpose,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": df.ultimateVision
                ]
            ))
        }

        // DrivingForceArchive
        for arch in forceArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "visionArch-\(base)",
                source: "Ultimate Vision (Archived)",
                content: arch.visionSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": arch.purposeSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))

            items.append(.init(
                id: "purposeArch-\(base)",
                source: "Ultimate Purpose (Archived)",
                content: arch.purposeSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": arch.visionSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Passion
        for p in passions {
            let base = p.passion_id.uuidString
            items.append(.init(
                id: "passion-\(base)",
                source: "Passion",
                content: p.passion,
                date: p.date,
                emotion: p.emotion,
                additionalFields: [
                    "ID": base
                ]
            ))
        }

        // PassionArchive
        for arch in passionArch {
            let base = arch.id.uuidString
            items.append(.init(
                id: "passionArch-\(base)",
                source: "Passion (Archived)",
                content: arch.passionSnapshot,
                date: arch.archivedAt,
                emotion: arch.emotion,
                additionalFields: [
                    "ID": base,
                    "Updated At": arch.updatedAt.formatted(),
                    "Original Date": arch.date.formatted()
                ]
            ))
        }

        // Fulfillment
        for f in fulfillments {
            let base = f.category_id.uuidString
            let ts = f.updatedAt

            items.append(.init(
                id: "fulfillment-\(base)",
                source: "Fulfillment",
                content: f.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Identity": f.category_identitiy,
                    "Vision": f.category_vision,
                    "Purpose": f.category_purpose
                ]
            ))
        }

        // FulfillmentArchive
        for arch in fulfillmentArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "fulfillmentArch-\(base)",
                source: "Fulfillment (Archived)",
                content: arch.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Identity": arch.category_identitiy,
                    "Vision": arch.category_vision,
                    "Purpose": arch.category_purpose,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentRoles
        for role in fulfillmentRoles {
            let base = role.id.uuidString
            let ts = role.updatedAt

            items.append(.init(
                id: "role-\(base)",
                source: "Fulfillment Role",
                content: role.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": role.category_id.uuidString,
                    "Rank": "\(role.rank)"
                ]
            ))
        }

        // FulfillmentRolesArchive
        for arch in fulfillmentRolesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "roleArch-\(base)",
                source: "Fulfillment Role (Archived)",
                content: arch.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentFocus
        for focus in fulfillmentFocus {
            let base = focus.id.uuidString
            let ts = focus.updatedAt

            items.append(.init(
                id: "focus-\(base)",
                source: "Fulfillment Focus",
                content: focus.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": focus.category_id.uuidString,
                    "Rank": "\(focus.rank)"
                ]
            ))
        }

        // FulfillmentFocusArchive
        for arch in fulfillmentFocusArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "focusArch-\(base)",
                source: "Fulfillment Focus (Archived)",
                content: arch.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentResources
        for resource in fulfillmentResources {
            let base = resource.id.uuidString
            let ts = resource.updatedAt

            items.append(.init(
                id: "resource-\(base)",
                source: "Fulfillment Resource",
                content: resource.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": resource.category_id.uuidString,
                    "Rank": "\(resource.rank)"
                ]
            ))
        }

        // FulfillmentResourcesArchive
        for arch in fulfillmentResourcesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "resourceArch-\(base)",
                source: "Fulfillment Resource (Archived)",
                content: arch.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // PassionFulfillmentJoin
        for join in passionFulfillmentJoins {
            let base = join.id.uuidString
            let ts = Date()

            items.append(.init(
                id: "join-\(base)",
                source: "Passion-Fulfillment Join",
                content: "Passion: \(join.passion_id), Category: \(join.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": join.passion_id.uuidString,
                    "Category ID": join.category_id.uuidString
                ]
            ))
        }

        // PassionFulfillmentJoinArchive
        for arch in passionFulfillmentJoinArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "joinArch-\(base)",
                source: "Passion-Fulfillment Join (Archived)",
                content: "Passion: \(arch.passion_id), Category: \(arch.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": arch.passion_id.uuidString,
                    "Category ID": arch.category_id.uuidString,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Outcomes
        for outcome in outcomes {
            let base = outcome.outcome_id.uuidString
            let ts = outcome.updatedAt

            items.append(.init(
                id: "outcome-\(base)",
                source: "Outcome",
                content: outcome.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": outcome.category,
                    "Reasons": outcome.reasons,
                    "Duration": "\(daysBetween(outcome.start, outcome.end)) days",
                    "Start": outcome.start.formatted(),
                    "End": outcome.end.formatted(),
                    "Rank": "\(outcome.rank)",
                    "Format": outcome.format ?? ""
                ]
            ))
        }

        // OutcomesArchive
        for arch in outcomesArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "outcomeArch-\(base)",
                source: "Outcome (Archived)",
                content: arch.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": arch.category,
                    "Reasons": arch.reasons,
                    "Duration": "\(daysBetween(arch.start, arch.end)) days",
                    "Start": arch.start.formatted(),
                    "End": arch.end.formatted(),
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted(),
                    "Format": arch.format ?? ""
                ]
            ))
        }

        // OutcomesMeasure
        for measure in outcomesMeasures {
            let base = measure.outcome_id.uuidString
            let ts = measure.measuredAt

            items.append(.init(
                id: "measure-\(base)",
                source: "Outcome Measure",
                content: "\(measure.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(measure.measure_amt)",
                    "Measure Updated": measure.measure_updated.formatted(),
                    "Measured At": measure.measuredAt.formatted(),
                    "Direction": measure.direction ?? "",
                    "Format": measure.format ?? ""
                ]
            ))
        }

        // OutcomesMeasureArchive
        for arch in outcomesMeasuresArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "measureArch-\(base)",
                source: "Outcome Measure (Archived)",
                content: "\(arch.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(arch.measure_amt)",
                    "Measure Updated": arch.measure_updated.formatted(),
                    "Measured At": arch.measuredAt.formatted(),
                    "Updated At": arch.archivedAt.formatted(),
                    "Direction": arch.direction ?? "",
                    "Format": arch.format ?? ""
                ]
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
}

// MARK: - Filter Model
struct ModelFilter: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Main View
struct DataPrinterView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    @State private var selection = Set<String>()
    @State private var showingDeleteAlert = false
    @State private var showingFilterSheet = false
    @State private var selectedFilters = Set<String>()

    private let availableFilters: [ModelFilter] = [
        .init(id: "vision", name: "Ultimate Vision"),
        .init(id: "purpose", name: "Ultimate Purpose"),
        .init(id: "visionArch", name: "Ultimate Vision (Archived)"),
        .init(id: "purposeArch", name: "Ultimate Purpose (Archived)"),
        .init(id: "passion", name: "Passion"),
        .init(id: "passionArch", name: "Passion (Archived)"),
        .init(id: "fulfillment", name: "Fulfillment"),
        .init(id: "fulfillmentArch", name: "Fulfillment (Archived)"),
        .init(id: "role", name: "Fulfillment Role"),
        .init(id: "roleArch", name: "Fulfillment Role (Archived)"),
        .init(id: "focus", name: "Fulfillment Focus"),
        .init(id: "focusArch", name: "Fulfillment Focus (Archived)"),
        .init(id: "resource", name: "Fulfillment Resource"),
        .init(id: "resourceArch", name: "Fulfillment Resource (Archived)"),
        .init(id: "join", name: "Passion-Fulfillment Join"),
        .init(id: "joinArch", name: "Passion-Fulfillment Join (Archived)"),
        .init(id: "outcome", name: "Outcome"),
        .init(id: "outcomeArch", name: "Outcome (Archived)"),
        .init(id: "measure", name: "Outcome Measure"),
        .init(id: "measureArch", name: "Outcome Measure (Archived)")
    ]

    @Query(sort: \DrivingForce.updatedAt, order: .reverse)
    private var drivingForces: [DrivingForce]

    @Query(sort: \DrivingForceArchive.archivedAt, order: .reverse)
    private var drivingForceArchives: [DrivingForceArchive]

    @Query(sort: \Passion.date, order: .forward)
    private var passions: [Passion]

    @Query(sort: \PassionArchive.archivedAt, order: .forward)
    private var passionArchives: [PassionArchive]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @Query(sort: \FulfillmentArchive.archivedAt, order: .reverse)
    private var fulfillmentArchives: [FulfillmentArchive]

    @Query(sort: \FulfillmentRoles.updatedAt, order: .reverse)
    private var fulfillmentRoles: [FulfillmentRoles]

    @Query(sort: \FulfillmentRolesArchive.archivedAt, order: .reverse)
    private var fulfillmentRolesArchives: [FulfillmentRolesArchive]

    @Query(sort: \FulfillmentFocus.updatedAt, order: .reverse)
    private var fulfillmentFocus: [FulfillmentFocus]

    @Query(sort: \FulfillmentFocusArchive.archivedAt, order: .reverse)
    private var fulfillmentFocusArchives: [FulfillmentFocusArchive]

    @Query(sort: \FulfillmentResources.updatedAt, order: .reverse)
    private var fulfillmentResources: [FulfillmentResources]

    @Query(sort: \FulfillmentResourcesArchive.archivedAt, order: .reverse)
    private var fulfillmentResourcesArchives: [FulfillmentResourcesArchive]

    @Query(sort: \PassionFulfillmentJoin.id, order: .forward)
    private var passionFulfillmentJoins: [PassionFulfillmentJoin]

    @Query(sort: \PassionFulfillmentJoinArchive.archivedAt, order: .forward)
    private var passionFulfillmentJoinArchives: [PassionFulfillmentJoinArchive]

    @Query(sort: \Outcomes.updatedAt, order: .reverse)
    private var outcomes: [Outcomes]

    @Query(sort: \OutcomesArchive.archivedAt, order: .reverse)
    private var outcomesArchives: [OutcomesArchive]

    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse)
    private var outcomesMeasures: [OutcomesMeasure]

    @Query(sort: \OutcomesMeasureArchive.archivedAt, order: .reverse)
    private var outcomesMeasuresArchives: [OutcomesMeasureArchive]

    private var items: [DataItem] {
        let allItems = DataItem.flatten(
            forces: drivingForces,
            forceArch: drivingForceArchives,
            passions: passions,
            passionArch: passionArchives,
            fulfillments: fulfillments,
            fulfillmentArch: fulfillmentArchives,
            fulfillmentRoles: fulfillmentRoles,
            fulfillmentRolesArch: fulfillmentRolesArchives,
            fulfillmentFocus: fulfillmentFocus,
            fulfillmentFocusArch: fulfillmentFocusArchives,
            fulfillmentResources: fulfillmentResources,
            fulfillmentResourcesArch: fulfillmentResourcesArchives,
            passionFulfillmentJoins: passionFulfillmentJoins,
            passionFulfillmentJoinArch: passionFulfillmentJoinArchives,
            outcomes: outcomes,
            outcomesArch: outcomesArchives,
            outcomesMeasures: outcomesMeasures,
            outcomesMeasuresArch: outcomesMeasuresArchives
        )
        
        if selectedFilters.isEmpty {
            return allItems
        }
        
        return allItems.filter { item in
            guard let prefix = item.id.split(separator: "-").first else { return false }
            return selectedFilters.contains(String(prefix))
        }
    }

    var body: some View {
        List(items, selection: $selection) { item in
            NavigationLink {
                DataPrinterDetailView(item: item)
            } label: {
                DataPrinterRow(item)
            }
            .tag(item.id)
        }
        .listStyle(.plain)
        .tint(.red)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode?.wrappedValue == .active {
                    Button {
                        if selection.count == items.count {
                            selection.removeAll()
                        } else {
                            selection = Set(items.map { $0.id })
                        }
                    } label: {
                        Text(selection.count == items.count ? "Deselect All" : "Select All")
                    }

                    Spacer()

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Text("Delete (\(selection.count))")
                    }
                    .foregroundColor(.red)
                    .disabled(selection.isEmpty)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedFilters.isEmpty ? .gray : .blue)
                    }
                    
                    EditButton()
                }
            }
        }
        .navigationTitle("All Data")
        .alert("Permanently delete selected items?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performBulkDelete()
            }
        } message: {
            Text("This will remove the chosen records forever.")
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterView(
                availableFilters: availableFilters,
                selectedFilters: $selectedFilters
            )
        }
    }

    // MARK: - Bulk Delete Logic
    private func performBulkDelete() {
        for id in selection {
            guard let dash = id.firstIndex(of: "-") else { continue }
            let uuidString = String(id[id.index(after: dash)...])
            guard let uuid = UUID(uuidString: uuidString) else { continue }

            let prefix = String(id[..<dash])
            switch prefix {
            case "vision", "purpose":
                if let df = drivingForces.first(where: { $0.id == uuid }) {
                    context.delete(df)
                }
            case "visionArch", "purposeArch":
                if let arch = drivingForceArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "passion":
                if let p = passions.first(where: { $0.passion_id == uuid }) {
                    context.delete(p)
                }
            case "passionArch":
                if let arch = passionArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "fulfillment":
                if let f = fulfillments.first(where: { $0.category_id == uuid }) {
                    context.delete(f)
                }
            case "fulfillmentArch":
                if let arch = fulfillmentArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "role":
                if let role = fulfillmentRoles.first(where: { $0.id == uuid }) {
                    context.delete(role)
                }
            case "roleArch":
                if let arch = fulfillmentRolesArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "focus":
                if let focus = fulfillmentFocus.first(where: { $0.id == uuid }) {
                    context.delete(focus)
                }
            case "focusArch":
                if let arch = fulfillmentFocusArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "resource":
                if let resource = fulfillmentResources.first(where: { $0.id == uuid }) {
                    context.delete(resource)
                }
            case "resourceArch":
                if let arch = fulfillmentResourcesArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "join":
                if let join = passionFulfillmentJoins.first(where: { $0.id == uuid }) {
                    context.delete(join)
                }
            case "joinArch":
                if let arch = passionFulfillmentJoinArchives.first(where: { $0.id == uuid }) {
                    context.delete(arch)
                }
            case "outcome":
                if let outcome = outcomes.first(where: { $0.outcome_id == uuid }) {
                    context.delete(outcome)
                }
            case "outcomeArch":
                if let arch = outcomesArchives.first(where: { $0.outcome_id == uuid }) {
                    context.delete(arch)
                }
            case "measure":
                if let measure = outcomesMeasures.first(where: { $0.outcome_id == uuid }) {
                    context.delete(measure)
                }
            case "measureArch":
                if let arch = outcomesMeasuresArchives.first(where: { $0.outcome_id == uuid }) {
                    context.delete(arch)
                }
            default:
                break
            }
        }
        try? context.save()
        selection.removeAll()
    }
}

// MARK: - Filter View
struct FilterView: View {
    let availableFilters: [ModelFilter]
    @Binding var selectedFilters: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(availableFilters) { filter in
                HStack {
                    Text(filter.name)
                    Spacer()
                    if selectedFilters.contains(filter.id) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFilters.contains(filter.id) {
                        selectedFilters.remove(filter.id)
                    } else {
                        selectedFilters.insert(filter.id)
                    }
                }
            }
            .navigationTitle("Filter Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(selectedFilters.count == availableFilters.count ? "Deselect All" : "Select All") {
                        if selectedFilters.count == availableFilters.count {
                            selectedFilters.removeAll()
                        } else {
                            selectedFilters = Set(availableFilters.map { $0.id })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row View Helper
@ViewBuilder
private func DataPrinterRow(_ item: DataItem) -> some View {
    let dateText = item.date.formatted(
        .dateTime
        .month(.abbreviated)
        .day()
        .year()
        .hour(.twoDigits(amPM: .abbreviated))
        .minute()
    )

    VStack(alignment: .leading, spacing: 8) {
        Text(item.source)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)

        if let emo = item.emotion {
            Text(emo.capitalized)
                .font(.subheadline)
                .fontWeight(.bold)
        }

        Text(item.content)
            .font(.body)

        Text(dateText)
            .font(.caption2)
            .foregroundColor(.gray)
    }
    .padding(.vertical, 4)
}

// MARK: - Detail View
struct DataPrinterDetailView: View {
    let item: DataItem

    var body: some View {
        Form {
            Section("Model") {
                Text(item.source)
            }
            Section("Content") {
                if let emo = item.emotion {
                    HStack {
                        Text("Emotion:")
                        Spacer()
                        Text(emo.capitalized)
                    }
                }
                HStack {
                    Text("Text:")
                    Spacer()
                    Text(item.content)
                        .multilineTextAlignment(.trailing)
                }
                ForEach(item.additionalFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text("\(key):")
                        Spacer()
                        Text(value)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section("Timestamp") {
                Text(item.date.formatted(
                    .dateTime
                    .month(.wide)
                    .day()
                    .year()
                    .hour()
                    .minute()
                    .second()
                ))
            }
        }
        .navigationTitle("Details")
    }
}
