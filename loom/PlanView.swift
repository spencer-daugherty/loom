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

            Spacer(minLength: 0)

            // Bottom buttons side-by-side (like Step 2)
            HStack(spacing: 12) {
                // CLOSE BUTTON
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

                // NEXT BUTTON
                Button {
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
        // Requirements:
        // - When showHidden OFF: show only non-ghost, newest first.
        // - When showHidden ON (only on this page): show in-session items first (new, non-ghost),
        //   then ghosts, then pre-session non-ghost items; newest first within each group.
        if !showHidden {
            return allItems
                .filter { !$0.isGhost }
                .sorted { $0.createdAt > $1.createdAt }
        }

        return allItems.sorted { lhs, rhs in
            let lhsIsBaseline = baselineItemIDs.contains(lhs.id)
            let rhsIsBaseline = baselineItemIDs.contains(rhs.id)

            // Group rank: 0 = in-session (non-ghost), 1 = ghosts, 2 = baseline non-ghost
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
            // Title
            Text("Capture")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Brainstorm info row (with Show more / Show less)
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
                        // Collapsed view: one line feel + trailing "Show more"
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

            // Toggle row (inline, above list)
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

            // List
            List {
                ForEach(displayItems) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // Icon rules:
                        // - Existing before session: plus.viewfinder
                        // - If ghost + showHidden ON: hidden icon
                        // - For items created in-session: no icon (and Step 2 cannot create ghosts)
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
                        // Optional: match CaptureView’s ghost styling when ghosts are shown
                        if item.isGhost {
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                .foregroundStyle(.blue)
                        }
                    }
                    // Symmetric spacing above/below each row box (so the divider gap matches)
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .onDelete(perform: deleteItems)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Bottom input (sticky keyboard)
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

            // Bottom Back/Next buttons (keep as-is stylistically)
            HStack(spacing: 12) {
                // Back button styled like Close on previous screen
                Button {
                    // Return to Step 1 (PlanView) by dismissing the modal sheet
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

                // Next button styled like Next on previous screen
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
            // Capture baseline IDs once per presentation.
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

    @State private var showHidden: Bool = false
    @State private var isCategorizeExpanded: Bool = false

    // Pool + chunked items are UI-only for now.
    @State private var poolItemIDs: [UUID] = []
    @State private var chunks: [ChunkContainerState] = []

    private let hiddenUntilLaterIconName = "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted"
    private let maxChunks = 5
    private let categories: [ChunkCategory] = [.social, .career, .administrative]

    var body: some View {
        VStack(spacing: 12) {
            Text("Chunk")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Categorize info row (with show more/less)
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

            // Toggle row (same as step 2)
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

            // Top list (pool)
            List {
                ForEach(poolItems) { item in
                    rowView(
                        text: item.text,
                        showGhostOutline: item.isGhost,
                        isDraggable: true,
                        dragPayload: DragPayload(itemID: item.id)
                    )
                    .contentShape(Rectangle())
                    // IMPORTANT: make the ROW itself a drop target.
                    // This is what allows dragging items out of a chunk and dropping “onto the pool list”.
                    .dropDestination(for: DragPayload.self) { payloads, _ in
                        guard let payload = payloads.first else { return false }
                        moveItemToPool(payload.itemID)
                        return true
                    }
                    // Match Step 2: symmetric space between the rounded box and list separators
                    .padding(.vertical, 4)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                }
                .listRowSeparator(.visible)
            }
            .listRowSpacing(4)
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Allow dropping back into pool (drop on empty space below rows too)
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)
                return true
            }
            // Fix: when toggle changes, ensure pool contains the newly-visible items (ghosts)
            .onChange(of: showHidden) { _, _ in
                syncPoolWithVisibility()
            }

            // Chunk containers
            // Move "+ Add Chunk" INTO this List as the last row, so it scrolls with the chunks.
            List {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, _ in
                    chunkContainerView(chunkIndex: index)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }

                // Add Chunk row (hide once max reached)
                if chunks.count < maxChunks {
                    addChunkRow
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            if canRefresh {
                Button {
                    resetStepThree()
                } label: {
                    Text("Refresh")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.vertical, 2)
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }

            // Back/Next buttons
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
                    // Step 4 placeholder
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
        .onAppear {
            // Initialize pool and chunks once per presentation.
            if chunks.isEmpty {
                chunks = [
                    ChunkContainerState(isLocked: true),
                    ChunkContainerState(isLocked: true),
                ]
            }
            if poolItemIDs.isEmpty {
                poolItemIDs = initialPoolIDs
            } else {
                // In case items changed since previous appearance (e.g. Step 2 added items)
                syncPoolWithVisibility()
            }
        }
        // Also keep pool in sync if the underlying SwiftData query changes.
        .onChange(of: allItems.map(\.id)) { _, _ in
            syncPoolWithVisibility()
        }
    }

    private var canRefresh: Bool {
        if showHidden { return true }
        if isCategorizeExpanded { return true }
        if chunks.count != 2 { return true }
        if chunks.contains(where: { !$0.itemIDs.isEmpty }) { return true }
        if chunks.contains(where: { $0.category != nil }) { return true }
        if poolItemIDs != initialPoolIDs { return true }
        return false
    }

    private func resetStepThree() {
        // "Start over" resets Step 3 UI-only state back to initial defaults.
        showHidden = false
        isCategorizeExpanded = false

        chunks = [
            ChunkContainerState(isLocked: true),
            ChunkContainerState(isLocked: true),
        ]

        // Rebuild pool from scratch using the same initial-load logic.
        poolItemIDs = initialPoolIDs
    }

    // MARK: - Add Chunk row (boxed, whole box tappable)

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
            .contentShape(Rectangle()) // ensures full interior is tappable
        }
        .buttonStyle(.plain) // keep our custom box styling
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

            // Only the HANDLE is draggable, not the entire row.
            // This prevents the chunk/category container from feeling draggable.
            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Drag")
                .contentShape(Rectangle()) // make the handle easier to grab
                .padding(.leading, 4)
                .if(isDraggable && dragPayload != nil, transform: { view in
                    view.draggable(dragPayload!) {
                        // Explicit preview so the system doesn't snapshot the whole chunk container.
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Text(text)
                                .lineLimit(1)
                                .frame(maxWidth: .infinity, alignment: .leading)

                            Image(systemName: "arrow.up.and.down.and.arrow.left.and.right")
                                .foregroundStyle(.secondary)
                        }
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                        .frame(maxWidth: 320) // keep preview compact
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
            // Header:
            // - "Actions Related To:" left aligned
            // - Picker immediately after with minimal spacing (left aligned)
            // - Spacer pushes delete button to far right
            HStack(alignment: .center, spacing: 6) {
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)

                Picker(
                    "",
                    selection: Binding(
                        get: { chunks[chunkIndex].category },
                        set: { newValue in
                            setChunkCategory(chunkIndex: chunkIndex, to: newValue)
                        }
                    )
                ) {
                    Text("Select…").tag(ChunkCategory?.none)
                    ForEach(categories) { cat in
                        Text(cat.displayName)
                            .tag(Optional(cat))
                            .disabled(isCategoryTaken(cat, excluding: chunkIndex))
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

            // Items inside chunk
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
                        // IMPORTANT: make each ROW inside the chunk a drop target.
                        // This is what enables:
                        // - dragging an item OUT of this chunk and INTO another chunk
                        // - dragging an item OUT and back to the pool
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
        // Chunk container remains a DROP TARGET too (drop onto empty space / below rows).
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

    // MARK: - Category selection rules

    private func isCategoryTaken(_ category: ChunkCategory, excluding index: Int) -> Bool {
        chunks.enumerated().contains { i, c in
            i != index && c.category == category
        }
    }

    private func setChunkCategory(chunkIndex: Int, to newValue: ChunkCategory?) {
        // Enforce uniqueness (ignore attempt if already taken elsewhere).
        if let newValue, isCategoryTaken(newValue, excluding: chunkIndex) {
            return
        }
        chunks[chunkIndex].category = newValue
    }

    // MARK: - Drag/drop moves

    private func moveItem(_ itemID: UUID, toChunkAt chunkIndex: Int) {
        // Remove from pool if present.
        if let idx = poolItemIDs.firstIndex(of: itemID) {
            poolItemIDs.remove(at: idx)
        }

        // Remove from any other chunk.
        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        // Add to target chunk (append)
        if !chunks[chunkIndex].itemIDs.contains(itemID) {
            chunks[chunkIndex].itemIDs.append(itemID)
        }
    }

    private func moveItemToPool(_ itemID: UUID) {
        // Remove from any chunk.
        for i in chunks.indices {
            if let existingIndex = chunks[i].itemIDs.firstIndex(of: itemID) {
                chunks[i].itemIDs.remove(at: existingIndex)
            }
        }

        // Add back to pool (top)
        if !poolItemIDs.contains(itemID) {
            poolItemIDs.insert(itemID, at: 0)
        }
    }

    // MARK: - Pool sync (fix showHidden toggle not revealing ghosts)

    private func syncPoolWithVisibility() {
        // Keep chunk membership, but ensure pool is a valid subset of currently-visible items.
        let visibleIDSet = Set(visibleItems.map(\.id))

        // Anything already chunked should stay out of the pool.
        let chunkedIDs = Set(chunks.flatMap(\.itemIDs))

        // Filter pool to what's still visible and not chunked.
        poolItemIDs = poolItemIDs.filter { visibleIDSet.contains($0) && !chunkedIDs.contains($0) }

        // Add any newly-visible items that aren't in pool and aren't chunked (prepend newest-ish by visibleItems order).
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
        // First two cannot be deleted.
        guard index >= 2 else { return false }
        // Only deletable if empty.
        return chunks[index].itemIDs.isEmpty
    }

    private func deleteChunkContainerIfAllowed(at index: Int) {
        guard canDeleteChunk(at: index) else { return }
        chunks.remove(at: index)
    }
}

// MARK: - Step 3 supporting types (UI-only)

private struct DragPayload: Codable, Hashable, Transferable {
    let itemID: UUID
    static var transferRepresentation: some TransferRepresentation {
        CodableRepresentation(contentType: .data)
    }
}

private enum ChunkCategory: String, CaseIterable, Identifiable {
    case social
    case career
    case administrative

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .social: return "Social"
        case .career: return "Career"
        case .administrative: return "Administrative"
        }
    }
}

private struct ChunkContainerState: Identifiable, Hashable {
    var id: UUID = .init()
    var isLocked: Bool
    var category: ChunkCategory? = nil
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

