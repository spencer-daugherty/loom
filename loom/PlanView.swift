import SwiftUI
import SwiftData

/// Step 1 of a multi-step flow.
/// UI-only: Three one-line text fields with a bottom-pinned "Next" + "Close" button.
struct PlanView: View {
    @State private var morningPowerQuestion: String = ""
    @State private var gratefulFor: String = ""
    @State private var incantation: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse)
    private var allWeeklyMindsetEntries: [WeeklyMindsetEntry.Fields]

    @State private var navigateToStep2: Bool = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case morning, grateful, incantation }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var existingEntryForWeek: WeeklyMindsetEntry.Fields? {
        allWeeklyMindsetEntries.first { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var isNextDisabled: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("Weekly Planning")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            VStack(alignment: .leading, spacing: 8) {
                Text("Morning Power Question")
                    .font(.headline)
                Text("What am I happy about in life right now?")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
                TextField("My dreams, aspirations, and goals", text: $morningPowerQuestion)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .morning)
                    .onSubmit { focusedField = .grateful }
            }
            .padding(.top, 16)

            VStack(alignment: .leading, spacing: 8) {
                Text("What am I grateful for?")
                    .font(.headline)
                TextField("Health", text: $gratefulFor)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .grateful)
                    .onSubmit { focusedField = .incantation }
            }

            VStack(alignment: .leading, spacing: 8) {
                Text("Incantation")
                    .font(.headline)
                Text("What’s a simple phrase to set your mindset?")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
                TextField("Where I focus improves", text: $incantation)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .incantation)
                    .onSubmit {
                        if isNextDisabled { return }
                        saveStepOneAndAdvance()
                    }
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    saveStepOneAndAdvance()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isNextDisabled)
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        // IMPORTANT: keep only ONE modal host; navigate steps *inside* that host.
        .fullScreenCover(isPresented: $navigateToStep2) {
            PlanFlowHostView()
        }
        .onAppear {
            // Hydrate Step 1 from persisted weekly record if present.
            if let existing = existingEntryForWeek {
                morningPowerQuestion = existing.morningPowerQuestion
                gratefulFor = existing.gratitude
                incantation = existing.incantation
            }

            DispatchQueue.main.async {
                focusedField = .morning
            }
        }
    }

    private func saveStepOneAndAdvance() {
        let trimmedMorning = morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedGratitude = gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedIncantation = incantation.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = existingEntryForWeek {
            existing.createdAt = .now
            existing.morningPowerQuestion = trimmedMorning
            existing.gratitude = trimmedGratitude
            existing.incantation = trimmedIncantation
        } else {
            let entry = WeeklyMindsetEntry.Fields(
                createdAt: .now,
                morningPowerQuestion: trimmedMorning,
                gratitude: trimmedGratitude,
                incantation: trimmedIncantation
            )
            modelContext.insert(entry)
        }

        try? modelContext.save()
        navigateToStep2 = true
    }
}

// MARK: - Single modal host for steps 2–5 (prevents stacked fullScreenCover text input bugs)

private struct PlanFlowHostView: View {
    @Environment(\.dismiss) private var dismiss

    @State private var step: Int = 2

    var body: some View {
        ZStack {
            switch step {
            case 2:
                PlanStepTwoView(onBack: { dismiss() }, onNext: { step = 3 })
            case 3:
                PlanStepThreeView(onBack: { step = 2 }, onNext: { step = 4 })
            case 4:
                PlanStepFourView(onBack: { step = 3 }, onNext: { step = 5 })
            default:
                PlanStepFiveView(onBack: { step = 4 })
            }
        }
    }
}

// MARK: - Step 2

struct PlanStepTwoView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @State private var input: String = ""
    @State private var showHidden: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var baselineItemIDs: Set<UUID> = []
    @State private var isBrainstormExpanded: Bool = false

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var displayItems: [RollingCaptureItem] {
        if !showHidden {
            return allItems
                .filter { !$0.isGhost }
                .sorted { $0.createdAt > $1.createdAt }
        }

        return allItems.sorted { lhs, rhs in
            let lhsIsBaseline = baselineItemIDs.contains(lhs.id)
            let rhsIsBaseline = baselineItemIDs.contains(rhs.id)

            func rank(_ item: RollingCaptureItem, isBaseline: Bool) -> Int {
                if !isBaseline, !item.isGhost { return 0 }
                if item.isGhost { return 1 }
                return 2
            }

            let rL = rank(lhs, isBaseline: lhsIsBaseline)
            let rR = rank(rhs, isBaseline: rhsIsBaseline)

            if rL != rR { return rL < rR }
            return lhs.createdAt > rhs.createdAt
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Capture")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isBrainstormExpanded {
                        (
                            Text("Brainstorm: ")
                                .fontWeight(.bold)
                            + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isBrainstormExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            (
                                Text("Brainstorm: ")
                                    .fontWeight(.bold)
                                + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
                            )
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                            Button("Show more") { isBrainstormExpanded = true }
                                .font(.subheadline)
                                .layoutPriority(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Toggle(isOn: $showHidden) { EmptyView() }
                    .labelsHidden()

                Image(systemName: hiddenUntilLaterIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showHidden ? .blue : .secondary)
                    .accessibilityHidden(true)

                Text("Show Actions Hidden Until Later")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            List {
                ForEach(displayItems) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        if baselineItemIDs.contains(item.id) {
                            Image(systemName: "plus.viewfinder")
                                .foregroundStyle(.secondary)
                        } else if showHidden, item.isGhost {
                            Image(systemName: hiddenUntilLaterIconName)
                                .foregroundStyle(.blue)
                        }

                        Text(item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        if item.isGhost {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.blue)
                        }
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            HStack(spacing: 12) {
                TextField("Add an action…", text: $input)
                    .textInputAutocapitalization(.none)
                    .autocorrectionDisabled(true)
                    .focused($isInputFocused)
                    .submitLabel(.done)
                    .onSubmit(addItem)
                    .padding(12)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3), lineWidth: 1)
                    )
                    .layoutPriority(1)
                    .frame(maxWidth: .infinity)
            }
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if let onNext { onNext() }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .onAppear {
            if baselineItemIDs.isEmpty {
                baselineItemIDs = Set(allItems.map(\.id))
            }
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: isInputFocused) { _, newValue in
            if newValue == false {
                DispatchQueue.main.async {
                    isInputFocused = true
                }
            }
        }
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newItem = RollingCaptureItem(
            text: trimmed,
            isGhost: false,
            createdAt: .now,
            unhideDate: nil,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)
        try? modelContext.save()

        input = ""
        isInputFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        for offset in offsets {
            let item = displayItems[offset]
            modelContext.delete(item)
        }
        try? modelContext.save()
    }
}

// MARK: - Step 3

