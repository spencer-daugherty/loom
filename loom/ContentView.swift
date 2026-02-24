import SwiftUI
import Charts
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

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

struct ContentView: View {
    @AppStorage("enable_projects_feature") private var enableProjectsFeature = false
    @AppStorage("blank_homepage_mode") private var blankHomepageMode = false
    @AppStorage("setup_homepage_mode") private var setupHomepageMode = false
    @AppStorage("has_completed_plan_flow_once") private var hasCompletedPlanFlowOnce = false
    @State private var isPresentingCaptureView = false
    @State private var pressedEmotion: String? = nil
    @State private var pressedOutcome: Outcomes? = nil
    @State private var showVisionPurposePopup: Bool = false
    @State private var pressedCategoryTitle: String? = nil
    @State private var fulfillmentRadarSelectedIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase
    @Namespace private var graphNamespace
    @Namespace private var pageIndicatorNamespace
    @Namespace private var littleWinsCompletionNamespace
    @State private var showSplash: Bool = true
    @State private var splashMinimumElapsed: Bool = false
    @State private var splashPreparationFinished: Bool = false
    @State private var splashPreparationStarted: Bool = false
    @State private var measuredCardHeights: [String: CGFloat] = [:]
    @State private var showPlayBlockedHint: Bool = false
    @State private var playBlockedHintKind: PlayBlockedHintKind = .drivingAndFulfillmentForObjectives
    @State private var highlightDrivingRequirement: Bool = false
    @State private var highlightFulfillmentRequirement: Bool = false
    @State private var playBlockedResetWorkItem: DispatchWorkItem? = nil
    @State private var drivingCardBounceOn = false
    @State private var littleWinsLogoDotBounceOn = false
    @State private var homePageIndex: Int = 1
    @State private var measuredHeaderLogoWidth: CGFloat = 118
    @State private var littleWinsCardOrder: [UUID] = []
    @State private var littleWinsCompletedFocusIDs: Set<UUID> = []
    @State private var littleWinsCompletionStateHydrated = false
    @State private var littleWinsCalendarPreviewDate: Date? = nil
    @State private var littleWinsShowHiddenPlaceholder = false
    @State private var isPresentingLittleWinsManagerSheet = false
    @State private var littleWinsScheduleStoreRevision = 0
    @State private var littleWinsIntegrationStoreRevision = 0
    @State private var littleWinsIntegrationDetailTarget: LittleWinsIntegrationDetailTarget? = nil
    @State private var littleWinsAppleHealthRefreshInFlight = false
    @State private var littleWinsDeckDragX: CGFloat = 0
    @State private var littleWinsDeckIsDragging = false
    @State private var littleWinsSuppressRowTapUntil: Date = .distantPast
    @Environment(\.modelContext) private var modelContext
    private let drivingBounceTimer = Timer.publish(every: 2.0, on: .main, in: .common).autoconnect()

    // Model-derived state
    @Query(sort: \ActivePlanState.id, order: .forward)
    private var activePlanStates: [ActivePlanState]

    @State private var playSheetDestination: PlayDestination? = nil
    @State private var navigateToFulfillmentFromOnboarding = false

    private enum PlayDestination: String, Identifiable, Hashable {
        case action
        var id: String { rawValue }
    }

    private enum PlayBlockedHintKind {
        case drivingAndFulfillmentForObjectives
        case drivingForFulfillment
    }

    private enum HomeSwipePage: Int {
        case social = 0
        case home = 1
        case littleWins = 2
    }

    private var isActivePlan: Bool {
        activePlanStates.first?.isActive ?? false
    }

    private var isActiveActionFlow: Bool {
        isActivePlan
    }

