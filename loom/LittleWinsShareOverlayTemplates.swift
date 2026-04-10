import SwiftUI
import Charts

enum LittleWinsShareImageFilter: String, CaseIterable, Identifiable {
    case color
    case mono

    var id: String { rawValue }

    var title: String {
        switch self {
        case .color:
            return "Color"
        case .mono:
            return "Mono"
        }
    }

    func next() -> LittleWinsShareImageFilter {
        let all = Self.allCases
        guard let index = all.firstIndex(of: self) else { return .color }
        return all[(index + 1) % all.count]
    }
}

enum LittleWinsShareTemplateKind: String {
    case todaysWins
    case completedWins
    case weeklyCalendar
    case streak
    case hotStreak
    case fullSnapshot
    case fullHouse
    case royalFlush
    case foundingMember
    case starterStory
    case appleHealthVerified
    case measuredGoalProgress
    case goalAchieved
    case fulfillmentPulse
    case weeklyMomentum
    case insightDrop
}

struct LittleWinsShareTemplateDefinition: Identifiable {
    let id: String
    let title: String
    let subtitle: String
    let priority: Int
    fileprivate let kind: LittleWinsShareTemplateKind
    fileprivate let eligibilityLogic: (LittleWinsShareOverlayData) -> Bool
    fileprivate let lockReasonResolver: (LittleWinsShareOverlayData) -> String

    func isEligible(in data: LittleWinsShareOverlayData) -> Bool {
        eligibilityLogic(data)
    }

    func lockReason(in data: LittleWinsShareOverlayData) -> String? {
        isEligible(in: data) ? nil : lockReasonResolver(data)
    }

    func previewThumbnail(data: LittleWinsShareOverlayData, isSelected: Bool) -> AnyView {
        AnyView(
            LittleWinsShareTemplateThumbnail(
                template: self,
                data: data,
                isSelected: isSelected
            )
        )
    }

    func renderView(data: LittleWinsShareOverlayData, showsBackdrop: Bool = true) -> AnyView {
        AnyView(
            LittleWinsShareOverlayTemplateView(
                template: self,
                data: data,
                showsBackdrop: showsBackdrop
            )
        )
    }
}

enum LittleWinsShareTemplateCatalog {
    static let templates: [LittleWinsShareTemplateDefinition] = [
        .init(
            id: "hotStreak",
            title: "Hot Streak",
            subtitle: "Unlocked at 5 straight days",
            priority: 10,
            kind: .hotStreak,
            eligibilityLogic: { $0.hotStreak },
            lockReasonResolver: { data in
                "Complete Little Wins for \(max(0, 5 - data.streak)) more day\(max(0, 5 - data.streak) == 1 ? "" : "s") to unlock."
            }
        ),
        .init(
            id: "fullHouse",
            title: "Full House",
            subtitle: "Every active card cleared today",
            priority: 20,
            kind: .fullHouse,
            eligibilityLogic: { $0.fullHouseUnlocked },
            lockReasonResolver: { _ in
                "Complete every active Little Win card today to unlock."
            }
        ),
        .init(
            id: "royalFlush",
            title: "Royal Flush",
            subtitle: "Seven straight full-house days",
            priority: 30,
            kind: .royalFlush,
            eligibilityLogic: { $0.royalFlushUnlocked },
            lockReasonResolver: { data in
                "Protect your Full House for \(max(0, 7 - data.royalFlushProgressDays)) more day\(max(0, 7 - data.royalFlushProgressDays) == 1 ? "" : "s") to unlock."
            }
        ),
        .init(
            id: "foundingMember",
            title: "Founding Member",
            subtitle: "Annual member badge story",
            priority: 40,
            kind: .foundingMember,
            eligibilityLogic: { $0.userProfile.isFoundingMember },
            lockReasonResolver: { _ in
                "Founding Member stories unlock on Loom's annual plan."
            }
        ),
        .init(
            id: "starterStory",
            title: "Starter Story",
            subtitle: "Only during the first 3 days",
            priority: 50,
            kind: .starterStory,
            eligibilityLogic: { $0.userProfile.isWithinStarterWindow },
            lockReasonResolver: { _ in
                "Starter Story is available only during your first 3 days in Loom."
            }
        ),
        .init(
            id: "appleHealthVerified",
            title: "Apple Health Verified",
            subtitle: "Auto-verified Little Wins progress",
            priority: 55,
            kind: .appleHealthVerified,
            eligibilityLogic: { $0.appleHealthVerifiedStory != nil },
            lockReasonResolver: { _ in
                "Connect a Little Win to Apple Health to unlock this story."
            }
        ),
        .init(
            id: "measuredGoalProgress",
            title: "Measured Goal Progress",
            subtitle: "Live measurable goal chart",
            priority: 60,
            kind: .measuredGoalProgress,
            eligibilityLogic: { $0.featuredActiveGoal != nil },
            lockReasonResolver: { _ in
                "Create an active measurable goal in Outcomes to unlock this story."
            }
        ),
        .init(
            id: "goalAchieved",
            title: "Goal Achieved",
            subtitle: "Unlocked after a successful completion",
            priority: 70,
            kind: .goalAchieved,
            eligibilityLogic: { $0.latestAchievedGoal != nil },
            lockReasonResolver: { _ in
                "Finish a goal successfully to unlock this story."
            }
        ),
        .init(
            id: "fulfillmentPulse",
            title: "Fulfillment Pulse",
            subtitle: "Live fulfillment radar and score",
            priority: 80,
            kind: .fulfillmentPulse,
            eligibilityLogic: { $0.fulfillmentStory != nil },
            lockReasonResolver: { _ in
                "Add fulfillment areas with current scores to unlock this story."
            }
        ),
        .init(
            id: "weeklyMomentum",
            title: "Weekly Momentum",
            subtitle: "Your last 7 days of follow-through",
            priority: 90,
            kind: .weeklyMomentum,
            eligibilityLogic: { $0.totalWeekCompletions > 0 },
            lockReasonResolver: { _ in
                "Log Little Wins this week to unlock your momentum story."
            }
        ),
        .init(
            id: "insightDrop",
            title: "Insight Drop",
            subtitle: "Latest Loom diagnostic direction",
            priority: 100,
            kind: .insightDrop,
            eligibilityLogic: { $0.latestInsight != nil },
            lockReasonResolver: { _ in
                "Generate Loom insights to unlock this story."
            }
        ),
        .init(
            id: "todaysWins",
            title: "Today's Little Wins",
            subtitle: "Active cards in motion",
            priority: 110,
            kind: .todaysWins,
            eligibilityLogic: { !$0.activeCards.isEmpty },
            lockReasonResolver: { _ in
                "Create Little Wins to unlock this story."
            }
        ),
        .init(
            id: "completedWins",
            title: "Completed Wins",
            subtitle: "Cards finished today",
            priority: 120,
            kind: .completedWins,
            eligibilityLogic: { !$0.completedCardsToday.isEmpty },
            lockReasonResolver: { _ in
                "Complete one full Little Win card today to unlock."
            }
        ),
        .init(
            id: "weeklyCalendar",
            title: "Weekly Calendar",
            subtitle: "Real mini-card stacks by day",
            priority: 130,
            kind: .weeklyCalendar,
            eligibilityLogic: { $0.hasAnyWins },
            lockReasonResolver: { _ in
                "Add or complete Little Wins to populate your calendar story."
            }
        ),
        .init(
            id: "streak",
            title: "Streak",
            subtitle: "Current consistency run",
            priority: 140,
            kind: .streak,
            eligibilityLogic: { $0.streak > 0 },
            lockReasonResolver: { _ in
                "Complete one Little Win today to start your streak."
            }
        ),
        .init(
            id: "fullSnapshot",
            title: "Full Snapshot",
            subtitle: "Cards plus weekly calendar",
            priority: 150,
            kind: .fullSnapshot,
            eligibilityLogic: { !$0.activeCards.isEmpty || $0.totalWeekCompletions > 0 },
            lockReasonResolver: { _ in
                "Add Little Wins to build your snapshot."
            }
        )
    ]