struct PlanStepThreeView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @Query(sort: \PlanLabel.category, order: .forward)
    private var allPlanLabels: [PlanLabel]

    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse)
    private var allChunkSelections: [PlanChunkSelection]

    @Query(sort: \PlannedChunk.updatedAt, order: .reverse)
    private var plannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse)
    private var plannedActions: [PlannedChunkAction]

    @State private var showHidden: Bool = false
    @State private var isCategorizeExpanded: Bool = false

    @State private var poolItemIDs: [UUID] = []
    @State private var chunks: [ChunkContainerState] = []

    @State private var baselineShowHidden: Bool = false
    @State private var baselinePoolItemIDs: [UUID] = []
    @State private var baselineChunks: [ChunkContainerState] = []

    @State private var isHydratingFromStorage: Bool = false

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let maxChunks = 5

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var defaultLabels: [PlanLabel] {
        allPlanLabels
            .filter { $0.source == "default" }
            .sorted {
                if $0.category != $1.category { return $0.category < $1.category }
                return $0.label < $1.label
            }
    }

    private var selectedLabelIDs: Set<UUID> {
        Set(chunks.compactMap(\.selectionLabelId))
    }

    private func labelsByCategory(for chunkIndex: Int) -> [(category: String, labels: [PlanLabel])] {
        let currentSelection = chunks.indices.contains(chunkIndex) ? chunks[chunkIndex].selectionLabelId : nil

        let available = defaultLabels.filter { label in
            if let currentSelection, label.labelId == currentSelection { return true }
            return !selectedLabelIDs.contains(label.labelId)
        }

        let grouped = Dictionary(grouping: available, by: \.category)
        return grouped.keys.sorted().map { key in
            (category: key, labels: grouped[key]!.sorted { $0.label < $1.label })
        }
    }

    private var qualifyingChunkIndices: [Int] {
        chunks.indices.filter { chunks[$0].itemIDs.count >= 3 }
    }

    private var isStep3NextEnabled: Bool {
        let qualifying = qualifyingChunkIndices
        guard qualifying.count >= 2 else { return false }
        return qualifying.allSatisfy { chunks[$0].selectionLabelId != nil }
    }

    private var isRefreshVisible: Bool {
        showHidden != baselineShowHidden ||
        poolItemIDs != baselinePoolItemIDs ||
        chunks != baselineChunks ||
        isPersistedPlanOutOfSyncWithCapture
    }

    private var isPersistedPlanOutOfSyncWithCapture: Bool {
        let weekChunks = plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekActions = plannedActions.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekSelections = allChunkSelections.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        if weekChunks.isEmpty && weekActions.isEmpty && weekSelections.isEmpty {
            return false
        }

        let captureTextSet = Set(allItems.map(\.text))
        if weekActions.contains(where: { !captureTextSet.contains($0.text) }) {
            return true
        }

        let plannedTextSet = Set(weekActions.map(\.text))
        let visibleCaptureItems = (showHidden ? allItems : allItems.filter { !$0.isGhost })

        if visibleCaptureItems.contains(where: { !plannedTextSet.contains($0.text) }) {
            return true
        }

        return false
    }

    private var hasHiddenActionInAnyChunk: Bool {
        guard !chunks.isEmpty else { return false }

        let ghostIDs = Set(allItems.filter(\.isGhost).map(\.id))
        guard !ghostIDs.isEmpty else { return false }

        return chunks.contains { chunk in
            chunk.itemIDs.contains { ghostIDs.contains($0) }
        }
    }

    private func chunkLightFillColor(categoryName: String?) -> Color {
        guard let categoryName else {
            return Color(.secondarySystemBackground)
        }
        return FulfillmentCategoryColors.lightColor(for: categoryName)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Chunk")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                VStack(alignment: .leading, spacing: 6) {
                    if isCategorizeExpanded {
                        (
                            Text("Categorize: ")
                                .fontWeight(.bold)
                            + Text("Look at your Capture list and ask, which items are related to a similar topic?")
                        )
                        .foregroundStyle(.secondary)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)

                        Button("Show less") { isCategorizeExpanded = false }
                            .font(.subheadline)
                    } else {
                        HStack(alignment: .firstTextBaseline, spacing: 6) {
                            (
                                Text("Categorize: ")
                                    .fontWeight(.bold)
                                + Text("Look at your Capture list and ask, which items are related to a similar topic?")
                            )
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                            .lineLimit(1)
                            .truncationMode(.tail)

                            Button("Show more") { isCategorizeExpanded = true }
                                .font(.subheadline)
                                .layoutPriority(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 10) {
                Toggle(
                    isOn: Binding(
                        get: { showHidden },
                        set: { newValue in
                            if hasHiddenActionInAnyChunk && newValue == false {
                                showHidden = true
                                return
                            }
                            showHidden = newValue
                        }
                    )
                ) { EmptyView() }
                .labelsHidden()
                .disabled(hasHiddenActionInAnyChunk)

                Image(systemName: hiddenUntilLaterIconName)
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showHidden ? .blue : .secondary)
                    .accessibilityHidden(true)

                Text("Show Actions Hidden Until Later")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }

            List {
                ForEach(poolItems) { item in
                    rowView(
                        text: item.text,
                        showGhostOutline: item.isGhost,
                        isDraggable: true,
                        dragPayload: DragPayload(itemID: item.id)
                    )
                    .contentShape(Rectangle())
                    .dropDestination(for: DragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        moveItemToPool(payload.itemID)

                        enforceShowHiddenIfNeeded()
                        persistStep3Plan()
                        return true
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                }
                .listRowSeparator(.visible)
            }
            .listRowSpacing(4)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)

                enforceShowHiddenIfNeeded()
                persistStep3Plan()
                return true
            }
            .onChange(of: showHidden) { _, _ in
                enforceShowHiddenIfNeeded()
                syncPoolWithVisibility()
                persistStep3Plan()
            }

            List {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, _ in
                    chunkContainerView(chunkIndex: index)
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }

                if chunks.count < maxChunks {
                    addChunkRow
                        .listRowInsets(EdgeInsets(top: 8, leading: 0, bottom: 8, trailing: 0))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if isRefreshVisible {
                Button { refreshStep3() } label: {
                    Text("Refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
            }

            HStack(spacing: 12) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    if let onNext { onNext() }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isStep3NextEnabled)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .onAppear {
            PlanLabelSeeder.seedDefaultsIfNeeded(in: modelContext)

            if chunks.isEmpty {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }

            hydrateStep3FromStorageOrInitialize()

            enforceShowHiddenIfNeeded()

            if baselineChunks.isEmpty && baselinePoolItemIDs.isEmpty {
                let weekChunks = plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
                let weekActions = plannedActions.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
                let weekSelections = allChunkSelections.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

                let hasAnyPersisted = !(weekChunks.isEmpty && weekActions.isEmpty && weekSelections.isEmpty)
                if !hasAnyPersisted {
                    baselineShowHidden = showHidden
                    baselinePoolItemIDs = poolItemIDs
                    baselineChunks = chunks
                }
            }
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            enforceShowHiddenIfNeeded()
            syncPoolWithVisibility()
            persistStep3Plan()
        }
        .onChange(of: allItems.map(\.isGhost)) { _, _ in
            enforceShowHiddenIfNeeded()
            syncPoolWithVisibility()
            persistStep3Plan()
        }
    }

    private var addChunkRow: some View {
        Button {
            addChunkContainer()
            persistStep3Plan()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.system(size: 16, weight: .bold))
                Text("Add Chunk")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity, minHeight: 48)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.25),
                    lineWidth: 1
                )
        )
    }

    private var visibleItems: [RollingCaptureItem] {
        let base = showHidden ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            return $0.createdAt > $1.createdAt
        }
    }

    private var initialPoolIDs: [UUID] {
        visibleItems.map(\.id)
    }

    private var poolItems: [RollingCaptureItem] {
        let byID = Dictionary(uniqueKeysWithValues: visibleItems.map { ($0.id, $0) })
        return poolItemIDs.compactMap { byID[$0] }
    }

    private func enforceShowHiddenIfNeeded() {
        if hasHiddenActionInAnyChunk && showHidden == false {
            showHidden = true
        }
    }

    @ViewBuilder
    private func rowView(
        text: String,
        showGhostOutline: Bool,
        isDraggable: Bool,
        dragPayload: DragPayload?
    ) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Drag")
                .contentShape(Rectangle())
                .padding(.leading, 4)
                .if(isDraggable && dragPayload != nil, transform: { view in
                    view.draggable(dragPayload!) {
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(text)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: 320)
                    }
                })
        }
        .padding(8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        .overlay {
            if showGhostOutline {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                    .foregroundStyle(.blue)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func chunkContainerView(chunkIndex: Int) -> some View {
        let chunk = chunks[chunkIndex]
        let showDeleteX = chunkIndex >= 2
        let canDeleteThisChunk = canDeleteChunk(at: chunkIndex)

        let fill = chunkLightFillColor(categoryName: chunk.selectionCategory)

        VStack(spacing: 10) {
            HStack(alignment: .center, spacing: 6) {
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle((colorScheme == .dark && chunk.selectionLabelId != nil) ? Color.black : Color.secondary)

                Picker(
                    "",
                    selection: Binding(
                        get: { chunks[chunkIndex].selectionLabelId },
                        set: { newValue in
                            setChunkSelection(chunkIndex: chunkIndex, toLabelId: newValue)
                            persistStep3Plan()
                        }
                    )
                ) {
                    Text("Select…").tag(UUID?.none)

                    ForEach(labelsByCategory(for: chunkIndex), id: \.category) { section in
                        Section(section.category) {
                            ForEach(section.labels, id: \.labelId) { label in
                                Text(label.label)
                                    .tag(Optional(label.labelId))
                            }
                        }
                    }
                }
                .pickerStyle(.menu)

                Spacer(minLength: 0)

                if showDeleteX {
                    Button {
                        deleteChunkContainerIfAllowed(at: chunkIndex)
                        persistStep3Plan()
                    } label: {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .opacity(canDeleteThisChunk ? 1.0 : 0.35)
                            .accessibilityLabel("Delete chunk")
                    }
                    .buttonStyle(.plain)
                    .disabled(!canDeleteThisChunk)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 0) {
                if chunk.itemIDs.isEmpty {
                    Text("Drag actions here")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .padding(.vertical, 14)
                        .frame(maxWidth: .infinity)
                } else {
                    ForEach(chunkItems(for: chunkIndex)) { item in
                        rowView(
                            text: item.text,
                            showGhostOutline: item.isGhost,
                            isDraggable: true,
                            dragPayload: DragPayload(itemID: item.id)
                        )
                        .contentShape(Rectangle())
                        .dropDestination(for: DragPayload.self) { payloads, _ in
                            guard let payload = payloads.first else { return false }
                            moveItem(payload.itemID, toChunkAt: chunkIndex)

                            enforceShowHiddenIfNeeded()
                            persistStep3Plan()
                            return true
                        }
                    }
                }
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(fill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.18), lineWidth: 1)
        )
        .dropDestination(for: DragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            moveItem(payload.itemID, toChunkAt: chunkIndex)

            enforceShowHiddenIfNeeded()
            persistStep3Plan()
            return true
        }
    }

    private func chunkItems(for chunkIndex: Int) -> [RollingCaptureItem] {
        let ids = chunks[chunkIndex].itemIDs
        let byID = Dictionary(uniqueKeysWithValues: visibleItems.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    private func setChunkSelection(chunkIndex: Int, toLabelId newLabelId: UUID?) {
        chunks[chunkIndex].selectionLabelId = newLabelId

        guard let newLabelId else {
            chunks[chunkIndex].selectionLabel = nil
            chunks[chunkIndex].selectionCategoryId = nil
            chunks[chunkIndex].selectionCategory = nil
            return
        }

        guard let selected = defaultLabels.first(where: { $0.labelId == newLabelId }) else {
            chunks[chunkIndex].selectionLabel = nil
            chunks[chunkIndex].selectionCategoryId = nil
            chunks[chunkIndex].selectionCategory = nil
            return
        }

        chunks[chunkIndex].selectionLabel = selected.label
        chunks[chunkIndex].selectionCategoryId = selected.categoryId
        chunks[chunkIndex].selectionCategory = selected.category
    }

    private func refreshStep3() {
        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }

        showHidden = false

        chunks = [
            ChunkContainerState(isLocked: true),
            ChunkContainerState(isLocked: true),
        ]

        poolItemIDs = allItems
            .filter { !$0.isGhost }
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.id)

        clearPersistedStep3PlanForCurrentWeek()
        persistStep3Plan()

        baselineShowHidden = showHidden
        baselinePoolItemIDs = poolItemIDs
        baselineChunks = chunks
    }

    /// Clears only Step 3's persisted records for the current week, while preserving `PlannedChunk` IDs
    /// whenever possible (so Step 4 can keep referencing `plannedChunkId`).
    ///
    /// - Deletes: PlannedChunkAction (week), PlanChunkSelection (week)
    /// - Adjusts/Deletes: PlannedChunk to match current indices (week) via `persistStep3Plan()`
    private func clearPersistedStep3PlanForCurrentWeek() {
        for action in plannedActions where Calendar.current.isDate(action.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(action)
        }
        for sel in allChunkSelections where Calendar.current.isDate(sel.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(sel)
        }
        try? modelContext.save()
    }

    private func hydrateStep3FromStorageOrInitialize() {
        guard poolItemIDs.isEmpty else { return }

        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }

        let persistedChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        let persistedActions = plannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        let persistedSelections = allChunkSelections
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        if persistedChunks.isEmpty && persistedActions.isEmpty && persistedSelections.isEmpty {
            if chunks.isEmpty || chunks.count < 2 {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }

            poolItemIDs = initialPoolIDs
            syncPoolWithVisibility()
            persistStep3Plan()

            baselineShowHidden = showHidden
            baselinePoolItemIDs = poolItemIDs
            baselineChunks = chunks
            return
        }

        let ghostTextSetForWeek: Set<String> = {
            let chunkIDs = Set(persistedChunks.map(\.id))
            let texts = persistedActions
                .filter { chunkIDs.contains($0.plannedChunkId) }
                .map(\.text)
            return Set(texts)
        }()

        if !ghostTextSetForWeek.isEmpty {
            let hasGhostInPersistedPlan = allItems.contains { item in
                item.isGhost && ghostTextSetForWeek.contains(item.text)
            }
            if hasGhostInPersistedPlan {
                showHidden = true
            }
        }

        let maxIndex = persistedChunks.map(\.chunkIndex).max() ?? 1
        let desiredCount = min(maxChunks, max(2, maxIndex + 1))

        chunks = (0..<desiredCount).map { idx in
            ChunkContainerState(isLocked: idx < 2)
        }

        for sel in persistedSelections {
            guard sel.chunkIndex >= 0, sel.chunkIndex < chunks.count else { continue }
            chunks[sel.chunkIndex].selectionLabelId = sel.labelId
            chunks[sel.chunkIndex].selectionLabel = sel.label
            chunks[sel.chunkIndex].selectionCategoryId = sel.categoryId
            chunks[sel.chunkIndex].selectionCategory = sel.category
        }

        // Map persisted actions -> visible capture items by text
        for pc in persistedChunks {
            guard pc.chunkIndex >= 0, pc.chunkIndex < chunks.count else { continue }

            if chunks[pc.chunkIndex].selectionLabelId == nil {
                chunks[pc.chunkIndex].selectionLabelId = pc.labelId
                chunks[pc.chunkIndex].selectionLabel = pc.label
                chunks[pc.chunkIndex].selectionCategoryId = pc.categoryId
                chunks[pc.chunkIndex].selectionCategory = pc.category
            }

            let ordered = persistedActions
                .filter { $0.plannedChunkId == pc.id }
                .sorted { $0.sortOrder < $1.sortOrder }
                .compactMap { action in
                    visibleItems.first(where: { $0.text == action.text })?.id
                }

            chunks[pc.chunkIndex].itemIDs = ordered
        }

        syncPoolWithVisibility()
    }

    /// Persist Step 3 in a way that:
    /// - preserves existing PlannedChunk IDs for the week whenever possible
    /// - supports "shift" semantics when a chunk is deleted (later chunks shift left)
    ///
    /// This fixes Step 4 "disappearing" because Step 4 references PlannedChunk.id.
    private func persistStep3Plan() {
        guard !isHydratingFromStorage else { return }

        let weekStart = currentWeekStart
        let captureByID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })

        // Fetch existing week chunks by ascending chunkIndex (these IDs should remain stable).
        let existingWeekChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: weekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        // We always rebuild selections + actions for the week.
        clearPersistedStep3PlanForCurrentWeek()

        // Ensure we have PlannedChunk rows for indices 0..<chunks.count
        // Preserve IDs by reusing the existing row at each index, if present.
        var weekChunksByIndex: [Int: PlannedChunk] = [:]
        for pc in existingWeekChunks {
            weekChunksByIndex[pc.chunkIndex] = pc
        }

        // If user deleted a chunk and "shift" happened, we must:
        // - reindex PlannedChunk objects in-place to 0..<chunks.count
        // - delete any extra persisted chunks beyond new count
        //
        // We perform reindexing by:
        // 1) taking existingWeekChunks in order
        // 2) assigning them new indices sequentially (preserving IDs)
        // 3) deleting leftover ones
        //
        // This matches "shift left" behavior.
        for (newIndex, pc) in existingWeekChunks.enumerated() {
            if newIndex < chunks.count {
                if pc.chunkIndex != newIndex {
                    pc.chunkIndex = newIndex
                    pc.weekChunkKey = "\(dayKey(from: weekStart))|\(newIndex)"
                    pc.updatedAt = .now
                }
                weekChunksByIndex[newIndex] = pc
            } else {
                // Any extra persisted chunk rows beyond the UI chunk count should be removed.
                modelContext.delete(pc)
            }
        }

        // If we don't have enough persisted chunks, create missing ones.
        if chunks.count > existingWeekChunks.count {
            for idx in existingWeekChunks.count..<chunks.count {
                // Temporary filler values; will be overwritten below if selection exists.
                let pc = PlannedChunk(
                    weekStart: weekStart,
                    chunkIndex: idx,
                    labelId: UUID(),
                    label: "",
                    categoryId: UUID(),
                    category: "",
                    updatedAt: .now
                )
                modelContext.insert(pc)
                weekChunksByIndex[idx] = pc
            }
        }

        // Persist selections (one per chunkIndex)
        for (chunkIndex, chunkState) in chunks.enumerated() {
            let sel = PlanChunkSelection(
                weekStart: weekStart,
                chunkIndex: chunkIndex,
                labelId: chunkState.selectionLabelId,
                label: chunkState.selectionLabel,
                categoryId: chunkState.selectionCategoryId,
                category: chunkState.selectionCategory,
                updatedAt: .now
            )
            modelContext.insert(sel)
        }

        // Update each PlannedChunk with the selected label/category (and then insert actions)
        for (chunkIndex, chunkState) in chunks.enumerated() where !chunkState.itemIDs.isEmpty {
            guard let plannedChunk = weekChunksByIndex[chunkIndex] else { continue }
            guard let labelId = chunkState.selectionLabelId else { continue }

            plannedChunk.weekStart = weekStart
            plannedChunk.chunkIndex = chunkIndex
            plannedChunk.labelId = labelId
            plannedChunk.label = chunkState.selectionLabel ?? ""
            plannedChunk.categoryId = chunkState.selectionCategoryId ?? UUID()
            plannedChunk.category = chunkState.selectionCategory ?? ""
            plannedChunk.updatedAt = .now
            plannedChunk.weekChunkKey = "\(dayKey(from: weekStart))|\(chunkIndex)"

            for (order, itemID) in chunkState.itemIDs.enumerated() {
                guard let item = captureByID[itemID] else { continue }

                let planned = PlannedChunkAction(
                    weekStart: weekStart,
                    chunkIndex: chunkIndex,
                    plannedChunkId: plannedChunk.id,
                    text: item.text,
                    sortOrder: order,
                    createdAt: .now
                )
                modelContext.insert(planned)
            }
        }

        try? modelContext.save()
    }

    private func dayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func moveItem(_ itemID: UUID, toChunkAt chunkIndex: Int) {
        if let idx = poolItemIDs.firstIndex(of: itemID) {
            poolItemIDs.remove(at: idx)
        }

        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        if !chunks[chunkIndex].itemIDs.contains(itemID) {
            chunks[chunkIndex].itemIDs.append(itemID)
        }
    }

    private func moveItemToPool(_ itemID: UUID) {
        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        if !poolItemIDs.contains(itemID) {
            poolItemIDs.insert(itemID, at: 0)
        }
    }

    private func syncPoolWithVisibility() {
        let visibleIDSet = Set(visibleItems.map(\.id))
        let chunkedIDs = Set(chunks.flatMap(\.itemIDs))

        poolItemIDs = poolItemIDs.filter { visibleIDSet.contains($0) && !chunkedIDs.contains($0) }

        let poolSet = Set(poolItemIDs)
        let toAdd = visibleItems
            .map(\.id)
            .filter { !poolSet.contains($0) && !chunkedIDs.contains($0) }

        if !toAdd.isEmpty {
            poolItemIDs.insert(contentsOf: toAdd, at: 0)
        }

        if poolItemIDs.isEmpty {
            poolItemIDs = initialPoolIDs.filter { !chunkedIDs.contains($0) }
        }
    }

    private func addChunkContainer() {
        guard chunks.count < maxChunks else { return }
        chunks.append(ChunkContainerState(isLocked: false))
    }

    private func canDeleteChunk(at index: Int) -> Bool {
        guard index >= 2 else { return false }
        return chunks[index].itemIDs.isEmpty
    }

    private func deleteChunkContainerIfAllowed(at index: Int) {
        guard canDeleteChunk(at: index) else { return }
        chunks.remove(at: index) // <-- shift happens naturally in UI state (indices collapse)
    }
}

