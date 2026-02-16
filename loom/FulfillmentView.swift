import SwiftUI
import SwiftData
import Charts
#if canImport(UIKit)
import UIKit
#endif

fileprivate struct CategoryDef: Identifiable {
    let id: String
    let title: String
    let iconName: String
}

fileprivate let categories: [CategoryDef] = [
    .init(id: "career",     title: "Career & Business",    iconName: "battery.25"),
    .init(id: "leadership", title: "Leadership & Impact",  iconName: "battery.25"),
    .init(id: "wealth",     title: "Wealth & Lifestyle",   iconName: "battery.25"),
    .init(id: "mind",       title: "Mind & Meaning",       iconName: "battery.25"),
    .init(id: "love",       title: "Love & Relationships", iconName: "battery.25"),
    .init(id: "health",     title: "Health & Vitality",    iconName: "battery.25"),
]

fileprivate func estimatedListRowHeight() -> CGFloat {
    #if canImport(UIKit)
    return UIFont.preferredFont(forTextStyle: .body).lineHeight + 30
    #else
    return 56
    #endif
}

struct PassionsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    let record: Fulfillment
    @State private var isSelectingPassion = false
    
    private var categoryPassions: [Passion] {
        let categoryPassionIDs = passionJoins
            .filter { $0.category_id == record.category_id }
            .map { $0.passion_id }
        return passions.filter { categoryPassionIDs.contains($0.passion_id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .foregroundColor(.black)
                Text("Passions")
                    .font(.headline)
                    .foregroundColor(.black)
            }
            
            List {
                ForEach(categoryPassions, id: \.passion_id) { passion in
                    Text("\(passion.emotion.capitalized): \(passion.passion)")
                }
                
                HStack {
                    Button(isSelectingPassion ? "Done" : "Connect Passion") {
                        withAnimation { isSelectingPassion.toggle() }
                    }
                    .foregroundColor(.blue)
                    Spacer()
                }
                .padding(.vertical, 4)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            }
            .listStyle(.plain)
            .scrollDisabled(true)
            .environment(\.editMode, .constant(.active))
            .frame(height: CGFloat(categoryPassions.count + 1) * estimatedListRowHeight())
            
            if isSelectingPassion {
                List {
                    ForEach(passions, id: \.passion_id) { passion in
                        Button(action: {
                            togglePassion(passion)
                        }) {
                            HStack {
                                Text("\(passion.emotion.capitalized): \(passion.passion)")
                                Spacer()
                                if categoryPassions.contains(where: { $0.passion_id == passion.passion_id }) {
                                    Image(systemName: "checkmark")
                                        .foregroundColor(.blue)
                                }
                            }
                        }
                        .foregroundColor(.primary)
                    }
                }
                .listStyle(.plain)
                .scrollDisabled(true)
                .frame(height: CGFloat(passions.count) * estimatedListRowHeight())
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.gray.opacity(0.4))
                )
            }
        }
    }
    
    private func togglePassion(_ passion: Passion) {
        let existingJoin = passionJoins.first {
            $0.passion_id == passion.passion_id && $0.category_id == record.category_id
        }
        
        if let join = existingJoin {
            RecentlyDeletedStore.trash(join, in: modelContext)
        } else {
            let join = PassionFulfillmentJoin(
                passion_id: passion.passion_id,
                category_id: record.category_id
            )
            modelContext.insert(join)
        }
    }
}

struct FulfillmentView: View {
    @Environment(\.modelContext) private var modelContext

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query private var passions: [Passion]