    static var sortedTemplates: [LittleWinsShareTemplateDefinition] {
        templates.sorted { lhs, rhs in
            if lhs.priority == rhs.priority {
                return lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
            }
            return lhs.priority < rhs.priority
        }
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

struct LittleWinsShareUserProfile {
    let displayName: String?
    let installDate: Date?
    let daysSinceInstall: Int?
    let isSubscribed: Bool
    let isFoundingMember: Bool

    var isWithinStarterWindow: Bool {
        guard let daysSinceInstall else { return false }
        return daysSinceInstall < 3
    }

    var starterDayNumber: Int? {
        guard let daysSinceInstall else { return nil }
        return min(3, max(1, daysSinceInstall + 1))
    }
}

struct LittleWinsShareGoalProgressPoint: Identifiable {
    let date: Date
    let value: Double

    var id: Date { date }
}

struct LittleWinsShareGoalProgressData {
    let outcomeID: UUID
    let title: String
    let category: String
    let startDate: Date
    let endDate: Date
    let startValue: Double
    let currentValue: Double
    let goalValue: Double
    let latestDate: Date
    let chartPoints: [LittleWinsShareGoalProgressPoint]
    let format: String?
    let unit: String?
    let decimalPlaces: Int
    let isBehindGoalPath: Bool?

    var progressFraction: Double {
        let delta = goalValue - startValue
        guard abs(delta) > 0.0001 else { return 0 }
        let raw = (currentValue - startValue) / delta
        return min(1, max(0, raw))
    }

    var directionIsUp: Bool {
        goalValue >= startValue
    }

    var daysRemaining: Int {
        max(0, Calendar.current.dateComponents([.day], from: Calendar.current.startOfDay(for: .now), to: Calendar.current.startOfDay(for: endDate)).day ?? 0)
    }

    var progressLabel: String {
        "\(Int(round(progressFraction * 100)))%"
    }

    var statusColor: Color {
        if let isBehindGoalPath {
            return isBehindGoalPath ? .orange : .green
        }
        return .blue
    }
}

struct LittleWinsShareAppleHealthVerifiedData {
    let focusID: UUID
    let focusTitle: String
    let categoryTitle: String
    let metricTitle: String
    let unitLabel: String
    let progressValue: Double
    let targetValue: Double
    let decimalPlaces: Int
    let updatedAt: Date?
    let relatedGoalTitle: String?

    var progressFraction: Double {
        guard targetValue > 0 else { return 0 }
        return min(1, max(0, progressValue / targetValue))
    }

    var progressPercentLabel: String {
        "\(Int(round(progressFraction * 100)))%"
    }

    var statusTitle: String {
        progressFraction >= 1 ? "Verified complete" : "Verified in progress"
    }
}

struct LittleWinsShareAchievedGoalData {
    let archiveID: UUID
    let title: String
    let category: String
    let completedAt: Date
    let goalValue: Double?
    let finalValue: Double?
    let daysElapsed: Int
    let goalMet: Bool
    let isMeasurable: Bool
    let chartPoints: [LittleWinsShareGoalProgressPoint]
    let startDate: Date
    let endDate: Date
    let format: String?
    let decimalPlaces: Int
}

struct LittleWinsShareFulfillmentMetric: Identifiable {
    let title: String
    let color: Color
    let percentage: Double

    var id: String { title }
}

struct LittleWinsShareFulfillmentStoryData {
    let featuredCategoryTitle: String
    let featuredColor: Color
    let score: Double
    let delta: Double?
    let metrics: [LittleWinsShareFulfillmentMetric]

    var scorePercent: Double {
        (FulfillmentScoringMath.clamp(score, 1, 5) / 5.0) * 100.0
    }
}

struct LittleWinsShareInsightData {
    let rootCause: String
    let nextDirection: String
    let generatedAt: Date
}

struct LittleWinsShareOverlayData {
    let activeCards: [LittleWinsShareOverlayCard]
    let completedCardsToday: [LittleWinsShareOverlayCard]
    let completedCardStylesLast7Days: [[LittleWinsShareOverlayMiniCardStyle]]
    let completionCountsLast7Days: [Int]
    let fulfillmentAreaColors: [Color]
    let radarSideCount: Int
    let streak: Int
    let hotStreak: Bool
    let totalWeekCompletions: Int
    let fullHouseUnlocked: Bool
    let royalFlushUnlocked: Bool
    let royalFlushProgressDays: Int
    let userProfile: LittleWinsShareUserProfile
    let appleHealthVerifiedStory: LittleWinsShareAppleHealthVerifiedData?
    let featuredActiveGoal: LittleWinsShareGoalProgressData?
    let latestAchievedGoal: LittleWinsShareAchievedGoalData?
    let fulfillmentStory: LittleWinsShareFulfillmentStoryData?
    let latestInsight: LittleWinsShareInsightData?

    var hasAnyWins: Bool {
        !activeCards.isEmpty || totalWeekCompletions > 0
    }

    var todayCompletionCount: Int {
        completedCardsToday.reduce(0) { $0 + $1.completedCount }
    }

    var activeDayCountLast7: Int {
        normalizedCompletionCountsLast7Days.filter { $0 > 0 }.count
    }

    var featuredCard: LittleWinsShareOverlayCard? {
        completedCardsToday.first
            ?? activeCards.max(by: { $0.completedCount < $1.completedCount })
            ?? activeCards.first
    }

    var normalizedCompletionCountsLast7Days: [Int] {
        if completionCountsLast7Days.count == 7 { return completionCountsLast7Days }
        if completionCountsLast7Days.count > 7 { return Array(completionCountsLast7Days.suffix(7)) }
        return Array(repeating: 0, count: max(0, 7 - completionCountsLast7Days.count)) + completionCountsLast7Days
    }

    var primaryAccentColor: Color {
        fulfillmentAreaColors.first ?? featuredCard?.titleColor ?? .blue
    }

    var secondaryAccentColor: Color {
        if fulfillmentAreaColors.count > 1 {
            return fulfillmentAreaColors[1]
        }
        return featuredCard?.cardColor ?? primaryAccentColor
    }

    var tertiaryAccentColor: Color {
        if fulfillmentAreaColors.count > 2 {
            return fulfillmentAreaColors[2]
        }
        return secondaryAccentColor
    }
}

struct LittleWinsShareOverlayTemplateView: View {
    let template: LittleWinsShareTemplateDefinition
    let data: LittleWinsShareOverlayData
    let showsBackdrop: Bool

    var body: some View {
        ZStack(alignment: .topLeading) {
            if showsBackdrop {
                storyBackdrop(colors: templateBackdropColors)
                    .ignoresSafeArea()
            }

            overlayContent
        }
        .overlay {
            if let lockReason = template.lockReason(in: data) {
                lockedTemplateOverlay(text: lockReason)
            }
        }
    }

    private var overlayContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            templateHeader

            switch template.kind {
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
            case .starterStory:
                starterStoryLayout
            case .appleHealthVerified:
                appleHealthVerifiedLayout
            case .measuredGoalProgress:
                measuredGoalProgressLayout
            case .goalAchieved:
                goalAchievedLayout
            case .fulfillmentPulse:
                fulfillmentPulseLayout
            case .weeklyMomentum:
                weeklyMomentumLayout
            case .insightDrop:
                insightDropLayout
            }
        }
        .padding(.top, 126)
        .padding(.horizontal, 20)
        .padding(.bottom, 148)
    }

