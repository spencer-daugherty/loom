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

    @State private var input: String = ""
    @State private var isGhostOn: Bool = false
    @FocusState private var isInputFocused: Bool

    @State private var selectedUnhideDate: Date? = nil
    @State private var isDatePickerPresented: Bool = false
    @State private var datePickerTempDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var popoverDetentHeight: CGFloat = 520

    private var displayItems: [RollingCaptureItem] {
        // After auto-unhide runs, anything due will have isGhost=false, so filtering is straightforward.
        let base = isGhostOn ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            return $0.createdAt > $1.createdAt
        }
    }

    private var earliestUnhideDate: Date { Calendar.current.date(byAdding: .day, value: 7, to: Date())! }

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
                    List {
                        ForEach(displayItems) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)

                                // Show unhide history if present (matches your existing “Unhidden …” UI).
                                if let d = item.unhiddenAt {
                                    Text("Unhidden " + formatShortDate(d))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                } else if item.isGhost, let scheduled = item.unhideDate {
                                    // Optional: If you prefer not to show this, remove it.
                                    Text("Hidden until " + formatShortDate(scheduled))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
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
                            .padding(.vertical, 1)
                            .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                        }
                        .onDelete(perform: deleteItems)
                    }
                    .listRowSpacing(4)
                    .listStyle(.plain)
                    .scrollContentBackground(.hidden)
                }
                .background(Color.clear)
                .navigationTitle("Rolling Capture")
                .navigationBarTitleDisplayMode(.inline)
                .onAppear {
                    runAutoUnhideIfNeeded()

                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }
                .onChange(of: scenePhase) { _, newPhase in
                    // Ensures items unhide when app comes back to foreground.
                    if newPhase == .active {
                        runAutoUnhideIfNeeded()
                    }
                }
                .onChange(of: isInputFocused) { _, newValue in
                    if newValue == false {
                        if isDatePickerPresented { return }
                        DispatchQueue.main.async {
                            isInputFocused = true
                        }
                    }
                }
                .onChange(of: isGhostOn) { _, newValue in
                    if newValue == false { selectedUnhideDate = nil }
                }
                .onChange(of: isDatePickerPresented) { _, newValue in
                    if newValue {
                        isInputFocused = false
                    } else {
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            isInputFocused = true
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
                                        isInputFocused = false
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
        isInputFocused = true
    }

    private func deleteItems(at offsets: IndexSet) {
        for offset in offsets {
            let item = displayItems[offset]
            modelContext.delete(item)
        }
        try? modelContext.save()
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
}
