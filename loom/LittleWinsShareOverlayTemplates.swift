import SwiftUI

enum LittleWinsShareTemplate: String, CaseIterable, Identifiable {
    case todaysWins
    case completedWins
    case weeklyCalendar
    case streak
    case hotStreak
    case fullSnapshot
    case fullHouse
    case royalFlush
    case foundingMember

    var id: String { rawValue }

    var title: String {
        switch self {
        case .todaysWins:
            return "Today's Little Wins"
        case .completedWins:
            return "Completed Wins"
        case .weeklyCalendar:
            return "Weekly Calendar"
        case .streak:
            return "Streak"
        case .hotStreak:
            return "Building hot streak"
        case .fullSnapshot:
            return "Full Snapshot"
        case .fullHouse:
            return "Full House"
        case .royalFlush:
            return "Royal Flush"
        case .foundingMember:
            return "Founding Member"
        }
    }

    var subtitle: String {
        switch self {
        case .todaysWins:
            return "Working cards"
        case .completedWins:
            return "Completed cards"
        case .weeklyCalendar:
            return "Mini card stacks"
        case .streak:
            return "Consistency view"
        case .hotStreak:
            return "Momentum mode"
        case .fullSnapshot:
            return "Cards + calendar"
        case .fullHouse:
            return "Unlock with all cards completed"
        case .royalFlush:
            return "Unlock with 7 straight full-house days"
        case .foundingMember:
            return "Locked"
        }
    }
}

enum LittleWinsShareImageFilter: String, CaseIterable, Identifiable {
    case vivid
    case warm
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .vivid:
            return "Vivid"
        case .warm:
            return "Warm"
        case .mono:
            return "Mono"
        }
    }

    func next() -> LittleWinsShareImageFilter {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .vivid }
        return all[(index + 1) % all.count]
    }
}

struct LittleWinsShareOverlayWin: Identifiable {
    let id: UUID
    let title: String
    let isCompleted: Bool
}

struct LittleWinsShareOverlayCard: Identifiable {
    let id: UUID
    let title: String
    let cardColor: Color
    let titleColor: Color
    let wins: [LittleWinsShareOverlayWin]

    var completedCount: Int {
        wins.filter(\.isCompleted).count
    }

    var isCompleted: Bool {
        !wins.isEmpty && completedCount == wins.count
    }
}

struct LittleWinsShareOverlayMiniCardStyle {
    let fillColor: Color
    let strokeColor: Color
}

struct LittleWinsShareOverlayData {
    let activeCards: [LittleWinsShareOverlayCard]
    let completedCardsToday: [LittleWinsShareOverlayCard]
    let completedCardStylesLast7Days: [[LittleWinsShareOverlayMiniCardStyle]]
    let radarSideCount: Int
    let streak: Int
    let hotStreak: Bool
    let totalWeekCompletions: Int
    let fullHouseUnlocked: Bool
    let royalFlushUnlocked: Bool
    let royalFlushProgressDays: Int

    var hasAnyWins: Bool {
        !activeCards.isEmpty || totalWeekCompletions > 0
    }
}

struct LittleWinsShareOverlayTemplateView: View {
    let template: LittleWinsShareTemplate
    let data: LittleWinsShareOverlayData
    let showsBackdrop: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsBackdrop {
                LinearGradient(
                    colors: [
                        Color.black.opacity(0.28),
                        Color.black.opacity(0.14),
                        Color.black.opacity(0.24)
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .ignoresSafeArea()
            }

            switch template {
            case .todaysWins:
                todaysWinsLayout
            case .completedWins:
                completedWinsLayout
            case .weeklyCalendar:
                weeklyCalendarLayout
            case .streak:
                streakLayout
            case .hotStreak:
                hotStreakLayout
            case .fullSnapshot:
                fullSnapshotLayout
            case .fullHouse:
                fullHouseLayout
            case .royalFlush:
                royalFlushLayout
            case .foundingMember:
                foundingMemberLayout
            }
        }
    }

    init(
        template: LittleWinsShareTemplate,
        data: LittleWinsShareOverlayData,
        showsBackdrop: Bool = true
    ) {
        self.template = template
        self.data = data
        self.showsBackdrop = showsBackdrop
    }

    private var standardTemplatePadding: EdgeInsets {
        EdgeInsets(top: 130, leading: 20, bottom: 20, trailing: 20)
    }