// MARK: - Step 4

struct PlanStepFourView: View {
    let onBack: (() -> Void)?
    let onNext: (() -> Void)?

    init(onBack: (() -> Void)? = nil, onNext: (() -> Void)? = nil) {
        self.onBack = onBack
        self.onNext = onNext
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingInstructions: Bool = false

    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var stepFourStates: [PlannedChunkStepFourState]

    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .forward)
    private var outcomeLinks: [PlannedChunkOutcomeLink]

    @State private var selectedOutcomeIDsByChunk: [UUID: [UUID]] = [:]
    @State private var selectedRoleIDByChunk: [UUID: UUID?] = [:]

    @State private var resultTextByChunk: [UUID: String] = [:]
    @State private var roleTextByChunk: [UUID: String] = [:]
    @State private var purposeTextByChunk: [UUID: String] = [:]

    @FocusState private var focusedField: Step4FocusField?
    private enum Step4FocusField: Hashable {
        case result(UUID)
        case purpose(UUID)
        case roleNote(UUID)
    }

    private struct SheetChunkID: Identifiable, Hashable { let id: UUID }
    @State private var outcomeSheetChunkID: SheetChunkID? = nil
    @State private var roleSheetChunkID: SheetChunkID? = nil

    private let targetIconName = "scope"

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var plannedActionsForWeek: [PlannedChunkAction] {
        allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
    }

