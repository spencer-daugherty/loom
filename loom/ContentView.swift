import SwiftUI
import Charts
import SwiftData

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
    @State private var isPresentingCaptureView = false
    @State private var pressedEmotion: String? = nil
    @State private var pressedOutcome: Outcomes? = nil
    @State private var showVisionPurposePopup: Bool = false
    @State private var pressedCategoryTitle: String? = nil
    @State private var fulfillmentRadarSelectedIndex: Int = 0
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var graphNamespace
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
    @Environment(\.modelContext) private var modelContext

    // Model-derived state
    @Query(sort: \ActivePlanState.id, order: .forward)
    private var activePlanStates: [ActivePlanState]

    @State private var navPath: [PlayDestination] = []
    @State private var playSheetDestination: PlayDestination? = nil

    private enum PlayDestination: String, Identifiable, Hashable {
        case plan
        case action
        var id: String { rawValue }
    }

    private enum PlayBlockedHintKind {
        case drivingAndFulfillmentForObjectives
        case drivingForFulfillment
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
        NavigationStack(path: $navPath) {
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
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                            .onPreferenceChange(HomeCardHeightPreferenceKey.self) { heights in
                                var updated = measuredCardHeights
                                updated.merge(heights) { _, new in new }
                                if updated != measuredCardHeights {
                                    measuredCardHeights = updated
                                }
                            }
                            .environment(\.contentCardDensity, cardDensity)

                            footer
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
        .navigationDestination(for: ContentView.PlayDestination.self) { destination in
            switch destination {
            case .plan:
                PlanView()
            case .action:
                ActionView()
            }
        }
        .fullScreenCover(item: $playSheetDestination) { destination in
            switch destination {
            case .plan:
                PlanView()
            case .action:
                ActionView()
            }
        }
        .sheet(isPresented: $isPresentingCaptureView) {
            CaptureView()
                .presentationDragIndicator(.visible)
        }
        .onChange(of: isActivePlan) { _, newValue in
            // When Plan Step 5 activates the plan, automatically launch ActionView.
            if newValue == true {
                playSheetDestination = .action
            }
        }
        .onAppear {
            beginStartupPreparationIfNeeded()
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
        ZStack {
            HStack {
                Text(Date()
                    .formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Spacer()

                NavigationLink {
                    AccountView()
                } label: {
                    Image(systemName: "person.circle")
                        .font(.system(size: 28))
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal)
            .padding(.top, 8) // Added thin padding above header

            // Center-aligned logo
            Image("logo")
                .resizable()
                .scaledToFit()
                .frame(height: 40)
                .modifier(DarkModeInvertImage())
        }
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

                Button(action: {
                    guard canOpenPlanOrActionFlow else {
                        triggerPlayBlockedFeedback()
                        return
                    }
                    playSheetDestination = isActiveActionFlow ? .action : .plan
                }) {
                    Image(systemName: isActiveActionFlow ? "forward.fill" : "play.fill")
                        .font(.title)
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 60, height: 60)
                        .background(canOpenPlanOrActionFlow ? Color.accentColor : Color(.systemGray3))
                        .opacity(canOpenPlanOrActionFlow ? 1.0 : 0.62)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
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
                + Text(" Fulfillment categories at a minimum to create Objectives.")
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
            if isDrivingForceEmptyState {
                DrivingForceStartView()
            } else {
                DrivingForceView(autoOpenCreateVision: false)
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
            if isFulfillmentEmptyState {
                FulfillmentStartView()
            } else {
                FulfillmentView()
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
        let isObjectivesEmptyState = shouldShowBlankHomepageAppearance || (outcomes.isEmpty && !enableProjectsFeature)
        let objectivesCardBackground: Color = isObjectivesEmptyState
            ? Color(.systemGray5)
            : Color(.secondarySystemBackground)
        return NavigationLink {
            ObjectivesView(autoOpenAddOutcome: isObjectivesEmptyState)
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
                            let currentDate = Date()
                            let filteredOutcomes = outcomes.filter { $0.start <= currentDate }

                            ForEach(filteredOutcomes.prefix(4)) { outcome in
                                let remainingDays = daysUntil(outcome.end)
                                HStack(alignment: .center, spacing: 8) {

                                    // Box with days until end date
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(categoryBackgroundColor(for: outcome.category))
                                            .frame(width: 40, height: 20)

                                        Text("\(remainingDays)d")
                                            .font(.caption)
                                            .foregroundColor(remainingDays < 0 ? .red : .primary)
                                            .bold()
                                    }

                                    // Outcome text
                                    Text(outcome.outcome)
                                        .font(.body)
                                        .foregroundColor(categoryTextColor(for: outcome.category))
                                        .lineLimit(1)

                                    // Progress Circle
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

                                if outcome != filteredOutcomes.prefix(4).last {
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
        VStack(alignment: .leading, spacing: 12) {
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
                let remainingDays = daysUntil(outcome.end)
                VStack(spacing: 2) {
                    Text("\(remainingDays)")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(remainingDays < 0 ? .red : .black)
                    Text("days left")
                        .font(.caption2)
                        .foregroundColor(remainingDays < 0 ? .red : .black)
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

            // Three-to-Thrive
            sectionHeader("Three-to-Thrive")
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
