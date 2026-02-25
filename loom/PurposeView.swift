import SwiftUI
import SwiftData

// MARK: - Supporting Types
struct PassionCategory {
    let emotion: String
    let title: String
    let prompt: String
    let query: [Passion]
}

struct AddState {
    var isAdding: Bool = false
    var newText: String = ""
}

enum Field: Hashable {
    case vision
    case purpose
    case passion(String)
}

struct PurposeView: View {
    let autoOpenCreateVision: Bool
    @Environment(\.modelContext) private var context
    @Environment(\.colorScheme) private var colorScheme
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \DrivingForceArchive.archivedAt, order: .reverse) private var drivingForceArchives: [DrivingForceArchive]
    
    // Passion queries for each emotion
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "love" },
        sort: \Passion.date,
        order: .forward
    ) private var lovePassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "vows" },
        sort: \Passion.date,
        order: .forward
    ) private var vowsPassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "thrill" },
        sort: \Passion.date,
        order: .forward
    ) private var thrillPassions: [Passion]
    
    @Query(
        filter: #Predicate<Passion> { $0.emotion == "just" },
        sort: \Passion.date,
        order: .forward
    ) private var justPassions: [Passion]
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward)
    private var passionJoins: [PassionFulfillmentJoin]
    @Query(sort: \PassionScoreSnapshot.monthStartDate, order: .reverse)
    private var passionScoreSnapshots: [PassionScoreSnapshot]
    
    // Consolidated passion categories
    private var passionQueries: [PassionCategory] {
        [
            PassionCategory(emotion: "love", title: "Love", prompt: "What do I love?", query: lovePassions),
            PassionCategory(emotion: "vows", title: "Vow", prompt: "What am I committed to?", query: vowsPassions),
            PassionCategory(emotion: "thrill", title: "Thrill", prompt: "What excites me?", query: thrillPassions),
            PassionCategory(emotion: "just", title: "Hate", prompt: "What do I hate?", query: justPassions)
        ]
    }
    
    @State private var visionText: String = ""
    @State private var purposeText: String = ""
    @State private var visionTextDraft: String = ""
    @State private var purposeTextDraft: String = ""
    @State private var addStates: [String: AddState] = [:]
    @State private var isShowingInstructions: Bool = false
    @State private var isShowingHistoric = false
    @State private var activeEditor: DrivingForceEditor?
    @State private var editorDraftText: String = ""
    @State private var pendingDeleteRow: HistoricRow?
    @State private var editorCursorSeed: Int = 0
    @State private var editorShouldFocus: Bool = false
    @State private var didAutoOpenCreateVision: Bool = false
    @State private var showDrivingForceTrends: Bool = false
    @State private var lastPassionScoreRefreshMonthStart: Date?
    @State private var highlightedPassionEmotionKey: String = "love"
    @State private var passionAutoRotatePausedUntil: Date = .distantPast
    @State private var drivingForceHeaderInsightOutlineAngle: Double = 0
    @FocusState private var focusedField: Field?
    private let passionHeaderTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()

    private enum DrivingForceEditor: String, Identifiable {
        case vision
        case purpose
        var id: String { rawValue }
    }

    private enum HistoricKind: String {
        case vision
        case purpose

        var label: String {
            switch self {
            case .vision: return "Vision"
            case .purpose: return "Purpose"
            }
        }
    }

    private struct HistoricRow: Identifiable {
        let archive: DrivingForceArchive
        let kind: HistoricKind
        let text: String

        var id: String { "\(archive.id.uuidString)|\(kind.rawValue)" }
    }

    private var currentDrivingForce: DrivingForce? {
        drivingForces.first
    }

    private var visionPlaceholder: String {
        "Imagine there are no limits. What do you want to be, do, have or create in your life overall? What does your ideal life look and feel like?"
    }

    private var purposePlaceholder: String {
        "What gets you up in the morning? What keeps you going? What could... if you were really excited about it? What are the reasons WHY you want your life to be this way? What will it give you? How will it make you feel?"
    }

    private var historicRows: [HistoricRow] {
        var rows: [HistoricRow] = []
        rows.reserveCapacity(drivingForceArchives.count * 2)
        for archive in drivingForceArchives {
            let vision = archive.visionSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !vision.isEmpty {
                rows.append(HistoricRow(archive: archive, kind: .vision, text: archive.visionSnapshot))
            }
        }
        return rows
    }
    
    var body: some View {
        List {
            drivingForceInsightsHeader
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

            AnyView(drivingForceSections)
            AnyView(passionsHeader)
            AnyView(passionsSections)
            if !historicRows.isEmpty {
                AnyView(historicToggleRow)
            }
            AnyView(historicRowsSection)
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(4)
        .toolbar { topToolbar }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if focusedField == .vision {
                    Spacer()
                    Button("Done") {
                        focusedField = nil
                        hideKeyboard()
                    }
                }
            }
        }
        .navigationTitle("Purpose")
        .background(backgroundTapDismiss)
        .task {
            if let existing = drivingForces.first {
                visionText = existing.ultimateVision
                purposeText = existing.ultimatePurpose
                visionTextDraft = existing.ultimateVision
                purposeTextDraft = existing.ultimatePurpose
            }
            refreshPassionScoresForCurrentMonthIfNeeded()
            maybeAutoOpenCreateVision()
        }
        .onAppear {
            maybeAutoOpenCreateVision()
        }
        .onChange(of: focusedField) { oldValue, newValue in
            if oldValue == .vision && newValue != .vision {
                saveVisionInline()
            }
            if oldValue == .purpose && newValue != .purpose {
                savePurposeInline()
            }
        }
        .onReceive(passionHeaderTimer) { now in
            guard now >= passionAutoRotatePausedUntil else { return }
            rotateHighlightedPassion()
        }
        .onReceive(NotificationCenter.default.publisher(for: .littleWinsPassionsDidChange)) { _ in
            refreshPassionScoresForCurrentMonthIfNeeded(force: true)
        }
        .sheet(isPresented: $isShowingInstructions, content: instructionsSheet)
        .navigationDestination(isPresented: $showDrivingForceTrends) {
            DrivingForceTrendsView(snapshots: passionScoreSnapshots)
        }
        .alert("Delete Historic Item?", isPresented: deleteHistoricBinding, actions: deleteHistoricActions, message: deleteHistoricMessage)
    }

    @ToolbarContentBuilder
    private var topToolbar: some ToolbarContent {
        ToolbarItem(placement: .navigationBarTrailing) {
            Button {
                isShowingInstructions = true
            } label: {
                Image(systemName: "graduationcap")
                    .font(.title2)
            }
            .buttonStyle(.plain)
        }
    }

    private var backgroundTapDismiss: some View {
        Color.clear
            .contentShape(Rectangle())
            .onTapGesture {
                focusedField = nil
                hideKeyboard()
            }
    }

    private func editorSheet(_ editor: DrivingForceEditor) -> some View {
        let sheetTitle = editorSheetTitle(for: editor)
        let placeholder = editorPlaceholder(for: editor)
        return NavigationStack {
            VStack(alignment: .leading, spacing: 10) {
                ZStack(alignment: .topLeading) {
#if canImport(UIKit)
                    DrivingForceEditorTextView(
                        text: $editorDraftText,
                        isFocused: $editorShouldFocus,
                        cursorSeed: editorCursorSeed
                    )
                    .frame(minHeight: 220)
                    .padding(8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
#else
                    TextEditor(text: $editorDraftText)
                        .frame(minHeight: 220)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
#endif
                    if editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Text(placeholder)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 16)
                            .allowsHitTesting(false)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding()
            .navigationTitle(sheetTitle)
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                switch editor {
                case .vision:
                    editorDraftText = visionText
                case .purpose:
                    editorDraftText = purposeText
                }
                editorCursorSeed += 1
                editorShouldFocus = false
                DispatchQueue.main.async {
                    editorShouldFocus = true
                }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.20) {
                    editorShouldFocus = true
                }
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        activeEditor = nil
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    if hasEditorChanges(editor) {
                        Button("Save") {
                            saveEditorChanges(editor)
                            activeEditor = nil
                        }
                    }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .onDisappear {
            editorShouldFocus = false
        }
    }

    private func instructionsSheet() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Instructions")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                instructionSectionTitle("Set Your Purpose")
                instructionBody("This isn’t long-term goals.")
                instructionBody("It’s who you are: your values, principles, and high-level direction that tends to stay stable over time.")
                instructionBody("Wording can evolve, but the themes should remain a compass.")

                instructionSectionTitle("Vision")
                instructionLabel("Need ideas?")
                instructionBullets([
                    "Who do I want to become?",
                    "What experiences do I want to have?",
                    "What impact do I want to make?"
                ])
                instructionLabel("Example:")
                instructionExample("“I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact.”")

                instructionSectionTitle("Passions")
                instructionLabel("Need ideas?")

                instructionSubsection("Love")
                instructionBullets([
                    "Time with family and close relationships",
                    "Learning, growth, and self-improvement",
                    "Building and creating something meaningful"
                ])

                instructionSubsection("Vows (Commitments)")
                instructionBullets([
                    "Always act with integrity",
                    "Take full responsibility for my life",
                    "Keep growing and becoming better"
                ])

                instructionSubsection("Thrill (Excitement)")
                instructionBullets([
                    "Achieving difficult goals",
                    "Solving hard problems",
                    "Taking risks and pursuing new opportunities"
                ])

                instructionSubsection("Hate")
                instructionBullets([
                    "Wasted potential",
                    "Dishonesty and manipulation",
                    "Laziness and excuses"
                ])
            }
            .padding()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func instructionSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func instructionSubsection(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func instructionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func instructionBody(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func instructionExample(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.italic())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func instructionBullets(_ items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(items, id: \.self) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text("•")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(item)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private var deleteHistoricBinding: Binding<Bool> {
        Binding(
            get: { pendingDeleteRow != nil },
            set: { if !$0 { pendingDeleteRow = nil } }
        )
    }

    private func deleteHistoricActions() -> some View {
        Group {
            Button("Delete", role: .destructive) {
                if let row = pendingDeleteRow {
                    deleteHistoricRow(row)
                }
                pendingDeleteRow = nil
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteRow = nil
            }
        }
    }

    private func deleteHistoricMessage() -> some View {
        Text("Are you sure you want to delete this item? It will be available for 30 days in Account Manager.")
    }

    private var drivingForceInsightsHeader: some View {
        HStack(alignment: .top, spacing: 6) {
            VStack(alignment: .leading, spacing: 12) {
                passionSignalRow(icon: "heart.fill", label: "Love", emotionKey: "love", value: usagePoints(for: "love"))
                passionSignalRow(icon: "lock.fill", label: "Vows", emotionKey: "vows", value: usagePoints(for: "vows"))
                passionSignalRow(icon: "bolt.fill", label: "Thrill", emotionKey: "thrill", value: usagePoints(for: "thrill"))
                passionSignalRow(icon: "shield.fill", label: "Hate", emotionKey: "just", value: usagePoints(for: "just"))

                Button {
                    showDrivingForceTrends = true
                } label: {
                    Text("Show insights")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
                .padding(.leading, 14)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)

            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .center, spacing: 8) {
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .stroke(colorScheme == .dark ? Color.white : Color.black, lineWidth: 3)
                        .frame(width: 98, height: 58)
                        .overlay {
                            Text(totalPassionSignalScoreText)
                                .font(.system(size: 24, weight: .bold))
                                .foregroundStyle(.primary)
                        }

                    VStack(alignment: .leading, spacing: 1) {
                        HStack(spacing: 4) {
                            let aggregateDelta = totalPassionMonthOverMonthDelta()
                            Text(headerPassionDeltaGlyph(aggregateDelta))
                                .font(.title3.weight(.bold))
                                .foregroundStyle(headerPassionDeltaColor(aggregateDelta))
                            Text(headerPassionDeltaText(aggregateDelta))
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(headerPassionDeltaColor(aggregateDelta))
                        }
                        Text("month")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if let snap = selectedHeaderPassionSnapshot,
                   let summaryInsight = primaryDrivingForceHeaderInsightMessage(for: snap) {
                    let loomAIGradient = AngularGradient(
                        colors: [
                            Color(red: 0.22, green: 0.47, blue: 1.0),
                            Color(red: 0.15, green: 0.83, blue: 0.95),
                            Color(red: 0.62, green: 0.40, blue: 0.95),
                            Color(red: 0.80, green: 0.38, blue: 0.78),
                            Color(red: 0.98, green: 0.36, blue: 0.58),
                            Color(red: 0.75, green: 0.42, blue: 0.74),
                            Color(red: 0.22, green: 0.47, blue: 1.0)
                        ],
                        center: .center,
                        angle: .degrees(drivingForceHeaderInsightOutlineAngle)
                    )
                    VStack(alignment: .leading, spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 32, height: 32)
                            .frame(maxWidth: .infinity, alignment: .center)
                        Text(summaryInsight)
                            .font(.footnote)
                            .foregroundStyle(.primary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(loomAIGradient.opacity(0.95), lineWidth: 2)
                    )
                }
            }
            .frame(width: 166, alignment: .topTrailing)
        }
        .padding(.horizontal, 15)
        .padding(.vertical, 15)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .fill(colorScheme == .dark ? Color(.secondarySystemBackground) : Color(.systemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 16, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .onAppear {
            if highlightedPassionEmotionKey.isEmpty {
                highlightedPassionEmotionKey = "love"
            }
            guard drivingForceHeaderInsightOutlineAngle == 0 else { return }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                drivingForceHeaderInsightOutlineAngle = 360
            }
        }
    }

    private func passionSignalCircle(icon: String, value: Int) -> some View {
        let gap: Double = 4
        let halfGap = gap / 2
        let radius: CGFloat = 22
        let center = CGPoint(x: radius, y: radius)
        let quadrantAngles: [(start: Double, end: Double)] = [
            (-90,   0),
            (0,    90),
            (90,  180),
            (180, 270)
        ]

        return ZStack {
            ForEach(0..<4, id: \.self) { index in
                let angles = quadrantAngles[index]
                Path { path in
                    path.addArc(center: center,
                                radius: radius,
                                startAngle: .degrees(angles.start + halfGap),
                                endAngle: .degrees(angles.end - halfGap),
                                clockwise: false)
                }
                .stroke((index + 1) <= value ? Color.primary : Color(.tertiaryLabel), lineWidth: 2.4)
            }

            Image(systemName: icon)
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.primary)
        }
        .frame(width: radius * 2, height: radius * 2)
    }

    private func passionSignalRow(icon: String, label: String, emotionKey: String, value: Int) -> some View {
        let delta = passionMonthOverMonthDelta(for: emotionKey)
        return Button {
            highlightedPassionEmotionKey = emotionKey
            passionAutoRotatePausedUntil = Date().addingTimeInterval(20)
        } label: {
            HStack(spacing: 6) {
                Circle()
                    .fill(
                        highlightedPassionEmotionKey == emotionKey
                        ? AnyShapeStyle(
                            AngularGradient(
                                colors: [
                                    Color(red: 0.22, green: 0.47, blue: 1.0),
                                    Color(red: 0.15, green: 0.83, blue: 0.95),
                                    Color(red: 0.62, green: 0.40, blue: 0.95),
                                    Color(red: 0.80, green: 0.38, blue: 0.78),
                                    Color(red: 0.98, green: 0.36, blue: 0.58),
                                    Color(red: 0.75, green: 0.42, blue: 0.74),
                                    Color(red: 0.22, green: 0.47, blue: 1.0)
                                ],
                                center: .center,
                                angle: .degrees(24)
                            )
                        )
                        : AnyShapeStyle(Color.clear)
                    )
                    .frame(width: 7, height: 7)
                passionSignalCircle(icon: icon, value: value)
                Text(label)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                    .layoutPriority(1)
                    .frame(minWidth: 52, maxWidth: 66, alignment: .leading)
                VStack(alignment: .leading, spacing: 0) {
                    HStack(spacing: 3) {
                        Text(headerPassionDeltaGlyph(delta))
                            .font(.subheadline.weight(.bold))
                            .foregroundStyle(headerPassionDeltaColor(delta))
                        Text(headerPassionDeltaText(delta))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(headerPassionDeltaColor(delta))
                    }
                    Text("month")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.leading, -1)
                .fixedSize(horizontal: true, vertical: false)
            }
            .padding(.leading, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func usagePoints(for emotionKey: String) -> Int {
        if let snapScore = latestMonthlyPassionScore(for: emotionKey) {
            return Int(PassionScoringMath.clamp(snapScore.rounded(), min: 0, max: 4))
        }
        return legacyUsagePoints(for: emotionKey)
    }

    private func legacyUsagePoints(for emotionKey: String) -> Int {
        let ids: Set<UUID>
        switch emotionKey {
        case "love":
            ids = Set(lovePassions.map(\.passion_id))
        case "vows":
            ids = Set(vowsPassions.map(\.passion_id))
        case "thrill":
            ids = Set(thrillPassions.map(\.passion_id))
        case "just":
            ids = Set(justPassions.map(\.passion_id))
        default:
            ids = []
        }
        let count = passionJoins.filter { ids.contains($0.passion_id) }.count
        return min(4, count)
    }

    private var totalPassionSignalScoreText: String {
        let values = ["love", "vows", "thrill", "just"].map { passionDisplayScore(for: $0) }
        let total = values.reduce(0, +)
        if abs(total.rounded() - total) < 0.001 {
            return "\(Int(total.rounded()))/16"
        }
        return String(format: "%.1f/16", total)
    }

    private func passionDisplayScore(for emotionKey: String) -> Double {
        if let snapScore = latestMonthlyPassionScore(for: emotionKey) {
            return PassionScoringMath.clamp(snapScore, min: 0, max: 4)
        }
        return Double(legacyUsagePoints(for: emotionKey))
    }

    private func latestMonthlyPassionScore(for emotionKey: String) -> Double? {
        latestMonthlyPassionSnapshot(for: emotionKey)?.score
    }

    private func latestMonthlyPassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        let monthStart = PassionScoringMath.monthWindow(for: .now).monthStart
        return passionScoreSnapshots.first(where: {
            $0.passionTypeRaw == passionType.rawValue &&
            Calendar.current.isDate($0.monthStartDate, inSameDayAs: monthStart)
        })
    }

    private func previousMonthlyPassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        let currentMonthStart = PassionScoringMath.monthWindow(for: .now).monthStart
        guard let priorMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) else { return nil }
        return passionScoreSnapshots.first(where: {
            $0.passionTypeRaw == passionType.rawValue &&
            Calendar.current.isDate($0.monthStartDate, inSameDayAs: priorMonthStart)
        })
    }

    private var selectedHeaderPassionSnapshot: PassionScoreSnapshot? {
        latestMonthlyPassionSnapshot(for: highlightedPassionEmotionKey)
    }

    private func passionMonthOverMonthDelta(for emotionKey: String) -> Double? {
        guard let current = latestMonthlyPassionSnapshot(for: emotionKey)?.score,
              let prior = previousMonthlyPassionSnapshot(for: emotionKey)?.score else { return nil }
        let delta = roundedTenth(current) - roundedTenth(prior)
        return abs(delta) < 0.05 ? 0 : delta
    }

    private func totalPassionMonthOverMonthDelta() -> Double? {
        let keys = ["love", "vows", "thrill", "just"]
        let currentScores = keys.compactMap { latestMonthlyPassionSnapshot(for: $0)?.score }
        let priorScores = keys.compactMap { previousMonthlyPassionSnapshot(for: $0)?.score }
        guard currentScores.count == keys.count, priorScores.count == keys.count else { return nil }
        let currentTotal = roundedTenth(currentScores.reduce(0, +))
        let priorTotal = roundedTenth(priorScores.reduce(0, +))
        let delta = currentTotal - priorTotal
        return abs(delta) < 0.05 ? 0 : delta
    }

    private func headerPassionDeltaText(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "—" }
        return String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
    }

    private func headerPassionDeltaGlyph(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private func headerPassionDeltaColor(_ delta: Double?) -> Color {
        guard let delta else { return .secondary }
        if abs(delta) < 0.05 { return .secondary }
        return delta > 0 ? .green : .orange
    }

    private func rotateHighlightedPassion() {
        let order = ["love", "vows", "thrill", "just"]
        guard !order.isEmpty else { return }
        let currentIndex = order.firstIndex(of: highlightedPassionEmotionKey) ?? -1
        let nextIndex = (currentIndex + 1) % order.count
        highlightedPassionEmotionKey = order[nextIndex]
    }

    private func primaryDrivingForceHeaderInsightMessage(for snap: PassionScoreSnapshot) -> String? {
        let structure = PassionScoringMath.clamped01(snap.structure)
        let outcomes = PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0)
        let actions = PassionScoringMath.clamped01(snap.actionCoverage)
        let wins = PassionScoringMath.clamped01(snap.littleWinsCoverage)
        let carry = PassionScoringMath.clamped01(snap.carryoverPenalty)
        let consistency = PassionScoringMath.clamped01(snap.consistency)

        let structurePct = Int((structure * 100).rounded())
        let outcomesPct = Int((outcomes * 100).rounded())
        let actionPct = Int((actions * 100).rounded())
        let winsPct = Int((wins * 100).rounded())
        let carryPct = Int((carry * 100).rounded())
        let consistencyPct = Int((consistency * 100).rounded())
        let name = passionHeaderTitle(for: highlightedPassionEmotionKey)

        if carry >= 0.30 {
            return "Carryover is high (\(carryPct)% penalty) for \(name). Reduce scope or break supporting work into smaller actions."
        }
        if structure >= 0.65 && actions <= 0.45 {
            return "\(name) has strong structure (\(structurePct)%) but weak execution (\(actionPct)% Action blocks)."
        }
        if wins >= 0.65 && outcomes <= 0.45 {
            return "\(name) is supported by daily wins (\(winsPct)%), but outcomes are weak (\(outcomesPct)%)."
        }
        if consistency <= 0.35 {
            return "\(name) is volatile (\(consistencyPct)% consistency). Steadier weekly support will improve this score."
        }
        if outcomes >= 0.7 && actions >= 0.7 && carry <= 0.15 {
            return "\(name) is well supported with strong outcomes (\(outcomesPct)%) and execution (\(actionPct)%)."
        }
        return "\(name) is stable overall. Improve one support behavior this month to raise the score."
    }

    private func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func passionHeaderTitle(for emotionKey: String) -> String {
        switch emotionKey {
        case "love": return "Love"
        case "vows": return "Vows"
        case "thrill": return "Thrill"
        case "just": return "Hate"
        default: return emotionKey.capitalized
        }
    }

    private func passionType(forEmotionKey emotionKey: String) -> PassionType? {
        switch emotionKey {
        case "love": return .love
        case "vows": return .vows
        case "thrill": return .thrill
        case "just": return .hate
        default: return nil
        }
    }

    private func refreshPassionScoresForCurrentMonthIfNeeded(force: Bool = false) {
        let monthStart = PassionScoringMath.monthWindow(for: .now).monthStart
        if !force, let last = lastPassionScoreRefreshMonthStart,
           Calendar.current.isDate(last, inSameDayAs: monthStart) {
            return
        }
        let service = PassionScoringService()
        _ = try? service.computeAndBackfillMonthlySnapshots(in: context)
        lastPassionScoreRefreshMonthStart = monthStart
    }

    @ViewBuilder
    private var drivingForceSections: some View {
        inlineDrivingForceSection(
            title: "Vision",
            placeholder: visionPlaceholder,
            text: $visionTextDraft,
            focus: .vision
        )
    }

    private var passionsHeader: some View {
        Text("Passions")
            .font(.title2).bold()
            .listRowBackground(Color.clear)
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }

    private var passionsSections: some View {
        Group {
            ForEach(passionQueries, id: \.emotion) { category in
                PassionEditor(
                    category: category,
                    addState: addStates[category.emotion] ?? AddState(),
                    onAddStateChange: { newState in
                        addStates[category.emotion] = newState
                    },
                    focusedField: $focusedField,
                    onCommit: { text in
                        commitPassion(text: text, emotion: category.emotion)
                    },
                    onDelete: deletePassion
                )
            }
        }
    }

    private var historicToggleRow: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                isShowingHistoric.toggle()
            }
        } label: {
            HStack(spacing: 6) {
                Image(systemName: isShowingHistoric ? "chevron.up" : "chevron.down")
                    .font(.caption2.weight(.semibold))
                Text("Previous Visions")
                    .font(.caption2.weight(.semibold))
            }
            .foregroundStyle(.primary)
            .padding(.vertical, 5)
            .padding(.horizontal, 8)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.systemGray4))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.black.opacity(0.15), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .leading)
        .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 2, trailing: 16))
        .listRowBackground(Color.clear)
    }

    @ViewBuilder
    private var historicRowsSection: some View {
        if isShowingHistoric {
            if !historicRows.isEmpty {
                Section {
                    ForEach(historicRows) { row in
                        historicRowView(row)
                    }
                }
            }
        }
    }

    private func historicRowView(_ row: HistoricRow) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(row.kind.label)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(shortDate(row.archive.archivedAt))
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.secondary)
            }
            Text(row.text)
                .font(.body)
                .foregroundStyle(.primary)
        }
        .padding(.vertical, 2)
        .swipeActions(edge: .leading, allowsFullSwipe: true) {
            Button("Recover") {
                recoverArchive(row.archive, kind: row.kind)
            }
            .tint(.blue)
        }
        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
            Button("Delete", role: .destructive) {
                pendingDeleteRow = row
            }
            .tint(.red)
        }
    }

    private func inlineDrivingForceSection(
        title: String,
        placeholder: String,
        text: Binding<String>,
        focus: Field
    ) -> some View {
        return Section(title) {
            TextField(placeholder, text: text, axis: .vertical)
                .font(.system(size: 19))
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .lineLimit(2...10)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .frame(minHeight: 88, alignment: .topLeading)
                .background((colorScheme == .dark ? Color(.secondarySystemBackground) : Color.white), in: RoundedRectangle(cornerRadius: 12))
                .focused($focusedField, equals: focus)
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
    }

    private func editorSheetTitle(for editor: DrivingForceEditor) -> String {
        let current = currentText(for: editor).trimmingCharacters(in: .whitespacesAndNewlines)
        if current.isEmpty {
            return editor == .vision ? "Create Vision" : "Create Purpose"
        }
        return editor == .vision ? "Edit Vision" : "Edit Purpose"
    }

    private func editorPlaceholder(for editor: DrivingForceEditor) -> String {
        editor == .vision ? visionPlaceholder : purposePlaceholder
    }

    private func currentText(for editor: DrivingForceEditor) -> String {
        editor == .vision ? visionText : purposeText
    }

    private func maybeAutoOpenCreateVision() {
        guard autoOpenCreateVision, !didAutoOpenCreateVision else { return }
        let hasMissingVision = visionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        guard hasMissingVision else { return }
        didAutoOpenCreateVision = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            focusedField = .vision
        }
    }
    
    private func commitPassion(text: String, emotion: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addStates[emotion] = AddState()
            return
        }
        let passion = Passion(date: .now, emotion: emotion, passion: trimmed)
        context.insert(passion)
        addStates[emotion] = AddState()
        hideKeyboard()
    }
    
    private func deletePassion(_ passion: Passion) {
        let archive = PassionArchive(
            date: passion.date,
            emotion: passion.emotion,
            passionSnapshot: passion.passion,
            archivedAt: .now
        )
        context.insert(archive)
        RecentlyDeletedStore.trash(passion, in: context)
    }
    
    private func hasEditorChanges(_ editor: DrivingForceEditor) -> Bool {
        let current: String
        switch editor {
        case .vision:
            current = visionText
        case .purpose:
            current = purposeText
        }
        return editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines) != current.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func saveVisionInline() {
        let trimmed = visionTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != visionText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        editorDraftText = visionTextDraft
        saveEditorChanges(.vision)
    }

    private func savePurposeInline() {
        let trimmed = purposeTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed != purposeText.trimmingCharacters(in: .whitespacesAndNewlines) else { return }
        editorDraftText = purposeTextDraft
        saveEditorChanges(.purpose)
    }

    private func saveEditorChanges(_ editor: DrivingForceEditor) {
        let now = Date()
        let trimmedDraft = editorDraftText.trimmingCharacters(in: .whitespacesAndNewlines)

        if let existing = currentDrivingForce {
            switch editor {
            case .vision:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: existing.ultimateVision,
                        purposeSnapshot: "",
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimateVision = trimmedDraft
                visionText = trimmedDraft
                visionTextDraft = trimmedDraft
            case .purpose:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: "",
                        purposeSnapshot: existing.ultimatePurpose,
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimatePurpose = trimmedDraft
                purposeText = trimmedDraft
                purposeTextDraft = trimmedDraft
            }
            existing.updatedAt = now
        } else {
            let newVision = (editor == .vision) ? trimmedDraft : ""
            let newPurpose = (editor == .purpose) ? trimmedDraft : ""
            let created = DrivingForce(
                ultimateVision: newVision,
                ultimatePurpose: newPurpose,
                updatedAt: now
            )
            context.insert(created)
            visionText = created.ultimateVision
            purposeText = created.ultimatePurpose
            visionTextDraft = created.ultimateVision
            purposeTextDraft = created.ultimatePurpose
        }

        try? context.save()
    }

    private func recoverArchive(_ archive: DrivingForceArchive, kind: HistoricKind) {
        let now = Date()

        if let existing = currentDrivingForce {
            switch kind {
            case .vision:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: existing.ultimateVision,
                        purposeSnapshot: "",
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimateVision = archive.visionSnapshot
                visionText = archive.visionSnapshot
                visionTextDraft = archive.visionSnapshot
            case .purpose:
                context.insert(
                    DrivingForceArchive(
                        visionSnapshot: "",
                        purposeSnapshot: existing.ultimatePurpose,
                        updatedAt: existing.updatedAt,
                        archivedAt: now
                    )
                )
                existing.ultimatePurpose = archive.purposeSnapshot
                purposeText = archive.purposeSnapshot
                purposeTextDraft = archive.purposeSnapshot
            }
            existing.updatedAt = now
        } else {
            switch kind {
            case .vision:
                visionText = archive.visionSnapshot
                visionTextDraft = archive.visionSnapshot
            case .purpose:
                purposeText = archive.purposeSnapshot
                purposeTextDraft = archive.purposeSnapshot
            }
            context.insert(DrivingForce(
                ultimateVision: visionText,
                ultimatePurpose: purposeText,
                updatedAt: now
            ))
        }

        // Consumed from history after recovery.
        context.delete(archive)
        try? context.save()
    }

    private func deleteHistoricRow(_ row: HistoricRow) {
        let archive = row.archive
        let hasVision = !archive.visionSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasPurpose = !archive.purposeSnapshot.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        if hasVision && hasPurpose {
            // Split an old combined archive entry so one row can be deleted independently.
            let deletedOnly: DrivingForceArchive
            switch row.kind {
            case .vision:
                deletedOnly = DrivingForceArchive(
                    visionSnapshot: archive.visionSnapshot,
                    purposeSnapshot: "",
                    updatedAt: archive.updatedAt,
                    archivedAt: archive.archivedAt
                )
                archive.visionSnapshot = ""
            case .purpose:
                deletedOnly = DrivingForceArchive(
                    visionSnapshot: "",
                    purposeSnapshot: archive.purposeSnapshot,
                    updatedAt: archive.updatedAt,
                    archivedAt: archive.archivedAt
                )
                archive.purposeSnapshot = ""
            }
            context.insert(deletedOnly)
            RecentlyDeletedStore.trash(deletedOnly, in: context, source: "Purpose Archive")
            try? context.save()
            return
        }

        RecentlyDeletedStore.trash(archive, in: context, source: "Purpose Archive")
        try? context.save()
    }

    private func shortDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "M/d/yyyy"
        return formatter.string(from: date)
    }
}

