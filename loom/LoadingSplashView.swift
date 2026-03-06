import SwiftUI

fileprivate let fallbackFulfillmentMetrics: [(String, Color, Double)] = [
    ("Area 1", FulfillmentCategoryTheme.color(for: "Career & Business"), 20),
    ("Area 2", FulfillmentCategoryTheme.color(for: "Leadership & Impact"), 20),
    ("Area 3", FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"), 20),
    ("Area 4", FulfillmentCategoryTheme.color(for: "Mind & Meaning"), 20),
    ("Area 5", FulfillmentCategoryTheme.color(for: "Love & Relationships"), 20),
    ("Area 6", FulfillmentCategoryTheme.color(for: "Health & Vitality"), 20),
]

// Reusable radar graph used in both the splash screen and the Fulfillment card
struct FulfillmentRadarGraph: View {
    let metrics: [(String, Color, Double)] // (title, color, percentage 0...100)
    let showOutline: Bool
    let dotDiameter: CGFloat
    let showDotOutline: Bool
    let showDotShadow: Bool

    init(metrics: [(String, Color, Double)], showOutline: Bool = true, dotDiameter: CGFloat = 14, showDotOutline: Bool = true, showDotShadow: Bool = true) {
        self.metrics = metrics.isEmpty ? fallbackFulfillmentMetrics : metrics
        self.showOutline = showOutline
        self.dotDiameter = dotDiameter
        self.showDotOutline = showDotOutline
        self.showDotShadow = showDotShadow
    }

    var body: some View {
        GeometryReader { geo in
            let size   = min(geo.size.width, geo.size.height)
            let half   = size / 2
            let radius = half
            let center = CGPoint(x: half, y: half)
            let count  = metrics.count
            let sideCount = max(3, count)

            if count == 0 {
                Color.clear
            } else {
                // compute outer polygon vertices (one side per category)
                let outerPoints: [CGPoint] = (0..<count).map { i in
                    let angle = Angle.degrees(Double(i)/Double(count)*360 - 90).radians
                    return CGPoint(x: half + cos(angle)*radius,
                                   y: half + sin(angle)*radius)
                }
                // compute data polygon vertices
                let filledPoints: [CGPoint] = outerPoints.enumerated().map { i, pt in
                    let ratio = max(0.2, min(metrics[i].2 / 100, 1))
                    return CGPoint(x: half + (pt.x - half)*ratio,
                                   y: half + (pt.y - half)*ratio)
                }

                // build the net path
                let webPath = Path { path in
                    guard let first = filledPoints.first else { return }
                    path.move(to: first)
                    for p in filledPoints.dropFirst() { path.addLine(to: p) }
                    path.closeSubpath()
                }

                // angular gradient stops for netting (50% opacity), thinner bands
                let stops: [Gradient.Stop] = {
                    let countD: Double = Double(count)
                    let frac: Double = 1.0 / countD
                    let shrink: Double = frac * 0.3
                    var s: [Gradient.Stop] = []
                    s.reserveCapacity(count * 2 + 1)
                    for i in 0..<count {
                        let iD: Double = Double(i)
                        let base: Double = iD / countD
                        let start: Double = max(base - shrink, 0)
                        let end: Double = min(base + shrink, 1)
                        let color = metrics[i].1.opacity(0.5)
                        s.append(.init(color: color, location: start))
                        s.append(.init(color: color, location: end))
                    }
                    let endColor = metrics[0].1.opacity(0.5)
                    s.append(.init(color: endColor, location: 1.0))
                    return s
                }()

                ZStack {
                    // Netting
                    webPath
                        .fill(
                            AngularGradient(
                                gradient: .init(stops: stops),
                                center: .center,
                                startAngle: .degrees(-90),
                                endAngle: .degrees(270)
                            )
                        )

                    // Outermost polygon outline (optional)
                    if showOutline {
                        Path { path in
                            for j in 0..<sideCount {
                                let a = Angle.degrees(Double(j)/Double(sideCount)*360 - 90).radians
                                let pt = CGPoint(
                                    x: center.x + cos(a)*radius,
                                    y: center.y + sin(a)*radius
                                )
                                if j == 0 { path.move(to: pt) }
                                else      { path.addLine(to: pt) }
                            }
                            path.closeSubpath()
                        }
                        .stroke(Color(.separator), lineWidth: 4)
                    }

                    // Data dots with white outline and glow
                    ForEach(filledPoints.indices, id: \.self) { i in
                        let scale = max(0.1, dotDiameter / 14)
                        Circle()
                            .fill(metrics[i].1)
                            .frame(width: dotDiameter, height: dotDiameter)
                            .overlay {
                                if showDotOutline {
                                    Circle().stroke(Color(.systemBackground), lineWidth: 2 * scale)
                                }
                            }
                            .shadow(color: showDotShadow ? Color(.systemBackground).opacity(0.9) : Color.clear,
                                    radius: showDotShadow ? 10 * scale : 0,
                                    x: 0, y: 0)
                            .position(filledPoints[i])
                    }
                }
            }
        }
    }
}

private struct LoadingSplashPreviewHost: View {
    @Namespace private var namespace

    var body: some View {
        LoadingSplashView(
            metrics: [],
            namespace: namespace,
            minimumDisplayDuration: 0.1
        )
    }
}

#Preview {
    LoadingSplashPreviewHost()
        .loomPreviewContainer()
}

