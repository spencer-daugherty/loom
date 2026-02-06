import SwiftUI

struct ActionView: View {
    var body: some View {
        VStack(spacing: 16) {
            Text("ActionView loaded").font(.caption).foregroundColor(.secondary)
            Text("ActionView")
                .font(.largeTitle)
                .bold()
            Text("Placeholder — coming soon")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(.systemBackground))
    }
}

#Preview {
    NavigationStack { ActionView() }
}
