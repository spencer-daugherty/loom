import SwiftUI

private struct CaptureItem: Identifiable, Equatable {
    let id = UUID()
    let text: String
    let isGhost: Bool
    let createdAt: Date
}

struct CaptureView: View {
    @State private var input: String = ""
    @State private var items: [CaptureItem] = []
    @State private var isGhostOn: Bool = false
    @FocusState private var isInputFocused: Bool
    
    private var displayItems: [CaptureItem] {
        let base = isGhostOn ? items : items.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // List of items
                List {
                    ForEach(displayItems) { item in
                        Text(item.text)
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
            .safeAreaInset(edge: .bottom) {
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
                .background(Color(.systemBackground))
            }
        }
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        let newItem = CaptureItem(text: trimmed, isGhost: isGhostOn, createdAt: Date())
        items.append(newItem)
        input = ""
        isInputFocused = true
    }
    private func deleteItems(at offsets: IndexSet) {
        let idsToDelete = offsets.map { displayItems[$0].id }
        items.removeAll { idsToDelete.contains($0.id) }
    }
}

