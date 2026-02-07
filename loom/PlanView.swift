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

            // Morning Power Question
            VStack(alignment: .leading, spacing: 8) {
                Text("Morning Power Question")
                    .font(.headline)
                Text("What am I happy about in life right now?")
                    .font(.footnote)
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
                    .font(.footnote)
                    .foregroundColor(.secondary)
                TextField("Where I focus improves", text: $incantation)
                    .textFieldStyle(.roundedBorder)
                    .submitLabel(.done)
                    .focused($focusedField, equals: .incantation)
                    .onSubmit { focusedField = nil }
            }

            Spacer(minLength: 0)

            // Hidden navigation link to Step 2
            NavigationLink(destination: PlanStepTwoView(), isActive: $navigateToStep2) {
                EmptyView()
            }
            .hidden()

            VStack(spacing: 8) {
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
            }
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            DispatchQueue.main.async {
                focusedField = .morning
            }
        }
    }
}

struct PlanStepTwoView: View {
    var body: some View {
        VStack {
            Text("Step 2 coming soon")
                .font(.title2)
                .padding()
        }
        .navigationTitle("Step 2")
    }
}

#Preview {
    PlanView()
}
