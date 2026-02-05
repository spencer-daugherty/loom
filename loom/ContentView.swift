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
    @State private var isPresentingCaptureView = false
    @State private var pressedEmotion: String? = nil
    @State private var pressedOutcome: Outcomes? = nil
    @State private var showVisionPurposePopup: Bool = false
    @Environment(\.colorScheme) private var colorScheme
    @Namespace private var graphNamespace
    @State private var showSplash: Bool = true
    
    private func daysUntil(_ endDate: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: Date(), to: endDate)
        return max(0, components.day ?? 0)
    }
    
    var body: some View {
        NavigationStack {
            ZStack {
                // Background
                Color(.systemGroupedBackground)
                    .edgesIgnoringSafeArea(.all)
                
                // Main content pinned to top
                VStack(spacing: 10) {
                    header

                    VStack(spacing: 16) {
                        drivingForceSection
                        fulfillmentSection
                        objectivesSection
                    }
                    .padding(.horizontal)

                    Spacer(minLength: 0)   // <-- this is the real “pin to bottom”

                    footer
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                
                // Loading Splash Overlay
                if showSplash {
                    LoadingSplashView(
                        metrics: fulfillmentMetrics,
                        namespace: graphNamespace
                    )
                    .transition(.opacity)
                    .zIndex(2)
                }

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
            }
        }
        .onAppear {
            // Ensure splash shows for at least 1 second
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                withAnimation(.easeInOut(duration: 0.6)) {
                    showSplash = false
                }
            }
        }
        .tint(Color.accentColor)
    }
    
    @Query(sort: \DrivingForce.updatedAt, order: .reverse)
    private var drivingForces: [DrivingForce]
    
    @Query(sort: \Outcomes.rank, order: .forward)
    private var outcomes: [Outcomes]
    
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse)
    private var outcomeMeasures: [OutcomesMeasure]

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
        switch category {
        case "Career & Business": return .blue
        case "Leadership & Impact": return .indigo
        case "Wealth & Lifestyle": return .green
        case "Mind & Meaning": return .purple
        case "Love & Relationships": return .red
        case "Health & Vitality": return .orange
        default: return .black
        }
    }

    private func categoryBaseUIColor(for category: String) -> UIColor {
        switch category {
        case "Career & Business": return .systemBlue
        case "Leadership & Impact": return .systemIndigo
        case "Wealth & Lifestyle": return .systemGreen
        case "Mind & Meaning": return .systemPurple
        case "Love & Relationships": return .systemRed
        case "Health & Vitality": return .systemOrange
        default: return .black
        }
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
    
    private func usagePoints(for emotionLabel: String) -> Int {
        let key = emotionKey(for: emotionLabel)
        let ids = Set(passions.filter { $0.emotion == key }.map { $0.passion_id })
        let count = passionJoins.filter { ids.contains($0.passion_id) }.count
        return min(4, count)
    }

    private func completionCount(for categoryTitle: String) -> Int {
        guard let record = fulfillments.first(where: { $0.category == categoryTitle }) else {
            return 0
        }
        let hasVision = !record.category_vision.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRole = roles.contains { $0.category_id == record.category_id }
        let hasFocus = foci.contains { $0.category_id == record.category_id }
        let hasResource = resources.contains { $0.category_id == record.category_id }
        let passionIDs = Set(passions.map(\.passion_id))
        let hasPassion = passionJoins.contains { $0.category_id == record.category_id && passionIDs.contains($0.passion_id) }
        return [hasVision, hasPurpose, hasRole, hasFocus, hasResource, hasPassion].filter { $0 }.count
    }

    private func batteryPercentage(for categoryTitle: String) -> Double {
        let count = completionCount(for: categoryTitle)
        switch count {
        case 0: return 0
        case 1...2: return 25
        case 3...4: return 50
        case 5: return 75
        default: return 100
        }
    }

    private func progressTrim(for measure: OutcomesMeasure) -> Double {
        let measureAmt = measure.measure_amt
        guard measureAmt != 0 else { return 0 }
        let value = measure.measure
        if measure.direction == "↑" {
            return min(max(value / measureAmt, 0), 1)
        } else {
            return min(max((measureAmt - value) / (measureAmt - 0), 0), 1)
        }
    }

    private func latestMeasure(for outcome: Outcomes) -> OutcomesMeasure? {
        outcomeMeasures.first { $0.outcome_id == outcome.outcome_id }
    }

    private var fulfillmentMetrics: [(String, Color, Double)] {
        [
            ("Career & Business",    .blue,   batteryPercentage(for: "Career & Business")),
            ("Leadership & Impact",  .indigo, batteryPercentage(for: "Leadership & Impact")),
            ("Wealth & Lifestyle",   .green,  batteryPercentage(for: "Wealth & Lifestyle")),
            ("Mind & Meaning",       .purple, batteryPercentage(for: "Mind & Meaning")),
            ("Love & Relationships", .red,    batteryPercentage(for: "Love & Relationships")),
            ("Health & Vitality",    .orange, batteryPercentage(for: "Health & Vitality"))
        ]
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
                    DataPrinterView()
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
                // .padding(.top, 25) // Added thin padding above logo
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
                                    Image(systemName: "plus")
                                        .foregroundColor(.accentColor)
                                        .padding(.leading, 16)
                                        .scaleEffect(1.2)
                                    Text("Capture Action")
                                        .foregroundColor(.primary)
                                        .padding(.leading, 8)
                                    Spacer()
                                }
                            )
                            .frame(height: 60)
                    }
                    .frame(maxWidth: .infinity)
                }
                .buttonStyle(.plain)

                Button(action: {}) {
                    Image(systemName: "play.fill")
                        .font(.title)
                        .foregroundColor(Color(.systemBackground))
                        .frame(width: 60, height: 60)
                        .background(Color.accentColor)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal)
            .padding(.top, 8)

            Text("")
                .font(.caption2)
                .foregroundColor(.secondary)
                .padding(.bottom, 4) // tiny, controlled spacing
        }
        .frame(maxWidth: .infinity)
        .background(Color.clear)
        .sheet(isPresented: $isPresentingCaptureView) {
            CaptureView()
        }
    }

    // MARK: - Extracted Sections to reduce body complexity
    private var drivingForceSection: some View {
        NavigationLink {
            DrivingForceView()
        } label: {
            SectionCard(iconName: "infinity", title: "Driving Force") {
                VStack(alignment: .leading, spacing: 12) {

                    // Ultimate Vision + Purpose group
                    VStack(alignment: .leading, spacing: 12) {

                        // Ultimate Vision
                        VStack(alignment: .leading, spacing: 4) {
                            Text("ULTIMATE VISION")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(.gray)

                            Text(
                                (drivingForces.first?.ultimateVision ?? "").isEmpty
                                    ? "+ Add My Ultimate Vision"
                                    : (drivingForces.first?.ultimateVision ?? "")
                            )
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

                            Text(
                                (drivingForces.first?.ultimatePurpose ?? "").isEmpty
                                    ? "+ Add My Ultimate Purpose"
                                    : (drivingForces.first?.ultimatePurpose ?? "")
                            )
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
        .buttonStyle(.plain)
    }

    private var fulfillmentSection: some View {
        NavigationLink {
            FulfillmentView()
        } label: {
            SectionCard(iconName: "trophy", title: "Fulfillment") {
                HStack(alignment: .center, spacing: 16) {
                    FulfillmentRadarGraph(metrics: fulfillmentMetrics)
                        .matchedGeometryEffect(id: "fulfillmentGraph", in: graphNamespace)
                        .frame(width: 140, height: 140)
                        .padding(.top, 10)
                    
                    // labels
                    VStack(alignment: .leading, spacing: 6) {
                        let metrics: [(String, Color, Double)] = [
                            ("Career & Business",    .blue,   80),
                            ("Leadership & Impact",  .indigo, 65),
                            ("Wealth & Lifestyle",   .green,  90),
                            ("Mind & Meaning",       .purple, 75),
                            ("Love & Relationships", .red,    85),
                            ("Health & Vitality",    .orange, 70)
                        ]
                        ForEach(metrics, id: \.0) { metric in
                            Text(metric.0)
                                .foregroundColor(metric.1)
                                .fontWeight(.bold)
                        }
                    }
                    .font(.subheadline)
                }
            }
        }
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
    }

    private var objectivesSection: some View {
        NavigationLink {
            ObjectivesView()
        } label: {
            SectionCard(iconName: "scope", title: "Objectives") {
                HStack(alignment: .top, spacing: 2) {

                    // Left: four outcome texts with dividers
                    VStack(alignment: .leading, spacing: 8) {
                        if outcomes.isEmpty {
                            Text("+ Add Outcome")
                                .font(.body)
                                .foregroundColor(.primary)
                        } else {
                            let currentDate = Date()
                            let filteredOutcomes = outcomes.filter { $0.start <= currentDate }

                            ForEach(filteredOutcomes.prefix(4)) { outcome in
                                HStack(alignment: .center, spacing: 8) {

                                    // Box with days until end date
                                    ZStack {
                                        RoundedRectangle(cornerRadius: 4)
                                            .fill(categoryBackgroundColor(for: outcome.category))
                                            .frame(width: 40, height: 20)

                                        Text("\(daysUntil(outcome.end))d")
                                            .font(.caption)
                                            .foregroundColor(.primary)
                                            .bold()
                                    }

                                    // Outcome text
                                    Text(outcome.outcome)
                                        .font(.body)
                                        .foregroundColor(categoryTextColor(for: outcome.category))
                                        .lineLimit(1)

                                    // Progress Circle
                                    if let measure = outcomeMeasures.first(where: { $0.outcome_id == outcome.outcome_id }),
                                       measure.measure_amt != 0 && measure.direction != nil && measure.format != nil {
                                        Spacer()
                                        ZStack {
                                            Circle()
                                                .stroke(Color(UIColor.systemGray3), lineWidth: 1.5)
                                                .frame(width: 16, height: 16)

                                            Circle()
                                                .trim(from: 0, to: progressTrim(for: measure))
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

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
                .frame(maxWidth: .infinity)
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
        .buttonStyle(.plain)
        .frame(maxHeight: .infinity)
    }
}

struct SectionCard<Content: View>: View {
    let iconName: String
    let title: String
    let content: () -> Content

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Image(systemName: iconName)
                    .font(.headline)
                Text(title)
                    .font(.headline)

                Spacer()

                Image(systemName: "chevron.right")
                    .font(.headline)
            }
            .padding(.horizontal)
            .padding(.top, 12)
            .foregroundColor(.primary)

            Divider()
                .padding(.vertical, 4)

            content()
                .padding(.horizontal)
                .padding(.bottom, 12)
        }
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.primary.opacity(0.08), radius: 6, x: 0, y: 3)
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

    private func categoryColor(for category: String) -> Color {
        switch category {
        case "Career & Business": return .blue
        case "Leadership & Impact": return .indigo
        case "Wealth & Lifestyle": return .green
        case "Mind & Meaning": return .purple
        case "Love & Relationships": return .red
        case "Health & Vitality": return .orange
        default: return .primary
        }
    }

    private func lightenedCategoryColor(for category: String) -> Color {
        let baseColor = UIColor(categoryColor(for: category))
        return Color(baseColor.adjusted(by: 0.8))
    }

    private func isOutcomeMeasurable(_ measure: OutcomesMeasure) -> Bool {
        measure.measure_amt != 0 && measure.direction != nil && measure.format != nil
    }

    private func daysUntil(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: .now, to: date)
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

    private func progressValue(measure: Double, measureAmt: Double, direction: String) -> Double {
        guard measureAmt != 0 else { return 0 }
        let isUpDirection = direction == MeasureDirection.up.rawValue
        if isUpDirection {
            return min(max(measure / measureAmt, 0), 1)
        } else {
            return min(max((measure - measureAmt) / (0 - measureAmt), 0), 1)
        }
    }

    @ViewBuilder
    private func DarkMeasurableOutcomeBox(measure: Double, measuredAt: Date, measureAmt: Double, endDate: Date, format: String) -> some View {
        HStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(formattedValue(measure, format: format))
                    .font(.title3)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("updated \(formattedDate(measuredAt))")
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
    private func DarkProgressCircleView(measure: Double, measureAmt: Double, direction: String) -> some View {
        let progress = progressValue(measure: measure, measureAmt: measureAmt, direction: direction)
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
                VStack(spacing: 2) {
                    Text("\(daysUntil(outcome.end))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .foregroundColor(.black)
                    Text("days left")
                        .font(.caption2)
                        .foregroundColor(.black)
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
                            format: measure.format ?? "Number"
                        )
                        .frame(height: 44)

                        DarkProgressCircleView(
                            measure: measure.measure,
                            measureAmt: measure.measure_amt,
                            direction: measure.direction ?? MeasureDirection.up.rawValue
                        )
                        .frame(width: 40, height: 40)
                    } else {
                        MeasurableOutcomeBox(
                            measure: measure.measure,
                            measuredAt: measure.measuredAt,
                            measureAmt: measure.measure_amt,
                            endDate: outcome.end,
                            format: measure.format ?? "Number"
                        )
                        .frame(height: 44)

                        ProgressCircleView(
                            measure: measure.measure,
                            measureAmt: measure.measure_amt,
                            direction: measure.direction ?? MeasureDirection.up.rawValue
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

