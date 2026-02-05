import SwiftUI

struct Note: Identifiable, Hashable {
    let id = UUID()
    let text: String
}

struct CaptureView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var notes: [Note] = []
    @State private var newText: String = ""
    @State private var selection = Set<UUID>()
    @State private var editMode: EditMode = .inactive
    @FocusState private var isTextFieldFocused: Bool
    @State private var selectedIcon: Int = 0 // 0: -, 1: star, 2: down

    var iconNames = ["person", "mappin.and.ellipse", "bell", "calendar"]
    var sliderIcons = ["minus", "star", "arrow.down"]

    var body: some View {
        NavigationView {
            VStack {
                // Scrollable notes list
                List(selection: $selection) {
                    ForEach(notes) { note in
                        Text(note.text)
                            .lineLimit(2)
                            .truncationMode(.tail)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                }
                .environment(\.editMode, $editMode)

                // Input area above keyboard
                VStack(spacing: 8) {
                    TextField("Enter note...", text: $newText)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .focused($isTextFieldFocused)

                    HStack {
                        // Left icons
                        ForEach(iconNames, id: \.self) { name in
                            Image(systemName: name)
                                .font(.title2)
                        }
                        Spacer()
                        // Slider selector
                        HStack {
                            ForEach(0..<sliderIcons.count, id: \.self) { idx in
                                Button(action: { selectedIcon = idx }) {
                                    Image(systemName: sliderIcons[idx])
                                        .font(.title2)
                                        .opacity(selectedIcon == idx ? 1 : 0.5)
                                }
                            }
                        }
                        Spacer()
                        // Add notes button
                        Button("Add notes") {
                            guard !newText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
                            notes.append(Note(text: newText))
                            newText = ""
                            isTextFieldFocused = true
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.horizontal)
                }
                .padding(.bottom, 8)
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    HStack {
                        Button {
                            editMode = editMode.isEditing ? .inactive : .active
                            if editMode == .inactive {
                                // delete selected
                                notes.removeAll { selection.contains($0.id) }
                                selection.removeAll()
                            }
                        } label: {
                            Image(systemName: editMode.isEditing ? "trash" : "pencil")
                        }
                        Button(action: { /* share action */ }) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(action: { /* sort action */ }) {
                            Image(systemName: "arrow.up.arrow.down")
                        }
                        Button(action: { /* filter action */ }) {
                            Image(systemName: "line.horizontal.3.decrease.circle")
                        }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .onAppear {
            isTextFieldFocused = true
        }
    }
}
