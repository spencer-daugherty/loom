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
                    rowView(text: item.text, showGhostOutline: item.isGhost)
                        .contentShape(Rectangle())
                        .draggable(DragPayload(itemID: item.id))
                        .dropDestination(for: DragPayload.self) { _, _ in
                            // no-op for row itself; pool list is handled by outer dropDestination below
                            false
                        }
                        .listRowSeparator(.visible)
                }
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)
            // Allow dropping back into pool
            .dropDestination(for: DragPayload.self) { payloads, _ in
                guard let payload = payloads.first else { return false }
                moveItemToPool(payload.itemID)
                return true
            }

            // Chunk containers
            List {
                ForEach(Array(chunks.enumerated()), id: \.element.id) { index, chunk in
                    chunkContainerView(chunkIndex: index)
                        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                        .listRowSeparator(.hidden)
                }
                .onDelete(perform: deleteChunkContainers)
            }
            .listStyle(.plain)
            .scrollContentBackground(.hidden)

            // Add Chunk button
            Button {
                addChunkContainer()
            } label: {
                Label("Add Chunk", systemImage: "plus")
                    .font(.headline)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .buttonStyle(.plain)
            .padding(.horizontal)
            .padding(.top, 4)

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
            }
        }
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
    private func rowView(text: String, showGhostOutline: Bool) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(text)
                .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .accessibilityLabel("Drag")
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
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private func chunkContainerView(chunkIndex: Int) -> some View {
        let chunk = chunks[chunkIndex]

        VStack(spacing: 10) {
            // Header with centered title + picker
            VStack(spacing: 6) {
                Text("Actions Related To:")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)

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
            }
            .frame(maxWidth: .infinity)

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
                        rowView(text: item.text, showGhostOutline: item.isGhost)
                            .draggable(DragPayload(itemID: item.id))
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
        .swipeActions(edge: .trailing, allowsFullSwipe: false) {
            Button(role: .destructive) {
                deleteChunkContainerIfAllowed(at: chunkIndex)
            } label: {
                Text("Delete")
            }
            .disabled(!canDeleteChunk(at: chunkIndex))
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

    private func deleteChunkContainers(at offsets: IndexSet) {
        // Support swipe delete from List editing gestures; apply the same rules.
        for index in offsets.sorted(by: >) {
            deleteChunkContainerIfAllowed(at: index)
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
