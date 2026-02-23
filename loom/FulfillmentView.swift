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

fileprivate let defaultFulfillmentCategoryTitles: [String] = [
    "Area 1", "Area 2", "Area 3", "Area 4", "Area 5", "Area 6"
]

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
                        Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
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
                                    Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
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

    private func displayEmotionLabel(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "just": return "Hate"
        case "vows": return "Vow"
        default: return raw.capitalized
        }
    }
}

struct FulfillmentView: View {
    private struct LittleWinsManagerTarget: Identifiable {
        let id: UUID
        let categoryTitle: String
    }
    private struct LittleWinsEditorTarget: Identifiable {
        let categoryID: UUID
        let categoryTitle: String
        let focusID: UUID?
        let autoFocus: Bool

        var id: String {
            if let focusID { return "edit-\(focusID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

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
    @State private var showRecoverPreviousAlert = false
    @State private var recoverPreviousAlertMessage = ""
    @State private var pendingRecoverPrevious: ReplacedFulfillmentCategoryArchive?
    @State private var showRecoverColorPicker = false
    @State private var recoverColorOptions: [String] = []
    @State private var selectedRecoverColorKey: String = ""
    @State private var expandedPreviousID: UUID? = nil
    @State private var isAddingRole = false
    @State private var newRoleText = ""
    @State private var isAddingFocus = false
    @State private var newFocusText = ""
    @State private var isAddingResource = false
    @State private var newResourceText = ""
    @State private var visionDrafts: [UUID: String] = [:]
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var isShowingInstructions = false
    @State private var highlightedCategoryIndex: Int = 0
    @State private var radarAutoRotatePausedUntil: Date = .distantPast
    @State private var littleWinsManagerTarget: LittleWinsManagerTarget?
    @State private var littleWinsEditorTarget: LittleWinsEditorTarget?
    @State private var littleWinsScheduleStoreRevision = 0
    @FocusState private var focusedField: Field?
    @FocusState private var focusedVisionCategoryID: UUID?
    @FocusState private var focusedPurposeCategoryID: UUID?
    private enum Field { case role, focus, resource }
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

    private var isAnyLittleWinsSheetPresented: Bool {
        littleWinsManagerTarget != nil || littleWinsEditorTarget != nil
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
            if !isAnyLittleWinsSheetPresented {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer(minLength: 0)
                    Button("Done") {
                        commitVisionDraft(for: focusedVisionCategoryID)
                        commitPurposeDraft(for: focusedPurposeCategoryID)
                        focusedVisionCategoryID = nil
                        focusedPurposeCategoryID = nil
                        focusedField = nil
                    }
                }
            }
        }
        .onChange(of: focusedField) { _, new in
            commitInlineExcluding(new)
        }
        .onChange(of: focusedVisionCategoryID) { old, _ in
            commitVisionDraft(for: old)
        }
        .onChange(of: focusedPurposeCategoryID) { old, _ in
            commitPurposeDraft(for: old)
        }
        .onReceive(radarTimer) { _ in
            guard !orderedFulfillments.isEmpty else { return }
            guard Date() >= radarAutoRotatePausedUntil else { return }
            if highlightedCategoryIndex >= orderedFulfillments.count { highlightedCategoryIndex = 0 }
            highlightedCategoryIndex = (highlightedCategoryIndex + 1) % orderedFulfillments.count
        }
        .onReceive(NotificationCenter.default.publisher(for: .littleWinsScheduleDidChange)) { _ in
            littleWinsScheduleStoreRevision &+= 1
        }
        .sheet(isPresented: $isShowingInstructions) {
            fulfillmentInstructionsSheet()
        }
        .sheet(item: $littleWinsManagerTarget) { target in
            LittleWinsManagerSheetView(categoryID: target.id, categoryTitle: target.categoryTitle)
        }
        .sheet(item: $littleWinsEditorTarget) { target in
            LittleWinEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                focusID: target.focusID,
                autoFocusTextField: target.autoFocus
            )
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
        .alert("Can't Recover Area", isPresented: $showRecoverPreviousAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recoverPreviousAlertMessage)
        }
        .sheet(isPresented: $showRecoverColorPicker) {
            NavigationStack {
                List {
                    ForEach(recoverColorOptions, id: \.self) { key in
                        Button {
                            selectedRecoverColorKey = key
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(FulfillmentCategoryTheme.color(forKey: key))
                                    .frame(width: 16, height: 16)
                                Text(FulfillmentCategoryTheme.palette.first(where: { $0.key == key })?.name ?? key.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedRecoverColorKey == key {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Select New Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showRecoverColorPicker = false
                            pendingRecoverPrevious = nil
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Recover") {
                            guard let archive = pendingRecoverPrevious else { return }
                            recoverPreviousCategory(archive, colorOverride: selectedRecoverColorKey)
                            showRecoverColorPicker = false
                            pendingRecoverPrevious = nil
                        }
                        .disabled(selectedRecoverColorKey.isEmpty)
                    }
                }
            }
            .presentationDetents([
                .height(min(420, max(200, 130 + CGFloat(recoverColorOptions.count) * 52)))
            ])
            .presentationDragIndicator(.visible)
        }
    }

    private var previousCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
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
                            Text("Previous Areas")
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
                }