private struct DrivingForceTrendRow: Identifiable {
    let id: String
    let monthStart: Date
    let passionType: PassionType
    let title: String
    let value: Double
}

private struct DrivingForceTrendsView: View {
    private enum TimelineOption: String, CaseIterable, Identifiable {
        case all = "All"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"
        case threeYears = "3Y"

        var id: String { rawValue }

        var rollingMonths: Int? {
            switch self {
            case .all: return nil
            case .threeMonths: return 3
            case .sixMonths: return 6
            case .oneYear: return 12
            case .threeYears: return 36
            }
        }
    }

    private struct TrendSegment: Identifiable {
        let id: String
        let color: Color
        let height: CGFloat
    }

    @Environment(\.colorScheme) private var colorScheme
    let snapshots: [PassionScoreSnapshot]

    @State private var selectedTimeline: TimelineOption = .all
    @State private var selectedMonthRaw: Date?
    @State private var selectedPassionTypeRaw: String?
    @State private var trendsContentIsReady = false

    private let chartPassionOrder: [PassionType] = [.love, .vows, .thrill, .hate]
    private let plotHeight: CGFloat = 220
    private let yAxisWidth: CGFloat = 24
    private let leadingPadding: CGFloat = 14
    private let trailingPadding: CGFloat = 8