    @State private var expandedCardID: String? = nil
    @State private var isAddingRole = false
    @State private var newRoleText = ""
    @State private var isAddingFocus = false
    @State private var newFocusText = ""
    @State private var isAddingResource = false
    @State private var newResourceText = ""
    @State private var isShowingInstructions = false
    @State private var highlightedCategoryIndex: Int = 0
    @State private var radarAutoRotatePausedUntil: Date = .distantPast
    @FocusState private var focusedField: Field?
    private enum Field { case vision, purpose, role, focus, resource }
    private let radarTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    var body: some View {
        ScrollView {
            ZStack {
                if isAddingRole || isAddingFocus || isAddingResource {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            commitInlineIfNeeded()
                            focusedField = nil
                        }
                }

                VStack(spacing: 0) {
                    fulfillmentRadarHeader
                        .padding(.horizontal)
                        .padding(.top)
                        .background(Color(.systemGray6))

                    VStack(spacing: 16) {
                        ForEach(categories) { cat in
                            card(
                                id: cat.id,
                                title: cat.title,
                                iconName: batteryIconName(for: cat.title),
                                color: FulfillmentCategoryTheme.color(for: cat.title),
                                lightColor: FulfillmentCategoryTheme.lightColor(for: cat.title)
                            )
                        }
                        Spacer()
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Fulfillment")
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingInstructions = true
                } label: {
                    Image(systemName: "graduationcap")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .purpose {
                    Spacer(minLength: 0)
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .onChange(of: focusedField) { _, new in
            commitInlineExcluding(new)
        }
        .task {
            ensureCategoryRecordsExist()
        }
        .onReceive(radarTimer) { _ in
            guard !categories.isEmpty else { return }
            guard Date() >= radarAutoRotatePausedUntil else { return }
            highlightedCategoryIndex = (highlightedCategoryIndex + 1) % categories.count
        }
        .sheet(isPresented: $isShowingInstructions) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions")
                    .font(.headline)
                Text("Placeholder instructions text for Fulfillment.")
                    .font(.body)
                Spacer(minLength: 0)
            }
            .padding()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private var fulfillmentRadarHeader: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let baseGraphWidth = max(120, width * 0.40)
            let graphWidth = baseGraphWidth * 1.2
            let leftWidth = max(120, width - baseGraphWidth - 28)
            let selected = categories[highlightedCategoryIndex]
            let selectedScore = radarScore(for: selected.title)

            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                        Text(selected.title)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(FulfillmentCategoryTheme.color(for: selected.title))
                            .lineLimit(2)
                    Text("Tap radar slice to focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(FulfillmentCategoryTheme.color(for: selected.title))
                        .frame(width: 92, height: 58)
                        .overlay {
                            Text("\(selectedScore)/5")
                                .font(.system(size: 26, weight: .bold))
                                .foregroundStyle(.white)
                        }

                    VStack(alignment: .leading, spacing: 3) {
                        Text("analyzed:")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.gray)
                        Text("• Outcome progress")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• Action block completion")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• Three-to-Thrive consistency")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• Category engagement")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("• Momentum")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 4)

                    NavigationLink {
                        FulfillmentTrendsView()
                    } label: {
                        Text("Show trends")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: leftWidth, alignment: .leading)

                FulfillmentInteractiveRadar(
                    metrics: fulfillmentMetrics,
                    selectedIndex: $highlightedCategoryIndex,
                    onManualSelect: {
                        radarAutoRotatePausedUntil = Date().addingTimeInterval(20)
                    }
                )
                .frame(width: graphWidth, height: graphWidth)
                .frame(width: baseGraphWidth, height: 245, alignment: .center)

                Spacer(minLength: 0)
            }
        }
        .frame(height: 245)
        .padding(.bottom, 8)
    }

    private func commitInlineIfNeeded() {
        guard let openID = expandedCardID,
              let cat = categories.first(where: { $0.id == openID }),
              let record = fulfillmentRecord(for: cat.title)
        else { return }

        if isAddingRole {
            let trimmed = newRoleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addRole(text: trimmed, record: record) }
            newRoleText = ""
            isAddingRole = false
        }
        if isAddingFocus {
            let trimmed = newFocusText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addFocus(text: trimmed, record: record) }
            newFocusText = ""
            isAddingFocus = false
        }
        if isAddingResource {
            let trimmed = newResourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addResource(text: trimmed, record: record) }
            newResourceText = ""
            isAddingResource = false
        }
    }
    
    private func commitInlineExcluding(_ keepOpen: Field?) {
        guard let openID = expandedCardID,
              let cat = categories.first(where: { $0.id == openID }),
              let record = fulfillmentRecord(for: cat.title)
        else { return }

        if isAddingRole && keepOpen != .role {
            let trimmed = newRoleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addRole(text: trimmed, record: record) }
            newRoleText = ""
            isAddingRole = false
        }
        if isAddingFocus && keepOpen != .focus {
            let trimmed = newFocusText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addFocus(text: trimmed, record: record) }
            newFocusText = ""
            isAddingFocus = false
        }
        if isAddingResource && keepOpen != .resource {
            let trimmed = newResourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addResource(text: trimmed, record: record) }
            newResourceText = ""
            isAddingResource = false
        }
    }

    @ViewBuilder
    private func card(
        id: String,
        title: String,
        iconName: String,
        color: Color,
        lightColor: Color
    ) -> some View {
        if let record = fulfillmentRecord(for: title) {
            let isExpanded = (expandedCardID == id)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                }
                .padding()
                .background(color)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        expandedCardID = isExpanded ? nil : id
                    }
                }

                if isExpanded {
                    VStack(alignment: .leading, spacing: 16) {
                    Text("Vision")
                        .font(.headline)
                        .foregroundColor(.black)
                    TextField(
                        "Fit, strong, flexible and CALM",
                        text: Binding(
                            get: { record.category_vision },
                            set: { new in updateVision(record: record, newText: new) }
                        )
                    )
                    .textFieldStyle(.roundedBorder)
                    .focused($focusedField, equals: .vision)

                    Text("Purpose")
                        .font(.headline)
                        .foregroundColor(.black)
                    TextEditor(
                        text: Binding(
                            get: { record.category_purpose },
                            set: { new in updatePurpose(record: record, newText: new) }
                        )
                    )
                    .frame(minHeight: 100)
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(Color.gray.opacity(0.4)))
                    .focused($focusedField, equals: .purpose)

                    Text("Roles")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        let rolesForRecord = getRoles(for: record)
                        ForEach(getRoles(for: record), id: \.id) { r in
                            Text(r.role)
                        }
                        .onMove { from, to in
                            moveRoles(from: from, to: to, record: record)
                        }
                        .onDelete { idx in
                            deleteRoles(at: idx, record: record)
                        }

                        if isAddingRole {
                            HStack {
                                TextField("H2O lover", text: $newRoleText)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .role)
                                    .onSubmit {
                                        addRole(text: newRoleText, record: record)
                                        newRoleText = ""
                                        isAddingRole = false
                                        focusedField = nil
                                    }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        } else if rolesForRecord.count < 3 {
                            HStack {
                                Button("Add Role") {
                                    withAnimation { isAddingRole = true }
                                    DispatchQueue.main.async { focusedField = .role }
                                }
                                .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .environment(\.editMode, .constant(.active))
                    .frame(height: CGFloat(getRoles(for: record).count + (isAddingRole ? 1 : 1)) * estimatedListRowHeight())

                    Text("Three-to-Thrive")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        let fociForRecord = getFoci(for: record)
                        ForEach(getFoci(for: record), id: \.id) { f in
                            Text(f.activity)
                        }
                        .onMove { from, to in
                            moveFoci(from: from, to: to, record: record)
                        }
                        .onDelete { idx in
                            deleteFoci(at: idx, record: record)
                        }

                        if isAddingFocus {
                            HStack {
                                TextField("yoga classes", text: $newFocusText)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .focus)
                                    .onSubmit {
                                        addFocus(text: newFocusText, record: record)
                                        newFocusText = ""
                                        isAddingFocus = false
                                        focusedField = nil
                                    }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        } else if fociForRecord.count < 3 {
                            HStack {
                                Button("Add Focus") {
                                    withAnimation { isAddingFocus = true }
                                    DispatchQueue.main.async { focusedField = .focus }
                                }
                                .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .environment(\.editMode, .constant(.active))
                    .frame(height: CGFloat(getFoci(for: record).count + (isAddingFocus ? 1 : 1)) * estimatedListRowHeight())

                    Text("Resources")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        ForEach(getResources(for: record), id: \.id) { res in
                            Text(res.resource)
                        }
                        .onMove { from, to in
                            moveResources(from: from, to: to, record: record)
                        }
                        .onDelete { idx in
                            deleteResources(at: idx, record: record)
                        }

                        if isAddingResource {
                            HStack {
                                TextField("great gym nearby", text: $newResourceText)
                                    .submitLabel(.done)
                                    .focused($focusedField, equals: .resource)
                                    .onSubmit {
                                        addResource(text: newResourceText, record: record)
                                        newResourceText = ""
                                        isAddingResource = false
                                        focusedField = nil
                                    }
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        } else {
                            HStack {
                                Button("Add Resource") {
                                    withAnimation { isAddingResource = true }
                                    DispatchQueue.main.async { focusedField = .resource }
                                }
                                .foregroundColor(.blue)
                                Spacer()
                            }
                            .padding(.vertical, 4)
                            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
                        }
                    }
                    .listStyle(.plain)
                    .scrollDisabled(true)
                    .environment(\.editMode, .constant(.active))
                    .frame(height: CGFloat(getResources(for: record).count + (isAddingResource ? 1 : 1)) * estimatedListRowHeight())

                    PassionsSectionView(record: record)
                    }
                    .padding()
                    .background(lightColor)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )) { _ in
                if expandedCardID == id {
                    expandedCardID = id
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
        } else {
            EmptyView()
        }
    }

    // MARK: - Completion Helpers
    private func batteryIconName(for categoryTitle: String) -> String {
        let count = completionCount(for: categoryTitle)
        switch count {
        case 0: return "battery.0"
        case 1...2: return "battery.25"
        case 3...4: return "battery.50"
        case 5: return "battery.75"
        default: return "battery.100"
        }
    }

    private func completionCount(for categoryTitle: String) -> Int {
        guard let record = fulfillments.first(where: { $0.category == categoryTitle }) else {
            return 0
        }
        let hasVision = !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRole = roles.contains { $0.category_id == record.category_id }
        let hasFocus = foci.contains { $0.category_id == record.category_id }
        let hasResource = resources.contains { $0.category_id == record.category_id }
        let passionIDs = Set(passions.map(\.passion_id))
        let hasPassion = passionJoins.contains { $0.category_id == record.category_id && passionIDs.contains($0.passion_id) }
        return [hasVision, hasPurpose, hasRole, hasFocus, hasResource, hasPassion].filter { $0 }.count
    }

    private func isCategoryComplete(_ categoryTitle: String) -> Bool {
        completionCount(for: categoryTitle) == 6
    }

    private var fulfillmentMetrics: [(String, Color, Double)] {
        categories.map { cat in
            let pct = (Double(radarScore(for: cat.title)) / 5.0) * 100.0
            return (cat.title, FulfillmentCategoryTheme.color(for: cat.title), pct)
        }
    }

    private func radarScore(for categoryTitle: String) -> Int {
        let raw = completionCount(for: categoryTitle)
        let scaled = Int(round((Double(raw) / 6.0) * 5.0))
        return min(5, max(0, scaled))
    }

    // MARK: - Data Helpers

    private func fulfillmentRecord(for category: String) -> Fulfillment? {
        fulfillments.first(where: { $0.category == category })
    }

    private func ensureCategoryRecordsExist() {
        var insertedAny = false
        for cat in categories where fulfillmentRecord(for: cat.title) == nil {
            let f = Fulfillment(category: cat.title)
            modelContext.insert(f)
            insertedAny = true
        }
        if insertedAny {
            try? modelContext.save()
        }
    }

    private func updateVision(record: Fulfillment, newText: String) {
        guard record.category_vision != newText else { return }
        let archive = FulfillmentArchive(
            category_id: record.category_id,
            updatedAt: record.updatedAt,
            category: record.category,
            category_identitiy: record.category_identitiy,
            category_vision: record.category_vision,
            category_purpose: record.category_purpose,
            archivedAt: Date()
        )
        modelContext.insert(archive)
        record.category_vision = newText
        record.updatedAt = Date()
    }

    private func updatePurpose(record: Fulfillment, newText: String) {
        guard record.category_purpose != newText else { return }
        let archive = FulfillmentArchive(
            category_id: record.category_id,
            updatedAt: record.updatedAt,
            category: record.category,
            category_identitiy: record.category_identitiy,
            category_vision: record.category_vision,
            category_purpose: record.category_purpose,
            archivedAt: Date()
        )
        modelContext.insert(archive)
        record.category_purpose = newText
        record.updatedAt = Date()
    }

    private func getRoles(for f: Fulfillment) -> [FulfillmentRoles] {
        roles.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addRole(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        guard getRoles(for: record).count < 3 else { return }
        let nextRank = (getRoles(for: record).map(\.rank).max() ?? 0) + 1
        let r = FulfillmentRoles(category_id: record.category_id, role: text, rank: nextRank)
        modelContext.insert(r)
        if nextRank == 1 {
            let archive = FulfillmentArchive(
                category_id: record.category_id,
                updatedAt: record.updatedAt,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            record.category_identitiy = text
            record.updatedAt = Date()
        }
    }

    private func moveRoles(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getRoles(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, r) in list.enumerated() {
            if r.rank != i + 1 {
                let archive = FulfillmentRolesArchive(
                    category_id: r.category_id,
                    updatedAt: r.updatedAt,
                    role: r.role,
                    rank: r.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                r.rank = i + 1
                r.updatedAt = Date()
            }
        }
        if let top = list.first, top.role != record.category_identitiy {
            let archive = FulfillmentArchive(
                category_id: record.category_id,
                updatedAt: record.updatedAt,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            record.category_identitiy = top.role
            record.updatedAt = Date()
        }
    }

    private func deleteRoles(at offsets: IndexSet, record: Fulfillment) {
        let list = getRoles(for: record)
        for idx in offsets {
            let r = list[idx]
            let archive = FulfillmentRolesArchive(
                category_id: r.category_id,
                updatedAt: r.updatedAt,
                role: r.role,
                rank: r.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            RecentlyDeletedStore.trash(r, in: modelContext)
        }
    }

    private func getFoci(for f: Fulfillment) -> [FulfillmentFocus] {
        foci.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addFocus(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        guard getFoci(for: record).count < 3 else { return }
        let nextRank = (getFoci(for: record).map(\.rank).max() ?? 0) + 1
        let f = FulfillmentFocus(category_id: record.category_id, activity: text, rank: nextRank)
        modelContext.insert(f)
    }

    private func moveFoci(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getFoci(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, f) in list.enumerated() {
            if f.rank != i + 1 {
                let archive = FulfillmentFocusArchive(
                    category_id: f.category_id,
                    updatedAt: f.updatedAt,
                    activity: f.activity,
                    rank: f.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                f.rank = i + 1
                f.updatedAt = Date()
            }
        }
    }

    private func deleteFoci(at offsets: IndexSet, record: Fulfillment) {
        let list = getFoci(for: record)
        for idx in offsets {
            let f = list[idx]
            let archive = FulfillmentFocusArchive(
                category_id: f.category_id,
                updatedAt: f.updatedAt,
                activity: f.activity,
                rank: f.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            RecentlyDeletedStore.trash(f, in: modelContext)
        }
    }

    private func getResources(for f: Fulfillment) -> [FulfillmentResources] {
        resources.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addResource(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        let nextRank = (getResources(for: record).map(\.rank).max() ?? 0) + 1
        let r = FulfillmentResources(category_id: record.category_id, resource: text, rank: nextRank)
        modelContext.insert(r)
    }

    private func moveResources(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getResources(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, r) in list.enumerated() {
            if r.rank != i + 1 {
                let archive = FulfillmentResourcesArchive(
                    category_id: r.category_id,
                    updatedAt: r.updatedAt,
                    resource: r.resource,
                    rank: r.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                r.rank = i + 1
                r.updatedAt = Date()
            }
        }
    }

    private func deleteResources(at offsets: IndexSet, record: Fulfillment) {
        let list = getResources(for: record)
        for idx in offsets {
            let r = list[idx]
            let archive = FulfillmentResourcesArchive(
                category_id: r.category_id,
                updatedAt: r.updatedAt,
                resource: r.resource,
                rank: r.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            RecentlyDeletedStore.trash(r, in: modelContext)
        }
    }
}

private struct FulfillmentTrendRow: Identifiable {
    let id = UUID()
    let monthIndex: Int
    let month: String
    let category: String
    let value: Double
}

private struct FulfillmentTrendsView: View {
    private let rows: [FulfillmentTrendRow] = FulfillmentTrendsView.buildRows()
    private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private var categoryStyleScale: KeyValuePairs<String, Color> {
        [
            "Career & Business": FulfillmentCategoryTheme.color(for: "Career & Business"),
            "Leadership & Impact": FulfillmentCategoryTheme.color(for: "Leadership & Impact"),
            "Wealth & Lifestyle": FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"),
            "Mind & Meaning": FulfillmentCategoryTheme.color(for: "Mind & Meaning"),
            "Love & Relationships": FulfillmentCategoryTheme.color(for: "Love & Relationships"),
            "Health & Vitality": FulfillmentCategoryTheme.color(for: "Health & Vitality")
        ]
    }

    private var colorScale: [String: Color] {
        [
            "Career & Business": FulfillmentCategoryTheme.color(for: "Career & Business"),
            "Leadership & Impact": FulfillmentCategoryTheme.color(for: "Leadership & Impact"),
            "Wealth & Lifestyle": FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"),
            "Mind & Meaning": FulfillmentCategoryTheme.color(for: "Mind & Meaning"),
            "Love & Relationships": FulfillmentCategoryTheme.color(for: "Love & Relationships"),
            "Health & Vitality": FulfillmentCategoryTheme.color(for: "Health & Vitality")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 10) {
                Chart(rows) { row in
                    AreaMark(
                        x: .value("Month", row.monthIndex),
                        y: .value("Score", row.value),
                        stacking: .standard
                    )
                    .foregroundStyle(by: .value("Category", row.category))
                    .interpolationMethod(.catmullRom)
                }
                .chartForegroundStyleScale(categoryStyleScale)
                .chartXScale(domain: 0...11)
                .chartXAxis {
                    AxisMarks(values: Array(0...11)) { value in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel {
                            if let i = value.as(Int.self), i >= 0, i < months.count {
                                Text(months[i])
                            }
                        }
                    }
                }
                .chartYScale(domain: 0...25)
                .chartYAxis {
                    AxisMarks(position: .trailing, values: Array(stride(from: 0, through: 25, by: 5))) { _ in
                        AxisGridLine()
                        AxisTick()
                        AxisValueLabel()
                    }
                }
                .frame(height: 250)
                .opacity(0.2)
                .overlay {
                    VStack(spacing: 4) {
                        Text("Not Available Yet")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("History and trends will be available over time.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 16)
                }

                insightsSkeleton
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Fulfillment Trends")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var insightsSkeleton: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                skeletonTile()
                skeletonTile()
                skeletonTile()
            }

            VStack(alignment: .leading, spacing: 10) {
                skeletonLine(width: 180, height: 12)
                skeletonSignalRow()
                skeletonSignalRow()
                skeletonSignalRow()
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

            VStack(alignment: .leading, spacing: 8) {
                skeletonCapsuleRow()
                skeletonCapsuleRow()
                skeletonCapsuleRow()
            }
        }
    }

    private func skeletonTile() -> some View {
        VStack(alignment: .leading, spacing: 6) {
            skeletonLine(width: 54, height: 8)
            skeletonLine(width: 42, height: 16)
            skeletonLine(width: 62, height: 8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func skeletonSignalRow() -> some View {
        HStack(spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(Color(.systemGray4))
                .frame(width: 14, height: 14)
            skeletonLine(width: 130, height: 11)
            Spacer(minLength: 0)
            skeletonLine(width: 70, height: 11)
        }
    }

    private func skeletonCapsuleRow() -> some View {
        HStack(spacing: 8) {
            skeletonLine(width: 140, height: 12)
            Spacer(minLength: 0)
            Capsule()
                .fill(Color(.systemGray4))
                .frame(width: 42, height: 20)
        }
    }

    private func skeletonLine(width: CGFloat, height: CGFloat) -> some View {
        RoundedRectangle(cornerRadius: max(4, height / 2))
            .fill(Color(.systemGray4))
            .frame(width: width, height: height)
    }

    private static func buildRows() -> [FulfillmentTrendRow] {
        let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
        let categoryTitles = [
            "Career & Business",
            "Leadership & Impact",
            "Wealth & Lifestyle",
            "Mind & Meaning",
            "Love & Relationships",
            "Health & Vitality"
        ]

        return months.enumerated().flatMap { monthIndex, month in
            categoryTitles.enumerated().map { categoryIndex, category in
                // Deterministic but varied whole-number values in 1...5.
                let baseSeed = monthIndex * 131 + categoryIndex * 59 + 17
                let wave1 = sin(Double(baseSeed) * 0.51 + Double(monthIndex) * 0.93)
                let wave2 = cos(Double(baseSeed) * 0.27 + Double(categoryIndex) * 1.21)
                let mixed = (wave1 * 0.55 + wave2 * 0.45 + 1.0) * 0.5
                let score = min(5.0, max(1.0, round(mixed * 5.0)))
                return FulfillmentTrendRow(monthIndex: monthIndex, month: month, category: category, value: score)
            }
        }
    }
}

private struct FulfillmentInteractiveRadar: View {
    let metrics: [(String, Color, Double)]
    @Binding var selectedIndex: Int
    let onManualSelect: () -> Void
    @State private var pulseIndex: Int? = nil

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let count = max(metrics.count, 1)

            let outerPoints: [CGPoint] = (0..<count).map { i in
                let angle = Angle.degrees((Double(i) / Double(count)) * 360 - 90).radians
                return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
            }

            let renderedMetrics: [(String, Color, Double)] = (0..<count).map { i in
                (metrics[i].0, segmentColor(i), metrics[i].2)
            }
            let valuePoints: [CGPoint] = (0..<count).map { i in
                let ratio = max(0, min(metrics[i].2 / 100.0, 1.0))
                let outer = outerPoints[i]
                return CGPoint(
                    x: center.x + (outer.x - center.x) * ratio,
                    y: center.y + (outer.y - center.y) * ratio
                )
            }

            ZStack {
                // Keep the radar internals identical to ContentView's graph style.
                FulfillmentRadarGraph(
                    metrics: renderedMetrics,
                    showOutline: true,
                    dotDiameter: 20,
                    showDotOutline: false,
                    showDotShadow: false
                )

                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(metrics[i].1)
                        .frame(width: 20, height: 20)
                        .overlay(
                            Circle().stroke(Color(.systemBackground), lineWidth: 2)
                        )
                        .shadow(color: Color.white.opacity(0.9), radius: 10, x: 0, y: 0)
                        .scaleEffect(circleScale(for: i))
                        .animation(.easeInOut(duration: 0.18), value: pulseIndex)
                        .animation(.easeInOut(duration: 0.18), value: selectedIndex)
                        .position(valuePoints[i])
                }

                ForEach(0..<count, id: \.self) { i in
                    let next = (i + 1) % count
                    sliceTapShape(center: center, p1: outerPoints[i], p2: outerPoints[next])
                        .fill(Color.clear)
                        .contentShape(sliceTapShape(center: center, p1: outerPoints[i], p2: outerPoints[next]))
                        .onTapGesture {
                            selectSlice(i)
                        }
                }

                // Larger, invisible tap targets around dots for easier selection.
                ForEach(0..<count, id: \.self) { i in
                    Circle()
                        .fill(Color.clear)
                        .frame(width: 44, height: 44)
                        .contentShape(Circle())
                        .position(valuePoints[i])
                        .onTapGesture {
                            selectSlice(i)
                        }
                }
            }
        }
    }

    private func segmentColor(_ index: Int) -> Color {
        if index == selectedIndex {
            return metrics[index].1
        }
        return muted(metrics[index].1)
    }

    private func muted(_ color: Color) -> Color {
        color.opacity(0.25)
    }

    private func selectSlice(_ index: Int) {
        selectedIndex = index
        onManualSelect()
        pulseIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if pulseIndex == index {
                pulseIndex = nil
            }
        }
    }

    private func sliceTapShape(center: CGPoint, p1: CGPoint, p2: CGPoint) -> Path {
        Path { path in
            path.move(to: center)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.closeSubpath()
        }
    }

    private func circleScale(for index: Int) -> CGFloat {
        if pulseIndex == index { return 1.35 }
        if selectedIndex == index { return 1.20 }
        return 1.0
    }
}
