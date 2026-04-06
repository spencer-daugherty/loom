import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct PurposeStartView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme

    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse) private var diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    @Query(sort: \PurposeProfileInsightsSnapshot.generatedAt, order: .reverse) private var purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    private let startAtInsights: Bool

    @State private var step: Step = .intro
    @State private var visionText: String = ""
    @State private var purposeText: String = ""
    @State private var draftPassions: [String: [String]] = [
        "love": [],
        "vows": [],
        "thrill": [],
        "just": []
    ]
    @State private var entryText: [String: String] = [
        "love": "",
        "vows": "",
        "thrill": "",
        "just": ""
    ]
    @State private var showNeedIdeasVision = false
    @State private var showNeedIdeasPassions = false
    @State private var autoWriteVisionSuggestions: [String] = []
    @State private var autoWritePassionSuggestions: [AutoWritePassionSuggestion] = []
    @State private var isAutoWritingVision = false
    @State private var isAutoWritingPassions = false
    @State private var autoWriteVisionErrorMessage: String? = nil
    @State private var autoWritePassionsErrorMessage: String? = nil
    @State private var autoWriteVisionTroubleshootingMessage: String? = nil
    @State private var autoWritePassionsTroubleshootingMessage: String? = nil
    @State private var autoWriteVisionLoadedKeys = Set<String>()
    @State private var autoWritePassionsLoadedKeys = Set<String>()
    @State private var autoWritePassionSuggestionsCache: [String: [AutoWritePassionSuggestion]] = [:]
    @State private var selectedPassionAutoWriteFilter: PassionAutoWriteFilter = .all
    @State private var autoWriteMemory: PurposeAutoWriteMemory = .load()
    @State private var lastAppliedVisionSuggestion: String? = nil
    @State private var trackedEditForLastAppliedVision = false
    @State private var purposeInsightCards: [PurposeInsightCard] = []
    @State private var purposeInsightProfileName: String = ""
    @State private var isGeneratingPurposeInsights = false
    @State private var insightsOutlinePhase: CGFloat = 0
    @State private var animatePurposeInsightOutline = false
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating: Bool = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil
    @State private var keyboardHeight: CGFloat = 0
    @State private var validationHintText: String = ""
    @State private var showValidationHint = false
    @State private var hintWorkItem: DispatchWorkItem?
    @State private var shouldHighlightStepValidation = false
    @State private var invalidPassionKeys = Set<String>()
    @State private var addingPassionBuckets: Set<String> = []
    @State private var showPurposeInsightsTimeoutAlert = false
    @State private var hasTimedOutPurposeInsights = false
    @State private var purposeInsightsTimeoutTask: Task<Void, Never>?
    @State private var purposeInsightsTroubleshootingMessage: String? = nil
    @State private var loadedPurposeInsightsCycleKey: String?

    @FocusState private var focusedField: Field?
    private enum Field: Hashable {
        case vision
        case purpose
        case passion(String)
    }

    private struct AutoWritePassionSuggestion: Identifiable, Hashable {
        let emotion: String
        let passion: String
        var id: String { "\(emotion)|\(passion.lowercased())" }
    }

    private struct PurposeInsightCard: Identifiable, Hashable {
        struct Signals: Hashable {
            let stressTrigger: String
            let breakingPoint: String
        }

        let title: String
        let body: String?
        let signals: Signals?
        var id: String {
            if let body {
                return "\(title.lowercased())|\(body.lowercased())"
            }
            if let signals {
                return "\(title.lowercased())|\(signals.stressTrigger.lowercased())|\(signals.breakingPoint.lowercased())"
            }
            return title.lowercased()
        }

        init(title: String, body: String) {
            self.title = title
            self.body = body
            self.signals = nil
        }

        init(title: String, signals: Signals) {
            self.title = title
            self.body = nil
            self.signals = signals
        }
    }

    private struct PurposeAutoWriteMemory: Codable {
        var visionAccepted: [String: Int] = [:]
        var visionEdited: [String: Int] = [:]
        var passionsAccepted: [String: [String: Int]] = [
            "love": [:], "vows": [:], "thrill": [:], "just": [:]
        ]

        private static let defaultsKey = "purpose_start_autowrite_memory_v1"

        static func load() -> Self {
            guard
                let data = UserDefaults.standard.data(forKey: defaultsKey),
                let decoded = try? JSONDecoder().decode(Self.self, from: data)
            else { return Self() }
            return decoded
        }

        func persist() {
            guard let data = try? JSONEncoder().encode(self) else { return }
            UserDefaults.standard.set(data, forKey: Self.defaultsKey)
        }

        mutating func recordVisionAccepted(_ phrase: String) {
            let key = Self.compact(phrase, maxWords: 10, maxChars: 64)
            visionAccepted = Self.bumpedMap(visionAccepted, key: key, keepTop: 6)
        }

        mutating func recordVisionEdited(_ phrase: String) {
            let key = Self.compact(phrase, maxWords: 10, maxChars: 64)
            visionEdited = Self.bumpedMap(visionEdited, key: key, keepTop: 6)
        }

        mutating func recordPassionAccepted(emotion: String, passion: String) {
            let key = Self.compact(passion, maxWords: 5, maxChars: 40)
            let current = passionsAccepted[emotion] ?? [:]
            passionsAccepted[emotion] = Self.bumpedMap(current, key: key, keepTop: 6)
        }

        func visionSummary() -> String {
            let accepted = topKeys(visionAccepted, limit: 2)
            let edited = topKeys(visionEdited, limit: 2)
            var lines: [String] = []
            if !accepted.isEmpty { lines.append("Accepted examples: \(accepted.joined(separator: " | "))") }
            if !edited.isEmpty { lines.append("Edited examples: \(edited.joined(separator: " | "))") }
            if lines.isEmpty { return "No preference memory yet." }
            return lines.joined(separator: "; ")
        }

        func passionsSummary(filter: PassionAutoWriteFilter) -> String {
            let keys: [String] = filter == .all ? ["love", "vows", "thrill", "just"] : [filter.rawValue]
            var parts: [String] = []
            for key in keys {
                let top = topKeys(passionsAccepted[key] ?? [:], limit: 2)
                guard !top.isEmpty else { continue }
                let label: String
                switch key {
                case "love": label = "Love"
                case "vows": label = "Vow"
                case "thrill": label = "Thrill"
                default: label = "Hate"
                }
                parts.append("\(label): \(top.joined(separator: ", "))")
            }
            return parts.isEmpty ? "No preference memory yet." : parts.joined(separator: "; ")
        }

        private static func bumpedMap(_ map: [String: Int], key: String, keepTop: Int) -> [String: Int] {
            guard !key.isEmpty else { return map }
            var updated = map
            updated[key, default: 0] += 1
            let trimmed = updated
                .sorted { lhs, rhs in
                    if lhs.value == rhs.value { return lhs.key < rhs.key }
                    return lhs.value > rhs.value
                }
                .prefix(keepTop)
                .map { ($0.key, $0.value) }
            return Dictionary(uniqueKeysWithValues: trimmed)
        }

        private func topKeys(_ map: [String: Int], limit: Int) -> [String] {
            map.sorted {
                if $0.value == $1.value { return $0.key < $1.key }
                return $0.value > $1.value
            }
            .prefix(limit)
            .map(\.key)
        }

        private static func compact(_ text: String, maxWords: Int, maxChars: Int) -> String {
            let cleaned = text
                .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                .trimmingCharacters(in: .whitespacesAndNewlines)
            guard !cleaned.isEmpty else { return "" }
            let words = cleaned.split(whereSeparator: \.isWhitespace).prefix(maxWords).joined(separator: " ")
            return String(words.prefix(maxChars))
        }
    }

    private enum PassionAutoWriteFilter: String, CaseIterable, Identifiable {
        case all
        case love
        case vows
        case thrill
        case just

        var id: String { rawValue }
        var label: String {
            switch self {
            case .all: return "All"
            case .love: return "Love"
            case .vows: return "Vow"
            case .thrill: return "Thrill"
            case .just: return "Hate"
            }
        }
    }

    private var passionAutoWriteFilterOptionsReversed: [PassionAutoWriteFilter] {
        Array(PassionAutoWriteFilter.allCases.reversed())
    }

    private enum Step: Int, CaseIterable {
        case intro = 0
        case vision = 1
        case purpose = 2
        case passions = 3
        case summary = 4
        case insights = 5

        var title: String {
            switch self {
            case .intro: return "Set Your Purpose"
            case .vision: return "Vision"
            case .purpose: return "Purpose"
            case .passions: return "Passions"
            case .summary: return "Summary"
            case .insights: return "How Loom sees you (so far)..."
            }
        }
    }

    init(startAtInsights: Bool = false) {
        self.startAtInsights = startAtInsights
        _step = State(initialValue: startAtInsights ? .insights : .intro)
    }

    private let bucketOrder: [(key: String, title: String)] = [
        ("love", "Love"),
        ("vows", "Vow"),
        ("thrill", "Thrill"),
        ("just", "Hate")
    ]

    private var currentDrivingForce: DrivingForce? {
        drivingForces.first
    }

    private var personalizationSnapshot: PersonalizationSnapshot? {
        PersonalizationStore.cachedContextForCurrentUser()?.current
    }

    private var hasPersonalizationSnapshot: Bool {
        personalizationSnapshot != nil
    }

    private var visionTrimmed: String {
        visionText.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var summaryCanSave: Bool {
        !visionTrimmed.isEmpty &&
        bucketOrder.allSatisfy { missingCount(draftPassions[$0.key] ?? []) == 0 }
    }

    private var firstIncompleteBucket: String? {
        bucketOrder.first(where: { missingCount(draftPassions[$0.key] ?? []) > 0 })?.key
    }

    private var missingPassionKeys: [String] {
        bucketOrder
            .map(\.key)
            .filter { missingCount(draftPassions[$0] ?? []) > 0 }
    }

    private var isVisionInvalid: Bool {
        visionTrimmed.isEmpty
    }

    private var isPassionsInvalid: Bool {
        !missingPassionKeys.isEmpty
    }

    private var isNextDisabled: Bool {
        switch step {
        case .vision: return isVisionInvalid
        case .purpose: return false
        case .passions: return isPassionsInvalid
        default: return false
        }
    }

    private var isScrollableStep: Bool {
        step == .vision || step == .passions || step == .summary || step == .insights
    }

    private var editorSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var rowSurfaceColor: Color {
        colorScheme == .dark ? Color(.secondarySystemBackground) : .white
    }

    private var contentBottomPadding: CGFloat {
        (step == .summary || step == .insights) ? 100 : 0
    }
    private var screenHeight: CGFloat { UIScreen.main.bounds.height }
    private var screenWidth: CGFloat { UIScreen.main.bounds.width }
    private var isCompactIntroLayout: Bool { screenHeight <= 740 || screenWidth <= 390 }
    private var introSubtextFont: Font { isCompactIntroLayout ? .system(size: 14) : .body }
    private let autoWritePillHeight: CGFloat = 45
    private var isVisionKeyboardVisible: Bool { step == .vision && keyboardHeight > 0 }
    private var isPassionsKeyboardVisible: Bool { (step == .passions || step == .purpose) && keyboardHeight > 0 }
    private let footerPinnedHeight: CGFloat = 68
    private let keyboardFloatingGap: CGFloat = 15
    private var keyboardScrollableBottomPadding: CGFloat {
        guard isScrollableStep, keyboardHeight > 0 else { return 0 }
        // Ensure lower content can scroll fully above keyboard while footer remains fixed.
        return max(0, keyboardHeight - footerPinnedHeight + 24)
    }

    private func autoWriteBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return footerPinnedHeight + 8 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + keyboardFloatingGap
    }

    var body: some View {
        ZStack {
            Color(.systemGroupedBackground)
                .ignoresSafeArea()

            Group {
                if isScrollableStep {
                    ScrollView {
                        mainContent
                    }
                } else {
                    mainContent
                        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            footer
                .padding(.horizontal)
                .padding(.top, 8)
                .padding(.bottom, 10)
                .background(Color(.systemGroupedBackground))
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
        .onChange(of: step) { _, newStep in
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.06) {
                switch newStep {
                case .vision:
                    focusedField = nil
                case .purpose:
                    focusedField = nil
                case .passions:
                    if let key = firstIncompleteBucket {
                        focusedField = .passion(key)
                    } else {
                        focusedField = .passion("love")
                    }
                default:
                    focusedField = nil
                }
            }
            if newStep == .insights {
                restartPurposeInsightsTimeoutWindow()
            } else {
                hasTimedOutPurposeInsights = false
                purposeInsightsTimeoutTask?.cancel()
                purposeInsightsTimeoutTask = nil
            }
            handleAutoStartForStep(newStep)
        }
        .onChange(of: focusedField) { _, newValue in
            if case .some(.passion(let key)) = newValue {
                addingPassionBuckets = [key]
            } else {
                addingPassionBuckets = []
                for key in bucketOrder.map(\.key) {
                    entryText[key] = ""
                }
            }
        }
        .onChange(of: visionText) { _, newValue in
            clearStepValidationIfResolved()
            recordVisionEditIfNeeded(newValue: newValue)
        }
        .onChange(of: draftPassions) { _, _ in
            clearStepValidationIfResolved()
        }
        .onChange(of: isGeneratingPurposeInsights, initial: false) { _, newValue in
            setAutoWriteLoadingAnimation(newValue)
        }
        .navigationTitle(stepTitle)
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(step != .intro)
        .toolbar {
            if step != .intro {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button {
                        goBackFromCurrentStep()
                    } label: {
                        Label("Back", systemImage: "chevron.left")
                    }
                }
            }
        }
        .onAppear {
            loadFromPersistentData()
            if step == .insights {
                restartPurposeInsightsTimeoutWindow()
            }
            handleAutoStartForStep(step)
        }
        .onDisappear {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            purposeInsightsTimeoutTask?.cancel()
            purposeInsightsTimeoutTask = nil
        }
        .onChange(of: purposeInsightCards) { _, newValue in
            if !newValue.isEmpty {
                hasTimedOutPurposeInsights = false
                purposeInsightsTimeoutTask?.cancel()
                purposeInsightsTimeoutTask = nil
                animatePurposeInsightOutline = false
                Task { @MainActor in
                    try? await Task.sleep(for: .milliseconds(220))
                    guard !purposeInsightCards.isEmpty else { return }
                    animatePurposeInsightOutline = true
                }
            } else if step == .insights && !hasTimedOutPurposeInsights {
                restartPurposeInsightsTimeoutWindow()
                animatePurposeInsightOutline = false
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard
                let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect
            else { return }
            let screenHeight = UIScreen.main.bounds.height
            let overlap = max(0, screenHeight - frame.minY)
            keyboardHeight = overlap
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .overlay(alignment: .bottom) {
            if showValidationHint {
                Text(validationHintText)
                    .font(.footnote)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.black.opacity(0.12), lineWidth: 1)
                    )
                    .padding(.horizontal, 24)
                    .padding(.bottom, 56)
                    .transition(.opacity)
            }
        }
        .overlay(alignment: .bottom) {
            if let troubleshooting = bottomCopyTroubleshootingDetails {
                LoomAIBottomCopyTroubleshootingButton(details: troubleshooting)
                    .padding(.horizontal, 16)
                    .padding(.bottom, keyboardHeight > 0 ? (keyboardHeight + 12) : 84)
                    .transition(.opacity)
            } else if shouldShowBottomTroubleshootingPending {
                Text("Preparing troubleshooting…")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
                    .padding(.horizontal, 16)
                    .padding(.bottom, keyboardHeight > 0 ? (keyboardHeight + 12) : 84)
                    .transition(.opacity)
            }
        }
        .overlay {
            GeometryReader { proxy in
                Group {
                    if step == .vision {
                        HStack(spacing: 8) {
                            visionAutoWriteControls
                            if isVisionKeyboardVisible {
                                keyboardDismissButton
                            }
                        }
                    } else if step == .passions || step == .purpose {
                        HStack(spacing: 8) {
                            passionsAutoWriteControls
                            if isPassionsKeyboardVisible {
                                keyboardDismissButton
                            }
                        }
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                .padding(.trailing, 16)
                .padding(.bottom, autoWriteBottomPadding(in: proxy))
            }
        }
        .alert("Check your connection", isPresented: $showPurposeInsightsTimeoutAlert) {
            if loomAITroubleshootingEnabled,
               let details = purposeInsightsTroubleshootingMessage,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Copy troubleshooting") {
                    UIPasteboard.general.string = details
                }
            }
            Button("OK", role: .cancel) { }
        } message: {
            Text("Generate insights later in Account > Personalization.")
        }
    }

    private var keyboardDismissButton: some View {
        Button {
            if step == .vision && keyboardDismissShowsCheckmark {
                if isNextDisabled {
                    triggerStepValidationFeedback()
                } else {
                    shouldHighlightStepValidation = false
                    invalidPassionKeys = []
                    showValidationHint = false
                    focusedField = nil
                    advanceFromCurrentStep()
                }
            } else if (step == .passions || step == .purpose) && keyboardDismissShowsCheckmark {
                if case .passion(let bucketKey) = focusedField {
                    savePassionEntryFromKeyboard(bucketKey)
                }
            } else {
                focusedField = nil
            }
        } label: {
            Image(systemName: keyboardDismissShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(keyboardDismissShowsCheckmark ? .white : .primary.opacity(0.85))
                .frame(width: autoWritePillHeight, height: autoWritePillHeight)
                .background(
                    Group {
                        if keyboardDismissShowsCheckmark {
                            Circle().fill(Color.blue)
                        } else {
                            Circle().fill(.ultraThinMaterial)
                        }
                    }
                )
                .overlay(
                    Circle()
                        .stroke(
                            keyboardDismissShowsCheckmark
                            ? Color.blue.opacity(0.9)
                            : Color.white.opacity(0.28),
                            lineWidth: 1
                        )
                )
        }
        .buttonStyle(.plain)
    }

    private var keyboardDismissShowsCheckmark: Bool {
        switch focusedField {
        case .vision:
            return !visionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .purpose:
            return !purposeText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .passion(let key):
            return !(entryText[key] ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case nil:
            if step == .vision {
                return !visionText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            if step == .passions || step == .purpose {
                return entryText.values.contains { !$0.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
            }
            return false
        }
    }

    @ViewBuilder
    private var mainContent: some View {
        VStack(alignment: .leading, spacing: 14) {
            header

            switch step {
            case .intro:
                introStep
            case .vision:
                visionStep
            case .purpose:
                passionsStep
            case .passions:
                passionsStep
            case .summary:
                summaryStep
            case .insights:
                insightsStep
            }
        }
        .padding(.horizontal)
        .padding(.bottom, contentBottomPadding + keyboardScrollableBottomPadding)
        .frame(maxWidth: .infinity, alignment: .topLeading)
    }

    private var header: some View {
        VStack(spacing: 1) {
            if step == .intro {
                ZStack {
                    IntroRouteLinesView()
                        .padding(.horizontal, -24)
                        .allowsHitTesting(false)
                    Image("DrivingForceGraphic")
                        .resizable()
                        .scaledToFit()
                        .frame(maxWidth: .infinity)
                        .frame(height: 420)
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                }
                .frame(height: 420)
                .padding(.bottom, 2)
            }
            if step != .intro && !(startAtInsights && step == .insights) {
                progressStrip
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            if step == .intro {
                HStack(spacing: 6) {
                    Image(systemName: "clock.fill")
                        .font(.caption)
                    Text("~4 minutes")
                        .font(.caption.weight(.bold))
                }
                .foregroundStyle(.secondary)
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.systemGray5), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                .frame(maxWidth: .infinity, alignment: .center)
            }
        }
    }

    private var footer: some View {
        HStack(spacing: 10) {
            if step == .intro {
                Button {
                    step = .vision
                } label: {
                    Text("Start")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            } else if step == .summary {
                Button {
                    guard summaryCanSave else {
                        triggerHint("Please complete all required items.")
                        return
                    }
                    step = .insights
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
                .disabled(!summaryCanSave)
            } else if step == .insights {
                if startAtInsights {
                    Button {
                        dismiss()
                    } label: {
                        Text("Back")
                            .frame(maxWidth: .infinity)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                } else {
                    Button {
                        finalizeAndContinue()
                    } label: {
                        ZStack {
                            Text("Continue")
                                .opacity(isWaitingForPurposeInsights ? 0.0 : 1.0)
                                .frame(maxWidth: .infinity)
                            if isWaitingForPurposeInsights {
                                ProgressView()
                                    .progressViewStyle(.circular)
                            }
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                    .frame(maxWidth: .infinity)
                    .disabled(isWaitingForPurposeInsights)
                    .opacity(isWaitingForPurposeInsights ? 0.55 : 1.0)
                }
            } else {
                Button {
                    if isNextDisabled {
                        triggerStepValidationFeedback()
                    } else {
                        shouldHighlightStepValidation = false
                        invalidPassionKeys = []
                        showValidationHint = false
                        advanceFromCurrentStep()
                    }
                } label: {
                    Text("Next")
                        .frame(maxWidth: .infinity)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.borderedProminent)
                .tint(isNextDisabled ? Color(.systemGray3) : .accentColor)
                .controlSize(.large)
                .frame(maxWidth: .infinity)
            }
        }
    }

    private func goBackFromCurrentStep() {
        if startAtInsights, step == .insights {
            dismiss()
            return
        }
        switch step {
        case .intro:
            dismiss()
        case .vision:
            step = .intro
        case .purpose, .passions:
            step = .vision
        case .summary:
            step = .passions
        case .insights:
            step = .summary
        }
    }

    private var stepTitle: String {
        switch step {
        case .intro:
            return "Set Your Purpose"
        case .vision:
            return "Vision"
        case .purpose:
            return "Passions"
        case .passions:
            return "Passions"
        case .summary:
            return "Summary"
        case .insights:
            return "How Loom sees you (so far)..."
        }
    }

    private var isWaitingForPurposeInsights: Bool {
        AppleIntelligenceSupport.isAvailable
            && step == .insights
            && purposeInsightCards.isEmpty
            && !hasTimedOutPurposeInsights
    }

    private var progressCurrentStep: Int {
        switch step {
        case .vision: return 1
        case .purpose: return 2
        case .passions: return 2
        case .summary: return 3
        case .insights: return 4
        case .intro: return 0
        }
    }

    private let progressTotalSteps: Int = 4

    private var progressStrip: some View {
        HStack(spacing: 6) {
            ForEach(1...progressTotalSteps, id: \.self) { index in
                Capsule()
                    .fill(index <= progressCurrentStep ? Color.accentColor : Color(.systemGray4))
                    .frame(width: 26)
                    .frame(height: 4)
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    private var introStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("This isn’t long-term goals.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            Text("It’s who you are: your values, principles, and high-level direction that tends to stay stable over time.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
            Text("Wording can evolve, but the themes should remain a compass.")
                .font(introSubtextFont)
                .lineLimit(nil)
                .minimumScaleFactor(0.8)
                .allowsTightening(true)
                .fixedSize(horizontal: false, vertical: true)
                .foregroundStyle(.secondary)
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var visionStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .padding(.top, 1)
                Text("Start fast and simple. You can improve over time.")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundStyle(Color.black.opacity(0.7))
                    .multilineTextAlignment(.leading)
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
            )

            Text("If there were no limits, what life would you create?")
                .font(.headline)

            multiLineEditor(
                text: $visionText,
                placeholder: "Write your ultimate vision...",
                showError: shouldHighlightStepValidation && isVisionInvalid
            )
            .focused($focusedField, equals: .vision)

            VStack(alignment: .leading, spacing: 6) {
                if !autoWriteVisionSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(autoWriteVisionSuggestions, id: \.self) { suggestion in
                            let isApplied = normalizedVisionSuggestion(visionTrimmed) == normalizedVisionSuggestion(suggestion)
                            Button {
                                visionText = suggestion
                                autoWriteMemory.recordVisionAccepted(suggestion)
                                autoWriteMemory.persist()
                                lastAppliedVisionSuggestion = suggestion
                                trackedEditForLastAppliedVision = false
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image("LoomAI")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                        .padding(.top, 1)
                                    Text(suggestion)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                        .multilineTextAlignment(.leading)
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isApplied)
                        }
                    }
                }

                if let error = autoWriteVisionErrorMessage {
                    purposeRetryRow(
                        message: error,
                        troubleshooting: autoWriteVisionTroubleshootingMessage,
                        buttonTitle: "Try again"
                    ) {
                        Task { await requestAutoWriteVisionSuggestions(forceRefresh: true) }
                    }
                } else if !hasPersonalizationSnapshot {
                    Text("Suggestions are less personalized until you complete Account -> Personalization.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedIdeasVision.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need ideas?")
                        Image(systemName: showNeedIdeasVision ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedIdeasVision {
                    VStack(alignment: .leading, spacing: 6) {
                        Text("• Who do I want to become?")
                        Text("• What experiences do I want to have?")
                        Text("• What impact do I want to make?")
                        Text("Example:")
                            .font(.subheadline.weight(.semibold))
                            .padding(.top, 4)
                        Text("\"I live a life of purpose, growth, and freedom. I build meaningful work that creates value for others while giving me time, financial independence, and the ability to choose how I live. I am healthy, energized, and surrounded by strong relationships, and I continue to learn, lead, and make a positive impact.\"")
                            .italic()
                            .lineLimit(nil)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private var passionsStep: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isPassionsInvalid {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.subheadline)
                        .foregroundStyle(Color.black.opacity(0.7))
                        .padding(.top, 1)
                    Text("Please add at least 2 items per Passion. You can always edit and improve later.")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color.black.opacity(0.7))
                        .multilineTextAlignment(.leading)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 10)
                        .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
                )
            }

            ForEach(bucketOrder, id: \.key) { bucket in
                let shouldOutlineBucket = shouldHighlightStepValidation && invalidPassionKeys.contains(bucket.key)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Text(bucket.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.primary)
                        Spacer(minLength: 8)
                        Text(passionPrompt(for: bucket.key))
                            .italic()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if addingPassionBuckets.contains(bucket.key) {
                        TextField("Add \(bucket.title)", text: bindingForBucketEntry(bucket.key))
                            .focused($focusedField, equals: .passion(bucket.key))
                            .textInputAutocapitalization(.sentences)
                            .autocorrectionDisabled(false)
                            .submitLabel(.done)
                            .onSubmit {
                                savePassionEntry(bucket.key)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    } else {
                        Button {
                            addingPassionBuckets = [bucket.key]
                            entryText[bucket.key] = ""
                            focusedField = .passion(bucket.key)
                        } label: {
                            HStack(spacing: 0) {
                                Text("+ Add \(bucket.title)")
                                Spacer(minLength: 0)
                            }
                            .contentShape(Rectangle())
                        }
                        .foregroundStyle(.blue)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    }

                    let values = draftPassions[bucket.key] ?? []
                    ForEach(Array(values.enumerated()), id: \.offset) { index, value in
                        let selectionCount = passionSelectionCount(for: value, in: bucket.key)
                        HStack(spacing: 10) {
                            Text(value)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            Text("\(selectionCount)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                                .monospacedDigit()
                            Button {
                                deletePassions(at: IndexSet(integer: index), in: bucket.key)
                            } label: {
                                Image(systemName: "minus.circle.fill")
                                    .foregroundStyle(.red)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .background(bucketValidationRowBackground(isInvalid: shouldOutlineBucket))
                    }
                }
                .padding(10)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
            }

            VStack(alignment: .leading, spacing: 6) {
                if !autoWritePassionSuggestions.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        ForEach(autoWritePassionSuggestions) { suggestion in
                            let isApplied = isPassionSuggestionApplied(suggestion)
                            Button {
                                applyAutoWritePassionSuggestion(suggestion)
                            } label: {
                                HStack(alignment: .top, spacing: 10) {
                                    Image("LoomAI")
                                        .resizable()
                                        .renderingMode(.template)
                                        .scaledToFit()
                                        .frame(width: 16, height: 16)
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                        .padding(.top, 1)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(bucketTitle(for: suggestion.emotion))
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(0.85))
                                        Text(suggestion.passion)
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                            .multilineTextAlignment(.leading)
                                    }
                                    Spacer(minLength: 0)
                                }
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                                        .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                                )
                            }
                            .buttonStyle(.plain)
                            .disabled(isApplied)
                        }
                    }
                }

                if let error = autoWritePassionsErrorMessage {
                    purposeRetryRow(
                        message: error,
                        troubleshooting: autoWritePassionsTroubleshootingMessage,
                        buttonTitle: "Try again"
                    ) {
                        Task { await requestAutoWritePassionSuggestions(forceRefresh: true) }
                    }
                } else if !hasPersonalizationSnapshot {
                    Text("Add Personalization in Account for more tailored Passion suggestions.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        showNeedIdeasPassions.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Text("Need ideas?")
                        Image(systemName: showNeedIdeasPassions ? "chevron.up" : "chevron.down")
                            .font(.caption2.weight(.semibold))
                    }
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)

                if showNeedIdeasPassions {
                    VStack(alignment: .leading, spacing: 10) {
                        passionIdeasGroup(
                            title: "Love",
                            items: [
                                "Time with family and close relationships",
                                "Learning, growth, and self-improvement",
                                "Building and creating something meaningful"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Vows (Commitments)",
                            items: [
                                "Always act with integrity",
                                "Take full responsibility for my life",
                                "Keep growing and becoming better"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Thrill (Excitement)",
                            items: [
                                "Achieving difficult goals",
                                "Solving hard problems",
                                "Taking risks and pursuing new opportunities"
                            ]
                        )
                        passionIdeasGroup(
                            title: "Hate",
                            items: [
                                "Wasted potential",
                                "Dishonesty and manipulation",
                                "Laziness and excuses"
                            ]
                        )
                    }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(10)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                    .padding(.top, 2)
                }
            }
            .padding(10)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
        }
        .padding(14)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func passionIdeasGroup(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.subheadline.weight(.semibold))
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
            }
        }
    }

    private func bucketValidationRowBackground(isInvalid: Bool) -> some View {
        RoundedRectangle(cornerRadius: 10, style: .continuous)
            .fill(rowSurfaceColor)
            .overlay(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .stroke(isInvalid ? Color.red.opacity(0.82) : Color.clear, lineWidth: isInvalid ? 1.6 : 0)
            )
    }

    private var summaryStep: some View {
        VStack(alignment: .leading, spacing: 12) {
            summaryCard(title: "Vision", body: visionTrimmed, onEdit: {
                step = .vision
            })

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Passions")
                        .font(.headline)
                    Spacer()
                    Button("Edit") {
                        step = .passions
                    }
                    .font(.caption.weight(.semibold))
                }
                ForEach(bucketOrder, id: \.key) { bucket in
                    let items = draftPassions[bucket.key] ?? []
                    VStack(alignment: .leading, spacing: 4) {
                        Text(bucket.title)
                            .font(.subheadline.weight(.semibold))
                        if items.isEmpty {
                            Text("No items added.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            VStack(alignment: .leading, spacing: 3) {
                                ForEach(items, id: \.self) { item in
                                    Text("• \(item)")
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                }
                            }
                        }
                    }
                    .padding(10)
                    .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 10))
                }
            }
            .padding(12)
            .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
        }
    }

    private var insightsStep: some View {
        Group {
            if AppleIntelligenceSupport.isAvailable {
                VStack(alignment: .leading, spacing: 12) {
                    PurposeInsightsThinkingHeader(
                        title: "LoomAI",
                        progress: 1.0
                    )

                    if !(isGeneratingPurposeInsights && purposeInsightCards.isEmpty) {
                        Text("This will personalize your Loom experience.")
                            .font(.title3.weight(.medium))
                            .foregroundStyle(.secondary)
                    }

                    Text(purposeInsightHeadingText)
                        .font(.system(size: 38, weight: .bold))
                        .fixedSize(horizontal: false, vertical: true)

                    Group {
                        if isGeneratingPurposeInsights && purposeInsightCards.isEmpty {
                            ForEach(0..<1, id: \.self) { _ in
                                purposeInsightsLoadingCard
                            }
                            .transition(.opacity)
                        } else {
                            ForEach(purposeInsightCards) { card in
                                purposeInsightsCard(card, animateOutline: animatePurposeInsightOutline)
                            }
                            .transition(.opacity.combined(with: .move(edge: .bottom)))
                        }
                    }
                    .animation(.easeInOut(duration: 0.24), value: isGeneratingPurposeInsights)
                    .animation(.easeInOut(duration: 0.24), value: purposeInsightCards.count)

                    Text("This may change overtime and with different data. View anytime in Account > Personalization")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(14)
                .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
                .onAppear {
                    if autoWriteOutlineAngle == 0 {
                        withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                            autoWriteOutlineAngle = 360
                        }
                    }
                    if insightsOutlinePhase == 0 {
                        withAnimation(.linear(duration: 2.1).repeatForever(autoreverses: false)) {
                            insightsOutlinePhase = 1
                        }
                    }
                }
            } else {
                EmptyView()
            }
        }
    }

    private func purposeRetryRow(
        message: String,
        troubleshooting: String? = nil,
        buttonTitle: String,
        action: @escaping () -> Void
    ) -> some View {
        let hasTroubleshooting = loomAITroubleshootingEnabled && !(troubleshooting ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top, spacing: 8) {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer(minLength: 6)
                HStack(spacing: 10) {
                    Button(buttonTitle, action: action)
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                }
            }

            if hasTroubleshooting, let troubleshooting {
                LoomAITroubleshootingSection(details: troubleshooting)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
    }

    private var bottomCopyTroubleshootingDetails: String? {
        guard loomAITroubleshootingEnabled else { return nil }
        return [
            autoWriteVisionTroubleshootingMessage,
            autoWritePassionsTroubleshootingMessage
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty })
    }

    private var shouldShowBottomTroubleshootingPending: Bool {
        guard loomAITroubleshootingEnabled else { return false }
        guard bottomCopyTroubleshootingDetails == nil else { return false }
        let hasError = [
            autoWriteVisionErrorMessage,
            autoWritePassionsErrorMessage
        ]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .contains { !$0.isEmpty }
        return hasError
    }

    private var purposeInsightHeadingText: String {
        let profile = purposeInsightProfileName.trimmingCharacters(in: .whitespacesAndNewlines)
        return profile.isEmpty ? "How Loom sees you (so far)..." : profile
    }

    private func purposeInsightsCard(_ card: PurposeInsightCard, animateOutline: Bool) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(card.title)
                .font(.caption.weight(.bold))
                .textCase(.uppercase)
                .foregroundStyle(.secondary)
                .tracking(0.45)
            if let body = card.body {
                Text(body)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            } else if let signals = card.signals {
                VStack(alignment: .leading, spacing: 8) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Stress trigger")
                            .italic()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(signals.stressTrigger)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Breaking point")
                            .italic()
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                        Text(signals.breakingPoint)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(autoWriteGradient.opacity(0.68), lineWidth: 1.2)

                if animateOutline {
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .trim(from: insightsOutlinePhase, to: min(insightsOutlinePhase + 0.22, 1))
                        .stroke(autoWriteGradient, style: StrokeStyle(lineWidth: 1.8, lineCap: .round))
                }
            }
        )
    }

    private var purposeInsightsLoadingCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.22))
                .frame(width: 140, height: 11)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.16))
                .frame(height: 12)
            RoundedRectangle(cornerRadius: 4, style: .continuous)
                .fill(Color.secondary.opacity(0.14))
                .frame(height: 12)
        }
        .redacted(reason: .placeholder)
        .padding(.horizontal, 12)
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .stroke(autoWriteGradient.opacity(0.35), lineWidth: 1)
        )
    }

    private struct PurposeInsightsThinkingHeader: View {
        let title: String
        let progress: Double

        @State private var shineOffset: CGFloat = -0.7

        private static let gradientTokens: [Color] = [
            Color(red: 0.22, green: 0.47, blue: 1.0),
            Color(red: 0.15, green: 0.83, blue: 0.95),
            Color(red: 0.62, green: 0.40, blue: 0.95),
            Color(red: 0.80, green: 0.38, blue: 0.78),
            Color(red: 0.98, green: 0.36, blue: 0.58),
            Color(red: 0.22, green: 0.47, blue: 1.0)
        ]

        var body: some View {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 18, height: 18)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                GeometryReader { proxy in
                    let fullWidth = max(1, proxy.size.width)
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.secondary.opacity(0.16))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(
                                LinearGradient(
                                    colors: Self.gradientTokens,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: fullWidth * max(0, min(1, progress)))

                        RoundedRectangle(cornerRadius: 8, style: .continuous)
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
                            .frame(width: fullWidth * 0.35)
                            .offset(x: fullWidth * shineOffset)
                    }
                }
                .frame(height: 12)
            }
            .onAppear {
                withAnimation(.linear(duration: 1.8).repeatForever(autoreverses: false)) {
                    shineOffset = 1.2
                }
            }
        }
    }

    private func summaryCard(title: String, body: String, onEdit: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
                Button("Edit", action: onEdit)
                    .font(.caption.weight(.semibold))
            }
            Text(body.isEmpty ? "Not set" : body)
                .foregroundStyle(body.isEmpty ? .secondary : .primary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func multiLineEditor(text: Binding<String>, placeholder: String, showError: Bool = false) -> some View {
        TextField(placeholder, text: text, axis: .vertical)
            .font(.system(size: 19))
            .textInputAutocapitalization(.sentences)
            .autocorrectionDisabled(false)
            .lineLimit(2...10)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(minHeight: 88, alignment: .topLeading)
            .background(editorSurfaceColor, in: RoundedRectangle(cornerRadius: 12))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .stroke(showError ? Color.red.opacity(0.8) : Color(.separator).opacity(0.5), lineWidth: showError ? 1.6 : 1)
            )
    }

    private func passionBucketSection(_ bucketKey: String, title: String) -> some View {
        let values = draftPassions[bucketKey] ?? []
        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.headline)
                Spacer()
            }

            if addingPassionBuckets.contains(bucketKey) {
                TextField("New \(title)", text: bindingForBucketEntry(bucketKey))
                    .focused($focusedField, equals: .passion(bucketKey))
                    .textInputAutocapitalization(.sentences)
                    .autocorrectionDisabled(false)
                    .submitLabel(.done)
                    .onSubmit {
                        savePassionEntry(bucketKey)
                    }
            } else {
                Button("+ New \(title)") {
                    addingPassionBuckets = [bucketKey]
                    entryText[bucketKey] = ""
                    focusedField = .passion(bucketKey)
                }
                .foregroundStyle(.blue)
            }

            if values.isEmpty {
                EmptyView()
            } else {
                FlowChips(
                    values: values,
                    onDelete: { value in
                        removeChip(value, from: bucketKey)
                    }
                )
            }
        }
        .padding(12)
        .background(Color(.systemGroupedBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func bindingForBucketEntry(_ key: String) -> Binding<String> {
        Binding(
            get: { entryText[key] ?? "" },
            set: { entryText[key] = $0 }
        )
    }

    func missingCount(_ items: [String], minimum: Int = 2) -> Int {
        max(0, minimum - sanitizedUnique(items).count)
    }

    private func sanitizedUnique(_ items: [String]) -> [String] {
        var seen = Set<String>()
        var out: [String] = []
        for raw in items {
            let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            let key = trimmed.lowercased()
            if seen.insert(key).inserted {
                out.append(trimmed)
            }
        }
        return out
    }

    private func addChip(from bucketKey: String) {
        let raw = entryText[bucketKey] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var current = draftPassions[bucketKey] ?? []
        let duplicate = current.contains { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == trimmed.lowercased() }
        guard !duplicate else {
            triggerHint("Duplicate in \(bucketTitle(for: bucketKey))")
            return
        }
        current.append(trimmed)
        draftPassions[bucketKey] = current
        entryText[bucketKey] = ""

        // Same persistence pattern as PurposeView.commitPassion
        let passion = Passion(date: .now, emotion: bucketKey, passion: trimmed)
        context.insert(passion)
        try? context.save()
    }

    private func savePassionEntry(_ bucketKey: String) {
        let raw = entryText[bucketKey] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingPassionBuckets.remove(bucketKey)
            entryText[bucketKey] = ""
            return
        }
        addChip(from: bucketKey)
        addingPassionBuckets.remove(bucketKey)
        focusedField = nil
    }

    private func savePassionEntryFromKeyboard(_ bucketKey: String) {
        let raw = entryText[bucketKey] ?? ""
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        addChip(from: bucketKey)
        addingPassionBuckets = [bucketKey]
        focusedField = .passion(bucketKey)
    }

    private func removeChip(_ value: String, from bucketKey: String) {
        var current = draftPassions[bucketKey] ?? []
        guard let idx = current.firstIndex(where: { $0.caseInsensitiveCompare(value) == .orderedSame }) else { return }
        let removed = current.remove(at: idx)
        draftPassions[bucketKey] = current

        // Same persistence pattern as PurposeView.deletePassion
        if let model = passions.first(where: {
            $0.emotion == bucketKey &&
            $0.passion.caseInsensitiveCompare(removed) == .orderedSame
        }) {
            let archive = PassionArchive(
                date: model.date,
                emotion: model.emotion,
                passionSnapshot: model.passion,
                archivedAt: .now
            )
            context.insert(archive)
            RecentlyDeletedStore.trash(model, in: context)
            try? context.save()
        }
    }

    private func deletePassions(at offsets: IndexSet, in bucketKey: String) {
        let values = draftPassions[bucketKey] ?? []
        for index in offsets {
            guard values.indices.contains(index) else { continue }
            removeChip(values[index], from: bucketKey)
        }
    }

    private func passionSelectionCount(for passionText: String, in emotionKey: String) -> Int {
        let matchingPassionIDs = Set(
            passions
                .filter {
                    $0.emotion == emotionKey &&
                    $0.passion.caseInsensitiveCompare(passionText) == .orderedSame
                }
                .map(\.passion_id)
        )
        guard !matchingPassionIDs.isEmpty else { return 0 }
        return Set(
            passionJoins
                .filter { matchingPassionIDs.contains($0.passion_id) }
                .map(\.category_id)
        ).count
    }

    private func advanceFromCurrentStep() {
        switch step {
        case .vision:
            step = .passions
        case .purpose:
            step = .passions
        case .passions:
            // Do not gate on passions step itself.
            step = .summary
        default:
            break
        }
    }

    private func finalizeAndContinue() {
        guard summaryCanSave else {
            triggerHint("Please complete all required items.")
            return
        }

        saveVisionIfChanged()
        dismiss()
    }

    private func loadFromPersistentData() {
        if let existing = currentDrivingForce {
            visionText = existing.ultimateVision
            purposeText = existing.ultimatePurpose
        }

        var grouped: [String: [String]] = [
            "love": [],
            "vows": [],
            "thrill": [],
            "just": []
        ]
        for item in passions {
            guard grouped[item.emotion] != nil else { continue }
            let trimmed = item.passion.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { continue }
            if !(grouped[item.emotion] ?? []).contains(where: { $0.caseInsensitiveCompare(trimmed) == .orderedSame }) {
                grouped[item.emotion, default: []].append(trimmed)
            }
        }
        draftPassions = grouped
    }

    private func saveVisionIfChanged() {
        let now = Date()
        let trimmed = visionTrimmed
        let purposeTrimmed = purposeText.trimmingCharacters(in: .whitespacesAndNewlines)
        if let existing = currentDrivingForce {
            let resolvedPurpose = purposeTrimmed.isEmpty ? (existing.ultimatePurpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? trimmed : existing.ultimatePurpose) : purposeTrimmed
            guard existing.ultimateVision != trimmed || existing.ultimatePurpose != resolvedPurpose else { return }
            // Same archive/write pattern as PurposeView.saveEditorChanges(.vision)
            context.insert(
                DrivingForceArchive(
                    visionSnapshot: existing.ultimateVision,
                    purposeSnapshot: existing.ultimatePurpose,
                    updatedAt: existing.updatedAt,
                    archivedAt: now
                )
            )
            existing.ultimateVision = trimmed
            existing.ultimatePurpose = resolvedPurpose
            existing.updatedAt = now
        } else {
            let resolvedPurpose = purposeTrimmed.isEmpty ? trimmed : purposeTrimmed
            context.insert(
                DrivingForce(
                    ultimateVision: trimmed,
                    ultimatePurpose: resolvedPurpose,
                    updatedAt: now
                )
            )
        }
        try? context.save()
    }

    private func bucketTitle(for key: String) -> String {
        bucketOrder.first(where: { $0.key == key })?.title ?? key.capitalized
    }

    private func passionPrompt(for key: String) -> String {
        switch key {
        case "love": return "What do I love?"
        case "vows": return "What am I committed to?"
        case "thrill": return "What excites me?"
        case "just": return "What do I refuse to tolerate (hate)?"
        default: return ""
        }
    }

    private func triggerHint(_ text: String) {
        hintWorkItem?.cancel()
        validationHintText = text
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.6, execute: work)
    }

    private func triggerStepValidationFeedback() {
        hintWorkItem?.cancel()
        shouldHighlightStepValidation = true
        invalidPassionKeys = Set(missingPassionKeys)

        switch step {
        case .vision:
            validationHintText = "Please complete your Vision"
        case .purpose:
            validationHintText = "Please add your Passions"
        case .passions:
            validationHintText = "Please add at least 2 items in each Passion category"
        default:
            validationHintText = "Please complete required fields"
        }

        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = true
        }

        let work = DispatchWorkItem {
            shouldHighlightStepValidation = false
            invalidPassionKeys = []
            withAnimation(.easeInOut(duration: 0.15)) {
                showValidationHint = false
            }
        }
        hintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private func clearStepValidationIfResolved() {
        guard showValidationHint || shouldHighlightStepValidation else { return }
        guard !isNextDisabled else { return }
        hintWorkItem?.cancel()
        shouldHighlightStepValidation = false
        invalidPassionKeys = []
        withAnimation(.easeInOut(duration: 0.15)) {
            showValidationHint = false
        }
    }

    private var autoWriteGradient: AngularGradient {
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
            angle: .degrees(autoWriteOutlineAngle)
        )
    }

    private var autoWriteSuggestionCardFill: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.22, green: 0.47, blue: 1.0),
                Color(red: 0.62, green: 0.40, blue: 0.95),
                Color(red: 0.98, green: 0.36, blue: 0.58)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionBackgroundFill(isApplied: Bool) -> AnyShapeStyle {
        if isApplied {
            if colorScheme == .dark {
                return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.34))
            } else {
                return AnyShapeStyle(Color(red: 0.90, green: 0.97, blue: 0.92))
            }
        }
        return AnyShapeStyle(autoWriteSuggestionCardFill.opacity(0.92))
    }

    private func autoWriteSuggestionBorderColor(isApplied: Bool) -> Color {
        if isApplied {
            return colorScheme == .dark ? Color.white.opacity(0.18) : Color.green.opacity(0.30)
        }
        return Color.white.opacity(0.24)
    }

    private var visionAutoWriteControls: some View {
        let isLoading = isAutoWritingVision
        return VStack(alignment: .trailing, spacing: 8) {
            Button {
                guard !isLoading else { return }
                Task { await requestAutoWriteVisionSuggestions(forceRefresh: true) }
            } label: {
                HStack(spacing: 6) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 27, height: 27)
                        .rotation3DEffect(
                            .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                            axis: (x: 1, y: 0, z: 0)
                        )
                    Text("AutoWrite")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(autoWriteGradient)
                }
                .padding(.horizontal, 15)
                .padding(.vertical, 9)
                .background(
                    Capsule()
                        .fill(Color(.systemGroupedBackground))
                )
                .overlay(
                    Capsule()
                        .stroke(autoWriteGradient, lineWidth: 2.25)
                )
            }
            .buttonStyle(.plain)
            .disabled(isLoading)
            .opacity(isLoading ? 0.7 : 1)
            .onAppear {
                guard autoWriteOutlineAngle == 0 else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    autoWriteOutlineAngle = 360
                }
            }
            .onChange(of: isLoading, initial: false) { _, newValue in
                setAutoWriteLoadingAnimation(newValue)
            }
        }
        .frame(height: autoWritePillHeight)
    }

    private var passionsAutoWriteControls: some View {
        let isLoading = isAutoWritingPassions
        return VStack(alignment: .trailing, spacing: 8) {
            ZStack(alignment: .trailing) {
                Button {
                    guard !isLoading else { return }
                    Task { await requestAutoWritePassionSuggestions(forceRefresh: true) }
                } label: {
                    HStack(alignment: .top, spacing: 6) {
                        Image("LoomAI")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 27, height: 27)
                            .rotation3DEffect(
                                .degrees(isLoading && autoWriteIconAnimating ? 180 : 0),
                                axis: (x: 1, y: 0, z: 0)
                            )
                        VStack(alignment: .leading, spacing: 0.5) {
                            Text("AutoWrite")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(autoWriteGradient)
                            Text(selectedPassionAutoWriteFilter.label)
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                        .padding(.top, 0.5)
                        Spacer(minLength: 0)
                    }
                    .padding(.leading, 12)
                    .padding(.trailing, 42)
                    .padding(.vertical, 8)
                }
                .buttonStyle(.plain)
                .disabled(isLoading)
                .opacity(isLoading ? 0.7 : 1)

                Menu {
                    ForEach(passionAutoWriteFilterOptionsReversed) { filter in
                        Button {
                            selectedPassionAutoWriteFilter = filter
                        } label: {
                            if selectedPassionAutoWriteFilter == filter {
                                Label(filter.label, systemImage: "checkmark")
                            } else {
                                Text(filter.label)
                            }
                        }
                    }
                } label: {
                    Image(systemName: "chevron.up.chevron.down")
                        .font(.caption.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 27, height: 27)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .frame(width: 27, height: 27)
                .padding(.trailing, 8)
            }
            .background(
                Capsule()
                    .fill(Color(.systemGroupedBackground))
            )
            .overlay(
                Capsule()
                    .stroke(autoWriteGradient, lineWidth: 2.25)
            )
            .fixedSize(horizontal: true, vertical: false)
            .onAppear {
                guard autoWriteOutlineAngle == 0 else { return }
                withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                    autoWriteOutlineAngle = 360
                }
            }
            .onChange(of: isLoading, initial: false) { _, newValue in
                setAutoWriteLoadingAnimation(newValue)
            }
        }
    }

    private struct PurposeVisionAutoWriteResponse: Decodable {
        let suggestions: [String]?
        let confidence: String?
    }

    private struct PurposePassionsAutoWriteResponse: Decodable {
        struct Suggestion: Decodable {
            let emotion: String?
            let passion: String?
            let text: String?
            let bucket: String?
        }
        let suggestions: [Suggestion]?
        let confidence: String?
    }

    private func requestAutoWriteVisionSuggestions(forceRefresh: Bool = false) async {
        let requestKey = visionAutoWriteCacheKey
        if !forceRefresh, autoWriteVisionLoadedKeys.contains(requestKey) {
            return
        }
        autoWriteVisionLoadedKeys.insert(requestKey)
        let markFailed = { _ = autoWriteVisionLoadedKeys.remove(requestKey) }

        let previousSuggestions = autoWriteVisionSuggestions
        autoWriteVisionErrorMessage = nil
        autoWriteVisionTroubleshootingMessage = nil
        isAutoWritingVision = true
        defer { isAutoWritingVision = false }
        if forceRefresh {
            autoWriteVisionSuggestions = []
        }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: context)
            let effectivePreviousSuggestions = visionTrimmed.isEmpty ? [] : previousSuggestions
            let response = try await LoomAIService().sendPurposeVisionAutoWrite(
                currentVision: visionTrimmed,
                previousSuggestions: effectivePreviousSuggestions,
                mode: "newVision",
                context: contextSnapshot,
                requestHash: requestKey
            )
            let suggestions = decodeAutoWriteVisionSuggestions(from: response.message)
            guard !suggestions.isEmpty else {
                autoWriteVisionErrorMessage = "No suggestions yet."
                autoWriteVisionTroubleshootingMessage = loomAITroubleshootingLocalDetails(
                    feature: "purpose_start_autowrite_vision",
                    reason: "No suggestions were returned in the response.",
                    responsePreview: response.message,
                    requestHash: requestKey
                )
                markFailed()
                return
            }
            let nextSuggestions = Array(suggestions.prefix(2))
            guard !nextSuggestions.isEmpty else {
                autoWriteVisionErrorMessage = "No new suggestions yet."
                let duplicateDetails = loomAIDuplicateSuggestionTroubleshootingDetails(
                    feature: "purpose_start_autowrite_vision",
                    reason: "No usable suggestions were returned after parsing.",
                    responsePreview: response.message,
                    requestHash: requestKey
                )
                autoWriteVisionTroubleshootingMessage = duplicateDetails
                loomAIReportTroubleshootingIfEnabled(details: duplicateDetails)
                markFailed()
                return
            }
            autoWriteVisionSuggestions = nextSuggestions
            autoWriteVisionErrorMessage = nil
            autoWriteVisionTroubleshootingMessage = nil
        } catch {
            autoWriteVisionErrorMessage = "Couldn’t generate Vision suggestions. Check your connection."
            autoWriteVisionTroubleshootingMessage = loomAITroubleshootingDetails(
                feature: "purpose_start_autowrite_vision",
                error: error,
                requestHash: requestKey
            )
            markFailed()
        }
    }

    private func requestAutoWritePassionSuggestions(forceRefresh: Bool = false) async {
        let requestKey = passionsAutoWriteCacheKey
        if !forceRefresh, let cached = autoWritePassionSuggestionsCache[requestKey], !cached.isEmpty {
            autoWritePassionSuggestions = cached
            autoWritePassionsErrorMessage = nil
            autoWritePassionsTroubleshootingMessage = nil
            return
        }
        if !forceRefresh, autoWritePassionsLoadedKeys.contains(requestKey) {
            return
        }
        autoWritePassionsLoadedKeys.insert(requestKey)
        let markFailed = { _ = autoWritePassionsLoadedKeys.remove(requestKey) }

        autoWritePassionsErrorMessage = nil
        autoWritePassionsTroubleshootingMessage = nil
        isAutoWritingPassions = true
        defer { isAutoWritingPassions = false }
        if forceRefresh || autoWritePassionSuggestionsCache[requestKey] == nil {
            autoWritePassionSuggestions = []
        }
        let delayNanos = UInt64.random(in: 2_000_000_000...5_000_000_000)
        try? await Task.sleep(nanoseconds: delayNanos)
        guard !Task.isCancelled else {
            markFailed()
            return
        }

        let existingByEmotion = Dictionary(uniqueKeysWithValues: bucketOrder.map { bucket in
            var items = draftPassions[bucket.key] ?? []
            let pendingInput = (entryText[bucket.key] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !pendingInput.isEmpty {
                items.append(pendingInput)
            }
            return (bucket.key, items)
        })
        let selectedEmotion = selectedPassionAutoWriteFilter == .all ? nil : selectedPassionAutoWriteFilter.rawValue
        let generated = PassionAutoWriteSuggestionTable.pickSuggestions(
            filterEmotion: selectedEmotion,
            existingByEmotion: existingByEmotion,
            singleBucketCount: 2
        )
        let resolvedSuggestions = generated.map { AutoWritePassionSuggestion(emotion: $0.emotion, passion: $0.passion) }

        guard !resolvedSuggestions.isEmpty else {
            autoWritePassionsErrorMessage = "No suggestions yet."
            autoWritePassionsTroubleshootingMessage = loomAITroubleshootingLocalDetails(
                feature: "purpose_start_autowrite_passions",
                reason: "No local table suggestions were available after filtering currently selected passions.",
                requestHash: requestKey
            )
            markFailed()
            return
        }

        autoWritePassionSuggestions = resolvedSuggestions
        autoWritePassionSuggestionsCache[requestKey] = resolvedSuggestions
        autoWritePassionsErrorMessage = nil
        autoWritePassionsTroubleshootingMessage = nil
    }

    private func generatePurposeInsights(forceRefresh: Bool = false) async {
        guard AppleIntelligenceSupport.isAvailable else {
            purposeInsightCards = []
            purposeInsightProfileName = ""
            purposeInsightsTroubleshootingMessage = nil
            loadedPurposeInsightsCycleKey = nil
            hasTimedOutPurposeInsights = false
            return
        }
        guard let personalizationSnapshot else {
            purposeInsightCards = []
            purposeInsightProfileName = ""
            return
        }

        let diagnostics = DiagnosticAnswers(snapshot: personalizationSnapshot)
        let currentVision = visionTrimmed.isEmpty
            ? currentDrivingForce?.ultimateVision.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            : visionTrimmed
        let passions = currentPassionPhrasesForProfileInsights()
        let userKey = PersonalizationUserIdentity.currentUserKey()
        let monthKey = PurposeProfileInsightsHasher.monthKey()
        let cycleKey = "\(userKey)|\(monthKey)"
        if !forceRefresh,
           loadedPurposeInsightsCycleKey == cycleKey,
           !purposeInsightCards.isEmpty {
            return
        }
        if !forceRefresh,
           let stored = latestPurposeProfileSnapshot(for: userKey),
           stored.monthKey == monthKey {
            applyPurposeInsightSnapshot(stored)
            loadedPurposeInsightsCycleKey = cycleKey
            return
        }

        isGeneratingPurposeInsights = true
        if purposeInsightCards.isEmpty {
            purposeInsightCards = []
            purposeInsightProfileName = ""
            animatePurposeInsightOutline = false
        }
        defer {
            isGeneratingPurposeInsights = false
        }
        guard !Task.isCancelled else { return }
        let inputsHash = PurposeProfileInsightsHasher.hash(
            diagnostic: diagnostics,
            vision: currentVision,
            passions: passions
        )

        do {
            let resolved = try await AppleIntelligencePurposeInsightsGenerator.purposeProfile(
                diagnostic: diagnostics,
                vision: currentVision,
                passions: passions
            )
            guard !Task.isCancelled else { return }
            persistPurposeProfileSnapshot(
                record: resolved,
                userKey: userKey,
                monthKey: monthKey,
                inputsHash: inputsHash
            )
            purposeInsightsTroubleshootingMessage = nil
            applyPurposeInsightRecord(resolved)
            loadedPurposeInsightsCycleKey = cycleKey
        } catch {
            purposeInsightsTroubleshootingMessage = loomAITroubleshootingDetails(
                feature: "purpose_start_insights_profile",
                error: error
            )
            if let stored = latestPurposeProfileSnapshot(for: userKey) {
                applyPurposeInsightSnapshot(stored)
                loadedPurposeInsightsCycleKey = cycleKey
                return
            }
            purposeInsightCards = []
            purposeInsightProfileName = ""
        }
    }

    private func restartPurposeInsightsTimeoutWindow() {
        guard AppleIntelligenceSupport.isAvailable else {
            hasTimedOutPurposeInsights = false
            purposeInsightsTimeoutTask?.cancel()
            return
        }
        hasTimedOutPurposeInsights = false
        purposeInsightsTimeoutTask?.cancel()
        purposeInsightsTimeoutTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard step == .insights else { return }
                guard purposeInsightCards.isEmpty else { return }
                hasTimedOutPurposeInsights = true
                showPurposeInsightsTimeoutAlert = true
            }
        }
    }

    private func handleAutoStartForStep(_ newStep: Step) {
        switch newStep {
        case .vision:
            Task { await requestAutoWriteVisionSuggestions() }
        case .purpose, .passions:
            Task { await requestAutoWritePassionSuggestions() }
        case .insights:
            Task { await generatePurposeInsights() }
        default:
            break
        }
    }

    private var visionAutoWriteCacheKey: String {
        "vision|\(stableHash(personalizationSignature() + "|" + normalizedVisionSuggestion(visionTrimmed)))"
    }

    private var passionsAutoWriteCacheKey: String {
        "passions|\(stableHash(personalizationSignature() + "|" + selectedPassionAutoWriteFilter.rawValue + "|" + draftPassionsSignature()))"
    }

    private func personalizationSignature() -> String {
        guard let snapshot = personalizationSnapshot else { return "none" }
        let parts: [String] = [
            snapshot.createdAt.ISO8601Format(),
            snapshot.stressSource,
            snapshot.breakPoint,
            snapshot.lifeAreasSelected.joined(separator: "|"),
            snapshot.planningReality,
            snapshot.desiredChange
        ]
        return parts.joined(separator: "||")
    }

    private func draftPassionsSignature() -> String {
        bucketOrder
            .map { bucket in
                let values = (draftPassions[bucket.key] ?? [])
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                    .filter { !$0.isEmpty }
                return "\(bucket.key):\(values.joined(separator: ","))"
            }
            .joined(separator: "|")
    }

    private func stableHash(_ raw: String) -> String {
        raw.unicodeScalars.reduce(UInt64(5381)) { acc, scalar in
            ((acc << 5) &+ acc) &+ UInt64(scalar.value)
        }
        .description
    }

    private func applyPurposeInsightRecord(_ record: PurposeProfileRecord) {
        withAnimation(.easeInOut(duration: 0.24)) {
            purposeInsightProfileName = record.profile
            purposeInsightCards = purposeInsightCards(for: record)
        }
    }

    private func purposeInsightCards(for record: PurposeProfileRecord) -> [PurposeInsightCard] {
        [
            PurposeInsightCard(title: "Strength", body: record.strength),
            PurposeInsightCard(title: "Weakness", body: record.weakness),
            PurposeInsightCard(
                title: "Signals",
                signals: .init(
                    stressTrigger: record.stressTrigger,
                    breakingPoint: record.breakingPoint
                )
            )
        ]
    }

    private func currentPassionPhrasesForProfileInsights() -> [String] {
        let byBucket = bucketOrder.flatMap { bucket -> [String] in
            var values = draftPassions[bucket.key] ?? []
            let pending = (entryText[bucket.key] ?? "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
            if !pending.isEmpty {
                values.append(pending)
            }
            return values
        }
        let normalized = byBucket
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return Array(Set(normalized)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func latestDiagnosticsInsightsSnapshot(for personalization: PersonalizationSnapshot?) -> DiagnosticsInsightsSnapshot? {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        if let personalization {
            let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: personalization)
            if let exact = diagnosticsInsightsSnapshots.first(where: {
                $0.userKey == userKey && $0.diagnosticsHash == diagnosticsHash
            }) {
                return exact
            }
        }
        if let latestForUser = diagnosticsInsightsSnapshots.first(where: { $0.userKey == userKey }) {
            return latestForUser
        }
        return diagnosticsInsightsSnapshots.first
    }

    private func latestPurposeProfileSnapshot(for userKey: String) -> PurposeProfileInsightsSnapshot? {
        purposeProfileInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    private func applyPurposeInsightSnapshot(_ snapshot: PurposeProfileInsightsSnapshot) {
        let record = PurposeProfileRecord(
            profile: snapshot.profile,
            strength: snapshot.strength,
            weakness: snapshot.weakness,
            stressTrigger: snapshot.stressTrigger,
            breakingPoint: snapshot.breakingPoint
        )
        applyPurposeInsightRecord(record)
    }

    private func persistPurposeProfileSnapshot(
        record: PurposeProfileRecord,
        userKey: String,
        monthKey: String,
        inputsHash: String
    ) {
        let snapshotKey = PurposeProfileInsightsHasher.snapshotKey(
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash
        )
        if let existing = purposeProfileInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
            existing.generatedAt = .now
            existing.profile = record.profile
            existing.strength = record.strength
            existing.weakness = record.weakness
            existing.stressTrigger = record.stressTrigger
            existing.breakingPoint = record.breakingPoint
            existing.inputsHash = inputsHash
            existing.monthKey = monthKey
            existing.userKey = userKey
        } else {
            context.insert(
                PurposeProfileInsightsSnapshot(
                    snapshotKey: snapshotKey,
                    userKey: userKey,
                    monthKey: monthKey,
                    inputsHash: inputsHash,
                    generatedAt: .now,
                    profile: record.profile,
                    strength: record.strength,
                    weakness: record.weakness,
                    stressTrigger: record.stressTrigger,
                    breakingPoint: record.breakingPoint
                )
            )
        }
        try? context.save()
    }

    private func defaultPurposeInsightRecord(
        stress: String,
        breakPoint: String,
        planning: String,
        desired: String,
        areas: [String],
        vision: String,
        passions: [String]
    ) -> PurposeProfileRecord {
        PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: stress,
                breakPoint: breakPoint,
                planning: planning,
                desired: desired,
                areas: areas,
                vision: vision,
                passions: passions
            )
        )
    }

    private func decodeAutoWritePassionSuggestions(from raw: String) -> [AutoWritePassionSuggestion] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8) {
            if let parsed = try? JSONDecoder().decode(PurposePassionsAutoWriteResponse.self, from: data) {
                return Array((parsed.suggestions ?? [])
                    .compactMap { item in
                        let emotionRaw = item.emotion ?? item.bucket ?? ""
                        guard let emotion = normalizedPassionEmotionKey(emotionRaw) else { return nil }
                        let passionRaw = item.passion ?? item.text ?? ""
                        let passion = normalizedPassionPhrase(passionRaw)
                        guard !passion.isEmpty else { return nil }
                        return AutoWritePassionSuggestion(emotion: emotion, passion: passion)
                    }
                    .prefix(4))
            }
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let map = root["suggestions"] as? [String: Any] {
                let orderedBuckets = ["love", "vows", "thrill", "just"]
                let mapped = orderedBuckets.compactMap { bucket -> AutoWritePassionSuggestion? in
                    let value = (map[bucket] as? String) ?? (map[bucket.uppercased()] as? String)
                    let passion = normalizedPassionPhrase(value ?? "")
                    guard !passion.isEmpty else { return nil }
                    return AutoWritePassionSuggestion(emotion: bucket, passion: passion)
                }
                if !mapped.isEmpty {
                    return mapped
                }
            }
        }

        return Array(trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .compactMap { line -> AutoWritePassionSuggestion? in
                let parts = line.split(separator: ":", maxSplits: 1).map { String($0) }
                guard parts.count == 2, let emotion = normalizedPassionEmotionKey(parts[0]) else { return nil }
                let passion = normalizedPassionPhrase(parts[1])
                guard !passion.isEmpty else { return nil }
                return AutoWritePassionSuggestion(emotion: emotion, passion: passion)
            }
            .prefix(4))
    }

    private func normalizedPassionEmotionKey(_ raw: String) -> String? {
        let key = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        if key.contains("love") { return "love" }
        if key.contains("vow") || key.contains("commit") { return "vows" }
        if key.contains("thrill") || key.contains("excite") { return "thrill" }
        if key.contains("hate") || key.contains("just") { return "just" }
        return nil
    }

    private func normalizedPassionPhrase(_ text: String) -> String {
        let cleaned = text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !cleaned.isEmpty else { return "" }
        let words = cleaned.split(whereSeparator: \.isWhitespace)
        let limited = words.prefix(3).joined(separator: " ")
        return truncateSuggestion(String(limited), maxLength: 60)
    }

    private func isPassionSuggestionApplied(_ suggestion: AutoWritePassionSuggestion) -> Bool {
        let values = draftPassions[suggestion.emotion] ?? []
        let normalizedSuggestion = normalizedVisionSuggestion(suggestion.passion)
        return values.contains { normalizedVisionSuggestion($0) == normalizedSuggestion }
    }

    private func selectPassionSuggestionsForCurrentFilter(
        from suggestions: [AutoWritePassionSuggestion],
        maxCount: Int
    ) -> [AutoWritePassionSuggestion] {
        let ranked = rankPassionSuggestionsForBrevity(suggestions)
        guard selectedPassionAutoWriteFilter == .all else {
            return Array(ranked.prefix(maxCount))
        }
        let orderedBuckets = ["love", "vows", "thrill", "just"]
        var selected: [AutoWritePassionSuggestion] = []
        for bucket in orderedBuckets {
            guard let match = ranked.first(where: { $0.emotion == bucket }) else { continue }
            selected.append(match)
        }
        return selected
    }

    private func rankPassionSuggestionsForBrevity(
        _ suggestions: [AutoWritePassionSuggestion]
    ) -> [AutoWritePassionSuggestion] {
        suggestions.sorted { lhs, rhs in
            let lhsWords = passionSuggestionWordCount(lhs.passion)
            let rhsWords = passionSuggestionWordCount(rhs.passion)
            let lhsOneWordPenalty = lhsWords == 1 ? 0 : 1
            let rhsOneWordPenalty = rhsWords == 1 ? 0 : 1
            if lhsOneWordPenalty != rhsOneWordPenalty {
                return lhsOneWordPenalty < rhsOneWordPenalty
            }
            if lhsWords != rhsWords {
                return lhsWords < rhsWords
            }
            if lhs.passion.count != rhs.passion.count {
                return lhs.passion.count < rhs.passion.count
            }
            return lhs.passion.localizedCaseInsensitiveCompare(rhs.passion) == .orderedAscending
        }
    }

    private func passionSuggestionWordCount(_ text: String) -> Int {
        max(1, text.split(whereSeparator: \.isWhitespace).count)
    }

    private func isPassionSuggestionTooSimilarToExisting(_ suggestion: AutoWritePassionSuggestion) -> Bool {
        var existing = draftPassions[suggestion.emotion] ?? []
        let pending = (entryText[suggestion.emotion] ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            existing.append(pending)
        }
        let suggestionNorm = normalizedVisionSuggestion(suggestion.passion)
        let suggestionTokens = Set(suggestionNorm.split(separator: " ").map(String.init))

        for item in existing {
            let itemNorm = normalizedVisionSuggestion(item)
            if itemNorm.isEmpty { continue }
            if itemNorm == suggestionNorm { return true }
            let itemTokens = Set(itemNorm.split(separator: " ").map(String.init))
            if !itemTokens.isEmpty {
                let overlapCount = suggestionTokens.intersection(itemTokens).count
                let overlapRatio = Double(overlapCount) / Double(max(1, min(suggestionTokens.count, itemTokens.count)))
                if overlapRatio >= 0.75 { return true }
            }
        }
        return false
    }

    private func applyAutoWritePassionSuggestion(_ suggestion: AutoWritePassionSuggestion) {
        guard !isPassionSuggestionApplied(suggestion) else { return }
        var values = draftPassions[suggestion.emotion] ?? []
        values.append(suggestion.passion)
        draftPassions[suggestion.emotion] = values

        let passion = Passion(date: .now, emotion: suggestion.emotion, passion: suggestion.passion)
        context.insert(passion)
        try? context.save()
        autoWriteMemory.recordPassionAccepted(emotion: suggestion.emotion, passion: suggestion.passion)
        autoWriteMemory.persist()
    }

    private func recordVisionEditIfNeeded(newValue: String) {
        guard let applied = lastAppliedVisionSuggestion, !trackedEditForLastAppliedVision else { return }
        let newNormalized = normalizedVisionSuggestion(newValue)
        let appliedNormalized = normalizedVisionSuggestion(applied)
        guard !newNormalized.isEmpty, newNormalized != appliedNormalized else { return }
        autoWriteMemory.recordVisionEdited(newValue)
        autoWriteMemory.persist()
        trackedEditForLastAppliedVision = true
    }

    private func normalizedVisionSuggestion(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func decodeAutoWriteVisionSuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(PurposeVisionAutoWriteResponse.self, from: data) {
            return Array((parsed.suggestions ?? [])
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(3))
        }

        return Array(trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .filter { !$0.isEmpty }
            .prefix(3))
    }

    private func truncateSuggestion(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func setAutoWriteLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimating = false
            autoWriteIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.55)) {
                        autoWriteIconAnimating.toggle()
                    }
                    try? await Task.sleep(for: .milliseconds(550))
                }
            }
        } else {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            var transaction = Transaction()
            transaction.disablesAnimations = true
            withTransaction(transaction) {
                autoWriteIconAnimating = false
            }
        }
    }
}

