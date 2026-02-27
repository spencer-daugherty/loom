import SwiftUI

private let onboardingDefaultFulfillmentColors: [Color] = [
    .blue,
    .indigo,
    .green,
    .purple,
    .red,
    .orange
]

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
        case .strands:
            StrandAnimationPlaceholderView(
                reduceMotion: reduceMotion,
                colors: onboardingDefaultFulfillmentColors
            )
        case .weave:
            LoomSplashBoxPlaceholderView(reduceMotion: reduceMotion)
        case .identity:
            IdentityVisionPlaceholderView(reduceMotion: reduceMotion)
        case .summary:
            StrandAnimationPlaceholderView(
                reduceMotion: reduceMotion,
                colors: onboardingDefaultFulfillmentColors
            )
        case .balance, .radar:
            RadarPlaceholderView(reduceMotion: reduceMotion)
        case .execution:
            TodayMockPlaceholderView(reduceMotion: reduceMotion)
        }
    }
}

struct IdentityVisionPlaceholderView: View {
    let reduceMotion: Bool
    @State private var lineReveal: CGFloat = 0
    @State private var circlesVisible = false
    @State private var pulse = false

    private let passionIcons: [String] = [
        "heart.fill",
        "lock.fill",
        "bolt.fill",
        "shield.fill"
    ]

    private let grayscaleCircleColors: [Color] = [
        Color(white: 0.82),
        Color(white: 0.68),
        Color(white: 0.56),
        Color(white: 0.44)
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            VStack(spacing: 22) {
                HStack(spacing: 12) {
                    Text("Purpose")
                        .font(.headline.weight(.semibold))
                        .foregroundStyle(.primary)

                    Capsule()
                        .fill(Color.accentColor.opacity(0.22))
                        .frame(width: 160, height: 12)
                        .overlay(alignment: .leading) {
                            Capsule()
                                .fill(Color.accentColor.opacity(0.65))
                                .frame(width: 160 * max(0, min(1, lineReveal)), height: 12)
                        }
                }

                HStack(spacing: 14) {
                    ForEach(0..<4, id: \.self) { index in
                        Circle()
                            .fill(grayscaleCircleColors[index].opacity(0.92))
                            .frame(width: 44, height: 44)
                            .overlay {
                                Circle()
                                    .stroke(.white.opacity(0.30), lineWidth: 1)
                                Image(systemName: passionIcons[index])
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.white.opacity(0.94))
                            }
                            .scaleEffect(reduceMotion ? 1 : (pulse ? 1.06 : 0.94))
                            .opacity(circlesVisible ? 1 : 0)
                            .offset(y: reduceMotion ? 0 : (pulse ? -2 : 2))
                            .animation(
                                reduceMotion ? nil : .spring(response: 0.42, dampingFraction: 0.8).delay(Double(index) * 0.08),
                                value: circlesVisible
                            )
                    }
                }
            }
            .padding(.horizontal, 20)
        }
        .onAppear {
            if reduceMotion {
                lineReveal = 1
                circlesVisible = true
                return
            }

            lineReveal = 0
            circlesVisible = false
            pulse = false

            withAnimation(.easeOut(duration: 0.65)) {
                lineReveal = 1
            }

            withAnimation(.easeOut(duration: 0.45).delay(0.14)) {
                circlesVisible = true
            }

            withAnimation(.easeInOut(duration: 1.4).repeatForever(autoreverses: true).delay(0.25)) {
                pulse = true
            }
        }
    }
}

struct StrandAnimationPlaceholderView: View {
    let reduceMotion: Bool
    let colors: [Color]
    @State private var animationStartDate: Date = .now

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            WindLinesBackground(
                colors: colors,
                animationStartDate: animationStartDate,
                lineCount: 6,
                lineWidth: 14.4,
                sourceBandFraction: 0.8,
                logoWidth: 40,
                logoHeight: 40,
                leftInset: -28,
                startXFractionOverride: -0.185,
                endXFractionOverride: 1.185,
                endBandFractionOverride: 0.78,
                reverseEndOrdering: true,
                reverseRevealLineIndices: [1, 3, 5],
                applyFunnel: false,
                fixedStartFractions: [0.12, 0.25, 0.38, 0.62, 0.75, 0.88],
                fixedEndFractions: [0.84, 0.70, 0.56, 0.44, 0.30, 0.16]
            )
            .offset(y: 2)
            .allowsHitTesting(false)
            .opacity(reduceMotion ? 0.95 : 1.0)
        }
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .onAppear {
            animationStartDate = .now
        }
    }
}

struct LoomSplashBoxPlaceholderView: View {
    let reduceMotion: Bool
    @Environment(\.colorScheme) private var colorScheme
    @State private var splashStartDate: Date = .now
    @State private var hasStartedMotion = false
    @State private var startupTask: Task<Void, Never>? = nil

