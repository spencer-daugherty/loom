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

struct FulfillmentStartView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]

    @State private var navigateToFulfillment = false

    @State private var step: Step = .intro
    @State private var visionIndex: Int = 0
    @State private var purposeIndex: Int = 0
    @State private var priorityCategoryIDs: [UUID] = []
    @State private var deepIndex: Int = 0

    @State private var visionDrafts: [UUID: String] = [:]
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var roleEntry: String = ""
    @State private var focusEntry: String = ""
    @State private var resourceEntry: String = ""

    @State private var addingRole = false
    @State private var addingFocus = false
    @State private var addingResource = false
    @State private var addingCategory = false
    @State private var newCategoryText = ""

    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPurpose = false

    @State private var showValidationHint = false
    @State private var validationHintText = ""
    @State private var hintWorkItem: DispatchWorkItem?
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
            case .visionSweep: return "Fast Vision Sweep"
            case .purposeSweep: return "Fast Purpose Sweep"
            case .priorities: return "Select Priority Categories"
            case .roles: return "Roles"
            case .threeToThrive: return "Three-to-Thrive"
            case .resources: return "Resources"
            case .passions: return "Passions"
            case .summary: return "Summary"
            }
        }
    }

    private var orderedFulfillments: [Fulfillment] {
        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
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
        let names = orderedFulfillments
            .map { $0.category.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard names.count >= 3 else { return false }
        let uniqueCount = Set(names.map { $0.lowercased() }).count
        return uniqueCount == names.count
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
            footer
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step != .intro)
        .onAppear(perform: loadFromPersistentData)
        .navigationDestination(isPresented: $navigateToFulfillment) {
            FulfillmentView()
        }
        .overlay(alignment: .bottom) {
            if showValidationHint {
                Text(validationHintText)
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
                    Text("Start Building Momentum")
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
            Text("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                .foregroundStyle(.secondary)
            Text("They're never finished. You continually improve them to stay moving forward.")
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var createCategoriesStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Create your categories first, then move into fast alignment.")
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(orderedFulfillments, id: \.category_id) { record in
                    HStack(spacing: 8) {
                        TextField(
                            "Category",
                            text: Binding(
                                get: { record.category },
                                set: { newValue in
                                    record.category = newValue
                                    record.updatedAt = Date()
                                    try? modelContext.save()
                                }
                            )
                        )
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)

                        Button(role: .destructive) {
                            deleteCategory(record)
                        } label: {
                            Image(systemName: "minus.circle.fill")
                        }
                        .buttonStyle(.plain)
                        .disabled(orderedFulfillments.count <= 3)
                    }
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(rowSurfaceColor)
                }

                if addingCategory {
                    TextField("New Category", text: $newCategoryText)
                        .textInputAutocapitalization(.words)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)
                        .onSubmit(addCategory)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(rowSurfaceColor)
                } else {
                    Button("+ Add Category") {
                        addingCategory = true
                        newCategoryText = ""
                    }
                    .foregroundStyle(.blue)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(rowSurfaceColor)
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(canStartOnboarding ? Color.clear : Color.red.opacity(0.35), lineWidth: canStartOnboarding ? 0 : 1)
            )

            Text("Minimum 3 unique categories")
                .font(.caption)
                .foregroundStyle(canStartOnboarding ? Color.secondary : Color.red)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var visionSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentVisionRecord {
                phaseSubtext("Phase 1: Quick Alignment")
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

                Button("Skip and return later") {
                    moveVisionForward(saveCurrent: false)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)

                visionIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var purposeSweepStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let record = currentPurposeRecord {
                phaseSubtext("Phase 1: Quick Alignment")
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

                Button("Skip and return later") {
                    movePurposeForward(saveCurrent: false)
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
                .buttonStyle(.plain)

                purposeIdeasExpander
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var prioritiesStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            phaseSubtext("Phase 2: Prioritization")
            Text("Most people try to improve everything and fail. Choose the 2–3 areas where progress will change your life the most.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

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
                phaseSubtext("Phase 3: Deep Design")
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
                                    try? modelContext.save()
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

        phaseSubtext("Phase 3: Deep Design")
        categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
        Text("What 3 focus areas will create the most impact here?")
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
                            try? modelContext.save()
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
                phaseSubtext("Phase 3: Deep Design")
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
                                    try? modelContext.save()
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
                phaseSubtext("Phase 3: Deep Design")
                categoryHeader(record.category, index: deepIndex + 1, total: deepCategoryIDs.count)
                Text("Connect passions from your Driving Force.")
                    .font(.headline)

                VStack(spacing: 8) {
                    ForEach(passions, id: \.passion_id) { passion in
                        let isSelected = selectedPassionIDs(for: record.category_id).contains(passion.passion_id)
                        Button {
                            togglePassion(passion, for: record.category_id)
                            try? modelContext.save()
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
            phaseSubtext("Phase 4: Completion")

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
            try? modelContext.save()
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
            try? modelContext.save()
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
    }

    // MARK: - Data load & finalize

    private func loadFromPersistentData() {
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
        let duplicate = orderedFulfillments.contains {
            $0.category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased()
        }
        guard !duplicate else {
            triggerHint("Duplicate category name.")
            return
        }
        let record = Fulfillment(
            category_id: UUID(),
            updatedAt: Date(),
            category: trimmed,
            category_identitiy: "",
            category_vision: "",
            category_purpose: ""
        )
        modelContext.insert(record)
        try? modelContext.save()
        addingCategory = false
        newCategoryText = ""
    }

    private func deleteCategory(_ record: Fulfillment) {
        guard orderedFulfillments.count > 3 else {
            triggerHint("Keep at least 3 categories.")
            return
        }
        RecentlyDeletedStore.trash(record, in: modelContext)
        try? modelContext.save()
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

        navigateToFulfillment = true
    }

    // MARK: - Validation feedback

    private func triggerValidationFeedback() {
        highlightInvalid = true
        invalidCategoryIDs = []

        switch step {
        case .createCategories:
            validationHintText = "Add at least 3 unique category names."
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
        try? modelContext.save()
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
        try? modelContext.save()
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
        try? modelContext.save()
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
