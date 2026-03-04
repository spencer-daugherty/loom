import SwiftUI

private enum DeviceFrameConstants {
    static let screenAspectRatio: CGFloat = 9.0 / 19.5
    static let screenSideInsetRatio: CGFloat = 0.015
    static let screenTopInsetRatio: CGFloat = 0.030
    static let screenBottomInsetRatio: CGFloat = 0.035

    static let deviceAspectRatio: CGFloat = {
        let heightPerWidth =
            ((1 - (screenSideInsetRatio * 2)) / screenAspectRatio) +
            screenTopInsetRatio +
            screenBottomInsetRatio
        return 1 / heightPerWidth
    }()
}

struct DeviceFrameView<Content: View>: View {
    static var screenAspectRatio: CGFloat { DeviceFrameConstants.screenAspectRatio }
    static var deviceAspectRatio: CGFloat { DeviceFrameConstants.deviceAspectRatio }

    private let content: (CGSize) -> Content

    init(@ViewBuilder content: @escaping (CGSize) -> Content) {
        self.content = content
    }

    var body: some View {
        GeometryReader { proxy in
            let metrics = FrameMetrics.fitting(in: proxy.size)
            let screenShape = RoundedRectangle(
                cornerRadius: metrics.screenCornerRadius,
                style: .continuous
            )

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: metrics.outerCornerRadius, style: .continuous)
                    .fill(Color.black.opacity(0.94))

                RoundedRectangle(cornerRadius: metrics.outerCornerRadius * 0.96, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: metrics.shellStrokeWidth)
                    .padding(metrics.shellStrokeWidth * 0.85)

                screenShape
                    .fill(Color(.systemBackground))
                    .frame(width: metrics.screenSize.width, height: metrics.screenSize.height)
                    .overlay {
                        content(metrics.screenSize)
                            .frame(
                                width: metrics.screenSize.width,
                                height: metrics.screenSize.height,
                                alignment: .topLeading
                            )
                            .clipShape(screenShape)
                    }
                    .overlay(alignment: .top) {
                        Capsule(style: .continuous)
                            .fill(Color.black.opacity(0.92))
                            .frame(
                                width: metrics.dynamicIslandSize.width,
                                height: metrics.dynamicIslandSize.height
                            )
                            .padding(.top, metrics.dynamicIslandTopInset)
                            .allowsHitTesting(false)
                    }
                    .offset(x: metrics.screenOrigin.x, y: metrics.screenOrigin.y)
            }
            .frame(width: metrics.deviceSize.width, height: metrics.deviceSize.height)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        }
        .aspectRatio(Self.deviceAspectRatio, contentMode: .fit)
    }

    private struct FrameMetrics {
        let deviceSize: CGSize
        let screenSize: CGSize
        let screenOrigin: CGPoint
        let outerCornerRadius: CGFloat
        let screenCornerRadius: CGFloat
        let dynamicIslandSize: CGSize
        let dynamicIslandTopInset: CGFloat
        let shellStrokeWidth: CGFloat

        static func fitting(in availableSize: CGSize) -> FrameMetrics {
            let availableWidth = max(1, availableSize.width)
            let availableHeight = max(1, availableSize.height)
            let deviceWidth = min(
                availableWidth,
                availableHeight * DeviceFrameConstants.deviceAspectRatio
            )
            let deviceHeight = deviceWidth / DeviceFrameConstants.deviceAspectRatio
            let screenWidth = deviceWidth * (1 - (DeviceFrameConstants.screenSideInsetRatio * 2))
            let screenHeight = screenWidth / DeviceFrameConstants.screenAspectRatio
            let screenOrigin = CGPoint(
                x: (deviceWidth - screenWidth) / 2,
                y: deviceWidth * DeviceFrameConstants.screenTopInsetRatio
            )
            let shellStrokeWidth = max(1, deviceWidth * 0.005)
            let outerCornerRadius = deviceWidth * 0.112
            let screenCornerRadius = screenWidth * 0.102

            return FrameMetrics(
                deviceSize: CGSize(width: deviceWidth, height: deviceHeight),
                screenSize: CGSize(width: screenWidth, height: screenHeight),
                screenOrigin: screenOrigin,
                outerCornerRadius: outerCornerRadius,
                screenCornerRadius: screenCornerRadius,
                dynamicIslandSize: CGSize(
                    width: screenWidth * 0.320,
                    height: screenWidth * 0.090
                ),
                dynamicIslandTopInset: screenWidth * 0.030,
                shellStrokeWidth: shellStrokeWidth
            )
        }
    }
}

struct TipPhonePreview: View {
    let feature: TipFeature
    var animate: Bool = true
    private static let previewDesignSize = CGSize(width: 240, height: 520)

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    @State private var step: Int = 0
    @State private var loopTask: Task<Void, Never>?