    private var allMonthStarts: [Date] {
        Array(Set(snapshots.map { Calendar.current.startOfDay(for: $0.monthStartDate) })).sorted()
    }

    private var latestMonthStart: Date? { allMonthStarts.last }

    private var visibleMonths: [Date] {
        guard let latestMonthStart else { return [] }
        guard let months = selectedTimeline.rollingMonths else { return allMonthStarts }
        let cal = Calendar.current
        let start = cal.date(byAdding: .month, value: -(months - 1), to: latestMonthStart) ?? latestMonthStart
        let filtered = allMonthStarts.filter { $0 >= start && $0 <= latestMonthStart }
        return filtered.isEmpty ? [latestMonthStart] : filtered
    }

    private var timelineOptions: [TimelineOption] {
        let count = allMonthStarts.count
        var options: [TimelineOption] = [.all]
        if count >= 3 { options.append(.threeMonths) }
        if count >= 6 { options.append(.sixMonths) }
        if count >= 12 { options.append(.oneYear) }
        if count >= 24 { options.append(.threeYears) }
        return options
    }

    private var selectedMonthStart: Date? {
        guard let latestMonthStart else { return nil }
        guard let selectedMonthRaw else { return latestMonthStart }
        return nearestMonth(to: selectedMonthRaw) ?? latestMonthStart
    }

