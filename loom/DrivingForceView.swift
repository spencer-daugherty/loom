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
    case passion(String)
}

struct DrivingForceView: View {
    let autoOpenCreateVision: Bool
    @Environment(\.modelContext) private var context
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \DrivingForceArchive.archivedAt, order: .reverse) private var drivingForceArchives: [DrivingForceArchive]
    
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
    @State private var isShowingHistoric = false
    @State private var activeEditor: DrivingForceEditor?
    @State private var editorDraftText: String = ""
    @State private var pendingDeleteRow: HistoricRow?
    @State private var editorCursorSeed: Int = 0
    @State private var editorShouldFocus: Bool = false
    @State private var didAutoOpenCreateVision: Bool = false
    @FocusState private var focusedField: Field?

    private enum DrivingForceEditor: String, Identifiable {
        case vision
        case purpose
        var id: String { rawValue }
    }

    private enum HistoricKind: String {
        case vision
        case purpose

        var label: String {
            switch self {
            case .vision: return "Vision"
            case .purpose: return "Purpose"
            }
        }
    }

    private struct HistoricRow: Identifiable {
        let archive: DrivingForceArchive
        let kind: HistoricKind
        let text: String

        var id: String { "\(archive.id.uuidString)|\(kind.rawValue)" }
    }

    private var currentDrivingForce: DrivingForce? {
        drivingForces.first
    }

    private var visionPlaceholder: String {
        "Imagine there are no limits. What do you want to be, do, have or create in your life overall? What does your ideal life look and feel like?"
    }

    private var purposePlaceholder: String {
        "What gets you up in the morning? What keeps you going? What could... if you were really excited about it? What are the reasons WHY you want your life to be this way? What will it give you? How will it make you feel?"
    }

    private var historicRows: [HistoricRow] {
        var rows: [HistoricRow] = []
        rows.reserveCapacity(drivingForceArchives.count * 2)
        for archive in drivingForceArchives {
            let vision = archive.visionSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            let purpose = archive.purposeSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !vision.isEmpty {
                rows.append(HistoricRow(archive: archive, kind: .vision, text: archive.visionSnapshot))
            }
            if !purpose.isEmpty {
                rows.append(HistoricRow(archive: archive, kind: .purpose, text: archive.purposeSnapshot))
            }
        }
        return rows
    }
    
    var body: some View {
        List {
            drivingForceInsightsHeader
                .listRowInsets(EdgeInsets(top: 0, leading: -16, bottom: 8, trailing: -16))
                .listRowBackground(Color.clear)

            AnyView(drivingForceSections)
            AnyView(passionsHeader)
            AnyView(passionsSections)
            if !historicRows.isEmpty {
                AnyView(historicToggleRow)
            }
            AnyView(historicRowsSection)
        }
        .listStyle(.insetGrouped)
        .toolbar { topToolbar }
        .navigationTitle("Driving Force")
        .background(backgroundTapDismiss)
        .sheet(item: $activeEditor, content: editorSheet)
        .task {
            if let existing = drivingForces.first {
                visionText = existing.ultimateVision
                purposeText = existing.ultimatePurpose
            }
            maybeAutoOpenCreateVision()
        }
        .onAppear {
            maybeAutoOpenCreateVision()
        }
        .sheet(isPresented: $isShowingInstructions, content: instructionsSheet)
        .alert("Delete Historic Item?", isPresented: deleteHistoricBinding, actions: deleteHistoricActions, message: deleteHistoricMessage)
    }

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
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

    private var backgroundTapDismiss: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
                hideKeyboard()
            }
    }

    private func editorSheet(_ editor: DrivingForceEditor) -> some View {
        let sheetTitle = editorSheetTitle(for: editor)
        let placeholder = editorPlaceholder(for: editor)
        return NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
#if canImport(UIKit)
                    DrivingForceEditorTextView(
                        text: $editorDraftText,
                        isFocused: $editorShouldFocus,
                        cursorSeed: editorCursorSeed
                    )
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
#else
                    TextEditor(text: $editorDraftText)
                        .frame(minHeight: 220)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
#endif
                    if editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                switch editor {
                case .vision:
                    editorDraftText = visionText
                case .purpose:
                    editorDraftText = purposeText
                }
                editorCursorSeed += 1
                editorShouldFocus = false
                DispatchQueue.main.async {
                    editorShouldFocus = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    editorShouldFocus = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeEditor = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasEditorChanges(editor) {
                        Button("Save") {
                            saveEditorChanges(editor)
                            activeEditor = nil
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            editorShouldFocus = false
        }
    }

    private func instructionsSheet() -> some View {
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

    private var deleteHistoricBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteRow != nil },
            set: { if !$0 { pendingDeleteRow = nil } }
        )
    }

    private func deleteHistoricActions() -> some View {
        Group {
            Button("Delete", role: .destructive) {
                if let row = pendingDeleteRow {
                    deleteHistoricRow(row)
                }
                pendingDeleteRow = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteRow = nil
            }
        }
    }

    private func deleteHistoricMessage() -> some View {
        Text("Are you sure you want to delete this item? It will be available for 30 days in Account Manager.")
    }

    private var drivingForceInsightsHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                passionSignalRow(icon: "heart.fill", label: "Love", value: min(4, lovePassions.count))
                passionSignalRow(icon: "lock.fill", label: "Vows", value: min(4, vowsPassions.count))
                passionSignalRow(icon: "bolt.fill", label: "Thrill", value: min(4, thrillPassions.count))
                passionSignalRow(icon: "shield.fill", label: "Hate", value: min(4, justPassions.count))
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                VStack(alignment: .leading, spacing: 3) {
                    Text("analyzed:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.gray)
                    Text("• Action Done")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("• Outcome Completion")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("• Reflection Reports")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("• Momentum")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    NavigationLink {
                        DrivingForceTrendsView()
                    } label: {
                        Text("Show trends")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, minHeight: 238, maxHeight: 238, alignment: .topLeading)
        .background(
            Color(.systemGray6)
        )
    }

    private func passionSignalCircle(icon: String, value: Int) -> some View {
        let gap: Double = 4
        let halfGap = gap / 2
        let radius: CGFloat = 22
        let center = CGPoint(x: radius, y: radius)
        let quadrantAngles: [(start: Double, end: Double)] = [
            (-90,   0),
            (0,    90),
            (90,  180),
            (180, 270)
        ]

        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                let angles = quadrantAngles[index]
                Path { path in
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: .degrees(angles.start + halfGap),
                                endAngle: .degrees(angles.end - halfGap),
                                clockwise: false)
                }
                .stroke((index + 1) <= value ? Color.primary : Color(.tertiaryLabel), lineWidth: 2.4)
            }

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func passionSignalRow(icon: String, label: String, value: Int) -> some View {
        HStack(spacing: 10) {
            passionSignalCircle(icon: icon, value: value)
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
        }
    }

    @ViewBuilder
    private var drivingForceSections: some View {
        readOnlyDrivingForceSection(
            title: "Ultimate Vision",
            text: visionText,
            editor: .vision
        )

        readOnlyDrivingForceSection(
            title: "Ultimate Purpose",
            text: purposeText,
            editor: .purpose
        )
    }

    private var passionsHeader: some View {
        Text("Passions")
            .font(.title2).bold()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }

    private var passionsSections: some View {
        Group {
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
    }

    private var historicToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingHistoric.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShowingHistoric ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                Text("Previous Ultimate Visions/Purposes")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
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
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var historicRowsSection: some View {
        if isShowingHistoric {
            if historicRows.isEmpty {
                Section {
                    Text("No historic ultimate vision/purpose snapshots yet.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } else {
                Section {
                    ForEach(historicRows) { row in
                        historicRowView(row)
                    }
                }
            }
        }
    }

    private func historicRowView(_ row: HistoricRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(shortDate(row.archive.archivedAt))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(row.text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Recover") {
                recoverArchive(row.archive, kind: row.kind)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                pendingDeleteRow = row
            }
            .tint(.red)
        }
    }

    private func readOnlyDrivingForceSection(
        title: String,
        text: String,
        editor: DrivingForceEditor
    ) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let buttonTitle: String = trimmed.isEmpty
            ? (editor == .vision ? "Create Ultimate Vision" : "Create Ultimate Purpose")
            : "Edit"
        return Section(title) {
            if !trimmed.isEmpty {
                Text(text)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
            }

            Button(buttonTitle) {
                activeEditor = editor
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .foregroundStyle(.blue)
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }

    private func editorSheetTitle(for editor: DrivingForceEditor) -> String {
        let current = currentText(for: editor).trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            return editor == .vision ? "Create Ultimate Vision" : "Create Ultimate Purpose"
        }
        return editor == .vision ? "Edit Ultimate Vision" : "Edit Ultimate Purpose"
    }

    private func editorPlaceholder(for editor: DrivingForceEditor) -> String {
        editor == .vision ? visionPlaceholder : purposePlaceholder
    }

    private func currentText(for editor: DrivingForceEditor) -> String {
        editor == .vision ? visionText : purposeText
    }

    private func maybeAutoOpenCreateVision() {
        guard autoOpenCreateVision, !didAutoOpenCreateVision else { return }
        let hasMissingVision = visionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasMissingPurpose = purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasMissingVision || hasMissingPurpose else { return }
        didAutoOpenCreateVision = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            activeEditor = .vision
        }
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
        RecentlyDeletedStore.trash(passion, in: context)
    }
    
    private func hasEditorChanges(_ editor: DrivingForceEditor) -> Bool {
        let current: String
        switch editor {
        case .vision:
            current = visionText
        case .purpose:
            current = purposeText
        }
        return editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines) != current.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveEditorChanges(_ editor: DrivingForceEditor) {
        let now = Date()
        let trimmedDraft = editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = currentDrivingForce {
            switch editor {
            case .vision:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: existing.ultimateVision,
                        purposeSnapshot: "",
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimateVision = trimmedDraft
                visionText = trimmedDraft
            case .purpose:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: "",
                        purposeSnapshot: existing.ultimatePurpose,
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimatePurpose = trimmedDraft
                purposeText = trimmedDraft
            }
            existing.updatedAt = now
        } else {
            let newVision = (editor == .vision) ? trimmedDraft : ""
            let newPurpose = (editor == .purpose) ? trimmedDraft : ""
            let created = DrivingForce(
                ultimateVision: newVision,
                ultimatePurpose: newPurpose,
                updatedAt: now
            )
            context.insert(created)
            visionText = created.ultimateVision
            purposeText = created.ultimatePurpose
        }

        try? context.save()
    }

    private func recoverArchive(_ archive: DrivingForceArchive, kind: HistoricKind) {
        let now = Date()

        if let existing = currentDrivingForce {
            switch kind {
            case .vision:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: existing.ultimateVision,
                        purposeSnapshot: "",
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimateVision = archive.visionSnapshot
                visionText = archive.visionSnapshot
            case .purpose:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: "",
                        purposeSnapshot: existing.ultimatePurpose,
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimatePurpose = archive.purposeSnapshot
                purposeText = archive.purposeSnapshot
            }
            existing.updatedAt = now
        } else {
            switch kind {
            case .vision:
                visionText = archive.visionSnapshot
            case .purpose:
                purposeText = archive.purposeSnapshot
            }
            context.insert(DrivingForce(
                ultimateVision: visionText,
                ultimatePurpose: purposeText,
                updatedAt: now
            ))
        }

        // Consumed from history after recovery.
        context.delete(archive)
        try? context.save()
    }

    private func deleteHistoricRow(_ row: HistoricRow) {
        let archive = row.archive
        let hasVision = !archive.visionSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !archive.purposeSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasVision && hasPurpose {
            // Split an old combined archive entry so one row can be deleted independently.
            let deletedOnly: DrivingForceArchive
            switch row.kind {
            case .vision:
                deletedOnly = DrivingForceArchive(
                    visionSnapshot: archive.visionSnapshot,
                    purposeSnapshot: "",
                    updatedAt: archive.updatedAt,
                    archivedAt: archive.archivedAt
                )
                archive.visionSnapshot = ""
            case .purpose:
                deletedOnly = DrivingForceArchive(
                    visionSnapshot: "",
                    purposeSnapshot: archive.purposeSnapshot,
                    updatedAt: archive.updatedAt,
                    archivedAt: archive.archivedAt
                )
                archive.purposeSnapshot = ""
            }
            context.insert(deletedOnly)
            RecentlyDeletedStore.trash(deletedOnly, in: context, source: "Driving Force Archive")
            try? context.save()
            return
        }

        RecentlyDeletedStore.trash(archive, in: context, source: "Driving Force Archive")
        try? context.save()
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter.string(from: date)
    }
}

