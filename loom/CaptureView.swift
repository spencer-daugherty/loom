import SwiftUI

struct CaptureView: View {
    @State private var input: String = ""
    @State private var items: [String] = []
    @FocusState private var isInputFocused: Bool

    var body: some View {
        NavigationView {
            VStack(spacing: 12) {
                // List of items
                List {
                    ForEach(items, id: \.self) { item in
                        Text(item)
                    }
                    .onDelete(perform: deleteItems)
                }
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
                HStack {
                    TextField("Enter new item…", text: $input)
                        .textInputAutocapitalization(.none)
                        .autocorrectionDisabled(true)
                        .focused($isInputFocused)
                        .submitLabel(.done)
                        .onSubmit(addItem)
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                        .frame(maxWidth: .infinity)
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
        items.append(trimmed)
        input = ""
        isInputFocused = true
    }
    private func deleteItems(at offsets: IndexSet) {
        items.remove(atOffsets: offsets)
    }
}

