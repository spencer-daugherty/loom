import SwiftUI

struct OnboardingSlideView: View {
    let page: OnboardingPage

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        VStack(spacing: 24) {
            visual
                .frame(maxWidth: .infinity)
                .frame(height: 250)

            VStack(spacing: 12) {
                Text(page.headline)
                    .font(.title2.weight(.bold))
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)

                Text(page.body)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.horizontal, 6)
        }
        .padding(.horizontal, 20)
        .padding(.top, 16)
    }

    @ViewBuilder
    private var visual: some View {
        switch page.visualKind {
        case .strands, .weave, .identity, .summary:
            StrandAnimationPlaceholderView(reduceMotion: reduceMotion)
        case .balance, .radar:
            RadarPlaceholderView(reduceMotion: reduceMotion)
        case .execution:
            TodayMockPlaceholderView(reduceMotion: reduceMotion)
        }
    }
}

struct StrandAnimationPlaceholderView: View {
    let reduceMotion: Bool
    @State private var shift: CGFloat = -18

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            ForEach(0..<6, id: \.self) { index in
                Capsule()
                    .fill(Color.accentColor.opacity(0.17 + (Double(index) * 0.08)))
                    .frame(width: 250, height: 12)
                    .rotationEffect(.degrees(Double(index * 11) - 24))
                    .offset(x: reduceMotion ? 0 : shift, y: CGFloat(index * 14) - 35)
            }

            Text("Strands Placeholder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 170)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 2.2).repeatForever(autoreverses: true)) {
                shift = 18
            }
        }
    }
}

struct RadarPlaceholderView: View {
    let reduceMotion: Bool
    @State private var pulse = 0.95

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            ForEach(1...4, id: \.self) { ring in
                Circle()
                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1.5)
                    .frame(width: CGFloat(50 + ring * 35), height: CGFloat(50 + ring * 35))
            }

            Polygon(sides: 6)
                .stroke(Color.accentColor, lineWidth: 3)
                .frame(width: 130, height: 130)
                .scaleEffect(reduceMotion ? 1 : pulse)

            Text("Radar Placeholder")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(8)
                .background(.ultraThinMaterial, in: Capsule())
                .padding(.top, 170)
        }
        .onAppear {
            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = 1.05
            }
        }
    }
}

struct TodayMockPlaceholderView: View {
    let reduceMotion: Bool
    @State private var reveal = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            VStack(spacing: 10) {
                HStack {
                    Circle().fill(Color.accentColor).frame(width: 9, height: 9)
                    Text("Today")
                        .font(.headline)
                    Spacer()
                }

                ForEach(0..<3, id: \.self) { idx in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color.accentColor.opacity(0.12 + (Double(idx) * 0.08)))
                        .frame(height: 34)
                        .overlay(alignment: .leading) {
                            RoundedRectangle(cornerRadius: 6)
                                .fill(Color.accentColor.opacity(0.32))
                                .frame(width: reveal ? CGFloat(85 + idx * 35) : 36, height: 10)
                                .padding(.leading, 10)
                                .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: reveal)
                        }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .onAppear { reveal = true }
    }
}

private struct Polygon: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        guard sides >= 3 else { return Path() }
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        var path = Path()

        for side in 0..<sides {
            let angle = (Double(side) * (360.0 / Double(sides)) - 90) * .pi / 180
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if side == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