                Spacer(minLength: 0)

                NavigationLink {
                    ManageFulfillmentCategoriesView()
                } label: {
                    Text("Manage Fulfillment Areas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            if !replacedCategoryArchives.isEmpty, showPreviousCategories {
                ForEach(replacedCategoryArchives, id: \.id) { archive in
                    previousCategoryCard(archive)
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
                    Text("→ Manage Fulfillment Areas")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                fulfillmentInstructionSectionTitle("Set Fulfillment Areas")
                fulfillmentInstructionBody("Design the most important areas of your life.")
                fulfillmentInstructionBody("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                fulfillmentInstructionBody("They're never finished. You continually improve them to stay moving forward.")

                fulfillmentInstructionSectionTitle("Create Categories")
                fulfillmentInstructionBody("What 3-7 areas of your life must you consistently improve to succeed?")
                fulfillmentInstructionLabel("Need help?")
                fulfillmentInstructionBody("Fulfillment Areas are the key parts of your life you continually strengthen and maintain.")
                fulfillmentInstructionBody("They are not one-time goals. When these areas are strong, life feels stable and balanced. When neglected, progress in other areas becomes harder.")
                fulfillmentInstructionBody("Every action you take will connect to one of these areas, helping you focus on what truly matters instead of reacting to what feels urgent.")
                fulfillmentInstructionBody("Start simple. You can refine or change them anytime.")

                fulfillmentInstructionSectionTitle("Define Vision")
                fulfillmentInstructionBody("What does your ideal life look like in this area?")
                fulfillmentInstructionLabel("Need ideas?")
                fulfillmentInstructionBody("This is not a goal. It’s the long-term direction you want in this area.")
                fulfillmentInstructionBody("Focus on how your life feels, how you show up, and what success looks like.")
                fulfillmentInstructionBody("You can refine this anytime. Start simple.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "I am healthy, energized, and strong, with habits that support long-term vitality and resilience.",
                    "I feel calm, focused, and in control of this area, which allows me to show up fully in the rest of my life.",
                    "I consistently grow and improve, creating stability, balance, and confidence in this area.",
                    "I experience freedom and momentum here, knowing I’m building a strong foundation for my future.",
                    "This area of my life supports my happiness, creativity, and overall sense of fulfillment."
                ])

                fulfillmentInstructionSectionTitle("Define Purpose")
                fulfillmentInstructionBody("Why does improving this area truly matter?")
                fulfillmentInstructionLabel("Need ideas?")
                fulfillmentInstructionBody("Purpose is your deeper reason. It keeps you consistent when motivation fades.")
                fulfillmentInstructionBody("Think about why this matters and how your life improves when this area strengthens. When strong, everything feels easier.")
                fulfillmentInstructionBody("You can refine this anytime. Start simple.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "This fuels my energy and confidence so I can show up fully every day.",
                    "This gives me stability and peace of mind instead of constant stress.",
                    "Success here creates freedom and momentum across the rest of my life.",
                    "I want to feel proud of who I am in this area.",
                    "Neglecting this always leads to bigger problems later, so it’s a must.",
                    "This helps me feel grounded, focused, and fulfilled instead of reactive."
                ])

                fulfillmentInstructionSectionTitle("Identify Roles")
                fulfillmentInstructionBody("Who do you want to be in this area of your life?")
                fulfillmentInstructionLabel("Need help?")
                fulfillmentInstructionBody("Roles define your identity.")
                fulfillmentInstructionBody("They guide how you think, act, and make decisions before results show up. Instead of focusing only on goals, focus on the person who naturally creates those outcomes.")
                fulfillmentInstructionBody("Choose identities that feel empowering and motivating. These should reflect the best version of yourself in this area.")
                fulfillmentInstructionBody("You can update these anytime as you evolve.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Athlete",
                    "Wealth Builder",
                    "Focused Student",
                    "Loving Partner",
                    "Empowering Leader",
                    "Energized Creator",
                    "Community Contributor",
                    "Prayer Warrior"
                ])

                fulfillmentInstructionSectionTitle("Choose Your Focus")
                fulfillmentInstructionBody("Which areas would improve your life the most right now?")
                fulfillmentInstructionBody("Choose 1 or more areas than need increased focus.")

                fulfillmentInstructionSectionTitle("List Little Wins")
                fulfillmentInstructionBody("What small, repeatable wins can move this area forward?")
                fulfillmentInstructionLabel("Need Help?")
                fulfillmentInstructionBody("Small actions create momentum.")
                fulfillmentInstructionBody("Focus on a few easy, high-impact 1-3 actions you can do consistently.")
                fulfillmentInstructionBody("These should be simple enough that you can follow through even on busy or low-energy days.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Stretch or walk",
                    "Pray or journal",
                    "Review budget",
                    "Call loved one",
                    "Read for 10 min"
                ])