    private var templateBackdropColors: [Color] {
        switch template.kind {
        case .hotStreak:
            return [Color.orange.opacity(0.85), data.primaryAccentColor.opacity(0.28), Color.black.opacity(0.88)]
        case .fullHouse:
            return [Color.green.opacity(0.72), data.primaryAccentColor.opacity(0.28), Color.black.opacity(0.88)]
        case .royalFlush:
            return [Color.yellow.opacity(0.52), data.secondaryAccentColor.opacity(0.28), Color.black.opacity(0.90)]
        case .foundingMember:
            return [data.primaryAccentColor.opacity(0.78), data.secondaryAccentColor.opacity(0.34), Color.black.opacity(0.90)]
        case .starterStory:
            return [data.primaryAccentColor.opacity(0.58), data.secondaryAccentColor.opacity(0.26), Color.black.opacity(0.88)]
        case .appleHealthVerified:
            return [Color.red.opacity(0.76), data.secondaryAccentColor.opacity(0.24), Color.black.opacity(0.90)]
        case .measuredGoalProgress:
            return [Color.blue.opacity(0.74), data.primaryAccentColor.opacity(0.24), Color.black.opacity(0.88)]
        case .goalAchieved:
            return [Color.green.opacity(0.66), data.primaryAccentColor.opacity(0.24), Color.black.opacity(0.88)]
        case .fulfillmentPulse:
            let accent = data.fulfillmentStory?.featuredColor ?? .blue
            return [accent.opacity(0.74), data.secondaryAccentColor.opacity(0.18), Color.black.opacity(0.90)]
        case .weeklyMomentum:
            return [data.primaryAccentColor.opacity(0.68), data.secondaryAccentColor.opacity(0.20), Color.black.opacity(0.88)]
        case .insightDrop:
            return [data.primaryAccentColor.opacity(0.58), data.tertiaryAccentColor.opacity(0.20), Color.black.opacity(0.90)]
        case .todaysWins, .completedWins, .weeklyCalendar, .streak, .fullSnapshot:
            return [Color.black.opacity(0.76), data.primaryAccentColor.opacity(0.14), Color.black.opacity(0.92)]
        }
    }

    private var templateHeader: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("logo")
                .resizable()
                .renderingMode(.template)
                .scaledToFit()
                .frame(height: 28)
                .foregroundStyle(.white)

            VStack(alignment: .leading, spacing: 2) {
                Text(template.title)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                Text(template.subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            if template.kind == .starterStory, let starterDayNumber = data.userProfile.starterDayNumber {
                statCapsule(title: "Day \(starterDayNumber)", accent: .green)
            } else if template.kind == .hotStreak {
                statCapsule(title: "\(data.streak) days", accent: .orange)
            } else if template.kind == .appleHealthVerified {
                statCapsule(title: "Verified", accent: .pink)
            } else if template.kind == .weeklyMomentum {
                statCapsule(title: "\(data.totalWeekCompletions) wins", accent: .blue)
            } else if template.kind == .royalFlush {
                statCapsule(title: "\(data.royalFlushProgressDays)/7", accent: .yellow)
            }
        }
    }

