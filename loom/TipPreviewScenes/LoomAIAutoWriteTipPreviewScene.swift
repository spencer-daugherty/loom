import SwiftUI

struct LoomAIAutoWriteTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    private var currentDraft: String {
        normalizedStep == 3 ? "Prep tomorrow's workout clothes tonight" : "yoga classes"
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                Text("New Little Win")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .center)

                TipPreviewPanel(fill: Color(.systemBackground)) {
                    TipPreviewSectionLabel(text: "New Little Win")

                    Text(currentDraft)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(normalizedStep == 3 ? .primary : .secondary)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 11)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .fill(Color(.secondarySystemBackground))
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .stroke(Color.black.opacity(0.08), lineWidth: 1)
                        )

                    if normalizedStep >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            autoWriteSuggestion(
                                intro: normalizedStep == 3 ? "Added Little Win in Health & Energy:" : "Add Little Win in Health & Energy:",
                                suggestion: "Prep tomorrow's workout clothes tonight",
                                applied: normalizedStep == 3,
                                tint: TipPreviewPalette.loomAI[0]
                            )

                            autoWriteSuggestion(
                                intro: "Add Little Win in Health & Energy:",
                                suggestion: "Walk 20 minutes after lunch",
                                applied: false,
                                tint: TipPreviewPalette.loomAI[2]
                            )
                        }
                    }

                    setupRow(title: "Can be completed any day", value: "No")
                    weekdaysRow
                }

                if normalizedStep <= 1 {
                    HStack {
                        Spacer(minLength: 0)
                        autoWriteButton
                    }
                    .padding(.trailing, 6)
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.34) : nil, value: normalizedStep)
        }
    }

    private var autoWriteButton: some View {
        HStack(spacing: 6) {
            Image("LoomAI")
                .resizable()
                .scaledToFit()
                .frame(width: 17, height: 17)
                .rotation3DEffect(
                    .degrees(normalizedStep == 1 && isAnimated ? 180 : 0),
                    axis: (x: 1, y: 0, z: 0)
                )
            Text(normalizedStep == 1 ? "AutoWriting" : "AutoWrite")
                .font(.caption.weight(.semibold))
        }
        .foregroundStyle(
            LinearGradient(
                colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[2], TipPreviewPalette.loomAI[3]],
                startPoint: .leading,
                endPoint: .trailing
            )
        )
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(
            Capsule(style: .continuous)
                .fill(Color(.systemGroupedBackground))
        )
        .overlay(
            Capsule(style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[2], TipPreviewPalette.loomAI[3]],
                        startPoint: .leading,
                        endPoint: .trailing
                    ),
                    lineWidth: 2
                )
        )
        .overlay {
            if normalizedStep == 1 && isAnimated {
                TipPreviewAnimatedOutline(cornerRadius: 999)
                    .opacity(0.75)
            }
        }
    }

    private func autoWriteSuggestion(
        intro: String,
        suggestion: String,
        applied: Bool,
        tint: Color
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image("LoomAI")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(width: 16, height: 16)
                .foregroundStyle(applied ? Color.white.opacity(0.92) : tint.opacity(0.95))
                .padding(.top, 1)

            VStack(alignment: .leading, spacing: 3) {
                Text(intro)
                    .font(.caption.italic())
                    .foregroundStyle(applied ? Color.white.opacity(0.86) : tint.opacity(0.90))
                    .fixedSize(horizontal: false, vertical: true)

                Text(suggestion)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(applied ? .white : tint)
                    .fixedSize(horizontal: false, vertical: true)

                if applied {
                    Text("Tap field to edit")
                        .font(.caption2)
                        .foregroundStyle(Color.white.opacity(0.78))
                }
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(applied ? tint : tint.opacity(0.12))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(applied ? tint.opacity(0.16) : tint.opacity(0.26), lineWidth: 1)
        )
    }

    private func setupRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.blue)
        }
    }

    private var weekdaysRow: some View {
        HStack(spacing: 0) {
            ForEach(Array(["M", "T", "W", "T", "F", "S", "S"].enumerated()), id: \.offset) { index, label in
                let isSelected = index < 5
                Text(label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(isSelected ? .white : .primary)
                    .frame(width: 28, height: 28)
                    .background(
                        Circle()
                            .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color(.separator).opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                    )
                    .frame(maxWidth: .infinity)
            }
        }
        .padding(.top, 2)
    }
}
