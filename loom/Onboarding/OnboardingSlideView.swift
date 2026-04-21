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
        .padding(.top, 16)
        .reviewPathColumn(maxWidth: 640, horizontalPadding: 20, alignment: .top)
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
            LoomAIChatPlaceholderView(reduceMotion: reduceMotion)
        case .balance:
            FulfillmentBalancePlaceholderView(reduceMotion: reduceMotion)
        case .radar:
            LittleWinsDeckPlaceholderView(reduceMotion: reduceMotion)
        case .execution:
            TodayMockPlaceholderView(reduceMotion: reduceMotion)
        }
    }
}

#Preview {
    OnboardingSlideView(
        page: OnboardingPage(
            id: 0,
            headline: "Loom",
            body: "Previewing onboarding slide layout.",
            visualKind: .summary
        )
    )
    .loomPreviewContainer()
}

struct LoomAIChatPlaceholderView: View {
    let reduceMotion: Bool
    @State private var visiblePrompt = false
    @State private var visibleReply = false
    @State private var visibleSuggestions = false
    @State private var suggestionPairIndex = 0
    @State private var cycleTask: Task<Void, Never>?

    private let loomAISuggestionFill = LinearGradient(
        colors: [
            Color(red: 0.22, green: 0.47, blue: 1.0),
            Color(red: 0.62, green: 0.40, blue: 0.95),
            Color(red: 0.98, green: 0.36, blue: 0.58)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 16, height: 16)
                    Text("LoomAI")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [Color.blue.opacity(0.95), Color.cyan.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 186, height: 34)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 6) {
                            Capsule().fill(Color.white.opacity(0.9)).frame(width: 58, height: 8)
                            Capsule().fill(Color.white.opacity(0.75)).frame(width: 34, height: 8)
                        }
                        .padding(.leading, 10)
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .opacity(visiblePrompt ? 1 : 0)
                    .offset(y: visiblePrompt ? 0 : 6)

                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 218, height: 40)
                    .overlay(alignment: .leading) {
                        HStack(spacing: 6) {
                            Capsule().fill(Color.black.opacity(0.55)).frame(width: 76, height: 8)
                            Capsule().fill(Color.black.opacity(0.35)).frame(width: 44, height: 8)
                        }
                        .padding(.leading, 11)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .opacity(visibleReply ? 1 : 0)
                    .offset(y: visibleReply ? 0 : 6)

                VStack(alignment: .leading, spacing: 6) {
                    ForEach(0..<2, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(loomAISuggestionFill.opacity(0.92))
                            .frame(width: idx == 0 ? (160 + CGFloat(suggestionPairIndex * 2)) : (182 + CGFloat(suggestionPairIndex * 2)), height: 26)
                            .overlay(alignment: .leading) {
                                HStack(spacing: 6) {
                                    Circle().fill(Color.white.opacity(0.95)).frame(width: 6, height: 6)
                                    Capsule().fill(Color.white.opacity(0.78)).frame(width: idx == 0 ? 100 : 122, height: 7)
                                }
                                .padding(.leading, 9)
                            }
                            .overlay(
                                RoundedRectangle(cornerRadius: 10, style: .continuous)
                                    .stroke(Color.white.opacity(0.24), lineWidth: 1)
                            )
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .opacity(visibleSuggestions ? 1 : 0)
                .offset(y: visibleSuggestions ? 0 : 6)

                Spacer(minLength: 0)
            }
            .padding(14)
        }
        .onAppear {
            visiblePrompt = reduceMotion
            visibleReply = reduceMotion
            visibleSuggestions = reduceMotion
            cycleTask?.cancel()
            cycleTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                        visiblePrompt = false
                        visibleReply = false
                        visibleSuggestions = false
                    }
                    try? await Task.sleep(nanoseconds: 280_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                        visiblePrompt = true
                    }
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                        visibleReply = true
                    }
                    try? await Task.sleep(nanoseconds: 260_000_000)
                    guard !Task.isCancelled else { break }
                    withAnimation(reduceMotion ? nil : .easeOut(duration: 0.35)) {
                        suggestionPairIndex = (suggestionPairIndex + 1) % 3
                        visibleSuggestions = true
                    }
                    try? await Task.sleep(nanoseconds: reduceMotion ? 1_000_000_000 : 1_450_000_000)
                }
            }
        }
        .onDisappear {
            cycleTask?.cancel()
            cycleTask = nil
        }
    }
}

