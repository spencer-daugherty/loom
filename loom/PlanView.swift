import SwiftUI

/// Step 1 of a multi-step flow.
/// UI-only: Three one-line text fields with a bottom-pinned "Next" button.
struct PlanView: View {
    @State private var morningPowerQuestion: String = ""
    @State private var gratefulFor: String = ""
    @State private var incantation: String = ""

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

            Button(action: {}) {
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

#Preview {
    PlanView()
}
