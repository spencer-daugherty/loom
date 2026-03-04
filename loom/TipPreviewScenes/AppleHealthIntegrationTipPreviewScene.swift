import SwiftUI

struct AppleHealthIntegrationTipPreviewScene: View {
    let step: Int
    let isAnimated: Bool

    private var ringProgress: CGFloat {
        switch step % 4 {
        case 0: return 0.24
        case 1: return 0.52
        case 2: return 0.76
        default: return 0.92
        }
    }

    private var metricValue: Int {
        switch step % 4 {
        case 0: return 3_100
        case 1: return 4_850
        case 2: return 6_420
        default: return 7_200
        }
    }

    var body: some View {
        TipPreviewSurface {
            GeometryReader { proxy in
                let contentWidth = max(1, proxy.size.width)
                let ringSize = min(62, max(48, contentWidth * 0.30))
                let ringLineWidth = max(5, ringSize * 0.11)

                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Text("Apple Health")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Spacer()
                        Toggle("", isOn: .constant(true))
                            .labelsHidden()
                            .disabled(true)
                            .scaleEffect(0.78)
                    }

                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .stroke(Color.pink.opacity(0.18), lineWidth: ringLineWidth)
                            Circle()
                                .trim(from: 0, to: ringProgress)
                                .stroke(
                                    AngularGradient(
                                        colors: [Color.pink, Color.red, Color.orange],
                                        center: .center
                                    ),
                                    style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .round)
                                )
                                .rotationEffect(.degrees(-90))

                            VStack(spacing: 1) {
                                Text("\(metricValue)")
                                    .font(.caption2.weight(.bold))
                                Text("steps")
                                    .font(.system(size: 9, weight: .medium))
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: ringSize, height: ringSize)

                        VStack(alignment: .leading, spacing: 7) {
                            TipPreviewCard(
                                title: "Outcome Metric",
                                tint: Color.pink.opacity(0.12),
                                outline: Color.pink.opacity(0.28),
                                lineWidths: [0.78]
                            )
                            .frame(height: 40)

                            TipPreviewCard(
                                title: "Little Win Logged",
                                tint: step >= 3 ? Color.green.opacity(0.16) : Color(.systemGray5),
                                outline: step >= 3 ? Color.green.opacity(0.34) : Color.black.opacity(0.08),
                                lineWidths: [0.68]
                            )
                            .frame(height: 40)
                        }
                    }

                    Spacer(minLength: 0)
                }
            }
        }
    }
}