    private var todaysWinsLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Today's cards are live.",
                subtitle: data.activeCards.isEmpty
                    ? "Create Little Wins to start building shareable cards."
                    : "\(data.activeCards.count) active card\(data.activeCards.count == 1 ? "" : "s") across Loom today."
            )

            if data.activeCards.isEmpty {
                emptyStateCard(text: "Create Little Wins to start building cards.")
            } else {
                templateCardsGrid(cards: Array(data.activeCards.prefix(4)), cardOpacity: 0.94)
            }

            Spacer(minLength: 0)
        }
    }

    private var completedWinsLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Cards landed today.",
                subtitle: data.completedCardsToday.isEmpty
                    ? "Finish a card to stack it here."
                    : "\(data.completedCardsToday.count) completed card\(data.completedCardsToday.count == 1 ? "" : "s") today."
            )

            if data.completedCardsToday.isEmpty {
                emptyStateCard(text: "Complete every row in a card to stack it in today's wins.")
            } else {
                VStack(alignment: .leading, spacing: 12) {
                    celebrationSeal(symbol: "checkmark.seal.fill", title: "Completed Today", accent: .green)
                    templateCardsGrid(cards: Array(data.completedCardsToday.prefix(4)), cardOpacity: 0.98)
                }
            }

            Spacer(minLength: 0)
        }
    }

    private var weeklyCalendarLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Last 7 days at a glance.",
                subtitle: "\(data.activeDayCountLast7) active day\(data.activeDayCountLast7 == 1 ? "" : "s"), \(data.totalWeekCompletions) completed Little Win\(data.totalWeekCompletions == 1 ? "" : "s")."
            )

            calendarMiniStackBoard
            weeklyCompletionStrip
            Spacer(minLength: 0)
        }
    }

    private var streakLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)

            bigHeroStatCard(
                eyebrow: "Current streak",
                title: "\(data.streak)",
                subtitle: data.streak > 0
                    ? "\(data.streak) day\(data.streak == 1 ? "" : "s") of Little Wins momentum."
                    : "Complete one Little Win today to begin.",
                accent: .blue,
                symbol: "bolt.fill"
            )
        }
    }

    private var hotStreakLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            Spacer(minLength: 0)

            HStack(alignment: .bottom, spacing: 12) {
                bigHeroStatCard(
                    eyebrow: "Hot streak",
                    title: "\(data.streak)",
                    subtitle: "Keep showing up daily to protect the run.",
                    accent: .orange,
                    symbol: "flame.fill"
                )

                VStack(spacing: 12) {
                    celebrationSeal(symbol: "flame.fill", title: "Ignited", accent: .orange)
                    statCard(
                        title: "Week volume",
                        value: "\(data.totalWeekCompletions)",
                        subtitle: "Completed wins in the last 7 days."
                    )
                }
                .frame(width: 126)
            }

            weeklyCompletionStrip
        }
    }

    private var fullSnapshotLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "A polished Loom snapshot.",
                subtitle: "Real cards, real weekly consistency, no generic social template."
            )

            if let featuredCard = data.featuredCard {
                littleWinsCard(featuredCard)
                    .frame(height: 214)
            } else {
                emptyStateCard(text: "Set a few Little Wins to generate your snapshot.")
            }

            calendarMiniStackBoard
            Spacer(minLength: 0)
        }
    }

    private var fullHouseLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Every card is cleared today.",
                subtitle: "The cleanest Little Wins share in Loom."
            )

            celebrationSeal(symbol: "sparkles", title: "Full House", accent: .green)
            templateCardsGrid(cards: Array(data.completedCardsToday.prefix(4)), cardOpacity: 1.0)
            calendarMiniStackBoard
            Spacer(minLength: 0)
        }
    }

    private var royalFlushLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Seven straight full-house days.",
                subtitle: "Daily completeness with no drop-off."
            )

            HStack(alignment: .top, spacing: 12) {
                celebrationSeal(symbol: "crown.fill", title: "Royal Flush", accent: .yellow)
                    .frame(width: 132)

                VStack(spacing: 12) {
                    statCard(
                        title: "Run protected",
                        value: "7/7",
                        subtitle: "Full House every day this week."
                    )
                    statCard(
                        title: "Week total",
                        value: "\(data.totalWeekCompletions)",
                        subtitle: "Little Wins completed in the streak window."
                    )
                }
            }

            calendarMiniStackBoard
            Spacer(minLength: 0)
        }
    }

    private var foundingMemberLayout: some View {
        let accent = data.primaryAccentColor

        return VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Founding Member.",
                subtitle: "Annual access with pricing locked in from Loom's earliest launch window."
            )

            HStack(alignment: .top, spacing: 14) {
                VStack(alignment: .leading, spacing: 12) {
                    storyPanel {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(data.userProfile.displayName?.nonEmptyOr("Founding Member") ?? "Founding Member")
                                .font(.title3.weight(.bold))
                                .foregroundStyle(.white)
                            Text("Annual member")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.78))
                            statCapsule(
                                title: data.radarSideCount >= 5 ? "Early Annual" : "Founding Annual",
                                accent: accent.opacity(0.92),
                                textColor: .white
                            )
                        }
                    }

                    storyPanel {
                        Text("This founder share keeps the real Loom Little Wins card treatment instead of a generic social badge.")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                }

                celebrationSeal(symbol: "rosette", title: "Founder", accent: accent)
                    .frame(width: 128)
            }

            if let featuredCard = data.featuredCard {
                littleWinsCard(featuredCard)
                    .frame(height: 192)
            } else {
                calendarMiniStackBoard
            }

            Spacer(minLength: 0)
        }
    }

    private var starterStoryLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            let dayNumber = data.userProfile.starterDayNumber ?? 1
            heroText(
                title: "Day \(dayNumber) on Loom.",
                subtitle: "A first-week share with your real cards and early momentum."
            )

            HStack(alignment: .top, spacing: 12) {
                bigHeroStatCard(
                    eyebrow: "Starter story",
                    title: "Day \(dayNumber)",
                    subtitle: data.activeCards.isEmpty
                        ? "Set up your first Little Wins card."
                        : "\(data.activeCards.count) active card\(data.activeCards.count == 1 ? "" : "s") already in play.",
                    accent: .green,
                    symbol: "seedling"
                )

                VStack(spacing: 12) {
                    statCard(
                        title: "First streak",
                        value: "\(data.streak)",
                        subtitle: "Consistency starts small."
                    )
                    statCard(
                        title: "This week",
                        value: "\(data.totalWeekCompletions)",
                        subtitle: "Completed Little Wins so far."
                    )
                }
                .frame(width: 126)
            }

            if let featuredCard = data.featuredCard {
                littleWinsCard(featuredCard)
                    .frame(height: 178)
            }

            Spacer(minLength: 0)
        }
    }

    private var appleHealthVerifiedLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let verified = data.appleHealthVerifiedStory {
                heroText(
                    title: "Apple Health is verifying real progress.",
                    subtitle: verified.relatedGoalTitle != nil
                        ? "\(verified.focusTitle) is syncing into Loom and supporting \(verified.relatedGoalTitle!)."
                        : "\(verified.focusTitle) is connected to \(verified.metricTitle) and updating automatically."
                )

                HStack(alignment: .top, spacing: 12) {
                    bigHeroStatCard(
                        eyebrow: verified.metricTitle,
                        title: "\(formattedValue(verified.progressValue, decimalPlaces: verified.decimalPlaces)) \(verified.unitLabel)",
                        subtitle: "Auto-synced toward \(formattedValue(verified.targetValue, decimalPlaces: verified.decimalPlaces)) \(verified.unitLabel).",
                        accent: .pink,
                        symbol: "heart.fill"
                    )

                    VStack(spacing: 12) {
                        statCard(
                            title: verified.statusTitle,
                            value: verified.progressPercentLabel,
                            subtitle: verified.categoryTitle
                        )
                        statCard(
                            title: "Connected win",
                            value: verified.focusTitle,
                            subtitle: verified.relatedGoalTitle ?? "Verified by Apple Health."
                        )
                    }
                    .frame(width: 132)
                }

                storyPanel {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack(spacing: 8) {
                            Image(systemName: "heart.text.square.fill")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.white)
                            Text("Verified source")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.92))
                        }

                        Text("Loom is pulling \(verified.metricTitle.lowercased()) from Apple Health so this Little Win reflects real completion instead of manual logging.")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                Spacer(minLength: 0)
            } else {
                emptyStateCard(text: "Connect a Little Win to Apple Health to unlock this story.")
            }
        }
    }

    private var measuredGoalProgressLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let goal = data.featuredActiveGoal {
                heroText(
                    title: goal.title,
                    subtitle: "\(goal.category) goal tracked with real Loom data."
                )

                goalStoryPanel(goal: goal)
                goalSummaryRow(goal: goal)
            } else {
                emptyStateCard(text: "Create an active measurable goal to unlock the chart story.")
            }

            Spacer(minLength: 0)
        }
    }

    private var goalAchievedLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let goal = data.latestAchievedGoal {
                heroText(
                    title: goal.title,
                    subtitle: "\(goal.category) completed successfully on \(goal.completedAt.formatted(.dateTime.month(.abbreviated).day()))."
                )

                HStack(alignment: .top, spacing: 12) {
                    celebrationSeal(symbol: "checkmark.seal.fill", title: "Goal Achieved", accent: .green)
                        .frame(width: 132)

                    VStack(spacing: 12) {
                        statCard(
                            title: "Elapsed",
                            value: "\(goal.daysElapsed)",
                            subtitle: "Days from start to completion."
                        )

                        if let finalValue = goal.finalValue, let goalValue = goal.goalValue {
                            statCard(
                                title: "Final vs goal",
                                value: "\(formattedValue(finalValue, decimalPlaces: goal.decimalPlaces)) / \(formattedValue(goalValue, decimalPlaces: goal.decimalPlaces))",
                                subtitle: "Measured completion."
                            )
                        } else {
                            statCard(
                                title: "Completion",
                                value: "Success",
                                subtitle: "Outcome closed out successfully."
                            )
                        }
                    }
                }

                if goal.isMeasurable && !goal.chartPoints.isEmpty {
                    LittleWinsShareGoalArchiveChartView(goal: goal)
                        .frame(height: 220)
                        .storyChartSurface()
                }
            } else {
                emptyStateCard(text: "Complete a goal successfully to unlock this story.")
            }

            Spacer(minLength: 0)
        }
    }

    private var fulfillmentPulseLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let fulfillment = data.fulfillmentStory {
                heroText(
                    title: fulfillment.featuredCategoryTitle,
                    subtitle: "Live fulfillment radar with this week's Loom score."
                )

                HStack(alignment: .top, spacing: 14) {
                    storyPanel {
                        FulfillmentRadarGraph(
                            metrics: fulfillment.metrics.map { ($0.title, $0.color, $0.percentage) },
                            showOutline: true,
                            dotDiameter: 12,
                            showDotOutline: true,
                            showDotShadow: true
                        )
                        .frame(height: 182)
                    }

                    VStack(spacing: 12) {
                        statCard(
                            title: "Weekly score",
                            value: String(format: "%.1f", fulfillment.score),
                            subtitle: "Out of 5.0"
                        )
                        statCard(
                            title: "Radar fill",
                            value: "\(Int(round(fulfillment.scorePercent)))%",
                            subtitle: fulfillmentDeltaLine(fulfillment.delta)
                        )
                    }
                    .frame(width: 126)
                }
            } else {
                emptyStateCard(text: "Add fulfillment areas with current scores to unlock this story.")
            }

            Spacer(minLength: 0)
        }
    }

    private var weeklyMomentumLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            heroText(
                title: "Weekly momentum",
                subtitle: "\(data.activeDayCountLast7) active day\(data.activeDayCountLast7 == 1 ? "" : "s") and \(data.totalWeekCompletions) completed Little Win\(data.totalWeekCompletions == 1 ? "" : "s")."
            )

            HStack(alignment: .top, spacing: 12) {
                bigHeroStatCard(
                    eyebrow: "This week",
                    title: "\(data.totalWeekCompletions)",
                    subtitle: "Completed Little Wins over the last 7 days.",
                    accent: .blue,
                    symbol: "chart.bar.fill"
                )

                VStack(spacing: 12) {
                    statCard(
                        title: "Active days",
                        value: "\(data.activeDayCountLast7)/7",
                        subtitle: "Days with at least one completion."
                    )
                    statCard(
                        title: "Current streak",
                        value: "\(data.streak)",
                        subtitle: "Days in a row right now."
                    )
                }
                .frame(width: 126)
            }

            weeklyCompletionStrip
            calendarMiniStackBoard
            Spacer(minLength: 0)
        }
    }

    private var insightDropLayout: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let insight = data.latestInsight {
                heroText(
                    title: "Loom insight drop",
                    subtitle: "Latest diagnostic direction from your real profile."
                )

                storyPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Next Direction")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.66))
                            .textCase(.uppercase)

                        Text(insight.nextDirection)
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineSpacing(2)
                    }
                }

                storyPanel {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Root Cause")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.66))
                            .textCase(.uppercase)
                        Text(insight.rootCause)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.white.opacity(0.88))
                            .lineSpacing(2)
                    }
                }

                if let fulfillment = data.fulfillmentStory {
                    HStack(spacing: 12) {
                        statCapsule(title: fulfillment.featuredCategoryTitle, accent: fulfillment.featuredColor)
                        Text(fulfillmentDeltaLine(fulfillment.delta))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }
                }
            } else {
                emptyStateCard(text: "Generate Loom insights to unlock this story.")
            }

            Spacer(minLength: 0)
        }
    }

    private func goalStoryPanel(goal: LittleWinsShareGoalProgressData) -> some View {
        storyPanel {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(goal.title)
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .lineLimit(2)
                        Text(goal.category)
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))
                    }

                    Spacer(minLength: 0)

                    statCapsule(title: goal.progressLabel, accent: goal.statusColor)
                }

                LittleWinsShareGoalProgressChartView(goal: goal)
                    .frame(height: 220)
            }
        }
    }

    private func goalSummaryRow(goal: LittleWinsShareGoalProgressData) -> some View {
        HStack(spacing: 10) {
            statCard(
                title: "Current",
                value: formattedValue(goal.currentValue, decimalPlaces: goal.decimalPlaces),
                subtitle: goal.latestDate.formatted(.dateTime.month(.abbreviated).day())
            )
            statCard(
                title: "Goal",
                value: formattedValue(goal.goalValue, decimalPlaces: goal.decimalPlaces),
                subtitle: goal.directionIsUp ? "Target up" : "Target down"
            )
            statCard(
                title: "Remaining",
                value: "\(goal.daysRemaining)d",
                subtitle: goal.isBehindGoalPath == true ? "Behind path" : "Window left"
            )
        }
    }

    private var weeklyCompletionStrip: some View {
        let counts = data.normalizedCompletionCountsLast7Days
        let maxCount = max(1, counts.max() ?? 1)
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        return storyPanel {
            HStack(alignment: .bottom, spacing: 10) {
                ForEach(Array(counts.enumerated()), id: \.offset) { index, count in
                    let dayOffset = 6 - index
                    let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) ?? today
                    VStack(spacing: 6) {
                        Capsule(style: .continuous)
                            .fill(count > 0 ? Color.white.opacity(0.9) : Color.white.opacity(0.18))
                            .frame(width: 18, height: max(12, (CGFloat(count) / CGFloat(maxCount)) * 82))
                            .overlay(
                                Capsule(style: .continuous)
                                    .stroke(Color.white.opacity(0.16), lineWidth: 1)
                            )

                        Text(date.formatted(.dateTime.weekday(.narrow)))
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.72))

                        Text("\(count)")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.white)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private var calendarMiniStackBoard: some View {
        VStack(spacing: 6) {
            HStack(spacing: 8) {
                ForEach(Array(completedDays.enumerated()), id: \.offset) { _, day in
                    VStack(spacing: 3) {
                        miniCardStack(styles: day.styles)
                            .frame(
                                width: LittleWinsCardStyleMetrics.miniCardWidth,
                                height: LittleWinsCardStyleMetrics.miniCardHeight + 2,
                                alignment: .top
                            )

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
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(Color.black.opacity(0.32))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
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

    private func storyBackdrop(colors: [Color]) -> some View {
        ZStack {
            LinearGradient(
                colors: colors,
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            RadialGradient(
                colors: [
                    colors.first?.opacity(0.42) ?? Color.white.opacity(0.18),
                    Color.clear
                ],
                center: .topLeading,
                startRadius: 30,
                endRadius: 360
            )
            .blendMode(.screen)

            Circle()
                .fill(colors.first?.opacity(0.14) ?? Color.white.opacity(0.10))
                .frame(width: 220, height: 220)
                .blur(radius: 30)
                .offset(x: 120, y: -160)

            Circle()
                .fill((colors.dropFirst().first ?? .white).opacity(0.14))
                .frame(width: 240, height: 240)
                .blur(radius: 36)
                .offset(x: -140, y: 180)
        }
    }

    private func heroText(title: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.title3.weight(.bold))
                .foregroundStyle(.white)
            Text(subtitle)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.82))
        }
    }

    private func storyPanel<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Color.black.opacity(0.30))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .stroke(Color.white.opacity(0.18), lineWidth: 1)
        )
    }

    private func statCard(title: String, value: String, subtitle: String) -> some View {
        storyPanel {
            VStack(alignment: .leading, spacing: 6) {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.66))
                    .textCase(.uppercase)
                Text(value)
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .lineLimit(2)
                    .minimumScaleFactor(0.7)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.white.opacity(0.76))
                    .lineLimit(3)
            }
        }
    }

    private func bigHeroStatCard(
        eyebrow: String,
        title: String,
        subtitle: String,
        accent: Color,
        symbol: String
    ) -> some View {
        storyPanel {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: symbol)
                        .font(.headline.weight(.semibold))
                    Text(eyebrow)
                        .font(.subheadline.weight(.semibold))
                }
                .foregroundStyle(.white.opacity(0.92))

                Text(title)
                    .font(.system(size: 72, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)

                Text(subtitle)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.84))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.vertical, 6)
            .background(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .fill(
                        LinearGradient(
                            colors: [accent.opacity(0.32), Color.clear],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
            )
        }
    }

    private func celebrationSeal(symbol: String, title: String, accent: Color) -> some View {
        TimelineView(.animation(minimumInterval: 1.0 / 24.0)) { context in
            let phase = context.date.timeIntervalSinceReferenceDate
            let pulse = 1.0 + (sin(phase * 2.4) * 0.04)

            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(accent.opacity(0.24))
                        .frame(width: 84, height: 84)
                        .scaleEffect(pulse)

                    Circle()
                        .stroke(Color.white.opacity(0.26), lineWidth: 1)
                        .frame(width: 84, height: 84)

                    Circle()
                        .fill(Color.black.opacity(0.24))
                        .frame(width: 64, height: 64)

                    Image(systemName: symbol)
                        .font(.title2.weight(.semibold))
                        .foregroundStyle(.white)
                }

                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.88))
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.28))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
        }
    }

    private func statCapsule(
        title: String,
        accent: Color,
        textColor: Color = .white
    ) -> some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(textColor)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .background(
                Capsule(style: .continuous)
                    .fill(accent)
            )
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
                    .aspectRatio(1.0 / LittleWinsCardStyleMetrics.aspectRatio, contentMode: .fit)
                    .opacity(cardOpacity)
            }
        }
    }

    private func emptyStateCard(text: String) -> some View {
        storyPanel {
            Text(text)
                .font(.subheadline.weight(.medium))
                .foregroundStyle(.white.opacity(0.92))
                .multilineTextAlignment(.leading)
        }
    }

    private func lockedTemplateOverlay(text: String) -> some View {
        ZStack {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .fill(Color.black.opacity(0.62))
                .padding(.horizontal, 18)
                .padding(.vertical, 112)

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(.white)
                Text(text)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
            }
        }
        .allowsHitTesting(false)
    }

    private func miniCardStack(styles: [LittleWinsShareOverlayMiniCardStyle]) -> some View {
        let visibleStyles = Array(styles.suffix(7))
        let stackLiftPerCard = LittleWinsCardStyleMetrics.miniCardStackLift(for: LittleWinsCardStyleMetrics.miniCardHeight)

        return ZStack {
            if visibleStyles.isEmpty {
                RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.miniCardCornerRadius, style: .continuous)
                    .fill(Color(.systemGray5))
                    .frame(
                        width: LittleWinsCardStyleMetrics.miniCardWidth,
                        height: LittleWinsCardStyleMetrics.miniCardHeight
                    )
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
        LittleWinsMiniCardView(
            fillColor: style.fillColor,
            strokeColor: style.strokeColor.opacity(0.85),
            radarSideCount: data.radarSideCount,
            width: LittleWinsCardStyleMetrics.miniCardWidth,
            height: LittleWinsCardStyleMetrics.miniCardHeight
        )
    }

    private func littleWinsCard(_ card: LittleWinsShareOverlayCard) -> some View {
        GeometryReader { proxy in
            let targetWidth = max(proxy.size.width, 1)
            let targetHeight = max(proxy.size.height, 1)
            let baseWidth = LittleWinsCardStyleMetrics.referenceWidth
            let baseHeight = LittleWinsCardStyleMetrics.referenceHeight
            let scale = min(targetWidth / baseWidth, targetHeight / baseHeight)

            LittleWinsShareScaledCardView(
                card: card,
                radarSideCount: data.radarSideCount
            )
            .frame(width: baseWidth, height: baseHeight, alignment: .top)
            .scaleEffect(scale, anchor: .topLeading)
            .frame(width: targetWidth, height: targetHeight, alignment: .topLeading)
        }
    }

    private func fulfillmentDeltaLine(_ delta: Double?) -> String {
        guard let delta else { return "No prior-week delta yet." }
        if abs(delta) < 0.05 { return "Holding steady week over week." }
        return delta > 0
            ? String(format: "Up %.1f vs last week.", delta)
            : String(format: "Down %.1f vs last week.", abs(delta))
    }

    private func formattedValue(_ value: Double, decimalPlaces: Int) -> String {
        let formatter = NumberFormatter()
        formatter.numberStyle = .decimal
        formatter.minimumFractionDigits = 0
        formatter.maximumFractionDigits = max(0, decimalPlaces)
        return formatter.string(from: NSNumber(value: value)) ?? String(format: "%.\(max(0, decimalPlaces))f", value)
    }
}

