import SwiftUI

struct AppleHealthIntegrationTipPreviewScene: View {
    private let contentColumnWidth: CGFloat = 350

    let step: Int
    let isAnimated: Bool

    @State private var shouldCollapseIntoCalendar = false
    @State private var collapseTask: Task<Void, Never>?
    @State private var goalLineProgress: CGFloat = 0
    @State private var goalLineTask: Task<Void, Never>?
    @State private var loadingSpinnerRotation: Double = 0

    private var normalizedStep: Int {
        step % 5
    }

    private var completedCount: Int {
        switch normalizedStep {
        case 0: return 0
        case 1: return 1
        case 2: return 2
        default: return 3
        }
    }

    private var isCollapsedIntoCalendar: Bool {
        normalizedStep == 3 && shouldCollapseIntoCalendar
    }

    private var showsGoalsScreen: Bool {
        normalizedStep == 4
    }

    private var healthCard: AppleHealthTipCardModel {
        let title = "Health & Energy"
        let titleColor = FulfillmentCategoryTheme.color(for: title)
        let cardColor = FulfillmentCategoryTheme.lightColor(for: title)
        let items = [
            "15 min walk",
            "30 min workout",
            "10,000 steps"
        ]

        let wins = items.enumerated().map { index, item in
            AppleHealthTipWin(
                id: UUID(),
                title: item,
                isCompleted: index < completedCount
            )
        }

        return AppleHealthTipCardModel(
            title: title,
            cardColor: cardColor,
            titleColor: titleColor,
            wins: wins
        )
    }

    private var calendarStyles: [[AppleHealthTipMiniCardStyle]] {
        var styles = Array(repeating: [AppleHealthTipMiniCardStyle](), count: 7)
        if isCollapsedIntoCalendar {
            styles[6] = [
                AppleHealthTipMiniCardStyle(
                    fillColor: healthCard.cardColor,
                    strokeColor: healthCard.titleColor
                )
            ]
        }
        return styles
    }

    var body: some View {
        TipPreviewSurface {
            GeometryReader { proxy in
                let availableWidth = max(1, proxy.size.width)
                let availableHeight = max(1, proxy.size.height)
                let referenceSize = CGSize(width: 390, height: 844)
                let scale = min(availableWidth / referenceSize.width, availableHeight / referenceSize.height)
                let scaledWidth = referenceSize.width * scale
                let scaledHeight = referenceSize.height * scale

                ZStack(alignment: .topLeading) {
                    littleWinsHealthLayout
                        .opacity(showsGoalsScreen ? 0 : 1)

                    goalsOutcomeLayout
                        .opacity(showsGoalsScreen ? 1 : 0)
                }
                .frame(width: referenceSize.width, height: referenceSize.height)
                .scaleEffect(scale, anchor: .topLeading)
                .frame(width: scaledWidth, height: scaledHeight, alignment: .topLeading)
                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                .animation(isAnimated ? .easeInOut(duration: 0.32) : nil, value: showsGoalsScreen)
            }
        }
        .onAppear {
            scheduleCollapseTransition(for: normalizedStep)
            scheduleGoalLineAnimation(for: normalizedStep)
            if isAnimated {
                withAnimation(.linear(duration: 1.0).repeatForever(autoreverses: false)) {
                    loadingSpinnerRotation = 360
                }
            } else {
                loadingSpinnerRotation = 0
            }
        }
        .onChange(of: normalizedStep) { _, newValue in
            scheduleCollapseTransition(for: newValue)
            scheduleGoalLineAnimation(for: newValue)
        }
        .onDisappear {
            collapseTask?.cancel()
            collapseTask = nil
            goalLineTask?.cancel()
            goalLineTask = nil
        }
    }