    private var latestMonthSnapshots: [PassionScoreSnapshot] {
        guard let latestMonthStart else { return [] }
        return snapshots.filter { Calendar.current.isDate($0.monthStartDate, inSameDayAs: latestMonthStart) }
    }

    private var selectedMonthSnapshots: [PassionScoreSnapshot] {
        guard let selectedMonthStart else { return latestMonthSnapshots }
        return snapshots.filter { Calendar.current.isDate($0.monthStartDate, inSameDayAs: selectedMonthStart) }
    }

    private var selectedSnapshot: PassionScoreSnapshot? {
        if let raw = selectedPassionTypeRaw,
           let row = selectedMonthSnapshots.first(where: { $0.passionTypeRaw == raw }) {
            return row
        }
        return selectedMonthSnapshots.sorted(by: passionSnapshotSort).first
    }

    private func passionSnapshotSort(_ lhs: PassionScoreSnapshot, _ rhs: PassionScoreSnapshot) -> Bool {
        let li = chartPassionOrder.firstIndex(of: lhs.passionType) ?? Int.max
        let ri = chartPassionOrder.firstIndex(of: rhs.passionType) ?? Int.max
        return li < ri
    }

    private var chartRows: [DrivingForceTrendRow] {
        let cal = Calendar.current
        let visibleSet = Set(visibleMonths.map { cal.startOfDay(for: $0) })
        let latestByKey = Dictionary(grouping: snapshots.filter {
            visibleSet.contains(cal.startOfDay(for: $0.monthStartDate))
        }) { snap in
            "\(Int(cal.startOfDay(for: snap.monthStartDate).timeIntervalSince1970))|\(snap.passionTypeRaw)"
        }.compactMapValues { rows in
            rows.max(by: { $0.updatedAt < $1.updatedAt })
        }

        return chartPassionOrder.flatMap { passion in
            visibleMonths.map { month in
                let monthStart = cal.startOfDay(for: month)
                let key = "\(Int(monthStart.timeIntervalSince1970))|\(passion.rawValue)"
                let snap = latestByKey[key]
                return DrivingForceTrendRow(
                    id: key,
                    monthStart: monthStart,
                    passionType: passion,
                    title: passionTitle(for: passion),
                    value: snap?.score ?? 0
                )
            }
        }
    }

