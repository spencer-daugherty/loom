import SwiftUI

private struct CaptureItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isGhost: Bool
    let createdAt: Date
    let unhideDate: Date?
}

struct CaptureView: View {
    @State private var input: String = ""
    @State private var items: [CaptureItem] = []
    @State private var isGhostOn: Bool = false
    @FocusState private var isInputFocused: Bool
    
    @State private var selectedUnhideDate: Date? = nil
    @State private var isDatePickerPresented: Bool = false
    @State private var datePickerTempDate: Date = Calendar.current.date(byAdding: .day, value: 7, to: Date())!

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
                        .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 0, trailing: 0))
                    }
                    .onDelete(perform: deleteItems)
                }
                .listRowSpacing(4)
                .listStyle(.plain)
            }
            .padding()
            .navigationTitle("Rolling Capture")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    isInputFocused = true
                }
            }
            .onChange(of: isInputFocused) { oldValue, newValue in
                if newValue == false {
                    DispatchQueue.main.async {
                        isInputFocused = true
                    }
                }
            }
            .onChange(of: isGhostOn) { oldValue, newValue in
                if newValue == false { selectedUnhideDate = nil }
            }
            .safeAreaInset(edge: .bottom) {
                VStack(alignment: .trailing, spacing: 4) {
                    if isGhostOn && !input.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        HStack {
                            Spacer()
                            Button(action: {
                                if let existing = selectedUnhideDate {
                                    datePickerTempDate = existing
                                } else {
                                    datePickerTempDate = earliestUnhideDate
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
                                    .foregroundStyle(.primary)
                                    Image(systemName: "chevron.down")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 8)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(Capsule())
                            }
                            .popover(isPresented: $isDatePickerPresented) {
                                VStack(alignment: .leading, spacing: 12) {
                                    DatePicker(
                                        "Hide Action Until",
                                        selection: $datePickerTempDate,
                                        in: earliestUnhideDate...,
                                        displayedComponents: .date
                                    )
                                    .datePickerStyle(.graphical)
                                    HStack {
                                        Spacer()
                                        Button("Set Date") {
                                            selectedUnhideDate = datePickerTempDate
                                            isDatePickerPresented = false
                                        }
                                    }
                                }
                                .padding()
                            }
                        }
                        .padding(.horizontal)
                    }
                    HStack(spacing: 12) {
                        TextField("Enter new item…", text: $input)
                            .textInputAutocapitalization(.none)
                            .autocorrectionDisabled(true)
                            .focused($isInputFocused)
                            .submitLabel(.done)
                            .onSubmit(addItem)
                            .padding(12)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
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
                    .padding([.horizontal, .top])
                    .padding(.bottom, 12)
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
        input = ""
        isInputFocused = true
    }
    private func deleteItems(at offsets: IndexSet) {
        let idsToDelete = offsets.map { displayItems[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
    }
}