#Preview {
    NavigationStack {
        PurposeStartView()
    }
    .loomPreviewContainer()
}

private struct FlowChips: View {
    let values: [String]
    var onDelete: ((String) -> Void)? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            ForEach(Array(values.enumerated()), id: \.offset) { _, value in
                SwipeChipPill(text: value) {
                    onDelete?(value)
                }
            }
        }
    }
}

private struct SwipeChipPill: View {
    let text: String
    var onDelete: () -> Void
    @State private var dragX: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            Capsule()
                .fill(Color.red.opacity(0.14))
            Text("Delete")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.red)
                .padding(.trailing, 12)

            HStack(spacing: 8) {
                Text(text)
                    .font(.subheadline)
                    .lineLimit(2)
                Spacer(minLength: 0)
                Image(systemName: "chevron.left")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.systemGroupedBackground), in: Capsule())
            .offset(x: dragX)
            .gesture(
                DragGesture(minimumDistance: 10)
                    .onChanged { value in
                        dragX = min(0, value.translation.width)
                    }
                    .onEnded { value in
                        if value.translation.width < -70 {
                            withAnimation(.easeOut(duration: 0.16)) {
                                dragX = -220
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
                                onDelete()
                            }
                        } else {
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.84)) {
                                dragX = 0
                            }
                        }
                    }
            )
        }
        .frame(maxWidth: .infinity)
        .frame(height: 36)
    }
}

private struct IntroRouteLinesView: View {
    var body: some View {
        PurposeIntroRouteLinesCanvas()
    }
}