    private var chartRowsByMonth: [Date: [DrivingForceTrendRow]] {
        Dictionary(grouping: chartRows) { Calendar.current.startOfDay(for: $0.monthStart) }
    }

    private var actualSnapshotValueByMonthPassion: [String: Double] {
        let visibleSet = Set(visibleMonths.map { Calendar.current.startOfDay(for: $0) })
        let latestVisibleSnapshots = Dictionary(grouping: snapshots.filter {
            visibleSet.contains(Calendar.current.startOfDay(for: $0.monthStartDate))
        }) {
            monthPassionKey(monthStart: $0.monthStartDate, passionType: $0.passionType)
        }.compactMapValues { rows in
            rows.max(by: { $0.updatedAt < $1.updatedAt })
        }
        return latestVisibleSnapshots.mapValues(\.score)
    }

    private var yTicks: [Double] { Array(stride(from: 0.0, through: 16.0, by: 4.0)) }
    private var chartYMax: Double { 16.0 }

    private var baselineVisibleMonthStart: Date? { visibleMonths.first }

    private var averageScore: Double {
        guard !selectedMonthSnapshots.isEmpty else { return 0 }
        return selectedMonthSnapshots.map(\.score).reduce(0, +) / Double(selectedMonthSnapshots.count)
    }

    private var strongestSnapshotIfUnique: PassionScoreSnapshot? {
        guard let best = selectedMonthSnapshots.max(by: { $0.score < $1.score }) else { return nil }
        let bestRounded = roundedTenth(best.score)
        let ties = selectedMonthSnapshots.filter { roundedTenth($0.score) == bestRounded }.count
        return ties == 1 ? best : nil
    }

