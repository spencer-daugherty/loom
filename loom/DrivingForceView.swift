import SwiftUI
import SwiftData

// MARK: - Supporting Types
struct PassionCategory {
    let emotion: String
    let title: String
    let prompt: String
    let query: [Passion]
}

struct AddState {
    var isAdding: Bool = false
    var newText: String = ""
}

enum Field: Hashable {
    case vision, purpose, passion(String)
}

struct DrivingForceView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    
    // Passion queries for each emotion
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "love" },
        sort: \Passion.date,
        order: .forward
    ) private var lovePassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "vows" },
        sort: \Passion.date,
        order: .forward
    ) private var vowsPassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "thrill" },
        sort: \Passion.date,
        order: .forward
    ) private var thrillPassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "just" },
        sort: \Passion.date,
        order: .forward
    ) private var justPassions: [Passion]
    
    // Consolidated passion categories
    private var passionQueries: [PassionCategory] {
        [
            PassionCategory(emotion: "love", title: "Love", prompt: "What do I love?", query: lovePassions),
            PassionCategory(emotion: "vows", title: "Vows", prompt: "What am I committed to?", query: vowsPassions),
            PassionCategory(emotion: "thrill", title: "Thrill", prompt: "What excites me?", query: thrillPassions),
            PassionCategory(emotion: "just", title: "Hate", prompt: "What do I hate?", query: justPassions)
        ]
    }
    
    @State private var visionText: String = ""
    @State private var purposeText: String = ""
    @State private var addStates: [String: AddState] = [:]
    @State private var isShowingInstructions: Bool = false
    @FocusState private var focusedField: Field?
    
    var body: some View {
        Form {
            textEditorSection(
                title: "Ultimate Vision",
                text: $visionText,
                field: .vision,
                placeholder: """
                Imagine there are no limits. What do you want to be, do, have or create in your life overall? What does your ideal life look and feel like?
                """
            )
            
            textEditorSection(
                title: "Ultimate Purpose",
                text: $purposeText,
                field: .purpose,
                placeholder: """
                What gets you up in the morning? What keeps you going? What could... if you were really excited about it? What are the reasons WHY you want your life to be this way? What will it give you? How will it make you feel?
                """
            )
            
            Text("Passions")
                .font(.title2).bold()
                .listRowBackground(Color.clear)
                .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            
            ForEach(passionQueries, id: \.emotion) { category in
                PassionEditor(
                    category: category,
                    addState: addStates[category.emotion] ?? AddState(),
                    onAddStateChange: { newState in
                        addStates[category.emotion] = newState
                    },
                    focusedField: $focusedField,
                    onCommit: { text in
                        commitPassion(text: text, emotion: category.emotion)
                    },
                    onDelete: deletePassion
                )
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .vision || focusedField == .purpose {
                    HStack {
                        Spacer()
                        Button("Save") {
                            saveChanges()
                            focusedField = nil
                        }
                        .fontWeight(.semibold)
                        .padding(.trailing)
                    }
                    .frame(maxWidth: .infinity)
                    .background(Color.white)
                }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button {
                    isShowingInstructions = true
                } label: {
                    Image(systemName: "graduationcap")
                        .font(.title2)
                }
                .buttonStyle(.plain)
            }
        }
        .navigationTitle("Driving Force")
        .background(
            Color.clear
                .contentShape(Rectangle())
                .onTapGesture {
                    focusedField = nil
                    hideKeyboard()
                }
        )
        .task {
            if let existing = drivingForces.first {
                visionText = existing.ultimateVision
                purposeText = existing.ultimatePurpose
            }
        }
        .sheet(isPresented: $isShowingInstructions) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Instructions")
                    .font(.headline)
                Text("Placeholder instructions text for Driving Force.")
                    .font(.body)
                Spacer(minLength: 0)
            }
            .padding()
            .presentationDetents([.medium])
            .presentationDragIndicator(.visible)
        }
    }

    private func textEditorSection(
        title: String,
        text: Binding<String>,
        field: Field,
        placeholder: String
    ) -> some View {
        Section(title) {
            ZStack(alignment: .topLeading) {
                if text.wrappedValue.isEmpty {
                    Text(placeholder)
                        .foregroundColor(.gray)
                        .padding(.top, 8)
                        .padding(.horizontal, 4)
                }
                TextEditor(text: text)
                    .frame(height: 100)
                    .focused($focusedField, equals: field)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }
    
    private func commitPassion(text: String, emotion: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addStates[emotion] = AddState()
            return
        }
        let passion = Passion(date: .now, emotion: emotion, passion: trimmed)
        context.insert(passion)
        addStates[emotion] = AddState()
        hideKeyboard()
    }
    
    private func deletePassion(_ passion: Passion) {
        let archive = PassionArchive(
            date: passion.date,
            emotion: passion.emotion,
            passionSnapshot: passion.passion,
            archivedAt: .now
        )
        context.insert(archive)
        context.delete(passion)
    }
    
    private func saveChanges() {
        let trimmedVision = visionText.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedPurpose = purposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        guard !trimmedVision.isEmpty || !trimmedPurpose.isEmpty else { return }
        
        let now = Date()
        if let existing = drivingForces.first {
            let archive = DrivingForceArchive(
                visionSnapshot: existing.ultimateVision,
                purposeSnapshot: existing.ultimatePurpose,
                archivedAt: existing.updatedAt
            )
            context.insert(archive)
            
            if !trimmedVision.isEmpty {
                existing.ultimateVision = trimmedVision
            }
            if !trimmedPurpose.isEmpty {
                existing.ultimatePurpose = trimmedPurpose
            }
            existing.updatedAt = now
        } else {
            let newDF = DrivingForce(
                ultimateVision: trimmedVision,
                ultimatePurpose: trimmedPurpose,
                updatedAt: now
            )
            context.insert(newDF)
        }
        
        try? context.save()
    }
}

