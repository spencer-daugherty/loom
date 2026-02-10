import SwiftUI

private struct CaptureItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isGhost: Bool
    let createdAt: Date
    let unhideDate: Date?
}

private struct PopoverHeightPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

struct CaptureView: View {
    @State private var input: String = ""
    @State private var items: [CaptureItem] = []
    @State private var isGhostOn: Bool = false
    @FocusState private var isInputFocused: Bool
    @Environment(\.colorScheme) private var colorScheme
    
    @State private var selectedUnhideDate: Date? = nil
    @State private var isDatePickerPresented: Bool = false
    @State private var datePickerTempDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
    @State private var popoverDetentHeight: CGFloat = 520

    private var displayItems: [CaptureItem] {
        let base = isGhostOn ? items : items.filter { !$0.isGhost }
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
                    // List of items
                    List {
                        ForEach(displayItems) { item in
                            HStack(alignment: .firstTextBaseline, spacing: 8) {
                                Text(item.text)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                if let d = item.unhideDate {
                                    Text("Unhidden " + formatShortDate(d))
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
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        isInputFocused = true
                    }
                }
                .onChange(of: isInputFocused) { oldValue, newValue in
                    if newValue == false {
                        // If the date picker popover is open, don't force focus back yet
                        if isDatePickerPresented { return }
                        DispatchQueue.main.async {
                            isInputFocused = true
                        }
                    }
                }
                .onChange(of: isGhostOn) { oldValue, newValue in
                    if newValue == false { selectedUnhideDate = nil }
                }
                .onChange(of: isDatePickerPresented) { oldValue, newValue in
                    if newValue {
                        // Ensure keyboard is dismissed when popover opens
                        isInputFocused = false
                    } else {
                        // Restore keyboard shortly after the popover closes to avoid timing issues
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
                                    // Dismiss keyboard when presenting the date picker
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
                                        // Add a small safety inset and enforce a reasonable minimum to avoid layout issues
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
            // Prompt for a date if missing and prevent adding
            datePickerTempDate = earliestUnhideDate
            isDatePickerPresented = true
            return
        }
        let newItem = CaptureItem(
            text: trimmed,
            isGhost: isGhostOn,
            createdAt: Date(),
            unhideDate: selectedUnhideDate
        )
        items.append(newItem)

        // ---- NEW: reset the pill to a fresh state (clear the selected date)
        selectedUnhideDate = nil
        datePickerTempDate = earliestUnhideDate
        // keep isGhostOn as-is (toggle remains on if the user wants to add more ghosted items)

        input = ""
        isInputFocused = true
    }
    private func deleteItems(at offsets: IndexSet) {
        let idsToDelete = offsets.map { displayItems[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
    }
}
