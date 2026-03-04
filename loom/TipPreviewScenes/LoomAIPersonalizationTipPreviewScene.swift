import SwiftUI

struct LoomAIPersonalizationTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var showsInsights: Bool { step >= 2 }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 8) {
                TipPreviewLoomAIHeader(progress: step == 0 ? 0.34 : 1.0, isAnimated: isAnimated)

                if showsInsights {
                    VStack(spacing: 7) {
                        insightsCard(title: "ROOT CAUSE", lineWidths: [0.94, 0.62], emphasized: false)
                        insightsCard(title: "FULFILLMENT AREAS", lineWidths: [0.86, 0.72], emphasized: false)
                        insightsCard(title: "NEXT DIRECTION", lineWidths: [0.88, 0.68], emphasized: true)
                    }
                    .scaleEffect(step == 3 ? 1.01 : 0.995)
                } else {
                    VStack(spacing: 7) {
                        TipPreviewCard(
                            title: "DIAGNOSTIC A",
                            tint: Color(.systemGray5),
                            lineWidths: [0.82]
                        )

                        TipPreviewCard(
                            title: "DIAGNOSTIC B",
                            tint: Color(.systemGray5),
                            lineWidths: [0.90]
                        )
                    }
                }
            }
        }
    }

    private func insightsCard(title: String, lineWidths: [CGFloat], emphasized: Bool) -> some View {
        TipPreviewCard(
            title: title,
            tint: emphasized ? Color.blue.opacity(0.15) : Color(.systemGray5),
            outline: emphasized ? TipPreviewPalette.loomAI[0].opacity(0.22) : Color.black.opacity(0.08),
            lineWidths: lineWidths
        )
        .overlay {
            if isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 12)
                    .opacity(emphasized ? 0.9 : 0.45)
            }
        }
    }
}
