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
            
            // Top Title
            Text("Weekly Planning")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Morning Power Question
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

            // Grateful For
            VStack(alignment: .leading, spacing: 8) {
                Text("What am I grateful for?")
                    .font(.headline)
                TextField("Health", text: $gratefulFor)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .grateful)
                    .onSubmit { focusedField = .incantation }
            }

            // Incantation
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

            // Bottom buttons side-by-side (like Step 2)
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
        .fullScreenCover(isPresented: $navigateToStep2) {
            PlanStepTwoView()
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

struct PlanStepTwoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @State private var input: String = ""
    @State private var showHidden: Bool = false
    @FocusState private var isInputFocused: Bool

    /// Baseline set captured on appear; used to apply `plus.viewfinder` only to “existing before session” items.
    @State private var baselineItemIDs: Set<UUID> = []

    @State private var isBrainstormExpanded: Bool = false
    @State private var navigateToStep3: Bool = false

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

            // Brainstorm info row
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

                        Button("Show less") {
                            isBrainstormExpanded = false
                        }
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

                            Button("Show more") {
                                isBrainstormExpanded = true
                            }
                            .font(.subheadline)
                            .layoutPriority(1)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .padding(.horizontal)

            // Toggle row
            HStack(spacing: 10) {
                Toggle(isOn: $showHidden) {
                    EmptyView()
                }
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
            .padding(.horizontal)

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
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
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
            .padding(.horizontal, 24)
            .padding(.top, 4)

            HStack(spacing: 12) {
                Button {
                    dismiss()
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
                    navigateToStep3 = true
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom, 2)
        }
        .safeAreaPadding()
        .fullScreenCover(isPresented: $navigateToStep3) {
            PlanStepThreeView()
        }
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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @Query(sort: \PlanLabel.category, order: .forward)
    private var allPlanLabels: [PlanLabel]

    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse)
    private var allChunkSelections: [PlanChunkSelection]

    // Clear any existing plan for the week before writing a new one
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse)
    private var plannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse)
    private var plannedActions: [PlannedChunkAction]

    @State private var showHidden: Bool = false
    @State private var isCategorizeExpanded: Bool = false

    @State private var poolItemIDs: [UUID] = []
    @State private var chunks: [ChunkContainerState] = []

    // Step 3 baseline snapshot (used for "Refresh" visibility)
    @State private var baselineShowHidden: Bool = false
    @State private var baselinePoolItemIDs: [UUID] = []
    @State private var baselineChunks: [ChunkContainerState] = []

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

    /// Indices of chunks that have >= 3 actions.
    private var qualifyingChunkIndices: [Int] {
        chunks.indices.filter { chunks[$0].itemIDs.count >= 3 }
    }

    /// Step 3 Next enabled rule.
    private var isStep3NextEnabled: Bool {
        let qualifying = qualifyingChunkIndices
        guard qualifying.count >= 2 else { return false }
        return qualifying.allSatisfy { chunks[$0].selectionLabelId != nil }
    }

    private var isRefreshVisible: Bool {
        showHidden != baselineShowHidden ||
        poolItemIDs != baselinePoolItemIDs ||
        chunks != baselineChunks
    }

    @State private var navigateToStep4: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            Text("Chunk")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Categorize info row
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
            .padding(.horizontal)

            // Toggle row
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
            .padding(.horizontal)

            // Pool
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
                        return true
                    }
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listRowSeparator(.visible)
            }
            .listRowSpacing(4)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)
                return true
            }
            .onChange(of: showHidden) { _, _ in
                syncPoolWithVisibility()
            }

            // Chunks
            List {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, _ in
                    chunkContainerView(chunkIndex: index)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                if chunks.count < maxChunks {
                    addChunkRow
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Refresh button (small text, no shape; only visible if modified)
            if isRefreshVisible {
                Button {
                    refreshStep3()
                } label: {
                    Text("Refresh")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.top, 2)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 2)
            }

            // Back/Next
            HStack(spacing: 12) {
                Button {
                    dismiss()
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
                    persistStep3PlanAndAdvance()
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!isStep3NextEnabled)
            }
            .padding(.horizontal)
            .padding(.bottom, 2)
        }
        .safeAreaPadding()
        .fullScreenCover(isPresented: $navigateToStep4) {
            PlanStepFourView()
        }
        .onAppear {
            PlanLabelSeeder.seedDefaultsIfNeeded(in: modelContext)

            if chunks.isEmpty {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }
            if poolItemIDs.isEmpty {
                poolItemIDs = initialPoolIDs
            } else {
                syncPoolWithVisibility()
            }

            // Capture baseline after we've initialized state.
            if baselineChunks.isEmpty && baselinePoolItemIDs.isEmpty {
                baselineShowHidden = showHidden
                baselinePoolItemIDs = poolItemIDs
                baselineChunks = chunks
            }

            // IMPORTANT: Do not hydrate from stored selections on appear.
            // Step 3 should not store anything until "Next", and Refresh should return to "Select…".
        }
        .onChange(of: allItems.map(\.id)) { _, _ in
            syncPoolWithVisibility()
        }
    }

    // MARK: - Add Chunk row

    private var addChunkRow: some View {
        Button {
            addChunkContainer()
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

    // MARK: - Derived data

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

    // MARK: - UI pieces

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
                .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.25), lineWidth: 1)
        )
        .dropDestination(for: DragPayload.self) { payloads, _ in
            guard let payload = payloads.first else { return false }
            moveItem(payload.itemID, toChunkAt: chunkIndex)
            return true
        }
    }

    private func chunkItems(for chunkIndex: Int) -> [RollingCaptureItem] {
        let ids = chunks[chunkIndex].itemIDs
        let byID = Dictionary(uniqueKeysWithValues: visibleItems.map { ($0.id, $0) })
        return ids.compactMap { byID[$0] }
    }

    // MARK: - Picker behavior (NO persistence until Next)

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

    // MARK: - Step 3 "Refresh"

    private func refreshStep3() {
        // Reset ALL UI state back to default:
        // - Move all visible items back into pool
        // - Clear chunks (actions)
        // - Reset pickers to "Select…"
        for i in chunks.indices {
            chunks[i].itemIDs = []
            chunks[i].selectionLabelId = nil
            chunks[i].selectionLabel = nil
            chunks[i].selectionCategoryId = nil
            chunks[i].selectionCategory = nil
        }

        poolItemIDs = initialPoolIDs
        syncPoolWithVisibility()
    }

    // MARK: - Step 3 "Next" = save plan + advance
    //
    // IMPORTANT changes vs previous behavior:
    // - Do NOT delete RollingCaptureItem objects. That deletion was causing "empty chunks"
    //   when returning from Step 4, and it also removed items from Capture.
    // - Do NOT persist PlanChunkSelection on picker change. If you still want persisted picker
    //   state in the future, it should be written here (on Next) instead.

    private func persistStep3PlanAndAdvance() {
        guard isStep3NextEnabled else { return }

        let captureByID = Dictionary(uniqueKeysWithValues: allItems.map { ($0.id, $0) })

        // If the user goes back and re-plans the same week, wipe prior persisted plan for this week first.
        for action in plannedActions where Calendar.current.isDate(action.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(action)
        }
        for chunk in plannedChunks where Calendar.current.isDate(chunk.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(chunk)
        }

        // Also remove any previously stored picker selections for this week (since we aren't using them anymore).
        for sel in allChunkSelections where Calendar.current.isDate(sel.weekStart, inSameDayAs: currentWeekStart) {
            modelContext.delete(sel)
        }

        // Persist chunks (only those with actions, and they must be labeled to persist)
        for (chunkIndex, chunkState) in chunks.enumerated() where !chunkState.itemIDs.isEmpty {
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
        navigateToStep4 = true
    }

    // MARK: - Drag/drop moves

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

    // MARK: - Pool sync

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
    }

    // MARK: - Chunk management

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
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @State private var isShowingInstructions: Bool = false

    // Planned plan (from Step 3)
    @Query(sort: \PlannedChunk.chunkIndex, order: .forward)
    private var allPlannedChunks: [PlannedChunk]

    @Query(sort: \PlannedChunkAction.sortOrder, order: .forward)
    private var allPlannedActions: [PlannedChunkAction]

    // Data for pickers
    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]

    @Query(sort: \Fulfillment.updatedAt, order: .reverse)
    private var fulfillments: [Fulfillment]

    @Query(sort: \FulfillmentRoles.rank, order: .forward)
    private var roles: [FulfillmentRoles]

    // UI-only Step 4 state, keyed by PlannedChunk.id
    @State private var resultTextByChunk: [UUID: String] = [:]
    @State private var purposeTextByChunk: [UUID: String] = [:]
    @State private var selectedOutcomeIDsByChunk: [UUID: [UUID]] = [:]
    @State private var selectedRoleIDByChunk: [UUID: UUID?] = [:]

    // Sheets
    @State private var outcomeSheetChunkID: UUID? = nil
    @State private var roleSheetChunkID: UUID? = nil

    private let targetIconName = "scope" // closest "target" icon used in app

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

    // MARK: - Cross-chunk uniqueness (Outcomes + Roles)

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

        // Roles are already limited to the chunk's category; then we remove roles used by other chunks.
        let rolesInCategory = rolesForPlannedChunk(chunk)
        let takenByOtherChunks = selectedRoleIDs(excludingChunk: chunk.id)
        return rolesInCategory.filter { !takenByOtherChunks.contains($0.id) }
    }

    var body: some View {
        VStack(spacing: 12) {
            Text("Plan")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            instructionsRow
                .padding(.horizontal)

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
                .padding(.horizontal)
                .padding(.bottom, 12)
            }

            HStack(spacing: 12) {
                Button {
                    dismiss()
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
            .padding(.horizontal)
            .padding(.bottom, 2)
        }
        .safeAreaPadding()
        .sheet(isPresented: $isShowingInstructions) {
            StepFourInstructionsPopup()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $outcomeSheetChunkID) { chunkID in
            OutcomePickerSheet(
                title: "Connect Outcome(s)",
                outcomes: availableOutcomes(forChunk: chunkID),
                selectedIDs: Binding(
                    get: { selectedOutcomeIDsByChunk[chunkID] ?? [] },
                    set: { newValue in
                        selectedOutcomeIDsByChunk[chunkID] = Array(newValue.prefix(3))
                    }
                ),
                maxSelection: 3
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .sheet(item: $roleSheetChunkID) { chunkID in
            let chunk = plannedChunksForWeek.first(where: { $0.id == chunkID })
            RolePickerSheet(
                title: "Connect Role",
                roles: availableRoles(forChunk: chunk),
                selectedRoleID: Binding(
                    get: { selectedRoleIDByChunk[chunkID] ?? nil },
                    set: { newValue in
                        selectedRoleIDByChunk[chunkID] = newValue
                    }
                )
            )
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
        .onAppear {
            // Seed default blank strings for stable TextField bindings
            for chunk in plannedChunksForWeek {
                if resultTextByChunk[chunk.id] == nil { resultTextByChunk[chunk.id] = "" }
                if purposeTextByChunk[chunk.id] == nil { purposeTextByChunk[chunk.id] = "" }
                if selectedOutcomeIDsByChunk[chunk.id] == nil { selectedOutcomeIDsByChunk[chunk.id] = [] }
                if selectedRoleIDByChunk[chunk.id] == nil { selectedRoleIDByChunk[chunk.id] = nil }
            }
        }
    }

    private var instructionsRow: some View {
        Button {
            isShowingInstructions = true
        } label: {
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

    // MARK: - Card

    @ViewBuilder
    private func chunkCard(_ chunk: PlannedChunk) -> some View {
        let chunkID = chunk.id
        let actions = actionsForChunk(chunk)

        VStack(alignment: .leading, spacing: 12) {

            // Header: Actions Related To + label RIGHT-aligned
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 0)

                Text(chunk.label)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .lineLimit(1)
            }

            Divider().opacity(0.4)

            // RESULT header row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("RESULT")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("What do I want?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Result input box (placeholder cleared)
            PlanSingleLineEntryBox(
                placeholder: "",
                text: Binding(
                    get: { resultTextByChunk[chunkID] ?? "" },
                    set: { resultTextByChunk[chunkID] = $0 }
                )
            )

            // Connect Outcome(s) button row
            Button {
                outcomeSheetChunkID = chunkID
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: targetIconName)
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Connect Outcome(s)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    Text("optional")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
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

            // Selected outcomes list
            let selectedOutcomes = outcomesForChunk(chunk)
            if !selectedOutcomes.isEmpty {
                VStack(spacing: 8) {
                    ForEach(selectedOutcomes, id: \.outcome_id) { outcome in
                        HStack(spacing: 10) {
                            Image(systemName: targetIconName)
                                .font(.system(size: 16, weight: .semibold))
                                .foregroundStyle(.secondary)

                            Text(outcome.outcome)
                                .font(.subheadline)
                                .foregroundStyle(.primary)
                                .lineLimit(2)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Button {
                                removeOutcome(outcome, from: chunk)
                            } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .font(.system(size: 18, weight: .semibold))
                                    .foregroundStyle(.secondary)
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

            // PURPOSE header row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("PURPOSE")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()

                Text("Why do I want it?")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            // Connect Role button row (NO "optional" text)
            Button {
                roleSheetChunkID = chunkID
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: "trophy")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(.secondary)

                    Text("Connect Role")
                        .font(.subheadline)
                        .foregroundStyle(.primary)

                    Spacer(minLength: 0)

                    if let selectedRoleName = selectedRoleName(for: chunk) {
                        Text(selectedRoleName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }

                    Image(systemName: "chevron.right")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.secondary)
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

            // Purpose input box (placeholder cleared)
            PlanSingleLineEntryBox(
                placeholder: "",
                text: Binding(
                    get: { purposeTextByChunk[chunkID] ?? "" },
                    set: { purposeTextByChunk[chunkID] = $0 }
                )
            )

            Divider().opacity(0.4)

            // ACTIONS header row
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("ACTIONS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Spacer()
            }

            // Actions list
            VStack(alignment: .leading, spacing: 8) {
                ForEach(actions) { action in
                    Text("• \(action.text)")
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(
                    colorScheme == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.12),
                    lineWidth: 1
                )
        )
    }

    // MARK: - Derived helpers

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
        guard let fulfillment = fulfillmentForCategoryName(chunk.category) else {
            return []
        }
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

    private func suggestedPurpose(for chunk: PlannedChunk) -> String {
        let selectedOutcomes = outcomesForChunk(chunk)
        if selectedOutcomes.count == 1 {
            return selectedOutcomes[0].reasons.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        if let f = fulfillmentForCategoryName(chunk.category) {
            return f.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return ""
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

                    // Result
                    Group {
                        (
                            Text("Result: ")
                                .fontWeight(.bold)
                            + Text("What do I want?")
                                .italic()
                                .underline()
                        )
                        .font(.body)

                        Text("What’s the most important result or outcome you want to have happen today? What are you really committed to achieving?")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Divider().padding(.vertical, 2)

                    // Purpose
                    Group {
                        (
                            Text("Purpose: ")
                                .fontWeight(.bold)
                            + Text("Why do I want it?")
                                .italic()
                                .underline()
                        )
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

                    // Actions
                    Group {
                        (
                            Text("Actions: ")
                                .fontWeight(.bold)
                            + Text("How can I best achieve it now?")
                                .italic()
                                .underline()
                        )
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

// MARK: - Step 4 supporting views (UI-only)

private struct PlanSingleLineEntryBox: View {
    let placeholder: String
    @Binding var text: String

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        TextField(placeholder, text: $text)
            .font(.subheadline)
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .background(Color(.systemBackground), in: RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(
                        colorScheme == .dark ? Color.white.opacity(0.22) : Color.black.opacity(0.18),
                        lineWidth: 1
                    )
            )
    }
}

private struct OutcomePickerSheet: View {
    let title: String
    let outcomes: [Outcomes]
    @Binding var selectedIDs: [UUID]
    let maxSelection: Int

    @Environment(\.dismiss) private var dismiss

    private func isSelected(_ id: UUID) -> Bool {
        selectedIDs.contains(id)
    }

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
                            if isSelected(role.id) {
                                selectedRoleID = nil
                            } else {
                                selectedRoleID = role.id
                            }
                        } label: {
                            HStack {
                                Text(role.role)
                                    .foregroundStyle(.primary)

                                Spacer()

                                if isSelected(role.id) {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.blue)
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

// MARK: - Step 3 supporting types (UI-only)

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

// MARK: - tiny helper
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

extension UUID: @retroactive Identifiable {
    public var id: UUID { self }
}
