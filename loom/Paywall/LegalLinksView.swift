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
            return "Terms of Use"
        case .privacy:
            return "Privacy Policy"
        }
    }
}

private enum LoomLegalLinks {
    static let standardEULAURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    static var hostedPrivacyPolicyURL: URL? {
        guard
            let rawValue = Bundle.main.object(forInfoDictionaryKey: "PrivacyPolicyURL") as? String,
            let url = URL(string: rawValue.trimmingCharacters(in: .whitespacesAndNewlines)),
            !rawValue.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            return nil
        }
        return url
    }
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
                "Loom uses Apple's Standard Licensed Application End User License Agreement as its Terms of Use."
            )

            legalSection(
                title: "How Terms Apply",
                items: [
                    "Your use of Loom is governed by Apple's Standard EULA.",
                    "The Standard EULA applies to subscriptions and other in-app purchases offered in Loom.",
                    "You can review the full legal text at Apple's published Standard EULA page."
                ]
            )

            Button {
                presentedURL = LoomLegalLinks.standardEULAURL
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "safari")
                    Text("Open Apple's Standard EULA")
                }
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)

            Text(LoomLegalLinks.standardEULAURL.absoluteString)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .textSelection(.enabled)
        }
    }

    private var privacyContent: some View {
        VStack(alignment: .leading, spacing: 18) {
            legalLead(
                "This in-app Privacy Policy summary describes the data categories Loom currently uses based on the shipped code path."
            )

            if let hostedPrivacyPolicyURL = LoomLegalLinks.hostedPrivacyPolicyURL {
                Button {
                    presentedURL = hostedPrivacyPolicyURL
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "link")
                        Text("Open Hosted Privacy Policy")
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
            }

            legalSection(
                title: "Account Information",
                items: [
                    "Loom supports Sign in with Apple and Google Sign-In through Firebase Authentication.",
                    "The app may store your account name, email address, authentication provider, and provider user ID in app storage to maintain your session."
                ]
            )

            legalSection(
                title: "Content You Create in Loom",
                items: [
                    "Loom stores the planning, reflection, diagnostic, personalization, goal, fulfillment, capture, and LoomAI conversation content you create in the app.",
                    "This may include free-form text that you enter about your goals, habits, reflections, relationships, purpose, and other life areas."
                ]
            )

            legalSection(
                title: "Sync and Cloud Storage",
                items: [
                    "SwiftData app content may sync through Apple's CloudKit when iCloud-backed sync is available on the device.",
                    "Personalization snapshots may also sync through Firebase Firestore when the signed-in user is backed by Firebase Authentication.",
                    "App feedback submitted from the Account page is sent to Firebase Firestore."
                ]
            )

            legalSection(
                title: "AI and Personalization",
                items: [
                    "Loom includes AI features that may process your prompts and relevant Loom context to generate suggestions, rewrites, plans, and chat responses.",
                    "When Apple Intelligence is available, some generation may run on-device using Apple-provided models.",
                    "Other AI requests may be sent to Loom's remote AI worker, which in the current code path forwards requests to OpenAI's Responses API."
                ]
            )

            legalSection(
                title: "Health, Screen Time, Camera, Photos, and Notifications",
                items: [
                    "If you choose to connect Apple Health, Loom requests read access for supported health metrics such as steps, workout minutes, and sleep data.",
                    "If you use supported Screen Time features, Loom may request Family Controls authorization and store your selected app, category, or website scope.",
                    "If you use the Little Wins camera, Loom requests camera access and may save images to your Photos library only when you choose Save.",
                    "If you enable reminders, Loom requests notification permission to send local notifications."
                ]
            )

            legalSection(
                title: "Analytics, Diagnostics, and Purchases",
                items: [
                    "Loom can log product analytics events through Firebase Analytics and crash diagnostics through Firebase Crashlytics.",
                    "Loom uses StoreKit and the App Store to process purchases, restore purchases, and determine active subscription entitlements."
                ]
            )

            legalSection(
                title: "Your Controls",
                items: [
                    "You can choose whether to connect optional permissions such as Apple Health, camera, Photos, notifications, and Screen Time.",
                    "You can manage or cancel subscriptions in your Apple Account settings.",
                    "You can sign out of your Loom account from the Account page."
                ]
            )

            Text("A final hosted Privacy Policy URL should still be added in App Store Connect and, if desired, in the app's PrivacyPolicyURL setting before submission.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func legalLead(_ text: String) -> some View {
        Text(text)
            .font(.body)
            .foregroundStyle(.primary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func legalSection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(title)
                .font(.headline)

            VStack(alignment: .leading, spacing: 8) {
                ForEach(items, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Text("•")
                        Text(item)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            .font(.body)
            .foregroundStyle(.secondary)
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
