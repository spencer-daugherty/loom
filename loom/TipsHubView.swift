import SwiftUI

struct TipsHubView: View {
    private let tipFeatures = TipFeature.allCases.filter { $0.hubSection == .tips }
    private let inDevelopmentFeatures = TipFeature.allCases.filter { $0.hubSection == .inDevelopment }

    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(alignment: .leading, spacing: 22) {
                tipSection(features: tipFeatures)

                if !inDevelopmentFeatures.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("In Development")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.primary)

                        tipSection(features: inDevelopmentFeatures)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.large)
    }

    private func tipSection(features: [TipFeature]) -> some View {
        VStack(spacing: 14) {
            ForEach(features) { feature in
                NavigationLink {
                    TipDetailView(feature: feature)
                } label: {
                    TipHubCard(feature: feature)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .buttonStyle(.plain)
            }
        }
    }
}

private struct TipHubCard: View {
    let feature: TipFeature
    private let previewWidth: CGFloat = 66
    private let previewHeight: CGFloat = 143

    var body: some View {
        HStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 7) {
                    tipIcon(for: feature)

                    Text(feature.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                }

                Text(feature.summary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
                    .multilineTextAlignment(.leading)

                HStack(spacing: 6) {
                    if feature.isNew {
                        tipBadge(title: "New", tint: .blue)
                    }
                    if feature.isComingSoon {
                        tipBadge(title: "Coming soon", tint: .orange)
                    }
                }
            }

            Spacer(minLength: 0)

            TipPhonePreview(feature: feature, animate: false)
                .frame(width: previewWidth, height: previewHeight)
                .accessibilityHidden(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            Color(.secondarySystemBackground),
                            Color(.systemBackground)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(maxWidth: .infinity)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }

    @ViewBuilder
    private func tipIcon(for feature: TipFeature) -> some View {
        if feature == .appleHealthIntegration {
            Image(systemName: "heart.fill")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
        } else if feature == .loomAIPersonalization
            || feature == .loomAIChat
            || feature == .loomAIAutoWrite
            || feature == .loomAIEmailAssist
            || feature == .loomAIAgent {
            Image("LoomAI")
                .resizable()
                .scaledToFit()
                .frame(width: 16, height: 16)
        } else {
            Image(systemName: feature.symbolName)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func tipBadge(title: String, tint: Color) -> some View {
        Text(title)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                Capsule(style: .continuous)
                    .fill(tint.opacity(0.14))
            )
            .overlay(
                Capsule(style: .continuous)
                    .stroke(tint.opacity(0.28), lineWidth: 1)
            )
    }
}

#Preview {
    NavigationStack {
        TipsHubView()
    }
}
