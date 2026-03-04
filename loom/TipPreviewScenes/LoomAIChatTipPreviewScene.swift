import SwiftUI

struct LoomAIChatTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var showsUser: Bool { step >= 0 }
    private var showsReply: Bool { step >= 1 }
    private var showsSuggestions: Bool { step >= 2 }

    var body: some View {
        TipPreviewSurface {
            GeometryReader { proxy in
                let contentWidth = max(1, proxy.size.width)
                let userBubbleWidth = min(160, contentWidth * 0.78)
                let replyBubbleWidth = min(178, contentWidth * 0.86)
                let suggestionLineRatios: [CGFloat] = [0.78, 0.9]

                VStack(alignment: .leading, spacing: 8) {
                    TipPreviewLoomAIHeader(progress: 1.0, isAnimated: isAnimated)

                    if showsUser {
                        HStack {
                            Spacer(minLength: 0)
                            chatBubble(
                                widths: [0.76, 0.54],
                                fill: Color.blue.opacity(0.85),
                                lineColor: Color.white.opacity(0.72)
                            )
                            .frame(width: userBubbleWidth)
                        }
                    }

                    if showsReply {
                        HStack {
                            chatBubble(
                                widths: [0.80, 0.66],
                                fill: Color(.systemGray5),
                                lineColor: Color.primary.opacity(0.30)
                            )
                            .frame(width: replyBubbleWidth)
                            Spacer(minLength: 0)
                        }
                    }

                    if showsSuggestions {
                        VStack(spacing: 6) {
                            suggestionCard(lineRatio: suggestionLineRatios[0])
                            suggestionCard(lineRatio: suggestionLineRatios[1])
                        }
                        .transition(.opacity)
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }

    private func chatBubble(widths: [CGFloat], fill: Color, lineColor: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(Array(widths.enumerated()), id: \.offset) { _, ratio in
                Capsule()
                    .fill(lineColor)
                    .frame(width: max(42, ratio * 180), height: 6)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        )
    }

    private func suggestionCard(lineRatio: CGFloat) -> some View {
        HStack(spacing: 6) {
            Circle()
                .fill(Color.white.opacity(0.92))
                .frame(width: 6, height: 6)
            Capsule()
                .fill(Color.white.opacity(0.75))
                .frame(maxWidth: .infinity, minHeight: 7, maxHeight: 7, alignment: .leading)
                .scaleEffect(x: max(0.35, min(1, lineRatio)), y: 1, anchor: .leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 9)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: TipPreviewPalette.loomAI,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay {
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color.white.opacity(0.28), lineWidth: 1)
        }
    }
}
