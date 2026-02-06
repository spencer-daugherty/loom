import SwiftUI
import SwiftData

/// Step 1 of a multi-step flow.
/// UI-only: Three one-line text fields with a bottom-pinned "Next" button.
struct PlanView: View {
    @State private var morningPowerQuestion: String = ""
    @State private var gratefulFor: String = ""
    @State private var incantation: String = ""
    
    @Environment(\.modelContext) private var modelContext
    @State private var navigateToStep2: Bool = false

    private var isNextDisabled: Bool {
        morningPowerQuestion.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        gratefulFor.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
        incantation.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 24) {
            Text("PlanView loaded").font(.caption).foregroundColor(.secondary)
            // Morning Power Question
            VStack(alignment: .leading, spacing: 8) {
                Text("Morning Power Question")
                    .font(.headline)
                Text("What am I happy about in life right now?")
                    .font(.footnote)
                    .foregroundColor(.secondary)
                TextField("My dreams, aspirations, and goals", text: $morningPowerQuestion)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }

            // Grateful For
            VStack(alignment: .leading, spacing: 8) {
                Text("What am I grateful for?")
                    .font(.headline)
                TextField("Health", text: $gratefulFor)
                    .textFieldStyle(.roundedBorder)
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
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
                    .textInputAutocapitalization(.sentences)
                    .disableAutocorrection(false)
            }

            Spacer(minLength: 0)

            // Hidden navigation link to push Step 2 after saving
            NavigationLink(destination: PlanStepTwoView(), isActive: $navigateToStep2) {
                EmptyView()
            }
            .hidden()

            Button(action: {
                // Compute weekStart for current date via helper (derived from createdAt)
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
            }) {
                Text("Next")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .disabled(isNextDisabled)
        }
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
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
