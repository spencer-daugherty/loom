import SwiftUI
import SwiftData

/// Step 1 of a multi-step flow.
/// UI-only: Three one-line text fields with a bottom-pinned "Next" + "Close" button.
struct PlanView: View {
    @State private var morningPowerQuestion: String = ""
    @State private var gratefulFor: String = ""
    @State private var incantation: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    @State private var navigateToStep2: Bool = false
    @FocusState private var focusedField: Field?
    private enum Field: Hashable { case morning, grateful, incantation }

    private var isNextDisabled: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            
            // Top Title
            Text("Weekly Planning")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Morning Power Question
            VStack(alignment: .leading, spacing: 8) {
                Text("Morning Power Question")
                    .font(.headline)
                Text("What am I happy about in life right now?")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
                TextField("My dreams, aspirations, and goals", text: $morningPowerQuestion)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .morning)
                    .onSubmit { focusedField = .grateful }
            }
            .padding(.top, 16)

            // Grateful For
            VStack(alignment: .leading, spacing: 8) {
                Text("What am I grateful for?")
                    .font(.headline)
                TextField("Health", text: $gratefulFor)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.next)
                    .focused($focusedField, equals: .grateful)
                    .onSubmit { focusedField = .incantation }
            }

            // Incantation
            VStack(alignment: .leading, spacing: 8) {
                Text("Incantation")
                    .font(.headline)
                Text("What’s a simple phrase to set your mindset?")
                    .font(.subheadline)
                    .italic()
                    .foregroundColor(.secondary)
                TextField("Where I focus improves", text: $incantation)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .incantation)
                    .onSubmit {
                        if isNextDisabled { return }
                        let now = Date()
                        let entry = WeeklyMindsetEntry.Fields(
                            createdAt: now,
                            morningPowerQuestion: morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
                            gratitude: gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines),
                            incantation: incantation.trimmingCharacters(in: .whitespacesAndNewlines)
                        )
                        modelContext.insert(entry)
                        try? modelContext.save()
                        navigateToStep2 = true
                    }
            }

            Spacer(minLength: 0)

            // Bottom buttons side-by-side (like Step 2)
            HStack(spacing: 12) {
                // CLOSE BUTTON
                Button {
                    dismiss()
                } label: {
                    Text("Close")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                // NEXT BUTTON
                Button {
                    let now = Date()
                    let entry = WeeklyMindsetEntry.Fields(
                        createdAt: now,
                        morningPowerQuestion: morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines),
                        gratitude: gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines),
                        incantation: incantation.trimmingCharacters(in: .whitespacesAndNewlines)
                    )
                    modelContext.insert(entry)
                    try? modelContext.save()
                    navigateToStep2 = true
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .disabled(isNextDisabled)
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .fullScreenCover(isPresented: $navigateToStep2) {
            PlanStepTwoView()
        }
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .morning
            }
        }
    }
}

struct PlanStepTwoView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse)
    private var allItems: [RollingCaptureItem]

    @State private var input: String = ""
    @State private var showHidden: Bool = false
    @FocusState private var isInputFocused: Bool

    /// Baseline set captured on appear; used to apply `plus.viewfinder` only to “existing before session” items.
    @State private var baselineItemIDs: Set<UUID> = []

    private var displayItems: [RollingCaptureItem] {
        // Same conceptual behavior as CaptureView:
        // - When showHidden off: show only non-ghost
        // - When showHidden on: show both; ghosts grouped first; newest first within group
        let base = showHidden ? allItems : allItems.filter { !$0.isGhost }
        return base.sorted {
            if $0.isGhost != $1.isGhost { return $0.isGhost && !$1.isGhost }
            return $0.createdAt > $1.createdAt
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Title
            Text("Capture")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
                .padding(.top, 8)

            // Brainstorm info row
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle")
                    .foregroundStyle(.secondary)
                    .padding(.top, 1)

                (
                    Text("Brainstorm: ")
                        .fontWeight(.bold)
                    + Text("What needs to get done? What are any outcomes, actions or communications that need to happen? Are there any projects you’re working on that need your focus?")
                )
                .foregroundStyle(.secondary)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)

            // Toggle row (inline, above list)
            HStack(spacing: 10) {
                Toggle(isOn: $showHidden) {
                    EmptyView()
                }
                .labelsHidden()

                Image(systemName: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(showHidden ? .blue : .secondary)
                    .accessibilityHidden(true)

                Text("Show Actions Hidden Until Later")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Spacer(minLength: 0)
            }
            .padding(.horizontal)

            // List
            List {
                ForEach(displayItems) { item in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        // Icon rules:
                        // - Existing before session: plus.viewfinder
                        // - If ghost + showHidden ON: clock icon
                        // - For items created in-session: no icon (and no clock, because Step 2 cannot create ghosts)
                        if baselineItemIDs.contains(item.id) {
                            Image(systemName: "plus.viewfinder")
                                .foregroundStyle(.secondary)
                        } else if showHidden, item.isGhost {
                            Image(systemName: "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted")
                                .foregroundStyle(.blue)
                        }

                        Text(item.text)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    .overlay {
                        // Optional: match CaptureView’s ghost styling when ghosts are shown
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

            // Bottom input (sticky keyboard)
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
            }
            .padding(.horizontal, 24)
            .padding(.top, 4)

            // Bottom Back/Next buttons (keep as-is stylistically)
            HStack(spacing: 12) {
                // Back button styled like Close on previous screen
                Button {
                    // Return to Step 1 (PlanView) by dismissing the modal sheet
                    dismiss()
                } label: {
                    Text("Back")
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundColor(.black)
                }
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )

                // Next button styled like Next on previous screen
                Button {
                    // Continue forward from Step 2 (placeholder action)
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(.horizontal)
            .padding(.bottom)
        }
        .safeAreaPadding()
        .onAppear {
            // Capture baseline IDs once per presentation.
            if baselineItemIDs.isEmpty {
                baselineItemIDs = Set(allItems.map(\.id))
            }

            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                isInputFocused = true
            }
        }
        .onChange(of: isInputFocused) { _, newValue in
            if newValue == false {
                DispatchQueue.main.async {
                    isInputFocused = true
                }
            }
        }
    }

    private func addItem() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        let newItem = RollingCaptureItem(
            text: trimmed,
            isGhost: false,
            createdAt: .now,
            unhideDate: nil,
            unhiddenAt: nil
        )
        modelContext.insert(newItem)
        try? modelContext.save()

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
}

#Preview {
    PlanView()
}
