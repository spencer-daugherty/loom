import SwiftUI

struct LoomAIChatTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                TipPreviewLoomAIHeader(progress: 1.0, isAnimated: isAnimated)

                chatComposer

                if normalizedStep >= 1 {
                    HStack {
                        Spacer(minLength: 0)
                        userBubble
                    }
                }

                if normalizedStep == 2 {
                    typingBubble
                }

                if normalizedStep >= 3 {
                    assistantReply
                    suggestionCards
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.34) : nil, value: normalizedStep)
        }
    }

    private var chatComposer: some View {
        HStack(alignment: .bottom, spacing: 8) {
            Text("What daily Little Wins would improve Health & Energy?")
                .font(.caption)
                .foregroundStyle(normalizedStep == 0 ? .secondary : .primary)
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )

            ZStack {
                Circle()
                    .fill(Color.blue)
                Image(systemName: "arrow.up")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white)
            }
            .frame(width: 34, height: 34)
        }
    }

    private var userBubble: some View {
        bubble(
            title: nil,
            body: "What daily Little Wins would improve Health & Energy?",
            fill: Color.blue.opacity(0.90),
            foreground: .white
        )
        .frame(width: 168)
    }

    private var typingBubble: some View {
        HStack {
            bubble(title: "LoomAI", body: "Thinking through your current setup...", fill: Color(.systemGray6), foreground: .primary)
                .frame(width: 188)
            Spacer(minLength: 0)
        }
        .overlay(alignment: .bottomLeading) {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { _ in
                    Circle()
                        .fill(Color.secondary.opacity(0.55))
                        .frame(width: 5, height: 5)
                }
            }
            .padding(.leading, 18)
            .padding(.bottom, 10)
        }
    }

    private var assistantReply: some View {
        HStack {
            bubble(
                title: "LoomAI",
                body: "Based on your current setup, keep the next step measurable and easy to finish.",
                fill: Color(.systemGray6),
                foreground: .primary
            )
            .frame(width: 190)
            Spacer(minLength: 0)
        }
    }

    private var suggestionCards: some View {
        VStack(spacing: 7) {
            suggestionCard(
                heading: "Health & Energy",
                title: "Add Little Win in Health & Energy:",
                detail: "Walk 20 minutes after lunch"
            )

            suggestionCard(
                heading: "Health & Energy",
                title: "Add Little Win in Health & Energy:",
                detail: "Prep tomorrow's workout clothes tonight"
            )
        }
    }

    private func bubble(
        title: String?,
        body: String,
        fill: Color,
        foreground: Color
    ) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            if let title {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(foreground.opacity(0.72))
            }

            Text(body)
                .font(.caption.weight(.medium))
                .foregroundStyle(foreground)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(fill)
        )
    }

    private func suggestionCard(
        heading: String,
        title: String,
        detail: String
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image("LoomAI")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(.white.opacity(0.94))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(heading)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.78))
                Text(title)
                    .font(.caption.italic())
                    .foregroundStyle(.white.opacity(0.92))
                Text(detail)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[2], TipPreviewPalette.loomAI[3]],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }
}