    private var isStep4NextEnabled: Bool {
        guard !plannedChunksForWeek.isEmpty else { return false }

        return plannedChunksForWeek.allSatisfy { chunk in
            let id = chunk.id
            let resultOK = !(resultTextByChunk[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let roleNoteOK = !(roleTextByChunk[id] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            let roleOK = (selectedRoleIDByChunk[id] ?? nil) != nil
            return resultOK && roleNoteOK && roleOK
        }
    }

    private func selectedOutcomeIDs(excludingChunk chunkID: UUID?) -> Set<UUID> {
        var result = Set<UUID>()
        for (id, ids) in selectedOutcomeIDsByChunk where id != chunkID {
            result.formUnion(ids)
        }
        return result
    }

    private func availableOutcomes(forChunk chunkID: UUID) -> [Outcomes] {
        let takenByOtherChunks = selectedOutcomeIDs(excludingChunk: chunkID)
        return outcomes.filter { !takenByOtherChunks.contains($0.outcome_id) }
    }

    private func selectedRoleIDs(excludingChunk chunkID: UUID?) -> Set<UUID> {
        var result = Set<UUID>()
        for (id, roleID) in selectedRoleIDByChunk where id != chunkID {
            if let roleID { result.insert(roleID) }
        }
        return result
    }

    private func availableRoles(forChunk chunk: PlannedChunk?) -> [FulfillmentRoles] {
        guard let chunk else { return [] }
        let rolesInCategory = rolesForPlannedChunk(chunk)
        let takenByOtherChunks = selectedRoleIDs(excludingChunk: chunk.id)
        return rolesInCategory.filter { !takenByOtherChunks.contains($0.id) }
    }

    private func chunkLightFillColor(for chunk: PlannedChunk) -> Color {
        FulfillmentCategoryColors.lightColor(for: chunk.category)
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            instructionsRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if plannedChunksForWeek.isEmpty {
                        Text("No chunks yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            chunkCard(chunk)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Button {
                    step4AutosaveTask?.cancel()
                    persistStep4ForWeekNow()
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    step4AutosaveTask?.cancel()
                    persistStep4ForWeekNow()
                    if let onNext { onNext() }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isStep4NextEnabled)
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .sheet(isPresented: $isShowingInstructions) {
            StepFourInstructionsPopup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $outcomeSheetChunkID) { wrapper in
            OutcomePickerSheet(
                title: "Connect Outcome(s)",
                outcomes: availableOutcomes(forChunk: wrapper.id),
                selectedIDs: Binding(
                    get: { selectedOutcomeIDsByChunk[wrapper.id] ?? [] },
                    set: { newValue in
                        selectedOutcomeIDsByChunk[wrapper.id] = Array(newValue.prefix(3))
                        scheduleStep4Autosave()
                    }
                ),
                maxSelection: 3
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roleSheetChunkID) { wrapper in
            let chunk = plannedChunksForWeek.first(where: { $0.id == wrapper.id })
            RolePickerSheet(
                title: "Connect Role",
                roles: availableRoles(forChunk: chunk),
                selectedRoleID: Binding(
                    get: { selectedRoleIDByChunk[wrapper.id] ?? nil },
                    set: { newValue in
                        selectedRoleIDByChunk[wrapper.id] = newValue
                        scheduleStep4Autosave()
                    }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            hydrateStep4ForWeek()
        }
        .onChange(of: plannedChunksForWeek.map(\.id)) { _, _ in
            hydrateStep4ForWeek()
        }
        .onDisappear {
            step4AutosaveTask?.cancel()
            persistStep4ForWeekNow()
        }
    }

    private var instructionsRow: some View {
        Button { isShowingInstructions = true } label: {
            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Instructions")
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("Tap to read")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    @ViewBuilder
    private func chunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkID = chunk.id
        let actions = actionsForChunk(chunk)
        let fill = chunkLightFillColor(for: chunk)

        let resultBinding = Binding<String>(
            get: { resultTextByChunk[chunkID] ?? "" },
            set: {
                resultTextByChunk[chunkID] = $0
                scheduleStep4Autosave()
            }
        )

        let purposeBinding = Binding<String>(
            get: { purposeTextByChunk[chunkID] ?? "" },
            set: { purposeTextByChunk[chunkID] = $0 }
        )

        let roleNoteBinding = Binding<String>(
            get: { roleTextByChunk[chunkID] ?? "" },
            set: {
                roleTextByChunk[chunkID] = $0
                scheduleStep4Autosave()
            }
        )

        let selectedOutcomeIDsBinding = Binding<[UUID]>(
            get: { selectedOutcomeIDsByChunk[chunkID] ?? [] },
            set: {
                selectedOutcomeIDsByChunk[chunkID] = Array($0.prefix(3))
                scheduleStep4Autosave()
            }
        )

        let selectedRoleIDBinding = Binding<UUID?>(
            get: { selectedRoleIDByChunk[chunkID] ?? nil },
            set: {
                selectedRoleIDByChunk[chunkID] = $0
                scheduleStep4Autosave()
            }
        )

        let fulfillmentPurposeText = fulfillmentForCategoryName(chunk.category)?.category_purpose ?? ""
        let canPasteCategoryPurpose = !fulfillmentPurposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        let selectedOutcomeIDs = selectedOutcomeIDsByChunk[chunkID] ?? []
        let singleOutcome: Outcomes? = {
            guard selectedOutcomeIDs.count == 1, let onlyID = selectedOutcomeIDs.first else { return nil }
            return outcomes.first(where: { $0.outcome_id == onlyID })
        }()
        let outcomeReasonText = singleOutcome?.reasons ?? ""
        let canPasteOutcomeReason = !outcomeReasonText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        ChunkCardView(
            chunk: chunk,
            actions: actions,
            outcomes: outcomes,
            roles: roles,
            colorScheme: colorScheme,
            targetIconName: targetIconName,
            fill: fill,
            resultText: resultBinding,
            purposeText: purposeBinding,
            roleNoteText: roleNoteBinding,
            selectedOutcomeIDs: selectedOutcomeIDsBinding,
            selectedRoleID: selectedRoleIDBinding,
            pasteFromCategoryTitle: chunk.category,
            canPasteCategoryPurpose: canPasteCategoryPurpose,
            onPasteCategoryPurpose: {
                roleTextByChunk[chunkID] = fulfillmentPurposeText
                scheduleStep4Autosave()
            },
            shouldShowOutcomeReasonPaste: (singleOutcome != nil),
            canPasteOutcomeReason: canPasteOutcomeReason,
            onPasteOutcomeReason: {
                roleTextByChunk[chunkID] = outcomeReasonText
                scheduleStep4Autosave()
            },
            onOpenOutcomes: { outcomeSheetChunkID = SheetChunkID(id: chunkID) },
            onOpenRoles: { roleSheetChunkID = SheetChunkID(id: chunkID) },
            onRemoveOutcome: { outcomeID in
                var ids = selectedOutcomeIDsByChunk[chunkID] ?? []
                ids.removeAll { $0 == outcomeID }
                selectedOutcomeIDsByChunk[chunkID] = ids
                scheduleStep4Autosave()
            }
        )
    }

    private struct ChunkCardView: View {
        let chunk: PlannedChunk
        let actions: [PlannedChunkAction]
        let outcomes: [Outcomes]
        let roles: [FulfillmentRoles]
        let colorScheme: ColorScheme
        let targetIconName: String
        let fill: Color

        @Binding var resultText: String
        @Binding var purposeText: String
        @Binding var roleNoteText: String
        @Binding var selectedOutcomeIDs: [UUID]
        @Binding var selectedRoleID: UUID?

        let pasteFromCategoryTitle: String
        let canPasteCategoryPurpose: Bool
        let onPasteCategoryPurpose: () -> Void

        let shouldShowOutcomeReasonPaste: Bool
        let canPasteOutcomeReason: Bool
        let onPasteOutcomeReason: () -> Void

        let onOpenOutcomes: () -> Void
        let onOpenRoles: () -> Void
        let onRemoveOutcome: (UUID) -> Void

        private var forcedDarkTextColor: Color { .black }

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                headerRow

                Divider().opacity(0.4)

                resultSection

                outcomesConnectRow

                let selectedOutcomes = resolvedSelectedOutcomes
                if !selectedOutcomes.isEmpty {
                    selectedOutcomesList(selectedOutcomes)
                }

                Divider().opacity(0.4)

                purposeSection

                roleConnectRow

                TextField("Earn more income FASTER for a better future!", text: $roleNoteText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                pasteFromRow

                Divider().opacity(0.4)

                actionsSection
            }
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }

        @FocusState private var focusedField: Step4FocusField?

        private var headerRow: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("actions related to:")
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(forcedDarkTextColor)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(forcedDarkTextColor)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
            }
        }

        private var resultSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("RESULT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("What do I want?")
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                }

                TextField("Stand out as a rising star and get a raise!", text: $resultText)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
            }
        }

        private var outcomesConnectRow: some View {
            Button(action: onOpenOutcomes) {
                HStack(spacing: 10) {
                    Image(systemName: targetIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    Text("Connect Outcome(s)")
                        .font(.subheadline)
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    Spacer(minLength: 0)
                    Text("optional")
                        .font(.caption)
                        .foregroundStyle(colorScheme == .dark ? Color.secondary : Color.black)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private func selectedOutcomesList(_ selectedOutcomes: [Outcomes]) -> some View {
            VStack(spacing: 8) {
                ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                    HStack(spacing: 10) {
                        Image(systemName: targetIconName)
                            .font(.system(size: 16, weight: .semibold))
                            .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                        Text(outcome.outcome)
                            .font(.subheadline)
                            .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                            .lineLimit(2)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        Button {
                            onRemoveOutcome(outcome.outcome_id)
                        } label: {
                            Image(systemName: "xmark.circle.fill")
                                .font(.system(size: 18, weight: .semibold))
                                .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel("Remove outcome")
                    }
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(
                                colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                                lineWidth: 1
                            )
                    )
                }
            }
        }

        private var purposeSection: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(forcedDarkTextColor)
                Spacer()
                Text("Why do I want it?")
                    .font(.subheadline)
                    .foregroundStyle(forcedDarkTextColor)
            }
        }

        private var pasteFromRow: some View {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Text("paste from:")
                    .font(.caption2)
                    .foregroundStyle(Color(.systemGray))

                Button {
                    onPasteCategoryPurpose()
                } label: {
                    Text("\(pasteFromCategoryTitle) Purpose")
                        .font(.caption2)
                        .underline()
                }
                .buttonStyle(.plain)
                .foregroundStyle(canPasteCategoryPurpose ? .blue : .secondary.opacity(0.6))
                .disabled(!canPasteCategoryPurpose)

                if shouldShowOutcomeReasonPaste {
                    Button {
                        onPasteOutcomeReason()
                    } label: {
                        Text("Outcome Reason")
                            .font(.caption2)
                            .underline()
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(canPasteOutcomeReason ? .blue : .secondary.opacity(0.6))
                    .disabled(!canPasteOutcomeReason)
                }

                Spacer(minLength: 0)
            }
        }

        private var roleConnectRow: some View {
            Button(action: onOpenRoles) {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                    Text("Connect Role")
                        .font(.subheadline)
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                    Spacer(minLength: 0)

                    if let selectedRoleName {
                        Text(selectedRoleName)
                            .font(.caption)
                            .foregroundStyle(colorScheme == .dark ? Color.secondary : Color.black)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(
                            colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                            lineWidth: 1
                        )
                )
            }
            .buttonStyle(.plain)
        }

        private var actionsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("How can I best acheive it now?")
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(actions) { action in
                        Text("• \(action.text)")
                            .font(.subheadline)
                            .foregroundStyle(forcedDarkTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
            }
        }

        private var resolvedSelectedOutcomes: [Outcomes] {
            guard !selectedOutcomeIDs.isEmpty else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
            return selectedOutcomeIDs.compactMap { byID[$0] }
        }

        private var selectedRoleName: String? {
            guard let selectedRoleID else { return nil }
            return roles.first(where: { $0.id == selectedRoleID })?.role
        }
    }

    // MARK: Step 4 "routine" autosave (debounced)

    @State private var step4AutosaveTask: Task<Void, Never>? = nil

    private func scheduleStep4Autosave() {
        step4AutosaveTask?.cancel()
        step4AutosaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 400_000_000)
            persistStep4ForWeekNow()
        }
    }

    private func hydrateStep4ForWeek() {
        for chunk in plannedChunksForWeek {
            if selectedOutcomeIDsByChunk[chunk.id] == nil { selectedOutcomeIDsByChunk[chunk.id] = [] }
            if selectedRoleIDByChunk[chunk.id] == nil { selectedRoleIDByChunk[chunk.id] = nil }
            if resultTextByChunk[chunk.id] == nil { resultTextByChunk[chunk.id] = "" }
            if purposeTextByChunk[chunk.id] == nil { purposeTextByChunk[chunk.id] = "" }
            if roleTextByChunk[chunk.id] == nil { roleTextByChunk[chunk.id] = "" }
        }

        let weekStates = stepFourStates.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let byChunkId = Dictionary(uniqueKeysWithValues: weekStates.map { ($0.plannedChunkId, $0) })

        for chunk in plannedChunksForWeek {
            if let st = byChunkId[chunk.id] {
                resultTextByChunk[chunk.id] = st.resultText
                roleTextByChunk[chunk.id] = st.roleNoteText
                selectedRoleIDByChunk[chunk.id] = st.connectedRoleId
            }
        }

        let weekLinks = outcomeLinks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let linksByChunk = Dictionary(grouping: weekLinks, by: \.plannedChunkId)

        for chunk in plannedChunksForWeek {
            let ids = (linksByChunk[chunk.id] ?? []).map(\.outcomeId)
            selectedOutcomeIDsByChunk[chunk.id] = Array(ids.prefix(3))
        }
    }

    private func persistStep4ForWeekNow() {
        let weekStart = currentWeekStart

        for st in stepFourStates where Calendar.current.isDate(st.weekStart, inSameDayAs: weekStart) {
            modelContext.delete(st)
        }
        for link in outcomeLinks where Calendar.current.isDate(link.weekStart, inSameDayAs: weekStart) {
            modelContext.delete(link)
        }

        for chunk in plannedChunksForWeek {
            let st = PlannedChunkStepFourState(
                weekStart: weekStart,
                plannedChunkId: chunk.id,
                resultText: resultTextByChunk[chunk.id] ?? "",
                roleNoteText: roleTextByChunk[chunk.id] ?? "",
                connectedRoleId: selectedRoleIDByChunk[chunk.id] ?? nil,
                updatedAt: .now
            )
            modelContext.insert(st)

            let outcomeIDs = selectedOutcomeIDsByChunk[chunk.id] ?? []
            for oid in outcomeIDs.prefix(3) {
                let link = PlannedChunkOutcomeLink(
                    weekStart: weekStart,
                    plannedChunkId: chunk.id,
                    outcomeId: oid,
                    createdAt: .now
                )
                modelContext.insert(link)
            }
        }

        try? modelContext.save()
    }

    private func actionsForChunk(_ chunk: PlannedChunk) -> [PlannedChunkAction] {
        plannedActionsForWeek
            .filter { $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }
    }

    private func fulfillmentForCategoryName(_ category: String) -> Fulfillment? {
        fulfillments.first { $0.category == category }
    }

    private func rolesForCategoryID(_ categoryId: UUID?) -> [FulfillmentRoles] {
        guard let categoryId else { return [] }
        return roles
            .filter { $0.category_id == categoryId }
            .sorted { $0.rank < $1.rank }
    }

    private func rolesForPlannedChunk(_ chunk: PlannedChunk?) -> [FulfillmentRoles] {
        guard let chunk else { return [] }
        guard let fulfillment = fulfillmentForCategoryName(chunk.category) else { return [] }
        return rolesForCategoryID(fulfillment.category_id)
    }
}

// MARK: - Step 5 (Define)

struct PlanStepFiveView: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
    }

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingInstructions: Bool = false

