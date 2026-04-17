import SwiftUI

struct WidgetsTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var normalizedStep: Int {
        step % 4
    }

    var body: some View {
        TipPreviewSurface {
            VStack(alignment: .leading, spacing: 10) {
                header

                HStack(alignment: .top, spacing: 10) {
                    smallWidget(
                        title: "Top Focus",
                        systemImage: "scope",
                        tint: TipPreviewPalette.loomAI[0],
                        primary: normalizedStep >= 2 ? "Launch plan" : "Draft launch plan",
                        secondary: normalizedStep >= 2 ? "Today, 1 task left" : "Today, 3 tasks left"
                    )

                    smallWidget(
                        title: "Quick Capture",
                        systemImage: "plus.circle.fill",
                        tint: TipPreviewPalette.loomAI[1],
                        primary: "Add action",
                        secondary: normalizedStep >= 1 ? "Voice, photo, link" : "One tap from Home Screen"
                    )
                }

                wideWidget

                if normalizedStep >= 1 {
                    TipPreviewPanel(
                        fill: Color.white.opacity(0.94),
                        stroke: TipPreviewPalette.loomAI[normalizedStep == 3 ? 2 : 0].opacity(0.18)
                    ) {
                        HStack(alignment: .center, spacing: 8) {
                            Image(systemName: normalizedStep == 3 ? "sparkles" : "iphone")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TipPreviewPalette.loomAI[normalizedStep == 3 ? 2 : 0])

                            Text(statusText)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .lineLimit(2)

                            Spacer(minLength: 0)
                        }
                    }
                    .overlay {
                        if isAnimated {
                            TipPreviewAnimatedOutline(cornerRadius: 14)
                                .opacity(normalizedStep == 3 ? 0.78 : 0.42)
                        }
                    }
                }

                Spacer(minLength: 0)
            }
            .animation(isAnimated ? .easeInOut(duration: 0.35) : nil, value: normalizedStep)
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [TipPreviewPalette.loomAI[0], TipPreviewPalette.loomAI[2]],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 34, height: 34)

                    Image(systemName: "square.grid.2x2.fill")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.94))
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text("Widgets")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text("Coming soon")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                TipPreviewChip(text: "Home Screen", tint: TipPreviewPalette.loomAI[0])
                TipPreviewChip(text: "Quick Capture", tint: TipPreviewPalette.loomAI[1])
            }
        }
    }

    private var wideWidget: some View {
        TipPreviewPanel(fill: Color(.systemGray6), stroke: Color.black.opacity(0.08), cornerRadius: 16) {
            HStack(alignment: .top, spacing: 10) {
                Circle()
                    .fill(TipPreviewPalette.loomAI[3].opacity(0.16))
                    .frame(width: 34, height: 34)
                    .overlay {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.caption.weight(.bold))
                            .foregroundStyle(TipPreviewPalette.loomAI[3])
                    }

                VStack(alignment: .leading, spacing: 5) {
                    Text("Momentum Snapshot")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.primary)

                    Text(normalizedStep >= 3 ? "4 areas active, 9 wins this week" : "3 areas active, 6 wins this week")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    TipPreviewProgressBar(progress: normalizedStep >= 3 ? 0.82 : 0.58)
                        .frame(height: 8)
                }
            }
        }
    }

    private func smallWidget(
        title: String,
        systemImage: String,
        tint: Color,
        primary: String,
        secondary: String
    ) -> some View {
        TipPreviewPanel(fill: Color(.systemBackground), stroke: tint.opacity(0.16), cornerRadius: 16) {
            HStack(spacing: 6) {
                Image(systemName: systemImage)
                    .font(.caption.weight(.bold))
                    .foregroundStyle(tint)

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
            }

            Text(primary)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(2)

            Text(secondary)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var statusText: String {
        switch normalizedStep {
        case 1:
            return "Quick Capture widget saves straight into Loom."
        case 2:
            return "Focus widgets keep the current plan visible all day."
        case 3:
            return "Progress widgets surface momentum without opening the app."
        default:
            return "Widgets are being designed for fast visibility and one-tap action."
        }
    }
}