private struct DarkModeInvertImage: ViewModifier {
    @Environment(\.colorScheme) private var colorScheme

    func body(content: Content) -> some View {
        if colorScheme == .dark {
            // Invert colors but preserve transparency behavior
            content
                .colorInvert()
                .compositingGroup()
        } else {
            content
        }
    }
}

// Animated background of thin wind lines flowing left-to-right on the left side of the logo
// Animated background of thin wind lines flowing left-to-right on the left side of the logo
struct WindLinesBackground: View {
    let colors: [Color]
    let animationStartDate: Date
    let lineCount: Int
    let lineWidth: CGFloat
    let sourceBandFraction: Double
    let logoWidth: CGFloat
    let logoHeight: CGFloat
    let leftInset: CGFloat
    let startXFractionOverride: CGFloat?
    let endXFractionOverride: CGFloat?
    let endBandFractionOverride: CGFloat?
    let reverseEndOrdering: Bool
    let crossoverProgressOverride: CGFloat?
    let reverseRevealLineIndices: Set<Int>
    let applyFunnel: Bool
    let fixedStartFractions: [CGFloat]?
    let fixedEndFractions: [CGFloat]?

    init(
        colors: [Color],
        animationStartDate: Date = .distantPast,
        lineCount: Int = 30,
        lineWidth: CGFloat = 10,
        sourceBandFraction: Double = 0.4,
        logoWidth: CGFloat = 48,
        logoHeight: CGFloat = 48,
        leftInset: CGFloat = 0,
        startXFractionOverride: CGFloat? = nil,
        endXFractionOverride: CGFloat? = nil,
        endBandFractionOverride: CGFloat? = nil,
        reverseEndOrdering: Bool = false,
        crossoverProgressOverride: CGFloat? = nil,
        reverseRevealLineIndices: Set<Int> = [],
        applyFunnel: Bool = true,
        fixedStartFractions: [CGFloat]? = nil,
        fixedEndFractions: [CGFloat]? = nil
    ) {
        self.colors = colors.isEmpty ? fallbackFulfillmentMetrics.map { $0.1 } : colors
        self.animationStartDate = animationStartDate
        self.lineCount = max(1, lineCount)
        self.lineWidth = max(1, lineWidth)
        self.sourceBandFraction = max(0.05, min(sourceBandFraction, 1.0))
        self.logoWidth = logoWidth
        self.logoHeight = logoHeight
        self.leftInset = leftInset
        self.startXFractionOverride = startXFractionOverride
        self.endXFractionOverride = endXFractionOverride
        self.endBandFractionOverride = endBandFractionOverride
        self.reverseEndOrdering = reverseEndOrdering
        self.crossoverProgressOverride = crossoverProgressOverride
        self.reverseRevealLineIndices = reverseRevealLineIndices
        self.applyFunnel = applyFunnel
        self.fixedStartFractions = fixedStartFractions
        self.fixedEndFractions = fixedEndFractions
    }