    private var biggestMover: (PassionScoreSnapshot, Double)? {
        let deltas: [(PassionScoreSnapshot, Double)] = selectedMonthSnapshots.compactMap { snap in
            guard let delta = displayedDelta(for: snap) else { return nil }
            return (snap, delta)
        }
        let result = deltas.max { abs($0.1) < abs($1.1) }
        if let result, abs(result.1) < 0.05 { return nil }
        return result
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if trendsContentIsReady {
                    summaryTiles
                    timelinePickerRow
                    trendGraphSection
                    passionsSection
                    insightsSection
                } else {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Loading insights…")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .frame(minHeight: 220)
                    .padding(.vertical, 24)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Purpose Insights")
        .navigationBarTitleDisplayMode(.inline)
        .background(Color(.systemBackground))
        .onAppear {
            if selectedMonthRaw == nil {
                selectedMonthRaw = visibleMonths.last ?? allMonthStarts.last
            }
            if selectedPassionTypeRaw == nil {
                selectedPassionTypeRaw = selectedSnapshot?.passionTypeRaw
            }
            if !trendsContentIsReady {
                DispatchQueue.main.async {
                    trendsContentIsReady = true
                }
            }
        }
        .onChange(of: snapshots.count) { _, _ in
            if selectedMonthRaw == nil || nearestMonth(to: selectedMonthRaw ?? .now) == nil {
                selectedMonthRaw = visibleMonths.last ?? allMonthStarts.last
            }
            if let selectedPassionTypeRaw,
               selectedMonthSnapshots.contains(where: { $0.passionTypeRaw == selectedPassionTypeRaw }) {
                return
            }
            self.selectedPassionTypeRaw = selectedSnapshot?.passionTypeRaw
        }
        .onChange(of: selectedTimeline) { _, _ in
            selectedMonthRaw = visibleMonths.last ?? allMonthStarts.last
        }
    }

    @ViewBuilder
    private var trendGraphSection: some View {
        if visibleMonths.isEmpty {
            VStack(spacing: 6) {
                Text("No Purpose Insights Yet").font(.headline)
                Text("Monthly passion scores will appear here as you use Loom.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                let rowsByMonth = chartRowsByMonth
                GeometryReader { geo in
                    let plotWidth = max(0, geo.size.width - yAxisWidth)
                    HStack(spacing: 0) {
                        yAxisView
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                barsView(plotWidth: plotWidth, rowsByMonth: rowsByMonth)
                                xAxisView(plotWidth: plotWidth)
                            }
                        }
                    }
                }
                .frame(height: plotHeight + 16)
            }
            .padding(10)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var yAxisView: some View {
        VStack(spacing: 0) {
            ForEach(yTicks.reversed(), id: \.self) { tick in
                Text("\(Int(tick))")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: 24, height: plotHeight / CGFloat(max(1, yTicks.count - 1)), alignment: .trailing)
            }
        }
        .frame(height: plotHeight)
        .frame(width: yAxisWidth, alignment: .trailing)
        .padding(.top, 2)
    }

    private func barsView(plotWidth: CGFloat, rowsByMonth: [Date: [DrivingForceTrendRow]]) -> some View {
        let width = effectiveColumnWidth(plotWidth: plotWidth)
        let spacing = effectiveColumnSpacing
        return LazyHStack(alignment: .bottom, spacing: spacing) {
            ForEach(visibleMonths, id: \.self) { month in
                Button {
                    selectedMonthRaw = month
                } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(.systemBackground))
                            .frame(width: width, height: plotHeight)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ForEach(segments(for: month, rowsByMonth: rowsByMonth)) { segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(width: width, height: segment.height)
                            }
                        }
                        .frame(width: width, height: plotHeight, alignment: .bottom)

                        if let selectedMonthStart, Calendar.current.isDate(selectedMonthStart, inSameDayAs: month) {
                            RoundedRectangle(cornerRadius: 5)
                                .stroke(Color.blue.opacity(0.45), lineWidth: 2)
                                .background(
                                    RoundedRectangle(cornerRadius: 5)
                                        .fill(Color.blue.opacity(0.08))
                                )
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(minWidth: trendContentWidth(plotWidth: plotWidth, columnWidth: width, spacing: spacing), alignment: .leading)
        .frame(height: plotHeight, alignment: .bottom)
    }

    private func xAxisView(plotWidth: CGFloat) -> some View {
        let width = effectiveColumnWidth(plotWidth: plotWidth)
        let spacing = effectiveColumnSpacing
        return LazyHStack(alignment: .top, spacing: spacing) {
            ForEach(visibleMonths, id: \.self) { month in
                Text(monthLabel(month))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: width)
                    .lineLimit(1)
            }
        }
        .padding(.leading, leadingPadding)
        .padding(.trailing, trailingPadding)
        .frame(minWidth: trendContentWidth(plotWidth: plotWidth, columnWidth: width, spacing: spacing), alignment: .leading)
        .frame(height: 16, alignment: .top)
    }

    private var effectiveColumnSpacing: CGFloat {
        switch selectedTimeline {
        case .threeMonths: return 4
        case .sixMonths: return 3
        default: return 2
        }
    }

    private var baseColumnWidth: CGFloat {
        switch selectedTimeline {
        case .threeMonths: return 34
        case .sixMonths: return 24
        case .oneYear: return 16
        case .threeYears, .all: return 12
        }
    }

    private func effectiveColumnWidth(plotWidth: CGFloat) -> CGFloat {
        let count = max(1, visibleMonths.count)
        let usable = max(0, plotWidth - leadingPadding - trailingPadding - CGFloat(max(0, count - 1)) * effectiveColumnSpacing)
        let fillWidth = usable / CGFloat(count)
        return max(baseColumnWidth, fillWidth)
    }

    private func trendContentWidth(plotWidth: CGFloat, columnWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = max(1, visibleMonths.count)
        let total = leadingPadding + trailingPadding + CGFloat(count) * columnWidth + CGFloat(max(0, count - 1)) * spacing
        return max(plotWidth, total)
    }

    private var timelinePickerRow: some View {
        Picker("", selection: $selectedTimeline) {
            ForEach(timelineOptions) { option in
                Text(option.rawValue).tag(option)
            }
        }
        .pickerStyle(.segmented)
    }

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            summaryTile(
                title: "Average",
                value: selectedMonthSnapshots.isEmpty ? "—" : String(format: "%.1f/4", averageScore),
                subtitle: selectedMonthStart.map(monthDateLabel) ?? "—"
            )
            summaryTile(
                title: "Strongest",
                value: strongestSnapshotIfUnique.map { passionTitle(for: $0.passionType) } ?? "—",
                subtitle: strongestSnapshotIfUnique.map { String(format: "%.1f/4", $0.score) } ?? "—"
            )
            summaryTile(
                title: "Mover",
                value: biggestMover.map { passionTitle(for: $0.0.passionType) } ?? "—",
                subtitle: biggestMover.map { String(format: "%@%.1f", $0.1 >= 0 ? "+" : "", $0.1) } ?? "—"
            )
        }
    }

    private func summaryTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.headline).lineLimit(1).minimumScaleFactor(0.75)
            Text(subtitle).font(.caption2).foregroundStyle(.secondary).lineLimit(1).minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Passions").font(.headline)
            ForEach(selectedMonthSnapshots.sorted(by: passionSnapshotSort), id: \.passionTypeRaw) { snap in
                Button {
                    selectedPassionTypeRaw = snap.passionTypeRaw
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(passionColor(for: snap.passionType))
                            .frame(width: 10, height: 10)
                        Text(passionTitle(for: snap.passionType))
                            .foregroundStyle(.primary)
                            .fontWeight(selectedPassionTypeRaw == snap.passionTypeRaw ? .semibold : .regular)
                        Spacer(minLength: 0)
                        Text(String(format: "%.1f/4", snap.score))
                            .foregroundStyle(.secondary)
                        let delta = displayedDelta(for: snap)
                        Text(deltaGlyph(delta))
                            .foregroundStyle(deltaColor(delta))
                            .frame(width: 18)
                        if let delta {
                            Text(deltaText(delta))
                                .font(.subheadline)
                                .foregroundStyle(deltaColor(delta))
                                .frame(width: 40, alignment: .trailing)
                        } else {
                            Text("—")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .frame(width: 40, alignment: .trailing)
                        }
                    }
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(
                        RoundedRectangle(cornerRadius: 10)
                            .fill(selectedPassionTypeRaw == snap.passionTypeRaw ? Color(.systemGray5) : Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Insights").font(.headline)
                Spacer()
                if let snap = selectedSnapshot {
                    Text(passionTitle(for: snap.passionType))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(insightsPassionTitleColor(for: snap.passionType))
                }
            }

            if let snap = selectedSnapshot {
                if let message = primaryInsightMessage(for: snap) {
                    DrivingForceAnimatedInsightCallout(message: message)
                }

                VStack(spacing: 8) {
                    insightRow("Current Score", String(format: "%.1f/4", snap.score))
                    insightRow("Month Score", String(format: "%.1f/4", snap.targetScore))
                    insightRow("Momentum", momentumText(snap.momentum))
                    insightRow("Consistency", consistencyText(snap.consistency))
                    Divider()
                    insightRow("Structure", percentTextOrDash(snap.structure))
                    insightRow("Outcomes", percentTextOrDash(snap.outcomeCoverage ?? 0))
                    insightRow("Action blocks", percentTextOrDash(snap.actionCoverage))
                    insightRow("Little Wins", percentTextOrDash(snap.littleWinsCoverage))
                    insightRow(
                        "Carryover penalty",
                        percentTextOrDash(snap.carryoverPenalty),
                        color: snap.carryoverPenalty > 0.30 ? .red : .secondary
                    )
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
            }
        }
    }

    private func insightRow(_ label: String, _ value: String, color: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.subheadline)
            Spacer(minLength: 0)
            Text(value)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(color)
        }
    }

    private func segments(for month: Date, rowsByMonth: [Date: [DrivingForceTrendRow]]) -> [TrendSegment] {
        let key = Calendar.current.startOfDay(for: month)
        let rows = (rowsByMonth[key] ?? []).sorted {
            (chartPassionOrder.firstIndex(of: $0.passionType) ?? Int.max) < (chartPassionOrder.firstIndex(of: $1.passionType) ?? Int.max)
        }
        return rows.compactMap { row in
            guard row.value > 0 else { return nil }
            let height = CGFloat(row.value / chartYMax) * plotHeight
            guard height > 0 else { return nil }
            return TrendSegment(id: row.id, color: passionColor(for: row.passionType), height: height)
        }
    }

    private func displayedDelta(for snap: PassionScoreSnapshot) -> Double? {
        guard let baseline = baselineVisibleMonthStart, let selected = selectedMonthStart else { return nil }
        let baseKey = monthPassionKey(monthStart: baseline, passionType: snap.passionType)
        let selectedKey = monthPassionKey(monthStart: selected, passionType: snap.passionType)
        guard let base = actualSnapshotValueByMonthPassion[baseKey],
              let current = actualSnapshotValueByMonthPassion[selectedKey] else { return nil }
        return roundedTenth(current) - roundedTenth(base)
    }

    private func monthPassionKey(monthStart: Date, passionType: PassionType) -> String {
        "\(Int(Calendar.current.startOfDay(for: monthStart).timeIntervalSince1970))|\(passionType.rawValue)"
    }

    private func nearestMonth(to date: Date) -> Date? {
        guard !visibleMonths.isEmpty else { return nil }
        let target = Calendar.current.startOfDay(for: date)
        return visibleMonths.min(by: { abs($0.timeIntervalSince(target)) < abs($1.timeIntervalSince(target)) })
    }

    private func monthLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("M/yy")
        return f.string(from: date)
    }

    private func monthDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("MMM y")
        return f.string(from: date)
    }

    private func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func percentTextOrDash(_ value: Double) -> String {
        let pct = Int((PassionScoringMath.clamped01(value) * 100).rounded())
        return pct == 0 ? "—" : "\(pct)%"
    }

    private func momentumText(_ value: Double) -> String {
        let v = PassionScoringMath.clamp(value, min: -1, max: 1)
        if abs(v) < 0.12 { return "Stable" }
        return v > 0 ? "Improving" : "Declining"
    }

    private func consistencyText(_ value: Double) -> String {
        let v = PassionScoringMath.clamp(value, min: 0, max: 1)
        if v >= 0.75 { return "Stable" }
        if v >= 0.4 { return "Mixed" }
        return "Volatile"
    }

    private func deltaText(_ delta: Double) -> String {
        if abs(delta) < 0.05 { return "—" }
        return String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
    }

    private func deltaGlyph(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private func deltaColor(_ delta: Double?) -> Color {
        guard let delta else { return .secondary }
        if abs(delta) < 0.05 { return .secondary }
        return delta > 0 ? .green : .orange
    }

    private func passionTitle(for passionType: PassionType) -> String {
        switch passionType {
        case .love: return "Love"
        case .vows: return "Vows"
        case .thrill: return "Thrill"
        case .hate: return "Hate"
        }
    }

    private func passionColor(for passionType: PassionType) -> Color {
        switch passionType {
        case .love: return Color(white: 0.82)
        case .vows: return Color(white: 0.56)
        case .thrill: return Color(white: 0.30)
        case .hate: return Color(white: 0.08)
        }
    }

    private func insightsPassionTitleColor(for passionType: PassionType) -> Color {
        if colorScheme == .dark {
            return Color(white: 0.88)
        }
        return passionColor(for: passionType)
    }

    private func primaryInsightMessage(for snap: PassionScoreSnapshot) -> String? {
        struct Candidate {
            let priority: Double
            let text: String
        }

        let structure = PassionScoringMath.clamped01(snap.structure)
        let outcomes = PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0)
        let actions = PassionScoringMath.clamped01(snap.actionCoverage)
        let wins = PassionScoringMath.clamped01(snap.littleWinsCoverage)
        let carry = PassionScoringMath.clamped01(snap.carryoverPenalty)
        let consistency = PassionScoringMath.clamped01(snap.consistency)
        let evidence = PassionScoringMath.clamped01(snap.evidenceStable)

        let structurePct = Int((structure * 100).rounded())
        let outcomesPct = Int((outcomes * 100).rounded())
        let actionPct = Int((actions * 100).rounded())
        let winsPct = Int((wins * 100).rounded())
        let carryPct = Int((carry * 100).rounded())
        let consistencyPct = Int((consistency * 100).rounded())
        let evidencePct = Int((evidence * 100).rounded())

        var items: [Candidate] = []

        if structure >= 0.65 && actions <= 0.45 {
            items.append(.init(
                priority: (1 - actions) * 1.4,
                text: "\(passionTitle(for: snap.passionType)) has strong structure (\(structurePct)%) but weak execution (\(actionPct)% Action blocks). Focus on finishing the most important supporting work."
            ))
        }

        if wins >= 0.65 && outcomes <= 0.45 {
            items.append(.init(
                priority: (1 - outcomes) * 1.35,
                text: "\(passionTitle(for: snap.passionType)) is supported by daily wins (\(winsPct)%), but outcomes are weak (\(outcomesPct)%). Make sure monthly outcomes reflect this passion directly."
            ))
        }

        if carry >= 0.30 {
            items.append(.init(
                priority: carry * 1.5,
                text: "Carryover is high (\(carryPct)% penalty) for \(passionTitle(for: snap.passionType)). Reduce scope or break support work into smaller actions."
            ))
        }

        if consistency <= 0.35 {
            items.append(.init(
                priority: (1 - consistency) * 1.2,
                text: "\(passionTitle(for: snap.passionType)) is volatile (\(consistencyPct)% consistency). Aim for steadier weekly execution instead of spikes."
            ))
        }

        if evidence >= 0.70 && carry < 0.20 {
            items.append(.init(
                priority: evidence * 0.8,
                text: "\(passionTitle(for: snap.passionType)) is performing well (\(evidencePct)% evidence). Keep the current support pattern consistent."
            ))
        }

        return items.max(by: { $0.priority < $1.priority })?.text
            ?? "\(passionTitle(for: snap.passionType)) is stable overall. Improve one support behavior this month to lift the score."
    }
}