private struct DrivingForceTrendsView: View {
    var body: some View {
        VStack(spacing: 8) {
            Text("Not Available Yet")
                .font(.headline)
                .fontWeight(.bold)
            Text("History and trends will be available over time.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.top, 24)
        .navigationTitle("Driving Force Trends")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
    }
}

extension DrivingForceView {
    init(autoOpenCreateVision: Bool = false) {
        self.autoOpenCreateVision = autoOpenCreateVision
    }
}

#if canImport(UIKit)
private struct DrivingForceEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DrivingForceEditorTextView
        var lastCursorSeed: Int = 0

        init(parent: DrivingForceEditorTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = context.coordinator
        view.textContainerInset = .zero
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            if context.coordinator.lastCursorSeed != cursorSeed {
                uiView.selectedRange = NSRange(location: (uiView.text as NSString).length, length: 0)
                context.coordinator.lastCursorSeed = cursorSeed
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}
#endif

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
        .onChange(of: focusedField) { _, newValue in
            // If focus leaves this category's inline add field, collapse back to "Add Item".
            guard addState.isAdding else { return }
            if newValue != .passion(category.emotion) {
                onAddStateChange(AddState())
            }
        }
        .onChange(of: editingPassion?.id) { _, newValue in
            // Entering edit mode should close the add row for this category.
            if addState.isAdding && newValue != nil {
                onAddStateChange(AddState())
            }
        }
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
            RecentlyDeletedStore.trash(passion, in: context)
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