    private let logoMargin: CGFloat = 10

    private var verticalBandFraction: Double { sourceBandFraction }

    // Tuning knobs
    private let verticalShift: CGFloat = 0
    private let rightStopInset: CGFloat = 16

    // Funnel tuning (gradual across the whole line)
    private let funnelMinScale: CGFloat = 0.16    // how narrow it gets near the logo (0 = razor, 1 = no funnel)
    private let funnelCurve: CGFloat = 1.35       // >1 = slower at first, tighter near the end; 1 = linear-ish

    // Deterministic pseudo-random generator
    private func rand(_ seed: Int, _ a: Double, _ b: Double) -> Double {
        let seedD = Double(seed)
        let x = sin(seedD * 12.9898) * 43758.5453
        let u = x - floor(x)
        return a + (b - a) * u
    }

    var body: some View {
        TimelineView(.animation) { context in
            GeometryReader { geo in
                let size = geo.size
                let centerX = size.width / 2
                let startX = startXFractionOverride.map { size.width * $0 } ?? self.leftInset
                let defaultEndX = centerX - logoWidth / 2 - logoMargin - rightStopInset
                let endX = max(startX + 40, endXFractionOverride.map { size.width * $0 } ?? defaultEndX)
                let startupElapsed = context.date.timeIntervalSince(animationStartDate)

                Canvas { ctx, sz in
                    let t = context.date.timeIntervalSinceReferenceDate

                    let logoCenterY: CGFloat = sz.height / 2
                    let logoTop: CGFloat = logoCenterY - logoHeight / 2
                    let logoBottom: CGFloat = logoCenterY + logoHeight / 2
                    let logoCenter: CGFloat = (logoTop + logoBottom) * 0.5 + verticalShift

                    func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
                        let t = min(max((x - a) / (b - a), 0), 1)
                        return t * t * (3 - 2 * t)
                    }

                    for i in 0..<lineCount {
                        // Vertical distribution band (START positions stay the same)
                        let band = max(0.05, min(verticalBandFraction, 1.0))
                        let bandStart = 0.5 - band / 2.0

                        let localFracBase = (Double(i) + 0.5) / Double(lineCount)
                        let jitter = rand(i * 19 + 7, -0.03, 0.03)
                        let localFrac = min(max(localFracBase + jitter, 0.0), 1.0)
                        let clampedFrac = bandStart + band * localFrac

                        // Start Y (unchanged)
                        let startFracResolved: CGFloat = {
                            if let fixedStartFractions, i < fixedStartFractions.count {
                                return max(0, min(1, fixedStartFractions[i]))
                            }
                            return CGFloat(clampedFrac)
                        }()
                        let baseY: CGFloat = startFracResolved * sz.height + verticalShift

                        // End Y distribution can be overridden for alternate layouts (e.g., onboarding X-shape).
                        let centerSpread: CGFloat = {
                            if let endBandFractionOverride {
                                return max(8, min(1, endBandFractionOverride)) * sz.height
                            }
                            return logoHeight * 0.42
                        }()
                        let topY = logoCenter - centerSpread / 2
                        let bottomY = logoCenter + centerSpread / 2
                        let span = max(1, bottomY - topY)

                        let rawFrac: CGFloat =
                            lineCount <= 1 ? 0.5 : CGFloat(i) / CGFloat(lineCount - 1)
                        let startBandNormalized = max(0, min(1, CGFloat(localFrac)))
                        let endFrac: CGFloat = {
                            if reverseEndOrdering {
                                // Mirror each line's own start distribution at the destination.
                                // This keeps the crossover centered rather than skewing left/right.
                                return 1 - startBandNormalized
                            }
                            return rawFrac
                        }()
                        let endY: CGFloat = {
                            if let fixedEndFractions, i < fixedEndFractions.count {
                                return max(0, min(1, fixedEndFractions[i])) * sz.height + verticalShift
                            }
                            return topY + endFrac * span
                        }()

                        let colorIndex = colors.isEmpty ? 0 : i % colors.count
                        let color = colors.isEmpty ? .accentColor : colors[colorIndex]

                        let L = endX - startX
                        if L <= 1 { continue }

                        // Startup reveal: lines grow left -> right with slight per-line delays.
                        let lineDelay = rand(i * 83 + 17, 0.00, 0.36)
                        let lineRevealDuration = rand(i * 89 + 23, 0.62, 1.05)
                        let rawReveal = (startupElapsed - lineDelay) / lineRevealDuration
                        let revealProgress = max(0.0, min(rawReveal, 1.0))
                        if revealProgress <= 0.0 { continue }
                        let reverseReveal = reverseRevealLineIndices.contains(i)
                        let revealEdgeX = reverseReveal
                            ? endX - L * CGFloat(revealProgress)
                            : startX + L * CGFloat(revealProgress)

                        // Animation params
                        let speed = rand(i * 13 + 1, 0.15, 0.35)
                        let phase = rand(i * 17 + 3, 0.0, 1.0)
                        let posFrac = (t * speed + phase).truncatingRemainder(dividingBy: 1)

                        // Ocean mode: huge amplitude + multi-wave turbulence
                        let amp = rand(i * 23 + 5, 10.0, 40.0)
                        let freq = rand(i * 29 + 9, 2.0, 6.0)
                        let sigma = rand(i * 31 + 11, 0.08, 0.16)
                        let wobblePhase = rand(i * 37 + 13, 0.0, 2 * .pi)

                        // Extra “chop” layers
                        let chop1 = rand(i * 41 + 101, 6.0, 12.0)
                        let chop2 = rand(i * 47 + 103, 12.0, 22.0)
                        let chopPhase1 = rand(i * 53 + 107, 0.0, 2 * .pi)
                        let chopPhase2 = rand(i * 59 + 109, 0.0, 2 * .pi)

                        let timeScale: Double = 0.8 + rand(i * 61 + 113, 0.0, 0.8)
                        let oceanTime: Double = t * timeScale

                        // Helpers
                        func smoothstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
                            let tt = min(max((x - a) / (b - a), 0), 1)
                            return tt * tt * (3 - 2 * tt)
                        }

                        var path = Path()
                        let samples = 96

                        for j in 0...samples {
                            let twoPi: Double = 2.0 * Double.pi

                            let localS = Double(j) / Double(samples)
                            let s = localS
                            let x = startX + CGFloat(localS) * L

                            if reverseReveal {
                                if x < revealEdgeX { continue }
                            } else {
                                if x > revealEdgeX { continue }
                            }

                            let diff = (s - posFrac) / sigma
                            let envelope = exp(-pow(diff, 2) * 2)

                            let pulseArg: Double =
                                twoPi * (s * freq - oceanTime * speed * 0.6) + wobblePhase
                            let pulse: Double = sin(pulseArg) * amp * envelope

                            let swellArg: Double =
                                twoPi * (s * (freq * 0.45) + oceanTime * speed * 0.25) + wobblePhase * 0.7
                            let swell: Double = sin(swellArg) * (amp * 0.55)

                            let chopAArg: Double =
                                twoPi * (s * chop1 - oceanTime * speed * 1.2) + chopPhase1
                            let chopBArg: Double =
                                twoPi * (s * chop2 + oceanTime * speed * 1.7) + chopPhase2

                            let chop: Double =
                                sin(chopAArg) * (amp * 0.18) +
                                sin(chopBArg) * (amp * 0.10)

                            let edge: Double = sin(Double.pi * s)
                            let wiggleScale: Double = 0.5
                            let centerIntersectionLock = reverseEndOrdering && !applyFunnel
                            let centerNotch: Double = {
                                guard centerIntersectionLock else { return 1.0 }
                                let d = (s - 0.5) / 0.17
                                // 0 at exact center, ~1 away from center
                                return 1.0 - exp(-(d * d))
                            }()
                            let wiggle: Double = (pulse + swell + chop) * edge * wiggleScale * centerNotch

                            let baseLineY: CGFloat = baseY + (endY - baseY) * CGFloat(s)
                            var y = baseLineY + CGFloat(wiggle)

                            // Keep crossover mode geometrically stable after intersection; otherwise apply standard funnel.
                            if applyFunnel && crossoverProgressOverride == nil {
                                // ===== Funnel WITHOUT the hourglass (more aggressive curve-in + pinches late) =====
                                let sC = CGFloat(s)

                                // 1) More aggressive curvature (always on): ramp harder mid-to-late
                                let bendStart: CGFloat = 0.05
                                let bendEnd: CGFloat = 0.82

                                let rawBendT = smoothstep(bendStart, bendEnd, sC)          // 0 -> 1
                                let bendT = pow(rawBendT, 0.55)                            // <1 = ramps faster (more aggressive)

                                // Strength of the steering toward the logo
                                let bendStrength: CGFloat = 0.42                           // was ~0.22
                                let steerY = y + (logoCenter - y) * (bendT * bendStrength)

                                // 2) Late pinch (only near the end)
                                let pinchStart: CGFloat = 0.84
                                let pinchT = smoothstep(pinchStart, 1.0, sC)
                                let pinchCurve = pow(pinchT, funnelCurve)

                                // 3) Attractor slides logoCenter -> endY near the end (half-hourglass)
                                let attractStart: CGFloat = 0.78
                                let attractT = smoothstep(attractStart, 1.0, sC)
                                let attractorY = logoCenter + (endY - logoCenter) * attractT

                                // Combine: steer first, then pinch around the moving attractor
                                let lateScale = (1.0 - pinchCurve) + pinchCurve * funnelMinScale
                                y = attractorY + (steerY - attractorY) * lateScale
                            }

                            // Hard anchor at the start only
                            if j == 0 { y = baseY }

                            let point = CGPoint(x: x, y: y)
                            if j == 0 { path.move(to: point) }
                            else { path.addLine(to: point) }
                        }

                        // ========= Tail Fade (last 10%, gradual) =========
                        let tailStartFrac: CGFloat = 0.90
                        let tailStartStop: Double = Double(tailStartFrac)

                        let baseOpacity: Double = 0.125
                        let tailGradient = Gradient(stops: [
                            .init(color: color.opacity(baseOpacity), location: 0.0),
                            .init(color: color.opacity(baseOpacity), location: tailStartStop),

                            .init(color: color.opacity(baseOpacity * 0.75), location: min(tailStartStop + 0.03, 1.0)),
                            .init(color: color.opacity(baseOpacity * 0.45), location: min(tailStartStop + 0.06, 1.0)),
                            .init(color: color.opacity(baseOpacity * 0.22), location: min(tailStartStop + 0.085, 1.0)),
                            .init(color: color.opacity(0.0),                location: 1.0),
                        ])

                        ctx.stroke(
                            path,
                            with: .linearGradient(
                                tailGradient,
                                startPoint: CGPoint(x: startX, y: baseY),
                                endPoint: CGPoint(x: endX, y: endY)
                            ),
                            lineWidth: lineWidth
                        )

                        // ========= Glow Fade matches Tail Fade =========
                        let tailFactorAtGlow: Double = 1.0 - smoothstepD(Double(tailStartFrac), 1.0, posFrac)
                        let glowPeak: Double = 0.45 * tailFactorAtGlow

                        let glowHalfWidth = sigma * 0.8
                        let startStop = max(0.0, posFrac - glowHalfWidth)
                        let endStop   = min(1.0, posFrac + glowHalfWidth)

                        let gradient = Gradient(stops: [
                            .init(color: color.opacity(0.0),       location: startStop),
                            .init(color: color.opacity(glowPeak),  location: posFrac),
                            .init(color: color.opacity(0.0),       location: endStop),
                        ])

                        let gradStart = CGPoint(x: startX, y: baseY)
                        let gradEnd   = CGPoint(x: endX, y: endY)

                        // Clip blur so glow doesn't "cap" and look like expansion at the end
                        let revealMinX = reverseReveal ? revealEdgeX : startX
                        let revealMaxX = reverseReveal ? endX : revealEdgeX
                        let clipRect = CGRect(x: revealMinX, y: 0, width: max(1, revealMaxX - revealMinX), height: sz.height)

                        ctx.drawLayer { layer in
                            layer.clip(to: Path(clipRect))
                            layer.addFilter(.blur(radius: 7))
                            layer.stroke(
                                path,
                                with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd),
                                lineWidth: lineWidth + 2
                            )
                        }

                        ctx.drawLayer { layer in
                            layer.clip(to: Path(clipRect))
                            layer.addFilter(.blur(radius: 2))
                            layer.stroke(
                                path,
                                with: .linearGradient(gradient, startPoint: gradStart, endPoint: gradEnd),
                                lineWidth: max(1, lineWidth - 4)
                            )
                        }
                    }
                }
            }
        }
        .allowsHitTesting(false)
    }
}

