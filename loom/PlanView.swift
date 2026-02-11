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

    @State private var navigateToStep2: Bool = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case morning, grateful, incantation }

    private var isNextDisabled: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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
                        .foregroundColor(.black)
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
            DispatchQueue.main.async {
                focusedField = .morning
            }
        }
    }

    private func saveStepOneAndAdvance() {
        let now = Date()
        let entry = WeeklyMindsetEntry.Fields(
            createdAt: now,
            morningPowerQuestion: morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
            gratitude: gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines),
            incantation: incantation.trimmingCharacters(in: .whitespacesAndNewlines)
        )
        modelContext.insert(entry)
        try? modelContext.save()
        navigateToStep2 = true
    }
}

// MARK: - Single modal host for steps 2–4 (prevents stacked fullScreenCover text input bugs)

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
            default:
                PlanStepFourView(onBack: { step = 3 })
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

            // IMPORTANT:
            // To match Step 1 width, avoid stacking horizontal padding on:
            // - List
            // - List rows
            // Keep the "page" padding only on the outer VStack (below).
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
                        .foregroundColor(.black)
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
        // Single "page width" padding (match Step 1)
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

    // Baselines used solely for the "Refresh" button.
    // These MUST represent the "fresh/auto-generated from capture list" state, not the hydrated state.
    @State private var baselineShowHidden: Bool = false
    @State private var baselinePoolItemIDs: [UUID] = []
    @State private var baselineChunks: [ChunkContainerState] = []

    @State private var isHydratingFromStorage: Bool = false

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let maxChunks = 5

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
        // Show refresh if:
        // 1) user changed state vs the last "fresh baseline", OR
        // 2) the capture list has drifted since the plan was last persisted (common when you leave and come back).
        showHidden != baselineShowHidden ||
        poolItemIDs != baselinePoolItemIDs ||
        chunks != baselineChunks ||
        isPersistedPlanOutOfSyncWithCapture
    }

    /// When true, indicates the persisted plan for this week can't fully map back to the current capture list.
    /// (Most commonly: new capture items were added since planning, or planned actions no longer exist in capture.)
    ///
    /// This is what makes Refresh show immediately when you return to Step 3.
    private var isPersistedPlanOutOfSyncWithCapture: Bool {
        // If we have no plan persisted for this week, nothing to refresh.
        let weekChunks = plannedChunks.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekActions = plannedActions.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
        let weekSelections = allChunkSelections.filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        if weekChunks.isEmpty && weekActions.isEmpty && weekSelections.isEmpty {
            return false
        }

        // Step 3 persistence is text-based for actions, so we can only best-effort match by text.
        // If any planned action's text doesn't exist in current capture, we're out of sync.
        let captureTextSet = Set(allItems.map(\.text))
        if weekActions.contains(where: { !captureTextSet.contains($0.text) }) {
            return true
        }

        // If there are visible capture items that aren't represented anywhere in the persisted plan,
        // we consider that "needs refresh" because Step 3's "fresh" state would include them in the pool.
        //
        // Note: because persistence is text-based, duplicates are ambiguous. We intentionally treat any
        // missing *text* as needing refresh. This keeps behavior intuitive.
        let plannedTextSet = Set(weekActions.map(\.text))
        let visibleCaptureItems = (showHidden ? allItems : allItems.filter { !$0.isGhost })

        if visibleCaptureItems.contains(where: { !plannedTextSet.contains($0.text) }) {
            return true
        }

        return false
    }

    /// True if ANY chunk currently contains ANY ghost/hidden action.
    /// When this is true, Step 3 must force `showHidden = true` and prevent toggling it off.
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
                            // If a hidden action is currently inside any chunk,
                            // this toggle is "fixed on".
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

            // Pool list (keep width consistent with Step 1 by avoiding extra horizontal padding here)
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
                // User can only change this if no hidden action is in a chunk.
                // But also guard against other state changes.
                enforceShowHiddenIfNeeded()

                syncPoolWithVisibility()
                persistStep3Plan()
            }

            // Chunk containers list (no extra horizontal padding here)
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
                        .foregroundColor(.black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                Button {
                    // State is already persisted continuously; Next just advances.
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
        // Single "page width" padding (match Step 1)
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

            // If we hydrated a hidden action into a chunk, force showHidden on.
            enforceShowHiddenIfNeeded()

            // IMPORTANT CHANGE:
            // Do NOT set baselines here to the hydrated state.
            // Baselines represent the "fresh" state and are set by `refreshStep3()` and by the
            // "no persisted plan" initialization path only.
            //
            // However, if there is truly no persisted state for the week, we want baseline == current
            // so refresh stays hidden until user changes something.
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
            // If an item becomes ghost/unghosted while on this screen,
            // keep the toggle consistent.
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

    /// Forces the "Show Actions Hidden..." toggle ON if any chunk currently contains a hidden action.
    /// This is the single enforcement point used by:
    /// - hydration (returning to screen)
    /// - drag/drop interactions
    /// - toggle changes
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
                    .foregroundStyle(.secondary)

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
        // 1) Clear UI state
        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }

        showHidden = false

        if chunks.isEmpty {
            chunks = [
                ChunkContainerState(isLocked: true),
                ChunkContainerState(isLocked: true),
            ]
        } else {
            chunks = [
                ChunkContainerState(isLocked: true),
                ChunkContainerState(isLocked: true),
            ]
        }

        poolItemIDs = allItems
            .filter { !$0.isGhost } // because showHidden just got set to false
            .sorted { $0.createdAt > $1.createdAt }
            .map(\.id)

        // 2) Clear persisted state for this week (Step 4 reads these)
        clearPersistedPlanForCurrentWeek()

        // 3) Persist the "fresh" state (so if you exit & come back, it's still fresh)
        persistStep3Plan()

        // 4) Reset baselines so Refresh button hides immediately
        baselineShowHidden = showHidden
        baselinePoolItemIDs = poolItemIDs
        baselineChunks = chunks
    }

    private func clearPersistedPlanForCurrentWeek() {
        for action in plannedActions where Calendar.current.isDate(action.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(action)
        }
        for chunk in plannedChunks where Calendar.current.isDate(chunk.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(chunk)
        }
        for sel in allChunkSelections where Calendar.current.isDate(sel.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(sel)
        }
        try? modelContext.save()
    }

    /// Hydrate Step 3 UI state from SwiftData (the same models Step 4 uses) if present.
    /// Otherwise initialize "from scratch" and persist once.
    private func hydrateStep3FromStorageOrInitialize() {
        // Only hydrate once per appearance when our local state isn't already set.
        // If this view is recreated, @State resets and we rehydrate.
        guard poolItemIDs.isEmpty else { return }

        isHydratingFromStorage = true
        defer { isHydratingFromStorage = false }

        // Pull persisted planned chunks/actions for THIS week.
        let persistedChunks = plannedChunks
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        let persistedActions = plannedActions
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }

        let persistedSelections = allChunkSelections
            .filter { Calendar.current.isDate($0.weekStart, inSameDayAs: currentWeekStart) }
            .sorted { $0.chunkIndex < $1.chunkIndex }

        // If nothing persisted yet, start from scratch and persist.
        if persistedChunks.isEmpty && persistedActions.isEmpty && persistedSelections.isEmpty {
            // ensure default 2 locked chunks exist
            if chunks.isEmpty {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            } else if chunks.count < 2 {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }

            poolItemIDs = initialPoolIDs
            syncPoolWithVisibility()

            persistStep3Plan()

            // For the "no persisted plan" case, baseline == current is correct.
            baselineShowHidden = showHidden
            baselinePoolItemIDs = poolItemIDs
            baselineChunks = chunks
            return
        }

        // IMPORTANT:
        // If any persisted chunk contains an action that maps back to a ghost RollingCaptureItem,
        // force showHidden on BEFORE we finish hydration (so those IDs can resolve into `visibleItems`).
        let ghostTextSetForWeek: Set<String> = {
            let chunkIDs = Set(persistedChunks.map(\.id))
            let texts = persistedActions
                .filter { chunkIDs.contains($0.plannedChunkId) }
                .map(\.text)
            return Set(texts)
        }()

        if !ghostTextSetForWeek.isEmpty {
            // Best-effort because PlannedChunkAction is text-only.
            // If there are duplicates, we treat it as hidden if ANY matching capture item is ghost.
            let hasGhostInPersistedPlan = allItems.contains { item in
                item.isGhost && ghostTextSetForWeek.contains(item.text)
            }
            if hasGhostInPersistedPlan {
                showHidden = true
            }
        }

        // Ensure we have at least enough containers to represent persisted chunk indices.
        let maxIndex = persistedChunks.map(\.chunkIndex).max() ?? 1
        let desiredCount = min(maxChunks, max(2, maxIndex + 1))

        chunks = (0..<desiredCount).map { idx in
            // locked first two, user-added after
            ChunkContainerState(isLocked: idx < 2)
        }

        // Apply label selections from persisted selections first (preferred, since it's explicit).
        // Fall back to PlannedChunk label info if selection rows are missing.
        for sel in persistedSelections {
            guard sel.chunkIndex >= 0, sel.chunkIndex < chunks.count else { continue }
            chunks[sel.chunkIndex].selectionLabelId = sel.labelId
            chunks[sel.chunkIndex].selectionLabel = sel.label
            chunks[sel.chunkIndex].selectionCategoryId = sel.categoryId
            chunks[sel.chunkIndex].selectionCategory = sel.category
        }

        for pc in persistedChunks {
            guard pc.chunkIndex >= 0, pc.chunkIndex < chunks.count else { continue }

            // Only fill in if not already present from PlanChunkSelection.
            if chunks[pc.chunkIndex].selectionLabelId == nil {
                chunks[pc.chunkIndex].selectionLabelId = pc.labelId
                chunks[pc.chunkIndex].selectionLabel = pc.label
                chunks[pc.chunkIndex].selectionCategoryId = pc.categoryId
                chunks[pc.chunkIndex].selectionCategory = pc.category
            }

            // Reconstruct itemIDs ordering from PlannedChunkAction sortOrder.
            let ordered = persistedActions
                .filter { $0.plannedChunkId == pc.id }
                .sorted { $0.sortOrder < $1.sortOrder }
                .compactMap { action in
                    // Map by TEXT back to a RollingCaptureItem.id.
                    // NOTE: PlannedChunkAction currently stores only `text`, not capture item ID.
                    // We map to the most recent matching RollingCaptureItem.text.
                    // If duplicates exist, this may pick the wrong one.
                    visibleItems.first(where: { $0.text == action.text })?.id
                }

            chunks[pc.chunkIndex].itemIDs = ordered
        }

        // Recreate pool: everything visible not already chunked, stable order using initialPoolIDs.
        syncPoolWithVisibility()
        // IMPORTANT: do NOT set baselines here (see comment in onAppear).
    }

    /// Persist Step 3 continuously into the same data Step 4 reads:
    /// - PlannedChunk / PlannedChunkAction (actions assigned to chunks)
    /// - PlanChunkSelection (label/category selection per chunk)
    ///
    /// Called after every interaction (drag/drop, picker changes, add/delete chunk, showHidden changes).
    private func persistStep3Plan() {
        guard !isHydratingFromStorage else { return }

        let captureByID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })

        // Wipe current week's records and rebuild from UI state.
        // (Simple + robust for small datasets. If this grows, we can diff-update.)
        clearPersistedPlanForCurrentWeek()

        // Persist selections for all displayed chunk indices (even empty ones),
        // so returning restores the picker selections even before the chunk qualifies.
        for (chunkIndex, chunkState) in chunks.enumerated() {
            let sel = PlanChunkSelection(
                weekStart: currentWeekStart,
                chunkIndex: chunkIndex,
                labelId: chunkState.selectionLabelId,
                label: chunkState.selectionLabel,
                categoryId: chunkState.selectionCategoryId,
                category: chunkState.selectionCategory,
                updatedAt: .now
            )
            modelContext.insert(sel)
        }

        // Persist planned chunks/actions (only for chunks that have items, like before).
        for (chunkIndex, chunkState) in chunks.enumerated() where !chunkState.itemIDs.isEmpty {
            // If no label is selected yet, we still persist the actions into a chunk record.
            // But PlannedChunk requires a labelId, categoryId, etc. in your current model.
            // So we only persist PlannedChunk/Action when a label is selected.
            guard let labelId = chunkState.selectionLabelId else { continue }

            let plannedChunk = PlannedChunk(
                weekStart: currentWeekStart,
                chunkIndex: chunkIndex,
                labelId: labelId,
                label: chunkState.selectionLabel ?? "",
                categoryId: chunkState.selectionCategoryId ?? UUID(),
                category: chunkState.selectionCategory ?? "",
                updatedAt: .now
            )
            modelContext.insert(plannedChunk)

            for (order, itemID) in chunkState.itemIDs.enumerated() {
                guard let item = captureByID[itemID] else { continue }

                let planned = PlannedChunkAction(
                    weekStart: currentWeekStart,
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

        // If pool is still empty (first load), initialize deterministically.
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
        chunks.remove(at: index)
    }
}

// MARK: - Step 4

struct PlanStepFourView: View {
    let onBack: (() -> Void)?

    init(onBack: (() -> Void)? = nil) {
        self.onBack = onBack
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

    @State private var selectedOutcomeIDsByChunk: [UUID: [UUID]] = [:]
    @State private var selectedRoleIDByChunk: [UUID: UUID?] = [:]

    @State private var resultTextByChunk: [UUID: String] = [:]
    @State private var roleTextByChunk: [UUID: String] = [:]

    @FocusState private var focusedField: Step4FocusField?
    private enum Step4FocusField: Hashable {
        case result(UUID)
        case roleNote(UUID)
    }

    private struct SheetChunkID: Identifiable, Hashable { let id: UUID }
    @State private var outcomeSheetChunkID: SheetChunkID? = nil
    @State private var roleSheetChunkID: SheetChunkID? = nil

    private let targetIconName = "scope"

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
                    if let onBack { onBack() } else { dismiss() }
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
            }
            .padding(.bottom, 2)
        }
        // Single "page width" padding (match Step 1)
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        // Removed the keyboard "Done" toolbar entirely
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
                    }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            for chunk in plannedChunksForWeek {
                if selectedOutcomeIDsByChunk[chunk.id] == nil { selectedOutcomeIDsByChunk[chunk.id] = [] }
                if selectedRoleIDByChunk[chunk.id] == nil { selectedRoleIDByChunk[chunk.id] = nil }
                if resultTextByChunk[chunk.id] == nil { resultTextByChunk[chunk.id] = "" }
                if roleTextByChunk[chunk.id] == nil { roleTextByChunk[chunk.id] = "" }
            }
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
            set: { resultTextByChunk[chunkID] = $0 }
        )

        let roleNoteBinding = Binding<String>(
            get: { roleTextByChunk[chunkID] ?? "" },
            set: { roleTextByChunk[chunkID] = $0 }
        )

        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("actions related to:")
                    .font(.caption)
                    .fontWeight(.regular)
                    .foregroundStyle(.black)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(.black)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
            }

            Divider().opacity(0.4)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("What do I want?")
                    .font(.subheadline)
                    .foregroundStyle(.black)
            }

            TextField("Stand out as a rising star and get a raise!", text: resultBinding)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .result(chunkID))
                .submitLabel(.done)

            Button {
                outcomeSheetChunkID = SheetChunkID(id: chunkID)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: targetIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)
                    Text("Connect Outcome(s)")
                        .font(.subheadline)
                        .foregroundStyle(.black)
                    Spacer(minLength: 0)
                    Text("optional")
                        .font(.caption)
                        .foregroundStyle(.black)
                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
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

            let selectedOutcomes = outcomesForChunk(chunk)
            if !selectedOutcomes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                        HStack(spacing: 10) {
                            Image(systemName: targetIconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.black)

                            Text(outcome.outcome)
                                .font(.subheadline)
                                .foregroundStyle(.black)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                removeOutcome(outcome, from: chunk)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.black)
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

            Divider().opacity(0.4)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
                Text("Why do I want it?")
                    .font(.subheadline)
                    .foregroundStyle(.black)
            }

            Button {
                roleSheetChunkID = SheetChunkID(id: chunkID)
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.black)

                    Text("Connect Role")
                        .font(.subheadline)
                        .foregroundStyle(.black)

                    Spacer(minLength: 0)

                    if let selectedRoleName = selectedRoleName(for: chunk) {
                        Text(selectedRoleName)
                            .font(.caption)
                            .foregroundStyle(.black)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.black)
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

            TextField("Earn more income FASTER for a better future!", text: roleNoteBinding)
                .textFieldStyle(.roundedBorder)
                .focused($focusedField, equals: .roleNote(chunkID))
                .submitLabel(.done)

            Divider().opacity(0.4)

            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("ACTIONS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.black)
                Spacer()
            }

            VStack(alignment: .leading, spacing: 8) {
                ForEach(actions) { action in
                    Text("• \(action.text)")
                        .font(.subheadline)
                        .foregroundStyle(.black)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
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

    private func outcomesForChunk(_ chunk: PlannedChunk) -> [Outcomes] {
        let ids = selectedOutcomeIDsByChunk[chunk.id] ?? []
        guard !ids.isEmpty else { return [] }

        let byID = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })
        return ids.compactMap { byID[$0] }
    }

    private func removeOutcome(_ outcome: Outcomes, from chunk: PlannedChunk) {
        let chunkID = chunk.id
        var ids = selectedOutcomeIDsByChunk[chunkID] ?? []
        ids.removeAll { $0 == outcome.outcome_id }
        selectedOutcomeIDsByChunk[chunkID] = ids
    }

    private func selectedRoleName(for chunk: PlannedChunk) -> String? {
        guard let picked = (selectedRoleIDByChunk[chunk.id] ?? nil) else { return nil }
        return roles.first(where: { $0.id == picked })?.role
    }
}

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

                        Text("Why do you want to do this? What’s your real purpose? How will it make you feel to achieve your result? What will it give you? What will it give your family?")
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

