import SwiftUI
import SwiftData
import UIKit

fileprivate struct FulfillmentStartCategoryDef: Identifiable {
    let id: String
    let title: String
    let categoryID: UUID
}

fileprivate let fulfillmentStartDefaultCategoryDefs: [FulfillmentStartCategoryDef] = [
    .init(id: "career", title: "Career & Business", categoryID: PlanLabelSeeder.categoryIDs["Career & Business"]!),
    .init(id: "leadership", title: "Leadership & Impact", categoryID: PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
    .init(id: "wealth", title: "Wealth & Lifestyle", categoryID: PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
    .init(id: "mind", title: "Mind & Meaning", categoryID: PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
    .init(id: "love", title: "Love & Relationships", categoryID: PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
    .init(id: "health", title: "Health & Vitality", categoryID: PlanLabelSeeder.categoryIDs["Health & Vitality"]!),
]

fileprivate let fulfillmentStartSelectableDefaultCategories: [String] = [
    "Career & Business",
    "Faith & Spirituality",
    "Wealth & Finance",
    "Learning & Education",
    "Love & Relationships",
    "Health & Energy",
    "Lifestyle & Experiences",
    "Mindset & Resilience",
    "Service & Impact",
    "Home & Life"
]

struct FulfillmentStartView: View {
    private static let draftStorageKey = "fulfillment_start_onboarding_draft_v1"

    private struct DraftFulfillmentRow: Codable {
        var categoryID: UUID
        var updatedAt: Date
        var category: String
        var identity: String
        var vision: String
        var purpose: String
    }

    private struct DraftRoleRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var role: String
        var rank: Int
    }

    private struct DraftFocusRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var activity: String
        var rank: Int
    }

    private struct DraftResourceRow: Codable {
        var id: UUID
        var categoryID: UUID
        var updatedAt: Date
        var resource: String
        var rank: Int
    }

    private struct DraftPassionJoinRow: Codable {
        var id: UUID
        var passionID: UUID
        var categoryID: UUID
    }

    private struct DraftState: Codable {
        var stepRawValue: Int
        var visionIndex: Int
        var purposeIndex: Int
        var deepIndex: Int
        var priorityCategoryIDs: [UUID]
        var selectedCategoryNames: [String]
        var customCategoryNames: [String]
        var deletedDefaultCategoryNames: [String]
        var categoryColorKeys: [String: String]
        var visionDrafts: [String: String]
        var purposeDrafts: [String: String]
        var fulfillments: [DraftFulfillmentRow]
        var roles: [DraftRoleRow]
        var foci: [DraftFocusRow]
        var resources: [DraftResourceRow]
        var passionJoins: [DraftPassionJoinRow]
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var allPlannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var allPlannedActions: [PlannedChunkAction]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var allOutcomes: [Outcomes]
    @Query(sort: \PlanLabel.category, order: .forward) private var planLabels: [PlanLabel]

    @State private var navigateToFulfillment = false

    @State private var step: Step = .intro
    @State private var visionIndex: Int = 0
    @State private var purposeIndex: Int = 0
    @State private var priorityCategoryIDs: [UUID] = []
    @State private var deepIndex: Int = 0

    @State private var visionDrafts: [UUID: String] = [:]
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var fulfillmentSnapshot: [Fulfillment] = []
    @State private var roleEntry: String = ""
    @State private var focusEntry: String = ""
    @State private var resourceEntry: String = ""

    @State private var addingRole = false
    @State private var addingFocus = false
    @State private var addingResource = false
    @State private var addingCategory = false
    @State private var newCategoryText = ""
    @State private var selectedCategoryNames: [String] = []
    @State private var customCategoryNames: [String] = []
    @State private var deletedDefaultCategoryNames: Set<String> = []
    @State private var categoryColorKeys: [String: String] = [:]
    @State private var colorPickerCategory: String = ""
    @State private var showColorPicker = false

    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPurpose = false
    @State private var showNeedHelpCategories = false

    @State private var showValidationHint = false
    @State private var validationHintText = ""
    @State private var hintWorkItem: DispatchWorkItem?
    @State private var previousAutosaveEnabled: Bool = true
    @State private var didFinalizeOnboarding = false
    @State private var usesDraftPersistence = false
    @State private var highlightInvalid = false
    @State private var invalidCategoryIDs = Set<UUID>()

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case vision
        case purpose
        case role
        case focus
        case resource
    }

    private enum Step: Int, CaseIterable {
        case intro = 0
        case createCategories
        case visionSweep
        case purposeSweep
        case priorities
        case roles
        case threeToThrive
        case resources
        case passions
        case summary

        var title: String {
            switch self {
            case .intro: return "Set Fulfillment Areas"
            case .createCategories: return "Create Categories"
            case .visionSweep: return "Define Vision"
            case .purposeSweep: return "Define Purpose"
            case .priorities: return "Choose Your Focus"
            case .roles: return "Identify Roles"
            case .threeToThrive: return "List Little Wins"
            case .resources: return "Note Resources"
            case .passions: return "Passions"
            case .summary: return "Summary"
            }
        }
    }

    private var orderedFulfillments: [Fulfillment] {
        let baseRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        if !selectedCategoryNames.isEmpty {
            let all = baseRows
            let mapped = selectedCategoryNames.compactMap { selectedName in
                all.first { record in
                    categoryKey(record.category) == categoryKey(selectedName)
                }
            }
            if !mapped.isEmpty { return mapped }
        }
        var byID = Dictionary(uniqueKeysWithValues: baseRows.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        for def in fulfillmentStartDefaultCategoryDefs {
            if let row = byID.removeValue(forKey: def.categoryID) {
                ordered.append(row)
            }
        }
        ordered.append(contentsOf: byID.values.sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending })
        return ordered
    }

    private var currentVisionRecord: Fulfillment? {
        guard orderedFulfillments.indices.contains(visionIndex) else { return nil }
        return orderedFulfillments[visionIndex]
    }

    private var currentPurposeRecord: Fulfillment? {
        guard orderedFulfillments.indices.contains(purposeIndex) else { return nil }
        return orderedFulfillments[purposeIndex]
    }

    private var deepCategoryIDs: [UUID] {
        priorityCategoryIDs
    }

    private var currentDeepRecord: Fulfillment? {
        guard deepCategoryIDs.indices.contains(deepIndex) else { return nil }
        let categoryID = deepCategoryIDs[deepIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var progressCurrentStep: Int {
        switch step {
        case .createCategories: return 1
        case .visionSweep: return 2
        case .purposeSweep: return 3
        case .priorities: return 4
        case .roles: return 5
        case .threeToThrive: return 6
        case .resources: return 7
        case .passions: return 8
        case .summary: return 9
        case .intro: return 0
        }
    }

    private let progressTotalSteps: Int = 9

    private var editorSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var isScrollableStep: Bool {
        switch step {
        case .createCategories, .roles, .threeToThrive, .resources, .passions, .summary:
            return true
        default:
            return false
        }
    }

    private var isNextDisabled: Bool {
        switch step {
        case .createCategories:
            return !canStartOnboarding
        case .priorities:
            return !(2...3).contains(priorityCategoryIDs.count)
        case .threeToThrive:
            guard let record = currentDeepRecord else { return true }
            return getFoci(for: record).count != 3
        case .passions:
            guard let record = currentDeepRecord else { return true }
            return selectedPassions(for: record.category_id).isEmpty
        default:
            return false
        }
    }

    private var summaryCanComplete: Bool {
        guard !(orderedFulfillments.isEmpty) else { return false }
        guard (2...3).contains(priorityCategoryIDs.count) else { return false }
        for id in priorityCategoryIDs {
            guard let record = orderedFulfillments.first(where: { $0.category_id == id }) else { return false }
            if getFoci(for: record).count != 3 { return false }
            if selectedPassions(for: id).isEmpty { return false }
        }
        return true
    }

    private var canStartOnboarding: Bool {
        let names = selectedCategoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard (3...7).contains(names.count) else { return false }
        let uniqueCount = Set(names.map { $0.lowercased() }).count
        guard uniqueCount == names.count else { return false }
        return !hasCreateCategoriesColorConflict
    }

    private var conflictingSelectedCategories: Set<String> {
        var grouped: [String: [String]] = [:]
        for category in selectedCategoryNames {
            let colorKey = categoryColorKeys[category] ?? rotatedColorKey(for: category)
            grouped[colorKey, default: []].append(category)
        }
        let duplicates = grouped.values.filter { $0.count > 1 }.flatMap { $0 }
        return Set(duplicates)
    }

    private var hasCreateCategoriesColorConflict: Bool {
        !conflictingSelectedCategories.isEmpty
    }

    private var availableCategoryNames: [String] {
        let defaults = fulfillmentStartSelectableDefaultCategories.filter { !deletedDefaultCategoryNames.contains($0) }
        let custom = customCategoryNames.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        return defaults + custom
    }

    private var createCategoriesListHeight: CGFloat {
        let baseRows = availableCategoryNames.count + 1 // + custom row/input row
        let contentHeight = CGFloat(baseRows) * 56 + 14
        return contentHeight + 28
    }

    private var missingDefaultCategories: [String] {
        fulfillmentStartSelectableDefaultCategories.filter { defaultName in
            !availableCategoryNames.contains(where: { $0.caseInsensitiveCompare(defaultName) == .orderedSame })
        }
    }

    private var availableDefaultCategoryCount: Int {
        fulfillmentStartSelectableDefaultCategories.reduce(0) { count, defaultName in
            let exists = availableCategoryNames.contains(where: { $0.caseInsensitiveCompare(defaultName) == .orderedSame })
            return count + (exists ? 1 : 0)
        }
    }

    private var shouldShowRefreshButton: Bool {
        availableDefaultCategoryCount < fulfillmentStartSelectableDefaultCategories.count
    }

    private var onboardingColorCycleKeys: [String] {
        ["blue", "indigo", "green", "purple", "red", "orange"]
    }

    private func categoryKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let andNormalized = trimmed.replacingOccurrences(of: "&", with: " and ")
        let cleaned = andNormalized.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                if isScrollableStep {
                    ScrollView {
                        mainContent
                    }
                } else {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                if step == .createCategories, shouldShowRefreshButton {
                    Button("refresh") {
                        restoreDeletedDefaultCategories()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.gray)
                    .buttonStyle(.plain)
                    .frame(maxWidth: .infinity, alignment: .center)
                }

                footer
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step != .intro)
        .onAppear {
            previousAutosaveEnabled = modelContext.autosaveEnabled
            usesDraftPersistence = fulfillments.isEmpty
            modelContext.autosaveEnabled = usesDraftPersistence ? false : previousAutosaveEnabled
            if usesDraftPersistence, restoreDraftIfAvailable() {
                refreshFulfillmentSnapshot()
            } else {
                if !usesDraftPersistence {
                    clearDraft()
                }
                loadFromPersistentData()
            }
        }
        .onDisappear {
            if !didFinalizeOnboarding {
                persistDraft()
            }
            if usesDraftPersistence && !didFinalizeOnboarding {
                modelContext.rollback()
            }
            modelContext.autosaveEnabled = previousAutosaveEnabled
        }
        .onChange(of: step) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: visionIndex) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: purposeIndex) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: deepIndex) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: selectedCategoryNames) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: customCategoryNames) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: deletedDefaultCategoryNames) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: categoryColorKeys) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: priorityCategoryIDs) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: visionDrafts) { _, _ in
            persistDraftIfNeeded()
        }
        .onChange(of: purposeDrafts) { _, _ in
            persistDraftIfNeeded()
        }
        .navigationDestination(isPresented: $navigateToFulfillment) {
            FulfillmentView()
        }
        .overlay(alignment: .bottom) {
            let persistentColorConflict = step == .createCategories && hasCreateCategoriesColorConflict
            if persistentColorConflict || showValidationHint {
                Text(persistentColorConflict ? "Each color can only be used once." : validationHintText)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 56)
                    .transition(.opacity)
            }
        }
        .onChange(of: step) { _, newValue in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                switch newValue {
                case .visionSweep: focusedField = .vision
                case .purposeSweep: focusedField = .purpose
                case .roles: focusedField = addingRole ? .role : nil
                case .threeToThrive: focusedField = addingFocus ? .focus : nil
                case .resources: focusedField = addingResource ? .resource : nil
                default: focusedField = nil
                }
            }
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch step {
            case .intro:
                introStep
            case .createCategories:
                createCategoriesStep
            case .visionSweep:
                visionSweepStep
            case .purposeSweep:
                purposeSweepStep
            case .priorities:
                prioritiesStep
            case .roles:
                rolesStep
            case .threeToThrive:
                threeToThriveStep
            case .resources:
                resourcesStep
            case .passions:
                passionsStep
            case .summary:
                summaryStep
            }
        }
        .padding(.horizontal)
        .padding(.bottom, step == .summary ? 100 : 0)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(spacing: 1) {
            if step == .intro {
                ZStack {
                    FulfillmentIntroRouteLinesView()
                        .padding(.horizontal, -24)
                        .allowsHitTesting(false)
                    if let image = UIImage(named: "FulfillmentGraphic") {
                        Image(uiImage: image)
                            .renderingMode(.original)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 420)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(height: 420)
                .padding(.bottom, 2)
            }

            if step != .intro {
                progressStrip
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if step == .intro {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("~7 minutes")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }

            Text(step.title)
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var progressStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...progressTotalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= progressCurrentStep ? Color.accentColor : Color(.systemGray4))
                    .frame(maxWidth: .infinity)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity)
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button {
                    step = .createCategories
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            } else if step == .summary {
                Button {
                    step = .passions
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

                Button {
                    finalizeAndContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
                .disabled(!summaryCanComplete)
            } else {
                Button {
                    goBack()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .contentShape(Rectangle())
                }
                .foregroundStyle(Color.primary)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
                .buttonStyle(.plain)
                .overlay {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                }
                .frame(maxWidth: .infinity)

                Button {
                    if isNextDisabled {
                        triggerValidationFeedback()
                    } else {
                        highlightInvalid = false
                        invalidCategoryIDs = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Design the most important areas of your life.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("They're never finished. You continually improve them to stay moving forward.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("What 3-7 areas of your life must you consistently improve to succeed?")
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            List {
                ForEach(availableCategoryNames, id: \.self) { category in
                    let selected = selectedCategoryNames.contains(category)
                    let isConflicting = conflictingSelectedCategories.contains(category)
                    HStack(spacing: 8) {
                        Button {
                            colorPickerCategory = category
                            showColorPicker = true
                        } label: {
                            Circle()
                                .fill(fulfillmentCategoryColor(for: category))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            isConflicting ? Color.red : Color(.systemGray4),
                                            lineWidth: isConflicting ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)

                        Text(category)
                            .font(.system(size: 20))
                            .foregroundStyle(.primary)

                        Spacer()
                        if isConflicting {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }

                        Button {
                            toggleCategorySelection(category)
                        } label: {
                            Image(systemName: selected ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selected ? Color.blue : Color.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleCategorySelection(category)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        Button(role: .destructive) {
                            attemptRemoveCategoryFromStepList(category)
                        } label: {
                            Text("Delete")
                        }
                        .tint(.red)
                    }
                    .listRowBackground(rowSurfaceColor)
                }

                if addingCategory {
                    TextField("Custom Category", text: $newCategoryText)
                        .font(.system(size: 20))
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)
                        .onSubmit(addCategory)
                        .listRowBackground(rowSurfaceColor)
                } else {
                    Button("+ Custom Category") {
                        addingCategory = true
                        newCategoryText = ""
                    }
                    .font(.system(size: 20, weight: .regular))
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .listRowBackground(rowSurfaceColor)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .environment(\.defaultMinListRowHeight, 56)
            .frame(height: createCategoriesListHeight)
            .clipShape(RoundedRectangle(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedHelpCategories.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need help?")
                        Image(systemName: showNeedHelpCategories ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedHelpCategories {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Fulfillment Areas are the key parts of your life you continually strengthen and maintain.")
                        Text("They are not one-time goals. When these areas are strong, life feels stable and balanced. When neglected, progress in other areas becomes harder.")
                        Text("Every action you take will connect to one of these areas, helping you focus on what truly matters instead of reacting to what feels urgent.")
                        Text("Start simple. You can refine or change them anytime.")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        .sheet(isPresented: $showColorPicker) {
            FulfillmentStartColorPickerSheet(
                category: colorPickerCategory,
                currentColorKey: FulfillmentCategoryTheme.colorKey(for: colorPickerCategory, colorKeys: categoryColorKeys),
                onSelect: { colorKey in
                    applyColorSelection(for: colorPickerCategory, colorKey: colorKey)
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private var visionSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentVisionRecord {
                categoryHeader(record.category, index: visionIndex + 1, total: orderedFulfillments.count)
                Text("What does your ideal life look like in this area?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { visionDrafts[record.category_id] ?? record.category_vision },
                        set: { visionDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "One or two sentences..."
                )
                .focused($focusedField, equals: .vision)

                visionIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var purposeSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentPurposeRecord {
                categoryHeader(record.category, index: purposeIndex + 1, total: orderedFulfillments.count)
                Text("Why is success in this area an absolute must?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { purposeDrafts[record.category_id] ?? record.category_purpose },
                        set: { purposeDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "Short and emotional..."
                )
                .focused($focusedField, equals: .purpose)

                purposeIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var prioritiesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Which areas would improve your life the most right now?")
                .font(.headline)

            VStack(spacing: 8) {
                ForEach(orderedFulfillments, id: \.category_id) { record in
                    let selected = priorityCategoryIDs.contains(record.category_id)
                    Button {
                        togglePriority(record.category_id)
                    } label: {
                        HStack {
                            Text(record.category)
                                .foregroundStyle(.primary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 12)
                        .background(rowSurfaceColor, in: RoundedRectangle(cornerRadius: 10))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(selected ? Color.blue.opacity(0.6) : Color.clear, lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            Text("Selected: \(priorityCategoryIDs.count)")
                .font(.caption)
                .foregroundStyle((2...3).contains(priorityCategoryIDs.count) ? Color.secondary : Color.red)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("Who do you need to become in this area?")
                    .font(.headline)

                VStack(spacing: 0) {
                    if addingRole {
                        TextField("Add Role", text: $roleEntry)
                            .focused($focusedField, equals: .role)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .submitLabel(.done)
                            .onSubmit {
                                commitRole(record)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(rowSurfaceColor)
                    } else {
                        Button("+ Add Role") {
                            addingRole = true
                            roleEntry = ""
                            focusedField = .role
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowSurfaceColor)
                    }

                    ForEach(getRoles(for: record), id: \.id) { item in
                        HStack {
                            Text(item.role)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = getRoles(for: record).firstIndex(where: { $0.id == item.id }) {
                                    deleteRoles(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowSurfaceColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Skip for now") {
                    advanceFromCurrentStep()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var threeToThriveStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                threeToThriveContent(for: record)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func threeToThriveContent(for record: Fulfillment) -> some View {
        let fociItems = getFoci(for: record)
        let isInvalid = highlightInvalid && fociItems.count != 3
        let rowBackground = isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor

        categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
        Text("What small, repeatable wins will move this area forward?")
            .font(.headline)

        VStack(spacing: 0) {
            if addingFocus, fociItems.count < 3 {
                TextField("Add Focus Area", text: $focusEntry)
                    .focused($focusedField, equals: .focus)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit { commitFocus(record) }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(rowBackground)
            } else if fociItems.count < 3 {
                Button("+ Add Focus") {
                    addingFocus = true
                    focusEntry = ""
                    focusedField = .focus
                }
                .foregroundStyle(.blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(rowBackground)
            }

            ForEach(fociItems, id: \.id) { item in
                HStack {
                    Text(item.activity)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Button(role: .destructive) {
                        if let idx = fociItems.firstIndex(where: { $0.id == item.id }) {
                            deleteFoci(at: IndexSet(integer: idx), record: record)
                        }
                    } label: {
                        Image(systemName: "trash")
                    }
                    .buttonStyle(.plain)
                }
                .padding(.vertical, 10)
                .padding(.horizontal, 10)
                .background(rowBackground)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(isInvalid ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
        )

        Text("Exactly 3 required")
            .font(.caption)
            .foregroundStyle(fociItems.count == 3 ? Color.secondary : Color.red)
    }

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("Who and what can help you grow in this area?")
                    .font(.headline)

                Text("People • Tools • Communities • Knowledge")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                VStack(spacing: 0) {
                    if addingResource {
                        TextField("Add Resource", text: $resourceEntry)
                            .focused($focusedField, equals: .resource)
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .submitLabel(.done)
                            .onSubmit {
                                commitResource(record)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(rowSurfaceColor)
                    } else {
                        Button("+ Add Resource") {
                            addingResource = true
                            resourceEntry = ""
                            focusedField = .resource
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowSurfaceColor)
                    }

                    ForEach(getResources(for: record), id: \.id) { item in
                        HStack {
                            Text(item.resource)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = getResources(for: record).firstIndex(where: { $0.id == item.id }) {
                                    deleteResources(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowSurfaceColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Button("Skip for now") {
                    advanceFromCurrentStep()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("What passions drive you to improve this area?")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(passions, id: \.passion_id) { passion in
                        let isSelected = selectedPassionIDs(for: record.category_id).contains(passion.passion_id)
                        Button {
                            togglePassion(passion, for: record.category_id)
                        } label: {
                            HStack {
                                Text("\(passion.emotion.capitalized): \(passion.passion)")
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Spacer()
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .blue : .secondary)
                            }
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(
                                highlightInvalid && selectedPassions(for: record.category_id).isEmpty ? Color.red.opacity(0.08) : rowSurfaceColor
                            )
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                        .buttonStyle(.plain)
                    }
                }
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(highlightInvalid && selectedPassions(for: record.category_id).isEmpty ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )

                Text("At least 1 required")
                    .font(.caption)
                    .foregroundStyle(selectedPassions(for: record.category_id).isEmpty ? Color.red : Color.secondary)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "Categories", body: "\(orderedFulfillments.count) created") {
                step = .visionSweep
                visionIndex = 0
            }

            summaryCard(title: "Priority Categories", body: priorityCategoryNamesText) {
                step = .priorities
            }

            summaryCard(title: "Key Focus Areas", body: focusSummaryText) {
                step = .threeToThrive
                deepIndex = 0
            }

            summaryCard(title: "High-level Structure", body: structureSummaryText) {
                step = .roles
                deepIndex = 0
            }
        }
    }

    private var priorityCategoryNamesText: String {
        let names = priorityCategoryIDs.compactMap { id in
            orderedFulfillments.first(where: { $0.category_id == id })?.category
        }
        return names.isEmpty ? "None selected" : names.joined(separator: ", ")
    }

    private var focusSummaryText: String {
        var total = 0
        for id in priorityCategoryIDs {
            if let record = orderedFulfillments.first(where: { $0.category_id == id }) {
                total += getFoci(for: record).count
            }
        }
        return "\(total) focus areas defined"
    }

    private var structureSummaryText: String {
        var roleCount = 0
        var resourceCount = 0
        var passionCount = 0

        for id in priorityCategoryIDs {
            guard let record = orderedFulfillments.first(where: { $0.category_id == id }) else { continue }
            roleCount += getRoles(for: record).count
            resourceCount += getResources(for: record).count
            passionCount += selectedPassions(for: id).count
        }

        return "\(roleCount) roles • \(resourceCount) resources • \(passionCount) passion links"
    }

    private var visionIdeasExpander: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasVision.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need ideas?")
                    Image(systemName: showNeedIdeasVision ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasVision {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Keep it to 1–2 lines")
                    Text("• Focus on the future state")
                    Text("• Prioritize clarity over detail")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var purposeIdeasExpander: some View {
        VStack(alignment: .leading, spacing: 6) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasPurpose.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need ideas?")
                    Image(systemName: showNeedIdeasPurpose ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasPurpose {
                VStack(alignment: .leading, spacing: 6) {
                    Text("• Why this area matters deeply")
                    Text("• What it changes in your life")
                    Text("• Why it must happen")
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func categoryHeader(_ title: String, index: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
            Spacer(minLength: 8)
            Text("\(index)/\(max(total, 1))")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func phaseSubtext(_ text: String) -> some View {
        Text(text)
            .font(.caption)
            .foregroundStyle(.secondary)
    }

    private func summaryCard(title: String, body: String, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
            }
            Text(body)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func multiLineEditor(text: Binding<String>, placeholder: String, showError: Bool = false) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: 19))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .lineLimit(2...8)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 88, alignment: .topLeading)
            .background(editorSurfaceColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? Color.red.opacity(0.8) : Color(.separator).opacity(0.5), lineWidth: showError ? 1.6 : 1)
            )
    }

    // MARK: - Navigation

    private func goBack() {
        switch step {
        case .createCategories:
            step = .intro
        case .visionSweep:
            step = .createCategories
        case .purposeSweep:
            if purposeIndex > 0 {
                purposeIndex -= 1
            } else {
                step = .visionSweep
                visionIndex = max(orderedFulfillments.count - 1, 0)
            }
        case .priorities:
            step = .purposeSweep
            purposeIndex = max(orderedFulfillments.count - 1, 0)
        case .roles:
            if deepIndex > 0 {
                deepIndex -= 1
                step = .passions
            } else {
                step = .priorities
            }
        case .threeToThrive:
            step = .roles
        case .resources:
            step = .threeToThrive
        case .passions:
            step = .resources
        case .summary:
            step = .passions
        case .intro:
            dismiss()
        }
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .createCategories:
            syncSelectedCategoriesIntoFulfillment()
            step = .visionSweep
        case .visionSweep:
            moveVisionForward(saveCurrent: true)
        case .purposeSweep:
            movePurposeForward(saveCurrent: true)
        case .priorities:
            deepIndex = 0
            step = .roles
        case .roles:
            if let record = currentDeepRecord, addingRole {
                commitRole(record)
            }
            step = .threeToThrive
        case .threeToThrive:
            if let record = currentDeepRecord, addingFocus {
                commitFocus(record)
            }
            step = .resources
        case .resources:
            if let record = currentDeepRecord, addingResource {
                commitResource(record)
            }
            step = .passions
        case .passions:
            if deepIndex < deepCategoryIDs.count - 1 {
                deepIndex += 1
                step = .roles
            } else {
                step = .summary
            }
        default:
            break
        }
    }

    private func moveVisionForward(saveCurrent: Bool) {
        if saveCurrent, let record = currentVisionRecord {
            let text = (visionDrafts[record.category_id] ?? record.category_vision).trimmingCharacters(in: .whitespacesAndNewlines)
            updateVision(record: record, newText: text)
        }

        if visionIndex < orderedFulfillments.count - 1 {
            visionIndex += 1
        } else {
            purposeIndex = 0
            step = .purposeSweep
        }
    }

    private func movePurposeForward(saveCurrent: Bool) {
        if saveCurrent, let record = currentPurposeRecord {
            let text = (purposeDrafts[record.category_id] ?? record.category_purpose).trimmingCharacters(in: .whitespacesAndNewlines)
            updatePurpose(record: record, newText: text)
        }

        if purposeIndex < orderedFulfillments.count - 1 {
            purposeIndex += 1
        } else {
            step = .priorities
        }
    }

    private func togglePriority(_ id: UUID) {
        if priorityCategoryIDs.contains(id) {
            priorityCategoryIDs.removeAll { $0 == id }
        } else {
            guard priorityCategoryIDs.count < 3 else { return }
            priorityCategoryIDs.append(id)
        }
        persistDraftIfNeeded()
    }

    // MARK: - Data load & finalize

    private func loadFromPersistentData() {
        refreshFulfillmentSnapshot()
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        let categoriesFromFulfillment = sourceRows
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let categoriesFromLabels = planLabels
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let existingCategories = Array(Set(categoriesFromFulfillment + categoriesFromLabels))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        selectedCategoryNames = existingCategories
        customCategoryNames = existingCategories.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        var map = FulfillmentCategoryTheme.persistedColorKeys()
        let cycleKeys = onboardingColorCycleKeys
        if !cycleKeys.isEmpty {
            for (idx, category) in availableCategoryNames.enumerated() {
                let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
                guard !trimmed.isEmpty else { continue }
                // Preserve user-managed color assignments from AccountView.
                // Only assign a fallback color when none exists yet.
                if map[trimmed] == nil {
                    map[trimmed] = cycleKeys[idx % cycleKeys.count]
                }
            }
        }
        categoryColorKeys = map
        FulfillmentCategoryTheme.persistColorKeys(map)

        visionDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_vision) })
        purposeDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_purpose) })

        if priorityCategoryIDs.isEmpty {
            priorityCategoryIDs = Array(orderedFulfillments.prefix(2).map(\.category_id))
        } else {
            priorityCategoryIDs = priorityCategoryIDs.filter { id in
                orderedFulfillments.contains(where: { $0.category_id == id })
            }
        }
    }

    private func addCategory() {
        let trimmed = newCategoryText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingCategory = false
            newCategoryText = ""
            return
        }
        let duplicate = availableCategoryNames.contains { $0.lowercased() == trimmed.lowercased() }
        guard !duplicate else {
            triggerHint("Duplicate category name.")
            return
        }
        customCategoryNames.append(trimmed)
        toggleCategorySelection(trimmed, forceSelected: true)
        addingCategory = false
        newCategoryText = ""
        persistDraftIfNeeded()
    }

    private func deleteCategory(_ record: Fulfillment) {
        guard orderedFulfillments.count > 3 else {
            triggerHint("Keep at least 3 categories.")
            return
        }
        RecentlyDeletedStore.trash(record, in: modelContext)
        try? modelContext.save()
    }

    private func removeCategoryFromStepList(_ category: String) {
        if fulfillmentStartSelectableDefaultCategories.contains(category) {
            deletedDefaultCategoryNames.insert(category)
        } else {
            customCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
        selectedCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        categoryColorKeys.removeValue(forKey: category)
        applyCategorySelectionToLiveDataIfNeeded()
        persistDraftIfNeeded()
    }

    private func attemptRemoveCategoryFromStepList(_ category: String) {
        if hasOngoingUsage(in: category) {
            triggerHint("This category has an ongoing action block, chunk, or outcome.")
            return
        }
        removeCategoryFromStepList(category)
    }

    private func restoreDeletedDefaultCategories() {
        let missing = missingDefaultCategories
        deletedDefaultCategoryNames = deletedDefaultCategoryNames.filter { deleted in
            !missing.contains(where: { $0.caseInsensitiveCompare(deleted) == .orderedSame })
        }
        let cycleKeys = onboardingColorCycleKeys
        if !cycleKeys.isEmpty {
            var map = FulfillmentCategoryTheme.persistedColorKeys()
            for (idx, category) in fulfillmentStartSelectableDefaultCategories.enumerated() {
                map[category] = cycleKeys[idx % cycleKeys.count]
            }
            FulfillmentCategoryTheme.persistColorKeys(map)
            categoryColorKeys = map
        }
        for category in missing {
            assignDefaultColorIfNeeded(for: category)
        }
        persistDraftIfNeeded()
    }

    private func hasOngoingUsage(in category: String) -> Bool {
        let categoryTrimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryTrimmed.isEmpty else { return false }

        let activeWeeks = Set(
            activePlanStates
                .filter(\.isActive)
                .compactMap(\.weekStart)
                .map { Calendar.current.startOfDay(for: $0) }
        )
        let activeChunks = allPlannedChunks.filter {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame &&
            activeWeeks.contains(Calendar.current.startOfDay(for: $0.weekStart))
        }
        if !activeChunks.isEmpty {
            return true
        }

        let activeChunkIDs = Set(activeChunks.map(\.id))
        if !activeChunkIDs.isEmpty && allPlannedActions.contains(where: { activeChunkIDs.contains($0.plannedChunkId) }) {
            return true
        }

        return allOutcomes.contains {
            $0.category.caseInsensitiveCompare(categoryTrimmed) == .orderedSame
        }
    }

    private func toggleCategorySelection(_ category: String, forceSelected: Bool? = nil) {
        let shouldSelect: Bool
        if let forceSelected {
            shouldSelect = forceSelected
        } else {
            shouldSelect = !selectedCategoryNames.contains(category)
        }

        if shouldSelect {
            guard selectedCategoryNames.count < 7 else { return }
            if !selectedCategoryNames.contains(category) {
                selectedCategoryNames.append(category)
            }
            assignDefaultColorIfNeeded(for: category)
        } else {
            if hasOngoingUsage(in: category) {
                triggerHint("This category has an ongoing action block, chunk, or outcome.")
                return
            }
            selectedCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
        applyCategorySelectionToLiveDataIfNeeded()
        persistDraftIfNeeded()
    }

    private func applyCategorySelectionToLiveDataIfNeeded() {
        guard !usesDraftPersistence else { return }
        insertSelectedCategoriesIntoLiveData()
        pruneUnselectedCategoriesFromLiveData()
        try? modelContext.save()
        refreshFulfillmentSnapshot()
    }

    private func insertSelectedCategoriesIntoLiveData() {
        let sourceRows = fulfillments
        for category in selectedCategoryNames {
            let exists = sourceRows.contains {
                categoryKey($0.category) == categoryKey(category)
            }
            guard !exists else { continue }
            modelContext.insert(
                Fulfillment(
                    category_id: UUID(),
                    updatedAt: Date(),
                    category: category,
                    category_identitiy: "",
                    category_vision: "",
                    category_purpose: ""
                )
            )
        }
    }

    private func pruneUnselectedCategoriesFromLiveData() {
        let selectedKeys = Set(
            selectedCategoryNames.map { categoryKey($0) }
        )
        let rowsToDelete = fulfillments.filter { !selectedKeys.contains(categoryKey($0.category)) }
        let unselectedCategoryNames = Set(
            (fulfillments.map(\.category) + planLabels.map(\.category))
                .filter { !selectedKeys.contains(categoryKey($0)) }
        )
        guard !rowsToDelete.isEmpty || !unselectedCategoryNames.isEmpty else { return }

        let idsToDelete = Set(rowsToDelete.map(\.category_id))
        for role in roles where idsToDelete.contains(role.category_id) {
            modelContext.delete(role)
        }
        for focus in foci where idsToDelete.contains(focus.category_id) {
            modelContext.delete(focus)
        }
        for resource in resources where idsToDelete.contains(resource.category_id) {
            modelContext.delete(resource)
        }
        for join in passionJoins where idsToDelete.contains(join.category_id) {
            modelContext.delete(join)
        }
        for label in planLabels where unselectedCategoryNames.contains(where: { $0.caseInsensitiveCompare(label.category) == .orderedSame }) {
            modelContext.delete(label)
        }
        for row in rowsToDelete {
            modelContext.delete(row)
        }
    }

    private func syncSelectedCategoriesIntoFulfillment() {
        refreshFulfillmentSnapshot()
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        for category in selectedCategoryNames {
            let exists = sourceRows.contains {
                categoryKey($0.category) == categoryKey(category)
            }
            guard !exists else { continue }
            modelContext.insert(
                Fulfillment(
                    category_id: UUID(),
                    updatedAt: Date(),
                    category: category,
                    category_identitiy: "",
                    category_vision: "",
                    category_purpose: ""
                )
            )
        }
        refreshFulfillmentSnapshot()
        loadFromPersistentData()
        persistDraftIfNeeded()
    }

    private func refreshFulfillmentSnapshot() {
        let descriptor = FetchDescriptor<Fulfillment>()
        if let rows = try? modelContext.fetch(descriptor) {
            fulfillmentSnapshot = rows
        }
    }

    private func persistDraftIfNeeded() {
        guard !didFinalizeOnboarding else { return }
        persistDraft()
    }

    private func persistDraft() {
        let rows = orderedFulfillments
        let rowIDs = Set(rows.map(\.category_id))
        let rolesRows = roles.filter { rowIDs.contains($0.category_id) }
        let fociRows = foci.filter { rowIDs.contains($0.category_id) }
        let resourcesRows = resources.filter { rowIDs.contains($0.category_id) }
        let joinRows = passionJoins.filter { rowIDs.contains($0.category_id) }

        let draft = DraftState(
            stepRawValue: step.rawValue,
            visionIndex: visionIndex,
            purposeIndex: purposeIndex,
            deepIndex: deepIndex,
            priorityCategoryIDs: priorityCategoryIDs,
            selectedCategoryNames: selectedCategoryNames,
            customCategoryNames: customCategoryNames,
            deletedDefaultCategoryNames: Array(deletedDefaultCategoryNames),
            categoryColorKeys: categoryColorKeys,
            visionDrafts: Dictionary(uniqueKeysWithValues: visionDrafts.map { ($0.key.uuidString, $0.value) }),
            purposeDrafts: Dictionary(uniqueKeysWithValues: purposeDrafts.map { ($0.key.uuidString, $0.value) }),
            fulfillments: rows.map {
                DraftFulfillmentRow(
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    category: $0.category,
                    identity: $0.category_identitiy,
                    vision: $0.category_vision,
                    purpose: $0.category_purpose
                )
            },
            roles: rolesRows.map {
                DraftRoleRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    role: $0.role,
                    rank: $0.rank
                )
            },
            foci: fociRows.map {
                DraftFocusRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    activity: $0.activity,
                    rank: $0.rank
                )
            },
            resources: resourcesRows.map {
                DraftResourceRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    resource: $0.resource,
                    rank: $0.rank
                )
            },
            passionJoins: joinRows.map {
                DraftPassionJoinRow(
                    id: $0.id,
                    passionID: $0.passion_id,
                    categoryID: $0.category_id
                )
            }
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftStorageKey)
    }

    private func restoreDraftIfAvailable() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.draftStorageKey),
              let draft = try? JSONDecoder().decode(DraftState.self, from: data) else {
            return false
        }

        hydrateDraftIntoContext(draft)

        selectedCategoryNames = draft.selectedCategoryNames
        customCategoryNames = draft.customCategoryNames
        deletedDefaultCategoryNames = Set(draft.deletedDefaultCategoryNames)
        // Keep latest persisted category colors from AccountView and only fill gaps from draft.
        var mergedColors = FulfillmentCategoryTheme.persistedColorKeys()
        for (category, key) in draft.categoryColorKeys where mergedColors[category] == nil {
            mergedColors[category] = key
        }
        categoryColorKeys = mergedColors
        priorityCategoryIDs = draft.priorityCategoryIDs
        visionIndex = draft.visionIndex
        purposeIndex = draft.purposeIndex
        deepIndex = draft.deepIndex
        step = Step(rawValue: draft.stepRawValue) ?? .intro
        visionDrafts = Dictionary(uniqueKeysWithValues: draft.visionDrafts.compactMap { key, value in
            guard let id = UUID(uuidString: key) else { return nil }
            return (id, value)
        })
        purposeDrafts = Dictionary(uniqueKeysWithValues: draft.purposeDrafts.compactMap { key, value in
            guard let id = UUID(uuidString: key) else { return nil }
            return (id, value)
        })
        return true
    }

    private func hydrateDraftIntoContext(_ draft: DraftState) {
        modelContext.rollback()

        let existingFulfillments = (try? modelContext.fetch(FetchDescriptor<Fulfillment>())) ?? []
        for row in existingFulfillments {
            modelContext.delete(row)
        }
        let existingRoles = (try? modelContext.fetch(FetchDescriptor<FulfillmentRoles>())) ?? []
        for row in existingRoles {
            modelContext.delete(row)
        }
        let existingFoci = (try? modelContext.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
        for row in existingFoci {
            modelContext.delete(row)
        }
        let existingResources = (try? modelContext.fetch(FetchDescriptor<FulfillmentResources>())) ?? []
        for row in existingResources {
            modelContext.delete(row)
        }
        let existingJoins = (try? modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []
        for row in existingJoins {
            modelContext.delete(row)
        }

        for row in draft.fulfillments {
            modelContext.insert(
                Fulfillment(
                    category_id: row.categoryID,
                    updatedAt: row.updatedAt,
                    category: row.category,
                    category_identitiy: row.identity,
                    category_vision: row.vision,
                    category_purpose: row.purpose
                )
            )
        }
        for row in draft.roles {
            modelContext.insert(
                FulfillmentRoles(
                    id: row.id,
                    category_id: row.categoryID,
                    updatedAt: row.updatedAt,
                    role: row.role,
                    rank: row.rank
                )
            )
        }
        for row in draft.foci {
            modelContext.insert(
                FulfillmentFocus(
                    id: row.id,
                    category_id: row.categoryID,
                    updatedAt: row.updatedAt,
                    activity: row.activity,
                    rank: row.rank
                )
            )
        }
        for row in draft.resources {
            modelContext.insert(
                FulfillmentResources(
                    id: row.id,
                    category_id: row.categoryID,
                    updatedAt: row.updatedAt,
                    resource: row.resource,
                    rank: row.rank
                )
            )
        }
        for row in draft.passionJoins {
            modelContext.insert(
                PassionFulfillmentJoin(
                    id: row.id,
                    passion_id: row.passionID,
                    category_id: row.categoryID
                )
            )
        }
    }

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftStorageKey)
    }

    private func assignDefaultColorIfNeeded(for category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var map = FulfillmentCategoryTheme.persistedColorKeys()
        guard map[trimmed] == nil else {
            categoryColorKeys = map
            return
        }
        let cycleKeys = onboardingColorCycleKeys
        guard !cycleKeys.isEmpty else { return }
        let ordered = availableCategoryNames
        let idx = ordered.firstIndex(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) ?? ordered.count
        let nextColor = cycleKeys[idx % cycleKeys.count]
        map[trimmed] = nextColor
        FulfillmentCategoryTheme.persistColorKeys(map)
        categoryColorKeys = map
    }

    private func applyColorSelection(for category: String, colorKey: String) {
        var map = FulfillmentCategoryTheme.persistedColorKeys()
        let resolvedBefore = map[category] ?? FulfillmentCategoryTheme.defaultColorKeys()[category] ?? "blue"
        if let other = map.first(where: { $0.key != category && $0.value == colorKey })?.key {
            map[other] = resolvedBefore
        }
        map[category] = colorKey
        FulfillmentCategoryTheme.persistColorKeys(map)
        categoryColorKeys = map
        persistDraftIfNeeded()
    }

    private func fulfillmentCategoryColor(for category: String) -> Color {
        let key = categoryColorKeys[category] ?? rotatedColorKey(for: category)
        return FulfillmentCategoryTheme.color(forKey: key)
    }

    private func rotatedColorKey(for category: String) -> String {
        let cycleKeys = onboardingColorCycleKeys
        guard !cycleKeys.isEmpty else { return "blue" }
        if let idx = availableCategoryNames.firstIndex(where: { $0.caseInsensitiveCompare(category) == .orderedSame }) {
            return cycleKeys[idx % cycleKeys.count]
        }
        return cycleKeys.first ?? "blue"
    }

    private func finalizeAndContinue() {
        guard summaryCanComplete else {
            triggerHint("Complete required items before continuing.")
            return
        }

        for record in orderedFulfillments {
            let vision = (visionDrafts[record.category_id] ?? record.category_vision).trimmingCharacters(in: .whitespacesAndNewlines)
            let purpose = (purposeDrafts[record.category_id] ?? record.category_purpose).trimmingCharacters(in: .whitespacesAndNewlines)
            updateVision(record: record, newText: vision)
            updatePurpose(record: record, newText: purpose)
        }
        try? modelContext.save()
        didFinalizeOnboarding = true
        clearDraft()

        navigateToFulfillment = true
    }

    // MARK: - Validation feedback

    private func triggerValidationFeedback() {
        highlightInvalid = true
        invalidCategoryIDs = []

        switch step {
        case .createCategories:
            validationHintText = hasCreateCategoriesColorConflict
                ? "Each color can only be used once."
                : "Create at least 3 life categories."
        case .priorities:
            validationHintText = "Choose 2 or 3 priority categories."
        case .threeToThrive:
            validationHintText = "Add exactly 3 focus areas to continue."
            if let record = currentDeepRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .passions:
            validationHintText = "Connect at least 1 passion to continue."
            if let record = currentDeepRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        default:
            validationHintText = "Please complete required items."
        }

        triggerHint(validationHintText)
    }

    private func triggerHint(_ text: String) {
        hintWorkItem?.cancel()
        validationHintText = text
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    // MARK: - Persistence (mirrors FulfillmentView)

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
        persistDraftIfNeeded()
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
        persistDraftIfNeeded()
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
        persistDraftIfNeeded()
    }

    private func deleteRoles(at offsets: IndexSet, record: Fulfillment) {
        let list = getRoles(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
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
        persistDraftIfNeeded()
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
        persistDraftIfNeeded()
    }

    private func deleteFoci(at offsets: IndexSet, record: Fulfillment) {
        let list = getFoci(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
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
        persistDraftIfNeeded()
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
        persistDraftIfNeeded()
    }

    private func deleteResources(at offsets: IndexSet, record: Fulfillment) {
        let list = getResources(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
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
        persistDraftIfNeeded()
    }

    private func selectedPassionIDs(for categoryID: UUID) -> Set<UUID> {
        Set(
            passionJoins
                .filter { $0.category_id == categoryID }
                .map(\.passion_id)
        )
    }

    private func selectedPassions(for categoryID: UUID) -> [Passion] {
        let ids = selectedPassionIDs(for: categoryID)
        return passions.filter { ids.contains($0.passion_id) }
    }

    private func togglePassion(_ passion: Passion, for categoryID: UUID) {
        let existing = passionJoins.first {
            $0.passion_id == passion.passion_id && $0.category_id == categoryID
        }

        if let join = existing {
            RecentlyDeletedStore.trash(join, in: modelContext)
        } else {
            let join = PassionFulfillmentJoin(
                passion_id: passion.passion_id,
                category_id: categoryID
            )
            modelContext.insert(join)
        }
        persistDraftIfNeeded()
    }

    // MARK: - Inline commit helpers

    private func commitRole(_ record: Fulfillment) {
        let trimmed = roleEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingRole = false
            roleEntry = ""
            focusedField = nil
            return
        }
        addRole(text: trimmed, record: record)
        addingRole = false
        roleEntry = ""
        focusedField = nil
    }

    private func commitFocus(_ record: Fulfillment) {
        let trimmed = focusEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingFocus = false
            focusEntry = ""
            focusedField = nil
            return
        }
        addFocus(text: trimmed, record: record)
        addingFocus = false
        focusEntry = ""
        focusedField = nil
    }

    private func commitResource(_ record: Fulfillment) {
        let trimmed = resourceEntry.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingResource = false
            resourceEntry = ""
            focusedField = nil
            return
        }
        addResource(text: trimmed, record: record)
        addingResource = false
        resourceEntry = ""
        focusedField = nil
    }
}

private struct FulfillmentIntroRouteLinesView: View {
    private let lineCount: Int = 10
    @State private var animationStartDate: Date = .now

    private let colors: [Color] = [.blue, .green, .orange, .pink, .teal, .red]

    private func rand(_ seed: Int, _ a: Double, _ b: Double) -> Double {
        let seedD = Double(seed)
        let x = sin(seedD * 12.9898) * 43758.5453
        let u = x - floor(x)
        return a + (b - a) * u
    }

    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func smoothstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let tt = min(max((x - a) / (b - a), 0), 1)
        return tt * tt * (3 - 2 * tt)
    }

    private func routedPoint(s: CGFloat, size: CGSize, laneOffset: CGFloat) -> CGPoint {
        let startBandCenter = min(size.height * 0.58, 334)
        let endBandCenter = min(size.height * 0.83, 450)
        let endBandHalfSpan: CGFloat = 4.488
        let normalizedLane = max(-1.0, min(1.0, laneOffset / 70.0))
        let startY = startBandCenter + normalizedLane * (endBandHalfSpan * 4.68)
        let endYOffset: CGFloat = size.height * 0.01
        let endY = endBandCenter + normalizedLane * endBandHalfSpan + endYOffset
        let start = CGPoint(x: -28 + laneOffset * 0.35, y: startY)
        let midY = (startY + endY) * 0.5 - normalizedLane * (endBandHalfSpan * 0.35)
        let turn  = CGPoint(x: size.width * 0.26 + laneOffset * 0.05, y: midY)
        let end   = CGPoint(x: size.width * 0.50, y: endY)

        let split: CGFloat = 0.55
        if s <= split {
            let u = s / split
            let curveU = pow(u, 0.88)
            let x = start.x + (turn.x - start.x) * pow(curveU, 2.8)
            let y = start.y + (turn.y - start.y) * smoothstep(0, 1, curveU)
            return CGPoint(x: x, y: y)
        } else {
            let u = (s - split) / (1 - split)
            let curveU = smoothstep(0, 1, u)
            let x = turn.x + (end.x - turn.x) * curveU
            let y = turn.y + (end.y - turn.y) * smoothstep(0, 1, u)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let startupElapsed = context.date.timeIntervalSince(animationStartDate)

                for i in 0..<lineCount {
                    let color = colors[i % colors.count]
                    let laneFrac = (Double(i) + 0.5) / Double(lineCount)
                    let laneOffset = CGFloat((laneFrac - 0.5) * 140.0)

                    let lineDelay = rand(i * 83 + 17, 0.00, 0.36)
                    let lineRevealDuration = rand(i * 89 + 23, 0.62, 1.05)
                    let rawReveal = (startupElapsed - lineDelay) / lineRevealDuration
                    let revealProgress = max(0.0, min(rawReveal, 1.0))
                    if revealProgress <= 0.0 { continue }

                    let speed = rand(i * 13 + 1, 0.15, 0.35)
                    let phase = rand(i * 17 + 3, 0.0, 1.0)
                    let posFrac = (t * speed + phase).truncatingRemainder(dividingBy: 1)

                    let amp = rand(i * 23 + 5, 10.0, 40.0)
                    let freq = rand(i * 29 + 9, 2.0, 6.0)
                    let sigma = rand(i * 31 + 11, 0.08, 0.16)
                    let wobblePhase = rand(i * 37 + 13, 0.0, 2 * .pi)
                    let chop1 = rand(i * 41 + 101, 6.0, 12.0)
                    let chop2 = rand(i * 47 + 103, 12.0, 22.0)
                    let chopPhase1 = rand(i * 53 + 107, 0.0, 2 * .pi)
                    let chopPhase2 = rand(i * 59 + 109, 0.0, 2 * .pi)
                    let timeScale: Double = 0.8 + rand(i * 61 + 113, 0.0, 0.8)
                    let oceanTime: Double = t * timeScale

                    var path = Path()
                    let samples = 96
                    let twoPi = 2.0 * Double.pi

                    for j in 0...samples {
                        let localS = Double(j) / Double(samples)
                        let s = localS * revealProgress
                        let sCG = CGFloat(s)
                        var p = routedPoint(s: sCG, size: size, laneOffset: laneOffset)

                        let diff = (s - posFrac) / sigma
                        let envelope = exp(-pow(diff, 2) * 2)
                        let pulseArg = twoPi * (s * freq - oceanTime * speed * 0.6) + wobblePhase
                        let pulse = sin(pulseArg) * amp * envelope
                        let swellArg = twoPi * (s * (freq * 0.45) + oceanTime * speed * 0.25) + wobblePhase * 0.7
                        let swell = sin(swellArg) * (amp * 0.55)
                        let chopAArg = twoPi * (s * chop1 - oceanTime * speed * 1.2) + chopPhase1
                        let chopBArg = twoPi * (s * chop2 + oceanTime * speed * 1.7) + chopPhase2
                        let chop = sin(chopAArg) * (amp * 0.18) + sin(chopBArg) * (amp * 0.10)
                        let edge = sin(Double.pi * s)
                        let wiggle = (pulse + swell + chop) * edge * 0.5
                        p.y += CGFloat(wiggle)

                        if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }

                    let tailStartFrac: Double = 0.90
                    let baseOpacity: Double = 0.125
                    let tailGradient = Gradient(stops: [
                        .init(color: color.opacity(baseOpacity), location: 0.0),
                        .init(color: color.opacity(baseOpacity), location: tailStartFrac),
                        .init(color: color.opacity(baseOpacity * 0.75), location: min(tailStartFrac + 0.03, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.45), location: min(tailStartFrac + 0.06, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.22), location: min(tailStartFrac + 0.085, 1.0)),
                        .init(color: color.opacity(0.0), location: 1.0),
                    ])

                    let startPt = routedPoint(s: 0, size: size, laneOffset: laneOffset)
                    let endPt = routedPoint(s: CGFloat(revealProgress), size: size, laneOffset: laneOffset)

                    ctx.stroke(
                        path,
                        with: .linearGradient(tailGradient, startPoint: startPt, endPoint: endPt),
                        lineWidth: 10
                    )

                    let tailFactorAtGlow = 1.0 - smoothstepD(tailStartFrac, 1.0, posFrac)
                    let glowPeak = 0.45 * tailFactorAtGlow
                    let glowHalfWidth = sigma * 0.8
                    let startStop = max(0.0, posFrac - glowHalfWidth)
                    let endStop = min(1.0, posFrac + glowHalfWidth)
                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(0.0), location: startStop),
                        .init(color: color.opacity(glowPeak), location: posFrac),
                        .init(color: color.opacity(0.0), location: endStop),
                    ])

                    let revealX = startPt.x + (endPt.x - startPt.x)
                    let clipRect = CGRect(x: min(startPt.x, revealX), y: 0, width: max(1, abs(revealX - startPt.x) + 120), height: size.height)

                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 7))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 12
                        )
                    }
                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 2))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 6
                        )
                    }
                }
            }
        }
        .onAppear {
            animationStartDate = .now
        }
    }
}

#Preview {
    NavigationStack {
        FulfillmentStartView()
    }
}

private struct FulfillmentStartColorPickerSheet: View {
    let category: String
    let currentColorKey: String
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(FulfillmentCategoryTheme.palette, id: \.key) { option in
                    Button {
                        onSelect(option.key)
                    } label: {
                        HStack(spacing: 12) {
                            Circle()
                                .fill(option.color)
                                .frame(width: 22, height: 22)
                            Text(option.name)
                                .foregroundStyle(.primary)
                            Spacer()
                            if option.key == currentColorKey {
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
            .navigationTitle(category)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Close") { dismiss() }
                }
            }
        }
    }
}