private struct LittleWinsShareScaledCardView: View {
    let card: LittleWinsShareOverlayCard
    let radarSideCount: Int

    var body: some View {
        let fixedPrimaryText = Color.black.opacity(0.82)
        let fixedSecondaryText = Color.black.opacity(0.56)

        return VStack(spacing: 0) {
            Text(card.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(card.titleColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 18)

            GeometryReader { middleGeo in
                VStack {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(card.wins.prefix(4)) { win in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: win.isCompleted ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 26, weight: .regular))
                                    .foregroundStyle(win.isCompleted ? card.titleColor : fixedSecondaryText)
                                    .padding(.top, 6)
                                    .frame(width: 30, alignment: .center)

                                Text(win.title)
                                    .font(.system(size: 36, weight: .semibold))
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
                .padding(.horizontal, 38)
                .padding(.vertical, 14)
                .frame(maxWidth: .infinity, minHeight: middleGeo.size.height, alignment: .center)
                .clipped()
            }

            Spacer(minLength: 0)

            HStack {
                Spacer()
                Text("Little Wins")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(fixedPrimaryText)
                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(
            width: LittleWinsCardStyleMetrics.referenceWidth,
            height: LittleWinsCardStyleMetrics.referenceHeight,
            alignment: .top
        )
        .background {
            LittleWinsCardBackgroundView(
                cardColor: card.cardColor,
                titleColor: card.titleColor,
                patternText: card.title,
                width: LittleWinsCardStyleMetrics.referenceWidth,
                height: LittleWinsCardStyleMetrics.referenceHeight,
                radarSideCount: radarSideCount
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: LittleWinsCardStyleMetrics.cornerRadius, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }
}

private struct LittleWinsShareTemplateThumbnail: View {
    let template: LittleWinsShareTemplateDefinition
    let data: LittleWinsShareOverlayData
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.black.opacity(0.86))

                template.renderView(data: data, showsBackdrop: true)
                    .frame(width: 390, height: 844)
                    .scaleEffect(0.24, anchor: .topLeading)
                    .frame(width: 94, height: 120, alignment: .topLeading)
                    .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                    .allowsHitTesting(false)

                if template.lockReason(in: data) != nil {
                    Image(systemName: "lock.fill")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.white)
                        .frame(width: 22, height: 22)
                        .background(Color.black.opacity(0.66), in: Circle())
                        .padding(8)
                }
            }
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(isSelected ? Color.white : Color.white.opacity(0.16), lineWidth: isSelected ? 1.6 : 1)
            )
            .frame(width: 94, height: 120)

            Text(template.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white.opacity(isSelected ? 1.0 : 0.8))
                .lineLimit(2)
                .frame(width: 94, alignment: .leading)
        }
    }
}