                fulfillmentInstructionSectionTitle("Note Resources")
                fulfillmentInstructionBody("What people, tools, or environments can help you improve this area?")
                fulfillmentInstructionLabel("Need Help?")
                fulfillmentInstructionBody("Strong support makes success easier.")
                fulfillmentInstructionBody("Focus on 1–3 people, tools, or environments that support consistent growth.")
                fulfillmentInstructionBody("Choose resources that reduce friction and make the right behavior more automatic.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Great gym",
                    "Accountability partner",
                    "Mentor or coach",
                    "Budgeting app",
                    "Supportive community",
                    "Quiet workspace",
                    "State park nearby"
                ])

                fulfillmentInstructionSectionTitle("Passions")
                fulfillmentInstructionBody("What passions drive you to improve this area?")

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

                    HStack {
                        Button("Recover") {
                            handleRecoverTapped(for: archive)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .opacity(recoverButtonOpacity(for: archive))

                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            pendingDeletePrevious = archive
                            showDeletePreviousAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
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

    private func recoverPreviousCategory(_ archive: ReplacedFulfillmentCategoryArchive, colorOverride: String? = nil) {
        switch recoverEligibility(for: archive, colorOverride: colorOverride) {
        case .allowed:
            break
        case .needsColorSelection(let available):
            pendingRecoverPrevious = archive
            recoverColorOptions = available
            selectedRecoverColorKey = available.first ?? ""
            showRecoverColorPicker = true
            return
        case .blocked(let message):
            recoverPreviousAlertMessage = message
            showRecoverPreviousAlert = true
            return
        }

        let restored = Fulfillment(
            category_id: archive.category_id,
            updatedAt: .now,
            category: archive.category,
            category_identitiy: archive.category_identitiy,
            category_vision: archive.category_vision,
            category_purpose: archive.category_purpose
        )
        modelContext.insert(restored)

        let roleValues = csvItems(from: archive.rolesCSV)
        for (idx, value) in roleValues.enumerated() {
            modelContext.insert(
                FulfillmentRoles(
                    category_id: archive.category_id,
                    role: value,
                    rank: idx
                )
            )
        }

        let focusValues = csvItems(from: archive.fociCSV)
        for (idx, value) in focusValues.enumerated() {
            modelContext.insert(
                FulfillmentFocus(
                    category_id: archive.category_id,
                    activity: value,
                    rank: idx
                )
            )
        }

        let resourceValues = csvItems(from: archive.resourcesCSV)
        for (idx, value) in resourceValues.enumerated() {
            modelContext.insert(
                FulfillmentResources(
                    category_id: archive.category_id,
                    resource: value,
                    rank: idx
                )
            )
        }

        let desiredPassionKeys = Set(csvItems(from: archive.passionsCSV).map(normalizedPassionKey))
        if !desiredPassionKeys.isEmpty {
            var existingJoinPassionIDs = Set(
                passionJoins
                    .filter { $0.category_id == archive.category_id }
                    .map(\.passion_id)
            )
            for passion in passions {
                let raw = normalizedPassionKey(passion.emotion)
                if desiredPassionKeys.contains(raw) {
                    if !existingJoinPassionIDs.contains(passion.passion_id) {
                        modelContext.insert(
                            PassionFulfillmentJoin(
                                passion_id: passion.passion_id,
                                category_id: archive.category_id
                            )
                        )
                        existingJoinPassionIDs.insert(passion.passion_id)
                    }
                }
            }
        }

        var colorMap = FulfillmentCategoryTheme.persistedColorKeys()
        let restoredColorKey = colorOverride ?? FulfillmentCategoryTheme.colorKey(for: archive.category, colorKeys: colorMap)
        colorMap[archive.category] = restoredColorKey
        FulfillmentCategoryTheme.persistColorKeys(colorMap)

        if expandedPreviousID == archive.id {
            expandedPreviousID = nil
        }
        modelContext.delete(archive)
        try? modelContext.save()
    }

    private enum RecoverEligibility {
        case allowed
        case needsColorSelection([String])
        case blocked(String)
    }

    private func recoverEligibility(for archive: ReplacedFulfillmentCategoryArchive, colorOverride: String? = nil) -> RecoverEligibility {
        if fulfillments.contains(where: { $0.category_id == archive.category_id }) {
            return .blocked("An active area with this identity already exists.")
        }

        let activeCategoryKeys = Set(
            fulfillments
                .map { categoryKey($0.category) }
                .filter { !$0.isEmpty }
        )

        if activeCategoryKeys.count > 6 {
            return .blocked("Recovery is only available when there are 6 or fewer active areas.")
        }

        let archiveCategoryKey = categoryKey(archive.category)
        if !archiveCategoryKey.isEmpty && activeCategoryKeys.contains(archiveCategoryKey) {
            return .blocked("An active area with this name already exists.")
        }

        let colorMap = FulfillmentCategoryTheme.persistedColorKeys()
        let usedColorKeys = Set(
            fulfillments.map { FulfillmentCategoryTheme.colorKey(for: $0.category, colorKeys: colorMap) }
        )
        let desiredColorKey = colorOverride ?? FulfillmentCategoryTheme.colorKey(for: archive.category, colorKeys: colorMap)
        let hasColorConflict = usedColorKeys.contains(desiredColorKey)
        if hasColorConflict {
            let available = FulfillmentCategoryTheme.palette.map(\.key).filter { !usedColorKeys.contains($0) }
            if available.isEmpty {
                return .blocked("No colors are available. Free up a color in active areas, then try again.")
            }
            return .needsColorSelection(available)
        }
        return .allowed
    }

    private func handleRecoverTapped(for archive: ReplacedFulfillmentCategoryArchive) {
        switch recoverEligibility(for: archive) {
        case .allowed:
            recoverPreviousCategory(archive)
        case .needsColorSelection(let available):
            pendingRecoverPrevious = archive
            recoverColorOptions = available
            selectedRecoverColorKey = available.first ?? ""
            showRecoverColorPicker = true
        case .blocked(let message):
            recoverPreviousAlertMessage = message
            showRecoverPreviousAlert = true
        }
    }

    private func isRecoverBlocked(for archive: ReplacedFulfillmentCategoryArchive) -> Bool {
        if case .blocked = recoverEligibility(for: archive) {
            return true
        }
        return false
    }

    private func recoverButtonOpacity(for archive: ReplacedFulfillmentCategoryArchive) -> Double {
        isRecoverBlocked(for: archive) ? 0.45 : 1.0
    }

    private func normalizedPassionKey(_ raw: String) -> String {
        let prefix = raw
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? raw
        let key = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "just", "hate": return "hate"
        case "vows", "vow": return "vow"
        default: return key
        }
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
                        Text("• Little Wins consistency")
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
                    let showsRoleInputRow = isAddingRole || rolesForRecord.count < 3
                    let fociForRecord = getFoci(for: record)
                    let resourcesForRecord = getResources(for: record)
                    let rolesContentHeight = estimatedListContentHeight(
                        items: rolesForRecord.map(\.role),
                        hasInputRow: showsRoleInputRow
                    )
                    let resourcesContentHeight = estimatedListContentHeight(
                        items: resourcesForRecord.map(\.resource),
                        hasInputRow: true
                    )

                    VStack(alignment: .leading, spacing: 16) {
                    Text("Vision")
                        .font(.headline)
                        .foregroundColor(.black)
                    TextEditor(text: visionBinding(for: record))
                        .focused($focusedVisionCategoryID, equals: record.category_id)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Purpose")
                        .font(.headline)
                        .foregroundColor(.black)
                    TextEditor(text: purposeBinding(for: record))
                        .focused($focusedPurposeCategoryID, equals: record.category_id)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Roles")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        ForEach(getRoles(for: record), id: \.id) { r in
                            Text(r.role)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
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
                    .scrollDisabled(rolesContentHeight <= 220)
                    .environment(\.editMode, .constant(.active))
                    .frame(height: min(rolesContentHeight, 220))

                    Text("Little Wins")
                        .font(.headline)
                        .foregroundColor(.black)
                    VStack(spacing: 0) {
                        Button {
                            if fociForRecord.isEmpty {
                                presentLittleWinsEditorForNew(record: record)
                            } else {
                                presentLittleWinsManager(for: record)
                            }
                        } label: {
                            HStack {
                                Text(fociForRecord.isEmpty ? "Add Little Win" : "Manage Little Wins")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)

                        if !fociForRecord.isEmpty {
                            Divider()
                            ForEach(Array(fociForRecord.enumerated()), id: \.element.id) { index, f in
                                Button {
                                    presentLittleWinsEditor(for: f, categoryTitle: record.category)
                                } label: {
                                    HStack(spacing: 0) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(f.activity)
                                                .foregroundStyle(.primary)
                                                .lineLimit(nil)
                                                .fixedSize(horizontal: false, vertical: true)
                                            let summary = activeWeekdaySummary(for: f)
                                            if summary != "Any day" {
                                                Text(summary)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .contentShape(Rectangle())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)

                                if index < fociForRecord.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    )

                    Text("Resources")
                        .font(.headline)
                        .foregroundColor(.black)
                    List {
                        ForEach(resourcesForRecord, id: \.id) { res in
                            Text(res.resource)
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)
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
                    .scrollDisabled(resourcesContentHeight <= 260)
                    .environment(\.editMode, .constant(.active))
                    .frame(height: min(resourcesContentHeight, 260))

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

    private func estimatedListContentHeight(items: [String], hasInputRow: Bool) -> CGFloat {
        let textRowsHeight = items.reduce(CGFloat.zero) { partial, item in
            partial + estimatedListTextRowHeight(item)
        }
        let inputRowHeight: CGFloat = hasInputRow ? 52 : 0
        // Keep one row visible even when there are no items yet.
        return max(textRowsHeight + inputRowHeight, 56)
    }

    private func estimatedListTextRowHeight(_ text: String) -> CGFloat {
        let measured = estimatedTextHeight(for: text, width: 220)
        // Includes row insets and room for edit controls.
        return max(56, measured + 26)
    }

    private func estimatedTextHeight(for text: String, width: CGFloat) -> CGFloat {
#if canImport(UIKit)
        let font = UIFont.preferredFont(forTextStyle: .body)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(rect.height)
#else
        _ = text
        _ = width
        return 20
#endif
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

    private func visionBinding(for record: Fulfillment) -> Binding<String> {
        Binding(
            get: { visionDrafts[record.category_id] ?? record.category_vision },
            set: { newValue in
                visionDrafts[record.category_id] = newValue
            }
        )
    }

    private func purposeBinding(for record: Fulfillment) -> Binding<String> {
        Binding(
            get: { purposeDrafts[record.category_id] ?? record.category_purpose },
            set: { newValue in
                purposeDrafts[record.category_id] = newValue
            }
        )
    }

    private func commitVisionDraft(for categoryID: UUID?) {
        guard let categoryID,
              let draft = visionDrafts[categoryID],
              let record = fulfillments.first(where: { $0.category_id == categoryID })
        else { return }
        updateVision(record: record, newText: draft)
        visionDrafts[categoryID] = record.category_vision
    }

    private func commitPurposeDraft(for categoryID: UUID?) {
        guard let categoryID,
              let draft = purposeDrafts[categoryID],
              let record = fulfillments.first(where: { $0.category_id == categoryID })
        else { return }
        updatePurpose(record: record, newText: draft)
        purposeDrafts[categoryID] = record.category_purpose
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

    private func activeWeekdaySummary(for focus: FulfillmentFocus) -> String {
        _ = littleWinsScheduleStoreRevision
        let rule = LittleWinsScheduleStore.rule(for: focus.id)
        if rule.canCompleteAnyDay { return "Any day" }
        let normalizedMask = rule.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = labels.enumerated().compactMap { index, label in
            (normalizedMask & (1 << index)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func presentLittleWinsManager(for record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsManagerTarget(id: record.category_id, categoryTitle: record.category)
        DispatchQueue.main.async {
            littleWinsManagerTarget = target
        }
    }

    private func presentLittleWinsEditorForNew(record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsEditorTarget(
            categoryID: record.category_id,
            categoryTitle: record.category,
            focusID: nil,
            autoFocus: true
        )
        DispatchQueue.main.async {
            littleWinsEditorTarget = target
        }
    }

    private func presentLittleWinsEditor(for focus: FulfillmentFocus, categoryTitle: String) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsEditorTarget(
            categoryID: focus.category_id,
            categoryTitle: categoryTitle,
            focusID: focus.id,
            autoFocus: false
        )
        DispatchQueue.main.async {
            littleWinsEditorTarget = target
        }
    }

    private func prepareForLittleWinsSheetPresentation() {
        commitInlineIfNeeded()
        commitVisionDraft(for: focusedVisionCategoryID)
        commitPurposeDraft(for: focusedPurposeCategoryID)
        focusedField = nil
        focusedVisionCategoryID = nil
        focusedPurposeCategoryID = nil
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
            LittleWinsScheduleStore.removeRule(for: f.id)
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

private struct LittleWinsManagerSheetView: View {
    private struct EditorTarget: Identifiable {
        let focusID: UUID?
        let categoryID: UUID
        let categoryTitle: String
        let autoFocus: Bool

        var id: String {
            if let focusID { return "edit-\(focusID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    let categoryID: UUID
    let categoryTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var foci: [FulfillmentFocus]

    @State private var isDeleteMode = false
    @State private var selectedIDsForDelete: Set<UUID> = []
    @State private var editorTarget: EditorTarget?

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    private var littleWins: [FulfillmentFocus] {
        foci.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !isDeleteMode && littleWins.count < 3 {
                        Button {
                            startCreatingNew()
                        } label: {
                            HStack {
                                Text("Add Little Win")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    ForEach(littleWins, id: \.id) { focus in
                        Button {
                            guard !isDeleteMode else {
                                toggleDeleteSelection(for: focus.id)
                                return
                            }
                            beginEditing(focus)
                        } label: {
                            HStack(spacing: 10) {
                                if isDeleteMode {
                                    Image(systemName: selectedIDsForDelete.contains(focus.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDsForDelete.contains(focus.id) ? .red : .secondary)
                                }
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(focus.activity)
                                        .foregroundStyle(.primary)
                                    let summary = weekdaySummary(for: LittleWinsScheduleStore.rule(for: focus.id))
                                    if summary != "Any day" {
                                        Text(summary)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                Spacer()
                                if !isDeleteMode {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Little Wins")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isDeleteMode)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isDeleteMode {
                        Button("Cancel") {
                            isDeleteMode = false
                            selectedIDsForDelete.removeAll()
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isDeleteMode {
                        Button("Delete") { deleteSelected() }
                            .foregroundStyle(selectedIDsForDelete.isEmpty ? Color.secondary : Color.red)
                            .disabled(selectedIDsForDelete.isEmpty)
                    } else if !littleWins.isEmpty {
                        Button("Edit") {
                            isDeleteMode = true
                            selectedIDsForDelete.removeAll()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editorTarget) { target in
            LittleWinEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                focusID: target.focusID,
                autoFocusTextField: target.autoFocus
            )
        }
    }

    private func beginEditing(_ focus: FulfillmentFocus) {
        editorTarget = .init(
            focusID: focus.id,
            categoryID: categoryID,
            categoryTitle: categoryTitle,
            autoFocus: false
        )
    }

    private func startCreatingNew() {
        guard littleWins.count < 3 else { return }
        editorTarget = .init(
            focusID: nil,
            categoryID: categoryID,
            categoryTitle: categoryTitle,
            autoFocus: true
        )
    }

    private func toggleDeleteSelection(for id: UUID) {
        if selectedIDsForDelete.contains(id) {
            selectedIDsForDelete.remove(id)
        } else {
            selectedIDsForDelete.insert(id)
        }
    }

    private func weekdaySummary(for rule: LittleWinsScheduleRule) -> String {
        let normalized = rule.normalized
        if normalized.canCompleteAnyDay { return "Any day" }
        let normalizedMask = normalized.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let selected = weekdayLabels.enumerated().compactMap { idx, label in
            (normalizedMask & (1 << idx)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func deleteSelected() {
        let targets = littleWins.filter { selectedIDsForDelete.contains($0.id) }
        for focus in targets {
            modelContext.insert(
                FulfillmentFocusArchive(
                    category_id: focus.category_id,
                    updatedAt: focus.updatedAt,
                    activity: focus.activity,
                    rank: focus.rank,
                    archivedAt: Date()
                )
            )
            LittleWinsScheduleStore.removeRule(for: focus.id)
            RecentlyDeletedStore.trash(focus, in: modelContext)
        }
        try? modelContext.save()
        selectedIDsForDelete.removeAll()
        isDeleteMode = false
    }
}

struct LittleWinEditorSheetView: View {
    let categoryID: UUID
    let categoryTitle: String
    let focusID: UUID?
    let autoFocusTextField: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var foci: [FulfillmentFocus]

    @State private var draftText = ""
    @State private var draftCanAnyDay = true
    @State private var draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
    @State private var didHydrate = false
    @FocusState private var isTextFocused: Bool

    private let weekdayLetterLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var littleWins: [FulfillmentFocus] {
        foci.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private var editingFocus: FulfillmentFocus? {
        guard let focusID else { return nil }
        return foci.first { $0.id == focusID }
    }

    private var isEditing: Bool { focusID != nil }

    private var doneDisabled: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isEditing ? "Edit Little Win" : "New Little Win") {
                    TextField("yoga classes", text: $draftText)
                        .focused($isTextFocused)
                        .textInputAutocapitalization(.sentences)

                    HStack {
                        Text("Can be completed any day")
                        Spacer()
                        Menu {
                            Button("Yes") { setCanAnyDay(true) }
                            Button("No") { setCanAnyDay(false) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(draftCanAnyDay ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if !draftCanAnyDay {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                ForEach(Array(weekdayLetterLabels.enumerated()), id: \.offset) { index, label in
                                    let isSelected = (draftWeekdayMask & (1 << index)) != 0
                                    Button {
                                        toggleWeekday(index)
                                    } label: {
                                        Text(label)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .frame(width: 34, height: 34)
                                            .background(
                                                Circle()
                                                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(.separator).opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "Edit Little Win" : "Add Little Win")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .disabled(doneDisabled)
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            hydrateIfNeeded()
            guard autoFocusTextField else { return }
            DispatchQueue.main.async {
                isTextFocused = true
            }
        }
    }

    private func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        if let focus = editingFocus {
            let rule = LittleWinsScheduleStore.rule(for: focus.id)
            draftText = focus.activity
            draftCanAnyDay = rule.canCompleteAnyDay
            draftWeekdayMask = rule.activeWeekdayMask
        } else {
            draftText = ""
            draftCanAnyDay = true
            draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
        }
    }

    private func setCanAnyDay(_ value: Bool) {
        draftCanAnyDay = value
        if value {
            draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
        } else {
            draftWeekdayMask = 0
        }
    }

    private func toggleWeekday(_ index: Int) {
        let bit = 1 << index
        if (draftWeekdayMask & bit) != 0 {
            draftWeekdayMask &= ~bit
        } else {
            draftWeekdayMask |= bit
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var finalCanAnyDay = draftCanAnyDay
        var finalMask = draftWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if !finalCanAnyDay && finalMask == 0 {
            finalCanAnyDay = true
            finalMask = LittleWinsScheduleRule.everyDayMask
        }
        if !finalCanAnyDay && finalMask == LittleWinsScheduleRule.everyDayMask {
            finalCanAnyDay = true
        }

        let rule = LittleWinsScheduleRule(canCompleteAnyDay: finalCanAnyDay, activeWeekdayMask: finalMask).normalized

        if let focus = editingFocus {
            if focus.activity != trimmed {
                modelContext.insert(
                    FulfillmentFocusArchive(
                        category_id: focus.category_id,
                        updatedAt: focus.updatedAt,
                        activity: focus.activity,
                        rank: focus.rank,
                        archivedAt: Date()
                    )
                )
                focus.activity = trimmed
                focus.updatedAt = Date()
            }
            LittleWinsScheduleStore.setRule(rule, for: focus.id)
        } else {
            guard littleWins.count < 3 else { return }
            let nextRank = (littleWins.map(\.rank).max() ?? 0) + 1
            let focus = FulfillmentFocus(category_id: categoryID, activity: trimmed, rank: nextRank)
            modelContext.insert(focus)
            LittleWinsScheduleStore.setRule(rule, for: focus.id)
        }

        try? modelContext.save()
        dismiss()
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
    private static let fallbackMetrics: [(String, Color, Double)] = [
        ("Area 1", FulfillmentCategoryTheme.color(for: "Career & Business"), 20),
        ("Area 2", FulfillmentCategoryTheme.color(for: "Leadership & Impact"), 20),
        ("Area 3", FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"), 20),
        ("Area 4", FulfillmentCategoryTheme.color(for: "Mind & Meaning"), 20),
        ("Area 5", FulfillmentCategoryTheme.color(for: "Love & Relationships"), 20),
        ("Area 6", FulfillmentCategoryTheme.color(for: "Health & Vitality"), 20),
    ]

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
        self.metrics = metrics.isEmpty ? Self.fallbackMetrics : metrics
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