private struct DrivingForceAnimatedInsightCallout: View {
    let message: String
    @State private var outlineAngle: Double = 0

    private var outlineGradient: AngularGradient {
        AngularGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.15, green: 0.83, blue: 0.95),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.80, green: 0.38, blue: 0.78),
                Color(red: 0.98, green: 0.36, blue: 0.58),
                Color(red: 0.75, green: 0.42, blue: 0.74),
                Color(red: 0.22, green: 0.47, blue: 1.0)
            ],
            center: .center,
            angle: .degrees(outlineAngle)
        )
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("LoomAI")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(outlineGradient.opacity(0.95), lineWidth: 2)
        )
        .onAppear {
            guard outlineAngle == 0 else { return }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                outlineAngle = 360
            }
        }
    }
}

extension PurposeView {
    init(autoOpenCreateVision: Bool = false) {
        self.autoOpenCreateVision = autoOpenCreateVision
    }
}

#if canImport(UIKit)
private struct DrivingForceEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: DrivingForceEditorTextView
        var lastCursorSeed: Int = 0

        init(parent: DrivingForceEditorTextView) {
            self.parent = parent
        }

        func textViewDidChange(_ textView: UITextView) {
            parent.text = textView.text
        }

        func textViewDidBeginEditing(_ textView: UITextView) {
            parent.isFocused = true
        }

        func textViewDidEndEditing(_ textView: UITextView) {
            parent.isFocused = false
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator(parent: self)
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.backgroundColor = .clear
        view.font = UIFont.preferredFont(forTextStyle: .body)
        view.delegate = context.coordinator
        view.textContainerInset = .zero
        return view
    }

    func updateUIView(_ uiView: UITextView, context: Context) {
        context.coordinator.parent = self
        if uiView.text != text {
            uiView.text = text
        }

        if isFocused {
            if !uiView.isFirstResponder {
                uiView.becomeFirstResponder()
            }
            if context.coordinator.lastCursorSeed != cursorSeed {
                uiView.selectedRange = NSRange(location: (uiView.text as NSString).length, length: 0)
                context.coordinator.lastCursorSeed = cursorSeed
            }
        } else if uiView.isFirstResponder {
            uiView.resignFirstResponder()
        }
    }
}
#endif