private struct LittleWinsShareGoalProgressChartView: View {
    let goal: LittleWinsShareGoalProgressData

    var body: some View {
        Chart {
            RuleMark(y: .value("Goal", goal.goalValue))
                .foregroundStyle(.white.opacity(0.44))
                .lineStyle(.init(lineWidth: 3, dash: [6, 4]))

            RuleMark(x: .value("Start", Calendar.current.startOfDay(for: goal.startDate)))
                .foregroundStyle(.green.opacity(0.92))
                .lineStyle(.init(lineWidth: 1.6, dash: [5, 5]))

            RuleMark(x: .value("End", Calendar.current.startOfDay(for: goal.endDate)))
                .foregroundStyle(.orange.opacity(0.92))
                .lineStyle(.init(lineWidth: 1.6, dash: [5, 5]))

            ForEach(goal.chartPoints) { point in
                LineMark(
                    x: .value("Date", Calendar.current.startOfDay(for: point.date)),
                    y: .value("Measure", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)

                PointMark(
                    x: .value("Date", Calendar.current.startOfDay(for: point.date)),
                    y: .value("Measure", point.value)
                )
                .symbol(.circle)
                .symbolSize(34)
                .foregroundStyle(Color(.systemBackground))
                .annotation(position: .overlay, alignment: .center) {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.7)
                        .frame(width: 7, height: 7)
                }
            }

            if let latest = goal.chartPoints.last {
                PointMark(
                    x: .value("Latest Date", Calendar.current.startOfDay(for: latest.date)),
                    y: .value("Latest Value", latest.value)
                )
                .symbol(.circle)
                .symbolSize(60)
                .foregroundStyle(goal.statusColor)
            }
        }
        .chartXScale(domain: chartDateDomain)
        .chartYScale(domain: chartValueDomain)
        .chartXAxis {
            AxisMarks(values: axisDates) { value in
                AxisGridLine(stroke: .init(dash: [2, 2]))
                    .foregroundStyle(.white.opacity(0.14))
                AxisTick(stroke: .init(lineWidth: 1))
                    .foregroundStyle(.white.opacity(0.24))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.14))
                AxisTick()
                    .foregroundStyle(.white.opacity(0.24))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...1))))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
            }
        }
    }

    private var chartDateDomain: ClosedRange<Date> {
        let lower = Calendar.current.startOfDay(for: goal.startDate)
        let upperBase = max(goal.endDate, goal.latestDate)
        let upper = Calendar.current.startOfDay(for: upperBase)
        return lower...upper
    }

    private var chartValueDomain: ClosedRange<Double> {
        let values = goal.chartPoints.map(\.value) + [goal.goalValue]
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max(1, abs(maxValue - minValue) * 0.18)
        return (minValue - padding)...(maxValue + padding)
    }

    private var axisDates: [Date] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: goal.startDate)
        let mid = calendar.date(byAdding: .day, value: max(1, calendar.dateComponents([.day], from: start, to: goal.endDate).day ?? 0) / 2, to: start) ?? start
        let end = calendar.startOfDay(for: goal.endDate)
        return [start, mid, end]
    }
}