// Full-screen loading splash with animated, spinning radar graph and Loom logo
struct LoadingSplashView: View {
    let metrics: [(String, Color, Double)]
    let namespace: Namespace.ID
    let minimumDisplayDuration: TimeInterval
    let onMinimumElapsed: (() -> Void)?
    private var isPresented: Binding<Bool>?
    @State private var splashRadarSelectedIndex: Int = 0

    @Environment(\.colorScheme) private var colorScheme
    @State private var isTransitioningOut = false
    @State private var splashStartDate: Date = .now
    @State private var hasStartedMotion: Bool = false
    @State private var startupTask: Task<Void, Never>? = nil

    init(
        metrics: [(String, Color, Double)],
        namespace: Namespace.ID,
        minimumDisplayDuration: TimeInterval = 5,
        onMinimumElapsed: (() -> Void)? = nil,
        isPresented: Binding<Bool>? = nil
    ) {
        self.metrics = metrics
        self.namespace = namespace
        self.minimumDisplayDuration = minimumDisplayDuration
        self.onMinimumElapsed = onMinimumElapsed
        self.isPresented = isPresented
    }

    // Pulsing configuration
    private let amplitude: Double = 180 // 10x more dramatic pulsing
    private let speed: Double = 1.6    // pulse speed multiplier
    private var effectiveMetrics: [(String, Color, Double)] {
        metrics.isEmpty ? fallbackFulfillmentMetrics : metrics
    }