    var body: some View {
        DeviceFrameView { screenSize in
            let sceneScale = min(
                screenSize.width / Self.previewDesignSize.width,
                screenSize.height / Self.previewDesignSize.height
            )

            previewScene
                .frame(
                    width: Self.previewDesignSize.width,
                    height: Self.previewDesignSize.height,
                    alignment: .topLeading
                )
                .scaleEffect(sceneScale, anchor: .topLeading)
                .dynamicTypeSize(.xSmall ... .medium)
                .frame(
                    width: screenSize.width,
                    height: screenSize.height,
                    alignment: .topLeading
                )
        }
        .shadow(color: .black.opacity(0.18), radius: 14, x: 0, y: 8)
        .onAppear {
            startLoopIfNeeded()
        }
        .onDisappear {
            stopLoop()
        }
    }

    @ViewBuilder
    private var previewScene: some View {
        let shouldAnimateScene = animate && !reduceMotion && !feature.isComingSoon
        switch feature.previewType {
        case .littleWinsMoments:
            LittleWinsMomentsTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        case .loomAIPersonalization:
            LoomAIPersonalizationTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        case .appleHealthIntegration:
            AppleHealthIntegrationTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        case .assignActions:
            AssignActionsTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        case .loomAIChat:
            LoomAIChatTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        case .loomAIAutoWrite:
            LoomAIAutoWriteTipPreviewScene(step: step, isAnimated: shouldAnimateScene)
        }
    }

    private func startLoopIfNeeded() {
        stopLoop()
        step = 0

        guard animate,
              !reduceMotion,
              feature.previewStepCount > 1,
              !feature.isComingSoon else {
            return
        }

        loopTask = Task {
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 1_050_000_000)
                guard !Task.isCancelled else { break }
                await MainActor.run {
                    withAnimation(.easeInOut(duration: 0.42)) {
                        step = (step + 1) % feature.previewStepCount
                    }
                }
            }
        }
    }

    private func stopLoop() {
        loopTask?.cancel()
        loopTask = nil
    }
}

enum TipPreviewPalette {
    static let loomAI: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.98, green: 0.36, blue: 0.58)
    ]

    static let screenBackground = LinearGradient(
        colors: [
            Color(.secondarySystemBackground),
            Color(.systemBackground)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

struct TipPreviewSurface<Content: View>: View {
    @ViewBuilder var content: () -> Content

    var body: some View {
        ZStack(alignment: .topLeading) {
            content()
                .padding(14)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .background(Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}

struct TipPreviewLoomAIHeader: View {
    var progress: Double
    var isAnimated: Bool = true

    @State private var shimmerOffset: CGFloat = -0.8

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 14, height: 14)
                Text("LoomAI")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
            }

            GeometryReader { proxy in
                let width = max(1, proxy.size.width)
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.secondary.opacity(0.14))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: TipPreviewPalette.loomAI,
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * max(0, min(1, progress)))

                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.white.opacity(0.0),
                                    Color.white.opacity(0.45),
                                    Color.white.opacity(0.0)
                                ],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: width * 0.30)
                        .offset(x: width * shimmerOffset)
                }
            }
            .frame(height: 8)
        }
        .onAppear {
            guard isAnimated else {
                shimmerOffset = 0.06
                return
            }
            withAnimation(.linear(duration: 1.75).repeatForever(autoreverses: false)) {
                shimmerOffset = 1.2
            }
        }
    }
}

struct TipPreviewCard: View {
    var title: String? = nil
    var tint: Color = Color(.systemGray5)
    var outline: Color = Color.black.opacity(0.08)
    var lineWidths: [CGFloat] = [0.92, 0.72]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let title {
                Text(title)
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(lineWidths.enumerated()), id: \.offset) { _, ratio in
                    Capsule()
                        .fill(Color.primary.opacity(0.24))
                        .frame(maxWidth: .infinity, minHeight: 6, maxHeight: 6, alignment: .leading)
                        .scaleEffect(x: max(0.2, min(1.0, ratio)), y: 1, anchor: .leading)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(tint)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(outline, lineWidth: 1)
        )
    }
}

struct TipPreviewChip: View {
    var text: String
    var tint: Color

    var body: some View {
        Text(text)
            .font(.caption2.weight(.semibold))
            .foregroundStyle(tint)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(tint.opacity(0.16))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .stroke(tint.opacity(0.32), lineWidth: 1)
            )
    }
}

struct TipPreviewAnimatedOutline: View {
    var cornerRadius: CGFloat = 12
    @State private var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: TipPreviewPalette.loomAI + [TipPreviewPalette.loomAI[0]],
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: 1.1
            )
            .onAppear {
                guard angle == 0 else { return }
                withAnimation(.linear(duration: 6.2).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}