    // Data needed for "Define"
    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse)
    private var stepFourStates: [PlannedChunkStepFourState]

    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .forward)
    private var outcomeLinks: [PlannedChunkOutcomeLink]

    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    private var secondaryButtonTextColor: Color {
        colorScheme == .dark ? Color(.secondaryLabel) : .black
    }

    private var currentWeekStart: Date {
        WeeklyMindsetEntry.weekStart(for: Date())
    }

    private var plannedChunksForWeek: [PlannedChunk] {
        allPlannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }
    }

    private var stepFourStatesForWeekByChunkID: [UUID: PlannedChunkStepFourState] {
        let week = stepFourStates.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        return Dictionary(uniqueKeysWithValues: week.map { ($0.plannedChunkId, $0) })
    }

    private var outcomeIDsByChunkID: [UUID: [UUID]] {
        let week = outcomeLinks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let grouped = Dictionary(grouping: week, by: \.plannedChunkId)
        return grouped.mapValues { links in
            Array(links.map(\.outcomeId).prefix(3))
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Define")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            instructionsRow

            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    if plannedChunksForWeek.isEmpty {
                        Text("No chunks yet.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.top, 24)
                    } else {
                        ForEach(plannedChunksForWeek) { chunk in
                            defineChunkCard(chunk)
                        }
                    }
                }
                .padding(.bottom, 12)
            }

            Spacer(minLength: 0)

            HStack(spacing: 12) {
                Button {
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(secondaryButtonTextColor)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
            }
            .padding(.bottom, 2)
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .sheet(isPresented: $isShowingInstructions) {
            StepFiveInstructionsPopup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
    }

    private var instructionsRow: some View {
        Button { isShowingInstructions = true } label: {
            HStack(alignment: .center, spacing: 10) {
                Spacer(minLength: 0)
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .accessibilityHidden(true)
                Text("Instructions")
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Text("Tap to read")
                    .foregroundStyle(.secondary)
                    .font(.subheadline)
                Spacer(minLength: 0)
            }
            .frame(maxWidth: .infinity)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func defineChunkCard(_ chunk: PlannedChunk) -> some View {
        let fill = FulfillmentCategoryColors.lightColor(for: chunk.category)

        let step4 = stepFourStatesForWeekByChunkID[chunk.id]
        let resultText = step4?.resultText ?? ""
        // NOTE: Step 4 does not persist a separate "purpose" field. This uses roleNoteText as the purpose text.
        let purposeText = step4?.roleNoteText ?? ""

        let roleName: String = {
            guard let rid = step4?.connectedRoleId else { return "" }
            return roles.first(where: { $0.id == rid })?.role ?? ""
        }()

        let selectedOutcomeIDs = outcomeIDsByChunkID[chunk.id] ?? []
        let outcomesForChunk: [Outcomes] = {
            guard !selectedOutcomeIDs.isEmpty else { return [] }
            let byID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
            return selectedOutcomeIDs.compactMap { byID[$0] }
        }()

        // Use query-backed actions; these are the persisted Step 3 actions.
        let actions = allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        return DefineChunkCardView(
            fill: fill,
            colorScheme: colorScheme,
            resultText: resultText,
            selectedOutcomes: outcomesForChunk,
            roleName: roleName,
            purposeText: purposeText,
            actions: actions,
            onMoveActions: { from, to in
                moveActions(in: chunk, from: from, to: to)
            }
        )
    }

    private func moveActions(in chunk: PlannedChunk, from offsets: IndexSet, to destination: Int) {
        var list = allPlannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) && $0.plannedChunkId == chunk.id }
            .sorted { $0.sortOrder < $1.sortOrder }

        list.move(fromOffsets: offsets, toOffset: destination)

        for (idx, action) in list.enumerated() {
            if action.sortOrder != idx {
                action.sortOrder = idx
            }
        }
        try? modelContext.save()
    }

    private struct DefineChunkCardView: View {
        let fill: Color
        let colorScheme: ColorScheme

        let resultText: String
        let selectedOutcomes: [Outcomes]

        let roleName: String
        let purposeText: String

        let actions: [PlannedChunkAction]
        let onMoveActions: (IndexSet, Int) -> Void

        private var forcedDarkTextColor: Color { .black }
        private let targetIconName = "scope"

        // “Make both smaller by 25%”
        private let pillScale: CGFloat = 0.75

        // For drag/drop reorder within this card
        @State private var draggedActionID: UUID? = nil

        var body: some View {
            VStack(alignment: .leading, spacing: 12) {
                resultSection

                if !selectedOutcomes.isEmpty {
                    selectedOutcomesPillsSmall(selectedOutcomes)
                }

                Divider().opacity(0.4)

                purposeSection

                if !roleName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    rolePillSmall(roleName)
                }

                if !purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(purposeText)
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                        .fixedSize(horizontal: false, vertical: true)
                } else {
                    Text("—")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Divider().opacity(0.4)

                actionsSection
            }
            .padding(12)
            .background(fill, in: RoundedRectangle(cornerRadius: 14))
            .overlay(
                RoundedRectangle(cornerRadius: 14)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                        lineWidth: 1
                    )
            )
        }

        private var resultSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("RESULT")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("What do I want?")
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                }

                Text(resultText.isEmpty ? "—" : resultText)
                    .font(.subheadline)
                    .foregroundStyle(resultText.isEmpty ? .secondary : forcedDarkTextColor)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }

        private func selectedOutcomesPillsSmall(_ selectedOutcomes: [Outcomes]) -> some View {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                    pillSmall(iconSystemName: targetIconName, text: outcome.outcome)
                }
            }
        }

        private var purposeSection: some View {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(forcedDarkTextColor)
                Spacer()
                Text("Why do I want it?")
                    .font(.subheadline)
                    .foregroundStyle(forcedDarkTextColor)
            }
        }

        private func rolePillSmall(_ role: String) -> some View {
            pillSmall(iconSystemName: "trophy", text: role)
        }

        private func pillSmall(iconSystemName: String, text: String) -> some View {
            HStack(spacing: 10 * pillScale) {
                Image(systemName: iconSystemName)
                    .font(.system(size: 16 * pillScale, weight: .semibold))
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)

                Text(text)
                    .font(.system(size: 15 * pillScale, weight: .regular))
                    .foregroundStyle(colorScheme == .dark ? Color.primary : Color.black)
                    .lineLimit(2)
                    .fixedSize(horizontal: true, vertical: true)
            }
            .padding(.vertical, 8 * pillScale)
            .padding(.horizontal, 12 * pillScale)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10 * pillScale))
            .overlay(
                RoundedRectangle(cornerRadius: 10 * pillScale)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.15),
                        lineWidth: 1
                    )
            )
            .fixedSize(horizontal: true, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
        }

        private var actionsSection: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text("ACTIONS")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(forcedDarkTextColor)
                    Spacer()
                    Text("Drag to reorder")
                        .font(.subheadline)
                        .foregroundStyle(forcedDarkTextColor)
                }

                if actions.isEmpty {
                    Text("No actions yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 4)
                } else {
                    VStack(spacing: 8) {
                        ForEach(actions) { action in
                            DefineActionRow(text: action.text)
                                .onDrag {
                                    draggedActionID = action.id
                                    return NSItemProvider(object: action.id.uuidString as NSString)
                                }
                                .onDrop(of: [.text], delegate: ActionDropDelegate(
                                    targetID: action.id,
                                    draggedID: $draggedActionID,
                                    actions: actions,
                                    onMove: onMoveActions
                                ))
                        }
                    }
                }
            }
        }

        private struct DefineActionRow: View {
            let text: String

            var body: some View {
                HStack(alignment: .top, spacing: 10) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text(text)
                            .font(.subheadline)
                            .foregroundStyle(.black)
                            .fixedSize(horizontal: false, vertical: true)

                        HStack(spacing: 14) {
                            Image(systemName: "star")
                            Image(systemName: "clock")
                            Image(systemName: "person")
                            Image(systemName: "gearshape")
                            Image(systemName: "paperclip")
                        }
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(Color(.systemGray))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .padding(.top, 2)
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(Color.black.opacity(0.12), lineWidth: 1)
                )
            }
        }

        private struct ActionDropDelegate: DropDelegate {
            let targetID: UUID
            @Binding var draggedID: UUID?
            let actions: [PlannedChunkAction]
            let onMove: (IndexSet, Int) -> Void

            func dropEntered(info: DropInfo) {
                guard let draggedID, draggedID != targetID else { return }

                guard
                    let fromIndex = actions.firstIndex(where: { $0.id == draggedID }),
                    let toIndex = actions.firstIndex(where: { $0.id == targetID })
                else { return }

                // Move as user drags over rows.
                let destination = (toIndex > fromIndex) ? (toIndex + 1) : toIndex
                onMove(IndexSet(integer: fromIndex), destination)
            }

            func performDrop(info: DropInfo) -> Bool {
                draggedID = nil
                return true
            }

            func dropUpdated(info: DropInfo) -> DropProposal? {
                DropProposal(operation: .move)
            }
        }
    }
}

