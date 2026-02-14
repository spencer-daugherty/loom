import SwiftUI
import SwiftData

private struct PopoverHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CaptureView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]
    @Query(sort: \QuickCompletedCaptureItem.completedAt, order: .reverse)
    private var completedItems: [QuickCompletedCaptureItem]

    @State private var input: String = ""
    @State private var isGhostOn: Bool = false
    @FocusState private var focusedField: FocusField?

    @State private var selectedUnhideDate: Date? = nil
    @State private var isDatePickerPresented: Bool = false
    @State private var datePickerTempDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var popoverDetentHeight: CGFloat = 520
    @State private var inlineEditSaveTask: Task<Void, Never>? = nil
    @State private var showCompletedList: Bool = false
    @State private var showDuplicateHint: Bool = false
    @State private var shouldHighlightDuplicateInput: Bool = false
    @State private var duplicateMessage: String = "Duplicate: action is already entered"
    @State private var highlightedDuplicateItemID: UUID? = nil
    @State private var duplicateResetWorkItem: DispatchWorkItem? = nil

    private enum FocusField: Hashable {
        case newInput
        case item(UUID)
    }

    private var displayItems: [RollingCaptureItem] {
        // After auto-unhide runs, anything due will have isGhost=false, so filtering is straightforward.
        let base = isGhostOn ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            return $0.createdAt > $1.createdAt
        }
    }

    private var earliestUnhideDate: Date { Calendar.current.date(byAdding: .day, value: 7, to: Date())! }

    private func normalizedActionText(_ text: String) -> String {
        text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }

    private func formatShortDate(_ date: Date) -> String {
        let cal = Calendar.current
        let nowYear = cal.component(.year, from: Date())
        let year = cal.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale.current
        if year == nowYear {
            formatter.setLocalizedDateFormatFromTemplate("Md") // e.g., 7/14
        } else {
            formatter.setLocalizedDateFormatFromTemplate("Mdyy") // e.g., 7/14/24
        }
        return formatter.string(from: date)
    }

    var body: some View {
        NavigationView {
            ZStack {
                (colorScheme == .dark ? Color(.systemGroupedBackground) : Color.white).ignoresSafeArea()
                VStack(spacing: 12) {
                    ScrollViewReader { proxy in
                        List {
                            ForEach(displayItems) { item in
                                HStack(alignment: .firstTextBaseline, spacing: 8) {
                                    TextField(
                                        "Action",
                                        text: Binding(
                                            get: { item.text },
                                            set: { newValue in
                                                renameItemInline(item, to: newValue)
                                            }
                                        )
                                    )
                                    .font(.body.weight(.medium))
                                    .textFieldStyle(.plain)
                                    .focused($focusedField, equals: .item(item.id))
                                    .submitLabel(.done)
                                    .onSubmit {
                                        focusedField = .newInput
                                    }
                                        .frame(maxWidth: .infinity, alignment: .leading)

                                    if let d = item.unhiddenAt {
                                        Text("Unhidden " + formatShortDate(d))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else if item.isGhost, let scheduled = item.unhideDate {
                                        Text("Hidden until " + formatShortDate(scheduled))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .padding(8)
                                .padding(.vertical, 2)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                .overlay {
                                    if item.isGhost {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                                            .foregroundStyle(.blue)
                                    } else if highlightedDuplicateItemID == item.id {
                                        RoundedRectangle(cornerRadius: 8)
                                            .stroke(Color.red.opacity(0.85), lineWidth: 1.5)
                                    }
                                }
                                .padding(.vertical, 1)
                                .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)
                                .swipeActions(edge: .leading, allowsFullSwipe: true) {
                                    Button {
                                        quickCompleteItem(item)
                                    } label: {
                                        Text("Quick Complete")
                                    }
                                    .tint(.green)
                                }
                            }
                            .onDelete(perform: deleteItems)

                            if !completedItems.isEmpty {
                                Button {
                                    withAnimation(.easeInOut(duration: 0.2)) {
                                        showCompletedList.toggle()
                                    }
                                } label: {
                                    HStack(spacing: 6) {
                                        Image(systemName: showCompletedList ? "chevron.up" : "chevron.down")
                                            .font(.caption2.weight(.semibold))
                                        Text("Quickly Completed")
                                            .font(.caption2.weight(.semibold))
                                    }
                                    .foregroundStyle(colorScheme == .dark ? Color.white.opacity(0.68) : .black)
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
                                .id("completed-toggle")
                                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 0, trailing: 16))
                                .listRowSeparator(.hidden)

                                if showCompletedList {
                                    ForEach(Array(completedItems.enumerated()), id: \.element.id) { index, item in
                                        let row = HStack(alignment: .firstTextBaseline, spacing: 8) {
                                            Text(item.text)
                                                .font(.body.weight(.medium))
                                                .foregroundStyle(.secondary)
                                                .strikethrough(true, color: .secondary)
                                                .frame(maxWidth: .infinity, alignment: .leading)
                                        }
                                        .padding(8)
                                        .padding(.vertical, 2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                                        .padding(.vertical, 1)
                                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                                        .listRowSeparator(.hidden)
                                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                            Button {
                                                recaptureCompletedItem(item)
                                            } label: {
                                                Text("Recapture")
                                            }
                                            .tint(.gray)
                                        }
                                        if index == 0 {
                                            row.id("completed-list-start")
                                        } else {
                                            row
                                        }
                                    }
                                }
                            }
                        }
                        .listRowSpacing(4)
                        .listStyle(.plain)
                        .scrollContentBackground(.hidden)
                        .onChange(of: showCompletedList) { _, isShowing in
                            guard isShowing else { return }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                                withAnimation(.easeInOut(duration: 0.25)) {
                                    proxy.scrollTo("completed-list-start", anchor: .top)
                                }
                            }
                        }
                    }
                }
                .background(Color.clear)
                .navigationTitle("Rolling Capture")
                .navigationBarTitleDisplayMode(.inline)
                    .onAppear {
                        runAutoUnhideIfNeeded()
                        dedupeCaptureItemsIfNeeded()

                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                            focusedField = .newInput
                        }
                    }
                .onChange(of: scenePhase) { _, newPhase in
                    // Ensures items unhide when app comes back to foreground.
                    if newPhase == .active {
                        runAutoUnhideIfNeeded()
                        dedupeCaptureItemsIfNeeded()
                    }
                }
                .onChange(of: allItems.map(\.id)) { _, _ in
                    dedupeCaptureItemsIfNeeded()
                }
                .onChange(of: focusedField) { _, newValue in
                    if newValue == nil {
                        if isDatePickerPresented { return }
                        DispatchQueue.main.async {
                            focusedField = .newInput
                        }
                    }
                }
                .onChange(of: isGhostOn) { _, newValue in
                    if newValue == false { selectedUnhideDate = nil }
                }
                .onChange(of: isDatePickerPresented) { _, newValue in
                    if newValue {
                        focusedField = nil
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            focusedField = .newInput
                        }
                    }
                }
                .safeAreaInset(edge: .bottom) {
                    VStack(alignment: .trailing, spacing: 8) {
                        if isGhostOn && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                            HStack {
                                Spacer()
                                Button(action: {
                                    if let existing = selectedUnhideDate {
                                        datePickerTempDate = existing
                                    } else {
                                        datePickerTempDate = earliestUnhideDate
                                    }
                                    DispatchQueue.main.async {
                                        focusedField = nil
                                    }
                                    isDatePickerPresented = true
                                }) {
                                    HStack(spacing: 6) {
                                        Text(
                                            selectedUnhideDate != nil
                                            ? "Hide Action Until " + formatShortDate(selectedUnhideDate!)
                                            : "Hide Action Until"
                                        )
                                        .font(.subheadline)
                                        .foregroundStyle(selectedUnhideDate != nil ? Color.white : Color.primary)
                                        Image(systemName: "chevron.down")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(selectedUnhideDate != nil ? Color.white : Color.secondary)
                                    }
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 8)
                                    .background(
                                        (selectedUnhideDate != nil ? Color.blue : Color(.secondarySystemBackground))
                                    )
                                    .clipShape(Capsule())
                                    .overlay {
                                        if selectedUnhideDate == nil {
                                            Capsule()
                                                .stroke(colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3), lineWidth: 1)
                                        }
                                    }
                                }
                                .popover(isPresented: $isDatePickerPresented) {
                                    VStack(spacing: 0) {

                                        VStack(alignment: .leading, spacing: 0) {
                                            DatePicker(
                                                "Hide Action Until",
                                                selection: $datePickerTempDate,
                                                in: earliestUnhideDate...,
                                                displayedComponents: .date
                                            )
                                            .datePickerStyle(.graphical)
                                            .padding(.bottom, 0)

                                            HStack {
                                                Spacer(minLength: 0)
                                                Button(action: {
                                                    selectedUnhideDate = datePickerTempDate
                                                    isDatePickerPresented = false
                                                }) {
                                                    Text("Set Date")
                                                        .font(.headline)
                                                        .foregroundStyle(Color.white)
                                                        .padding(.horizontal, 16)
                                                        .padding(.vertical, 10)
                                                        .background(Color.blue)
                                                        .clipShape(Capsule())
                                                }
                                            }
                                            .padding(.top, -8)
                                        }
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 0)
                                    }
                                    .padding(.bottom, 8)
                                    .background(
                                        GeometryReader { proxy in
                                            Color.clear
                                                .preference(key: PopoverHeightPreferenceKey.self, value: proxy.size.height)
                                        }
                                    )
                                    .onPreferenceChange(PopoverHeightPreferenceKey.self) { h in
                                        popoverDetentHeight = max(520, h + 24)
                                    }
                                    .presentationDetents([.height(popoverDetentHeight)])
                                    .presentationDragIndicator(.visible)
                                }
                            }
                            .padding(.horizontal)
                        }

                        HStack(spacing: 12) {
                            TextField("Add an action…", text: $input)
                                .textInputAutocapitalization(.none)
                                .autocorrectionDisabled(true)
                                .focused($focusedField, equals: .newInput)
                                .submitLabel(.done)
                                .onSubmit(addItem)
                                .padding(12)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 10)
                                        .stroke(
                                            shouldHighlightDuplicateInput
                                            ? Color.red.opacity(0.85)
                                            : (colorScheme == .dark ? Color.white.opacity(0.35) : Color.black.opacity(0.3)),
                                            lineWidth: shouldHighlightDuplicateInput ? 1.5 : 1
                                        )
                                )
                                .layoutPriority(1)
                                .frame(maxWidth: .infinity)

                            Toggle(isOn: $isGhostOn) {
                                EmptyView()
                            }
                            .toggleStyle(.automatic)
                            .labelsHidden()
                            .frame(width: 60)

                            Image(systemName: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
                                .font(.system(size: 24, weight: .semibold))
                                .foregroundStyle(isGhostOn ? .blue : .secondary)
                                .accessibilityHidden(true)
                        }
                        .overlay(alignment: .top) {
                            if showDuplicateHint {
                                Text(duplicateMessage)
                                    .font(.footnote)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 8)
                                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 10)
                                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                                    )
                                    .offset(y: -58)
                                    .transition(.opacity)
                            }
                        }
                        .padding(.horizontal, 24)
                        .padding(.bottom, 24)
                    }
                    .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let duplicate = allItems.first(where: { normalizedActionText($0.text) == normalizedActionText(trimmed) }) {
            triggerDuplicateFeedback(duplicateID: duplicate.id)
            return
        }

        if isGhostOn && selectedUnhideDate == nil {
            datePickerTempDate = earliestUnhideDate
            isDatePickerPresented = true
            return
        }

        let newItem = RollingCaptureItem(
            text: trimmed,
            isGhost: isGhostOn,
            createdAt: .now,
            unhideDate: selectedUnhideDate,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)
        try? modelContext.save()

        selectedUnhideDate = nil
        datePickerTempDate = earliestUnhideDate

        input = ""
        focusedField = .newInput
    }

    private func deleteItems(at offsets: IndexSet) {
        for offset in offsets {
            let item = displayItems[offset]
            RecentlyDeletedStore.trash(item, in: modelContext)
        }
        try? modelContext.save()
    }

    private func renameItemInline(_ item: RollingCaptureItem, to rawText: String) {
        let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newNormalized = normalizedActionText(trimmed)
        let oldNormalized = normalizedActionText(item.text)

        if oldNormalized == newNormalized && item.text == trimmed {
            return
        }

        let duplicateExists = allItems.contains {
            $0.id != item.id && normalizedActionText($0.text) == newNormalized
        }
        if duplicateExists { return }

        item.text = trimmed
        scheduleInlineEditSave()
    }

    private func scheduleInlineEditSave() {
        inlineEditSaveTask?.cancel()
        inlineEditSaveTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 250_000_000)
            try? modelContext.save()
        }
    }

    private func runAutoUnhideIfNeeded() {
        // Define "today" as start-of-day so “<= today” is stable and matches the UI's date-only picker.
        let today = Calendar.current.startOfDay(for: .now)

        let dueGhosts = allItems.filter { item in
            guard item.isGhost, let d = item.unhideDate else { return false }
            return Calendar.current.startOfDay(for: d) <= today
        }

        guard !dueGhosts.isEmpty else { return }

        for item in dueGhosts {
            item.isGhost = false
            item.unhiddenAt = item.unhideDate ?? .now
            // Clear schedule now that it’s visible.
            item.unhideDate = nil
        }

        try? modelContext.save()
    }

    private func dedupeCaptureItemsIfNeeded() {
        var keeperByKey: [String: RollingCaptureItem] = [:]
        var toDelete: [RollingCaptureItem] = []

        for item in allItems {
            let key = normalizedActionText(item.text)
            guard !key.isEmpty else { continue }

            if let existing = keeperByKey[key] {
                let keepCurrent: Bool
                if item.isGhost != existing.isGhost {
                    // Prefer visible actions over hidden (ghost) when duplicates exist.
                    keepCurrent = !item.isGhost
                } else if item.createdAt != existing.createdAt {
                    keepCurrent = item.createdAt > existing.createdAt
                } else {
                    keepCurrent = item.id.uuidString > existing.id.uuidString
                }

                if keepCurrent {
                    toDelete.append(existing)
                    keeperByKey[key] = item
                } else {
                    toDelete.append(item)
                }
            } else {
                keeperByKey[key] = item
            }
        }

        guard !toDelete.isEmpty else { return }
        for item in toDelete {
            RecentlyDeletedStore.trash(item, in: modelContext, source: "Capture Deduplication")
        }
        try? modelContext.save()
    }

    private func quickCompleteItem(_ item: RollingCaptureItem) {
        modelContext.insert(QuickCompletedCaptureItem(text: item.text, completedAt: .now))
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private func recaptureCompletedItem(_ item: QuickCompletedCaptureItem) {
        let duplicateExists = allItems.contains {
            normalizedActionText($0.text) == normalizedActionText(item.text)
        }
        if !duplicateExists {
            modelContext.insert(RollingCaptureItem(
                text: item.text,
                isGhost: false,
                createdAt: .now,
                unhideDate: nil,
                unhiddenAt: nil
            ))
        }
        RecentlyDeletedStore.trash(item, in: modelContext)
        try? modelContext.save()
    }

    private func triggerDuplicateFeedback(duplicateID: UUID) {
        duplicateResetWorkItem?.cancel()
        shouldHighlightDuplicateInput = true
        highlightedDuplicateItemID = duplicateID
        withAnimation(.easeInOut(duration: 0.15)) {
            showDuplicateHint = true
        }

        let workItem = DispatchWorkItem {
            shouldHighlightDuplicateInput = false
            highlightedDuplicateItemID = nil
            withAnimation(.easeInOut(duration: 0.15)) {
                showDuplicateHint = false
            }
        }
        duplicateResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: workItem)
    }
}
