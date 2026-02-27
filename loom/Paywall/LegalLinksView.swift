import SwiftUI

enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: LocalizedStringKey {
        switch self {
        case .terms:
            return "Terms of Use"
        case .privacy:
            return "Privacy Policy"
        }
    }

    var bodyText: LocalizedStringKey {
        switch self {
        case .terms:
            return "Terms placeholder. Replace with your production Terms of Use content."
        case .privacy:
            return "Privacy placeholder. Replace with your production Privacy Policy content."
        }
    }
}

struct LegalLinksView: View {
    let document: LegalDocument

    var body: some View {
        NavigationStack {
            ScrollView {
                Text(document.bodyText)
                    .font(.body)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}

#Preview {
    LegalLinksView(document: .terms)
}
