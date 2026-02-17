import SwiftUI
import SwiftData
import Charts
#if canImport(UIKit)
import UIKit
#endif

fileprivate struct CategoryDef: Identifiable {
    let id: String
    let title: String
    let categoryID: UUID
}

fileprivate let defaultCategoryDefs: [CategoryDef] = [
    .init(id: "career",     title: "Career & Business",    categoryID: PlanLabelSeeder.categoryIDs["Career & Business"]!),
    .init(id: "leadership", title: "Leadership & Impact",  categoryID: PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
    .init(id: "wealth",     title: "Wealth & Lifestyle",   categoryID: PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
    .init(id: "mind",       title: "Mind & Meaning",       categoryID: PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
    .init(id: "love",       title: "Love & Relationships", categoryID: PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
    .init(id: "health",     title: "Health & Vitality",    categoryID: PlanLabelSeeder.categoryIDs["Health & Vitality"]!),
]

fileprivate let defaultFulfillmentCategoryTitles: [String] = defaultCategoryDefs.map(\.title)

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

            if categoryPassions.isEmpty {
                Text("No passions connected yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(categoryPassions, id: \.passion_id) { passion in
                        Text("\(passion.emotion.capitalized): \(passion.passion)")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Button("Connect Passion") {
                isSelectingPassion = true
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $isSelectingPassion) {
                NavigationStack {
                    List {
                        ForEach(passions, id: \.passion_id) { passion in
                            Button {
                                togglePassion(passion)
                            } label: {
                                HStack {
                                    Text("\(passion.emotion.capitalized): \(passion.passion)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if categoryPassions.contains(where: { $0.passion_id == passion.passion_id }) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                    }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationTitle("Connect Passions to \(record.category)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { isSelectingPassion = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
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
    @Environment(\.colorScheme) private var colorScheme

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query private var passions: [Passion]
    @Query(sort: \ReplacedFulfillmentCategoryArchive.replacedAt, order: .reverse)
    private var replacedCategoryArchives: [ReplacedFulfillmentCategoryArchive]

    @State private var expandedCardID: String? = nil
    @State private var showPreviousCategories = false
    @State private var pendingDeletePrevious: ReplacedFulfillmentCategoryArchive?
    @State private var showDeletePreviousAlert = false
    @State private var expandedPreviousID: UUID? = nil
    @State private var previousCardSwipeOffset: [UUID: CGFloat] = [:]
    @State private var isAddingRole = false
    @State private var newRoleText = ""
    @State private var isAddingFocus = false
    @State private var newFocusText = ""
    @State private var isAddingResource = false
    @State private var newResourceText = ""
    @State private var editingRecordID: UUID?
    @State private var editingText: String = ""
    @State private var editingOriginalText: String = ""
    @State private var editingField: EditableField?
    @State private var isEditSheetTextFocused: Bool = false
    @State private var editSheetCursorSeed: Int = 0
    @State private var isShowingInstructions = false
    @State private var highlightedCategoryIndex: Int = 0
    @State private var radarAutoRotatePausedUntil: Date = .distantPast
    @FocusState private var focusedField: Field?
    private enum Field { case role, focus, resource }
    private enum EditableField: Identifiable {
        case vision, purpose
        var id: String { self == .vision ? "vision" : "purpose" }
    }
    private let radarTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private func categoryKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let andNormalized = trimmed.replacingOccurrences(of: "&", with: " and ")
        let cleaned = andNormalized.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        let collapsed = cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return collapsed
    }

    private var orderedFulfillments: [Fulfillment] {
        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        var seenTitleKeys = Set<String>()
        for def in defaultCategoryDefs {
            if let record = byID.removeValue(forKey: def.categoryID) {
                let key = categoryKey(record.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { continue }
                ordered.append(record)
                seenTitleKeys.insert(key)
            }
        }
        let extras = byID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { row in
                let key = categoryKey(row.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { return false }
                seenTitleKeys.insert(key)
                return true
            }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        ordered.append(contentsOf: extras)
        return Array(ordered.prefix(7))
    }

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
                        ForEach(orderedFulfillments, id: \.category_id) { record in
                            let title = record.category
                            card(
                                id: record.category_id.uuidString,
                                title: title,
                                iconName: batteryIconName(for: record),
                                color: FulfillmentCategoryTheme.color(for: title),
                                lightColor: FulfillmentCategoryTheme.lightColor(for: title),
                                record: record
                            )
                        }

                        previousCategoriesSection
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
                if editingField == nil {
                    Spacer(minLength: 0)
                    Button("Done") { focusedField = nil }
                }
            }
        }
        .onChange(of: focusedField) { _, new in
            commitInlineExcluding(new)
        }
        .onReceive(radarTimer) { _ in
            guard !orderedFulfillments.isEmpty else { return }
            guard Date() >= radarAutoRotatePausedUntil else { return }
            if highlightedCategoryIndex >= orderedFulfillments.count { highlightedCategoryIndex = 0 }
            highlightedCategoryIndex = (highlightedCategoryIndex + 1) % orderedFulfillments.count
        }
        .sheet(isPresented: $isShowingInstructions) {
            fulfillmentInstructionsSheet()
        }
        .sheet(item: $editingField) { field in
            let hasChanges = editingText != editingOriginalText
            let categoryPrefix: String = {
                guard let recordID = editingRecordID,
                      let record = fulfillments.first(where: { $0.category_id == recordID }) else {
                    return "Category"
                }
                return record.category
            }()
            NavigationStack {
                List {
                    Section(field == .vision ? "\(categoryPrefix) Vision" : "\(categoryPrefix) Purpose") {
                        FulfillmentEditorTextView(
                            text: $editingText,
                            isFocused: $isEditSheetTextFocused,
                            cursorSeed: editSheetCursorSeed
                        )
                        .frame(height: 140)
                    }
                }
                .navigationTitle(field == .vision ? "Edit Vision" : "Edit Purpose")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button(hasChanges ? "Cancel" : "Close") {
                            isEditSheetTextFocused = false
                            editingField = nil
                            editingRecordID = nil
                            editingText = ""
                            editingOriginalText = ""
                        }
                        .foregroundColor(hasChanges ? .red : .primary)
                    }
                    if hasChanges {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Update") {
                                guard let recordID = editingRecordID,
                                      let record = fulfillments.first(where: { $0.category_id == recordID }) else {
                                    isEditSheetTextFocused = false
                                    editingField = nil
                                    editingRecordID = nil
                                    editingText = ""
                                    editingOriginalText = ""
                                    return
                                }
                                if field == .vision {
                                    updateVision(record: record, newText: editingText)
                                } else {
                                    updatePurpose(record: record, newText: editingText)
                                }
                                isEditSheetTextFocused = false
                                editingField = nil
                                editingRecordID = nil
                                editingText = ""
                                editingOriginalText = ""
                            }
                            .foregroundColor(.blue)
                        }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
            .onAppear {
                editSheetCursorSeed &+= 1
                DispatchQueue.main.async {
                    isEditSheetTextFocused = true
                }
            }
        }
        .alert("Move to Recently Deleted?", isPresented: $showDeletePreviousAlert, presenting: pendingDeletePrevious) { snapshot in
            Button("Cancel", role: .cancel) {
                pendingDeletePrevious = nil
            }
            Button("Delete", role: .destructive) {
                RecentlyDeletedStore.trash(snapshot, in: modelContext)
                try? modelContext.save()
                pendingDeletePrevious = nil
            }
        } message: { _ in
            Text("This item will be available for 30 days in account management.")
        }
    }

    private var previousCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            if !replacedCategoryArchives.isEmpty {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showPreviousCategories.toggle()
                        if !showPreviousCategories {
                            expandedPreviousID = nil
                        }
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: showPreviousCategories ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                        Text("Previous Categories")
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(colorScheme == .dark ? Color(.systemGray2) : .black)
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

                if showPreviousCategories {
                    ForEach(replacedCategoryArchives, id: \.id) { archive in
                        previousCategorySwipeContainer(for: archive)
                    }
                }
            }
        }
    }

    private func fulfillmentInstructionsSheet() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Instructions")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                fulfillmentInstructionBody("You can manage and edit your categories anytime in:")
                HStack(spacing: 6) {
                    Text("Account")
                    Image(systemName: "person.circle")
                    Text("→ Manage Fulfillment Categories")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("1. Choose Your Fulfillment Categories")
                fulfillmentInstructionBody("Start with broad, high-impact areas of life that must grow for your life to feel meaningful and balanced.")
                fulfillmentInstructionBody("Most people use 5–7 categories.\nExamples include:")
                fulfillmentInstructionBullets([
                    "Career & Business",
                    "Leadership & Impact",
                    "Wealth & Lifestyle",
                    "Mind & Meaning",
                    "Love & Relationships",
                    "Health & Vitality"
                ])
                fulfillmentInstructionBody("Your categories should be:")
                fulfillmentInstructionBullets([
                    "Broad enough to last years",
                    "Clear enough to guide decisions",
                    "Important enough that neglect hurts your life"
                ])
                fulfillmentInstructionBody("If you don’t improve in this area, your quality of life will suffer.\nIf you grow in this area, your fulfillment increases.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("2. Vision")
                fulfillmentInstructionBody("What do you ultimately want this area of your life to look like?\nThink long-term. Imagine your ideal future.")
                fulfillmentInstructionLabel("Focus on:")
                fulfillmentInstructionBullets([
                    "How your life looks",
                    "How you feel",
                    "What success in this area means"
                ])
                fulfillmentInstructionLabel("Example:")
                fulfillmentInstructionExample("Strong, energized, confident, and physically capable in every stage of life.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("3. Purpose")
                fulfillmentInstructionBody("Why is this area an absolute must for you?\nThis creates emotional drive. Without purpose, action fades.")
                fulfillmentInstructionLabel("Consider:")
                fulfillmentInstructionBullets([
                    "Why this matters",
                    "What this gives you",
                    "Who this impacts",
                    "How you will feel when you improve"
                ])
                fulfillmentInstructionBody("This is your fuel when motivation is low.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("4. Roles")
                fulfillmentInstructionBody("Who are you being in this area of life?\nRoles shape identity and behavior.")
                fulfillmentInstructionLabel("Think about:")
                fulfillmentInstructionBullets([
                    "The person you want to become",
                    "How you show up for others",
                    "The standards you hold yourself to"
                ])
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionExample("Leader, Provider, Builder, Mentor, Creator, Partner.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("5. Three-to-Thrive")
                fulfillmentInstructionBody("These are the three highest-impact habits in this category.")
                fulfillmentInstructionBody("They should be:")
                fulfillmentInstructionBullets([
                    "Simple",
                    "Repeatable",
                    "Weekly or daily",
                    "High leverage"
                ])
                fulfillmentInstructionBody("These drive consistent momentum even when life is busy.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionExample("Health & Vitality\n• 10k steps\n• Strength training\n• Deep breathing\n\nWealth & Lifestyle\n• Budget review\n• Financial learning\n• Strategic planning.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("6. Resources")
                fulfillmentInstructionBody("What people, tools, or systems help you grow here?")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Mentors",
                    "Books or courses",
                    "Apps or tools",
                    "Networks",
                    "Coaches or communities"
                ])
                fulfillmentInstructionBody("This prevents trying to do everything alone.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("7. Connect to Your Passions")
                fulfillmentInstructionBody("Each category should link to your Driving Force.")
                fulfillmentInstructionLabel("Ask:")
                fulfillmentInstructionBullets([
                    "Which Love does this category express?",
                    "Which Thrills does it activate?",
                    "Which Vows does it support?",
                    "Which Hates does it help you fight?"
                ])
                fulfillmentInstructionBody("This connection creates emotional leverage and long-term consistency.")
                fulfillmentInstructionBody("When your categories connect to your passions, progress becomes meaningful.")

                Divider().opacity(0.45)

                fulfillmentInstructionSectionTitle("Key Reminder")
                fulfillmentInstructionBody("Your Fulfillment Categories are your life operating system.")
                fulfillmentInstructionBody("They guide:")
                fulfillmentInstructionBullets([
                    "Your long-term goals",
                    "Your weekly planning",
                    "Your daily actions",
                    "Your growth and identity"
                ])
                fulfillmentInstructionBody("Review them regularly.\nRefine them yearly.\n\nClarity here makes everything else easier.")
            }
            .padding()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func fulfillmentInstructionSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func fulfillmentInstructionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func fulfillmentInstructionBody(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func fulfillmentInstructionExample(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.italic())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func fulfillmentInstructionBullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func previousCategorySwipeContainer(for archive: ReplacedFulfillmentCategoryArchive) -> some View {
        let offset = previousCardSwipeOffset[archive.id] ?? 0
        return ZStack(alignment: .trailing) {
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red)
            HStack {
                Spacer(minLength: 0)
                Button("Delete", role: .destructive) {
                    pendingDeletePrevious = archive
                    showDeletePreviousAlert = true
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 16)
            }
            previousCategoryCard(archive)
                .offset(x: offset)
                .gesture(
                    DragGesture(minimumDistance: 10, coordinateSpace: .local)
                        .onChanged { value in
                            if value.translation.width < 0 {
                                previousCardSwipeOffset[archive.id] = max(-104, value.translation.width)
                            } else if (previousCardSwipeOffset[archive.id] ?? 0) < 0 {
                                previousCardSwipeOffset[archive.id] = min(0, value.translation.width - 104)
                            }
                        }
                        .onEnded { value in
                            let shouldOpen = value.translation.width < -48 || (previousCardSwipeOffset[archive.id] ?? 0) < -52
                            withAnimation(.easeOut(duration: 0.2)) {
                                previousCardSwipeOffset[archive.id] = shouldOpen ? -104 : 0
                            }
                        }
                )
                .onTapGesture {
                    if (previousCardSwipeOffset[archive.id] ?? 0) < 0 {
                        withAnimation(.easeOut(duration: 0.2)) {
                            previousCardSwipeOffset[archive.id] = 0
                        }
                    }
                }
        }
        .frame(maxWidth: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func previousCategoryCard(_ archive: ReplacedFulfillmentCategoryArchive) -> some View {
        let roles = csvItems(from: archive.rolesCSV)
        let fociValues = csvItems(from: archive.fociCSV)
        let resourcesValues = csvItems(from: archive.resourcesCSV)
        let passionValues = csvItems(from: archive.passionsCSV)
        let isExpanded = (expandedPreviousID == archive.id)
        let hasVision = !archive.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !archive.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIdentity = !archive.category_identitiy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let completionCount = [hasVision, hasPurpose, hasIdentity, !roles.isEmpty, !fociValues.isEmpty, !resourcesValues.isEmpty, !passionValues.isEmpty].filter { $0 }.count
        let iconName: String = {
            switch completionCount {
            case 0: return "battery.0"
            case 1...2: return "battery.25"
            case 3...4: return "battery.50"
            case 5: return "battery.75"
            default: return "battery.100"
            }
        }()

        return VStack(spacing: 0) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.white)
                Text(archive.category)
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text("Replaced \(replacementDateText(archive.replacedAt))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(.systemGray2))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut) {
                    if isExpanded {
                        expandedPreviousID = nil
                    } else {
                        expandedPreviousID = archive.id
                        expandedCardID = nil
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Vision")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(archive.category_vision.isEmpty ? "No vision saved." : archive.category_vision)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Purpose")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(archive.category_purpose.isEmpty ? "No purpose saved." : archive.category_purpose)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Roles")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: roles)

                    Text("Focus")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: fociValues)

                    Text("Resources")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: resourcesValues)

                    Text("Passions")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: passionValues)
                }
                .padding(16)
                .background(Color(.systemGray6))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
    }

    private func readOnlyRows(values: [String]) -> some View {
        VStack(spacing: 0) {
            if values.isEmpty {
                Text("No items saved.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(values.indices, id: \.self) { index in
                    Text(values[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }
        }
    }

    private func replacementDateText(_ date: Date) -> String {
        let nowYear = Calendar.current.component(.year, from: .now)
        let year = Calendar.current.component(.year, from: date)
        if nowYear == year {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.month().day().year())
    }

    private func csvItems(from value: String) -> [String] {
        value
            .components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private var fulfillmentRadarHeader: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let baseGraphWidth = max(120, width * 0.40)
            let graphWidth = baseGraphWidth * 1.2
            let leftWidth = max(120, width - baseGraphWidth - 28)
            if orderedFulfillments.isEmpty {
                EmptyView()
            } else {
                let selectedIndex = min(max(0, highlightedCategoryIndex), max(0, orderedFulfillments.count - 1))
                let selected = orderedFulfillments[selectedIndex]
                let selectedTitle = selected.category
                let selectedScore = Int(round((batteryPercentage(for: selected) / 100.0) * 5.0))

                HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                        Text(selectedTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(FulfillmentCategoryTheme.color(for: selectedTitle))
                            .lineLimit(2)
                    Text("Tap radar slice to focus")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    RoundedRectangle(cornerRadius: 10)
                        .fill(FulfillmentCategoryTheme.color(for: selectedTitle))
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
        }
        .frame(height: 245)
        .padding(.bottom, 8)
    }

    private func commitInlineIfNeeded() {
        guard let openID = expandedCardID,
              let record = orderedFulfillments.first(where: { $0.category_id.uuidString == openID })
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
              let record = orderedFulfillments.first(where: { $0.category_id.uuidString == openID })
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
        lightColor: Color,
        record: Fulfillment
    ) -> some View {
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
                        if expandedCardID != nil {
                            expandedPreviousID = nil
                        }
                    }
                }

                if isExpanded {
                    let rolesForRecord = getRoles(for: record)
                    let rolesRows = rolesForRecord.count + ((isAddingRole || rolesForRecord.count < 3) ? 1 : 0)
                    let fociForRecord = getFoci(for: record)
                    let fociRows = fociForRecord.count + ((isAddingFocus || fociForRecord.count < 3) ? 1 : 0)
                    let resourcesForRecord = getResources(for: record)
                    let resourcesRows = resourcesForRecord.count + 1

                    VStack(alignment: .leading, spacing: 16) {
                    Text("Vision")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No vision yet." : record.category_vision)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    Button("Edit Vision") {
                        editingRecordID = record.category_id
                        editingText = record.category_vision
                        editingOriginalText = record.category_vision
                        isEditSheetTextFocused = false
                        editSheetCursorSeed &+= 1
                        editingField = .vision
                    }
                    .foregroundColor(.blue)

                    Text("Purpose")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "No purpose yet." : record.category_purpose)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    Button("Edit Purpose") {
                        editingRecordID = record.category_id
                        editingText = record.category_purpose
                        editingOriginalText = record.category_purpose
                        isEditSheetTextFocused = false
                        editSheetCursorSeed &+= 1
                        editingField = .purpose
                    }
                    .foregroundColor(.blue)

                    Text("Roles")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
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
                    .scrollDisabled(rolesRows <= 3)
                    .environment(\.editMode, .constant(.active))
                    .frame(minHeight: CGFloat(max(rolesRows, 1)) * 56, maxHeight: 220)

                    Text("Three-to-Thrive")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
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
                    .scrollDisabled(fociRows <= 3)
                    .environment(\.editMode, .constant(.active))
                    .frame(minHeight: CGFloat(max(fociRows, 1)) * 56, maxHeight: 220)

                    Text("Resources")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        ForEach(resourcesForRecord, id: \.id) { res in
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
                    .scrollDisabled(resourcesRows <= 4)
                    .environment(\.editMode, .constant(.active))
                    .frame(minHeight: CGFloat(max(resourcesRows, 1)) * 56, maxHeight: 260)

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
    }

    // MARK: - Completion Helpers
    private func batteryIconName(for record: Fulfillment) -> String {
        let count = completionCount(for: record)
        switch count {
        case 0: return "battery.0"
        case 1...2: return "battery.25"
        case 3...4: return "battery.50"
        case 5: return "battery.75"
        default: return "battery.100"
        }
    }

    private func completionCount(for record: Fulfillment) -> Int {
        let hasVision = !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRole = roles.contains { $0.category_id == record.category_id }
        let hasFocus = foci.contains { $0.category_id == record.category_id }
        let hasResource = resources.contains { $0.category_id == record.category_id }
        let passionIDs = Set(passions.map(\.passion_id))
        let hasPassion = passionJoins.contains { $0.category_id == record.category_id && passionIDs.contains($0.passion_id) }
        return [hasVision, hasPurpose, hasRole, hasFocus, hasResource, hasPassion].filter { $0 }.count
    }

    private var fulfillmentMetrics: [(String, Color, Double)] {
        orderedFulfillments.map { record in
            let title = record.category
            let pct = batteryPercentage(for: record)
            return (title, FulfillmentCategoryTheme.color(for: title), pct)
        }
    }

    private func batteryPercentage(for record: Fulfillment) -> Double {
        let count = completionCount(for: record)
        switch count {
        case 0: return 0
        case 1...2: return 25
        case 3...4: return 50
        case 5: return 75
        default: return 100
        }
    }

    // MARK: - Data Helpers

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
    @Query(sort: \Fulfillment.updatedAt, order: .forward) private var fulfillments: [Fulfillment]
    private let months = ["Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec"]
    private var categoryTitles: [String] {
        let titles = fulfillments.map(\.category)
            .filter { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        if titles.isEmpty {
            return defaultFulfillmentCategoryTitles
        }
        return Array(Set(titles)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }
    private var rows: [FulfillmentTrendRow] {
        buildRows(categoryTitles: categoryTitles, months: months)
    }
    private var categoryRange: [Color] {
        categoryTitles.map { FulfillmentCategoryTheme.color(for: $0) }
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
                .chartForegroundStyleScale(domain: categoryTitles, range: categoryRange)
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

    private func buildRows(categoryTitles: [String], months: [String]) -> [FulfillmentTrendRow] {
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

struct FulfillmentInteractiveRadar: View {
    let metrics: [(String, Color, Double)]
    @Binding var selectedIndex: Int
    let onManualSelect: () -> Void
    let enableInteraction: Bool
    let useOriginalDotStyle: Bool
    let customDotDiameter: CGFloat?
    let showOutline: Bool
    let emphasizeSelectedSlice: Bool
    @State private var pulseIndex: Int? = nil

    init(
        metrics: [(String, Color, Double)],
        selectedIndex: Binding<Int>,
        onManualSelect: @escaping () -> Void,
        enableInteraction: Bool = true,
        useOriginalDotStyle: Bool = false,
        customDotDiameter: CGFloat? = nil,
        showOutline: Bool = true,
        emphasizeSelectedSlice: Bool = true
    ) {
        self.metrics = metrics
        self._selectedIndex = selectedIndex
        self.onManualSelect = onManualSelect
        self.enableInteraction = enableInteraction
        self.useOriginalDotStyle = useOriginalDotStyle
        self.customDotDiameter = customDotDiameter
        self.showOutline = showOutline
        self.emphasizeSelectedSlice = emphasizeSelectedSlice
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let count = metrics.count

            if count == 0 {
                Color.clear
            } else {
                let safeSelectedIndex = min(max(0, selectedIndex), count - 1)
                let effectiveDotDiameter: CGFloat = customDotDiameter ?? (useOriginalDotStyle ? 14 : 20)
                let dotShadowRadius: CGFloat = useOriginalDotStyle ? 7 : max(5, effectiveDotDiameter * 0.5)

                let outerPoints: [CGPoint] = (0..<count).map { i in
                    let angle = Angle.degrees((Double(i) / Double(count)) * 360 - 90).radians
                    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }

                let renderedMetrics: [(String, Color, Double)] = (0..<count).map { i in
                    (metrics[i].0, segmentColor(i, selectedIndex: safeSelectedIndex), metrics[i].2)
                }
                let valuePoints: [CGPoint] = (0..<count).map { i in
                    let ratio = max(0.2, min(metrics[i].2 / 100.0, 1.0))
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
                        showOutline: showOutline,
                        dotDiameter: effectiveDotDiameter,
                        showDotOutline: false,
                        showDotShadow: false
                    )

                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(metrics[i].1)
                            .frame(width: effectiveDotDiameter, height: effectiveDotDiameter)
                            .overlay(
                                Circle().stroke(Color(.systemBackground), lineWidth: 2)
                            )
                            .shadow(color: Color(.systemBackground).opacity(0.9), radius: dotShadowRadius, x: 0, y: 0)
                            .scaleEffect((useOriginalDotStyle || !emphasizeSelectedSlice) ? 1 : circleScale(for: i, selectedIndex: safeSelectedIndex))
                            .animation(.easeInOut(duration: 0.18), value: pulseIndex)
                            .animation(.easeInOut(duration: 0.18), value: selectedIndex)
                            .position(valuePoints[i])
                    }

                    if enableInteraction {
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
        }
    }

    private func segmentColor(_ index: Int, selectedIndex: Int) -> Color {
        guard emphasizeSelectedSlice else { return metrics[index].1 }
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

    private func circleScale(for index: Int, selectedIndex: Int) -> CGFloat {
        if pulseIndex == index { return 1.35 }
        if selectedIndex == index { return 1.20 }
        return 1.0
    }
}

#if canImport(UIKit)
private struct FulfillmentEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FulfillmentEditorTextView
        var lastCursorSeed: Int = -1

        init(parent: FulfillmentEditorTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = context.coordinator
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            if context.coordinator.lastCursorSeed != cursorSeed {
                uiView.selectedRange = NSRange(location: (uiView.text as NSString).length, length: 0)
                context.coordinator.lastCursorSeed = cursorSeed
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}
#else
private struct FulfillmentEditorTextView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    var body: some View {
        TextEditor(text: $text)
    }
}
#endif