    private func pulsedMetrics(at time: TimeInterval) -> [(String, Color, Double)] {
        effectiveMetrics.enumerated().map { idx, tuple in
            let base = tuple.2

            // Deterministic per-slice variation to avoid correlated motion
            let seed1 = Double((idx * 127 + 311) % 100) / 100.0
            let seed2 = Double((idx * 73 + 97) % 100) / 100.0

            let localAmp = amplitude * (0.9 + seed1 * 0.8)   // 0.9x ... 1.7x amplitude
            let localSpeed = speed * (0.8 + seed2 * 1.2)     // 0.8x ... 2.0x speed

            let phase1 = Double(idx) * 0.8 + seed1 * .pi * 2
            let phase2 = Double(idx) * 1.3 + seed2 * .pi

            // Blend two waves for a more organic, less correlated pulse
            let delta1 = sin(time * localSpeed + phase1) * localAmp * 0.7
            let delta2 = sin(time * localSpeed * 0.47 + phase2) * localAmp * 0.3

            let value = max(50, min(100, base + delta1 + delta2))
            return (tuple.0, tuple.1, value)
        }
    }

    @ViewBuilder
    private func centeredSplashRow(
        metrics: [(String, Color, Double)],
        rotationDegrees: Double,
        radarScale: CGFloat,
        radarOpacity: Double
    ) -> some View {
        GeometryReader { geo in
            HStack(spacing: 12) {
                Color.clear
                    .frame(width: 45, height: 45)

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 48)
                    .opacity(0.95)
                    .transition(.opacity)
                    .modifier(DarkModeInvertImage())

                ZStack {
                    FulfillmentInteractiveRadar(
                        metrics: metrics,
                        selectedIndex: $splashRadarSelectedIndex,
                        onManualSelect: {},
                        enableInteraction: false,
                        customDotDiameter: 10,
                        showOutline: false,
                        emphasizeSelectedSlice: false
                    )
                    .rotationEffect(.degrees(rotationDegrees))
                }
                .frame(width: 45, height: 45)
                .scaleEffect(radarScale)
                .opacity(radarOpacity)
                .matchedGeometryEffect(
                    id: "fulfillmentGraph",
                    in: namespace,
                    properties: .frame,
                    anchor: .center,
                    isSource: true
                )
            }
            .position(x: geo.size.width / 2, y: geo.size.height / 2)
        }
    }

    var body: some View {
        ZStack {
            (colorScheme == .dark ? Color.black : Color(.systemGroupedBackground))
                .ignoresSafeArea()

            if hasStartedMotion {
                WindLinesBackground(colors: effectiveMetrics.map { $0.1 }, animationStartDate: splashStartDate)
                    .ignoresSafeArea()
            }

            if hasStartedMotion {
                TimelineView(.animation) { context in
                    let t = context.date.timeIntervalSinceReferenceDate
                    let animatedMetrics = isTransitioningOut ? effectiveMetrics : pulsedMetrics(at: t * 0.45)
                    let rotationDegrees = isTransitioningOut ? 0.0 : (t * Double(337.5))
                    let startupElapsed = context.date.timeIntervalSince(splashStartDate)
                    let radarIntroDelay: Double = 1.0
                    let radarGrowDuration: Double = 0.26
                    let radarPopDuration: Double = 0.24

                    let introRaw = (startupElapsed - radarIntroDelay) / radarGrowDuration
                    let intro = max(0.0, min(introRaw, 1.0))
                    let easedIntro = 1.0 - pow(1.0 - intro, 3.0) // easeOut cubic

                    let baseScale = CGFloat(0.05 + (0.95 * easedIntro))
                    let popStart = radarIntroDelay + radarGrowDuration
                    let popRaw = (startupElapsed - popStart) / radarPopDuration
                    let pop = max(0.0, min(popRaw, 1.0))
                    let popPulse = sin(pop * .pi) * 0.10 // slight overshoot, then settle

                    let radarScale = baseScale * CGFloat(1.0 + popPulse)
                    let radarOpacity = isTransitioningOut ? 1.0 : easedIntro

                    centeredSplashRow(
                        metrics: animatedMetrics,
                        rotationDegrees: rotationDegrees,
                        radarScale: radarScale,
                        radarOpacity: radarOpacity
                    )
                }
            } else {
                centeredSplashRow(
                    metrics: effectiveMetrics,
                    rotationDegrees: 0,
                    radarScale: 0.05,
                    radarOpacity: 0
                )
            }
        }
        .ignoresSafeArea()
        .overlay(alignment: .bottom) {
            Text("Version: 0.1.0-alpha.7")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 10) // sits above the home indicator
        }
        .onAppear {
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
        .task {
            try? await Task.sleep(nanoseconds: UInt64(minimumDisplayDuration * 1_000_000_000))
            if let isPresented = isPresented {
                if isPresented.wrappedValue {
                    withAnimation(.linear(duration: 0.22)) {
                        isTransitioningOut = true
                    }
                    try? await Task.sleep(nanoseconds: 220_000_000)
                    isPresented.wrappedValue = false
                }
            } else {
                // Keep dismissal behavior consistent with binding-based teardown:
                // settle the animated radar first so matched geometry can snapshot cleanly.
                withAnimation(.linear(duration: 0.22)) {
                    isTransitioningOut = true
                }
                try? await Task.sleep(nanoseconds: 220_000_000)
                onMinimumElapsed?()
            }
        }
    }
}