struct PassionEditor: View {
    let category: PassionCategory
    let addState: AddState
    let onAddStateChange: (AddState) -> Void
    @FocusState.Binding var focusedField: Field?
    let onCommit: (String) -> Void
    let onDelete: (Passion) -> Void
    @Environment(\.modelContext) private var context
    @State private var editingPassion: Passion?
    @State private var editText: String = ""
    
    var body: some View {
        Section {
            if addState.isAdding {
                TextField("Add \(category.title)", text: Binding(
                    get: { addState.newText },
                    set: { onAddStateChange(addStateWithNewText($0)) }
                ))
                .focused($focusedField, equals: .passion(category.emotion))
                .submitLabel(.done)
                .textInputAutocapitalization(.sentences)
                .autocorrectionDisabled(false)
                .onSubmit { onCommit(addState.newText) }
                .padding(.vertical, 4)
            } else {
                Button("+ Add \(category.title)") {
                    withAnimation {
                        onAddStateChange(AddState(isAdding: true))
                        focusedField = .passion(category.emotion)
                    }
                }
                .foregroundStyle(.blue)
                .padding(.vertical, 4)
            }

            ForEach(category.query, id: \.id) { passion in
                if editingPassion?.id == passion.id {
                    TextField("Edit passion", text: $editText)
                        .focused($focusedField, equals: .passion(category.emotion))
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .submitLabel(.done)
                        .onSubmit {
                            commitEdit(passion: passion)
                        }
                } else {
                    Text(passion.passion)
                        .onTapGesture {
                            startEditing(passion)
                        }
                        .swipeActions {
                            Button(role: .destructive) {
                                onDelete(passion)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                        .tint(.red)
                }
            }
        } header: {
            HStack(spacing: 8) {
                Text(category.title.uppercased())
                Spacer(minLength: 8)
                Text(category.prompt)
                    .italic()
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
        .onChange(of: focusedField) { _, newValue in
            // If focus leaves this category's inline add field, collapse back to "Add Item".
            guard addState.isAdding else { return }
            if newValue != .passion(category.emotion) {
                onAddStateChange(AddState())
            }
        }
        .onChange(of: editingPassion?.id) { _, newValue in
            // Entering edit mode should close the add row for this category.
            if addState.isAdding && newValue != nil {
                onAddStateChange(AddState())
            }
        }
    }
    
    private func addStateWithNewText(_ text: String) -> AddState {
        var newState = addState
        newState.newText = text
        return newState
    }
    
    private func startEditing(_ passion: Passion) {
        editingPassion = passion
        editText = passion.passion
        focusedField = .passion(category.emotion)
    }
    
    private func commitEdit(passion: Passion) {
        let trimmed = editText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            RecentlyDeletedStore.trash(passion, in: context)
            editingPassion = nil
            return
        }
        
        let archive = PassionArchive(
            date: passion.date,
            emotion: passion.emotion,
            passionSnapshot: passion.passion,
            archivedAt: .now
        )
        context.insert(archive)
        
        passion.passion = trimmed
        passion.date = .now
        editingPassion = nil
        hideKeyboard()
    }
}

#if canImport(UIKit)
extension View {
    func hideKeyboard() {
        UIApplication.shared.sendAction(
            #selector(UIResponder.resignFirstResponder),
            to: nil, from: nil, for: nil
        )
    }
}
#endif