struct LittleWinsDeckPlaceholderView: View {
    let reduceMotion: Bool
    let showsShadow: Bool
    @State private var cardOrder: [Int] = [0, 1, 2]
    @State private var checkedByCard: [Int: Set<Int>] = [0: [], 1: [], 2: []]
    @State private var deckTask: Task<Void, Never>?
    @State private var rowSaturationPhase: Int = 0

    private let cardColors: [Color] = [.blue, .orange, .red]
    private let actionCountsByCard: [Int] = [3, 2, 2]

    init(reduceMotion: Bool, showsShadow: Bool = true) {
        self.reduceMotion = reduceMotion
        self.showsShadow = showsShadow
    }

    private func rowSaturationOpacity(for row: Int) -> Double {
        let rotated = (row + rowSaturationPhase) % 3
        switch rotated {
        case 0: return 0.82
        case 1: return 0.58
        default: return 0.34
        }
    }

    private func miniLittleWinCard(
        cardID: Int,
        depth: Int,
        checks: Set<Int>,
        rows: [Int]
    ) -> some View {
        let yOffset = CGFloat(depth) * 7
        let cardWidth: CGFloat = 94 - CGFloat(depth * 4)
        let cardHeight: CGFloat = cardWidth * 1.42
        let baseColor = cardColors[cardID]
        let tilt = reduceMotion ? 0 : Double(depth == 0 ? 0 : (depth == 1 ? -2 : 2))

        return RoundedRectangle(cornerRadius: 8, style: .continuous)
            .fill(baseColor)
            .frame(width: cardWidth, height: cardHeight)
            .overlay {
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(Color.white.opacity(0.72))
            }
            .overlay {
                ZStack(alignment: .leading) {
                    GeometryReader { geo in
                        let lineHeight: CGFloat = 2.6
                        let lineSpacing: CGFloat = 1.8
                        let lineCount = max(1, Int((geo.size.height + lineSpacing) / (lineHeight + lineSpacing)))

                        VStack(spacing: lineSpacing) {
                            ForEach(0..<lineCount, id: \.self) { idx in
                                RoundedRectangle(cornerRadius: 2.2, style: .continuous)
                                    .fill(baseColor.opacity(0.16))
                                    .frame(width: geo.size.width, height: lineHeight)
                                    .opacity(idx.isMultiple(of: 3) ? 0.95 : 0.78)
                            }
                        }
                    }
                    .opacity(0.72)

                    VStack(spacing: 4) {
                        ForEach(rows, id: \.self) { row in
                            let barOpacity = rowSaturationOpacity(for: row)
                            HStack(spacing: 4) {
                                Image(systemName: checks.contains(row) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 17, weight: .semibold))
                                    .foregroundStyle(baseColor)

                                RoundedRectangle(cornerRadius: 3, style: .continuous)
                                    .fill(baseColor.opacity(barOpacity))
                                    .frame(width: 38 - CGFloat(row * 6), height: 10)
                            }
                        }
                    }
                    .padding(.leading, 8)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .overlay(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(baseColor.opacity(0.95), lineWidth: 1.2)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .padding(.top, 5)
                    .padding(.leading, 5)
            }
            .overlay(alignment: .bottomTrailing) {
                RoundedRectangle(cornerRadius: 3, style: .continuous)
                    .stroke(baseColor.opacity(0.95), lineWidth: 1.2)
                    .frame(width: 12, height: 12)
                    .rotationEffect(.degrees(45))
                    .padding(.bottom, 5)
                    .padding(.trailing, 5)
            }
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(baseColor.opacity(0.36), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
            .offset(y: yOffset)
            .rotationEffect(.degrees(tilt))
            .shadow(color: showsShadow ? .black.opacity(0.08) : .clear, radius: 3, x: 0, y: 2)
            .zIndex(Double(10 - depth))
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            ZStack {
                ForEach(Array(cardOrder.enumerated()), id: \.element) { depth, cardID in
                    let checks = checkedByCard[cardID] ?? []
                    let rows = Array(0..<actionCountsByCard[cardID])

                    miniLittleWinCard(
                        cardID: cardID,
                        depth: depth,
                        checks: checks,
                        rows: rows
                    )
                }
            }
        }
        .onAppear {
            checkedByCard = [0: [], 1: [], 2: []]
            guard !reduceMotion else { return }

            deckTask?.cancel()
            deckTask = Task { @MainActor in
                while !Task.isCancelled {
                    let topCard = cardOrder.first ?? 0
                    let actionCount = actionCountsByCard[topCard]
                    checkedByCard[topCard] = []
                    try? await Task.sleep(nanoseconds: 120_000_000)
                    for row in 0..<actionCount {
                        guard !Task.isCancelled else { break }
                        _ = withAnimation(.spring(response: 0.3, dampingFraction: 0.86)) {
                            checkedByCard[topCard, default: []].insert(row)
                        }
                        rowSaturationPhase = (rowSaturationPhase + 1) % 3
                        try? await Task.sleep(nanoseconds: 220_000_000)
                    }
                    try? await Task.sleep(nanoseconds: 380_000_000)
                    guard !Task.isCancelled else { break }

                    withAnimation(.easeInOut(duration: 0.45)) {
                        let moved = cardOrder.removeFirst()
                        cardOrder.append(moved)
                    }
                    let nextTop = cardOrder.first ?? 0
                    checkedByCard[nextTop] = []
                    try? await Task.sleep(nanoseconds: 420_000_000)
                }
            }
        }
        .onDisappear {
            deckTask?.cancel()
            deckTask = nil
        }
    }
}

struct FulfillmentBalancePlaceholderView: View {
    let reduceMotion: Bool
    let showsShadow: Bool
    @State private var pulse = 0.985
    @State private var rotatingMetrics: [(String, Color, Double)] = []
    @State private var currentCount: Int = 3
    @State private var countDirection: Int = 1
    @State private var cycleTask: Task<Void, Never>?

    private let categoryPool: [String] = [
        "Career & Business",
        "Health & Energy",
        "Love & Relationships",
        "Wealth & Finance",
        "Fun & Recreation",
        "Spiritual & Emotional",
        "Family & Friends",
        "Learning & Growth",
        "Creativity & Expression",
        "Environment & Home"
    ]

    private var colorPool: [Color] {
        Array(FulfillmentCategoryTheme.palette.prefix(7).map(\.color))
    }

    init(reduceMotion: Bool, showsShadow: Bool = true) {
        self.reduceMotion = reduceMotion
        self.showsShadow = showsShadow
    }

    private func randomMetrics(count: Int) -> [(String, Color, Double)] {
        let sectionNames = Array(categoryPool.shuffled().prefix(count))
        let palette = Array(colorPool.prefix(7))
        let eligibleColors: [Color] = {
            if count >= 7 {
                return palette
            }
            return Array(palette.prefix(6))
        }()
        let colors = Array(eligibleColors.shuffled().prefix(count))
        return (0..<count).map { idx in
            let value = Double(Int.random(in: 28...84))
            return (sectionNames[idx], colors[idx], value)
        }
    }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            FulfillmentInteractiveRadar(
                metrics: rotatingMetrics,
                selectedIndex: .constant(0),
                onManualSelect: {},
                enableInteraction: false,
                showOutline: true,
                emphasizeSelectedSlice: false
            )
            .frame(width: 176, height: 176)
            .scaleEffect(reduceMotion ? 1 : pulse)
        }
        .shadow(
            color: showsShadow ? Color.black.opacity(reduceMotion ? 0.08 : (pulse > 1.0 ? 0.22 : 0.10)) : .clear,
            radius: reduceMotion ? 4 : (pulse > 1.0 ? 16 : 7),
            x: 0,
            y: reduceMotion ? 2 : (pulse > 1.0 ? 8 : 3)
        )
        .onAppear {
            if rotatingMetrics.isEmpty {
                rotatingMetrics = randomMetrics(count: currentCount)
            }

            guard !reduceMotion else { return }
            withAnimation(.easeInOut(duration: 1.8).repeatForever(autoreverses: true)) {
                pulse = 1.02
            }

            cycleTask?.cancel()
            cycleTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_150_000_000)
                    guard !Task.isCancelled else { break }

                    if currentCount >= 7 {
                        countDirection = -1
                    } else if currentCount <= 3 {
                        countDirection = 1
                    }
                    currentCount += countDirection

                    withAnimation(.spring(response: 0.52, dampingFraction: 0.85)) {
                        rotatingMetrics = randomMetrics(count: currentCount)
                    }
                }
            }
        }
        .onDisappear {
            cycleTask?.cancel()
            cycleTask = nil
        }
    }
}

struct IdentityVisionPlaceholderView: View {
    let reduceMotion: Bool
    let showsShadow: Bool
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

    init(reduceMotion: Bool, showsShadow: Bool = true) {
        self.reduceMotion = reduceMotion
        self.showsShadow = showsShadow
    }

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
        .shadow(
            color: showsShadow ? Color.black.opacity(reduceMotion ? 0.08 : (pulse ? 0.20 : 0.10)) : .clear,
            radius: reduceMotion ? 4 : (pulse ? 14 : 6),
            x: 0,
            y: reduceMotion ? 2 : (pulse ? 7 : 3)
        )
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
    @State private var iconIndex: Int = 0
    @State private var itemOrder: [Int] = [0, 1, 2]
    @State private var rotateTask: Task<Void, Never>?

    private let rotatingSortIcons: [String] = [
        "star.square",
        "clock",
        "person",
        "wrench.and.screwdriver",
        "mappin.and.ellipse",
        "paperclip",
        "ellipsis.calendar"
    ]

    private let rowColors: [Color] = [
        .blue,
        .orange,
        .red
    ]

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(Color(.secondarySystemBackground))

            VStack(spacing: 10) {
                HStack {
                    Circle()
                        .fill(rowColors[itemOrder.first ?? 0])
                        .frame(width: 9, height: 9)
                    Text("Week")
                        .font(.headline)
                    Image(systemName: rotatingSortIcons[iconIndex % rotatingSortIcons.count])
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                ForEach(itemOrder, id: \.self) { item in
                    RoundedRectangle(cornerRadius: 10)
                        .fill(rowColors[item].opacity(0.18))
                        .frame(height: 34)
                        .overlay(alignment: .leading) {
                            HStack(spacing: 10) {
                                RoundedRectangle(cornerRadius: 6)
                                    .fill(rowColors[item].opacity(0.78))
                                    .frame(width: reveal ? CGFloat(85 + item * 35) : 36, height: 10)
                                    .animation(reduceMotion ? nil : .easeInOut(duration: 0.8), value: reveal)
                            }
                            .padding(.leading, 10)
                            .padding(.trailing, 8)
                        }
                }

                Spacer(minLength: 0)
            }
            .padding(18)
        }
        .onAppear {
            reveal = true
            guard !reduceMotion else { return }

            rotateTask?.cancel()
            rotateTask = Task { @MainActor in
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 1_050_000_000)
                    guard !Task.isCancelled else { break }

                    withAnimation(.easeInOut(duration: 0.35)) {
                        iconIndex = (iconIndex + 1) % rotatingSortIcons.count
                            itemOrder.shuffle()
                    }
                }
            }
        }
        .onDisappear {
            rotateTask?.cancel()
            rotateTask = nil
        }
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
