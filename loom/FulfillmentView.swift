import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

fileprivate struct CategoryDef: Identifiable {
    let id: String
    let title: String
    let iconName: String
    let color: Color
}

fileprivate let categories: [CategoryDef] = [
    .init(id: "career",     title: "Career & Business",    iconName: "battery.25", color: .blue),
    .init(id: "leadership", title: "Leadership & Impact",  iconName: "battery.25", color: .indigo),
    .init(id: "wealth",     title: "Wealth & Lifestyle",   iconName: "battery.25", color: .green),
    .init(id: "mind",       title: "Mind & Meaning",       iconName: "battery.25", color: .purple),
    .init(id: "love",       title: "Love & Relationships", iconName: "battery.25", color: .red),
    .init(id: "health",     title: "Health & Vitality",    iconName: "battery.25", color: .orange),
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
            modelContext.delete(join)
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
    @FocusState private var focusedField: Field?
    private enum Field { case vision, purpose, role, focus, resource }

    private let lightBlue = Color(red: 0.70, green: 0.85, blue: 1.00)
    private let lightIndigo = Color(red: 0.80, green: 0.80, blue: 0.95)
    private let lightGreen = Color(red: 0.80, green: 1.00, blue: 0.80)
    private let lightPurple = Color(red: 0.90, green: 0.80, blue: 0.90)
    private let lightRed = Color(red: 1.00, green: 0.80, blue: 0.80)
    private let lightOrange = Color(red: 1.00, green: 0.90, blue: 0.70)

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

                VStack(spacing: 16) {
                    ForEach(categories) { cat in
                        card(
                            id: cat.id,
                            title: cat.title,
                            iconName: batteryIconName(for: cat.title),
                            color: cat.color,
                            lightColor: lightColor(for: cat.id)
                        )
                    }
                    Spacer()
                }
                .padding()
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

    private func lightColor(for id: String) -> Color {
        switch id {
        case "career": return lightBlue
        case "leadership": return lightIndigo
        case "wealth": return lightGreen
        case "mind": return lightPurple
        case "love": return lightRed
        case "health": return lightOrange
        default: return Color.gray.opacity(0.1)
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
            modelContext.delete(r)
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
            modelContext.delete(f)
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
            modelContext.delete(r)
        }
    }
}
