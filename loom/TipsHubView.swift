import SwiftUI

struct TipsHubView: View {
    var body: some View {
        ScrollView(showsIndicators: false) {
            LazyVStack(spacing: 14) {
                ForEach(TipFeature.allCases) { feature in
                    NavigationLink {
                        TipDetailView(feature: feature)
                    } label: {
                        TipHubCard(feature: feature)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 18)
        }
        .background(Color(.systemGroupedBackground).ignoresSafeArea())
        .navigationTitle("Tips")
        .navigationBarTitleDisplayMode(.large)
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
                    Image(systemName: feature.symbolName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    Text(feature.title)
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
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

            TipPhonePreview(feature: feature, animate: false)
                .frame(width: previewWidth, height: previewHeight)
                .accessibilityHidden(true)
        }
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
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.black.opacity(0.07), lineWidth: 1)
        )
        .contentShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
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
