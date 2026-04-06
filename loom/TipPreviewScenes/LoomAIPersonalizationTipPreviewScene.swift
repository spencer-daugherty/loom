import SwiftUI

struct LoomAIPersonalizationTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    private let areaChips: [(String, Color)] = [
        ("Health & Energy", FulfillmentCategoryTheme.color(for: "Health & Energy")),
        ("Career & Business", FulfillmentCategoryTheme.color(for: "Career & Business")),
        ("Family & Friends", FulfillmentCategoryTheme.color(for: "Family & Friends"))
    ]

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                TipPreviewLoomAIHeader(progress: normalizedStep == 0 ? 0.22 : 1.0, isAnimated: isAnimated)

                switch normalizedStep {
                case 0:
                    diagnosticQuestionStep
                case 1:
                    lifeAreasStep
                case 2:
                    loadingInsightsStep
                default:
                    insightsStep
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.32) : nil, value: normalizedStep)
        }
    }

    private var diagnosticQuestionStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Quick Diagnostic")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            personalizationChoiceCard(
                title: "What’s causing the most stress right now?",
                choice: "Too many priorities competing",
                emphasized: true
            )

            personalizationChoiceCard(
                title: "When you try to make progress, what usually breaks first?",
                choice: "I start, then lose momentum",
                emphasized: false
            )
        }
    }

    private var lifeAreasStep: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose 3-7 life areas")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.primary)

            ForEach(areaChips, id: \.0) { item in
                HStack(spacing: 10) {
                    Text(item.0)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Spacer(minLength: 0)
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(item.1)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 11)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(item.1.opacity(0.56), lineWidth: 1.8)
                )
            }

            TipPreviewPrimaryPill(title: "Continue", tint: .blue)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        }
    }

    private var loadingInsightsStep: some View {
        VStack(spacing: 8) {
            insightLoadingCard(title: "Root Cause")
            insightLoadingCard(title: "Fulfillment Areas")
            insightLoadingCard(title: "Next Direction")
        }
    }

    private var insightsStep: some View {
        VStack(spacing: 8) {
            insightCard(
                title: "Root Cause",
                body: "You know what matters, but competing priorities and inconsistent execution keep your days reactive."
            )

            TipPreviewPanel(fill: Color(.secondarySystemBackground)) {
                TipPreviewSectionLabel(text: "Fulfillment Areas")

                FlexibleAreaChipWrap(items: areaChips)
            }

            insightCard(
                title: "Next Direction",
                body: "Reduce competing commitments, then build one daily support system inside Health & Energy and Career & Business.",
                emphasized: true
            )
        }
    }

    private func personalizationChoiceCard(
        title: String,
        choice: String,
        emphasized: Bool
    ) -> some View {
        TipPreviewPanel(
            fill: Color(.secondarySystemBackground),
            stroke: emphasized ? TipPreviewPalette.loomAI[0].opacity(0.46) : Color.black.opacity(0.08)
        ) {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 8) {
                Text(choice)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 0)
                Image(systemName: "checkmark.circle.fill")
                    .font(.title3)
                    .foregroundStyle(emphasized ? TipPreviewPalette.loomAI[0] : .blue)
            }
        }
        .overlay {
            if emphasized && isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 14)
                    .opacity(0.75)
            }
        }
    }

    private func insightLoadingCard(title: String) -> some View {
        TipPreviewPanel(fill: Color(.secondarySystemBackground)) {
            TipPreviewSectionLabel(text: title)

            VStack(alignment: .leading, spacing: 6) {
                Capsule()
                    .fill(Color.primary.opacity(0.18))
                    .frame(width: 148, height: 8)
                Capsule()
                    .fill(Color.primary.opacity(0.14))
                    .frame(width: 186, height: 7)
                Capsule()
                    .fill(Color.primary.opacity(0.12))
                    .frame(width: 132, height: 7)
            }
            .redacted(reason: .placeholder)

            TipPreviewProgressBar(progress: 0.66)
        }
    }

    private func insightCard(
        title: String,
        body: String,
        emphasized: Bool = false
    ) -> some View {
        TipPreviewPanel(
            fill: emphasized ? Color.blue.opacity(0.13) : Color(.secondarySystemBackground),
            stroke: emphasized ? TipPreviewPalette.loomAI[0].opacity(0.30) : Color.black.opacity(0.08)
        ) {
            TipPreviewSectionLabel(text: title)

            Text(body)
                .font(emphasized ? .body.weight(.medium) : .body)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .overlay {
            if emphasized && isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 14)
                    .opacity(0.9)
            }
        }
    }
}

private struct FlexibleAreaChipWrap: View {
    let items: [(String, Color)]

    var body: some View {
        VStack(spacing: 6) {
            HStack(spacing: 6) {
                areaChip(items[0])
                areaChip(items[1])
            }
            HStack(spacing: 6) {
                areaChip(items[2])
                Spacer(minLength: 0)
            }
        }
    }

    private func areaChip(_ item: (String, Color)) -> some View {
        Text(item.0)
            .font(.caption.weight(.semibold))
            .foregroundStyle(item.1)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(item.1.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(item.1.opacity(0.28), lineWidth: 1)
            )
    }
}
