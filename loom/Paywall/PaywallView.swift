import SwiftUI

struct PaywallView: View {
    @EnvironmentObject private var session: UserSessionStore

    @StateObject private var purchaseManager = PurchaseManager()
    @State private var selectedPlan: SubscriptionPlan = .annual
    @State private var presentedLegalDocument: LegalDocument?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Unlock Loom Pro")
                        .font(.largeTitle.weight(.bold))
                    Text("One direction for your life—identity, fulfillment, and execution in one system.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 10) {
                    paywallBullet("Weekly Reset to stay clear and calm")
                    paywallBullet("Fulfillment radar to protect balance")
                    paywallBullet("Personalized guidance tied to your categories")
                }

                VStack(spacing: 10) {
                    planCard(for: .annual)
                        .accessibilityIdentifier("paywall_plan_annual")
                    planCard(for: .monthly)
                        .accessibilityIdentifier("paywall_plan_monthly")
                }
                .padding(.top, 6)

                Button {
                    Task { await purchaseManager.purchase(plan: selectedPlan, session: session) }
                } label: {
                    if purchaseManager.isProcessing {
                        ProgressView()
                            .frame(maxWidth: .infinity)
                    } else {
                        Text(selectedPlan.ctaText)
                            .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(purchaseManager.isProcessing)
                .accessibilityIdentifier("paywall_primaryCTA")

                Text("Annual includes a 7-day free trial. Payment is charged to your Apple ID after confirmation (or after the trial ends). Subscription renews automatically unless canceled at least 24 hours before renewal. Manage or cancel anytime in Apple ID Settings.")
                    .font(.footnote)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await purchaseManager.restorePurchases(session: session) }
                } label: {
                    Text("Restore Purchases")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(purchaseManager.isProcessing)
                .accessibilityIdentifier("paywall_restore")

                HStack(spacing: 16) {
                    Button("Terms of Use") { presentedLegalDocument = .terms }
                    Button("Privacy Policy") { presentedLegalDocument = .privacy }
                }
                .font(.footnote.weight(.semibold))
                .padding(.top, 4)
            }
            .padding(20)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .sheet(item: $presentedLegalDocument) { document in
            LegalLinksView(document: document)
        }
    }

    private func paywallBullet(_ text: LocalizedStringKey) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(Color.accentColor)
                .padding(.top, 1)
            Text(text)
                .font(.body)
        }
    }

    private func planCard(for plan: SubscriptionPlan) -> some View {
        let selected = selectedPlan == plan

        return Button {
            selectedPlan = plan
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 3) {
                    Text(plan.title)
                        .font(.headline)
                        .foregroundStyle(.primary)
                    Text(plan.priceText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let trialText = plan.trialText {
                        Text(trialText)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: selected ? "largecircle.fill.circle" : "circle")
                    .foregroundStyle(selected ? Color.accentColor : Color.secondary)
                    .font(.title3)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(selected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    PaywallView()
        .environmentObject(UserSessionStore())
}
