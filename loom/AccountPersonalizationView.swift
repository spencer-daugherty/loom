import SwiftUI

struct AccountPersonalizationView: View {
    private enum EditorMode: String, Identifiable {
        case edit
        case reset
        var id: String { rawValue }
    }

    @EnvironmentObject private var personalizationStore: PersonalizationStore
    @State private var editorMode: EditorMode?
    @State private var selectedHistorySnapshot: PersonalizationSnapshot?
    @State private var isSaving = false

    var body: some View {
        List {
            Section("Insights") {
                if let current = personalizationStore.current {
                    VStack(spacing: 12) {
                        PersonalizationInsightsCards(snapshot: current)

                        Button("Edit diagnostic answers") {
                            editorMode = .edit
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Finish your diagnostic")
                            .font(.headline)

                        Text("Answer 6 quick questions. Loom will personalize your insights and AutoWrite.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Start diagnostic") {
                            editorMode = .reset
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let current = personalizationStore.current {
                Section("Current") {
                    snapshotRows(current)
                }
            }

            Section("History") {
                if personalizationStore.history.isEmpty {
                    Text("Old diagnostics will appear here when you update.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(personalizationStore.history.prefix(10).enumerated()), id: \.element.id) { index, snapshot in
                        Button {
                            selectedHistorySnapshot = snapshot
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Text(summaryForHistoryItem(snapshot, at: index))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSaving {
                ProgressView("Saving…")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .task {
            await personalizationStore.reloadForCurrentUser()
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                DiagnosticFlowView(
                    mode: .accountEdit,
                    initialDraft: mode == .edit ? personalizationStore.current.map(PersonalizationDraft.init(snapshot:)) : nil
                ) { draft, _ in
                    await saveDiagnosticDraft(draft, mode: mode)
                }
                .navigationTitle("Quick Diagnostic")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editorMode = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedHistorySnapshot) { snapshot in
            NavigationStack {
                List {
                    snapshotRows(snapshot)
                }
                .navigationTitle("Snapshot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedHistorySnapshot = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func snapshotRows(_ snapshot: PersonalizationSnapshot) -> some View {
        row("Most stress", value: snapshot.stressSource)
        row("Break point", value: snapshot.breakPoint)
        row("Life areas", value: snapshot.lifeAreasSelected.joined(separator: ", "))
        row("Most days", value: snapshot.planningReality)
        row("First change", value: snapshot.desiredChange)
        row(
            "Saved",
            value: snapshot.createdAt.formatted(
                .dateTime.month(.abbreviated).day().year().hour().minute()
            )
        )
    }

    @ViewBuilder
    private func row(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func summaryForHistoryItem(_ snapshot: PersonalizationSnapshot, at index: Int) -> String {
        let newer: PersonalizationSnapshot? = {
            if index == 0 {
                return personalizationStore.current
            }
            return personalizationStore.history[index - 1]
        }()
        guard let newer else { return "Snapshot archived." }
        return PersonalizationHistoryDiff.summary(from: snapshot, to: newer)
    }

    private func saveDiagnosticDraft(_ draft: PersonalizationDraft, mode: EditorMode) async {
        isSaving = true
        defer {
            isSaving = false
            editorMode = nil
        }

        do {
            let source: PersonalizationSaveSource = mode == .reset ? .accountReset : .accountEdit
            _ = try await personalizationStore.saveSnapshot(from: draft, source: source)
        } catch {
            // Keep previous values if save fails.
        }
    }
}

#Preview {
    NavigationStack {
        AccountPersonalizationView()
            .environmentObject(PersonalizationStore())
    }
}
