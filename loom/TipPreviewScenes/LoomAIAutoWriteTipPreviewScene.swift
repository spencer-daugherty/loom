import SwiftUI

struct LoomAIAutoWriteTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var isThinking: Bool { step == 1 }
    private var showsSuggestions: Bool { step >= 2 }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    autoWriteButton
                    if isThinking {
                        Text("Thinking")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                    Spacer(minLength: 0)
                }

                TipPreviewCard(
                    title: "Draft",
                    tint: Color(.systemBackground),
                    outline: Color.black.opacity(0.08),
                    lineWidths: [0.92, 0.82, 0.58]
                )
                .overlay {
                    if isThinking && isAnimated {
                        TipPreviewAnimatedOutline(cornerRadius: 12)
                            .opacity(0.85)
                    }
                }

                if showsSuggestions {
                    VStack(spacing: 6) {
                        TipPreviewCard(
                            tint: Color.blue.opacity(0.14),
                            outline: Color.blue.opacity(0.28),
                            lineWidths: [0.86]
                        )
                        TipPreviewCard(
                            tint: Color.purple.opacity(0.13),
                            outline: Color.purple.opacity(0.28),
                            lineWidths: [0.78]
                        )
                    }
                    .transition(.opacity)
                }

                Spacer(minLength: 0)
            }
        }
    }

    private var autoWriteButton: some View {
        HStack(spacing: 6) {
            Image(systemName: "wand.and.stars")
                .font(.caption.weight(.semibold))
            Text("AutoWrite")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(.white)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .background(
            Capsule(style: .continuous)
                .fill(
                    LinearGradient(
                        colors: TipPreviewPalette.loomAI,
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
    }
}