// MARK: - Step 4/5 instructions + sheets + helpers

private struct StepFourInstructionsPopup: View {
    @Environment(\.dismiss) private var dismiss
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Group {
                        (Text("Result: ").fontWeight(.bold) + Text("What do I want?").italic().underline())
                            .font(.body)

                        Text("What’s the most important result or outcome you want to have happen today? What are you really committed to achieving?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 2)

                    Group {
                        (Text("Purpose: ").fontWeight(.bold) + Text("Why do I want it?").italic().underline())
                            .font(.body)

                        Text("Why do you want to do this? What’s your real purpose? How will it make you feel to achieve your result? What will it give you? What will it give you? What will it give your family?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        Image(systemName: "trophy")
                            .font(.system(size: 18, weight: .semibold))
                            .foregroundStyle(.secondary)

                        Text("This connects what you do now to fulfillment via your roles in a category of improvement.")
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(.top, 2)

                    Divider().padding(.vertical, 2)

                    Group {
                        (Text("Actions: ").fontWeight(.bold) + Text("How can I best achieve it now?").italic().underline())
                            .font(.body)

                        Text("What specific actions can you take in order to achieve your result? What are the elements of your plan - both things you already captured as well as any new ideas that you come up with - that will help you achieve your result?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct StepFiveInstructionsPopup: View {
    @Environment(\.dismiss) private var dismiss

    @State private var prioritizeExpanded: Bool = false
    @State private var mustsExpanded: Bool = false
    @State private var durationExpanded: Bool = false
    @State private var leverageExpanded: Bool = false

    private let lightbulbIconName = "lightbulb"

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {

                    instructionBlock(
                        title: "Prioritize:",
                        description: "drag to sort actions based on priority or level of importance.",
                        tipExpanded: $prioritizeExpanded,
                        tipText: "Keep it simple by giving yourself as few things to think about as possible when you’re executing your plan!"
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Musts:",
                        description: "star the must actions that need to get complete. These are the items that will give you the most significant progress toward the completion of your Result.",
                        tipExpanded: $mustsExpanded,
                        tipText: "20% usually makes 80% of the difference in terms of achieving your Result. Most often, you don't need to complete all of the actions your recorded in your plan."
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Duration:",
                        description: "clock the estimated amount of time you think it will take to complete each action in your plan.",
                        tipExpanded: $durationExpanded,
                        tipText: #"You may estimate that it would take 7 hours to complete your entire Block, but if you just focus on your "must" actions, it might only take you 2 hours to achieve your Result. This distinction helps you focus on the most important actions so you can achieve your Result in the shortest period of time."#
                    )

                    Divider().padding(.vertical, 2)

                    instructionBlock(
                        title: "Leverage:",
                        description: "identify any actions that you can leverage to someone or something else.",
                        tipExpanded: $leverageExpanded,
                        tipText: "What other resources do you have available to help you get this Result (e.g., assistant, outsourcing, trades, technology)? Some of the actions in your Block can likely be completed without your direct time or brainpower. Who or what could assist you?"
                    )

                    Spacer(minLength: 0)
                }
                .padding()
            }
            .navigationTitle("Instructions")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    @ViewBuilder
    private func instructionBlock(
        title: String,
        description: String,
        tipExpanded: Binding<Bool>,
        tipText: String
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            (Text(title).fontWeight(.bold) + Text(" ") + Text(description))
                .font(.body)

            HStack(alignment: .firstTextBaseline, spacing: 10) {
                Image(systemName: lightbulbIconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(.secondary)

                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(tipText)
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                        .lineLimit(tipExpanded.wrappedValue ? nil : 1)
                        .truncationMode(.tail)
                        .fixedSize(horizontal: false, vertical: true)

                    Button(tipExpanded.wrappedValue ? "Show less" : "Show more") {
                        tipExpanded.wrappedValue.toggle()
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .layoutPriority(1)
                }
            }
        }
    }
}

private struct OutcomePickerSheet: View {
    let title: String
    let outcomes: [Outcomes]
    @Binding var selectedIDs: [UUID]
    let maxSelection: Int

    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: UUID) -> Bool { selectedIDs.contains(id) }

    private func toggle(_ id: UUID) {
        if let idx = selectedIDs.firstIndex(of: id) {
            selectedIDs.remove(at: idx)
        } else {
            guard selectedIDs.count < maxSelection else { return }
            selectedIDs.append(id)
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Select up to \(maxSelection).")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(outcomes) { outcome in
                    Button {
                        toggle(outcome.outcome_id)
                    } label: {
                        HStack(spacing: 10) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(outcome.outcome)
                                    .foregroundStyle(.primary)
                                    .font(.body)
                                    .lineLimit(2)

                                if !outcome.reasons.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                    Text(outcome.reasons)
                                        .foregroundStyle(.secondary)
                                        .font(.caption)
                                        .lineLimit(2)
                                }
                            }

                            Spacer()

                            if isSelected(outcome.outcome_id) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.blue)
                            } else if selectedIDs.count >= maxSelection {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary.opacity(0.4))
                            } else {
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(!isSelected(outcome.outcome_id) && selectedIDs.count >= maxSelection)
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct RolePickerSheet: View {
    let title: String
    let roles: [FulfillmentRoles]
    @Binding var selectedRoleID: UUID?

    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: UUID) -> Bool { selectedRoleID == id }

    var body: some View {
        NavigationStack {
            List {
                if roles.isEmpty {
                    Text("No roles found for this category yet.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(roles) { role in
                        Button {
                            selectedRoleID = isSelected(role.id) ? nil : role.id
                        } label: {
                            HStack {
                                Text(role.role)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if isSelected(role.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

private struct DragPayload: Codable, Hashable, Transferable {
    let itemID: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

private struct ChunkContainerState: Identifiable, Hashable {
    var id: UUID = .init()
    var isLocked: Bool

    var selectionLabelId: UUID? = nil
    var selectionLabel: String? = nil
    var selectionCategoryId: UUID? = nil
    var selectionCategory: String? = nil

    var itemIDs: [UUID] = []

    init(id: UUID = .init(), isLocked: Bool) {
        self.id = id
        self.isLocked = isLocked
    }
}

#Preview {
    PlanView()
}

private extension View {
    @ViewBuilder
    func `if`<Content: View>(_ condition: Bool, transform: (Self) -> Content) -> some View {
        if condition {
            transform(self)
        } else {
            self
        }
    }
}

private enum FulfillmentCategoryColors {
    private static let lightBlue = Color(red: 0.70, green: 0.85, blue: 1.00)
    private static let lightIndigo = Color(red: 0.80, green: 0.80, blue: 0.95)
    private static let lightGreen = Color(red: 0.80, green: 1.00, blue: 0.80)
    private static let lightPurple = Color(red: 0.90, green: 0.80, blue: 0.90)
    private static let lightRed = Color(red: 1.00, green: 0.80, blue: 0.80)
    private static let lightOrange = Color(red: 1.00, green: 0.90, blue: 0.70)

    static func lightColor(for categoryTitle: String) -> Color {
        switch categoryTitle {
        case "Career & Business": return lightBlue
        case "Leadership & Impact": return lightIndigo
        case "Wealth & Lifestyle": return lightGreen
        case "Mind & Meaning": return lightPurple
        case "Love & Relationships": return lightRed
        case "Health & Vitality": return lightOrange
        default: return Color.gray.opacity(0.1)
        }
    }
}