private struct LittleWinsShareGoalArchiveChartView: View {
    let goal: LittleWinsShareAchievedGoalData

    var body: some View {
        Chart {
            if let goalValue = goal.goalValue {
                RuleMark(y: .value("Goal", goalValue))
                    .foregroundStyle(.white.opacity(0.44))
                    .lineStyle(.init(lineWidth: 3, dash: [6, 4]))
            }

            ForEach(goal.chartPoints) { point in
                LineMark(
                    x: .value("Date", Calendar.current.startOfDay(for: point.date)),
                    y: .value("Measure", point.value)
                )
                .interpolationMethod(.catmullRom)
                .foregroundStyle(.blue)

                PointMark(
                    x: .value("Date", Calendar.current.startOfDay(for: point.date)),
                    y: .value("Measure", point.value)
                )
                .symbol(.circle)
                .symbolSize(32)
                .foregroundStyle(Color(.systemBackground))
                .annotation(position: .overlay) {
                    Circle()
                        .stroke(Color.blue, lineWidth: 1.6)
                        .frame(width: 7, height: 7)
                }
            }
        }
        .chartXScale(domain: chartDateDomain)
        .chartYScale(domain: chartValueDomain)
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 3)) { value in
                AxisGridLine(stroke: .init(dash: [2, 2]))
                    .foregroundStyle(.white.opacity(0.14))
                AxisTick()
                    .foregroundStyle(.white.opacity(0.24))
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine()
                    .foregroundStyle(.white.opacity(0.14))
                AxisTick()
                    .foregroundStyle(.white.opacity(0.24))
                AxisValueLabel {
                    if let number = value.as(Double.self) {
                        Text(number.formatted(.number.precision(.fractionLength(0...1))))
                            .foregroundStyle(.white.opacity(0.66))
                    }
                }
            }
        }
    }

    private var chartDateDomain: ClosedRange<Date> {
        Calendar.current.startOfDay(for: goal.startDate)...Calendar.current.startOfDay(for: goal.endDate)
    }

    private var chartValueDomain: ClosedRange<Double> {
        let values = goal.chartPoints.map(\.value) + [goal.goalValue, goal.finalValue].compactMap { $0 }
        let minValue = values.min() ?? 0
        let maxValue = values.max() ?? 1
        let padding = max(1, abs(maxValue - minValue) * 0.18)
        return (minValue - padding)...(maxValue + padding)
    }
}

private extension View {
    func storyChartSurface() -> some View {
        self
            .padding(14)
            .background(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(Color.black.opacity(0.30))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
    }
}

private extension String {
    func nonEmptyOr(_ fallback: String) -> String {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? fallback : trimmed
    }
}
