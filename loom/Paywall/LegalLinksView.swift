import SwiftUI
#if canImport(SafariServices)
import SafariServices
#endif

enum LegalDocument: String, Identifiable {
    case terms
    case privacy

    var id: String { rawValue }

    var title: String {
        switch self {
        case .terms:
            return "Standard License Agreement"
        case .privacy:
            return "Privacy Policy"
        }
    }
}

enum LoomLegalLinks {
    static let standardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!
    static let privacyPolicyURL = URL(string: "https://spencer-daugherty.github.io/loom/")!
    static let subscriptionSupportURL = URL(string: "https://support.apple.com/billing")!
}

struct LegalLinksView: View {
    @Environment(\.dismiss) private var dismiss

    let document: LegalDocument

    @State private var presentedURL: URL?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch document {
                    case .terms:
                        termsContent
                    case .privacy:
                        privacyContent
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(20)
            }
            .navigationTitle(document.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .sheet(
            isPresented: Binding(
                get: { presentedURL != nil },
                set: { isPresented in
                    if !isPresented {
                        presentedURL = nil
                    }
                }
            )
        ) {
            if let presentedURL {
                LegalWebView(url: presentedURL)
            }
        }
    }

    private var termsContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            legalLead(
                "Loom uses Apple's Standard Licensed Application End User License Agreement as its Standard License Agreement."
            )

            LegalSection(
                title: "How Terms Apply",
                items: [
                    "Your use of Loom is governed by Apple's Standard EULA.",
                    "The Standard EULA applies to subscriptions and other in-app purchases offered in Loom.",
                    "You can review the full legal text at Apple's published Standard EULA page."
                ]
            )

            Link(destination: LoomLegalLinks.standardEULAURL) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Apple's Standard EULA")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                presentedURL = LoomLegalLinks.standardEULAURL
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text("Preview Terms in App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(LoomLegalLinks.standardEULAURL.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            legalLead(
                "Loom's Privacy Policy is hosted externally and explains what data Loom collects, how it is used, and how to contact the developer about privacy requests."
            )

            LegalSection(
                title: "What You'll Find",
                items: [
                    "What information Loom collects and stores.",
                    "How analytics, purchases, and account data are handled.",
                    "How to request support or ask privacy-related questions."
                ]
            )

            Link(destination: LoomLegalLinks.privacyPolicyURL) {
                HStack(spacing: 8) {
                    Image(systemName: "arrow.up.right.square")
                    Text("Open Privacy Policy")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Button {
                presentedURL = LoomLegalLinks.privacyPolicyURL
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text("Preview Privacy Policy in App")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.bordered)

            Text(LoomLegalLinks.privacyPolicyURL.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private func legalLead(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }
}

private struct LegalSection: View {
    let title: String
    let items: [String]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.body)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

#if canImport(SafariServices)
private struct LegalWebView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        SFSafariViewController(url: url)
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}
#else
private struct LegalWebView: View {
    let url: URL

    var body: some View {
        VStack(spacing: 16) {
            Text("Open this link in a browser:")
                .font(.headline)
            Text(url.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
        .padding(20)
    }
}
#endif

#Preview {
    LegalLinksView(document: .terms)
}