    private var dockedTemplatePadding: EdgeInsets {
        EdgeInsets(top: 130, leading: 20, bottom: 150, trailing: 20)
    }

    private var todaysWinsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Working On")

            if data.activeCards.isEmpty {
                emptyStateCard(text: "Create Little Wins to start building cards.")
            } else {
                templateCardsGrid(cards: Array(data.activeCards.prefix(4)), cardOpacity: 0.5)
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var completedWinsLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Completed Today")

            if data.completedCardsToday.isEmpty {
                emptyStateCard(text: "Complete every row in a card to stack it in today\'s wins.")
            } else {
                templateCardsGrid(cards: Array(data.completedCardsToday.prefix(4)), cardOpacity: 0.5)
            }

            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var weeklyCalendarLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Weekly Calendar")
            calendarMiniStackBoard
            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
    }

    private var streakLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            templateTitle("Streak")
            bigStreakCard(
                title: "Current streak",
                count: data.streak,
                subtitle: data.streak > 0
                    ? "\(data.streak) day streak in motion."
                    : "Start with one completed card today.",
                symbol: "bolt.fill",
                tint: .blue
            )
        }
        .padding(dockedTemplatePadding)
    }

    private var hotStreakLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            templateTitle("Building hot streak")

            bigStreakCard(
                title: "Hot streak",
                count: data.streak,
                subtitle: data.hotStreak
                    ? "Keep cards complete each day to protect momentum."
                    : "Reach 5 straight days to ignite hot streak mode.",
                symbol: "flame.fill",
                tint: .orange
            )
        }
        .padding(dockedTemplatePadding)
        .overlay {
            if !data.hotStreak {
                lockedTemplateOverlay(text: "Complete Little Wins 5 days straight to unlock")
            }
        }
    }

    private var fullSnapshotLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            Spacer(minLength: 0)

            templateTitle("Full Snapshot")

            if data.activeCards.isEmpty {
                emptyStateCard(text: "Set a few Little Wins to generate your snapshot.")
            } else {
                templateCardsGrid(cards: Array(data.activeCards.prefix(4)), cardOpacity: 0.5)
            }

            calendarMiniStackBoard
        }
        .padding(dockedTemplatePadding)
    }

    private var fullHouseLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Full House")
            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
        .overlay {
            lockedTemplateOverlay(text: "Complete all Little Wins today to unlock")
        }
    }

    private var royalFlushLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Royal Flush")
            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
        .overlay {
            lockedTemplateOverlay(text: "Complete all Little Wins for 7 straight days to unlock")
        }
    }

    private var foundingMemberLayout: some View {
        VStack(alignment: .leading, spacing: 10) {
            templateTitle("Founding Member")
            Spacer(minLength: 0)
        }
        .padding(standardTemplatePadding)
        .overlay {
            lockedTemplateOverlay(text: "Founding Member template is locked for now")
        }
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

    private func templateCardsGrid(cards: [LittleWinsShareOverlayCard], cardOpacity: Double) -> some View {
        let visibleCards = Array(cards.prefix(4))
        let columns = [
            GridItem(.flexible(), spacing: 12, alignment: .top),
            GridItem(.flexible(), spacing: 12, alignment: .top)
        ]

        return LazyVGrid(columns: columns, spacing: 12) {
            ForEach(visibleCards) { card in
                littleWinsCard(card)
                    .aspectRatio(1.0 / 1.42, contentMode: .fit)
                    .opacity(cardOpacity)
            }
        }
    }

    private func streakSummaryCard(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.95))
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.85))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func bigStreakCard(
        title: String,
        count: Int,
        subtitle: String,
        symbol: String,
        tint: Color
    ) -> some View {
        VStack(spacing: 10) {
            HStack(spacing: 7) {
                Image(systemName: symbol)
                    .font(.headline.weight(.semibold))
                Text(title)
                    .font(.headline.weight(.semibold))
            }
            .foregroundStyle(.white.opacity(0.95))

            Text("\(count)")
                .font(.system(size: 84, weight: .bold, design: .rounded))
                .foregroundStyle(.white)
                .minimumScaleFactor(0.7)
                .lineLimit(1)

            Text(subtitle)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.88))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .padding(.horizontal, 14)
        .background(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .fill(
                    LinearGradient(
                        colors: [
                            tint.opacity(0.36),
                            Color.black.opacity(0.44)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
        )
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(
                    LinearGradient(
                        colors: [Color.white.opacity(0.40), tint.opacity(0.45)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ),
                    lineWidth: 1.2
                )
        )
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

    private var completedDays: [(weekday: String, dayNumber: String, styles: [LittleWinsShareOverlayMiniCardStyle])] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let stylesByDay = normalizedCompletedCardStyles
        return stylesByDay.enumerated().compactMap { index, styles in
            guard let date = calendar.date(byAdding: .day, value: -(6 - index), to: today) else { return nil }
            return (
                weekday: date.formatted(.dateTime.weekday(.narrow)),
                dayNumber: date.formatted(.dateTime.day()),
                styles: styles
            )
        }
    }

    private var normalizedCompletedCardStyles: [[LittleWinsShareOverlayMiniCardStyle]] {
        let styles = data.completedCardStylesLast7Days
        if styles.count == 7 { return styles }
        if styles.count > 7 { return Array(styles.suffix(7)) }
        return Array(repeating: [], count: max(0, 7 - styles.count)) + styles
    }

    private func miniCardStack(styles: [LittleWinsShareOverlayMiniCardStyle]) -> some View {
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

    private func miniCard(style: LittleWinsShareOverlayMiniCardStyle) -> some View {
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(style.fillColor)
            .frame(width: 28, height: 40)
            .overlay {
                LittleWinsRadarPolygonOutline(sides: data.radarSideCount)
                    .stroke(style.strokeColor.opacity(0.85), lineWidth: 1.6)
                    .padding(4)
            }
            .overlay {
                RoundedRectangle(cornerRadius: 4, style: .continuous)
                    .stroke(Color.white.opacity(0.25), lineWidth: 0.8)
            }
    }

    private func littleWinsCard(_ card: LittleWinsShareOverlayCard) -> some View {
        GeometryReader { proxy in
            let width = max(proxy.size.width, 1)
            let height = max(proxy.size.height, 1)
            let baseWidth: CGFloat = 300
            let baseHeight: CGFloat = baseWidth * 1.42
            let scale = min(width / baseWidth, height / baseHeight)
            let fixedPrimaryText = Color.black.opacity(0.82)
            let fixedSecondaryText = Color.black.opacity(0.56)
            let radarSideCount = data.radarSideCount
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
                                    Image(systemName: win.isCompleted ? "checkmark.circle.fill" : "circle")
                                        .font(.system(size: rowIconSize, weight: .regular))
                                        .foregroundStyle(win.isCompleted ? card.titleColor : fixedSecondaryText)
                                        .frame(width: rowIconFrameWidth, alignment: .center)
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
                littleWinsCardBackground(
                    cardColor: card.cardColor,
                    titleColor: card.titleColor,
                    patternText: card.title,
                    width: width,
                    height: height,
                    radarSideCount: radarSideCount,
                    scale: scale
                )
            }
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
        }
    }

    private func emptyStateCard(text: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.black.opacity(0.34))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.white.opacity(0.22), lineWidth: 1)
        )
    }

    private func lockedTemplateOverlay(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20, style: .continuous)
                .fill(Color.black.opacity(0.58))
                .padding(.horizontal, 18)
                .padding(.vertical, 120)

            VStack(spacing: 10) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
        }
        .allowsHitTesting(false)
    }

    private func littleWinsCardBackground(
        cardColor: Color,
        titleColor: Color,
        patternText: String,
        width: CGFloat,
        height: CGFloat,
        radarSideCount: Int,
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
                littleWinsCardTextPatternBackground(
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
                littleWinsInsetGuideLine(
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
                LittleWinsRadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: shapeLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.leading, cornerShapePadding)
                    .padding(.top, cornerShapePadding)
                    .opacity(0.9)
            }
            .overlay(alignment: .bottomTrailing) {
                LittleWinsRadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: shapeLineWidth))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.trailing, cornerShapePadding)
                    .padding(.bottom, cornerShapePadding)
                    .opacity(0.9)
            }
    }

    private func littleWinsInsetGuideLine(
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

    private func littleWinsCardTextPatternBackground(
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

private struct LittleWinsRadarPolygonOutline: Shape {
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
