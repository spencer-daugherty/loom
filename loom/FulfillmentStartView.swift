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
    enum EntryMode {
        case onboarding
        case addSingleArea
    }

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
        var passionIndex: Int?
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

    private let entryMode: EntryMode
    private let showsProgressStrip: Bool

    init(entryMode: EntryMode = .onboarding, showsProgressStrip: Bool = true) {
        self.entryMode = entryMode
        self.showsProgressStrip = showsProgressStrip
    }


    @State private var step: Step = .intro
    @State private var visionIndex: Int = 0
    @State private var purposeIndex: Int = 0
    @State private var roleIndex: Int = 0
    @State private var passionIndex: Int = 0
    @State private var didOpenPriorities = false
    @State private var priorityCategoryIDs: [UUID] = []
    @State private var deepIndex: Int = 0

    @State private var visionDrafts: [UUID: String] = [:]
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var fulfillmentSnapshot: [Fulfillment] = []
    @State private var draftRoles: [DraftRoleRow] = []
    @State private var draftFoci: [DraftFocusRow] = []
    @State private var draftResources: [DraftResourceRow] = []
    @State private var draftPassionJoins: [DraftPassionJoinRow] = []
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
    @State private var isForcedColorPickerForProceed = false

    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPurpose = false
    @State private var showNeedIdeasRoles = false
    @State private var showNeedIdeasLittleWins = false
    @State private var showNeedIdeasResources = false
    @State private var showNeedHelpCategories = false
    @State private var autoWriteMissionSuggestionsByCategoryID: [UUID: [String]] = [:]
    @State private var autoWritingMissionCategoryID: UUID? = nil
    @State private var appliedAutoWriteMissionSuggestionsByCategoryID: [UUID: Set<String>] = [:]
    @State private var autoWriteIdentitySuggestionsByCategoryID: [UUID: [IdentityAutoWriteSuggestion]] = [:]
    @State private var autoWritingIdentityCategoryID: UUID? = nil
    @State private var appliedAutoWriteIdentitySuggestionsByCategoryID: [UUID: Set<UUID>] = [:]
    @State private var autoWriteLittleWinSuggestionsByCategoryID: [UUID: [LittleWinAutoWriteSuggestion]] = [:]
    @State private var autoWritingLittleWinCategoryID: UUID? = nil
    @State private var appliedAutoWriteLittleWinSuggestionsByCategoryID: [UUID: Set<UUID>] = [:]
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating: Bool = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil

    @State private var showValidationHint = false
    @State private var validationHintText = ""
    @State private var hintWorkItem: DispatchWorkItem?
    @State private var previousAutosaveEnabled: Bool = true
    @State private var didFinalizeOnboarding = false
    @State private var didInitializeViewState = false
    @State private var ignoreBackUntil: Date = .distantPast
    @State private var usesDraftPersistence = false
    @State private var highlightInvalid = false
    @State private var invalidCategoryIDs = Set<UUID>()
    @State private var isAllSummaryExpanded = false
    @State private var addModeInitialActiveCategoryKeys = Set<String>()

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
        case roles
        case priorities
        case littleWins
        case resources
        case passions
        case summary

        var title: String {
            switch self {
            case .intro: return "Set Fulfillment Areas"
            case .createCategories: return "Create Categories"
            case .visionSweep: return "Define Mission"
            case .purposeSweep: return "Define Mission"
            case .roles: return "Set Identity"
            case .priorities: return "Choose Your Focus"
            case .littleWins: return "List Little Wins"
            case .resources: return "Note Resources"
            case .passions: return "Passions"
            case .summary: return "Summary"
            }
        }
    }

    private var isAddSingleAreaMode: Bool { entryMode == .addSingleArea }

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

    private var roleCategoryIDs: [UUID] {
        orderedFulfillments.map(\.category_id)
    }

    private var currentRoleRecord: Fulfillment? {
        guard roleCategoryIDs.indices.contains(roleIndex) else { return nil }
        let categoryID = roleCategoryIDs[roleIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var currentPassionRecord: Fulfillment? {
        guard roleCategoryIDs.indices.contains(passionIndex) else { return nil }
        let categoryID = roleCategoryIDs[passionIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var deepCategoryIDs: [UUID] {
        isAddSingleAreaMode ? orderedFulfillments.map(\.category_id) : priorityCategoryIDs
    }

    private var currentDeepRecord: Fulfillment? {
        guard deepCategoryIDs.indices.contains(deepIndex) else { return nil }
        let categoryID = deepCategoryIDs[deepIndex]
        return orderedFulfillments.first(where: { $0.category_id == categoryID })
    }

    private var progressCurrentStep: Int {
        if isAddSingleAreaMode {
            switch step {
            case .createCategories: return 1
            case .visionSweep: return 0
            case .purposeSweep: return 2
            case .roles: return 3
            case .littleWins: return 4
            case .passions: return 5
            case .resources: return 0
            default: return 0
            }
        }
        switch step {
        case .createCategories: return 1
        case .visionSweep: return 0
        case .purposeSweep: return 2
        case .roles: return 3
        case .priorities: return 4
        case .littleWins: return 5
        case .passions: return 6
        case .summary: return 7
        case .resources: return 0
        case .intro: return 0
        }
    }

    private var progressTotalSteps: Int {
        isAddSingleAreaMode ? 5 : 7
    }

    private var editorSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var isScrollableStep: Bool {
        switch step {
        case .createCategories, .visionSweep, .purposeSweep, .roles, .littleWins, .passions, .summary:
            return true
        default:
            return false
        }
    }

    private var isNextDisabled: Bool {
        switch step {
        case .createCategories:
            if isAddSingleAreaMode {
                return !(canAddSingleArea || shouldForceColorPickerBeforeProceed)
            }
            return !canStartOnboarding
        case .visionSweep:
            return false
        case .purposeSweep:
            guard let record = currentPurposeRecord else { return true }
            let text = (purposeDrafts[record.category_id] ?? record.category_purpose)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            return text.isEmpty
        case .roles:
            guard let record = currentRoleRecord else { return true }
            return getRoles(for: record).isEmpty
        case .priorities:
            if isAddSingleAreaMode { return false }
            return priorityCategoryIDs.isEmpty
        case .littleWins:
            if isAddSingleAreaMode { return false }
            guard let record = currentDeepRecord else { return true }
            return getFoci(for: record).isEmpty
        case .resources:
            return false
        case .passions:
            guard let record = currentPassionRecord else { return true }
            return selectedPassions(for: record.category_id).isEmpty
        default:
            return false
        }
    }

    private var summaryCanComplete: Bool {
        guard !(orderedFulfillments.isEmpty) else { return false }
        guard !priorityCategoryIDs.isEmpty else { return false }
        for id in roleCategoryIDs {
            guard let record = orderedFulfillments.first(where: { $0.category_id == id }) else { return false }
            if priorityCategoryIDs.contains(id), getFoci(for: record).isEmpty { return false }
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

    private var canAddSingleArea: Bool {
        let names = selectedCategoryNames
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard names.count == 1 else { return false }
        let uniqueCount = Set(names.map { $0.lowercased() }).count
        guard uniqueCount == 1 else { return false }
        guard !hasCreateCategoriesColorConflict else { return false }
        guard !hasAddSingleAreaActiveColorConflict else { return false }
        return true
    }

    private var shouldForceColorPickerBeforeProceed: Bool {
        guard step == .createCategories, isAddSingleAreaMode else { return false }
        guard selectedCategoryNames.count == 1 else { return false }
        return hasAddSingleAreaActiveColorConflict
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

    private var activeCategoryColorKeys: Set<String> {
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        return Set(sourceRows.compactMap { row in
            let category = row.category.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !category.isEmpty else { return nil }
            return categoryColorKeys[category]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[category]
                ?? "blue"
        })
    }

    private var hasAddSingleAreaActiveColorConflict: Bool {
        guard isAddSingleAreaMode else { return false }
        guard let category = selectedCategoryNames.first?.trimmingCharacters(in: .whitespacesAndNewlines),
              !category.isEmpty else { return false }
        let selectedColorKey = categoryColorKeys[category]
            ?? FulfillmentCategoryTheme.defaultColorKeys()[category]
            ?? rotatedColorKey(for: category)
        return activeCategoryColorKeys.contains(selectedColorKey)
    }

    private func unavailableColorKeys(for category: String) -> Set<String> {
        let current = category.trimmingCharacters(in: .whitespacesAndNewlines)
        var keys = Set<String>()

        for otherCategory in selectedCategoryNames {
            let other = otherCategory.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !other.isEmpty else { continue }
            guard other.caseInsensitiveCompare(current) != .orderedSame else { continue }
            let colorKey = categoryColorKeys[other]
                ?? FulfillmentCategoryTheme.defaultColorKeys()[other]
                ?? rotatedColorKey(for: other)
            keys.insert(colorKey)
        }

        if isAddSingleAreaMode {
            keys.formUnion(activeCategoryColorKeys)
        }

        return keys
    }

    private func availableColorOptions(for category: String) -> [FulfillmentCategoryTheme.PaletteOption] {
        let unavailable = unavailableColorKeys(for: category)
        return FulfillmentCategoryTheme.palette.filter { !unavailable.contains($0.key) }
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

    private var existingActiveCategoryKeys: Set<String> {
        if isAddSingleAreaMode {
            return addModeInitialActiveCategoryKeys
        }
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        return Set(sourceRows.map(\.category).map { categoryKey($0) })
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

    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }
    private var introHeroHeight: CGFloat {
        switch screenHeight {
        case ...680: return 210
        case ...740: return 240
        case ...812: return 300
        default: return 420
        }
    }
    private var introFooterReserve: CGFloat {
        screenHeight <= 680 ? 122 : (screenHeight <= 740 ? 112 : 92)
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
            if step != .intro {
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
        }
        .overlay(alignment: .bottom) {
            if step == .intro {
                footer
                    .padding(.horizontal)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
                    .background(Color(.systemGroupedBackground))
                    .zIndex(20)
            }
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step != .intro)
        .onAppear {
            guard !didInitializeViewState else { return }
            didInitializeViewState = true
            previousAutosaveEnabled = modelContext.autosaveEnabled
            // Always stage onboarding edits in draft storage/context only.
            // Nothing should be committed to shared app data until Summary -> Continue.
            usesDraftPersistence = true
            modelContext.autosaveEnabled = false
            if isAddSingleAreaMode {
                usesDraftPersistence = false
                step = .createCategories
                loadFromPersistentData()
                applyLoomAIPrefillIfAvailable()
            } else if !restoreDraftIfAvailable() {
                loadFromPersistentData()
            }
        }
        .onDisappear {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            if usesDraftPersistence && !didFinalizeOnboarding {
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
        .overlay(alignment: .bottom) {
            let persistentColorConflict = step == .createCategories && (hasCreateCategoriesColorConflict || hasAddSingleAreaActiveColorConflict)
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
                case .visionSweep: focusedField = nil
                case .purposeSweep: focusedField = .purpose
                case .roles: focusedField = addingRole ? .role : nil
                case .littleWins: focusedField = addingFocus ? .focus : nil
                case .resources: focusedField = nil
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
                purposeSweepStep
            case .purposeSweep:
                purposeSweepStep
            case .priorities:
                prioritiesStep
            case .roles:
                rolesStep
            case .littleWins:
                littleWinsStep
            case .resources:
                passionsStep
            case .passions:
                passionsStep
            case .summary:
                summaryStep
            }
        }
        .padding(.horizontal)
        .padding(.bottom, step == .intro ? introFooterReserve : (step == .summary ? 100 : 0))
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
                            .frame(height: introHeroHeight)
                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                    }
                }
                .frame(height: introHeroHeight)
                .padding(.bottom, 2)
            }

            if step != .intro && showsProgressStrip {
                progressStrip
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if step == .intro {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(isCompactIntroLayout ? .caption2 : .caption)
                    Text("~7 minutes")
                        .font((isCompactIntroLayout ? Font.caption2 : .caption).weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, isCompactIntroLayout ? 8 : 10)
                .padding(.vertical, isCompactIntroLayout ? 4 : 6)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }

            if !(isAddSingleAreaMode && !showsProgressStrip && step == .createCategories) {
                Text(currentStepDisplayTitle)
                    .font(isCompactIntroLayout && step == .intro ? .title2 : .largeTitle)
                    .fontWeight(.bold)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var currentStepDisplayTitle: String {
        if isAddSingleAreaMode && step == .createCategories {
            return "Add Fulfillment Area"
        }
        return step.title
    }

    private var progressStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...progressTotalSteps, id: \.self) { index in
                progressSegment(for: index)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .animation(.easeInOut(duration: 0.22), value: progressCurrentStep)
        .animation(.easeInOut(duration: 0.22), value: nestedProgressFraction ?? 0)
        .animation(.easeInOut(duration: 0.22), value: nestedProgressFraction != nil)
    }

    private func progressSegment(for index: Int) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(primarySegmentColor(for: index))

            if index == progressCurrentStep, let nested = nestedProgressFraction {
                GeometryReader { geo in
                    let clamped = max(0.0, min(1.0, nested))
                    let available = max(geo.size.width, 0)
                    let fillWidth = max(available * clamped, 0)
                    Capsule()
                        .fill(Color.accentColor.opacity(colorScheme == .dark ? 0.82 : 0.75))
                        .frame(width: fillWidth, height: geo.size.height)
                        .position(
                            x: fillWidth / 2,
                            y: geo.size.height / 2
                        )
                        .opacity(0.9)
                }
                .allowsHitTesting(false)
                .transition(.opacity)
            }
        }
        .frame(width: 26)
        .frame(height: 4)
    }

    private func primarySegmentColor(for index: Int) -> Color {
        if index < progressCurrentStep {
            return .accentColor
        }
        if index == progressCurrentStep {
            // Keep active multi-page step neutral until fully completed.
            return (nestedProgressFraction != nil) ? Color(.systemGray4) : .accentColor
        }
        return Color(.systemGray4)
    }

    private var nestedProgressFraction: CGFloat? {
        switch step {
        case .visionSweep:
            let total = orderedFulfillments.count
            guard total > 1 else { return nil }
            return CGFloat(visionIndex + 1) / CGFloat(total)
        case .purposeSweep:
            let total = orderedFulfillments.count
            guard total > 1 else { return nil }
            return CGFloat(purposeIndex + 1) / CGFloat(total)
        case .roles:
            let total = roleCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(roleIndex + 1) / CGFloat(total)
        case .littleWins:
            let total = deepCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(deepIndex + 1) / CGFloat(total)
        case .passions:
            let total = roleCategoryIDs.count
            guard total > 1 else { return nil }
            return CGFloat(passionIndex + 1) / CGFloat(total)
        default:
            return nil
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button {
                    ignoreBackUntil = Date().addingTimeInterval(0.45)
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
                    if shouldForceColorPickerBeforeProceed {
                        guard let category = selectedCategoryNames.first?.trimmingCharacters(in: .whitespacesAndNewlines),
                              !category.isEmpty else {
                            triggerValidationFeedback()
                            return
                        }
                        isForcedColorPickerForProceed = true
                        colorPickerCategory = category
                        showColorPicker = true
                    } else if isNextDisabled {
                        triggerValidationFeedback()
                    } else {
                        highlightInvalid = false
                        invalidCategoryIDs = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                } label: {
                    Text(footerPrimaryButtonTitle)
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
                .frame(maxWidth: .infinity)
            }
        }
        .contentShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if shouldShowMissionAutoWriteControls {
                missionAutoWriteControls
                    .offset(x: 0, y: -58)
            } else if shouldShowIdentityAutoWriteControls {
                identityAutoWriteControls
                    .offset(x: 0, y: -58)
            } else if shouldShowLittleWinAutoWriteControls {
                littleWinAutoWriteControls
                    .offset(x: 0, y: -58)
            }
        }
    }

    private var footerPrimaryButtonTitle: String {
        if isAddSingleAreaMode && step == .passions {
            return "Completed"
        }
        if isAddSingleAreaMode && step == .littleWins,
           let record = currentDeepRecord,
           getFoci(for: record).isEmpty {
            return "Skip"
        }
        return "Next"
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: isCompactIntroLayout ? 8 : 10) {
            Text("Design the most important areas of your life.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
            Text("They're never finished. You continually improve them to stay moving forward.")
                .font(introSubtextFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(isCompactIntroLayout ? 12 : 14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(isAddSingleAreaMode
                 ? "What area of your life must you consistently improve to succeed?"
                 : "What 3-7 areas of your life must you consistently improve to succeed?")
                .fontWeight(.bold)
                .foregroundStyle(.primary)

            List {
                ForEach(availableCategoryNames, id: \.self) { category in
                    let selected = selectedCategoryNames.contains(category)
                    let isActiveExisting = isAddSingleAreaMode && existingActiveCategoryKeys.contains(categoryKey(category))
                    let isConflicting = conflictingSelectedCategories.contains(category)
                    let hasSingleAreaActiveColorConflictForRow =
                        isAddSingleAreaMode &&
                        selected &&
                        hasAddSingleAreaActiveColorConflict
                    let shouldHighlightColorCircleConflict =
                        isConflicting || hasSingleAreaActiveColorConflictForRow
                    HStack(spacing: 8) {
                        Button {
                            guard !isActiveExisting else { return }
                            isForcedColorPickerForProceed = false
                            colorPickerCategory = category
                            showColorPicker = true
                        } label: {
                            Circle()
                                .fill(fulfillmentCategoryColor(for: category))
                                .frame(width: 22, height: 22)
                                .overlay(
                                    Circle()
                                        .stroke(
                                            shouldHighlightColorCircleConflict ? Color.red : Color(.systemGray4),
                                            lineWidth: shouldHighlightColorCircleConflict ? 2 : 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isActiveExisting)

                        Text(category)
                            .font(.system(size: 20))
                            .foregroundStyle(fulfillmentCategoryColor(for: category))
                            .opacity(isActiveExisting ? 0.5 : 1.0)

                        Spacer()
                        if isConflicting {
                            Circle()
                                .fill(Color.red)
                                .frame(width: 6, height: 6)
                        }

                        Button {
                            guard !isActiveExisting else { return }
                            toggleCategorySelection(category)
                        } label: {
                            Image(systemName: (selected || isActiveExisting) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(
                                    isActiveExisting ? Color.secondary.opacity(0.6) :
                                        (selected ? Color.blue : Color.secondary)
                                )
                        }
                        .buttonStyle(.plain)
                        .disabled(isActiveExisting)
                    }
                    .opacity(isActiveExisting ? 0.62 : 1.0)
                    .contentShape(Rectangle())
                    .onTapGesture {
                        guard !isActiveExisting else { return }
                        toggleCategorySelection(category)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                        if !isActiveExisting {
                        Button(role: .destructive) {
                            attemptRemoveCategoryFromStepList(category)
                        } label: {
                            Text("Delete")
                        }
                        .tint(.red)
                        }
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
                options: availableColorOptions(for: colorPickerCategory),
                showsCloseButton: !isForcedColorPickerForProceed,
                onSelect: { colorKey in
                    let shouldProceed = isForcedColorPickerForProceed
                    applyColorSelection(for: colorPickerCategory, colorKey: colorKey)
                    showColorPicker = false
                    isForcedColorPickerForProceed = false
                    if shouldProceed && canAddSingleArea {
                        highlightInvalid = false
                        invalidCategoryIDs = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                }
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onChange(of: showColorPicker) { _, isPresented in
            if !isPresented {
                isForcedColorPickerForProceed = false
            }
        }
    }

    private var visionSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentVisionRecord {
                let isInvalid = highlightInvalid &&
                    (visionDrafts[record.category_id] ?? record.category_vision)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                categoryHeader(record.category, index: visionIndex + 1, total: orderedFulfillments.count)
                Text("What does your ideal life look like in this area?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { visionDrafts[record.category_id] ?? record.category_vision },
                        set: { visionDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "Keep it simple and clear...",
                    showError: isInvalid
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
                let isInvalid = highlightInvalid &&
                    (purposeDrafts[record.category_id] ?? record.category_purpose)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                        .isEmpty
                categoryHeader(record.category, index: purposeIndex + 1, total: orderedFulfillments.count)
                Text("Why does improving this area truly matter?")
                    .font(.headline)

                multiLineEditor(
                    text: Binding(
                        get: { purposeDrafts[record.category_id] ?? record.category_purpose },
                        set: { purposeDrafts[record.category_id] = $0 }
                    ),
                    placeholder: "Keep it simple and clear...",
                    showError: isInvalid
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
                                .foregroundStyle(fulfillmentCategoryColor(for: record.category))
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
                                .stroke(
                                    selected
                                        ? Color.blue.opacity(0.6)
                                        : (highlightInvalid && priorityCategoryIDs.isEmpty ? Color.red.opacity(0.85) : Color.clear),
                                    lineWidth: (selected || (highlightInvalid && priorityCategoryIDs.isEmpty)) ? 1.5 : 1
                                )
                        )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var rolesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentRoleRecord {
                let rolesItems = getRoles(for: record)
                let isInvalid = highlightInvalid && rolesItems.isEmpty
                categoryHeader(record.category, index: roleIndex + 1, total: roleCategoryIDs.count)
                Text("Who do you want to be in this area of your life?")
                    .font(.headline)

                VStack(spacing: 0) {
                    if rolesItems.count < 3 {
                        if addingRole {
                            TextField("Add Identity", text: $roleEntry)
                                .focused($focusedField, equals: .role)
                                .textInputAutocapitalization(.sentences)
                                .autocorrectionDisabled(false)
                                .submitLabel(.done)
                                .onSubmit {
                                    commitRole(record)
                                }
                                .padding(.vertical, 10)
                                .padding(.horizontal, 10)
                                .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                        } else {
                            Button("+ Add Identity") {
                                addingRole = true
                                roleEntry = ""
                                focusedField = .role
                            }
                            .foregroundStyle(.blue)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.vertical, 10)
                            .padding(.horizontal, 10)
                            .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                        }
                    }

                    ForEach(rolesItems, id: \.id) { item in
                        HStack {
                            Text(item.role)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = rolesItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteRoles(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(isInvalid ? Color.red.opacity(0.85) : Color.clear, lineWidth: 1.5)
                )

                VStack(alignment: .leading, spacing: 6) {
                    if let suggestions = autoWriteIdentitySuggestionsByCategoryID[record.category_id], !suggestions.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            ForEach(suggestions, id: \.id) { suggestion in
                                let isApplied = appliedAutoWriteIdentitySuggestionsByCategoryID[record.category_id]?.contains(suggestion.id) ?? false
                                Button {
                                    let didApply = applyIdentityAutoWriteSuggestion(suggestion, for: record)
                                    guard didApply else { return }
                                    var applied = appliedAutoWriteIdentitySuggestionsByCategoryID[record.category_id] ?? Set<UUID>()
                                    applied.insert(suggestion.id)
                                    appliedAutoWriteIdentitySuggestionsByCategoryID[record.category_id] = applied
                                } label: {
                                    HStack(alignment: .top, spacing: 10) {
                                        Image("LoomAI")
                                            .resizable()
                                            .renderingMode(.template)
                                            .scaledToFit()
                                            .frame(width: 16, height: 16)
                                            .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                            .padding(.top, 1)

                                        VStack(alignment: .leading, spacing: 3) {
                                            Text(suggestionTopLine(suggestion, category: record.category, isApplied: isApplied))
                                                .font(.subheadline.italic())
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                                .multilineTextAlignment(.leading)
                                            Text(suggestion.identity)
                                                .font(.subheadline.weight(.bold))
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                                .multilineTextAlignment(.leading)
                                            if let replacing = suggestion.replaceIdentity?.trimmingCharacters(in: .whitespacesAndNewlines),
                                               !replacing.isEmpty {
                                                Text("\(isApplied ? "Replaced" : "Replacing"): \(replacing)")
                                                    .font(.caption)
                                                    .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                                    .multilineTextAlignment(.leading)
                                            }
                                        }

                                        Spacer(minLength: 0)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                                    )
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                                    )
                                }
                                .buttonStyle(.plain)
                                .disabled(isApplied)
                            }
                        }
                    }

                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNeedIdeasRoles.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Need help?")
                            Image(systemName: showNeedIdeasRoles ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    if showNeedIdeasRoles {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Roles define your identity.")
                                .fontWeight(.bold)
                            Text("They guide how you think, act, and make decisions before results show up. Instead of focusing only on goals, focus on the person who naturally creates those outcomes.")
                            Text("Choose identities that feel empowering and motivating. These should reflect the best version of yourself in this area.")
                            Text("You can update these anytime as you evolve.")
                            Text("Examples:")
                                .fontWeight(.bold)
                            Text("• Athlete").italic()
                            Text("• Wealth Builder").italic()
                            Text("• Focused Student").italic()
                            Text("• Loving Partner").italic()
                            Text("• Empowering Leader").italic()
                            Text("• Energized Creator").italic()
                            Text("• Community Contributor").italic()
                            Text("• Prayer Warrior").italic()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var littleWinsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                littleWinsContent(for: record)
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private func littleWinsContent(for record: Fulfillment) -> some View {
        let fociItems = getFoci(for: record)
        let isInvalid = highlightInvalid && fociItems.isEmpty
        let rowBackground = isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor

        categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
        Text("What small, repeatable wins can move this area forward?")
            .font(.headline)

        VStack(spacing: 0) {
            if addingFocus, fociItems.count < 3 {
                TextField("Add Little Win", text: $focusEntry)
                    .focused($focusedField, equals: .focus)
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit { commitFocus(record) }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(rowBackground)
            } else if fociItems.count < 3 {
                Button("+ Add Little Win") {
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
                            .foregroundStyle(.red)
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

        VStack(alignment: .leading, spacing: 6) {
            if let suggestions = autoWriteLittleWinSuggestionsByCategoryID[record.category_id], !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.id) { suggestion in
                        let isApplied = appliedAutoWriteLittleWinSuggestionsByCategoryID[record.category_id]?.contains(suggestion.id) ?? false
                        Button {
                            let didApply = applyLittleWinAutoWriteSuggestion(suggestion, for: record)
                            guard didApply else { return }
                            var applied = appliedAutoWriteLittleWinSuggestionsByCategoryID[record.category_id] ?? Set<UUID>()
                            applied.insert(suggestion.id)
                            appliedAutoWriteLittleWinSuggestionsByCategoryID[record.category_id] = applied
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image("LoomAI")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                    .padding(.top, 1)

                                VStack(alignment: .leading, spacing: 3) {
                                    Text(littleWinSuggestionTopLine(suggestion, category: record.category, isApplied: isApplied))
                                        .font(.subheadline.italic())
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                        .multilineTextAlignment(.leading)
                                    Text(suggestion.activity)
                                        .font(.subheadline.weight(.bold))
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                        .multilineTextAlignment(.leading)
                                    if let replacing = suggestion.replaceActivity?.trimmingCharacters(in: .whitespacesAndNewlines),
                                       !replacing.isEmpty {
                                        Text("\(isApplied ? "Replaced" : "Replacing"): \(replacing)")
                                            .font(.caption)
                                            .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                            .multilineTextAlignment(.leading)
                                    }
                                }

                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isApplied)
                    }
                }
            }

            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showNeedIdeasLittleWins.toggle()
                }
            } label: {
                HStack(spacing: 6) {
                    Text("Need Help?")
                    Image(systemName: showNeedIdeasLittleWins ? "chevron.up" : "chevron.down")
                        .font(.caption2.weight(.semibold))
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
            }
            .buttonStyle(.plain)

            if showNeedIdeasLittleWins {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Small actions create momentum.")
                        .fontWeight(.bold)
                    Text("Focus on a few easy, high-impact 1-3 actions you can do consistently.")
                    Text("These should be simple enough that you can follow through even on busy or low-energy days.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• Stretch or walk").italic()
                    Text("• Pray or journal").italic()
                    Text("• Review budget").italic()
                    Text("• Call loved one").italic()
                    Text("• Read for 10 min").italic()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private var resourcesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentDeepRecord {
                let resourcesItems = getResources(for: record)
                let isInvalid = highlightInvalid && resourcesItems.isEmpty
                let rowBackground = isInvalid ? Color.red.opacity(0.08) : rowSurfaceColor

                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("What people, tools, or environments can help you improve this area?")
                    .font(.headline)

                VStack(spacing: 0) {
                    if addingResource, resourcesItems.count < 3 {
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
                            .background(rowBackground)
                    } else if resourcesItems.count < 3 {
                        Button("+ Add Resource") {
                            addingResource = true
                            resourceEntry = ""
                            focusedField = .resource
                        }
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowBackground)
                    }

                    ForEach(resourcesItems, id: \.id) { item in
                        HStack {
                            Text(item.resource)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Button(role: .destructive) {
                                if let idx = resourcesItems.firstIndex(where: { $0.id == item.id }) {
                                    deleteResources(at: IndexSet(integer: idx), record: record)
                                }
                            } label: {
                                Image(systemName: "trash")
                                    .foregroundStyle(.red)
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

                VStack(alignment: .leading, spacing: 6) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showNeedIdeasResources.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Text("Need Help?")
                            Image(systemName: showNeedIdeasResources ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)

                    if showNeedIdeasResources {
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Strong support makes success easier.")
                                .fontWeight(.bold)
                            Text("Focus on 1–3 people, tools, or environments that support consistent growth.")
                            Text("Choose resources that reduce friction and make the right behavior more automatic.")
                            Text("Examples:")
                                .fontWeight(.bold)
                            Text("• Great gym").italic()
                            Text("• Accountability partner").italic()
                            Text("• Mentor or coach").italic()
                            Text("• Budgeting app").italic()
                            Text("• Supportive community").italic()
                            Text("• Quiet workspace").italic()
                            Text("• State park nearby").italic()
                        }
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    }
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let record = currentPassionRecord {
                categoryHeader(record.category, index: passionIndex + 1, total: roleCategoryIDs.count)
                Text("What passions drive you to improve this area?")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(passions, id: \.passion_id) { passion in
                        let isSelected = selectedPassionIDs(for: record.category_id).contains(passion.passion_id)
                        Button {
                            togglePassion(passion, for: record.category_id)
                        } label: {
                            HStack {
                                Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
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
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            summarySection(title: "Categories (* Increased Focus)") {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(orderedFulfillments, id: \.category_id) { record in
                        let isFocus = priorityCategoryIDs.contains(record.category_id)
                        Text(isFocus ? "\(record.category) *" : record.category)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(fulfillmentCategoryColor(for: record.category))
                    }
                }
            } onEdit: {
                step = .createCategories
            }

            summarySection(title: "Increased Focus Areas") {
                let focused = orderedFulfillments.filter { priorityCategoryIDs.contains($0.category_id) }
                if focused.isEmpty {
                    Text("None selected")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(focused, id: \.category_id) { record in
                            categoryDetailsBlock(
                                record: record,
                                includeVisionPurpose: false,
                                markAsFocus: true,
                                includeLittleWinsResources: true,
                                includePassions: false
                            )
                        }
                    }
                }
            } onEdit: {
                step = .priorities
            }

            summarySection(title: "All") {
                VStack(alignment: .leading, spacing: 8) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            isAllSummaryExpanded.toggle()
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Spacer(minLength: 0)
                            Text(isAllSummaryExpanded ? "Hide" : "Show")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.blue)
                            Image(systemName: isAllSummaryExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.blue)
                        }
                    }
                    .buttonStyle(.plain)

                    if isAllSummaryExpanded {
                        VStack(alignment: .leading, spacing: 10) {
                            ForEach(orderedFulfillments, id: \.category_id) { record in
                                categoryDetailsBlock(
                                    record: record,
                                    includeVisionPurpose: true,
                                    markAsFocus: false,
                                    includeLittleWinsResources: false,
                                    includePassions: true
                                )
                            }
                        }
                    }
                }
            } onEdit: {
                step = .roles
                deepIndex = 0
            }
        }
    }

    @ViewBuilder
    private func categoryDetailsBlock(
        record: Fulfillment,
        includeVisionPurpose: Bool,
        markAsFocus: Bool,
        includeLittleWinsResources: Bool,
        includePassions: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(markAsFocus ? "\(record.category) *" : record.category)
                .foregroundStyle(fulfillmentCategoryColor(for: record.category))
            .font(.subheadline.weight(.semibold))

            if includeVisionPurpose {
                summarySubBullet(title: "Mission", values: [record.category_purpose])
            }

            summaryNestedBullets(title: "Identity", values: getRoles(for: record).map(\.role))
            if includeLittleWinsResources {
                summaryNestedBullets(title: "Little Wins", values: getFoci(for: record).map(\.activity))
            }
            if includePassions {
                summaryNestedBullets(
                    title: "Passions",
                    values: selectedPassions(for: record.category_id).map { "\(displayEmotionLabel(for: $0.emotion)): \($0.passion)" }
                )
            }
        }
    }

    @ViewBuilder
    private func summarySubBullet(title: String, values: [String]) -> some View {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !cleaned.isEmpty {
            HStack(alignment: .top, spacing: 6) {
                Text("•")
                    .foregroundStyle(.secondary)
                Text("\(title):")
                    .font(.subheadline.weight(.semibold))
                Text(cleaned.joined(separator: ", "))
                    .font(.subheadline)
            }
            .padding(.leading, 12)
        }
    }

    @ViewBuilder
    private func summaryNestedBullets(title: String, values: [String]) -> some View {
        let cleaned = values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

        if !cleaned.isEmpty {
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .top, spacing: 6) {
                    Text("•")
                        .foregroundStyle(.secondary)
                    Text("\(title):")
                        .font(.subheadline.weight(.semibold))
                }
                .padding(.leading, 12)

                ForEach(cleaned, id: \.self) { value in
                    HStack(alignment: .top, spacing: 6) {
                        Text("◦")
                            .foregroundStyle(.secondary)
                        Text(value)
                            .font(.subheadline)
                    }
                    .padding(.leading, 30)
                }
            }
        }
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
                    Text("This is not a goal. It’s the long-term direction you want in this area.")
                        .fontWeight(.bold)
                    Text("Focus on how your life feels, how you show up, and what success looks like.")
                    Text("You can refine this anytime. Start simple.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• I am healthy, energized, and strong, with habits that support long-term vitality and resilience.")
                        .italic()
                    Text("• I feel calm, focused, and in control of this area, which allows me to show up fully in the rest of my life.")
                        .italic()
                    Text("• I consistently grow and improve, creating stability, balance, and confidence in this area.")
                        .italic()
                    Text("• I experience freedom and momentum here, knowing I’m building a strong foundation for my future.")
                        .italic()
                    Text("• This area of my life supports my happiness, creativity, and overall sense of fulfillment.")
                        .italic()
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
            if let record = currentPurposeRecord,
               let suggestions = autoWriteMissionSuggestionsByCategoryID[record.category_id],
               !suggestions.isEmpty {
                VStack(alignment: .leading, spacing: 8) {
                    ForEach(suggestions, id: \.self) { suggestion in
                        let isApplied = appliedAutoWriteMissionSuggestionsByCategoryID[record.category_id]?.contains(suggestion) ?? false
                        Button {
                            purposeDrafts[record.category_id] = suggestion
                            var applied = appliedAutoWriteMissionSuggestionsByCategoryID[record.category_id] ?? Set<String>()
                            applied.insert(suggestion)
                            appliedAutoWriteMissionSuggestionsByCategoryID[record.category_id] = applied
                        } label: {
                            HStack(alignment: .top, spacing: 10) {
                                Image("LoomAI")
                                    .resizable()
                                    .renderingMode(.template)
                                    .scaledToFit()
                                    .frame(width: 16, height: 16)
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                    .padding(.top, 1)
                                Text(suggestion)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                    .multilineTextAlignment(.leading)
                                Spacer(minLength: 0)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                        .disabled(isApplied)
                    }
                }
            }

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
                    Text("Mission is your deeper reason. It keeps you consistent when motivation fades.")
                        .fontWeight(.bold)
                    Text("Think about why this matters and how your life improves when this area strengthens. When strong, everything feels easier.")
                    Text("You can refine this anytime. Start simple.")
                    Text("Examples:")
                        .fontWeight(.bold)
                    Text("• This fuels my energy and confidence so I can show up fully every day.")
                        .italic()
                    Text("• This gives me stability and peace of mind instead of constant stress.")
                        .italic()
                    Text("• Success here creates freedom and momentum across the rest of my life.")
                        .italic()
                    Text("• I want to feel proud of who I am in this area.")
                        .italic()
                    Text("• Neglecting this always leads to bigger problems later, so it’s a must.")
                        .italic()
                    Text("• This helps me feel grounded, focused, and fulfilled instead of reactive.")
                        .italic()
                }
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private struct MissionAutoWriteResponse: Decodable {
        let suggestions: [String]?
        let confidence: String?
    }

    private struct IdentityAutoWriteSuggestion: Hashable, Codable {
        let id: UUID
        let identity: String
        let replaceIdentity: String?

        init(id: UUID = UUID(), identity: String, replaceIdentity: String?) {
            self.id = id
            self.identity = identity
            self.replaceIdentity = replaceIdentity
        }
    }

    private struct IdentityAutoWriteResponse: Decodable {
        let suggestions: [IdentityAutoWriteSuggestionDTO]?
        let confidence: String?
    }

    private struct IdentityAutoWriteSuggestionDTO: Decodable {
        let identity: String?
        let role: String?
        let text: String?
        let replaceIdentity: String?
        let replace: String?
        let weakestIdentity: String?
    }

    private struct LittleWinAutoWriteSuggestion: Hashable, Codable {
        let id: UUID
        let activity: String
        let replaceActivity: String?

        init(id: UUID = UUID(), activity: String, replaceActivity: String?) {
            self.id = id
            self.activity = activity
            self.replaceActivity = replaceActivity
        }
    }

    private struct LittleWinAutoWriteResponse: Decodable {
        let suggestions: [LittleWinAutoWriteSuggestionDTO]?
        let confidence: String?
    }

    private struct LittleWinAutoWriteSuggestionDTO: Decodable {
        let activity: String?
        let littleWin: String?
        let text: String?
        let replaceActivity: String?
        let replace: String?
        let weakestLittleWin: String?
    }

    private func requestAutoWriteMissionSuggestions(for record: Fulfillment) async {
        autoWritingMissionCategoryID = record.category_id
        defer { autoWritingMissionCategoryID = nil }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let existingMission = (purposeDrafts[record.category_id] ?? record.category_purpose)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let instruction = """
            You are helping with Loom Fulfillment Define Mission (AutoWrite).
            Fulfillment Area: \(record.category)
            Current Mission: \(existingMission.isEmpty ? "<empty>" : existingMission)

            Need ideas guidance to follow:
            - Mission is your deeper reason. It keeps you consistent when motivation fades.
            - Think about why this matters and how your life improves when this area strengthens.
            - Keep it simple and practical.

            Return JSON only:
            {"suggestions":["string"],"confidence":"high|medium|low"}

            Rules:
            - 1-2 suggestions
            - each suggestion must be <=120 characters
            - suggestions should be specific to the Fulfillment Area
            - no numbering, no bullets
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWriteMissionSuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }
            autoWriteMissionSuggestionsByCategoryID[record.category_id] = Array(suggestions.prefix(2))
            appliedAutoWriteMissionSuggestionsByCategoryID[record.category_id] = []
        } catch {
            return
        }
    }

    private func decodeAutoWriteMissionSuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(MissionAutoWriteResponse.self, from: data) {
            let normalized = (parsed.suggestions ?? [])
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .map { truncateMissionSuggestion($0, maxLength: 120) }
            return Array(normalized.prefix(2))
        }

        let fallback = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
            .map { truncateMissionSuggestion($0, maxLength: 120) }
        return Array(fallback.prefix(2))
    }

    private func truncateMissionSuggestion(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestAutoWriteIdentitySuggestions(for record: Fulfillment) async {
        autoWritingIdentityCategoryID = record.category_id
        defer { autoWritingIdentityCategoryID = nil }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let rolesNow = getRoles(for: record).map(\.role)
            let roleList = rolesNow.isEmpty ? "<none>" : rolesNow.joined(separator: ", ")

            let instruction = """
            You are helping with Loom Fulfillment Set Identity (AutoWrite).
            Fulfillment Area: \(record.category)
            Current Identities: \(roleList)

            Need ideas guidance to follow:
            - Roles define your identity.
            - They guide how you think, act, and make decisions before results show up.
            - Focus on identities that are clear, empowering, and practical in this area.

            Return JSON only:
            {"suggestions":[{"identity":"string","replaceIdentity":"string optional"}],"confidence":"high|medium|low"}

            Rules:
            - Return 1-2 suggestions.
            - identity must be <=120 characters.
            - If Current Identities already has 3 items, include replaceIdentity for each suggestion.
            - replaceIdentity should be the weakest current identity to replace.
            - No numbering, no bullets, no markdown.
            - Suggestions must be specific to the Fulfillment Area.
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWriteIdentitySuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }
            autoWriteIdentitySuggestionsByCategoryID[record.category_id] = Array(suggestions.prefix(2))
            appliedAutoWriteIdentitySuggestionsByCategoryID[record.category_id] = []
        } catch {
            return
        }
    }

    private func decodeAutoWriteIdentitySuggestions(from raw: String) -> [IdentityAutoWriteSuggestion] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(IdentityAutoWriteResponse.self, from: data) {
            let normalized = (parsed.suggestions ?? [])
                .compactMap { dto -> IdentityAutoWriteSuggestion? in
                    let identityRaw = (dto.identity ?? dto.role ?? dto.text ?? "")
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !identityRaw.isEmpty else { return nil }
                    let replaceRaw = (dto.replaceIdentity ?? dto.replace ?? dto.weakestIdentity ?? "")
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return IdentityAutoWriteSuggestion(
                        identity: truncateMissionSuggestion(identityRaw, maxLength: 120),
                        replaceIdentity: replaceRaw.isEmpty ? nil : truncateMissionSuggestion(replaceRaw, maxLength: 120)
                    )
                }
            return Array(normalized.prefix(2))
        }

        let fallback = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
            .map { IdentityAutoWriteSuggestion(identity: truncateMissionSuggestion($0, maxLength: 120), replaceIdentity: nil) }
        return Array(fallback.prefix(2))
    }

    private func suggestionTopLine(_ suggestion: IdentityAutoWriteSuggestion, category: String, isApplied: Bool) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = (suggestion.replaceIdentity ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let verb = isApplied ? (isReplace ? "Replaced" : "Added") : (isReplace ? "Replace" : "Add")
        if isReplace {
            return trimmedCategory.isEmpty ? "\(verb) Identity:" : "\(verb) Identity in \(trimmedCategory):"
        }
        return trimmedCategory.isEmpty ? "\(verb) Identity:" : "\(verb) Identity to \(trimmedCategory):"
    }

    private func applyIdentityAutoWriteSuggestion(_ suggestion: IdentityAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let newIdentity = suggestion.identity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newIdentity.isEmpty else { return false }

        let existing = getRoles(for: record)
        let normalizedNew = newIdentity.lowercased()
        if existing.contains(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew }) {
            return false
        }

        if existing.count < 3 {
            addRole(text: newIdentity, record: record)
            return true
        }

        let explicitTarget = (suggestion.replaceIdentity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetID = roleReplacementTargetID(for: explicitTarget, roles: existing)
            ?? weakestRoleReplacementID(in: existing),
           let idx = draftRoles.firstIndex(where: { $0.id == targetID }) {
            draftRoles[idx].role = newIdentity
            draftRoles[idx].updatedAt = Date()
            if draftRoles[idx].rank == 1 {
                record.category_identitiy = newIdentity
                record.updatedAt = Date()
            }
            persistDraftIfNeeded()
            return true
        }
        return false
    }

    private func roleReplacementTargetID(for target: String, roles: [DraftRoleRow]) -> UUID? {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else { return nil }
        return roles.first(where: { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTarget })?.id
    }

    private func weakestRoleReplacementID(in roles: [DraftRoleRow]) -> UUID? {
        roles
            .sorted { lhs, rhs in
                let lhsScore = identityStrengthScore(lhs.role)
                let rhsScore = identityStrengthScore(rhs.role)
                if lhsScore == rhsScore { return lhs.rank > rhs.rank }
                return lhsScore < rhsScore
            }
            .first?
            .id
    }

    private func identityStrengthScore(_ role: String) -> Int {
        let normalized = role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return 0 }
        let genericTokens = ["person", "good", "better", "best", "role", "identity", "helper", "worker", "member"]
        if genericTokens.contains(where: { normalized == $0 }) { return 1 }
        if normalized.count <= 4 { return 2 }
        if normalized.split(separator: " ").count <= 1 { return 3 }
        return 4
    }

    private func requestAutoWriteLittleWinSuggestions(for record: Fulfillment) async {
        autoWritingLittleWinCategoryID = record.category_id
        defer { autoWritingLittleWinCategoryID = nil }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let littleWinsNow = getFoci(for: record).map(\.activity)
            let list = littleWinsNow.isEmpty ? "<none>" : littleWinsNow.joined(separator: ", ")
            let mission = (purposeDrafts[record.category_id] ?? record.category_purpose)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            let identitiesNow = getRoles(for: record).map(\.role)
            let identities = identitiesNow.isEmpty ? "<none>" : identitiesNow.joined(separator: ", ")

            let instruction = """
            You are helping with Loom Fulfillment Little Wins (AutoWrite).
            Fulfillment Area: \(record.category)
            Mission: \(mission.isEmpty ? "<none>" : mission)
            Identities: \(identities)
            Current Little Wins: \(list)

            Need ideas guidance to follow:
            - Small actions create momentum.
            - Focus on easy, repeatable 1-3 little wins that are practical in this area.
            - Align suggestions to the Mission and Identities when provided.
            - Keep wording clear and actionable.

            Return JSON only:
            {"suggestions":[{"activity":"string","replaceActivity":"string optional"}],"confidence":"high|medium|low"}

            Rules:
            - Return 1-2 suggestions.
            - activity must be <=120 characters.
            - If Current Little Wins already has 3 items, include replaceActivity for each suggestion.
            - replaceActivity should be the weakest current little win to replace.
            - No numbering, no bullets, no markdown.
            - Suggestions must be specific to the Fulfillment Area.
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWriteLittleWinSuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }
            autoWriteLittleWinSuggestionsByCategoryID[record.category_id] = Array(suggestions.prefix(2))
            appliedAutoWriteLittleWinSuggestionsByCategoryID[record.category_id] = []
        } catch {
            return
        }
    }

    private func decodeAutoWriteLittleWinSuggestions(from raw: String) -> [LittleWinAutoWriteSuggestion] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)

        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(LittleWinAutoWriteResponse.self, from: data) {
            let normalized = (parsed.suggestions ?? [])
                .compactMap { dto -> LittleWinAutoWriteSuggestion? in
                    let activityRaw = (dto.activity ?? dto.littleWin ?? dto.text ?? "")
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    guard !activityRaw.isEmpty else { return nil }
                    let replaceRaw = (dto.replaceActivity ?? dto.replace ?? dto.weakestLittleWin ?? "")
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    return LittleWinAutoWriteSuggestion(
                        activity: truncateMissionSuggestion(activityRaw, maxLength: 120),
                        replaceActivity: replaceRaw.isEmpty ? nil : truncateMissionSuggestion(replaceRaw, maxLength: 120)
                    )
                }
            return Array(normalized.prefix(2))
        }

        let fallback = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
            .map { LittleWinAutoWriteSuggestion(activity: truncateMissionSuggestion($0, maxLength: 120), replaceActivity: nil) }
        return Array(fallback.prefix(2))
    }

    private func littleWinSuggestionTopLine(_ suggestion: LittleWinAutoWriteSuggestion, category: String, isApplied: Bool) -> String {
        let trimmedCategory = category.trimmingCharacters(in: .whitespacesAndNewlines)
        let isReplace = (suggestion.replaceActivity ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        let verb = isApplied ? (isReplace ? "Replaced" : "Added") : (isReplace ? "Replace" : "Add")
        if isReplace {
            return trimmedCategory.isEmpty ? "\(verb) Little Win:" : "\(verb) Little Win in \(trimmedCategory):"
        }
        return trimmedCategory.isEmpty ? "\(verb) Little Win:" : "\(verb) Little Win to \(trimmedCategory):"
    }

    private func applyLittleWinAutoWriteSuggestion(_ suggestion: LittleWinAutoWriteSuggestion, for record: Fulfillment) -> Bool {
        let newActivity = suggestion.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !newActivity.isEmpty else { return false }

        let existing = getFoci(for: record)
        let normalizedNew = newActivity.lowercased()
        if existing.contains(where: { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedNew }) {
            return false
        }

        if existing.count < 3 {
            addFocus(text: newActivity, record: record)
            return true
        }

        let explicitTarget = (suggestion.replaceActivity ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if let targetID = littleWinReplacementTargetID(for: explicitTarget, littleWins: existing)
            ?? weakestLittleWinReplacementID(in: existing),
           let idx = draftFoci.firstIndex(where: { $0.id == targetID }) {
            draftFoci[idx].activity = newActivity
            draftFoci[idx].updatedAt = Date()
            persistDraftIfNeeded()
            return true
        }
        return false
    }

    private func littleWinReplacementTargetID(for target: String, littleWins: [DraftFocusRow]) -> UUID? {
        let normalizedTarget = target.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalizedTarget.isEmpty else { return nil }
        return littleWins.first(where: { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalizedTarget })?.id
    }

    private func weakestLittleWinReplacementID(in littleWins: [DraftFocusRow]) -> UUID? {
        littleWins
            .sorted { lhs, rhs in
                let lhsScore = littleWinStrengthScore(lhs.activity)
                let rhsScore = littleWinStrengthScore(rhs.activity)
                if lhsScore == rhsScore { return lhs.rank > rhs.rank }
                return lhsScore < rhsScore
            }
            .first?
            .id
    }

    private func littleWinStrengthScore(_ activity: String) -> Int {
        let normalized = activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if normalized.isEmpty { return 0 }
        let genericTokens = ["work", "exercise", "task", "habit", "routine", "improve"]
        if genericTokens.contains(where: { normalized == $0 }) { return 1 }
        if normalized.count <= 6 { return 2 }
        if normalized.split(separator: " ").count <= 1 { return 3 }
        return 4
    }

    private func categoryHeader(_ title: String, index: Int, total: Int) -> some View {
        HStack {
            Text(title)
                .font(.headline)
                .foregroundStyle(fulfillmentCategoryColor(for: title))
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

    private func summarySection<Content: View>(
        title: String,
        @ViewBuilder content: () -> Content,
        onEdit: @escaping () -> Void
    ) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
            }
            content()
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
        if Date() < ignoreBackUntil {
            return
        }
        switch step {
        case .createCategories:
            if isAddSingleAreaMode {
                dismiss()
            } else {
                step = .intro
            }
        case .visionSweep:
            step = .createCategories
        case .purposeSweep:
            if purposeIndex > 0 {
                purposeIndex -= 1
            } else {
                step = .createCategories
            }
        case .roles:
            if roleIndex > 0 {
                roleIndex -= 1
            } else {
                step = .purposeSweep
                purposeIndex = max(orderedFulfillments.count - 1, 0)
            }
        case .priorities:
            step = .roles
            roleIndex = max(roleCategoryIDs.count - 1, 0)
        case .littleWins:
            if deepIndex > 0 {
                deepIndex -= 1
            } else {
                step = isAddSingleAreaMode ? .roles : .priorities
            }
        case .resources:
            if deepIndex > 0 {
                deepIndex -= 1
            } else {
                step = .littleWins
                deepIndex = max(deepCategoryIDs.count - 1, 0)
            }
        case .passions:
            if passionIndex > 0 {
                passionIndex -= 1
            } else {
                step = .littleWins
                deepIndex = max(deepCategoryIDs.count - 1, 0)
            }
        case .summary:
            step = .passions
            passionIndex = max(roleCategoryIDs.count - 1, 0)
        case .intro:
            dismiss()
        }
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .createCategories:
            syncSelectedCategoriesIntoFulfillment()
            visionIndex = 0
            purposeIndex = 0
            roleIndex = 0
            deepIndex = 0
            passionIndex = 0
            didOpenPriorities = false
            step = .purposeSweep
        case .visionSweep:
            moveVisionForward(saveCurrent: true)
        case .purposeSweep:
            movePurposeForward(saveCurrent: true)
        case .roles:
            if let record = currentRoleRecord, addingRole {
                commitRole(record)
            }
            if roleIndex < roleCategoryIDs.count - 1 {
                roleIndex += 1
            } else {
                if isAddSingleAreaMode {
                    deepIndex = 0
                    step = .littleWins
                } else {
                    step = .priorities
                    deepIndex = 0
                    if !didOpenPriorities {
                        priorityCategoryIDs.removeAll()
                        didOpenPriorities = true
                    }
                }
            }
        case .priorities:
            deepIndex = 0
            step = .littleWins
        case .littleWins:
            if let record = currentDeepRecord, addingFocus {
                commitFocus(record)
            }
            if deepIndex < deepCategoryIDs.count - 1 {
                deepIndex += 1
            } else {
                passionIndex = 0
                step = .passions
            }
        case .resources:
            passionIndex = 0
            step = .passions
        case .passions:
            if passionIndex < roleCategoryIDs.count - 1 {
                passionIndex += 1
            } else {
                if isAddSingleAreaMode {
                    finalizeAddedAreaAndDismiss()
                } else {
                    step = .summary
                }
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
            roleIndex = 0
            step = .roles
        }
    }

    private func togglePriority(_ id: UUID) {
        if priorityCategoryIDs.contains(id) {
            priorityCategoryIDs.removeAll { $0 == id }
        } else {
            priorityCategoryIDs.append(id)
        }
        if !priorityCategoryIDs.isEmpty {
            highlightInvalid = false
            invalidCategoryIDs.removeAll()
            showValidationHint = false
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
        let categoriesFromLabels = isAddSingleAreaMode ? [] : planLabels
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let existingCategories = Array(Set(categoriesFromFulfillment + categoriesFromLabels))
            .sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
        if isAddSingleAreaMode {
            addModeInitialActiveCategoryKeys = Set(categoriesFromFulfillment.map { categoryKey($0) })
        }
        if isAddSingleAreaMode {
            selectedCategoryNames = []
            customCategoryNames = existingCategories.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        } else {
            selectedCategoryNames = existingCategories
            customCategoryNames = existingCategories.filter { !fulfillmentStartSelectableDefaultCategories.contains($0) }
        }
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

        visionDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_vision) })
        purposeDrafts = Dictionary(uniqueKeysWithValues: orderedFulfillments.map { ($0.category_id, $0.category_purpose) })
        let categoryIDs = Set(orderedFulfillments.map(\.category_id))
        draftRoles = roles
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftRoleRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    role: $0.role,
                    rank: $0.rank
                )
            }
        draftFoci = foci
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftFocusRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    activity: $0.activity,
                    rank: $0.rank
                )
            }
        draftResources = resources
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftResourceRow(
                    id: $0.id,
                    categoryID: $0.category_id,
                    updatedAt: $0.updatedAt,
                    resource: $0.resource,
                    rank: $0.rank
                )
            }
        draftPassionJoins = passionJoins
            .filter { categoryIDs.contains($0.category_id) }
            .map {
                DraftPassionJoinRow(
                    id: $0.id,
                    passionID: $0.passion_id,
                    categoryID: $0.category_id
                )
            }

        priorityCategoryIDs = priorityCategoryIDs.filter { id in
            orderedFulfillments.contains(where: { $0.category_id == id })
        }
        if isAddSingleAreaMode {
            priorityCategoryIDs = []
        }
        visionIndex = min(visionIndex, max(orderedFulfillments.count - 1, 0))
        purposeIndex = min(purposeIndex, max(orderedFulfillments.count - 1, 0))
        roleIndex = min(roleIndex, max(roleCategoryIDs.count - 1, 0))
        deepIndex = min(deepIndex, max(deepCategoryIDs.count - 1, 0))
        passionIndex = min(passionIndex, max(roleCategoryIDs.count - 1, 0))
    }

    private func applyLoomAIPrefillIfAvailable() {
        guard isAddSingleAreaMode, let prefill = LoomAIFulfillmentAreaPrefillStore.take() else { return }

        let categoryName = prefill.categoryName.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !categoryName.isEmpty else { return }

        if !customCategoryNames.contains(where: { $0.caseInsensitiveCompare(categoryName) == .orderedSame }) &&
            !fulfillmentStartSelectableDefaultCategories.contains(where: { $0.caseInsensitiveCompare(categoryName) == .orderedSame }) {
            customCategoryNames.append(categoryName)
        }
        toggleCategorySelection(categoryName, forceSelected: true)
        assignDefaultColorIfNeeded(for: categoryName)

        refreshFulfillmentSnapshot()
        applyCategorySelectionToLiveDataIfNeeded()
        refreshFulfillmentSnapshot()

        guard let record = (fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot).first(where: {
            $0.category.caseInsensitiveCompare(categoryName) == .orderedSame
        }) else {
            return
        }

        if let mission = prefill.mission?.trimmingCharacters(in: .whitespacesAndNewlines), !mission.isEmpty {
            purposeDrafts[record.category_id] = mission
            if let idx = fulfillmentSnapshot.firstIndex(where: { $0.category_id == record.category_id }) {
                fulfillmentSnapshot[idx].category_purpose = mission
            }
        }

        if !prefill.identities.isEmpty {
            var existingRoleTexts = Set(draftRoles
                .filter { $0.categoryID == record.category_id }
                .map { $0.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            var nextRank = (draftRoles.filter { $0.categoryID == record.category_id }.map(\.rank).max() ?? -1) + 1
            for identity in prefill.identities.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }) {
                let key = identity.lowercased()
                guard !existingRoleTexts.contains(key) else { continue }
                draftRoles.append(.init(id: UUID(), categoryID: record.category_id, updatedAt: .now, role: identity, rank: nextRank))
                existingRoleTexts.insert(key)
                nextRank += 1
            }
        }

        if !prefill.littleWins.isEmpty {
            var existingFocusTexts = Set(draftFoci
                .filter { $0.categoryID == record.category_id }
                .map { $0.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() })
            var nextRank = (draftFoci.filter { $0.categoryID == record.category_id }.map(\.rank).max() ?? -1) + 1
            for littleWin in prefill.littleWins.map({ $0.trimmingCharacters(in: .whitespacesAndNewlines) }).filter({ !$0.isEmpty }).prefix(3) {
                let key = littleWin.lowercased()
                guard !existingFocusTexts.contains(key) else { continue }
                draftFoci.append(.init(id: UUID(), categoryID: record.category_id, updatedAt: .now, activity: littleWin, rank: nextRank))
                existingFocusTexts.insert(key)
                nextRank += 1
            }
        }

        if !prefill.connectedPassions.isEmpty {
            var passionsByKey = Dictionary(uniqueKeysWithValues: passions.map {
                ("\(displayEmotionLabel(for: $0.emotion).lowercased())|\($0.passion.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())", $0)
            })
            let existingJoinPassionIDs = Set(draftPassionJoins.filter { $0.categoryID == record.category_id }.map(\.passionID))
            for raw in prefill.connectedPassions {
                let parsed = parsePrefillPassion(raw)
                guard let parsed else { continue }
                let key = "\(parsed.emotion.lowercased())|\(parsed.title.lowercased())"
                let passion: Passion
                if let existing = passionsByKey[key] {
                    passion = existing
                } else {
                    let created = Passion(date: .now, emotion: parsed.emotion.lowercased(), passion: parsed.title)
                    modelContext.insert(created)
                    passionsByKey[key] = created
                    passion = created
                }
                if !existingJoinPassionIDs.contains(passion.passion_id) &&
                    !draftPassionJoins.contains(where: { $0.categoryID == record.category_id && $0.passionID == passion.passion_id }) {
                    draftPassionJoins.append(.init(id: UUID(), passionID: passion.passion_id, categoryID: record.category_id))
                }
            }
        }

        if let idx = orderedFulfillments.firstIndex(where: { $0.category_id == record.category_id }) {
            visionIndex = idx
            purposeIndex = idx
        }
        if let idx = roleCategoryIDs.firstIndex(of: record.category_id) {
            roleIndex = idx
            passionIndex = idx
        }
        step = .visionSweep
    }

    private func parsePrefillPassion(_ raw: String) -> (emotion: String, title: String)? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        let emotions = ["love", "thrill", "vows", "hate"]
        if let colon = trimmed.firstIndex(of: ":") {
            let left = trimmed[..<colon].trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let right = trimmed[trimmed.index(after: colon)...].trimmingCharacters(in: .whitespacesAndNewlines)
            if emotions.contains(left), !right.isEmpty { return (left, right) }
        }
        return ("love", trimmed)
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
            triggerHint("This category has an ongoing action block, group, or outcome.")
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
            var map = categoryColorKeys
            for (idx, category) in fulfillmentStartSelectableDefaultCategories.enumerated() {
                map[category] = cycleKeys[idx % cycleKeys.count]
            }
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
            if isAddSingleAreaMode {
                selectedCategoryNames = [category]
            } else {
                guard selectedCategoryNames.count < 7 else { return }
                if !selectedCategoryNames.contains(category) {
                    selectedCategoryNames.append(category)
                }
            }
            assignDefaultColorIfNeeded(for: category)
        } else {
            if hasOngoingUsage(in: category) {
                triggerHint("This category has an ongoing action block, group, or outcome.")
                return
            }
            selectedCategoryNames.removeAll { $0.caseInsensitiveCompare(category) == .orderedSame }
        }
        applyCategorySelectionToLiveDataIfNeeded()
        persistDraftIfNeeded()
    }

    private func applyCategorySelectionToLiveDataIfNeeded() {
        guard !isAddSingleAreaMode else { return }
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
        let sourceRows = fulfillmentSnapshot.isEmpty ? fulfillments : fulfillmentSnapshot
        let sourceByKey = Dictionary(uniqueKeysWithValues: sourceRows.map { (categoryKey($0.category), $0) })
        let stagedRows: [Fulfillment] = selectedCategoryNames.map { category in
            let key = categoryKey(category)
            if let existing = sourceByKey[key] {
                return existing
            }
            return Fulfillment(
                category_id: UUID(),
                updatedAt: Date(),
                category: category,
                category_identitiy: "",
                category_vision: "",
                category_purpose: ""
            )
        }
        fulfillmentSnapshot = stagedRows

        visionDrafts = Dictionary(uniqueKeysWithValues: stagedRows.map { ($0.category_id, $0.category_vision) })
        purposeDrafts = Dictionary(uniqueKeysWithValues: stagedRows.map { ($0.category_id, $0.category_purpose) })
        visionIndex = min(visionIndex, max(orderedFulfillments.count - 1, 0))
        purposeIndex = min(purposeIndex, max(orderedFulfillments.count - 1, 0))
        roleIndex = min(roleIndex, max(roleCategoryIDs.count - 1, 0))
        deepIndex = min(deepIndex, max(deepCategoryIDs.count - 1, 0))
        passionIndex = min(passionIndex, max(roleCategoryIDs.count - 1, 0))
        persistDraftIfNeeded()
    }

    private func refreshFulfillmentSnapshot() {
        let descriptor = FetchDescriptor<Fulfillment>()
        if let rows = try? modelContext.fetch(descriptor) {
            fulfillmentSnapshot = rows
        }
    }

    private func persistDraftIfNeeded() {
        guard usesDraftPersistence, !didFinalizeOnboarding else { return }
        persistDraft()
    }

    private func persistDraft() {
        let rows = orderedFulfillments
        let rowIDs = Set(rows.map(\.category_id))
        let rolesRows = draftRoles.filter { rowIDs.contains($0.categoryID) }
        let fociRows = draftFoci.filter { rowIDs.contains($0.categoryID) }
        let resourcesRows = draftResources.filter { rowIDs.contains($0.categoryID) }
        let joinRows = draftPassionJoins.filter { rowIDs.contains($0.categoryID) }

        let draft = DraftState(
            stepRawValue: step.rawValue,
            visionIndex: visionIndex,
            purposeIndex: purposeIndex,
            deepIndex: deepIndex,
            passionIndex: passionIndex,
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
            roles: rolesRows,
            foci: fociRows,
            resources: resourcesRows,
            passionJoins: joinRows
        )

        guard let data = try? JSONEncoder().encode(draft) else { return }
        UserDefaults.standard.set(data, forKey: Self.draftStorageKey)
    }

    private func restoreDraftIfAvailable() -> Bool {
        guard let data = UserDefaults.standard.data(forKey: Self.draftStorageKey),
              let draft = try? JSONDecoder().decode(DraftState.self, from: data) else {
            return false
        }
        fulfillmentSnapshot = draft.fulfillments.map {
            Fulfillment(
                category_id: $0.categoryID,
                updatedAt: $0.updatedAt,
                category: $0.category,
                category_identitiy: $0.identity,
                category_vision: $0.vision,
                category_purpose: $0.purpose
            )
        }

        selectedCategoryNames = draft.selectedCategoryNames
        customCategoryNames = draft.customCategoryNames
        deletedDefaultCategoryNames = Set(draft.deletedDefaultCategoryNames)
        // Preserve in-progress onboarding colors first, then fill any missing keys
        // from globally persisted preferences.
        var mergedColors = draft.categoryColorKeys
        for (category, key) in FulfillmentCategoryTheme.persistedColorKeys() where mergedColors[category] == nil {
            mergedColors[category] = key
        }
        categoryColorKeys = mergedColors
        priorityCategoryIDs = draft.priorityCategoryIDs
        draftRoles = draft.roles
        draftFoci = draft.foci
        draftResources = draft.resources
        draftPassionJoins = draft.passionJoins
        let restoredStep = Step(rawValue: draft.stepRawValue) ?? .intro
        visionIndex = max(0, draft.visionIndex)
        purposeIndex = max(0, draft.purposeIndex)
        deepIndex = max(0, draft.deepIndex)
        passionIndex = max(0, draft.passionIndex ?? 0)
        step = restoredStep
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

    private func clearDraft() {
        UserDefaults.standard.removeObject(forKey: Self.draftStorageKey)
    }

    private func assignDefaultColorIfNeeded(for category: String) {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        var map = categoryColorKeys
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
        categoryColorKeys = map
    }

    private func applyColorSelection(for category: String, colorKey: String) {
        guard availableColorOptions(for: category).contains(where: { $0.key == colorKey }) else { return }
        var map = categoryColorKeys
        let resolvedBefore = map[category] ?? FulfillmentCategoryTheme.defaultColorKeys()[category] ?? "blue"
        if let other = map.first(where: { $0.key != category && $0.value == colorKey })?.key {
            map[other] = resolvedBefore
        }
        map[category] = colorKey
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

        commitStagedFulfillmentRowsToContext()
        FulfillmentCategoryTheme.persistColorKeys(categoryColorKeys)
        try? modelContext.save()
        didFinalizeOnboarding = true
        clearDraft()
        dismiss()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            NotificationCenter.default.post(name: Notification.Name("open_fulfillment_after_onboarding"), object: nil)
        }
    }

    private func finalizeAddedAreaAndDismiss() {
        commitStagedFulfillmentRowsToContextAdditive()
        FulfillmentCategoryTheme.persistColorKeys(categoryColorKeys)
        try? modelContext.save()
        didFinalizeOnboarding = true
        dismiss()
    }

    private func commitStagedFulfillmentRowsToContextAdditive() {
        let stagedRows = orderedFulfillments
        let liveRows = (try? modelContext.fetch(FetchDescriptor<Fulfillment>())) ?? []
        let liveRoles = (try? modelContext.fetch(FetchDescriptor<FulfillmentRoles>())) ?? []
        let liveFoci = (try? modelContext.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
        let liveResources = (try? modelContext.fetch(FetchDescriptor<FulfillmentResources>())) ?? []
        let liveJoins = (try? modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []

        var resolvedCategoryIDByDraftID: [UUID: UUID] = [:]
        for staged in stagedRows {
            if let existing = liveRows.first(where: {
                $0.category_id == staged.category_id ||
                categoryKey($0.category) == categoryKey(staged.category)
            }) {
                existing.category = staged.category
                existing.category_identitiy = staged.category_identitiy
                existing.category_vision = staged.category_vision
                existing.category_purpose = staged.category_purpose
                existing.updatedAt = Date()
                resolvedCategoryIDByDraftID[staged.category_id] = existing.category_id
            } else {
                resolvedCategoryIDByDraftID[staged.category_id] = staged.category_id
                modelContext.insert(
                    Fulfillment(
                        category_id: staged.category_id,
                        updatedAt: staged.updatedAt,
                        category: staged.category,
                        category_identitiy: staged.category_identitiy,
                        category_vision: staged.category_vision,
                        category_purpose: staged.category_purpose
                    )
                )
            }
        }

        let keptIDs = Set(resolvedCategoryIDByDraftID.values)
        for role in liveRoles where keptIDs.contains(role.category_id) { modelContext.delete(role) }
        for focus in liveFoci where keptIDs.contains(focus.category_id) { modelContext.delete(focus) }
        for resource in liveResources where keptIDs.contains(resource.category_id) { modelContext.delete(resource) }
        for join in liveJoins where keptIDs.contains(join.category_id) { modelContext.delete(join) }

        for row in draftRoles {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentRoles(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, role: row.role, rank: row.rank))
        }
        for row in draftFoci {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentFocus(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, activity: row.activity, rank: row.rank))
        }
        for row in draftResources {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(FulfillmentResources(id: row.id, category_id: categoryID, updatedAt: row.updatedAt, resource: row.resource, rank: row.rank))
        }
        for row in draftPassionJoins {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(PassionFulfillmentJoin(id: row.id, passion_id: row.passionID, category_id: categoryID))
        }
    }

    private func commitStagedFulfillmentRowsToContext() {
        let stagedRows = orderedFulfillments
        let selectedKeys = Set(selectedCategoryNames.map { categoryKey($0) })
        let liveRows = (try? modelContext.fetch(FetchDescriptor<Fulfillment>())) ?? []
        let liveRoles = (try? modelContext.fetch(FetchDescriptor<FulfillmentRoles>())) ?? []
        let liveFoci = (try? modelContext.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
        let liveResources = (try? modelContext.fetch(FetchDescriptor<FulfillmentResources>())) ?? []
        let liveJoins = (try? modelContext.fetch(FetchDescriptor<PassionFulfillmentJoin>())) ?? []

        // Remove categories not included in this onboarding result.
        let rowsToDelete = liveRows.filter { !selectedKeys.contains(categoryKey($0.category)) }
        if !rowsToDelete.isEmpty {
            let idsToDelete = Set(rowsToDelete.map(\.category_id))
            for role in liveRoles where idsToDelete.contains(role.category_id) {
                modelContext.delete(role)
            }
            for focus in liveFoci where idsToDelete.contains(focus.category_id) {
                modelContext.delete(focus)
            }
            for resource in liveResources where idsToDelete.contains(resource.category_id) {
                modelContext.delete(resource)
            }
            for join in liveJoins where idsToDelete.contains(join.category_id) {
                modelContext.delete(join)
            }
            for row in rowsToDelete {
                modelContext.delete(row)
            }
        }

        var resolvedCategoryIDByDraftID: [UUID: UUID] = [:]
        for staged in stagedRows {
            if let existing = liveRows.first(where: {
                $0.category_id == staged.category_id
                || categoryKey($0.category) == categoryKey(staged.category)
            }) {
                existing.category = staged.category
                existing.category_identitiy = staged.category_identitiy
                existing.category_vision = staged.category_vision
                existing.category_purpose = staged.category_purpose
                existing.updatedAt = Date()
                resolvedCategoryIDByDraftID[staged.category_id] = existing.category_id
            } else {
                resolvedCategoryIDByDraftID[staged.category_id] = staged.category_id
                modelContext.insert(
                    Fulfillment(
                        category_id: staged.category_id,
                        updatedAt: staged.updatedAt,
                        category: staged.category,
                        category_identitiy: staged.category_identitiy,
                        category_vision: staged.category_vision,
                        category_purpose: staged.category_purpose
                    )
                )
            }
        }

        let keptIDs = Set(resolvedCategoryIDByDraftID.values)
        for role in liveRoles where keptIDs.contains(role.category_id) {
            modelContext.delete(role)
        }
        for focus in liveFoci where keptIDs.contains(focus.category_id) {
            modelContext.delete(focus)
        }
        for resource in liveResources where keptIDs.contains(resource.category_id) {
            modelContext.delete(resource)
        }
        for join in liveJoins where keptIDs.contains(join.category_id) {
            modelContext.delete(join)
        }

        for row in draftRoles {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentRoles(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    role: row.role,
                    rank: row.rank
                )
            )
        }
        for row in draftFoci {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentFocus(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    activity: row.activity,
                    rank: row.rank
                )
            )
        }
        for row in draftResources {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                FulfillmentResources(
                    id: row.id,
                    category_id: categoryID,
                    updatedAt: row.updatedAt,
                    resource: row.resource,
                    rank: row.rank
                )
            )
        }
        for row in draftPassionJoins {
            let categoryID = resolvedCategoryIDByDraftID[row.categoryID] ?? row.categoryID
            modelContext.insert(
                PassionFulfillmentJoin(
                    id: row.id,
                    passion_id: row.passionID,
                    category_id: categoryID
                )
            )
        }
    }

    // MARK: - Validation feedback

    private func triggerValidationFeedback() {
        highlightInvalid = true
        invalidCategoryIDs = []

        switch step {
        case .createCategories:
            validationHintText = hasCreateCategoriesColorConflict
                ? "Each color can only be used once."
                : (isAddSingleAreaMode ? "Select 1 category to continue." : "Create at least 3 life categories.")
        case .visionSweep:
            validationHintText = "Add a vision to continue."
            if let record = currentVisionRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .purposeSweep:
            validationHintText = "Add a mission to continue."
            if let record = currentPurposeRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .roles:
            validationHintText = "List 1 or more identities to continue."
            if let record = currentRoleRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .priorities:
            validationHintText = "Choose 1 or more areas than need increased focus."
        case .littleWins:
            validationHintText = "List 1 or more small wins to continue."
            if let record = currentDeepRecord {
                invalidCategoryIDs.insert(record.category_id)
            }
        case .resources:
            validationHintText = "Please continue."
        case .passions:
            validationHintText = "Connect at least 1 passion to continue."
            if let record = currentPassionRecord {
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
                highlightInvalid = false
                invalidCategoryIDs.removeAll()
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    // MARK: - Persistence (mirrors FulfillmentView)

    private func updateVision(record: Fulfillment, newText: String) {
        guard record.category_vision != newText else { return }
        record.category_vision = newText
        record.updatedAt = Date()
        persistDraftIfNeeded()
    }

    private func updatePurpose(record: Fulfillment, newText: String) {
        guard record.category_purpose != newText else { return }
        record.category_purpose = newText
        record.updatedAt = Date()
        persistDraftIfNeeded()
    }

    private func getRoles(for f: Fulfillment) -> [DraftRoleRow] {
        draftRoles.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addRole(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getRoles(for: record).count < 3 else {
            triggerHint("You can add up to 3 roles.")
            return
        }
        guard !roleExists(trimmed) else {
            triggerHint("Duplicate role is already entered.")
            return
        }
        let nextRank = (getRoles(for: record).map(\.rank).max() ?? 0) + 1
        draftRoles.append(
            DraftRoleRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                role: trimmed,
                rank: nextRank
            )
        )
        if nextRank == 1 {
            record.category_identitiy = text
            record.updatedAt = Date()
        }
        persistDraftIfNeeded()
    }

    private func roleExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftRoles.contains { role in
            role.role.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteRoles(at offsets: IndexSet, record: Fulfillment) {
        let list = getRoles(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let r = list[idx]
            draftRoles.removeAll { $0.id == r.id }
        }
        persistDraftIfNeeded()
    }

    private func getFoci(for f: Fulfillment) -> [DraftFocusRow] {
        draftFoci.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addFocus(text: String, record: Fulfillment) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getFoci(for: record).count < 3 else {
            triggerHint("You can add up to 3 little wins.")
            return
        }
        guard !focusExists(trimmed) else {
            triggerHint("Duplicate little win is already entered.")
            return
        }
        let nextRank = (getFoci(for: record).map(\.rank).max() ?? 0) + 1
        draftFoci.append(
            DraftFocusRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                activity: trimmed,
                rank: nextRank
            )
        )
        persistDraftIfNeeded()
    }

    private func focusExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftFoci.contains { row in
            row.activity.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteFoci(at offsets: IndexSet, record: Fulfillment) {
        let list = getFoci(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let f = list[idx]
            draftFoci.removeAll { $0.id == f.id }
        }
        persistDraftIfNeeded()
    }

    private func getResources(for f: Fulfillment) -> [DraftResourceRow] {
        draftResources.filter { $0.categoryID == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addResource(text: String, record: Fulfillment) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        guard getResources(for: record).count < 3 else {
            triggerHint("You can add up to 3 resources.")
            return
        }
        guard !resourceExists(trimmed) else {
            triggerHint("Duplicate resource is already entered.")
            return
        }
        let nextRank = (getResources(for: record).map(\.rank).max() ?? 0) + 1
        draftResources.append(
            DraftResourceRow(
                id: UUID(),
                categoryID: record.category_id,
                updatedAt: Date(),
                resource: trimmed,
                rank: nextRank
            )
        )
        persistDraftIfNeeded()
    }

    private func resourceExists(_ text: String) -> Bool {
        let normalized = text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !normalized.isEmpty else { return false }
        return draftResources.contains { row in
            row.resource.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
    }

    private func deleteResources(at offsets: IndexSet, record: Fulfillment) {
        let list = getResources(for: record)
        for idx in offsets {
            guard list.indices.contains(idx) else { continue }
            let r = list[idx]
            draftResources.removeAll { $0.id == r.id }
        }
        persistDraftIfNeeded()
    }

    private func selectedPassionIDs(for categoryID: UUID) -> Set<UUID> {
        Set(
            draftPassionJoins
                .filter { $0.categoryID == categoryID }
                .map(\.passionID)
        )
    }

    private func selectedPassions(for categoryID: UUID) -> [Passion] {
        let ids = selectedPassionIDs(for: categoryID)
        return passions.filter { ids.contains($0.passion_id) }
    }

    private func displayEmotionLabel(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "just": return "Hate"
        case "vows": return "Vow"
        default: return raw.capitalized
        }
    }

    private func togglePassion(_ passion: Passion, for categoryID: UUID) {
        let existing = draftPassionJoins.first {
            $0.passionID == passion.passion_id && $0.categoryID == categoryID
        }

        if let existing {
            draftPassionJoins.removeAll { $0.id == existing.id }
        } else {
            draftPassionJoins.append(
                DraftPassionJoinRow(
                    id: UUID(),
                    passionID: passion.passion_id,
                    categoryID: categoryID
                )
            )
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

struct FulfillmentIntroRouteLinesView: View {
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
    let options: [FulfillmentCategoryTheme.PaletteOption]
    let showsCloseButton: Bool
    let onSelect: (String) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(options, id: \.key) { option in
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
                if showsCloseButton {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("Close") { dismiss() }
                    }
                }
            }
        }
    }
}

private extension FulfillmentStartView {
    private var shouldShowMissionAutoWriteControls: Bool {
        step == .purposeSweep && currentPurposeRecord != nil
    }

    private var shouldShowIdentityAutoWriteControls: Bool {
        step == .roles && currentRoleRecord != nil
    }

    private var shouldShowLittleWinAutoWriteControls: Bool {
        step == .littleWins && currentDeepRecord != nil
    }

    private var autoWriteGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(autoWriteOutlineAngle)
        )
    }

    private var autoWriteSuggestionCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.98, green: 0.36, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionSecondaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return Color.white.opacity(0.86) }
        return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
    }

    private func autoWriteSuggestionBackgroundFill(isApplied: Bool) -> AnyShapeStyle {
        if isApplied {
            if colorScheme == .dark {
                return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.34))
            } else {
                return AnyShapeStyle(Color(red: 0.90, green: 0.97, blue: 0.92))
            }
        }
        return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.92))
    }

    private func autoWriteSuggestionBorderColor(isApplied: Bool) -> Color {
        if isApplied {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.green.opacity(0.30)
        }
        return Color.white.opacity(0.24)
    }

    @ViewBuilder
    private var missionAutoWriteControls: some View {
        if let record = currentPurposeRecord {
            let isLoading = autoWritingMissionCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteMissionSuggestions(for: record) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var identityAutoWriteControls: some View {
        if let record = currentRoleRecord {
            let isLoading = autoWritingIdentityCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteIdentitySuggestions(for: record) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    @ViewBuilder
    private var littleWinAutoWriteControls: some View {
        if let record = currentDeepRecord {
            let isLoading = autoWritingLittleWinCategoryID == record.category_id

            VStack(alignment: .trailing, spacing: 8) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWriteLittleWinSuggestions(for: record) }
                } label: {
                    HStack(spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        Text("AutoWrite")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(autoWriteGradient)
                    }
                    .padding(.horizontal, 15)
                    .padding(.vertical, 9)
                    .background(
                        Capsule()
                            .fill(Color(.systemGroupedBackground))
                    )
                    .overlay(
                        Capsule()
                            .stroke(autoWriteGradient, lineWidth: 2.25)
                    )
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)
                .onAppear {
                    guard autoWriteOutlineAngle == 0 else { return }
                    withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                        autoWriteOutlineAngle = 360
                    }
                }
                .onChange(of: isLoading, initial: false) { _, newValue in
                    setAutoWriteLoadingAnimation(newValue)
                }
            }
        }
    }

    private func setAutoWriteLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimating = false
            autoWriteIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        autoWriteIconAnimating.toggle()
                    }
                    try? await Task.sleep(for: .milliseconds(550))
                }
            }
        } else {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoWriteIconAnimating = false
            }
        }
    }
}