struct PassionEditor: View {
    let category: PassionCategory
    let addState: AddState
    let onAddStateChange: (AddState) -> Void
    @FocusState.Binding var focusedField: Field?
    let onCommit: (String) -> Void
    let onDelete: (Passion) -> Void
    @Environment(\.modelContext) private var context
    @State private var editingPassion: Passion?
    @State private var editText: String = ""
    
    var body: some View {
        Section(category.title) {
            ForEach(category.query, id: \.id) { passion in
                if editingPassion?.id == passion.id {
                    TextField("Edit passion", text: $editText)
                        .focused($focusedField, equals: .passion(category.emotion))
                        .submitLabel(.done)
                        .onSubmit {
                            commitEdit(passion: passion)
                        }
                } else {
                    Text(passion.passion)
                        .onTapGesture {
                            startEditing(passion)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(passion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .tint(.red)
                }
            }
            
            if addState.isAdding {
                HStack {
                    TextField(category.prompt, text: Binding(
                        get: { addState.newText },
                        set: { onAddStateChange(addStateWithNewText($0)) }
                    ))
                    .focused($focusedField, equals: .passion(category.emotion))
                    .submitLabel(.done)
                    .onSubmit { onCommit(addState.newText) }
                    Spacer()
                }
                .padding(.vertical, 4)
            } else {
                Button("Add Item") {
                    withAnimation {
                        onAddStateChange(AddState(isAdding: true))
                        focusedField = .passion(category.emotion)
                    }
                }
                .foregroundColor(.blue)
                .padding(.vertical, 4)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }
    
    private func addStateWithNewText(_ text: String) -> AddState {
        var newState = addState
        newState.newText = text
        return newState
    }
    
    private func startEditing(_ passion: Passion) {
        editingPassion = passion
        editText = passion.passion
        focusedField = .passion(category.emotion)
    }
    
    private func commitEdit(passion: Passion) {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            context.delete(passion)
            editingPassion = nil
            return
        }
        
        let archive = PassionArchive(
            date: passion.date,
            emotion: passion.emotion,
            passionSnapshot: passion.passion,
            archivedAt: .now
        )
        context.insert(archive)
        
        passion.passion = trimmed
        passion.date = .now
        editingPassion = nil
        hideKeyboard()
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif
