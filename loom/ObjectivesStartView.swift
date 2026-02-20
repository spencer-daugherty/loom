import SwiftUI

struct ObjectivesStartView: View {
    @State private var navigateToObjectives = false

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 14) {
                header
                introCard
                Spacer(minLength: 0)
            }
            .padding(.horizontal)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .safeAreaInset(edge: .bottom) {
            VStack(spacing: 6) {
                Button {
                    navigateToObjectives = true
                } label: {
                    Text("Create Outcome")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity)
            }
            .padding(.horizontal)
            .padding(.top, 8)
            .padding(.bottom, 10)
            .background(Color(.systemGroupedBackground))
        }
        .navigationTitle("")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(isPresented: $navigateToObjectives) {
            ObjectivesView(autoOpenAddOutcome: true)
        }
    }

    private var header: some View {
        VStack(spacing: 1) {
            ZStack {
                ObjectivesIntroRouteLinesView()
                    .padding(.horizontal, -24)
                    .allowsHitTesting(false)
                Image("ObjectivesLineGraphic")
                    .resizable()
                    .scaledToFit()
                    .frame(maxWidth: .infinity)
                    .frame(height: 420)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            }
            .frame(height: 420)
            .padding(.bottom, 2)

            HStack(spacing: 6) {
                Image(systemName: "clock.fill")
                    .font(.caption)
                Text("~2 minutes per outcome")
                    .font(.caption.weight(.bold))
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
            .frame(maxWidth: .infinity, alignment: .center)

            Text("Set Outcomes")
                .font(.largeTitle)
                .fontWeight(.bold)
                .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    private var introCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Define the long-term results you want to create.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("These are clear, measurable targets that move your categories forward and turn vision into reality.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
            Text("They give direction to your time, energy, and actions so you focus on what matters most.")
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }
}

private struct ObjectivesIntroRouteLinesView: View {
    private let lineCount: Int = 10
    @State private var animationStartDate: Date = .now

    private let colors: [Color] = [.blue, .green, .orange, .pink, .teal, .red]

    private func rand(_ seed: Int, _ a: Double, _ b: Double) -> Double {
        let seedD = Double(seed)
        let x = sin(seedD * 12.9898) * 43758.5453
        let u = x - floor(x)
        return a + (b - a) * u
    }

    private func smoothstep(_ a: CGFloat, _ b: CGFloat, _ x: CGFloat) -> CGFloat {
        let t = min(max((x - a) / (b - a), 0), 1)
        return t * t * (3 - 2 * t)
    }

    private func smoothstepD(_ a: Double, _ b: Double, _ x: Double) -> Double {
        let tt = min(max((x - a) / (b - a), 0), 1)
        return tt * tt * (3 - 2 * tt)
    }

    private func routedPoint(s: CGFloat, size: CGSize, laneOffset: CGFloat) -> CGPoint {
        let startBandCenter = min(size.height * 0.58, 334)
        let endBandCenter = max(size.height * 0.22, 74)
        let endBandHalfSpan: CGFloat = 4.488
        let normalizedLane = max(-1.0, min(1.0, laneOffset / 70.0))
        let startY = startBandCenter + normalizedLane * (endBandHalfSpan * 4.68)
        let endYOffset: CGFloat = -size.height * 0.01
        let endY = endBandCenter + normalizedLane * endBandHalfSpan + endYOffset
        let start = CGPoint(x: -28 + laneOffset * 0.35, y: startY)
        let midY = (startY + endY) * 0.5 - size.height * 0.08 - normalizedLane * (endBandHalfSpan * 0.35)
        let turn = CGPoint(x: size.width * 0.40 + laneOffset * 0.05, y: midY)
        let end = CGPoint(x: size.width * 0.72, y: endY)

        let split: CGFloat = 0.55
        if s <= split {
            let u = s / split
            let curveU = pow(u, 0.88)
            let x = start.x + (turn.x - start.x) * pow(curveU, 2.8)
            let y = start.y + (turn.y - start.y) * smoothstep(0, 1, curveU)
            return CGPoint(x: x, y: y)
        } else {
            let u = (s - split) / (1 - split)
            let curveU = smoothstep(0, 1, u)
            let x = turn.x + (end.x - turn.x) * curveU
            let y = turn.y + (end.y - turn.y) * smoothstep(0, 1, u)
            return CGPoint(x: x, y: y)
        }
    }

    var body: some View {
        TimelineView(.animation) { context in
            Canvas { ctx, size in
                let t = context.date.timeIntervalSinceReferenceDate
                let startupElapsed = context.date.timeIntervalSince(animationStartDate)

                for i in 0..<lineCount {
                    let color = colors[i % colors.count]
                    let laneFrac = (Double(i) + 0.5) / Double(lineCount)
                    let laneOffset = CGFloat((laneFrac - 0.5) * 140.0)

                    let lineDelay = rand(i * 83 + 17, 0.00, 0.36)
                    let lineRevealDuration = rand(i * 89 + 23, 0.62, 1.05)
                    let rawReveal = (startupElapsed - lineDelay) / lineRevealDuration
                    let revealProgress = max(0.0, min(rawReveal, 1.0))
                    if revealProgress <= 0.0 { continue }

                    let speed = rand(i * 13 + 1, 0.15, 0.35)
                    let phase = rand(i * 17 + 3, 0.0, 1.0)
                    let posFrac = (t * speed + phase).truncatingRemainder(dividingBy: 1)

                    let amp = rand(i * 23 + 5, 10.0, 40.0)
                    let freq = rand(i * 29 + 9, 2.0, 6.0)
                    let sigma = rand(i * 31 + 11, 0.08, 0.16)
                    let wobblePhase = rand(i * 37 + 13, 0.0, 2 * .pi)
                    let chop1 = rand(i * 41 + 101, 6.0, 12.0)
                    let chop2 = rand(i * 47 + 103, 12.0, 22.0)
                    let chopPhase1 = rand(i * 53 + 107, 0.0, 2 * .pi)
                    let chopPhase2 = rand(i * 59 + 109, 0.0, 2 * .pi)
                    let timeScale: Double = 0.8 + rand(i * 61 + 113, 0.0, 0.8)
                    let oceanTime: Double = t * timeScale

                    var path = Path()
                    let samples = 96
                    let twoPi = 2.0 * Double.pi

                    for j in 0...samples {
                        let localS = Double(j) / Double(samples)
                        let s = localS * revealProgress
                        let sCG = CGFloat(s)
                        var p = routedPoint(s: sCG, size: size, laneOffset: laneOffset)

                        let diff = (s - posFrac) / sigma
                        let envelope = exp(-pow(diff, 2) * 2)
                        let pulseArg = twoPi * (s * freq - oceanTime * speed * 0.6) + wobblePhase
                        let pulse = sin(pulseArg) * amp * envelope
                        let swellArg = twoPi * (s * (freq * 0.45) + oceanTime * speed * 0.25) + wobblePhase * 0.7
                        let swell = sin(swellArg) * (amp * 0.55)
                        let chopAArg = twoPi * (s * chop1 - oceanTime * speed * 1.2) + chopPhase1
                        let chopBArg = twoPi * (s * chop2 + oceanTime * speed * 1.7) + chopPhase2
                        let chop = sin(chopAArg) * (amp * 0.18) + sin(chopBArg) * (amp * 0.10)
                        let edge = sin(Double.pi * s)
                        let wiggle = (pulse + swell + chop) * edge * 0.5
                        p.y += CGFloat(wiggle)

                        if j == 0 { path.move(to: p) } else { path.addLine(to: p) }
                    }

                    let tailStartFrac: Double = 0.90
                    let baseOpacity: Double = 0.125
                    let tailGradient = Gradient(stops: [
                        .init(color: color.opacity(baseOpacity), location: 0.0),
                        .init(color: color.opacity(baseOpacity), location: tailStartFrac),
                        .init(color: color.opacity(baseOpacity * 0.75), location: min(tailStartFrac + 0.03, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.45), location: min(tailStartFrac + 0.06, 1.0)),
                        .init(color: color.opacity(baseOpacity * 0.22), location: min(tailStartFrac + 0.085, 1.0)),
                        .init(color: color.opacity(0.0), location: 1.0),
                    ])

                    let startPt = routedPoint(s: 0, size: size, laneOffset: laneOffset)
                    let endPt = routedPoint(s: CGFloat(revealProgress), size: size, laneOffset: laneOffset)

                    ctx.stroke(
                        path,
                        with: .linearGradient(tailGradient, startPoint: startPt, endPoint: endPt),
                        lineWidth: 10
                    )

                    let tailFactorAtGlow = 1.0 - smoothstepD(tailStartFrac, 1.0, posFrac)
                    let glowPeak = 0.45 * tailFactorAtGlow
                    let glowHalfWidth = sigma * 0.8
                    let startStop = max(0.0, posFrac - glowHalfWidth)
                    let endStop = min(1.0, posFrac + glowHalfWidth)
                    let gradient = Gradient(stops: [
                        .init(color: color.opacity(0.0), location: startStop),
                        .init(color: color.opacity(glowPeak), location: posFrac),
                        .init(color: color.opacity(0.0), location: endStop),
                    ])

                    let revealX = startPt.x + (endPt.x - startPt.x)
                    let clipRect = CGRect(x: min(startPt.x, revealX), y: 0, width: max(1, abs(revealX - startPt.x) + 120), height: size.height)

                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 7))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 12
                        )
                    }
                    ctx.drawLayer { layer in
                        layer.clip(to: Path(clipRect))
                        layer.addFilter(.blur(radius: 2))
                        layer.stroke(
                            path,
                            with: .linearGradient(gradient, startPoint: startPt, endPoint: endPt),
                            lineWidth: 6
                        )
                    }
                }
            }
        }
        .onAppear {
            animationStartDate = .now
        }
    }
}

#Preview {
    NavigationStack {
        ObjectivesStartView()
    }
}
