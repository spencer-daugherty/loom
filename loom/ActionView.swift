import SwiftUI
import SwiftData

struct ActionView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 16) {
            Text("ActionView")
                .font(.largeTitle)
                .bold()

            Text("Placeholder — coming soon")
                .foregroundColor(.secondary)

            Spacer(minLength: 0)

            Button {
                let state = ActivePlanState.fetchOrCreate(in: modelContext)
                state.isActive = false
                state.activatedAt = nil
                state.weekStart = nil
                try? modelContext.save()

                dismiss()
            } label: {
                Text("End Plan")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(.red)
        }
        .padding(.horizontal)
        .safeAreaPadding(.top)
        .safeAreaPadding(.bottom)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack { ActionView() }
}