    private var littleWinsHealthLayout: some View {
        VStack(alignment: .leading, spacing: 8) {
            animatedHealthCard
                .frame(width: contentColumnWidth, height: contentColumnWidth * 1.42)
                .opacity(0.5)
                .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 0)

            calendarMiniStackBoard
        }
        .padding(EdgeInsets(top: 116, leading: 20, bottom: 96, trailing: 20))
    }

    private var animatedHealthCard: some View {
        let collapseScale: CGFloat = isCollapsedIntoCalendar ? 0.083 : 1
        let collapseX: CGFloat = isCollapsedIntoCalendar ? 146 : 0
        let collapseY: CGFloat = isCollapsedIntoCalendar ? 262 : 0

        return healthCardView(healthCard)
            .scaleEffect(collapseScale, anchor: .center)
            .offset(x: collapseX, y: collapseY)
            .opacity(isCollapsedIntoCalendar ? 0 : 1)
            .animation(isAnimated ? .easeInOut(duration: 0.42) : nil, value: normalizedStep)
            .animation(isAnimated ? .easeInOut(duration: 0.42) : nil, value: shouldCollapseIntoCalendar)
    }

    private func scheduleCollapseTransition(for stepValue: Int) {
        collapseTask?.cancel()
        collapseTask = nil

        guard stepValue == 3 else {
            shouldCollapseIntoCalendar = false
            return
        }

        shouldCollapseIntoCalendar = false

        guard isAnimated else {
            shouldCollapseIntoCalendar = true
            return
        }

        collapseTask = Task {
            try? await Task.sleep(nanoseconds: 340_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 0.42)) {
                    shouldCollapseIntoCalendar = true
                }
            }
        }
    }

    private func scheduleGoalLineAnimation(for stepValue: Int) {
        goalLineTask?.cancel()
        goalLineTask = nil

        guard stepValue == 4 else {
            goalLineProgress = 0
            return
        }

        goalLineProgress = 0

        guard isAnimated else {
            goalLineProgress = 1
            return
        }

        goalLineTask = Task {
            try? await Task.sleep(nanoseconds: 120_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                withAnimation(.easeInOut(duration: 3.15)) {
                    goalLineProgress = 1
                }
            }
        }
    }

    private var goalsOutcomeLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Goals")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(maxWidth: .infinity, alignment: .center)

            goalsSummaryCard

            goalsChartCard

            Spacer(minLength: 0)
        }
        .padding(EdgeInsets(top: 118, leading: 20, bottom: 90, trailing: 20))
    }

    private var goalsSummaryCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Lose 10lbs")
                .font(.headline.weight(.semibold))
                .foregroundStyle(FulfillmentCategoryTheme.color(for: "Health & Energy"))
                .lineLimit(1)

            Text("Feel and look good!")
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)

            HStack(spacing: 8) {
                VStack(spacing: 2) {
                    Text("45")
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.primary)
                    Text("days left")
                        .font(.caption2)
                        .foregroundStyle(.primary)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(FulfillmentCategoryTheme.lightColor(for: "Health & Energy"))
                )
                .frame(height: 44)

                goalsMeasurePlaceholderBox
                    .frame(height: 44)

                goalsProgressRing
                    .frame(width: 40, height: 40)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private var goalsMeasurePlaceholderBox: some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text("X/X")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("updated")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .frame(width: 1)

            VStack(spacing: 2) {
                Text("X/X")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(.primary)
                Text("X/X goal")
                    .font(.caption2)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(.vertical, 6)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color(.systemGray5))
        )
    }

    private var goalsProgressRing: some View {
        ZStack {
            Circle()
                .stroke(Color(.systemGray3), lineWidth: 4)

            Circle()
                .trim(from: 0, to: goalLineProgress)
                .stroke(Color.black, lineWidth: 4)
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)
        }
    }

    private var goalsChartCard: some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let plot = CGRect(
                x: 16,
                y: 12,
                width: width - 32,
                height: height - 24
            )
            let goalY = plot.minY + (plot.height * 0.72)
            let startX = plot.minX + (plot.width * 0.08)
            let endX = plot.minX + (plot.width * 0.88)

            let animatedPoints = [
                CGPoint(x: startX, y: plot.minY + (plot.height * 0.24)),
                CGPoint(x: plot.minX + (plot.width * 0.24), y: plot.minY + (plot.height * 0.34)),
                CGPoint(x: plot.minX + (plot.width * 0.43), y: plot.minY + (plot.height * 0.28)),
                CGPoint(x: plot.minX + (plot.width * 0.62), y: plot.minY + (plot.height * 0.40)),
                CGPoint(x: plot.minX + (plot.width * 0.76), y: plot.minY + (plot.height * 0.53)),
                CGPoint(x: endX, y: goalY)
            ]
            let marker = pointAlongPolyline(points: animatedPoints, progress: goalLineProgress)

            ZStack(alignment: .topLeading) {
                Path { path in
                    path.move(to: CGPoint(x: plot.minX, y: goalY))
                    path.addLine(to: CGPoint(x: plot.maxX, y: goalY))
                }
                .stroke(Color.gray.opacity(0.75), style: StrokeStyle(lineWidth: 2, dash: [6, 4]))

                Path { path in
                    path.move(to: CGPoint(x: startX, y: plot.minY))
                    path.addLine(to: CGPoint(x: startX, y: plot.maxY))
                }
                .stroke(Color.green.opacity(0.95), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

                Path { path in
                    path.move(to: CGPoint(x: endX, y: plot.minY))
                    path.addLine(to: CGPoint(x: endX, y: plot.maxY))
                }
                .stroke(Color.orange.opacity(0.95), style: StrokeStyle(lineWidth: 2, dash: [5, 5]))

                pathForPolyline(points: animatedPoints, progress: goalLineProgress)
                    .stroke(Color.blue, style: StrokeStyle(lineWidth: 2.6, lineCap: .round, lineJoin: .round))

                ZStack {
                    Circle()
                        .fill(Color(.systemBackground))
                        .frame(width: 11, height: 11)
                    Circle()
                        .stroke(Color.blue, lineWidth: 2)
                        .frame(width: 11, height: 11)
                }
                .position(marker)
            }
            .frame(width: width, height: height)
        }
        .frame(width: 351, height: 152)
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.systemBackground).opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
    }

    private func pathForPolyline(points: [CGPoint], progress: CGFloat) -> Path {
        let clamped = max(0, min(1, progress))
        guard points.count > 1 else { return Path() }
        guard clamped > 0 else {
            var path = Path()
            path.move(to: points[0])
            return path
        }

        let segmentLengths = zip(points.dropFirst(), points.dropLast()).map { pair in
            hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
        }
        let totalLength = segmentLengths.reduce(0, +)
        guard totalLength > 0 else {
            var path = Path()
            path.move(to: points[0])
            return path
        }

        let targetLength = totalLength * clamped
        var consumed: CGFloat = 0

        var path = Path()
        path.move(to: points[0])

        for index in 0..<segmentLengths.count {
            let from = points[index]
            let to = points[index + 1]
            let segmentLength = segmentLengths[index]

            if consumed + segmentLength <= targetLength {
                path.addLine(to: to)
                consumed += segmentLength
                continue
            }

            let remaining = max(0, targetLength - consumed)
            let t = segmentLength > 0 ? (remaining / segmentLength) : 0
            let interpolated = CGPoint(
                x: from.x + ((to.x - from.x) * t),
                y: from.y + ((to.y - from.y) * t)
            )
            path.addLine(to: interpolated)
            break
        }

        return path
    }

    private func pointAlongPolyline(points: [CGPoint], progress: CGFloat) -> CGPoint {
        let clamped = max(0, min(1, progress))
        guard points.count > 1 else { return .zero }
        guard clamped > 0 else { return points[0] }
        guard clamped < 1 else { return points[points.count - 1] }

        let segmentLengths = zip(points.dropFirst(), points.dropLast()).map { pair in
            hypot(pair.0.x - pair.1.x, pair.0.y - pair.1.y)
        }
        let totalLength = segmentLengths.reduce(0, +)
        guard totalLength > 0 else { return points[0] }

        let targetLength = totalLength * clamped
        var consumed: CGFloat = 0

        for index in 0..<segmentLengths.count {
            let from = points[index]
            let to = points[index + 1]
            let segmentLength = segmentLengths[index]
            if consumed + segmentLength < targetLength {
                consumed += segmentLength
                continue
            }

            let remaining = max(0, targetLength - consumed)
            let t = segmentLength > 0 ? (remaining / segmentLength) : 0
            return CGPoint(
                x: from.x + ((to.x - from.x) * t),
                y: from.y + ((to.y - from.y) * t)
            )
        }

        return points[points.count - 1]
    }

    private func templateTitle(_ text: String) -> some View {
        let badgeHeight: CGFloat = 32

        return HStack(spacing: 8) {
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: badgeHeight)

            Text(text)
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .padding(.horizontal, 12)
                .frame(minHeight: badgeHeight)
                .background(
                    Capsule(style: .continuous)
                        .fill(Color.black.opacity(0.40))
                )
                .overlay(
                    Capsule(style: .continuous)
                        .stroke(Color.white.opacity(0.22), lineWidth: 1)
                )
        }
    }

    private var calendarMiniStackBoard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(completedDays.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 3) {
                        miniCardStack(styles: day.styles)
                            .frame(width: 28, height: 42, alignment: .top)

                        Text(day.weekday)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.82))

                        Text(day.dayNumber)
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(.white.opacity(0.74))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                }
            }
            .padding(.horizontal, 6)
            .padding(.vertical, 8)
        }
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private var completedDays: [(weekday: String, dayNumber: String, styles: [AppleHealthTipMiniCardStyle])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return calendarStyles.enumerated().compactMap { index, styles in
            guard let date = calendar.date(byAdding: .day, value: -(6 - index), to: today) else { return nil }
            return (
                weekday: date.formatted(.dateTime.weekday(.narrow)),
                dayNumber: date.formatted(.dateTime.day()),
                styles: styles
            )
        }
    }

    private func miniCardStack(styles: [AppleHealthTipMiniCardStyle]) -> some View {
        let visibleStyles = Array(styles.suffix(7))
        let stackLiftPerCard: CGFloat = 5

        return ZStack {
            if visibleStyles.isEmpty {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(width: 28, height: 40)
                    .overlay {
                        Text("-")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(Color(.systemGray2))
                    }
            } else {
                ForEach(Array(visibleStyles.enumerated()), id: \.offset) { index, style in
                    let depth = CGFloat(visibleStyles.count - 1 - index)
                    miniCard(style: style)
                        .offset(y: -(depth * stackLiftPerCard))
                        .zIndex(Double(index))
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func miniCard(style: AppleHealthTipMiniCardStyle) -> some View {
        RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(style.fillColor)
            .frame(width: 28, height: 40)
            .overlay {
                AppleHealthTipRadarPolygonOutline(sides: 6)
                    .stroke(style.strokeColor.opacity(0.85), lineWidth: 1.6)
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            }
    }

    private func healthCardView(_ card: AppleHealthTipCardModel) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let baseWidth: CGFloat = 300
            let baseHeight: CGFloat = baseWidth * 1.42
            let scale = min(width / baseWidth, height / baseHeight)
            let fixedPrimaryText = Color.black.opacity(0.82)
            let fixedSecondaryText = Color.black.opacity(0.56)
            let titleFontSize = max(12, 17 * scale)
            let rowFontSize = max(11, 36 * scale)
            let rowIconSize = max(10, 26 * scale)
            let rowIconFrameWidth = max(14, 30 * scale)
            let titleHorizontalPadding = max(10, 18 * scale)
            let titleTopPadding = max(6, 10 * scale)
            let titleBottomPadding = max(8, 18 * scale)
            let rowHorizontalPadding = max(14, 38 * scale)
            let rowVerticalPadding = max(6, 14 * scale)
            let footerTopPadding = max(6, 10 * scale)
            let footerBottomPadding = max(8, 14 * scale)
            let footerFontSize = max(11, 17 * scale)
            let rowSpacing = max(4, 10 * scale)
            let rowIconTopPadding = max(1, 6 * scale)
            let largeRowIconSize = rowIconSize * 2
            let largeRowIconFrameWidth = rowIconFrameWidth * 2

            VStack(spacing: 0) {
                Text(card.title)
                    .font(.system(size: titleFontSize, weight: .semibold))
                    .foregroundStyle(card.titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                    .padding(.horizontal, titleHorizontalPadding)
                    .padding(.top, titleTopPadding)
                    .padding(.bottom, titleBottomPadding)

                GeometryReader { middleGeo in
                    VStack {
                        Spacer(minLength: 0)

                        VStack(alignment: .leading, spacing: rowSpacing) {
                            ForEach(card.wins.prefix(4)) { win in
                                HStack(alignment: .top, spacing: 8) {
                                    completionIcon(
                                        isCompleted: win.isCompleted,
                                        titleColor: card.titleColor,
                                        idleColor: fixedSecondaryText,
                                        size: largeRowIconSize
                                    )
                                    .frame(width: largeRowIconFrameWidth, alignment: .center)
                                    .padding(.top, rowIconTopPadding)

                                    Text(win.title)
                                        .font(.system(size: rowFontSize, weight: .semibold))
                                        .foregroundStyle(fixedPrimaryText)
                                        .multilineTextAlignment(.leading)
                                        .lineLimit(2)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .strikethrough(win.isCompleted, color: fixedPrimaryText.opacity(0.7))
                                        .opacity(win.isCompleted ? 0.72 : 1)
                                }
                            }
                        }

                        Spacer(minLength: 0)
                    }
                    .padding(.horizontal, rowHorizontalPadding)
                    .padding(.vertical, rowVerticalPadding)
                    .frame(maxWidth: .infinity, minHeight: middleGeo.size.height, alignment: .center)
                    .clipped()
                }

                Spacer(minLength: 0)

                HStack {
                    Spacer()
                    Text("Little Wins")
                        .font(.system(size: footerFontSize, weight: .semibold))
                        .foregroundStyle(fixedPrimaryText)
                    Spacer()
                }
                .padding(.horizontal, titleHorizontalPadding)
                .padding(.top, footerTopPadding)
                .padding(.bottom, footerBottomPadding)
            }
            .frame(width: width, height: height, alignment: .top)
            .background {
                healthCardBackground(
                    cardColor: card.cardColor,
                    titleColor: card.titleColor,
                    patternText: card.title,
                    width: width,
                    height: height,
                    scale: scale
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        }
    }

    private func completionIcon(
        isCompleted: Bool,
        titleColor: Color,
        idleColor: Color,
        size: CGFloat
    ) -> some View {
        let ringLineWidth = max(1.3, size * 0.11)
        let innerInset = ringLineWidth * 1.1

        return ZStack {
            Circle()
                .stroke(idleColor.opacity(0.82), lineWidth: ringLineWidth)

            Circle()
                .trim(from: 0, to: isCompleted ? 1 : 0)
                .stroke(titleColor, style: StrokeStyle(lineWidth: ringLineWidth, lineCap: .butt))
                .rotationEffect(.degrees(-90))
                .scaleEffect(x: -1, y: 1)

            if isCompleted {
                Circle()
                    .fill(titleColor)
                    .padding(innerInset)

                Image(systemName: "checkmark")
                    .font(.system(size: size * 0.48, weight: .bold))
                    .foregroundStyle(.white)
            } else {
                ZStack {
                    Circle()
                        .trim(from: 0.08, to: 0.88)
                        .stroke(
                            titleColor.opacity(0.92),
                            style: StrokeStyle(
                                lineWidth: ringLineWidth,
                                lineCap: .round
                            )
                        )
                        .rotationEffect(.degrees(loadingSpinnerRotation - 90))

                    Image(systemName: "paperclip")
                        .font(.system(size: size * 0.36, weight: .semibold))
                        .foregroundStyle(idleColor.opacity(0.95))
                }
            }
        }
        .frame(width: size, height: size)
        .animation(isAnimated ? .easeInOut(duration: 0.55) : nil, value: isCompleted)
    }

    private func healthCardBackground(
        cardColor: Color,
        titleColor: Color,
        patternText: String,
        width: CGFloat,
        height: CGFloat,
        scale: CGFloat
    ) -> some View {
        let cornerShapeSize: CGFloat = max(20, 52 * scale)
        let cornerShapePadding: CGFloat = max(6, 14 * scale)
        let topTitleCutoutWidth = max(0, min(max(width * 0.62, 200), width - 86))
        let bottomTitleCutoutWidth = max(0, min(max(width * 0.32, 120), 180))
        let largeInsetLineWidth = max(1.2, 4 * scale)
        let shapeLineWidth = max(1.8, 6 * scale)

        return RoundedRectangle(cornerRadius: 18, style: .continuous)
            .fill(cardColor)
            .overlay {
                healthCardTextPatternBackground(
                    categoryTitle: patternText,
                    color: titleColor,
                    width: width,
                    height: height
                )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.12),
                                Color.clear,
                                Color.black.opacity(0.02)
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            }
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.white.opacity(0.28), lineWidth: 1)
            }
            .overlay {
                insetGuideLine(
                    inset: 18,
                    cornerRadius: 28,
                    strokeColor: titleColor.opacity(0.22),
                    lineWidth: largeInsetLineWidth,
                    width: width,
                    height: height,
                    topLeadingShapeCutout: .init(width: 112, height: 112),
                    bottomTrailingShapeCutout: .init(width: 112, height: 112),
                    shapePadding: cornerShapePadding,
                    shapeSize: cornerShapeSize,
                    topCutoutWidth: topTitleCutoutWidth,
                    bottomCutoutWidth: bottomTitleCutoutWidth
                )
            }
            .overlay(alignment: .topLeading) {
                AppleHealthTipRadarPolygonOutline(sides: 6)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: shapeLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.leading, cornerShapePadding)
                    .padding(.top, cornerShapePadding)
                    .opacity(0.9)
            }
            .overlay(alignment: .bottomTrailing) {
                AppleHealthTipRadarPolygonOutline(sides: 6)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: shapeLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.trailing, cornerShapePadding)
                    .padding(.bottom, cornerShapePadding)
                    .opacity(0.9)
            }
    }

    private func insetGuideLine(
        inset: CGFloat,
        cornerRadius: CGFloat,
        strokeColor: Color,
        lineWidth: CGFloat,
        width: CGFloat,
        height: CGFloat,
        topLeadingShapeCutout: CGSize = .zero,
        bottomTrailingShapeCutout: CGSize = .zero,
        shapePadding: CGFloat = 14,
        shapeSize: CGFloat = 52,
        topCutoutWidth: CGFloat? = nil,
        bottomCutoutWidth: CGFloat? = nil
    ) -> some View {
        let safeWidth = width.isFinite ? max(width, 0) : 0
        let safeHeight = height.isFinite ? max(height, 0) : 0
        let sanitizeDimension: (CGFloat) -> CGFloat = { value in
            guard value.isFinite else { return 0 }
            return max(value, 0)
        }

        let defaultTopCutoutWidth = min(max(safeWidth * 0.34, 120), 190)
        let defaultBottomCutoutWidth = min(
            max(safeWidth * 0.56, 180),
            safeWidth - (inset * 2) - 20
        )
        let topCutoutWidth = sanitizeDimension(topCutoutWidth ?? defaultTopCutoutWidth)
        let bottomCutoutWidth = sanitizeDimension(bottomCutoutWidth ?? defaultBottomCutoutWidth)
        let topY = inset
        let bottomY = safeHeight - inset
        let topLeadingCutoutCenter = CGPoint(
            x: shapePadding + (shapeSize / 2),
            y: shapePadding + (shapeSize / 2)
        )
        let bottomTrailingCutoutCenter = CGPoint(
            x: safeWidth - shapePadding - (shapeSize / 2),
            y: safeHeight - shapePadding - (shapeSize / 2)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: inset)
                .stroke(strokeColor, lineWidth: lineWidth)

            Rectangle()
                .fill(Color.black)
                .frame(width: topCutoutWidth, height: lineWidth + 10)
                .position(x: safeWidth / 2, y: topY)

            Rectangle()
                .fill(Color.black)
                .frame(width: bottomCutoutWidth, height: lineWidth + 10)
                .position(x: safeWidth / 2, y: bottomY)
        }
        .compositingGroup()
        .blendMode(.normal)
        .mask(
            Rectangle()
                .overlay {
                    Rectangle().fill(Color(.systemBackground))
                    Rectangle()
                        .frame(width: topCutoutWidth, height: lineWidth + 12)
                        .position(x: safeWidth / 2, y: topY)
                        .blendMode(.destinationOut)
                    Rectangle()
                        .frame(width: bottomCutoutWidth, height: lineWidth + 12)
                        .position(x: safeWidth / 2, y: bottomY)
                        .blendMode(.destinationOut)
                    if topLeadingShapeCutout != .zero {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .frame(width: topLeadingShapeCutout.width, height: topLeadingShapeCutout.height)
                            .position(topLeadingCutoutCenter)
                            .blendMode(.destinationOut)
                    }
                    if bottomTrailingShapeCutout != .zero {
                        RoundedRectangle(cornerRadius: 16, style: .continuous)
                            .frame(width: bottomTrailingShapeCutout.width, height: bottomTrailingShapeCutout.height)
                            .position(bottomTrailingCutoutCenter)
                            .blendMode(.destinationOut)
                    }
                }
                .compositingGroup()
        )
    }

    private func healthCardTextPatternBackground(
        categoryTitle: String,
        color: Color,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let textSize: CGFloat = 8.5
        let rowHeight: CGFloat = 9
        let rowCount = max(1, Int(ceil(height / rowHeight)) + 2)
        let repeatedLine = String(repeating: categoryTitle + " ", count: max(8, Int(width / 28)))

        return VStack(alignment: .leading, spacing: 0) {
            ForEach(0..<rowCount, id: \.self) { row in
                Text(repeatedLine)
                    .font(.system(size: textSize, weight: .semibold, design: .rounded))
                    .foregroundStyle(color.opacity(row.isMultiple(of: 2) ? 0.1 : 0.2))
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }
}

private struct AppleHealthTipCardModel {
    let title: String
    let cardColor: Color
    let titleColor: Color
    let wins: [AppleHealthTipWin]
}

private struct AppleHealthTipWin: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

private struct AppleHealthTipMiniCardStyle {
    let fillColor: Color
    let strokeColor: Color
}

private struct AppleHealthTipRadarPolygonOutline: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let sideCount = max(3, sides)
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2

        var path = Path()
        for index in 0..<sideCount {
            let angle = (Double(index) / Double(sideCount)) * (Double.pi * 2) - (Double.pi / 2)
            let point = CGPoint(
                x: center.x + CGFloat(cos(angle)) * radius,
                y: center.y + CGFloat(sin(angle)) * radius
            )
            if index == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}