    private var hasDrivingForceData: Bool {
        let ultimateVision = drivingForces.first?.ultimateVision ?? ""
        let ultimatePurpose = drivingForces.first?.ultimatePurpose ?? ""
        return !ultimateVision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !ultimatePurpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    private var shouldShowBlankHomepageAppearance: Bool {
        blankHomepageMode || setupHomepageMode
    }

    private var isDrivingForceEmptyState: Bool {
        shouldShowBlankHomepageAppearance || !hasDrivingForceData
    }

    private var isFulfillmentEmptyState: Bool {
        shouldShowBlankHomepageAppearance || fulfillmentMetrics.isEmpty
    }

    private var isObjectivesEmptyState: Bool {
        shouldShowBlankHomepageAppearance || (outcomes.isEmpty && !enableProjectsFeature)
    }

    private var areOnboardingPromptsVisible: Bool {
        isDrivingForceEmptyState && isFulfillmentEmptyState && isObjectivesEmptyState
    }

    private var shouldShowDrivingOnboardingPulse: Bool {
        areOnboardingPromptsVisible
    }

    private var shouldShowFulfillmentOnboardingPulse: Bool {
        !isDrivingForceEmptyState && isFulfillmentEmptyState
    }

    private var shouldShowAnyOnboardingBounce: Bool {
        shouldShowDrivingOnboardingPulse || shouldShowFulfillmentOnboardingPulse || shouldShowPlanButtonOnboardingBounce
    }

    private var shouldShowPlanButtonOnboardingBounce: Bool {
        !isDrivingForceEmptyState && !isFulfillmentEmptyState && !isActiveActionFlow
    }

    private var canOpenPlanOrActionFlow: Bool {
        if setupHomepageMode { return true }
        return !isDrivingForceEmptyState && !isFulfillmentEmptyState
    }

    private var splashMetricsFallback: [(String, Color, Double)] {
        [
            ("Area 1", FulfillmentCategoryTheme.color(for: "Career & Business"), 20),
            ("Area 2", FulfillmentCategoryTheme.color(for: "Leadership & Impact"), 20),
            ("Area 3", FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"), 20),
            ("Area 4", FulfillmentCategoryTheme.color(for: "Mind & Meaning"), 20),
            ("Area 5", FulfillmentCategoryTheme.color(for: "Love & Relationships"), 20),
            ("Area 6", FulfillmentCategoryTheme.color(for: "Health & Vitality"), 20),
        ]
    }

    private var splashMetrics: [(String, Color, Double)] {
        fulfillmentMetrics.isEmpty ? splashMetricsFallback : fulfillmentMetrics
    }
    
    private func daysUntil(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return components.day ?? 0
    }

    @ViewBuilder
    private func measuredCard<Content: View>(_ key: String, @ViewBuilder content: () -> Content) -> some View {
        content()
            .background(
                GeometryReader { proxy in
                    Color.clear
                        .preference(key: HomeCardHeightPreferenceKey.self, value: [key: proxy.size.height])
                }
            )
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGroupedBackground)
                    .ignoresSafeArea()

                GeometryReader { proxy in
                    let availableHeight = proxy.size.height - proxy.safeAreaInsets.top - proxy.safeAreaInsets.bottom
                    let cardSpacing: CGFloat = availableHeight < 760 ? 10 : (availableHeight > 900 ? 20 : 16)
                    let outerVerticalPadding: CGFloat = availableHeight < 760 ? 4 : (availableHeight > 900 ? 14 : 8)
                    let cardDensity: CGFloat = availableHeight < 760 ? 0.88 : (availableHeight > 900 ? 1.06 : 1.0)

                    ZStack {
                        // Background
                        Color(.systemGroupedBackground)
                            .edgesIgnoringSafeArea(.all)

                        // Main content with fixed top and bottom regions, and a flexible middle.
                        VStack(spacing: 10) {
                            header

                            TabView(selection: $homePageIndex) {
                                littleWinsMiddlePage()
                                    .tag(HomeSwipePage.social.rawValue)

                                centerHomepageMiddleContent(
                                    outerVerticalPadding: outerVerticalPadding,
                                    cardSpacing: cardSpacing,
                                    cardDensity: cardDensity
                                )
                                .safeAreaInset(edge: .bottom, spacing: 10) {
                                    VStack(spacing: 0) {
                                        footer
                                        Color.clear.frame(height: 8)
                                    }
                                }
                                .tag(HomeSwipePage.home.rawValue)

                                placeholderMiddlePage(title: "Sharing")
                                    .tag(HomeSwipePage.littleWins.rawValue)
                            }
                            .tabViewStyle(.page(indexDisplayMode: .never))
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onPreferenceChange(HomeCardHeightPreferenceKey.self) { heights in
                                var updated = measuredCardHeights
                                updated.merge(heights) { _, new in new }
                                if updated != measuredCardHeights {
                                    measuredCardHeights = updated
                                }
                            }
                            .environment(\.contentCardDensity, cardDensity)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)

                        if let emotion = pressedEmotion {
                            PassionPopupOverlay(
                                emotionTitle: displayTitle(for: emotion),
                                items: passions(for: emotion)
                            )
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .zIndex(1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pressedEmotion)
                        } else if showVisionPurposePopup {
                            VisionPurposePopupOverlay(
                                vision: (drivingForces.first?.ultimateVision ?? ""),
                                purpose: (drivingForces.first?.ultimatePurpose ?? "")
                            )
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .zIndex(1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: showVisionPurposePopup)
                        }
                        else if let selectedOutcome = pressedOutcome {
                            OutcomePopupOverlay(
                                outcome: selectedOutcome,
                                measure: latestMeasure(for: selectedOutcome)
                            )
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .zIndex(1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pressedOutcome)
                        }
                        else if let category = pressedCategoryTitle {
                            CategoryFulfillmentPopupOverlay(
                                category: category,
                                tint: categoryBackgroundColor(for: category),
                                titleColor: categoryTextColor(for: category),
                                vision: recordForCategory(category)?.category_vision ?? "",
                                purpose: recordForCategory(category)?.category_purpose ?? "",
                                roles: rolesForCategory(category).map { $0.role },
                                foci: fociForCategory(category).map { $0.activity },
                                resources: resourcesForCategory(category).map { $0.resource },
                                passions: passionsForCategory(category)
                            )
                            .allowsHitTesting(false)
                            .transition(.scale(scale: 0.9).combined(with: .opacity))
                            .zIndex(1)
                            .animation(.spring(response: 0.3, dampingFraction: 0.85), value: pressedCategoryTitle)
                        }
                    }
                    .frame(width: proxy.size.width, height: proxy.size.height, alignment: .top)
                }
                .opacity(showSplash ? 0.001 : 1)
                .allowsHitTesting(!showSplash)

                if showSplash {
                    LoadingSplashView(
                        metrics: splashMetrics,
                        namespace: graphNamespace,
                        minimumDisplayDuration: 3.0,
                        onMinimumElapsed: {
                            Task { @MainActor in
                                splashMinimumElapsed = true
                                dismissSplashIfReady()
                            }
                        }
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }
            }
            .ignoresSafeArea(.keyboard)
        }
        .navigationDestination(isPresented: $navigateToFulfillmentFromOnboarding) {
            FulfillmentView()
        }
        .fullScreenCover(item: $playSheetDestination) { destination in
            switch destination {
            case .action:
                ActionView()
            }
        }
        .sheet(isPresented: $isPresentingCaptureView) {
            CaptureView()
                .presentationDragIndicator(.visible)
        }
        .sheet(isPresented: $isPresentingLittleWinsManagerSheet) {
            ContentLittleWinsManagerSheetView(
                categories: orderedFulfillmentRecords.map { ($0.category_id, $0.category) }
            )
        }
        .onChange(of: isActivePlan) { _, newValue in
            // When Plan Step 5 activates the plan, automatically launch ActionView.
            if newValue == true {
                playSheetDestination = .action
            }
        }
        .onAppear {
            beginStartupPreparationIfNeeded()
            if shouldShowAnyOnboardingBounce {
                bounceDrivingCardOnce()
            }
            if shouldShowLittleWinsLogoDot {
                bounceLittleWinsLogoDotOnce()
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: Notification.Name("open_fulfillment_after_onboarding"))) { _ in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                navigateToFulfillmentFromOnboarding = true
            }
        }
        .onChange(of: shouldShowAnyOnboardingBounce) { _, shouldShow in
            if shouldShow {
                bounceDrivingCardOnce()
            } else {
                drivingCardBounceOn = false
            }
        }
        .onChange(of: shouldShowLittleWinsLogoDot) { _, shouldShow in
            if shouldShow {
                bounceLittleWinsLogoDotOnce()
            } else {
                littleWinsLogoDotBounceOn = false
            }
        }
        .onReceive(drivingBounceTimer) { _ in
            guard shouldShowAnyOnboardingBounce else { return }
            bounceDrivingCardOnce()
        }
        .onReceive(drivingBounceTimer) { _ in
            guard shouldShowLittleWinsLogoDot else { return }
            bounceLittleWinsLogoDotOnce()
        }
        .tint(Color.accentColor)
        .ignoresSafeArea(.keyboard)
    }

    @MainActor
    private func beginStartupPreparationIfNeeded() {
        guard !splashPreparationStarted else { return }
        splashPreparationStarted = true

        Task { @MainActor in
            await runStartupPreparation()
            splashPreparationFinished = true
            dismissSplashIfReady()
        }
    }

    @MainActor
    private func dismissSplashIfReady() {
        guard showSplash, splashMinimumElapsed, splashPreparationFinished else { return }
        withAnimation(.easeInOut(duration: 0.6)) {
            showSplash = false
        }
    }

    @MainActor
    private func runStartupPreparation() async {
        // 1) Read-only startup warmup (no first-launch data insertion).
        warmupFetch(ActivePlanState.self)
        await Task.yield()

        // 2) Housekeeping.
        RecentlyDeletedStore.purgeExpired(in: modelContext)
        await Task.yield()

        // 3) Warm up a few commonly used model tables to reduce first-open jank.
        warmupFetch(DrivingForce.self)
        warmupFetch(Fulfillment.self)
        warmupFetch(Outcomes.self)
        warmupFetch(PlanLabel.self)
        warmupFetch(PlannedChunkAction.self)
        warmupFetch(RollingCaptureItem.self)
        warmupFetch(ActionBlocksReflectionArchive.self)

        try? modelContext.save()
    }

    @MainActor
    private func warmupFetch<T: PersistentModel>(_ type: T.Type) {
        var descriptor = FetchDescriptor<T>()
        descriptor.fetchLimit = 1
        _ = try? modelContext.fetch(descriptor)
    }

    @Query(sort: \DrivingForce.updatedAt, order: .reverse)
    private var drivingForces: [DrivingForce]
    
    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]
    
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse)
    private var outcomeMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward)
    private var outcomeMeasureEntries: [OutcomesMeasureEntry]

    @Query(sort: \Passion.date, order: .forward)
    private var passions: [Passion]
    
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward)
    private var passionJoins: [PassionFulfillmentJoin]

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query(sort: \LittleWinsDailyCompletion.completedAt, order: .reverse)
    private var littleWinsDailyCompletions: [LittleWinsDailyCompletion]
    @Query(sort: \ActionBlocksReflectionArchive.completedAt, order: .reverse)
    private var reflectionArchives: [ActionBlocksReflectionArchive]

    // MARK: - Helpers to simplify complex expressions
    private func categoryTextColor(for category: String) -> Color {
        FulfillmentCategoryTheme.color(for: category)
    }

    private func categoryBaseUIColor(for category: String) -> UIColor {
        UIColor(FulfillmentCategoryTheme.color(for: category))
    }

    private func lightenedColor(from base: UIColor, factor: CGFloat = 0.8) -> Color {
        return Color(UIColor { trait in
            var red: CGFloat = 0
            var green: CGFloat = 0
            var blue: CGFloat = 0
            var alpha: CGFloat = 0
            base.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            // In dark mode, lighten less to avoid low contrast; in light mode, keep original factor
            let f: CGFloat = trait.userInterfaceStyle == .dark ? 0.4 : factor
            red += (1.0 - red) * f
            green += (1.0 - green) * f
            blue += (1.0 - blue) * f
            return UIColor(red: red, green: green, blue: blue, alpha: alpha)
        })
    }

    private func categoryBackgroundColor(for category: String) -> Color {
        lightenedColor(from: categoryBaseUIColor(for: category))
    }

    private struct ObjectivesCardListRow: Identifiable {
        enum Kind {
            case outcome(Outcomes)
            case upcomingOutcome(Outcomes, startsInDays: Int)
        }

        let id: String
        let kind: Kind
    }

    private func objectivesCardPreviewRows(limit: Int = 4) -> [ObjectivesCardListRow] {
        let currentDate = Date()
        let activeOutcomes = outcomes.filter { $0.start <= currentDate }
        let activeOutcomeRows = activeOutcomes.prefix(limit).map { outcome in
            ObjectivesCardListRow(
                id: "outcome-\(outcome.outcome_id.uuidString)",
                kind: .outcome(outcome)
            )
        }
        let remainingSlots = max(0, limit - activeOutcomeRows.count)
        guard remainingSlots > 0 else { return Array(activeOutcomeRows) }

        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: currentDate)
        let upcomingOutcomes = outcomes
            .filter { calendar.startOfDay(for: $0.start) > startOfToday }
            .sorted { lhs, rhs in
                let lhsStart = calendar.startOfDay(for: lhs.start)
                let rhsStart = calendar.startOfDay(for: rhs.start)
                if lhsStart != rhsStart { return lhsStart < rhsStart }
                return lhs.rank < rhs.rank
            }
            .prefix(remainingSlots)
            .map { outcome in
                let daysToStart = max(0, calendar.dateComponents([.day], from: currentDate, to: outcome.start).day ?? 0)
                return ObjectivesCardListRow(
                    id: "upcoming-outcome-\(outcome.outcome_id.uuidString)",
                    kind: .upcomingOutcome(outcome, startsInDays: daysToStart)
                )
            }

        return Array(activeOutcomeRows) + upcomingOutcomes
    }

    private func emotionKey(for label: String) -> String {
        // Map display label used in UI to the stored emotion key
        switch label {
        case "hate":
            return "just"    // 'Hate' is stored as 'just' in the model
        default:
            return label
        }
    }

    private func displayTitle(for emotionKey: String) -> String {
        switch emotionKey {
        case "love": return "Love"
        case "vows": return "Vows"
        case "thrill": return "Thrill"
        case "just": return "Hate"
        default: return emotionKey.capitalized
        }
    }

    private func passions(for emotionKey: String) -> [Passion] {
        passions.filter { $0.emotion == emotionKey }
    }
    
    private func recordForCategory(_ categoryTitle: String) -> Fulfillment? {
        fulfillments.first { $0.category == categoryTitle }
    }

    private func recordForCategoryID(_ categoryID: UUID) -> Fulfillment? {
        fulfillments.first { $0.category_id == categoryID }
    }

    private func rolesForCategory(_ categoryTitle: String) -> [FulfillmentRoles] {
        guard let rec = recordForCategory(categoryTitle) else { return [] }
        return roles.filter { $0.category_id == rec.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func fociForCategory(_ categoryTitle: String) -> [FulfillmentFocus] {
        guard let rec = recordForCategory(categoryTitle) else { return [] }
        return foci.filter { $0.category_id == rec.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func fociForCategoryID(_ categoryID: UUID) -> [FulfillmentFocus] {
        foci.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private struct LittleWinsCardData: Identifiable {
        let id: UUID
        let categoryTitle: String
        let cardColor: Color
        let titleColor: Color
        let items: [FulfillmentFocus]
        let activeTodayItemIDs: Set<UUID>
    }

    private struct LittleWinsIntegrationDetailTarget: Identifiable {
        let focusID: UUID
        var id: UUID { focusID }
    }

    private struct LittleWinsHistoricalCompletionItem: Identifiable {
        let id: UUID
        let focusId: UUID
        let categoryId: UUID?
        let categoryTitle: String
        let focusTitle: String
        let completedAt: Date
        let categoryFocusCountSnapshot: Int?
    }

    private struct LittleWinsHistoricalDayCategory: Identifiable {
        let id: String
        let categoryId: UUID?
        let categoryTitle: String
        let items: [LittleWinsHistoricalCompletionItem]
        let requiredFocusCount: Int?

        var completedFocusCount: Int {
            Set(items.map(\.focusId)).count
        }

        var isCompletedCard: Bool {
            guard let requiredFocusCount, requiredFocusCount > 0 else { return false }
            return completedFocusCount >= requiredFocusCount
        }
    }

    private func littleWinsWeekdayBit(for date: Date) -> Int {
        let weekday = Calendar.current.component(.weekday, from: date) // 1=Sun...7=Sat
        return 1 << max(0, min(6, weekday - 1))
    }

    private func littleWinsScheduleRule(for focus: FulfillmentFocus) -> LittleWinsScheduleRule {
        LittleWinsScheduleStore.rule(for: focus.id)
    }

    private func littleWinsIntegrationConfig(for focus: FulfillmentFocus) -> LittleWinsIntegrationConfig? {
        _ = littleWinsIntegrationStoreRevision
        return LittleWinsIntegrationStore.config(for: focus.id)
    }

    private func isLittleWinIntegrated(_ focus: FulfillmentFocus) -> Bool {
        guard let config = littleWinsIntegrationConfig(for: focus) else { return false }
        return config.isEnabled
    }

    private func isLittleWinFocusActive(_ focus: FulfillmentFocus, on date: Date) -> Bool {
        let rule = littleWinsScheduleRule(for: focus)
        if rule.canCompleteAnyDay { return true }
        return (rule.activeWeekdayMask & littleWinsWeekdayBit(for: date)) != 0
    }

    private func littleWinsWeekdaySummary(mask: Int) -> String {
        let normalizedMask = mask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = labels.enumerated().compactMap { index, label in
            (normalizedMask & (1 << index)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func littleWinsActiveDaysSummary(for card: LittleWinsCardData) -> String? {
        guard !card.items.isEmpty else { return nil }
        var unionMask = 0
        var hasRestricted = false
        for item in card.items {
            let rule = littleWinsScheduleRule(for: item)
            if rule.canCompleteAnyDay { continue }
            hasRestricted = true
            unionMask |= (rule.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask)
        }
        guard hasRestricted else { return nil }
        return littleWinsWeekdaySummary(mask: unionMask)
    }

    private func littleWinsCards(showHidden: Bool) -> [LittleWinsCardData] {
        _ = littleWinsScheduleStoreRevision
        let filterDate = todayStartDate
        let completedToday = littleWinsCompletionStateHydrated
            ? littleWinsCompletedFocusIDs
            : littleWinsCompletedFocusIDsFromStoreToday
        let sourceCards = orderedFulfillmentRecords.compactMap { record -> LittleWinsCardData? in
            let allWins = fociForCategoryID(record.category_id)
                .filter { !$0.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            let activeWins = allWins.filter { isLittleWinFocusActive($0, on: filterDate) }
            let activeWinIDs = Set(activeWins.map(\.id))
            let displayedWins = showHidden
                ? allWins
                : allWins.filter { activeWinIDs.contains($0.id) || completedToday.contains($0.id) }
            guard !displayedWins.isEmpty else { return nil }
            return LittleWinsCardData(
                id: record.category_id,
                categoryTitle: record.category,
                cardColor: FulfillmentCategoryTheme.lightColor(for: record.category),
                titleColor: FulfillmentCategoryTheme.color(for: record.category),
                items: displayedWins,
                activeTodayItemIDs: Set(activeWins.map(\.id))
            )
        }

        guard !littleWinsCardOrder.isEmpty else { return sourceCards }
        let byID = Dictionary(uniqueKeysWithValues: sourceCards.map { ($0.id, $0) })
        var ordered: [LittleWinsCardData] = []
        for id in littleWinsCardOrder {
            if let card = byID[id] { ordered.append(card) }
        }
        let remaining = sourceCards.filter { card in !littleWinsCardOrder.contains(card.id) }
        ordered.append(contentsOf: remaining)
        return ordered
    }

    private var littleWinsCards: [LittleWinsCardData] {
        littleWinsCards(showHidden: littleWinsShowHiddenPlaceholder)
    }

    private var littleWinsCardsIncludingHiddenToday: [LittleWinsCardData] {
        littleWinsCards(showHidden: true)
    }

    private var littleWinsSourceCardIDs: [UUID] {
        orderedFulfillmentRecords.compactMap { record in
            let hasWins = foci.contains {
                $0.category_id == record.category_id &&
                !$0.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            return hasWins ? record.category_id : nil
        }
    }

    private func syncLittleWinsCardOrder() {
        let sourceIDs = littleWinsSourceCardIDs
        let sourceIDSet = Set(sourceIDs)
        var next = littleWinsCardOrder.filter { sourceIDSet.contains($0) }
        for id in sourceIDs where !next.contains(id) {
            next.append(id)
        }
        if next != littleWinsCardOrder {
            littleWinsCardOrder = next
        }
    }

    private func isLittleWinsCardCompleted(_ card: LittleWinsCardData) -> Bool {
        let completedFocusIDs = littleWinsCompletionStateHydrated
            ? littleWinsCompletedFocusIDs
            : littleWinsCompletedFocusIDsFromStoreToday
        if littleWinsShowHiddenPlaceholder {
            return !card.items.isEmpty && card.items.allSatisfy { completedFocusIDs.contains($0.id) }
        }
        let eligibleIDs = card.activeTodayItemIDs
        if eligibleIDs.isEmpty {
            return !card.items.isEmpty && card.items.allSatisfy { completedFocusIDs.contains($0.id) }
        }
        return eligibleIDs.allSatisfy { completedFocusIDs.contains($0) }
    }

    private func isLittleWinsCardCompletedForActiveTodayStreak(_ card: LittleWinsCardData) -> Bool {
        let completedFocusIDs = littleWinsCompletionStateHydrated
            ? littleWinsCompletedFocusIDs
            : littleWinsCompletedFocusIDsFromStoreToday
        let eligibleIDs = card.activeTodayItemIDs
        guard !eligibleIDs.isEmpty else { return false }
        return eligibleIDs.allSatisfy { completedFocusIDs.contains($0) }
    }

    private var hasIncompleteLittleWinsCards: Bool {
        littleWinsCards.contains { !isLittleWinsCardCompleted($0) }
    }

    private var shouldShowLittleWinsLogoDot: Bool {
        homePageIndex == HomeSwipePage.home.rawValue && hasIncompleteLittleWinsCards
    }

    private var littleWinsHiddenClockIconName: String {
        #if canImport(UIKit)
        let candidates = [
            "clock.arrow.trianglehead.clockwise.rotate.90.path.dotted",
            "clock.arrow.circlepath",
            "clock"
        ]
        for name in candidates where UIImage(systemName: name) != nil {
            return name
        }
        return "clock"
        #else
        return "clock"
        #endif
    }

    private var todayStartDate: Date {
        Calendar.current.startOfDay(for: Date())
    }

    private func currentLittleWinsFocusCount(
        for categoryID: UUID,
        on date: Date = Calendar.current.startOfDay(for: Date())
    ) -> Int? {
        let count = foci.filter {
            $0.category_id == categoryID &&
            !$0.activity.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            isLittleWinFocusActive($0, on: date)
        }.count
        return count > 0 ? count : nil
    }

    private func littleWinsCompletionRecords(on date: Date) -> [LittleWinsDailyCompletion] {
        let calendar = Calendar.current
        return littleWinsDailyCompletions.filter { calendar.isDate($0.day, inSameDayAs: date) }
    }

    private func littleWinsHistoricalCompletionItems(on date: Date) -> [LittleWinsHistoricalCompletionItem] {
        let records = littleWinsCompletionRecords(on: date)
        guard !records.isEmpty else { return [] }

        var latestByFocusID: [UUID: LittleWinsHistoricalCompletionItem] = [:]
        let sorted = records.sorted { $0.completedAt < $1.completedAt }

        for record in sorted {
            let currentFocus = foci.first { $0.id == record.focusId }
            let resolvedCategoryID = record.categoryIdSnapshot ?? currentFocus?.category_id
            let snapshotCategoryTitle = record.categoryTitleSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines)
            let snapshotFocusTitle = record.focusTitleSnapshot?.trimmingCharacters(in: .whitespacesAndNewlines)
            let currentCategoryTitle = resolvedCategoryID.flatMap { recordForCategoryID($0)?.category }
            let currentFocusTitle = currentFocus?.activity.trimmingCharacters(in: .whitespacesAndNewlines)

            let categoryTitle = (snapshotCategoryTitle?.isEmpty == false ? snapshotCategoryTitle : nil)
                ?? currentCategoryTitle
                ?? "Archived Little Wins"
            let focusTitle = (snapshotFocusTitle?.isEmpty == false ? snapshotFocusTitle : nil)
                ?? (currentFocusTitle?.isEmpty == false ? currentFocusTitle : nil)
                ?? "Completed Action"
            let requiredCount = record.categoryFocusCountSnapshot
                ?? resolvedCategoryID.flatMap { currentLittleWinsFocusCount(for: $0) }

            latestByFocusID[record.focusId] = LittleWinsHistoricalCompletionItem(
                id: record.id,
                focusId: record.focusId,
                categoryId: resolvedCategoryID,
                categoryTitle: categoryTitle,
                focusTitle: focusTitle,
                completedAt: record.completedAt,
                categoryFocusCountSnapshot: requiredCount
            )
        }

        return latestByFocusID.values.sorted { lhs, rhs in
            if lhs.completedAt == rhs.completedAt {
                return lhs.focusTitle.localizedCaseInsensitiveCompare(rhs.focusTitle) == .orderedAscending
            }
            return lhs.completedAt < rhs.completedAt
        }
    }

    private func littleWinsHistoricalCategories(on date: Date) -> [LittleWinsHistoricalDayCategory] {
        let items = littleWinsHistoricalCompletionItems(on: date)
        guard !items.isEmpty else { return [] }

        let grouped = Dictionary(grouping: items) { item in
            item.categoryId?.uuidString ?? "title:\(item.categoryTitle.lowercased())"
        }

        return grouped.compactMap { key, groupItems in
            let sortedItems = groupItems.sorted { $0.completedAt < $1.completedAt }
            let latestRequiredCount = sortedItems.compactMap(\.categoryFocusCountSnapshot).max()
            let first = sortedItems.first
            return LittleWinsHistoricalDayCategory(
                id: key,
                categoryId: first?.categoryId,
                categoryTitle: first?.categoryTitle ?? "Archived Little Wins",
                items: sortedItems,
                requiredFocusCount: latestRequiredCount
            )
        }
        .sorted { lhs, rhs in
            let lhsDate = lhs.items.last?.completedAt ?? .distantPast
            let rhsDate = rhs.items.last?.completedAt ?? .distantPast
            if lhsDate == rhsDate {
                return lhs.categoryTitle.localizedCaseInsensitiveCompare(rhs.categoryTitle) == .orderedAscending
            }
            return lhsDate > rhsDate
        }
    }

    private func littleWinsHistoricalCompletedCardSnapshots(on date: Date) -> [LittleWinsCardData] {
        littleWinsHistoricalCategories(on: date)
            .filter(\.isCompletedCard)
            .map { category in
                LittleWinsCardData(
                    id: category.categoryId ?? UUID(),
                    categoryTitle: category.categoryTitle,
                    cardColor: FulfillmentCategoryTheme.lightColor(for: category.categoryTitle),
                    titleColor: FulfillmentCategoryTheme.color(for: category.categoryTitle),
                    items: [],
                    activeTodayItemIDs: Set<UUID>()
                )
            }
    }

    private var littleWinsCompletedFocusIDsFromStoreToday: Set<UUID> {
        let calendar = Calendar.current
        return Set(
            littleWinsDailyCompletions
                .filter { calendar.isDate($0.day, inSameDayAs: todayStartDate) }
                .map(\.focusId)
        )
    }

    private func syncLittleWinsCompletionStateFromStore() {
        let ids = littleWinsCompletedFocusIDsFromStoreToday
        if ids != littleWinsCompletedFocusIDs {
            littleWinsCompletedFocusIDs = ids
        }
        littleWinsCompletionStateHydrated = true
    }

    private func syncIntegratedLittleWinsCompletionsFromProgress() {
        _ = littleWinsIntegrationStoreRevision
        let calendar = Calendar.current
        var insertedAny = false

        for focus in foci {
            let title = focus.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { continue }
            guard let config = LittleWinsIntegrationStore.config(for: focus.id), config.isEnabled, config.isGoalAchieved else { continue }

            let alreadyCompletedToday = littleWinsDailyCompletions.contains {
                $0.focusId == focus.id && calendar.isDate($0.day, inSameDayAs: todayStartDate)
            }
            guard !alreadyCompletedToday else { continue }

            let categoryID = focus.category_id
            let categoryTitle = recordForCategoryID(categoryID)?.category
            let categoryFocusCount = currentLittleWinsFocusCount(for: categoryID, on: todayStartDate)
            modelContext.insert(
                LittleWinsDailyCompletion(
                    focusId: focus.id,
                    day: todayStartDate,
                    completedAt: .now,
                    categoryIdSnapshot: categoryID,
                    categoryTitleSnapshot: categoryTitle,
                    focusTitleSnapshot: title,
                    categoryFocusCountSnapshot: categoryFocusCount
                )
            )
            insertedAny = true
        }

        if insertedAny {
            try? modelContext.save()
            syncLittleWinsCompletionStateFromStore()
        }
    }

    private func insertIntegratedLittleWinCompletionIfNeeded(
        focus: FulfillmentFocus,
        on day: Date,
        completionTimestamp: Date
    ) -> Bool {
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: day)
        guard isLittleWinFocusActive(focus, on: dayStart) else { return false }

        let exists = littleWinsDailyCompletions.contains {
            $0.focusId == focus.id && calendar.isDate($0.day, inSameDayAs: dayStart)
        }
        guard !exists else { return false }

        let title = focus.activity.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !title.isEmpty else { return false }

        let categoryID = focus.category_id
        let categoryTitle = recordForCategoryID(categoryID)?.category
        let categoryFocusCount = currentLittleWinsFocusCount(for: categoryID, on: dayStart)

        modelContext.insert(
            LittleWinsDailyCompletion(
                focusId: focus.id,
                day: dayStart,
                completedAt: completionTimestamp,
                categoryIdSnapshot: categoryID,
                categoryTitleSnapshot: categoryTitle,
                focusTitleSnapshot: title,
                categoryFocusCountSnapshot: categoryFocusCount
            )
        )
        return true
    }

    private func refreshAppleHealthIntegratedLittleWinsProgressIfNeeded() {
        guard !littleWinsAppleHealthRefreshInFlight else { return }

        let targets: [(focus: FulfillmentFocus, config: LittleWinsIntegrationConfig)] = foci.compactMap { focus in
            let title = focus.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty else { return nil }
            guard let config = LittleWinsIntegrationStore.config(for: focus.id) else { return nil }
            guard config.isEnabled, config.isConnected, config.source == .appleHealth else { return nil }
            return (focus, config)
        }

        guard !targets.isEmpty else { return }
        littleWinsAppleHealthRefreshInFlight = true
        let calendar = Calendar.current
        let lookbackDates: [Date] = (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -offset, to: todayStartDate)
        }
        var insertedAny = false
        var savedAnyConfig = false

        func refreshNext(_ index: Int) {
            if index >= targets.count {
                if insertedAny {
                    try? modelContext.save()
                    syncLittleWinsCompletionStateFromStore()
                }
                littleWinsAppleHealthRefreshInFlight = false
                if savedAnyConfig {
                    littleWinsIntegrationStoreRevision &+= 1
                }
                syncIntegratedLittleWinsCompletionsFromProgress()
                return
            }

            let target = targets[index]
            var progressByDayStart: [Date: Double] = [:]

            func refreshDay(_ dayIndex: Int) {
                if dayIndex >= lookbackDates.count {
                    if let todayProgress = progressByDayStart[todayStartDate] {
                        var updated = target.config
                        let normalizedProgress = max(0, todayProgress)
                        if abs(updated.progressValue - normalizedProgress) > 0.0001 {
                            updated.progressValue = normalizedProgress
                            updated.updatedAtUnix = Date().timeIntervalSince1970
                            LittleWinsIntegrationStore.setConfig(updated, for: target.focus.id)
                            savedAnyConfig = true
                        }
                    }

                    for day in lookbackDates {
                        let dayStart = calendar.startOfDay(for: day)
                        guard let progress = progressByDayStart[dayStart] else { continue }
                        guard progress >= target.config.targetValue else { continue }
                        let completionStamp = (dayIndexForDate(dayStart, in: lookbackDates) == 0)
                            ? Date()
                            : (calendar.date(bySettingHour: 23, minute: 59, second: 0, of: dayStart) ?? dayStart)
                        if insertIntegratedLittleWinCompletionIfNeeded(
                            focus: target.focus,
                            on: dayStart,
                            completionTimestamp: completionStamp
                        ) {
                            insertedAny = true
                        }
                    }

                    refreshNext(index + 1)
                    return
                }

                let day = lookbackDates[dayIndex]
                LittleWinsHealthKitBridge.readProgress(for: target.config.metric, on: day) { result in
                    DispatchQueue.main.async {
                        if case .success(let progress) = result {
                            progressByDayStart[calendar.startOfDay(for: day)] = max(0, progress)
                        }
                        refreshDay(dayIndex + 1)
                    }
                }
            }

            refreshDay(0)
        }

        refreshNext(0)
    }

    private func dayIndexForDate(_ date: Date, in dates: [Date]) -> Int? {
        let calendar = Calendar.current
        return dates.firstIndex { calendar.isDate($0, inSameDayAs: date) }
    }

    private func littleWinsIntegrationDetailRows(for focus: FulfillmentFocus) -> [(String, String)] {
        guard let config = littleWinsIntegrationConfig(for: focus) else { return [] }
        let numberFormatter: NumberFormatter = {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.groupingSeparator = Locale.current.groupingSeparator
            formatter.usesGroupingSeparator = true
            formatter.maximumFractionDigits = (config.metric == .sleepHours) ? 1 : 0
            formatter.minimumFractionDigits = 0
            return formatter
        }()
        let formattedProgress = numberFormatter.string(from: NSNumber(value: config.progressValue)) ?? "\(config.progressValue)"
        let formattedTarget = numberFormatter.string(from: NSNumber(value: config.targetValue)) ?? "\(config.targetValue)"
        let progressText: String
        progressText = "\(formattedProgress) / \(formattedTarget) \(config.metric.unitLabel)"
        let statusText = config.isGoalAchieved ? "Goal achieved" : "In progress"
        let connectedText = config.isConnected ? "Connected" : "Not connected"
        let lastSyncText: String? = {
            guard config.updatedAtUnix > 0 else { return nil }
            let formatter = DateFormatter()
            formatter.dateStyle = .none
            formatter.timeStyle = .short
            return formatter.string(from: Date(timeIntervalSince1970: config.updatedAtUnix))
        }()

        var rows: [(String, String)] = [
            ("Source", config.source.title),
            ("Metric", config.metric.title),
            ("Progress", progressText),
            ("Status", statusText),
            ("Connection", connectedText)
        ]
        if config.source == .screenTime,
           let summary = config.screenTimeSelectionSummary,
           !summary.isEmpty {
            rows.append(("Selection", summary))
        }
        if let lastSyncText {
            rows.append(("Last sync", lastSyncText))
        }
        return rows
    }

    @ViewBuilder
    private func littleWinsIntegratedIndicator(
        config: LittleWinsIntegrationConfig,
        isCompleted: Bool,
        isDashedHiddenIndicator: Bool,
        titleColor: Color,
        fixedSecondaryText: Color
    ) -> some View {
        let progress = CGFloat(config.progressFraction)
        ZStack {
            Circle()
                .stroke((isDashedHiddenIndicator ? Color.blue : fixedSecondaryText), lineWidth: 2)
                .frame(width: 22, height: 22)

            if progress > 0 && !isCompleted {
                Circle()
                    .trim(from: 0, to: progress)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: 2.4, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .frame(width: 22, height: 22)
            }

            if isDashedHiddenIndicator && !isCompleted {
                Circle()
                    .stroke(style: StrokeStyle(lineWidth: 2, dash: [4]))
                    .foregroundStyle(.blue)
                    .frame(width: 22, height: 22)
            }

            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 26, weight: .regular))
                    .foregroundStyle(titleColor)
            } else {
                Image(systemName: "link")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(isDashedHiddenIndicator ? .blue : fixedSecondaryText)
            }
        }
        .frame(width: 30, alignment: .center)
    }

    private func presentLittleWinsIntegrationDetails(for item: FulfillmentFocus) {
        littleWinsIntegrationDetailTarget = .init(focusID: item.id)
    }

    private func persistLittleWinToggle(focusId: UUID, isCompleted: Bool) {
        let calendar = Calendar.current
        if isCompleted {
            if let existing = littleWinsDailyCompletions.first(where: {
                $0.focusId == focusId && calendar.isDate($0.day, inSameDayAs: todayStartDate)
            }) {
                modelContext.delete(existing)
            }
        } else if littleWinsDailyCompletions.first(where: {
            $0.focusId == focusId && calendar.isDate($0.day, inSameDayAs: todayStartDate)
        }) == nil {
            let focus = foci.first { $0.id == focusId }
            let categoryID = focus?.category_id
            let categoryTitle = categoryID.flatMap { recordForCategoryID($0)?.category }
            let focusTitle = focus?.activity.trimmingCharacters(in: .whitespacesAndNewlines)
            let categoryFocusCount = categoryID.flatMap { currentLittleWinsFocusCount(for: $0, on: todayStartDate) }
            modelContext.insert(
                LittleWinsDailyCompletion(
                    focusId: focusId,
                    day: todayStartDate,
                    completedAt: .now,
                    categoryIdSnapshot: categoryID,
                    categoryTitleSnapshot: categoryTitle,
                    focusTitleSnapshot: focusTitle,
                    categoryFocusCountSnapshot: categoryFocusCount
                )
            )
        }
        try? modelContext.save()
    }

    private func resourcesForCategory(_ categoryTitle: String) -> [FulfillmentResources] {
        guard let rec = recordForCategory(categoryTitle) else { return [] }
        return resources.filter { $0.category_id == rec.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func passionsForCategory(_ categoryTitle: String) -> [Passion] {
        guard let rec = recordForCategory(categoryTitle) else { return [] }
        let ids = passionJoins.filter { $0.category_id == rec.category_id }.map { $0.passion_id }
        let idSet = Set(ids)
        return passions.filter { idSet.contains($0.passion_id) }
    }

    private func usagePoints(for emotionLabel: String) -> Int {
        let key = emotionKey(for: emotionLabel)
        let ids = Set(passions.filter { $0.emotion == key }.map { $0.passion_id })
        let count = passionJoins.filter { ids.contains($0.passion_id) }.count
        return min(4, count)
    }

    private func categoryKey(_ raw: String) -> String {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !trimmed.isEmpty else { return "" }
        let andNormalized = trimmed.replacingOccurrences(of: "&", with: " and ")
        let cleaned = andNormalized.replacingOccurrences(
            of: "[^a-z0-9]+",
            with: " ",
            options: .regularExpression
        )
        return cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
    }

    private var orderedFulfillmentRecords: [Fulfillment] {
        let defaults: [(String, UUID)] = [
            ("Career & Business", PlanLabelSeeder.categoryIDs["Career & Business"]!),
            ("Leadership & Impact", PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
            ("Wealth & Lifestyle", PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
            ("Mind & Meaning", PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
            ("Love & Relationships", PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
            ("Health & Vitality", PlanLabelSeeder.categoryIDs["Health & Vitality"]!)
        ]

        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        var seen = Set<String>()
        for (_, id) in defaults {
            if let record = byID.removeValue(forKey: id) {
                let key = categoryKey(record.category)
                guard !key.isEmpty, !seen.contains(key) else { continue }
                ordered.append(record)
                seen.insert(key)
            }
        }
        let extras = byID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { row in
                let key = categoryKey(row.category)
                guard !key.isEmpty, !seen.contains(key) else { return false }
                seen.insert(key)
                return true
            }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        ordered.append(contentsOf: extras)
        return Array(ordered.prefix(7))
    }

    private func completionCount(for record: Fulfillment) -> Int {
        let hasVision = !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRole = roles.contains { $0.category_id == record.category_id }
        let hasFocus = foci.contains { $0.category_id == record.category_id }
        let hasResource = resources.contains { $0.category_id == record.category_id }
        let passionIDs = Set(passions.map(\.passion_id))
        let hasPassion = passionJoins.contains { $0.category_id == record.category_id && passionIDs.contains($0.passion_id) }
        return [hasVision, hasPurpose, hasRole, hasFocus, hasResource, hasPassion].filter { $0 }.count
    }

    private func batteryPercentage(for record: Fulfillment) -> Double {
        let count = completionCount(for: record)
        switch count {
        case 0: return 0
        case 1...2: return 25
        case 3...4: return 50
        case 5: return 75
        default: return 100
        }
    }

    private func progressTrim(for measure: OutcomesMeasure, outcomeID: UUID) -> Double {
        let start = outcomeMeasureEntries.first(where: { $0.outcome_id == outcomeID })?.measure ?? measure.measure
        return ProgressCircleView.progressValue(current: measure.measure, goal: measure.measure_amt, start: start)
    }

    private func latestMeasure(for outcome: Outcomes) -> OutcomesMeasure? {
        let snapshot = outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
        let latestEntry = outcomeMeasureEntries
            .filter { $0.outcome_id == outcome.outcome_id }
            .max(by: { $0.measuredAt < $1.measuredAt })

        guard snapshot != nil || latestEntry != nil else { return nil }

        return OutcomesMeasure(
            outcome_id: outcome.outcome_id,
            measure: latestEntry?.measure ?? snapshot?.measure ?? 0,
            measuredAt: latestEntry?.measuredAt ?? snapshot?.measuredAt ?? .now,
            measure_amt: snapshot?.measure_amt ?? latestEntry?.measure_amt ?? 0,
            measure_updated: snapshot?.measure_updated ?? .now,
            direction: nil,
            format: snapshot?.format ?? latestEntry?.format,
            unit: snapshot?.unit ?? latestEntry?.unit,
            decimalPlaces: snapshot?.decimalPlaces ?? latestEntry?.decimalPlaces
        )
    }

    private var fulfillmentMetrics: [(String, Color, Double)] {
        orderedFulfillmentRecords.map { record in
            let title = record.category
            return (title, FulfillmentCategoryTheme.color(for: title), batteryPercentage(for: record))
        }
    }

    private var header: some View {
        VStack(spacing: 4) {
            ZStack {
                HStack {
                    Text(Date()
                        .formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .opacity(homePageIndex == HomeSwipePage.social.rawValue ? 0 : 1)

                    Spacer()

                    NavigationLink {
                        AccountView()
                    } label: {
                        Image(systemName: "person.circle")
                            .font(.system(size: 28))
                            .opacity(homePageIndex == HomeSwipePage.littleWins.rawValue ? 0 : 1)
                    }
                    .buttonStyle(.plain)
                }
                .padding(.horizontal)
                .padding(.top, 8)
                .animation(.easeInOut(duration: 0.2), value: homePageIndex)
                .overlay {
                    GeometryReader { proxy in
                        let centerX = proxy.size.width / 2
                        let titleY = (proxy.size.height / 2) + 4
                        ZStack {
                            Text("Little Wins")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .opacity(homePageIndex == HomeSwipePage.social.rawValue ? 1 : 0)
                                .position(
                                    x: homePageIndex == HomeSwipePage.social.rawValue
                                        ? proxy.size.width * 0.20
                                        : centerX,
                                    y: titleY
                                )

                            Text("Sharing")
                                .font(.headline.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .opacity(homePageIndex == HomeSwipePage.littleWins.rawValue ? 1 : 0)
                                .position(
                                    x: homePageIndex == HomeSwipePage.littleWins.rawValue
                                        ? proxy.size.width * 0.80
                                        : centerX,
                                    y: titleY
                                )
                        }
                        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.72, blendDuration: 0.2), value: homePageIndex)
                    }
                }

                Image("logo")
                    .resizable()
                    .scaledToFit()
                    .frame(height: 40)
                    .modifier(DarkModeInvertImage())
                    .overlay(alignment: .leading) {
                        if shouldShowLittleWinsLogoDot {
                            Circle()
                                .fill(Color(.systemGray3))
                                .frame(width: 8, height: 8)
                                .offset(x: -14 + (littleWinsLogoDotBounceOn ? -3 : 0), y: 1)
                                .animation(
                                    .interactiveSpring(response: 0.24, dampingFraction: 0.72, blendDuration: 0.12),
                                    value: littleWinsLogoDotBounceOn
                                )
                        }
                    }
                    .background(
                        GeometryReader { proxy in
                            Color.clear
                                .preference(key: HeaderLogoWidthPreferenceKey.self, value: proxy.size.width)
                        }
                    )
            }

            pagePositionIndicator
                .padding(.top, 2)
                .padding(.horizontal, 24)
        }
        .onPreferenceChange(HeaderLogoWidthPreferenceKey.self) { width in
            guard width > 0 else { return }
            if abs(width - measuredHeaderLogoWidth) > 0.5 {
                measuredHeaderLogoWidth = width
            }
        }
    }

    @ViewBuilder
    private var pagePositionIndicator: some View {
        GeometryReader { proxy in
            let totalWidth = proxy.size.width
            let laneWidth = totalWidth / 3
            let indicatorWidth = max(64, laneWidth * 0.98)

            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(0.06))
                    .frame(height: 4)

                HStack(spacing: 0) {
                    ForEach(0..<3, id: \.self) { idx in
                        ZStack {
                            if idx == homePageIndex {
                                Capsule()
                                    .fill(Color.primary.opacity(0.22))
                                    .frame(width: indicatorWidth, height: 4)
                                    .matchedGeometryEffect(id: "home_page_indicator", in: pageIndicatorNamespace)
                                    .shadow(color: Color.primary.opacity(0.06), radius: 3, x: 0, y: 1)
                            }
                        }
                        .frame(width: laneWidth, height: 4)
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
        .frame(height: 4)
        .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.72, blendDuration: 0.2), value: homePageIndex)
    }

    @ViewBuilder
    private func centerHomepageMiddleContent(
        outerVerticalPadding: CGFloat,
        cardSpacing: CGFloat,
        cardDensity: CGFloat
    ) -> some View {
        ViewThatFits(in: .vertical) {
            GeometryReader { middleProxy in
                let middleHeight = middleProxy.size.height
                let drivingHeight = measuredCardHeights["driving"] ?? 170
                let fulfillmentHeight = measuredCardHeights["fulfillment"] ?? 170
                let objectivesHeight = measuredCardHeights["objectives"] ?? 170
                let totalCardHeight = drivingHeight + fulfillmentHeight + objectivesHeight
                let uniformGap = max(0, (middleHeight - totalCardHeight) / 4)

                VStack(spacing: 0) {
                    Color.clear.frame(height: uniformGap)
                    measuredCard("driving") {
                        drivingForceSection
                            .padding(.horizontal)
                    }
                    Color.clear.frame(height: uniformGap)
                    measuredCard("fulfillment") {
                        fulfillmentSection
                            .padding(.horizontal)
                    }
                    Color.clear.frame(height: uniformGap)
                    measuredCard("objectives") {
                        objectivesSection
                            .padding(.horizontal)
                    }
                    Color.clear.frame(height: uniformGap)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
            }
            .padding(.vertical, max(0, outerVerticalPadding - 2))

            ScrollView(showsIndicators: false) {
                VStack(spacing: cardSpacing) {
                    measuredCard("driving") { drivingForceSection }
                    measuredCard("fulfillment") { fulfillmentSection }
                    measuredCard("objectives") { objectivesSection }
                }
                .padding(.horizontal)
                .padding(.vertical, outerVerticalPadding)
            }
        }
        .environment(\.contentCardDensity, cardDensity)
    }

    private func placeholderMiddlePage(title: String) -> some View {
        VStack {
            Spacer()
            Text(title)
                .font(.title2.weight(.semibold))
                .foregroundStyle(.secondary)
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .contentShape(Rectangle())
    }

    private func littleWinsMiddlePage() -> some View {
        GeometryReader { proxy in
            littleWinsMiddlePageContent(proxy: proxy)
        }
        .contentShape(Rectangle())
        .onAppear(perform: syncLittleWinsCompletionStateFromStore)
        .onAppear(perform: syncIntegratedLittleWinsCompletionsFromProgress)
        .onAppear(perform: refreshAppleHealthIntegratedLittleWinsProgressIfNeeded)
        .onAppear(perform: syncLittleWinsCardOrder)
        .onChange(of: littleWinsDailyCompletions.map(\.id)) { _, _ in
            syncLittleWinsCompletionStateFromStore()
            syncIntegratedLittleWinsCompletionsFromProgress()
        }
        .onChange(of: littleWinsSourceCardIDs) { _, _ in
            syncLittleWinsCardOrder()
        }
        .onReceive(NotificationCenter.default.publisher(for: .littleWinsScheduleDidChange)) { _ in
            littleWinsScheduleStoreRevision &+= 1
        }
        .onReceive(NotificationCenter.default.publisher(for: .littleWinsIntegrationDidChange)) { _ in
            littleWinsIntegrationStoreRevision &+= 1
            syncIntegratedLittleWinsCompletionsFromProgress()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            refreshAppleHealthIntegratedLittleWinsProgressIfNeeded()
        }
        .onChange(of: homePageIndex) { _, _ in
            if littleWinsCalendarPreviewDate != nil {
                withAnimation(.easeOut(duration: 0.12)) {
                    littleWinsCalendarPreviewDate = nil
                }
            }
        }
        .sheet(item: $littleWinsIntegrationDetailTarget, content: littleWinsIntegrationDetailSheet)
        .onDisappear {
            littleWinsCalendarPreviewDate = nil
        }
    }

    private func littleWinsMiddlePageContent(proxy: GeometryProxy) -> some View {
        let horizontalPadding: CGFloat = 16
        let cardWidth = max(0, proxy.size.width - (horizontalPadding * 2))
        let cardHeight = min(max(cardWidth * 1.42, 360), max(380, proxy.size.height - 36))
        let cards = littleWinsCards
        let allTodayCards = littleWinsCardsIncludingHiddenToday
        let baselineVisibleCards = littleWinsCards(showHidden: false)
        let showsSetupLittleWinsPlaceholder = setupHomepageMode || allTodayCards.isEmpty
        let activeCards = cards.filter { !isLittleWinsCardCompleted($0) }
        let completedCards = allTodayCards.filter { isLittleWinsCardCompleted($0) }
        let visibleItemIDs = Set(baselineVisibleCards.flatMap { $0.items.map(\.id) })
        let allItemIDs = Set(allTodayCards.flatMap { $0.items.map(\.id) })
        let hasHiddenLittleWinsToReveal = littleWinsShowHiddenPlaceholder || !allItemIDs.subtracting(visibleItemIDs).isEmpty
        let allActiveCardsCompleted = !cards.isEmpty && activeCards.isEmpty
        let todayHasCompletedCard = !completedCards.isEmpty
        let streakShowsTodayComplete = allActiveCardsCompleted && todayHasCompletedCard
        let completedCardStreakCount = littleWinsCompletedCardStreakCount()
        let todayMiniStackTopOverflow = littleWinsMiniStackTopOverflow(forCardCount: completedCards.count)
        let calendarBadgeRowHeight: CGFloat = 36
        let calendarBadgeVisualLift = todayMiniStackTopOverflow + calendarBadgeRowHeight + 34
        let calendarBadgeHitAreaTopPadding = calendarBadgeRowHeight + 8
        let calendarRowHeight: CGFloat = 84 + todayMiniStackTopOverflow
        // Reserve only the actual laid-out calendar band height (row + paddings/spacers),
        // so the deck can use remaining space before hiding back cards.
        let calendarBandReserve: CGFloat = calendarRowHeight + 14
        let isCalendarPreviewActive = littleWinsCalendarPreviewDate != nil

        return Group {
            littleWinsDeckView(
                cards: activeCards,
                cardWidth: cardWidth,
                cardHeight: cardHeight,
                horizontalPadding: horizontalPadding,
                availableHeight: proxy.size.height,
                bottomCalendarBandReserve: calendarBandReserve,
                showsSetupPlaceholder: showsSetupLittleWinsPlaceholder
            )
        }
        .opacity(isCalendarPreviewActive ? 0 : 1)
        .animation(.easeInOut(duration: 0.18), value: isCalendarPreviewActive)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .safeAreaInset(edge: .bottom, spacing: 10) {
            if !cards.isEmpty || showsSetupLittleWinsPlaceholder {
                VStack(spacing: 0) {
                    VStack(spacing: 6) {
                        HStack {
                            littleWinsLastWeekCalendarRow(completedTodayCards: completedCards)
                        }
                        .frame(minHeight: calendarRowHeight, alignment: .top)
                        .padding(.horizontal)
                        .padding(.top, 6)
                        .padding(.bottom, 0)
                        .animation(
                            .interactiveSpring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.14),
                            value: littleWinsCompletedFocusIDs
                        )
                        .overlay(alignment: .top) {
                            ZStack {
                                HStack(spacing: 6) {
                                    if hasHiddenLittleWinsToReveal {
                                        Toggle("", isOn: $littleWinsShowHiddenPlaceholder)
                                            .labelsHidden()
                                            .toggleStyle(.switch)
                                        Image(systemName: littleWinsHiddenClockIconName)
                                            .font(.system(size: 21, weight: .semibold))
                                            .foregroundStyle(littleWinsShowHiddenPlaceholder ? .blue : .secondary)
                                            .frame(width: 31, height: 31, alignment: .center)
                                            .accessibilityHidden(true)
                                    }
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)

                                Button {
                                    isPresentingLittleWinsManagerSheet = true
                                } label: {
                                    Text("Manage Little Wins")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.blue)
                                }
                                .buttonStyle(.plain)
                                .opacity(showsSetupLittleWinsPlaceholder ? 0 : 1)
                                .allowsHitTesting(!showsSetupLittleWinsPlaceholder)

                                HStack(spacing: 8) {
                                    ForEach(0..<7, id: \.self) { idx in
                                        Group {
                                            if idx == 6 && completedCardStreakCount >= 2 {
                                                HStack(spacing: 4) {
                                                    Image(systemName: streakShowsTodayComplete ? "bolt.badge.checkmark.fill" : "bolt.fill")
                                                        .font(.caption2.weight(.semibold))
                                                    Text("\(completedCardStreakCount)d")
                                                        .font(.caption2.weight(.semibold))
                                                }
                                                .foregroundStyle(.secondary)
                                                .frame(maxWidth: .infinity)
                                            } else {
                                                Color.clear
                                            }
                                        }
                                        .frame(maxWidth: .infinity)
                                    }
                                }
                                .allowsHitTesting(false)
                            }
                            .frame(height: calendarBadgeRowHeight)
                            .padding(.horizontal)
                            .padding(.top, calendarBadgeHitAreaTopPadding)
                            .offset(y: -calendarBadgeVisualLift)
                        }
                    }
                    Color.clear.frame(height: 8)
                }
                .background(Color(.systemGroupedBackground))
            }
        }
        .overlay {
            if let previewDate = littleWinsCalendarPreviewDate {
                let previewCategories = littleWinsHistoricalCategories(on: previewDate)
                if !previewCategories.isEmpty {
                    littleWinsCalendarFullScreenPreview(
                        date: previewDate,
                        categories: previewCategories,
                        containerSize: proxy.size
                    )
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
                    .zIndex(60)
                }
            }
        }
    }

    @ViewBuilder
    private func littleWinsIntegrationDetailSheet(target: LittleWinsIntegrationDetailTarget) -> some View {
        if let focus = foci.first(where: { $0.id == target.focusID }),
           let config = littleWinsIntegrationConfig(for: focus) {
            NavigationStack {
                List {
                    Section {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(focus.activity)
                                .font(.headline)
                                .foregroundStyle(.primary)
                            if let category = recordForCategoryID(focus.category_id)?.category {
                                Text(category)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(FulfillmentCategoryTheme.color(for: category))
                            }
                        }
                        .padding(.vertical, 2)
                    }

                    Section("Integration") {
                        ForEach(littleWinsIntegrationDetailRows(for: focus), id: \.0) { row in
                            HStack {
                                Text(row.0)
                                    .foregroundStyle(.secondary)
                                Spacer()
                                Text(row.1)
                                    .multilineTextAlignment(.trailing)
                            }
                        }
                    }

                    Section {
                        Text("This Little Win is completed automatically from integrated progress and can’t be checked manually.")
                            .font(.footnote)
                            .foregroundStyle(.secondary)
                    }
                }
                .listStyle(.insetGrouped)
                .navigationTitle(config.source.title)
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { littleWinsIntegrationDetailTarget = nil }
                    }
                }
            }
        }
    }

    private func littleWinsCompletedCardStreakCount() -> Int {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let startsAtToday = littleWinsCardsIncludingHiddenToday.contains { isLittleWinsCardCompletedForActiveTodayStreak($0) }
        var streak = 0

        for dayOffset in (startsAtToday ? 0 : 1)...30 {
            guard let date = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let hasCompletedCardOnDay: Bool
            if calendar.isDate(date, inSameDayAs: today) {
                hasCompletedCardOnDay = littleWinsCardsIncludingHiddenToday.contains { isLittleWinsCardCompletedForActiveTodayStreak($0) }
            } else {
                hasCompletedCardOnDay = !littleWinsCompletedCards(on: date).isEmpty
            }
            if !hasCompletedCardOnDay {
                break
            }
            streak += 1
        }

        return streak
    }

    private func littleWinsMiniStackTopOverflow(forCardCount cardCount: Int) -> CGFloat {
        let miniCardWidth: CGFloat = 28
        let miniCardHeight: CGFloat = miniCardWidth * 1.42
        let miniStackLiftPerCard = min(6, max(4, miniCardHeight * 0.14))
        let visibleStackCount = min(7, max(0, cardCount))
        return CGFloat(max(0, visibleStackCount - 1)) * miniStackLiftPerCard
    }

    private func littleWinsDeckView(
        cards: [LittleWinsCardData],
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        horizontalPadding: CGFloat,
        availableHeight: CGFloat,
        bottomCalendarBandReserve: CGFloat,
        showsSetupPlaceholder: Bool = false
    ) -> some View {
        let baseBackStep = cardHeight * 0.05
        let hintHeight: CGFloat = 18
        let hintSpacing: CGFloat = 6
        let minimumTopStackSpacing: CGFloat = 0
        let minimumBottomControlsSpacing: CGFloat = 30
        let contentHeight = cardHeight + hintSpacing + hintHeight
        let availableDeckBandHeight = max(0, availableHeight - bottomCalendarBandReserve)
        let visibleCards = cards
        let stackCount = max(0, visibleCards.count)
        let effectiveBackStep: CGFloat
        if stackCount <= 1 {
            effectiveBackStep = baseBackStep
        } else {
            let maxAllowedStackRise = max(
                0,
                availableDeckBandHeight - contentHeight - minimumTopStackSpacing - minimumBottomControlsSpacing
            )
            let maxFittableStep = maxAllowedStackRise / CGFloat(max(1, stackCount - 1))
            effectiveBackStep = max(0, min(baseBackStep, maxFittableStep))
        }
        let visibleStackRise = effectiveBackStep * CGFloat(max(0, stackCount - 1))
        let remainingVerticalSlack = max(
            0,
            availableDeckBandHeight - contentHeight - visibleStackRise - minimumTopStackSpacing - minimumBottomControlsSpacing
        )
        let deckTopPadding: CGFloat
        if stackCount <= 1 {
            deckTopPadding = minimumTopStackSpacing
        } else {
            // Position the stack so the extra available space is balanced above the
            // back-most card and below the hint text (while keeping the bottom band fixed).
            let topGapForBackMost = minimumTopStackSpacing + (remainingVerticalSlack * 0.5)
            deckTopPadding = topGapForBackMost + visibleStackRise
        }

        return VStack(spacing: 6) {
            ZStack {
                if visibleCards.isEmpty {
                    littleWinsCompletedTodayPlaceholderCard(
                        width: cardWidth,
                        height: cardHeight,
                        isSetupPlaceholder: showsSetupPlaceholder
                    )
                } else {
                    ForEach(Array(visibleCards.enumerated()), id: \.element.id) { index, card in
                        let depth = CGFloat(index)
                        let isTop = index == 0
                        littleWinsCardView(
                            card,
                            width: cardWidth,
                            height: cardHeight,
                            isFrontmost: isTop
                        )
                        .offset(
                            x: isTop ? littleWinsDeckDragX : 0,
                            y: -(depth * effectiveBackStep)
                        )
                        .rotationEffect(.degrees(isTop ? Double(littleWinsDeckDragX / 28) : 0))
                        .scaleEffect(isTop ? 1.0 : max(0.94, 1.0 - (depth * 0.02)), anchor: .top)
                        .opacity(index > 2 ? 0.92 : 1.0)
                        .zIndex(Double(visibleCards.count - index))
                        .allowsHitTesting(isTop)
                        .matchedGeometryEffect(id: "lw-card-\(card.id.uuidString)", in: littleWinsCompletionNamespace)
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: cardHeight, alignment: .top)
            .contentShape(Rectangle())
            .simultaneousGesture(littleWinsDeckDragGesture(cards: cards, cardWidth: cardWidth))
            .animation(.interactiveSpring(response: 0.34, dampingFraction: 0.80, blendDuration: 0.15), value: littleWinsCardOrder)
            .animation(.interactiveSpring(response: 0.38, dampingFraction: 0.84, blendDuration: 0.14), value: littleWinsCompletedFocusIDs)

            Text("swipe right to rearrange")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .opacity(cards.count > 1 ? 1 : 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .padding(.horizontal, horizontalPadding)
        .padding(.top, deckTopPadding)
        .padding(.bottom, minimumBottomControlsSpacing)
    }

    private func littleWinsCompletedTodayPlaceholderCard(
        width: CGFloat,
        height: CGFloat,
        isSetupPlaceholder: Bool = false
    ) -> some View {
        let bg = Color(.systemGray6)
        let primary = colorScheme == .dark ? Color.white.opacity(0.86) : Color.black.opacity(0.78)
        let secondary = colorScheme == .dark ? Color.white.opacity(0.58) : Color.black.opacity(0.52)
        let radarSideCount = max(3, min(7, fulfillmentMetrics.count))
        let headerTitle = isSetupPlaceholder ? "Setup Card" : "Completed Today"
        let headlineText = isSetupPlaceholder ? "Setup Little Wins" : "All Little Win Cards Completed"
        let subheadlineText = isSetupPlaceholder ? "Set Fulfillment Areas to continue" : "Come back tomorrow to continue"

        return VStack(spacing: 0) {
            Text(headerTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 18)

            Spacer(minLength: 0)

            VStack(spacing: 8) {
                Text(headlineText)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(primary)
                    .multilineTextAlignment(.center)
                Text(subheadlineText)
                    .font(.subheadline)
                    .foregroundStyle(secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal, 30)

            Spacer(minLength: 0)

            Text("Little Wins")
                .font(.headline.weight(.semibold))
                .foregroundStyle(primary)
                .padding(.horizontal, 18)
                .padding(.top, 10)
                .padding(.bottom, 14)
        }
        .frame(width: width, height: height, alignment: .top)
        .background {
            littleWinsCardBackground(
                cardColor: bg,
                titleColor: Color(.systemGray3),
                patternText: isSetupPlaceholder ? "Setup Little Wins" : "Completed Little Wins",
                width: width,
                height: height,
                radarSideCount: radarSideCount
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private func littleWinsDeckDragGesture(cards: [LittleWinsCardData], cardWidth: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 10, coordinateSpace: .local)
            .onChanged { value in
                guard abs(value.translation.width) > abs(value.translation.height) else { return }
                guard value.translation.width > 0 else {
                    littleWinsDeckDragX = 0
                    return
                }
                guard cards.count > 1 else { return }
                littleWinsDeckIsDragging = true
                littleWinsDeckDragX = value.translation.width
            }
            .onEnded { value in
                let horizontalDominant = abs(value.translation.width) > abs(value.translation.height)
                let threshold = min(120, cardWidth * 0.18)
                let shouldNavigateToHome = horizontalDominant && value.translation.width < -threshold
                let shouldRotate = cards.count > 1 && horizontalDominant && value.translation.width > threshold
                littleWinsDeckIsDragging = false
                littleWinsSuppressRowTapUntil = Date().addingTimeInterval(0.2)

                if shouldNavigateToHome {
                    withAnimation(.interactiveSpring(response: 0.32, dampingFraction: 0.82, blendDuration: 0.12)) {
                        homePageIndex = HomeSwipePage.home.rawValue
                        littleWinsDeckDragX = 0
                    }
                } else if shouldRotate {
                    var nextOrder = cards.map(\.id)
                    let first = nextOrder.removeFirst()
                    nextOrder.append(first)
                    withAnimation(.interactiveSpring(response: 0.34, dampingFraction: 0.78, blendDuration: 0.15)) {
                        littleWinsCardOrder = nextOrder
                        littleWinsDeckDragX = 0
                    }
                } else {
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1)) {
                        littleWinsDeckDragX = 0
                    }
                }
            }
    }

    private func littleWinsLastWeekCalendarRow(completedTodayCards: [LittleWinsCardData]) -> some View {
        let dates = lastSevenDatesEndingToday()
        let calendar = Calendar.current

        return HStack(spacing: 8) {
            ForEach(dates, id: \.self) { date in
                let isToday = calendar.isDateInToday(date)
                let isHeldPreviewDate = calendar.isDate(date, inSameDayAs: littleWinsCalendarPreviewDate ?? .distantPast)
                let completedCardsForDate = isToday ? completedTodayCards : littleWinsCompletedCards(on: date)
                let historicalPreviewCategories = littleWinsHistoricalCategories(on: date)
                let hasHistoricalPreview = !historicalPreviewCategories.isEmpty
                let canShowHoldPreview = !completedCardsForDate.isEmpty && hasHistoricalPreview
                let miniCardWidth: CGFloat = 28
        let miniCardHeight: CGFloat = miniCardWidth * 1.42
                let visibleStackCount = min(7, completedCardsForDate.count)
                let miniStackLiftPerCard = min(6, max(4, miniCardHeight * 0.14))
                let miniStackTopOverflow = CGFloat(max(0, visibleStackCount - 1)) * miniStackLiftPerCard
                VStack(spacing: 3) {
                    if !completedCardsForDate.isEmpty {
                        littleWinsCompletedTodayMiniCardStack(
                            cards: completedCardsForDate,
                            cardWidth: miniCardWidth,
                            cardHeight: miniCardHeight,
                            usesMatchedGeometry: isToday
                        )
                        .frame(width: miniCardWidth, height: miniCardHeight, alignment: .top)
                    } else if isToday {
                        Color.clear
                            .frame(width: miniCardWidth, height: miniCardHeight)
                    } else {
                        RoundedRectangle(cornerRadius: 4, style: .continuous)
                            .fill(Color(.systemGray5))
                            .frame(width: miniCardWidth, height: miniCardHeight)
                            .overlay {
                                Image(systemName: "xmark")
                                    .font(.system(size: 17.5, weight: .semibold))
                                    .foregroundStyle(Color(.systemGray2))
                            }
                    }

                    Text(date.formatted(.dateTime.weekday(.narrow)))
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(date.formatted(.dateTime.day()))
                        .font(.caption.weight(isToday ? .semibold : .regular))
                        .foregroundStyle(isToday ? .primary : .secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 6)
                .padding(.bottom, 1)
                .background(
                    ZStack {
                        if isHeldPreviewDate {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color(.systemGray5))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                                )
                                .padding(.top, -miniStackTopOverflow)
                                .allowsHitTesting(false)
                        }

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(isToday && !isHeldPreviewDate ? Color.primary.opacity(0.08) : Color.clear)
                            .padding(.top, isToday ? -miniStackTopOverflow : 0)
                    }
                )
                .onLongPressGesture(minimumDuration: 0.18, maximumDistance: 36, pressing: { isPressing in
                    guard canShowHoldPreview else { return }
                    withAnimation(.interactiveSpring(response: 0.28, dampingFraction: 0.82, blendDuration: 0.1)) {
                        littleWinsCalendarPreviewDate = isPressing ? calendar.startOfDay(for: date) : nil
                    }
                }, perform: {})
            }
        }
        .padding(.top, 2)
    }

    private func littleWinsCompletedCards(on date: Date) -> [LittleWinsCardData] {
        let historicalCards = littleWinsHistoricalCompletedCardSnapshots(on: date)
        guard !historicalCards.isEmpty else { return [] }
        return historicalCards
    }

    private func littleWinsCompletedTodayMiniCardStack(
        cards: [LittleWinsCardData],
        cardWidth: CGFloat,
        cardHeight: CGFloat,
        usesMatchedGeometry: Bool = true
    ) -> some View {
        let visible = Array(cards.suffix(7))
        let stackLiftPerCard = min(6, max(4, cardHeight * 0.14))
        return ZStack {
            ForEach(Array(visible.enumerated()), id: \.element.id) { index, card in
                let depth = CGFloat(visible.count - 1 - index)
                Group {
                    if usesMatchedGeometry {
                        littleWinsCompletedMiniCard(card, width: cardWidth, height: cardHeight)
                            .matchedGeometryEffect(id: "lw-card-\(card.id.uuidString)", in: littleWinsCompletionNamespace)
                    } else {
                        littleWinsCompletedMiniCard(card, width: cardWidth, height: cardHeight)
                    }
                }
                    .offset(y: -(depth * stackLiftPerCard))
                    .zIndex(Double(index))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private func littleWinsCompletedMiniCard(
        _ card: LittleWinsCardData,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let radarSideCount = max(3, min(7, fulfillmentMetrics.count))
        return RoundedRectangle(cornerRadius: 4, style: .continuous)
            .fill(card.cardColor)
            .frame(width: width, height: height)
            .overlay {
                RadarPolygonOutline(sides: radarSideCount)
                    .stroke(card.titleColor, style: StrokeStyle(lineWidth: 1.8))
                    .padding(4)
            }
    }

    private func littleWinsCalendarFullScreenPreview(
        date: Date,
        categories: [LittleWinsHistoricalDayCategory],
        containerSize: CGSize
    ) -> some View {
        let horizontalPadding: CGFloat = 14
        let verticalPadding: CGFloat = 12
        let gridSpacing: CGFloat = 12
        let availableWidth = max(0, containerSize.width - (horizontalPadding * 2))
        let availableHeight = max(0, containerSize.height - (verticalPadding * 2) - 64)
        let completedCardCount = categories.filter(\.isCompletedCard).count
        let gridColumnsCount: Int = completedCardCount <= 4 ? 2 : 3
        let targetRowsCount: Int = completedCardCount <= 4 ? 2 : (completedCardCount <= 6 ? 2 : 3)
        let totalHorizontalSpacing = CGFloat(max(0, gridColumnsCount - 1)) * gridSpacing
        let totalVerticalSpacing = CGFloat(max(0, targetRowsCount - 1)) * gridSpacing
        let cardWidth = max(100, (availableWidth - totalHorizontalSpacing) / CGFloat(gridColumnsCount))
        let cardHeightCap = max(120, (availableHeight - totalVerticalSpacing) / CGFloat(targetRowsCount))
        let cardHeight = min(cardWidth * 1.42, cardHeightCap)
        let gridColumns = Array(
            repeating: GridItem(.flexible(), spacing: gridSpacing, alignment: .top),
            count: gridColumnsCount
        )

        return ZStack {
            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(date.formatted(.dateTime.weekday(.wide)))
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.secondary)
                        Text(date.formatted(.dateTime.month(.abbreviated).day()))
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(.primary)
                    }
                    Spacer(minLength: 0)
                    Text("\(completedCardCount) card\(completedCardCount == 1 ? "" : "s") completed")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: gridColumns,
                        spacing: gridSpacing
                    ) {
                        ForEach(categories) { category in
                            littleWinsHistoricalPreviewCardView(
                                category: category,
                                width: cardWidth,
                                height: cardHeight
                            )
                            .transition(.scale(scale: 0.92).combined(with: .opacity))
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.bottom, 6)
                }
            }
            .padding(.horizontal, horizontalPadding)
            .padding(.top, verticalPadding)
            .padding(.bottom, 6)
        }
        .allowsHitTesting(false)
    }

    private func littleWinsHistoricalPreviewCardView(
        category: LittleWinsHistoricalDayCategory,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let baseWidth: CGFloat = 300
        let baseHeight: CGFloat = baseWidth * 1.42
        let scale = min(width / baseWidth, height / baseHeight)
        return littleWinsHistoricalPreviewCardBaseView(
            category: category,
            width: baseWidth,
            height: baseHeight
        )
        .scaleEffect(scale, anchor: .top)
        .frame(width: width, height: height, alignment: .top)
    }

    private func littleWinsHistoricalPreviewCardBaseView(
        category: LittleWinsHistoricalDayCategory,
        width: CGFloat,
        height: CGFloat
    ) -> some View {
        let fixedPrimaryText = Color.black.opacity(0.82)
        let cardColor = FulfillmentCategoryTheme.lightColor(for: category.categoryTitle)
        let titleColor = FulfillmentCategoryTheme.color(for: category.categoryTitle)
        let radarSideCount = max(3, min(7, fulfillmentMetrics.count))

        return VStack(spacing: 0) {
            Text(category.categoryTitle)
                .font(.headline.weight(.semibold))
                .foregroundStyle(titleColor)
                .multilineTextAlignment(.center)
                .lineLimit(2)
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, 18)

            GeometryReader { middleGeo in
                VStack {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 10) {
                        ForEach(category.items.prefix(7)) { item in
                            littleWinsHistoricalPreviewItemRow(
                                title: item.focusTitle,
                                titleColor: titleColor,
                                fixedPrimaryText: fixedPrimaryText,
                                iconSize: 26,
                                fontSize: 36
                            )
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
        .frame(width: width, height: height, alignment: .top)
        .background {
            littleWinsCardBackground(
                cardColor: cardColor,
                titleColor: titleColor,
                patternText: category.categoryTitle,
                width: width,
                height: height,
                radarSideCount: radarSideCount
            )
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private func littleWinsHistoricalPreviewItemRow(
        title: String,
        titleColor: Color,
        fixedPrimaryText: Color,
        iconSize: CGFloat,
        fontSize: CGFloat
    ) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: iconSize, weight: .semibold))
                .foregroundStyle(titleColor)
                .padding(.top, 1)
                .frame(width: 30, alignment: .center)

            Text(title)
                .font(.system(size: fontSize, weight: .semibold))
                .foregroundStyle(fixedPrimaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .lineLimit(2)
                .minimumScaleFactor(0.55)
                .allowsTightening(true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func lastSevenDatesEndingToday() -> [Date] {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        return (0..<7).compactMap { offset in
            calendar.date(byAdding: .day, value: -(6 - offset), to: today)
        }
    }

    private func littleWinsCardView(
        _ card: LittleWinsCardData,
        width: CGFloat,
        height: CGFloat,
        isFrontmost: Bool
    ) -> some View {
        let fixedPrimaryText = Color.black.opacity(0.82)
        let fixedSecondaryText = Color.black.opacity(0.56)
        let radarSideCount = max(3, min(7, fulfillmentMetrics.count))
        let checkedCount = card.items.reduce(into: 0) { count, item in
            if littleWinsCompletedFocusIDs.contains(item.id) { count += 1 }
        }
        let totalCount = card.items.count
        let hasAnyActiveToday = !card.activeTodayItemIDs.isEmpty
        let isFullyUnhiddenToday = littleWinsShowHiddenPlaceholder && !hasAnyActiveToday
        let hasAnyUnhiddenHiddenItems = littleWinsShowHiddenPlaceholder && card.items.contains { !card.activeTodayItemIDs.contains($0.id) }
        let activeDaysSummary = littleWinsActiveDaysSummary(for: card)
        return VStack(spacing: 0) {
            ZStack {
                Text(card.categoryTitle)
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(card.titleColor)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)

                if !isFrontmost && checkedCount > 0 {
                    HStack {
                        Spacer()
                        Text("\(checkedCount)/\(totalCount)")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(fixedPrimaryText)
                            .padding(.trailing, 2)
                            .offset(y: -4)
                    }
                }
            }
            .padding(.horizontal, 18)
            .padding(.top, 10)
            .padding(.bottom, activeDaysSummary != nil && hasAnyUnhiddenHiddenItems ? 8 : 18)

            if hasAnyUnhiddenHiddenItems, let activeDaysSummary {
                HStack(spacing: 6) {
                    Image(systemName: littleWinsHiddenClockIconName)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(activeDaysSummary)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(.systemGray5))
                )
                .padding(.horizontal, 18)
                .padding(.bottom, 10)
            }

            GeometryReader { middleGeo in
                VStack {
                    Spacer(minLength: 0)

                    VStack(alignment: .leading, spacing: 12) {
                        ForEach(card.items, id: \.id) { item in
                            littleWinsItemRow(
                                item: item,
                                isActiveToday: card.activeTodayItemIDs.contains(item.id),
                                isInsideFullyHiddenCard: isFullyUnhiddenToday,
                                titleColor: card.titleColor,
                                fixedPrimaryText: fixedPrimaryText,
                                fixedSecondaryText: fixedSecondaryText
                            )
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
        .frame(width: width, height: height, alignment: .top)
        .background {
            littleWinsCardBackground(
                card: card,
                width: width,
                height: height,
                radarSideCount: radarSideCount
            )
        }
        .overlay {
            if isFullyUnhiddenToday {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(style: StrokeStyle(lineWidth: 4, dash: [6]))
                    .foregroundStyle(.blue)
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .shadow(color: Color.black.opacity(0.10), radius: 10, x: 0, y: 6)
    }

    private func littleWinsItemRow(
        item: FulfillmentFocus,
        isActiveToday: Bool,
        isInsideFullyHiddenCard: Bool,
        titleColor: Color,
        fixedPrimaryText: Color,
        fixedSecondaryText: Color
    ) -> some View {
        let isCompleted = littleWinsCompletedFocusIDs.contains(item.id)
        let integrationConfig = littleWinsIntegrationConfig(for: item)
        let isIntegrated = integrationConfig?.isEnabled == true
        let isInactiveHiddenToday = littleWinsShowHiddenPlaceholder && !isActiveToday
        let showDashedCircleOnly = isInactiveHiddenToday && !isInsideFullyHiddenCard
        return HStack(alignment: .top, spacing: 10) {
            Group {
                if let integrationConfig, isIntegrated {
                    littleWinsIntegratedIndicator(
                        config: integrationConfig,
                        isCompleted: isCompleted,
                        isDashedHiddenIndicator: showDashedCircleOnly && !isCompleted,
                        titleColor: titleColor,
                        fixedSecondaryText: fixedSecondaryText
                    )
                    .padding(.top, 6)
                } else if showDashedCircleOnly && !isCompleted {
                    Circle()
                        .stroke(style: StrokeStyle(lineWidth: 2, dash: [6]))
                        .foregroundStyle(.blue)
                        .frame(width: 22, height: 22)
                        .padding(.top, 8)
                } else {
                    Image(systemName: isCompleted ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 26, weight: .regular))
                        .foregroundStyle(isCompleted ? titleColor : fixedSecondaryText)
                        .padding(.top, 6)
                }
            }
            .frame(width: 30, alignment: .center)

            Text(item.activity)
                .font(.system(size: 36, weight: .semibold, design: .default))
                .foregroundStyle(fixedPrimaryText)
                .multilineTextAlignment(.leading)
                .frame(maxWidth: .infinity, alignment: .leading)
                .strikethrough(isCompleted, color: fixedPrimaryText.opacity(0.7))
                .opacity(isCompleted ? 0.72 : (isInactiveHiddenToday ? 0.78 : 1))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            guard isActiveToday || littleWinsShowHiddenPlaceholder || isInsideFullyHiddenCard || isCompleted else { return }
            guard !littleWinsDeckIsDragging else { return }
            guard Date() >= littleWinsSuppressRowTapUntil else { return }
            if isIntegrated {
                presentLittleWinsIntegrationDetails(for: item)
                return
            }
            withAnimation(.interactiveSpring(response: 0.38, dampingFraction: 0.82, blendDuration: 0.12)) {
                if isCompleted {
                    littleWinsCompletedFocusIDs.remove(item.id)
                } else {
                    littleWinsCompletedFocusIDs.insert(item.id)
                }
            }
            persistLittleWinToggle(focusId: item.id, isCompleted: isCompleted)
        }
    }

    private func littleWinsCardBackground(
        card: LittleWinsCardData,
        width: CGFloat,
        height: CGFloat,
        radarSideCount: Int
    ) -> some View {
        littleWinsCardBackground(
            cardColor: card.cardColor,
            titleColor: card.titleColor,
            patternText: card.categoryTitle,
            width: width,
            height: height,
            radarSideCount: radarSideCount
        )
    }

    private func littleWinsCardBackground(
        cardColor: Color,
        titleColor: Color,
        patternText: String,
        width: CGFloat,
        height: CGFloat,
        radarSideCount: Int
    ) -> some View {
        let cornerShapeSize: CGFloat = 52
        let cornerShapePadding: CGFloat = 14
        let topTitleCutoutWidth = min(max(width * 0.62, 200), width - 86)
        let bottomTitleCutoutWidth = min(max(width * 0.32, 120), 180)
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
                ZStack {
                    ForEach(0..<18, id: \.self) { idx in
                        RoundedRectangle(cornerRadius: 1.5, style: .continuous)
                            .fill(Color.white.opacity(0.05))
                            .frame(width: width * 0.9, height: 1)
                            .rotationEffect(.degrees(-14))
                            .offset(x: -width * 0.14, y: CGFloat(idx) * 16 - (height * 0.38))
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                .opacity(0.55)
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
                    lineWidth: 4,
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
            .overlay {
                littleWinsInsetGuideLine(
                    inset: 30,
                    cornerRadius: 24,
                    strokeColor: titleColor.opacity(0.14),
                    lineWidth: 4,
                    width: width,
                    height: height,
                    topLeadingShapeCutout: .init(width: 96, height: 96),
                    bottomTrailingShapeCutout: .init(width: 96, height: 96),
                    shapePadding: cornerShapePadding,
                    shapeSize: cornerShapeSize,
                    topCutoutWidth: topTitleCutoutWidth,
                    bottomCutoutWidth: bottomTitleCutoutWidth
                )
            }
            .overlay(alignment: .topLeading) {
                RadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: 6))
                    .frame(width: cornerShapeSize, height: cornerShapeSize)
                    .padding(.leading, cornerShapePadding)
                    .padding(.top, cornerShapePadding)
                    .opacity(0.9)
            }
            .overlay(alignment: .bottomTrailing) {
                RadarPolygonOutline(sides: radarSideCount)
                    .stroke(titleColor, style: StrokeStyle(lineWidth: 6))
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
        bottomTrailingShapeCutout: CGSize = .zero
        ,
        shapePadding: CGFloat = 14,
        shapeSize: CGFloat = 52,
        topCutoutWidth: CGFloat? = nil,
        bottomCutoutWidth: CGFloat? = nil
    ) -> some View {
        let topCutoutWidth = topCutoutWidth ?? min(max(width * 0.34, 120), 190)
        let bottomCutoutWidth = bottomCutoutWidth ?? min(max(width * 0.56, 180), width - (inset * 2) - 20)
        let topY = inset
        let bottomY = height - inset
        let topLeadingCutoutCenter = CGPoint(
            x: shapePadding + (shapeSize / 2),
            y: shapePadding + (shapeSize / 2)
        )
        let bottomTrailingCutoutCenter = CGPoint(
            x: width - shapePadding - (shapeSize / 2),
            y: height - shapePadding - (shapeSize / 2)
        )

        return ZStack {
            RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                .inset(by: inset)
                .stroke(strokeColor, lineWidth: lineWidth)

            Rectangle()
                .fill(Color.black)
                .frame(width: topCutoutWidth, height: lineWidth + 10)
                .position(x: width / 2, y: topY)

            Rectangle()
                .fill(Color.black)
                .frame(width: bottomCutoutWidth, height: lineWidth + 10)
                .position(x: width / 2, y: bottomY)
        }
        .compositingGroup()
        .blendMode(.normal)
        .mask(
            Rectangle()
                .overlay {
                    Rectangle().fill(Color.white)
                    Rectangle()
                        .frame(width: topCutoutWidth, height: lineWidth + 12)
                        .position(x: width / 2, y: topY)
                        .blendMode(.destinationOut)
                    Rectangle()
                        .frame(width: bottomCutoutWidth, height: lineWidth + 12)
                        .position(x: width / 2, y: bottomY)
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
        let textSize: CGFloat = 8.5 // ~50% of headline-sized "Little Wins" title
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
                    .padding(.vertical, 0)
            }
        }
        .frame(width: width, height: height, alignment: .topLeading)
        .clipped()
        .allowsHitTesting(false)
    }

    private var footer: some View {
        VStack(spacing: 6) {
            HStack(spacing: 16) {
                Button(action: { isPresentingCaptureView = true }) {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
                            .overlay(
                                Capsule().stroke(colorScheme == .dark ? Color.clear : Color(.separator).opacity(0.6), lineWidth: 1)
                            )
                            .shadow(color: Color.primary.opacity(colorScheme == .dark ? 0.2 : 0.08), radius: 8, x: 0, y: 2)
                            .overlay(
                                HStack {
                                    Image(systemName: "plus.viewfinder")
                                        .foregroundColor(.accentColor)
                                        .padding(.leading, 16)
                                        .scaleEffect(1.6)
                                    Text("Capture Action")
                                        .foregroundColor(.primary)
                                        .padding(.leading, 12)
                                    Spacer()
                                    Text("how you act")
                                        .font(.caption2)
                                        .italic()
                                        .foregroundStyle(.secondary)
                                        .padding(.trailing, 14)
                                }
                            )
                            .frame(height: 60)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Group {
                    if !canOpenPlanOrActionFlow {
                        Button(action: {
                            triggerPlayBlockedFeedback()
                        }) {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(Color(.systemBackground))
                                .frame(width: 60, height: 60)
                                .background(Color(.systemGray3))
                                .opacity(0.62)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else if isActiveActionFlow {
                        Button(action: {
                            playSheetDestination = .action
                        }) {
                            Image(systemName: "forward.fill")
                                .font(.title)
                                .foregroundColor(Color(.systemBackground))
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    } else {
                        NavigationLink {
                            if hasCompletedPlanFlowOnce {
                                PlanView()
                            } else {
                                PlanStartView()
                            }
                        } label: {
                            Image(systemName: "play.fill")
                                .font(.title)
                                .foregroundColor(Color(.systemBackground))
                                .frame(width: 60, height: 60)
                                .background(Color.accentColor)
                                .clipShape(Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .scaleEffect(
                    shouldShowPlanButtonOnboardingBounce
                        ? (drivingCardBounceOn ? 1.012 : 1.0)
                        : 1.0
                )
                .offset(
                    y: shouldShowPlanButtonOnboardingBounce
                        ? (drivingCardBounceOn ? -3 : 0)
                        : 0
                )
                .animation(
                    shouldShowPlanButtonOnboardingBounce
                        ? .easeInOut(duration: 0.20)
                        : .default,
                    value: drivingCardBounceOn
                )
            }
            .padding(.horizontal)
            .padding(.top, 6)
            .padding(.bottom, 0)
        }
        .overlay(alignment: .top) {
            if showPlayBlockedHint {
                playBlockedHintText(for: playBlockedHintKind)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .offset(y: -56)
                    .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
    }

    private func triggerPlayBlockedFeedback() {
        triggerPlayBlockedFeedback(
            kind: .drivingAndFulfillmentForObjectives,
            highlightDriving: isDrivingForceEmptyState,
            highlightFulfillment: isFulfillmentEmptyState
        )
    }

    private func triggerPlayBlockedFeedback(
        kind: PlayBlockedHintKind,
        highlightDriving: Bool,
        highlightFulfillment: Bool
    ) {
        playBlockedResetWorkItem?.cancel()
        playBlockedHintKind = kind
        highlightDrivingRequirement = highlightDriving
        highlightFulfillmentRequirement = highlightFulfillment
        withAnimation(.easeInOut(duration: 0.15)) {
            showPlayBlockedHint = true
        }

        let workItem = DispatchWorkItem {
            highlightDrivingRequirement = false
            highlightFulfillmentRequirement = false
            withAnimation(.easeInOut(duration: 0.15)) {
                showPlayBlockedHint = false
            }
        }
        playBlockedResetWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.9, execute: workItem)
    }

    private func playBlockedHintText(for kind: PlayBlockedHintKind) -> Text {
        switch kind {
        case .drivingAndFulfillmentForObjectives:
            return Text("Please complete both your ")
                + Text(Image(systemName: "infinity"))
                + Text(" Driving Force and ")
                + Text(Image(systemName: "trophy"))
                + Text(" Fulfillment areas to continue.")
        case .drivingForFulfillment:
            return Text("Please complete your ")
                + Text(Image(systemName: "infinity"))
                + Text(" Driving Force to continue to ")
                + Text(Image(systemName: "trophy"))
                + Text(" Fulfillment.")
        }
    }

    // MARK: - Extracted Sections to reduce body complexity
    private var drivingForceSection: some View {
        let ultimateVision = drivingForces.first?.ultimateVision ?? ""
        let ultimatePurpose = drivingForces.first?.ultimatePurpose ?? ""
        let drivingForceCardBackground: Color = isDrivingForceEmptyState
            ? Color(.systemGray5)
            : Color(.secondarySystemBackground)

        return NavigationLink {
            Group {
                if isDrivingForceEmptyState {
                    DrivingForceStartView()
                } else {
                    DrivingForceView(autoOpenCreateVision: false)
                }
            }
        } label: {
            SectionCard(
                iconName: "infinity",
                title: "Driving Force",
                headerHint: "who you are",
                backgroundColor: drivingForceCardBackground
            ) {
                if isDrivingForceEmptyState {
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("No core identities")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.gray)
                            Text("Tap to add a vision and purpose")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("Open Driving Force")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 132)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                } else {
                    VStack(alignment: .leading, spacing: 12) {

                        // Ultimate Vision + Purpose group
                        VStack(alignment: .leading, spacing: 12) {

                            // Ultimate Vision
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ULTIMATE VISION")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)

                                Text(ultimateVision)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: false, vertical: true)
                            }

                            // Ultimate Purpose
                            VStack(alignment: .leading, spacing: 4) {
                                Text("ULTIMATE PURPOSE")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.gray)

                                Text(ultimatePurpose)
                                    .font(.body)
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                            }
                        }
                        .contentShape(Rectangle())
                        .pressHighlight(showVisionPurposePopup, cornerRadius: 8, inset: 3)
                        .onLongPressGesture(
                            minimumDuration: 0.5,
                            maximumDistance: 50,
                            pressing: { isPressing in
                                if !isPressing {
                                    withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                        showVisionPurposePopup = false
                                    }
                                }
                            },
                            perform: {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                    showVisionPurposePopup = true
                                }
                            }
                        )

                        // Icons Row with dynamic quadrant coloring
                        HStack(spacing: 16) {
                            ForEach([("heart.fill", "love"),
                                     ("lock.fill",  "vows"),
                                     ("bolt.fill",  "thrill"),
                                     ("shield.fill","hate")], id: \.1) { iconName, label in
                                ZStack {
                                    let value = usagePoints(for: label)
                                    let gap: Double = 4
                                    let halfGap = gap / 2
                                    let radius: CGFloat = 25
                                    let center = CGPoint(x: radius, y: radius)
                                    let quadrantAngles: [(start: Double, end: Double)] = [
                                        (-90,   0),   // top-right
                                        (   0,  90),  // bottom-right
                                        (  90, 180),  // bottom-left
                                        ( 180, 270)   // top-left
                                    ]

                                    // Draw each quadrant
                                    ZStack {
                                        ForEach(0..<4, id: \.self) { index in
                                            let angles = quadrantAngles[index]
                                            Path { path in
                                                path.addArc(center: center,
                                                            radius: radius,
                                                            startAngle: .degrees(angles.start + halfGap),
                                                            endAngle:   .degrees(angles.end   - halfGap),
                                                            clockwise: false)
                                            }
                                            .stroke((index + 1) <= value
                                                    ? Color.primary
                                                    : Color(.tertiaryLabel),
                                                    lineWidth: 2)
                                        }
                                    }
                                    .frame(width: radius * 2, height: radius * 2)

                                    // Icon and label
                                    VStack(spacing: 2) {
                                        Image(systemName: iconName)
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                        Text(label)
                                            .font(.caption2)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                    }
                                }
                                .contentShape(Rectangle())
                                .pressHighlight(pressedEmotion == emotionKey(for: label), cornerRadius: 8, inset: 3)
                                .onLongPressGesture(
                                    minimumDuration: 0.5,
                                    maximumDistance: 50,
                                    pressing: { isPressing in
                                        if !isPressing {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                pressedEmotion = nil
                                            }
                                        }
                                    },
                                    perform: {
                                        let key = emotionKey(for: label)
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                            pressedEmotion = key
                                        }
                                    }
                                )
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .frame(maxHeight: .infinity)
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(
            shouldShowDrivingOnboardingPulse
                ? (drivingCardBounceOn ? 1.012 : 1.0)
                : 1.0
        )
        .offset(
            y: shouldShowDrivingOnboardingPulse
                ? (drivingCardBounceOn ? -3 : 0)
                : 0
        )
        .animation(
            shouldShowDrivingOnboardingPulse
                ? .easeInOut(duration: 0.20)
                : .default,
            value: drivingCardBounceOn
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlightDrivingRequirement ? Color.red.opacity(0.9) : Color.clear, lineWidth: 2)
        )
    }

    private var fulfillmentSection: some View {
        let fulfillmentCardBackground: Color = isFulfillmentEmptyState
            ? Color(.systemGray5)
            : Color(.secondarySystemBackground)

        return NavigationLink {
            Group {
                if isFulfillmentEmptyState {
                    FulfillmentStartView()
                } else {
                    FulfillmentView()
                }
            }
        } label: {
            SectionCard(
                iconName: "trophy",
                title: "Fulfillment",
                headerHint: "why you live",
                backgroundColor: fulfillmentCardBackground
            ) {
                if isFulfillmentEmptyState {
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("No life alignment")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.gray)
                            Text("Tap to add fulfillment categories")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("Open Fulfillment")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 132)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                } else {
                    HStack(alignment: .center, spacing: 16) {
                        ZStack {
                            FulfillmentInteractiveRadar(
                                metrics: fulfillmentMetrics,
                                selectedIndex: $fulfillmentRadarSelectedIndex,
                                onManualSelect: {},
                                enableInteraction: false,
                                useOriginalDotStyle: true,
                                emphasizeSelectedSlice: false
                            )
                        }
                        .frame(width: 140, height: 140)
                        .padding(.top, 10)
                        .matchedGeometryEffect(
                            id: "fulfillmentGraph",
                            in: graphNamespace,
                            properties: .frame,
                            anchor: .center
                        )
                        
                        // labels
                        VStack(alignment: .leading, spacing: 6) {
                            let metrics = fulfillmentMetrics
                            ForEach(metrics, id: \.0) { metric in
                                Text(metric.0)
                                    .foregroundColor(metric.1)
                                    .fontWeight(.bold)
                                    .contentShape(Rectangle())
                                    .pressHighlight(pressedCategoryTitle == metric.0, cornerRadius: 6, inset: 2)
                                    .onLongPressGesture(
                                        minimumDuration: 0.5,
                                        maximumDistance: 50,
                                        pressing: { isPressing in
                                            if !isPressing {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                    pressedCategoryTitle = nil
                                                }
                                            }
                                        },
                                        perform: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                pressedCategoryTitle = metric.0
                                            }
                                        }
                                    )
                            }
                        }
                        .font(.subheadline)
                    }
                }
            }
        }
        .buttonStyle(.plain)
        .scaleEffect(
            shouldShowFulfillmentOnboardingPulse
                ? (drivingCardBounceOn ? 1.012 : 1.0)
                : 1.0
        )
        .offset(
            y: shouldShowFulfillmentOnboardingPulse
                ? (drivingCardBounceOn ? -3 : 0)
                : 0
        )
        .animation(
            shouldShowFulfillmentOnboardingPulse
                ? .easeInOut(duration: 0.20)
                : .default,
            value: drivingCardBounceOn
        )
        .frame(maxHeight: .infinity)
        .overlay {
            if isDrivingForceEmptyState && !setupHomepageMode {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        triggerPlayBlockedFeedback(
                            kind: .drivingForFulfillment,
                            highlightDriving: true,
                            highlightFulfillment: false
                        )
                    }
            }
        }
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(highlightFulfillmentRequirement ? Color.red.opacity(0.9) : Color.clear, lineWidth: 2)
        )
    }

    private var objectivesSection: some View {
        let objectivesCardBackground: Color = isObjectivesEmptyState
            ? Color(.systemGray5)
            : Color(.secondarySystemBackground)
        return NavigationLink {
            if isObjectivesEmptyState {
                ObjectivesStartView()
            } else {
                ObjectivesView(autoOpenAddOutcome: false)
            }
        } label: {
            SectionCard(
                iconName: "scope",
                title: "Objectives",
                headerHint: "what you want",
                backgroundColor: objectivesCardBackground
            ) {
                if isObjectivesEmptyState {
                    VStack(spacing: 12) {
                        VStack(spacing: 4) {
                            Text("No long term goals")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.gray)
                            Text("Tap to add an Outcome")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }

                        Text("Open Objectives")
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(.gray)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                Capsule()
                                    .fill(Color(.systemGray6))
                            )
                    }
                    .frame(maxWidth: .infinity, minHeight: 132)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemGray5))
                    )
                } else {
                    HStack(alignment: .top, spacing: 2) {

                        // Left: four outcome texts with dividers
                        VStack(alignment: .leading, spacing: 8) {
                            let previewRows = objectivesCardPreviewRows(limit: 4)

                            ForEach(Array(previewRows.enumerated()), id: \.element.id) { idx, row in
                                switch row.kind {
                                case .outcome(let outcome):
                                    let remainingDays = daysUntil(outcome.end)
                                    HStack(alignment: .center, spacing: 8) {
                                        ZStack {
                                            RoundedRectangle(cornerRadius: 4)
                                                .fill(categoryBackgroundColor(for: outcome.category))
                                                .frame(width: 40, height: 20)

                                            Text("\(remainingDays)d")
                                                .font(.caption)
                                                .foregroundColor(remainingDays < 0 ? .red : .primary)
                                                .bold()
                                        }

                                        Text(outcome.outcome)
                                            .font(.body)
                                            .foregroundColor(categoryTextColor(for: outcome.category))
                                            .lineLimit(1)

                                        if let measure = latestMeasure(for: outcome),
                                           measure.measure_amt != 0 && measure.format != nil {
                                            Spacer()
                                            ZStack {
                                                Circle()
                                                    .stroke(Color(UIColor.systemGray3), lineWidth: 1.5)
                                                    .frame(width: 16, height: 16)

                                                Circle()
                                                    .trim(from: 0, to: progressTrim(for: measure, outcomeID: outcome.outcome_id))
                                                    .stroke(Color.primary, lineWidth: 1.5)
                                                    .frame(width: 16, height: 16)
                                                    .rotationEffect(.degrees(-90))
                                            }
                                        }
                                    }
                                    .contentShape(Rectangle())
                                    .pressHighlight(pressedOutcome?.outcome_id == outcome.outcome_id, cornerRadius: 8, inset: 3)
                                    .onLongPressGesture(
                                        minimumDuration: 0.5,
                                        maximumDistance: 50,
                                        pressing: { isPressing in
                                            if !isPressing {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                    pressedOutcome = nil
                                                }
                                            }
                                        },
                                        perform: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                pressedOutcome = outcome
                                            }
                                        }
                                    )

                                case .upcomingOutcome(let outcome, let startsInDays):
                                    HStack(alignment: .center, spacing: 8) {
                                        HStack(spacing: 4) {
                                            Image(systemName: "clock")
                                                .font(.caption2)
                                                .foregroundStyle(.gray)
                                            Text("\(startsInDays)d")
                                                .font(.caption.weight(.semibold))
                                                .foregroundStyle(.gray)
                                        }
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 3)
                                        .background(
                                            RoundedRectangle(cornerRadius: 6, style: .continuous)
                                                .fill(Color(.systemGray5))
                                        )

                                        Text(outcome.outcome)
                                            .font(.body)
                                            .foregroundColor(categoryTextColor(for: outcome.category))
                                            .lineLimit(1)

                                        Spacer(minLength: 0)
                                    }
                                    .contentShape(Rectangle())
                                    .pressHighlight(pressedOutcome?.outcome_id == outcome.outcome_id, cornerRadius: 8, inset: 3)
                                    .onLongPressGesture(
                                        minimumDuration: 0.5,
                                        maximumDistance: 50,
                                        pressing: { isPressing in
                                            if !isPressing {
                                                withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                    pressedOutcome = nil
                                                }
                                            }
                                        },
                                        perform: {
                                            withAnimation(.spring(response: 0.3, dampingFraction: 0.85)) {
                                                pressedOutcome = outcome
                                            }
                                        }
                                    )
                                }

                                if idx < (previewRows.count - 1) {
                                    Divider()
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        if enableProjectsFeature {
                            // Right: two folder icons
                            VStack(spacing: 8) {
                                ZStack {
                                    Image(systemName: "doc.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 65)
                                        .foregroundColor(Color.gray.opacity(0.2))

                                    Text("+ Add Project")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .frame(width: 50)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .offset(y: 10)
                                }

                                ZStack {
                                    Image(systemName: "doc.fill")
                                        .resizable()
                                        .scaledToFit()
                                        .frame(height: 65)
                                        .foregroundColor(Color.gray.opacity(0.2))

                                    Text("+ Add Project")
                                        .font(.caption2)
                                        .bold()
                                        .foregroundColor(.primary)
                                        .multilineTextAlignment(.center)
                                        .lineLimit(2)
                                        .truncationMode(.tail)
                                        .frame(width: 50)
                                        .fixedSize(horizontal: false, vertical: true)
                                        .offset(y: 10)
                                }
                            }
                            .frame(width: 60, alignment: .trailing)
                        }
                    }
                    .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
                    .padding(.vertical, 12)
                    .overlay(
                        Image(systemName: "ellipsis")
                            .font(.system(size: 20, weight: .bold))
                            .foregroundColor(Color(.lightGray))
                            .offset(y: 1),
                        alignment: .bottom
                    )
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
        .overlay {
            if !canOpenPlanOrActionFlow {
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        triggerPlayBlockedFeedback()
                    }
            }
        }
    }

    private func bounceDrivingCardOnce() {
        drivingCardBounceOn = false
        DispatchQueue.main.async {
            guard shouldShowAnyOnboardingBounce else { return }
            drivingCardBounceOn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                drivingCardBounceOn = false
            }
        }
    }

    private func bounceLittleWinsLogoDotOnce() {
        littleWinsLogoDotBounceOn = false
        DispatchQueue.main.async {
            guard shouldShowLittleWinsLogoDot else { return }
            littleWinsLogoDotBounceOn = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                littleWinsLogoDotBounceOn = false
            }
        }
    }
}

struct SectionCard<Content: View>: View {
    let iconName: String
    let title: String
    let headerHint: String?
    let backgroundColor: Color
    let content: () -> Content
    @Environment(\.contentCardDensity) private var cardDensity

    init(
        iconName: String,
        title: String,
        headerHint: String? = nil,
        backgroundColor: Color = Color(.secondarySystemBackground),
        @ViewBuilder content: @escaping () -> Content
    ) {
        self.iconName = iconName
        self.title = title
        self.headerHint = headerHint
        self.backgroundColor = backgroundColor
        self.content = content
    }

    var body: some View {
        let d = max(0.82, min(cardDensity, 1.12))
        VStack(spacing: 0) {
            HStack {
                Image(systemName: iconName)
                    .font(.headline)
                Text(title)
                    .font(.headline)

                Spacer()

                if let headerHint, !headerHint.isEmpty {
                    Text(headerHint)
                        .font(.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 12 * d)
            .foregroundColor(.primary)

            Divider()
                .padding(.vertical, 4 * d)

            content()
                .padding(.horizontal)
                .padding(.bottom, 12 * d)
        }
        .background(backgroundColor)
        .cornerRadius(16 * d)
        .shadow(color: Color.primary.opacity(0.08), radius: 6, x: 0, y: 3)
    }
}

private struct ContentCardDensityKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1.0
}

private struct HomeCardHeightPreferenceKey: PreferenceKey {
    static var defaultValue: [String: CGFloat] = [:]

    static func reduce(value: inout [String: CGFloat], nextValue: () -> [String: CGFloat]) {
        value.merge(nextValue()) { _, new in new }
    }
}

private struct HeaderLogoWidthPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0

    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        let next = nextValue()
        if next > 0 { value = next }
    }
}

private struct RadarPolygonOutline: Shape {
    let sides: Int

    func path(in rect: CGRect) -> Path {
        let clampedSides = max(3, min(7, sides))
        let center = CGPoint(x: rect.midX, y: rect.midY)
        let radius = min(rect.width, rect.height) / 2
        let startAngle = -CGFloat.pi / 2

        var path = Path()
        for idx in 0..<clampedSides {
            let angle = startAngle + (CGFloat(idx) * 2 * .pi / CGFloat(clampedSides))
            let point = CGPoint(
                x: center.x + cos(angle) * radius,
                y: center.y + sin(angle) * radius
            )
            if idx == 0 {
                path.move(to: point)
            } else {
                path.addLine(to: point)
            }
        }
        path.closeSubpath()
        return path
    }
}

private extension EnvironmentValues {
    var contentCardDensity: CGFloat {
        get { self[ContentCardDensityKey.self] }
        set { self[ContentCardDensityKey.self] = newValue }
    }
}

struct PassionPopupOverlay: View {
    let emotionTitle: String
    let items: [Passion]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(emotionTitle)
                    .font(.headline)
                    .fontWeight(.bold)
                Spacer()
            }
            if items.isEmpty {
                Text("No items yet")
                    .foregroundColor(.secondary)
            } else {
                if items.count <= 8 {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(items, id: \.passion_id) { p in
                            Text("• \(p.passion)")
                                .foregroundColor(.primary)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                } else {
                    let rowHeight: CGFloat = 22
                    let cap: CGFloat = 400
                    let estimated: CGFloat = rowHeight * CGFloat(items.count)
                    ScrollView {
                        VStack(alignment: .leading, spacing: 6) {
                            ForEach(items, id: \.passion_id) { p in
                                Text("• \(p.passion)")
                                    .foregroundColor(.primary)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .frame(height: min(estimated, cap))
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .padding()
    }
}

struct VisionPurposePopupOverlay: View {
    let vision: String
    let purpose: String

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Ultimate Vision")
                .font(.headline)
                .fontWeight(.bold)
            if vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("+ Add My Ultimate Vision")
                    .foregroundColor(.secondary)
            } else {
                Text(vision)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Divider().padding(.vertical, 4)

            Text("Ultimate Purpose")
                .font(.headline)
                .fontWeight(.bold)
            if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("+ Add My Ultimate Purpose")
                    .foregroundColor(.secondary)
            } else {
                Text(purpose)
                    .foregroundColor(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .padding()
    }
}

struct OutcomePopupOverlay: View {
    let outcome: Outcomes
    let measure: OutcomesMeasure?

    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward) private var allMeasureEntries: [OutcomesMeasureEntry]

    private func categoryColor(for category: String) -> Color {
        FulfillmentCategoryTheme.color(for: category)
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        let baseColor = UIColor(categoryColor(for: category))
        return Color(baseColor.adjusted(by: 0.8))
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.format != nil
    }

    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
        return components.day ?? 0
    }

    private func daysUntilStart(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
        return max(0, components.day ?? 0)
    }

    private func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }

    private func formattedDate(_ date: Date) -> String {
        let calendar = Calendar.current
        let isSameYear = calendar.isDate(date, equalTo: .now, toGranularity: .year)
        let formatter = DateFormatter()
        formatter.dateFormat = isSameYear ? "M/d" : "M/d/yy"
        return formatter.string(from: date)
    }

    private func formattedValue(_ value: Double, format: String) -> String {
        let roundedValue = String(format: "%.0f", value)
        switch format {
        case "Dollars": return "$\(roundedValue)"
        case "Percentage": return "\(roundedValue)%"
        default: return roundedValue
        }
    }

    private func progressValue(measure: Double, measureAmt: Double) -> Double {
        let start = allMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id })?.measure ?? measure
        return ProgressCircleView.progressValue(current: measure, goal: measureAmt, start: start)
    }

    private func measurementStatusPrefix(for measuredAt: Date) -> String {
        if let startDate = allMeasureEntries
            .filter({ $0.outcome_id == outcome.outcome_id })
            .min(by: { $0.measuredAt < $1.measuredAt })?
            .measuredAt,
           Calendar.current.isDate(startDate, inSameDayAs: measuredAt) {
            return "started"
        }
        return "updated"
    }

    @ViewBuilder
    private func DarkMeasurableOutcomeBox(measure: Double, measuredAt: Date, measureAmt: Double, endDate: Date, format: String, statusPrefix: String) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(formattedValue(measure, format: format))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("\(statusPrefix) \(formattedDate(measuredAt))")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)

            Rectangle()
                .fill(Color.white.opacity(0.2))
                .frame(width: 1)

            VStack(spacing: 2) {
                Text(formattedValue(measureAmt, format: format))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("\(formattedDate(endDate)) goal")
                    .font(.caption2)
                    .foregroundColor(.primary)
            }
            .padding(.vertical, 6)
            .padding(.horizontal, 10)
            .frame(maxWidth: .infinity)
        }
        .background(
            RoundedRectangle(cornerRadius: 8)
                .fill(Color(.secondarySystemBackground))
        )
    }

    @ViewBuilder
    private func DarkProgressCircleView(measure: Double, measureAmt: Double) -> some View {
        let progress = progressValue(measure: measure, measureAmt: measureAmt)
        let percentageText = String(format: "%.0f%%", progress * 100)
        ZStack {
            Circle()
                .stroke(Color.white.opacity(0.25), lineWidth: 4)
                .frame(width: 40, height: 40)

            Circle()
                .trim(from: 0, to: CGFloat(progress))
                .stroke(Color.white, lineWidth: 4)
                .frame(width: 40, height: 40)
                .rotationEffect(.degrees(-90))

            Text(percentageText)
                .font(.caption)
                .fontWeight(.bold)
                .foregroundColor(.white)
        }
    }

    var body: some View {
        let isUpcoming = Calendar.current.startOfDay(for: outcome.start) > Calendar.current.startOfDay(for: .now)
        VStack(alignment: .leading, spacing: 12) {
            if isUpcoming {
                let daysToStart = daysUntilStart(outcome.start)
                HStack(spacing: 8) {
                    Image(systemName: "clock")
                        .foregroundColor(.gray)
                        .font(.caption)
                    Text("starts in \(daysToStart) day\(daysToStart == 1 ? "" : "s") on \(formattedDate(outcome.start))")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .padding(.vertical, 4)
                .padding(.horizontal, 8)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color(.systemGray5))
                )
            }

            // Goal
            Text(outcome.outcome)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(categoryColor(for: outcome.category))
                .multilineTextAlignment(.leading)
                .fixedSize(horizontal: false, vertical: true)

            // Reasons
            if !outcome.reasons.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(outcome.reasons)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.leading)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Days + Progress
            HStack(spacing: 8) {
                let dayValue = isUpcoming ? daysBetween(outcome.start, outcome.end) : daysUntil(outcome.end)
                let shouldShowRed = !isUpcoming && dayValue < 0
                VStack(spacing: 2) {
                    Text("\(dayValue)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(shouldShowRed ? .red : .black)
                    Text(isUpcoming ? "days long" : "days left")
                        .font(.caption2)
                        .foregroundColor(shouldShowRed ? .red : .black)
                }
                .padding(.vertical, 6)
                .padding(.horizontal, 10)
                .background(
                    RoundedRectangle(cornerRadius: 8)
                        .fill(lightenedCategoryColor(for: outcome.category))
                )
                .frame(height: 44)

                if let measure, isOutcomeMeasurable(measure) {
                    if colorScheme == .dark {
                        DarkMeasurableOutcomeBox(
                            measure: measure.measure,
                            measuredAt: measure.measuredAt,
                            measureAmt: measure.measure_amt,
                            endDate: outcome.end,
                            format: measure.format ?? "Number",
                            statusPrefix: measurementStatusPrefix(for: measure.measuredAt)
                        )
                        .frame(height: 44)

                        DarkProgressCircleView(
                            measure: measure.measure,
                            measureAmt: measure.measure_amt
                        )
                        .frame(width: 40, height: 40)
                    } else {
                        MeasurableOutcomeBox(
                            measure: measure.measure,
                            measuredAt: measure.measuredAt,
                            measureAmt: measure.measure_amt,
                            endDate: outcome.end,
                            format: measure.format ?? "Number",
                            statusPrefix: measurementStatusPrefix(for: measure.measuredAt)
                        )
                        .frame(height: 44)

                        ProgressCircleView(
                            measure: measure.measure,
                            measureAmt: measure.measure_amt,
                            startMeasure: allMeasureEntries.first(where: { $0.outcome_id == outcome.outcome_id })?.measure ?? measure.measure
                        )
                        .frame(width: 40, height: 40)
                    }
                }
            }
        }
        .padding(16)
        .background(.regularMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .padding()
    }
}

struct CategoryFulfillmentPopupOverlay: View {
    let category: String
    let tint: Color
    let titleColor: Color
    let vision: String
    let purpose: String
    let roles: [String]
    let foci: [String]
    let resources: [String]
    let passions: [Passion]

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(.headline)
            .fontWeight(.bold)
            .foregroundColor(.black)
    }

    private func bulletList(_ items: [String]) -> some View {
        Group {
            if items.isEmpty {
                Text("No items yet")
                    .foregroundColor(.black)
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(items, id: \.self) { item in
                        Text("• \(item)")
                            .foregroundColor(.black)
                    }
                }
            }
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(category)
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(titleColor)

            // Vision
            sectionHeader("Vision")
            if vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("+ Add Vision")
                    .foregroundColor(.black)
            } else {
                Text(vision)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Purpose
            sectionHeader("Purpose")
            if purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("+ Add Purpose")
                    .foregroundColor(.black)
            } else {
                Text(purpose)
                    .foregroundColor(.black)
                    .fixedSize(horizontal: false, vertical: true)
            }

            // Roles
            sectionHeader("Roles")
            bulletList(roles)

            // Little Wins
            sectionHeader("Little Wins")
            bulletList(foci)

            // Resources
            sectionHeader("Resources")
            bulletList(resources)

            // Passions
            sectionHeader("Passions")
            Group {
                if passions.isEmpty {
                    Text("No items yet")
                        .foregroundColor(.black)
                } else {
                    VStack(alignment: .leading, spacing: 6) {
                        ForEach(passions, id: \.passion_id) { p in
                            Text("• \(p.emotion.capitalized): \(p.passion)")
                                .foregroundColor(.black)
                        }
                    }
                }
            }
        }
        .padding(16)
        .background(
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(.ultraThinMaterial)
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(tint.opacity(0.35))
            }
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
        .shadow(color: Color.black.opacity(0.2), radius: 10, x: 0, y: 6)
        .padding()
    }
}

struct ContentLittleWinsManagerSheetView: View {
    private struct EditorTarget: Identifiable {
        let categoryID: UUID
        let categoryTitle: String
        let focusID: UUID?
        let autoFocus: Bool

        var id: String {
            if let focusID { return "edit-\(focusID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    let categories: [(id: UUID, title: String)]
    let lockedCategoryID: UUID?

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var foci: [FulfillmentFocus]
    @State private var selectedCategoryID: UUID?
    @State private var isDeleteMode = false
    @State private var selectedIDsForDelete: Set<UUID> = []
    @State private var editorTarget: EditorTarget?
    @State private var showDeleteGuardHint = false

    private let placeholder = "Select Fulfillment Area"

    init(
        categories: [(id: UUID, title: String)],
        lockedCategoryID: UUID? = nil
    ) {
        self.categories = categories
        self.lockedCategoryID = lockedCategoryID
        _selectedCategoryID = State(initialValue: lockedCategoryID)
    }

    private var selectedCategoryTitle: String {
        guard let id = selectedCategoryID else { return "" }
        return categories.first(where: { $0.id == id })?.title ?? ""
    }

    private var selectedCategoryColor: Color {
        selectedCategoryTitle.isEmpty ? .blue : FulfillmentCategoryTheme.color(for: selectedCategoryTitle)
    }

    private var selectedDisplayText: String {
        selectedCategoryTitle.isEmpty ? placeholder : selectedCategoryTitle
    }

    private var littleWinsForSelection: [FulfillmentFocus] {
        guard let selectedCategoryID else { return [] }
        return foci
            .filter { $0.category_id == selectedCategoryID }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    HStack(spacing: 8) {
                        Text("Fulfillment Area")
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Spacer(minLength: 8)
                        Group {
                            if lockedCategoryID != nil {
                                HStack(spacing: 4) {
                                    Text(selectedDisplayText)
                                        .foregroundStyle(selectedCategoryColor.opacity(0.6))
                                        .fontWeight(selectedCategoryTitle.isEmpty ? .regular : .bold)
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                }
                                .fixedSize(horizontal: false, vertical: true)
                            } else {
                                Menu {
                                    Button(placeholder) {
                                        selectCategory(nil)
                                    }
                                    ForEach(categories, id: \.id) { category in
                                        Button(category.title) {
                                            selectCategory(category.id)
                                        }
                                    }
                                } label: {
                                    HStack(spacing: 4) {
                                        Text(selectedDisplayText)
                                            .foregroundStyle(selectedCategoryColor)
                                            .fontWeight(selectedCategoryTitle.isEmpty ? .regular : .bold)
                                            .lineLimit(1)
                                            .truncationMode(.tail)
                                        Image(systemName: "chevron.up.chevron.down")
                                            .font(.caption2)
                                            .foregroundStyle(selectedCategoryColor)
                                    }
                                    .fixedSize(horizontal: false, vertical: true)
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Section {
                    Button {
                        startCreatingNew()
                    } label: {
                        HStack {
                            Text("Add Little Win")
                                .foregroundStyle(selectedCategoryID == nil ? Color.secondary : Color.accentColor)
                            Spacer()
                        }
                        .frame(minHeight: 44, alignment: .center)
                        .padding(.horizontal, 14)
                    }
                    .buttonStyle(.plain)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    .disabled(selectedCategoryID == nil || isDeleteMode || littleWinsForSelection.count >= 3)

                    if selectedCategoryID != nil {
                        ForEach(littleWinsForSelection, id: \.id) { focus in
                            Button {
                                guard !isDeleteMode else {
                                    toggleDeleteSelection(for: focus.id)
                                    return
                                }
                                beginEditing(focus)
                            } label: {
                                HStack(spacing: 10) {
                                    if isDeleteMode {
                                        Image(systemName: selectedIDsForDelete.contains(focus.id) ? "checkmark.circle.fill" : "circle")
                                            .foregroundStyle(selectedIDsForDelete.contains(focus.id) ? .red : .secondary)
                                    }
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(focus.activity)
                                            .foregroundStyle(.primary)
                                        let rule = LittleWinsScheduleStore.rule(for: focus.id)
                                        if !rule.canCompleteAnyDay {
                                            Text(weekdaySummary(rule.activeWeekdayMask))
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    Spacer()
                                    if !isDeleteMode {
                                        Image(systemName: "chevron.right")
                                            .font(.caption2.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .animation(nil, value: selectedCategoryID)
            .navigationTitle("Manage Little Wins")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    if isDeleteMode {
                        Button("Cancel") {
                            isDeleteMode = false
                            selectedIDsForDelete.removeAll()
                        }
                    } else {
                        Button("Done") { dismiss() }
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    if isDeleteMode {
                        Button("Delete") { deleteSelected() }
                            .foregroundStyle(selectedIDsForDelete.isEmpty ? Color.secondary : Color.red)
                            .disabled(selectedIDsForDelete.isEmpty)
                    } else if selectedCategoryID != nil && !littleWinsForSelection.isEmpty {
                        Button("Edit") {
                            isDeleteMode = true
                            selectedIDsForDelete.removeAll()
                        }
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .sheet(item: $editorTarget) { target in
            LittleWinEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                focusID: target.focusID,
                autoFocusTextField: target.autoFocus
            )
        }
        .overlay(alignment: .bottom) {
            if showDeleteGuardHint {
                littleWinsDeleteGuardHintCard
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
            }
        }
        .animation(.easeInOut(duration: 0.18), value: showDeleteGuardHint)
    }

    private func startCreatingNew() {
        guard let selectedCategoryID else { return }
        guard littleWinsForSelection.count < 3 else { return }
        editorTarget = .init(
            categoryID: selectedCategoryID,
            categoryTitle: selectedCategoryTitle,
            focusID: nil,
            autoFocus: true
        )
    }

    private func selectCategory(_ id: UUID?) {
        var transaction = Transaction()
        transaction.animation = nil
        withTransaction(transaction) {
            selectedCategoryID = id
            isDeleteMode = false
            selectedIDsForDelete.removeAll()
        }
    }

    private func beginEditing(_ focus: FulfillmentFocus) {
        guard let category = categories.first(where: { $0.id == focus.category_id }) else { return }
        editorTarget = .init(
            categoryID: focus.category_id,
            categoryTitle: category.title,
            focusID: focus.id,
            autoFocus: false
        )
    }

    private func toggleDeleteSelection(for id: UUID) {
        if selectedIDsForDelete.contains(id) {
            selectedIDsForDelete.remove(id)
        } else {
            selectedIDsForDelete.insert(id)
        }
    }

    private func weekdaySummary(_ mask: Int) -> String {
        let normalizedMask = mask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = labels.enumerated().compactMap { index, label in
            (normalizedMask & (1 << index)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func deleteSelected() {
        let targets = littleWinsForSelection.filter { selectedIDsForDelete.contains($0.id) }
        guard !targets.isEmpty else { return }
        if foci.count - targets.count < 1 {
            showMinimumLittleWinsGuardHint()
            return
        }
        for focus in targets {
            modelContext.insert(
                FulfillmentFocusArchive(
                    category_id: focus.category_id,
                    updatedAt: focus.updatedAt,
                    activity: focus.activity,
                    rank: focus.rank,
                    archivedAt: Date()
                )
            )
            LittleWinsScheduleStore.removeRule(for: focus.id)
            LittleWinsIntegrationStore.removeConfig(for: focus.id)
            RecentlyDeletedStore.trash(focus, in: modelContext)
        }
        try? modelContext.save()
        selectedIDsForDelete.removeAll()
        isDeleteMode = false
    }

    private var littleWinsDeleteGuardHintCard: some View {
        HStack(spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundStyle(.white)
            Text("Keep at least 1 Little Win across Fulfillment Areas.")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.leading)
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color.red.opacity(0.92))
        )
        .shadow(color: Color.black.opacity(0.18), radius: 8, x: 0, y: 4)
        .allowsHitTesting(false)
    }

    private func showMinimumLittleWinsGuardHint() {
        withAnimation(.easeInOut(duration: 0.18)) {
            showDeleteGuardHint = true
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 2.0) {
            withAnimation(.easeInOut(duration: 0.18)) {
                showDeleteGuardHint = false
            }
        }
    }
}

struct ContentView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            ContentView()
                .previewDevice("iPhone SE (2nd generation)")
            ContentView()
                .previewDevice("iPhone 14")
            ContentView()
                .previewDevice("iPhone 14 Pro Max")
        }
    }
}

extension View {
    /// Press highlight that stays BEHIND content and doesn't change layout.
    func pressHighlight(
        _ isOn: Bool,
        cornerRadius: CGFloat = 8,
        inset: CGFloat = 3
    ) -> some View {
        self.background {
            if isOn {
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .fill(Color(.systemGray5))
                    .overlay(
                        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                            .stroke(Color.gray.opacity(0.35), lineWidth: 1)
                    )
                    // Grow outward without re-layout
                    .padding(-inset)
                    // Make sure it never steals taps/press logic
                    .allowsHitTesting(false)
            }
        }
    }
}
