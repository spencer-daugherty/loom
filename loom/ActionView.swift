import SwiftUI

struct ActionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("ActionView")
                .font(.largeTitle)
                .bold()
            Text("Placeholder — coming soon")
                .foregroundColor(.secondary)
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