    private let metrics: [(String, Color, Double)] = [
        ("Area 1", .blue, 20),
        ("Area 2", .indigo, 20),
        ("Area 3", .green, 20),
        ("Area 4", .purple, 20),
        ("Area 5", .red, 20),
        ("Area 6", .orange, 20),
    ]

    private func pulsedMetrics(at time: TimeInterval) -> [(String, Color, Double)] {
        metrics.enumerated().map { idx, tuple in
            let base = tuple.2
            let seed1 = Double((idx * 127 + 311) % 100) / 100.0
            let seed2 = Double((idx * 73 + 97) % 100) / 100.0
            let amplitude = 18.0 * (0.9 + seed1 * 0.8)
            let speed = 1.4 * (0.8 + seed2 * 1.2)
            let phase1 = Double(idx) * 0.8 + seed1 * .pi * 2
            let phase2 = Double(idx) * 1.3 + seed2 * .pi

            let delta1 = sin(time * speed + phase1) * amplitude * 0.7
            let delta2 = sin(time * speed * 0.47 + phase2) * amplitude * 0.3
            let value = max(12, min(100, base + delta1 + delta2))
            return (tuple.0, tuple.1, value)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            ZStack {
                WindLinesBackground(
                    colors: metrics.map { $0.1 },
                    animationStartDate: splashStartDate,
                    lineCount: 6,
                    lineWidth: 14.4, // 60% of prior 24pt thickness
                    sourceBandFraction: 0.8,
                    logoWidth: 40,
                    logoHeight: 40,
                    leftInset: -28
                )
                .offset(y: 2)
                .allowsHitTesting(false)
                .opacity(hasStartedMotion ? 1 : 0)

                if reduceMotion {
                    splashCore(metrics: metrics, rotationDegrees: 0, radarScale: 1, radarOpacity: 1)
                } else {
                    if hasStartedMotion {
                        TimelineView(.animation) { context in
                            let t = context.date.timeIntervalSinceReferenceDate
                            let startupElapsed = context.date.timeIntervalSince(splashStartDate)
                            let radarIntroDelay: Double = 1.0
                            let radarGrowDuration: Double = 0.26
                            let radarPopDuration: Double = 0.24

                            let introRaw = (startupElapsed - radarIntroDelay) / radarGrowDuration
                            let intro = max(0.0, min(introRaw, 1.0))
                            let easedIntro = 1.0 - pow(1.0 - intro, 3.0)

                            let baseScale = CGFloat(0.05 + (0.95 * easedIntro))
                            let popStart = radarIntroDelay + radarGrowDuration
                            let popRaw = (startupElapsed - popStart) / radarPopDuration
                            let pop = max(0.0, min(popRaw, 1.0))
                            let popPulse = sin(pop * .pi) * 0.10

                            splashCore(
                                metrics: pulsedMetrics(at: t * 0.45),
                                rotationDegrees: t * 337.5,
                                radarScale: baseScale * CGFloat(1.0 + popPulse),
                                radarOpacity: easedIntro
                            )
                        }
                    } else {
                        splashCore(metrics: metrics, rotationDegrees: 0, radarScale: 0.05, radarOpacity: 0)
                    }
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        }
        .onAppear {
            guard !reduceMotion else { return }
            hasStartedMotion = false
            startupTask?.cancel()
            startupTask = Task { @MainActor in
                try? await Task.sleep(nanoseconds: 120_000_000)
                splashStartDate = .now
                hasStartedMotion = true
            }
        }
        .onDisappear {
            startupTask?.cancel()
            startupTask = nil
        }
    }

    private func splashCore(
        metrics: [(String, Color, Double)],
        rotationDegrees: Double,
        radarScale: CGFloat,
        radarOpacity: Double
    ) -> some View {
        HStack(spacing: 10) {
            Color.clear.frame(width: 76, height: 76)

            Group {
                if colorScheme == .dark {
                    Image("logo")
                        .resizable()
                        .renderingMode(.template)
                        .foregroundStyle(.white)
                } else {
                    Image("logo")
                        .resizable()
                }
            }
            .scaledToFit()
            .frame(height: 40)
            .opacity(0.95)

            FulfillmentInteractiveRadar(
                metrics: metrics,
                selectedIndex: .constant(0),
                onManualSelect: {},
                enableInteraction: false,
                customDotDiameter: 8,
                showOutline: false,
                emphasizeSelectedSlice: false,
                customDotShadowColor: colorScheme == .dark ? Color(.secondarySystemBackground) : nil
            )
            .frame(width: 76, height: 76)
            .rotationEffect(.degrees(rotationDegrees))
            .scaleEffect(radarScale)
            .opacity(radarOpacity)
            .offset(x: -20)
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
