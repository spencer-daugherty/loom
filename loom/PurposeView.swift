import SwiftUI
import SwiftData

fileprivate let loomAIInsightsRefreshToggleDefaultsKey = "loom.enableLoomAIInsightsRefresh"

fileprivate func loomAIInsightsRefreshEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: loomAIInsightsRefreshToggleDefaultsKey)
}

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

@MainActor
fileprivate enum PurposeReadableInsightRuntimeStore {
    private static let defaultsPrefix = "loom.purposeReadableInsight."
    private static var textByKey: [String: String] = [:]

    static func value(for key: String) -> String? {
        if let cached = textByKey[key] { return cached }
        guard let persisted = UserDefaults.standard.string(forKey: defaultsPrefix + key), !persisted.isEmpty else {
            return nil
        }
        textByKey[key] = persisted
        return persisted
    }

    static func set(_ value: String, for key: String) {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        textByKey[key] = trimmed
        UserDefaults.standard.set(trimmed, forKey: defaultsPrefix + key)
    }
}

fileprivate struct PurposeReadableInsightRequestPayload: Codable {
    let isBaseline: Bool
    let passionTypeRaw: String
    let passionTitle: String
    let monthStartISO8601: String
    let score: Double
    let monthScore: Double
    let monthOverMonthDelta: Double?
    let momentum: Double
    let consistency: Double
    let structure: Double
    let structureItemCoverage: Double
    let structureFulfillmentLinkCoverage: Double
    let structureItemCount: Int
    let structureFulfillmentLinkCount: Int
    let outcomes: Double
    let outcomesIncludedInScore: Bool
    let actionBlocks: Double
    let littleWins: Double
    let evidence: Double
    let carryoverPenalty: Double
    let peerAverageScore: Double?
    let peerRank: Int?
    let peerCount: Int?
    let strongestPassion: String?
    let strongestPassionScore: Double?
    let biggestMoverPassion: String?
    let biggestMoverDelta: Double?
    let recentScores: [Double]
    let primaryLever: AppleIntelligenceReadableInsightLeverageAnalysis
}

fileprivate func purposeReadableInsightKey(
    for payload: PurposeReadableInsightRequestPayload,
    contextSignature: String
) -> String {
    "v7|\(AppleIntelligenceInsightPromptBuilder.payloadSignature(payload))|\(contextSignature)"
}

fileprivate func purposeReadableInsightPrompt(
    for payload: PurposeReadableInsightRequestPayload,
    appContextJSON: String
) -> String {
    let payloadJSON = AppleIntelligenceInsightPromptBuilder.encodeJSON(payload)

    return """
    Create a readable insight for one Purpose passion in Loom Purpose Insights.

    Requirements:
    - Use APP_CONTEXT plus the purpose passion insight payload below.
    - Return structured output with:
      - `insight`: one high-value insight sentence, not a recap of obvious values already shown in the UI.
      - `action`: one very short practical call to action the user can do in Loom to improve.
    - Keep the combined text under 220 characters and end each field as a complete sentence.
    - No questions, no filler.
    - Use APP_CONTEXT to understand what Loom tracks, how Purpose connects to Fulfillment, Outcomes, Action Blocks, and Little Wins, and how this insight sits inside the app flow.
    - Do not mention the passion name directly (the UI already shows it).
    - If you reference an insight metric, use the exact label and include the displayed value in parentheses.
    - Use (X%) for percentage-based metrics and score components.
    - If referencing Momentum or Consistency, use the displayed descriptor in parentheses (e.g., Momentum (Improving), Consistency (Stable)).
    - Use these labels verbatim when referenced: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Evidence, Carryover penalty.
    - The payload already includes `primaryLever`, the highest real score-improvement opportunity based on the actual Purpose formula. Base the insight on that lever only.
    - Explain why `primaryLever` matters using `primaryLever.reason`.
    - Turn `primaryLever.recommendedAction` into the practical action sentence.
    - If `primaryLever.metric` is `Structure`, use the structure breakdown fields to explain whether the bigger gap is passion definition or fulfillment links.
    - If `outcomesIncludedInScore` is false, do not describe Outcomes as weak, missing, or the main problem.
    - If `isBaseline` is true, line 1 must explicitly say this is an early baseline month and avoid trend or mover claims.
    - For baseline data, keep the interpretation broad but still practical, centered on the provided `primaryLever`.
    - Do not discuss peer rank, strongest passion, or mover context unless it clearly supports the same primary lever.
    - Do not invent values.
    - Return only structured output.

    Purpose scoring and element guide:
    \(AppleIntelligenceInsightPromptBuilder.purposeFormulaGuide())

    APP_CONTEXT JSON:
    \(appContextJSON)

    Purpose passion insight payload JSON:
    \(payloadJSON)
    """
}

fileprivate func purposeReadableInsightText(from result: AppleIntelligenceReadableInsightResult) -> String {
    [result.insight, result.action]
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
        .joined(separator: "\n\n")
}

fileprivate let purposeReadableInsightUnavailableMessage = "Insight unavailable right now. Try reopening this view in a moment."

fileprivate func purposeReadableInsightFallbackPrompt(
    for payload: PurposeReadableInsightRequestPayload,
    appContextJSON: String
) -> String {
    let payloadJSON = AppleIntelligenceInsightPromptBuilder.encodeJSON(payload)

    return """
    Create a readable Purpose insight for Loom when the primary structured generation failed.

    Requirements:
    - Use APP_CONTEXT plus the purpose passion insight payload below.
    - Return plain text only.
    - Return exactly two short paragraphs separated by one blank line.
    - Paragraph 1 is the insight sentence.
    - Paragraph 2 is the action sentence.
    - Keep the combined text under 220 characters.
    - No bullets, labels, or extra commentary.
    - Do not mention the passion name directly.
    - The payload already includes `primaryLever`, the highest real score-improvement opportunity. Base the insight on that lever only.
    - Use `primaryLever.reason` for the first paragraph and `primaryLever.recommendedAction` for the second paragraph.
    - If this is baseline data only (`isBaseline` is true), say this is an early baseline month and keep the direction broad rather than diagnostic.
    - If `outcomesIncludedInScore` is false, do not describe Outcomes as weak or missing.
    - If you reference a metric, use these exact labels: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Evidence, Carryover penalty.
    - Do not invent facts or values.

    Purpose scoring and element guide:
    \(AppleIntelligenceInsightPromptBuilder.purposeFormulaGuide())

    APP_CONTEXT JSON:
    \(appContextJSON)

    Purpose passion insight payload JSON:
    \(payloadJSON)
    """
}

fileprivate func purposeReadableInsightStoredText(
    from result: AppleIntelligenceReadableInsightResult,
    payload: PurposeReadableInsightRequestPayload
) -> String? {
    let normalized = normalizePurposeReadableInsightMetricReferences(
        purposeReadableInsightText(from: result),
        payload: payload
    )
    let text = limitPurposeReadableInsightText(normalized, maxCharacters: 220)
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    return trimmed.isEmpty ? nil : trimmed
}

fileprivate func limitPurposeReadableInsightText(_ text: String, maxCharacters: Int = 150) -> String {
    let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.count > maxCharacters else { return trimmed }
    let cutoffIndex = trimmed.index(trimmed.startIndex, offsetBy: maxCharacters)
    let prefix = String(trimmed[..<cutoffIndex]).trimmingCharacters(in: .whitespacesAndNewlines)
    if let sentenceEnd = prefix.lastIndex(where: { ".!?".contains($0) }) {
        let sentence = String(prefix[...sentenceEnd]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !sentence.isEmpty { return sentence }
    }
    if let naturalBreak = prefix.lastIndex(where: { ",;:".contains($0) }) {
        let base = String(prefix[..<naturalBreak]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty { return base + "." }
    }
    if let lastSpace = prefix.lastIndex(of: " "), lastSpace > prefix.startIndex {
        let base = String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        if !base.isEmpty { return base + "." }
    }
    return prefix + "."
}

fileprivate func purposeReadableInsightCTAParagraph(_ text: String?) -> String? {
    guard let text else { return nil }
    let parts = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return parts.last
}

fileprivate func purposeReadableInsightMomentumDescriptor(_ value: Double) -> String {
    let v = PassionScoringMath.clamp(value, min: -1, max: 1)
    if abs(v) < 0.12 { return "Stable" }
    return v > 0 ? "Improving" : "Declining"
}

fileprivate func purposeReadableInsightConsistencyDescriptor(_ value: Double) -> String {
    let v = PassionScoringMath.clamp(value, min: 0, max: 1)
    if v >= 0.75 { return "Stable" }
    if v >= 0.4 { return "Mixed" }
    return "Volatile"
}

fileprivate func normalizePurposeReadableInsightMetricReferences(
    _ text: String,
    payload: PurposeReadableInsightRequestPayload
) -> String {
    var output = text
        .replacingOccurrences(of: "acieving", with: "achieving")

    func pct(_ value: Double) -> String {
        "\(Int((PassionScoringMath.clamped01(value) * 100).rounded()))%"
    }

    let replacements: [(label: String, value: String)] = [
        ("Momentum", purposeReadableInsightMomentumDescriptor(payload.momentum)),
        ("Consistency", purposeReadableInsightConsistencyDescriptor(payload.consistency)),
        ("Structure", pct(payload.structure)),
        ("Outcomes", pct(payload.outcomes)),
        ("Action Blocks", pct(payload.actionBlocks)),
        ("Little Wins", pct(payload.littleWins)),
        ("Evidence", pct(payload.evidence)),
        ("Carryover penalty", pct(payload.carryoverPenalty))
    ]

    for item in replacements.sorted(by: { $0.label.count > $1.label.count }) {
        let escaped = NSRegularExpression.escapedPattern(for: item.label)
        let pattern = "(?i)\\b\(escaped)\\b(?:\\s*\\([^\\)]*\\))?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { continue }
        let source = output
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        output = regex.stringByReplacingMatches(
            in: source,
            range: nsRange,
            withTemplate: "\(item.label) (\(item.value))"
        )
    }

    return ensurePurposeReadableInsightCTA(output, payload: payload)
}

fileprivate func isPurposeSingleRecordPayload(_ payload: PurposeReadableInsightRequestPayload) -> Bool {
    payload.recentScores.count <= 1
}

fileprivate func startupPurposeTechnicalLine(payload: PurposeReadableInsightRequestPayload) -> String {
    "Baseline month only, so the clearest near-term lever is \(payload.primaryLever.metric.rawValue) (\(payload.primaryLever.displayValue)). \(payload.primaryLever.reason)"
}

fileprivate func startupPurposePracticalLine(payload: PurposeReadableInsightRequestPayload) -> String {
    normalizePurposeReadableInsightCTALine(payload.primaryLever.recommendedAction)
}

fileprivate func ensurePurposeReadableInsightCTA(
    _ text: String,
    payload: PurposeReadableInsightRequestPayload
) -> String {
    let lines = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    let fallbackCTA = normalizePurposeReadableInsightCTALine(payload.primaryLever.recommendedAction)

    guard let first = lines.first else { return fallbackCTA }
    if lines.count >= 2 {
        let cta = normalizePurposeReadableInsightCTALine(lines[1])
        return cta.isEmpty ? first + "\n\n" + fallbackCTA : first + "\n\n" + cta
    }
    return fallbackCTA.isEmpty ? first : first + "\n\n" + fallbackCTA
}

fileprivate func repairPurposeReadableInsightLineIfNeeded(
    _ text: String,
    payload: PurposeReadableInsightRequestPayload
) -> String {
    let lines = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: false)
        .map(String.init)

    guard let firstRaw = lines.first else { return text }
    let first = firstRaw.trimmingCharacters(in: .whitespacesAndNewlines)
    guard !first.isEmpty else { return text }

    let lower = first.lowercased()
    let shouldReplace =
        lower.contains("score (0.") ||
        (payload.outcomes >= 0.8 && lower.contains("weak outcome")) ||
        (lower.contains("action blocks") && lower.contains("imbalance") && payload.littleWins + 0.12 < payload.actionBlocks)

    guard shouldReplace else { return text }

    let replacement = practicalPurposeInsightLine(payload: payload)
    let remaining = lines.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    return ([replacement] + remaining).joined(separator: "\n")
}

fileprivate func practicalPurposeInsightLine(payload: PurposeReadableInsightRequestPayload) -> String {
    let lever = payload.primaryLever
    return "\(lever.metric.rawValue) (\(lever.displayValue)) is the clearest score lever right now. \(lever.reason)"
}

fileprivate func defaultPurposeReadableInsightCTA(payload: PurposeReadableInsightRequestPayload) -> String {
    normalizePurposeReadableInsightCTALine(payload.primaryLever.recommendedAction)
}

fileprivate func normalizePurposeReadableInsightCTALine(_ line: String) -> String {
    var output = line.trimmingCharacters(in: .whitespacesAndNewlines)
    output = output.replacingOccurrences(of: #"^(?i)in loom,\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(of: #"^(?i)in loom\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(
        of: #"(?i)shorten or split one Action Blocks? to reduce carryover"#,
        with: "Balance only adding essential actions and completing more actions",
        options: .regularExpression
    )
    if output.hasPrefix("Complete one small Action Blocks") {
        output = output.replacingOccurrences(of: "Action Blocks", with: "Action Plan")
    }
    if output.hasPrefix("Finish one small Action Blocks") {
        output = output.replacingOccurrences(of: "Action Blocks", with: "Action Plan")
    }
    if !output.isEmpty, !".!?".contains(output.last ?? ".") {
        output += "."
    }
    return output
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
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse)
    private var diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    @Query(sort: \PurposeProfileInsightsSnapshot.generatedAt, order: .reverse)
    private var purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]
    
    // Consolidated passion categories
    private var passionQueries: [PassionCategory] {
        [
            PassionCategory(emotion: "love", title: "Love", prompt: "What do I love?", query: lovePassions),
            PassionCategory(emotion: "vows", title: "Vow", prompt: "What am I committed to?", query: vowsPassions),
            PassionCategory(emotion: "thrill", title: "Thrill", prompt: "What excites me?", query: thrillPassions),
            PassionCategory(emotion: "just", title: "Hate", prompt: "What do I refuse to tolerate (hate)?", query: justPassions)
        ]
    }
    
    @State private var visionText: String = ""
    @State private var purposeText: String = ""
    @State private var visionTextDraft: String = ""
    @State private var purposeTextDraft: String = ""
    @State private var addStates: [String: AddState] = [:]
    @State private var focusedPassionFieldTextByEmotion: [String: String] = [:]
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
    @State private var readableInsightsByScoreKey: [String: String] = [:]
    @State private var readableInsightLoadingKeys: Set<String> = []
    @State private var readableInsightActiveRequestKeys: Set<String> = []
    @State private var readableInsightFailuresByKey: [String: AppleIntelligenceReadableInsightFailureState] = [:]
    @State private var showDeletePassionHint = false
    @State private var deletePassionHintText = ""
    @State private var deletePassionHintWorkItem: DispatchWorkItem?
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardDismissCommitSignal: Int = 0
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    @State private var autoWriteVisionSuggestions: [String] = []
    @State private var autoWritePassionSuggestions: [AutoWritePassionSuggestion] = []
    @State private var autoWritePassionSuggestionHistory: [AutoWritePassionSuggestion] = []
    @State private var isAutoWritingVision = false
    @State private var isAutoWritingPassions = false
    @State private var autoWriteVisionErrorMessage: String? = nil
    @State private var autoWritePassionsErrorMessage: String? = nil
    @State private var autoWriteVisionTroubleshootingMessage: String? = nil
    @State private var autoWritePassionsTroubleshootingMessage: String? = nil
    @State private var selectedPassionAutoWriteFilter: PassionAutoWriteFilter = .all
    @State private var selectedVisionAutoWriteMode: VisionAutoWriteMode = .newVision
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>? = nil
    @FocusState private var focusedField: Field?
    private let passionHeaderTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let keyboardFloatingGap: CGFloat = 15
    private let autoWritePillHeight: CGFloat = 45

    private enum DrivingForceEditor: String, Identifiable {
        case vision
        case purpose
        var id: String { rawValue }
    }

    private enum VisionAutoWriteMode: String, CaseIterable, Identifiable {
        case newVision
        case rewordVision
        var id: String { rawValue }
        var label: String {
            switch self {
            case .newVision: return "New Vision"
            case .rewordVision: return "Reword Vision"
            }
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
            case .all: return "All Passions"
            case .love: return "Love"
            case .vows: return "Vow"
            case .thrill: return "Thrill"
            case .just: return "Hate"
            }
        }
    }

    private struct AutoWritePassionSuggestion: Identifiable, Hashable {
        let id = UUID()
        let emotion: String
        let passion: String
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

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    private var focusedFieldHasNonBlankText: Bool {
        switch focusedField {
        case .vision:
            return !visionTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case .purpose:
            return !purposeTextDraft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case let .passion(emotion):
            if let text = focusedPassionFieldTextByEmotion[emotion] {
                return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
            let text = addStates[emotion]?.newText ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        case nil:
            return false
        }
    }

    private func keyboardDismissBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return 58 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + keyboardFloatingGap
    }

    private var keyboardDismissButton: some View {
        Button {
            commitFocusedOneLineFieldIfNeeded()
            focusedField = nil
            hideKeyboard()
        } label: {
            Group {
                if focusedFieldHasNonBlankText {
                    Image(systemName: "checkmark")
                        .font(.system(size: 16, weight: .bold))
                        .foregroundStyle(.white)
                        .frame(width: 45, height: 45)
                        .background(Color.blue, in: Circle())
                } else {
                    Image(systemName: "keyboard.chevron.compact.down")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(.primary.opacity(0.85))
                        .frame(width: 45, height: 45)
                        .background(.ultraThinMaterial, in: Circle())
                        .overlay(
                            Circle()
                                .stroke(Color.white.opacity(0.28), lineWidth: 1)
                        )
                }
            }
        }
        .buttonStyle(.plain)
    }

    private func commitFocusedOneLineFieldIfNeeded() {
        guard case let .passion(emotion) = focusedField else { return }
        let state = addStates[emotion] ?? AddState()
        if state.isAdding {
            commitPassion(text: state.newText, emotion: emotion)
        } else {
            keyboardDismissCommitSignal &+= 1
        }
    }

    private var passionAutoWriteFilterOptionsReversed: [PassionAutoWriteFilter] {
        Array(PassionAutoWriteFilter.allCases.reversed())
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

    @ViewBuilder
    private var visionAutoWriteSuggestionsSection: some View {
        let suggestions = autoWriteVisionSuggestions
        let errorMessage = autoWriteVisionErrorMessage
        if !suggestions.isEmpty || (errorMessage != nil) {
            Section {
                VStack(spacing: 8) {
                    ForEach(0..<suggestions.count, id: \.self) { (suggestionIndex: Int) in
                        let suggestion = suggestions[suggestionIndex]
                        let isApplied = normalizedVisionSuggestion(visionTextDraft) == normalizedVisionSuggestion(suggestion)
                        Button {
                            applyAutoWriteVisionSuggestion(suggestion)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image("LoomAI")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .padding(.leading, 2)
                                Text(suggestion)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                    .multilineTextAlignment(.leading)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }

                    if let errorMessage {
                        purposeAutoWriteRetryRow(
                            message: errorMessage,
                            troubleshooting: autoWriteVisionTroubleshootingMessage
                        ) {
                            Task { await requestAutoWriteVisionSuggestions() }
                        }
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    @ViewBuilder
    private var passionsAutoWriteErrorSection: some View {
        if let errorMessage = autoWritePassionsErrorMessage {
            Section {
                purposeAutoWriteRetryRow(
                    message: errorMessage,
                    troubleshooting: autoWritePassionsTroubleshootingMessage
                ) {
                    Task { await requestAutoWritePassionSuggestions() }
                }
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private func purposeAutoWriteRetryRow(
        message: String,
        troubleshooting: String?,
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
                    Button("Try again", action: action)
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

    @ViewBuilder
    private func passionAutoWriteSuggestionsSection(for emotion: String) -> some View {
        let suggestions = autoWritePassionSuggestions.filter { $0.emotion == emotion }
        if !suggestions.isEmpty {
            Section {
                VStack(spacing: 8) {
                    ForEach(0..<suggestions.count, id: \.self) { (suggestionIndex: Int) in
                        let suggestion = suggestions[suggestionIndex]
                        let isApplied = isPassionSuggestionApplied(suggestion)
                        Button {
                            applyAutoWritePassionSuggestion(suggestion)
                        } label: {
                            HStack(alignment: .center, spacing: 10) {
                                Image("LoomAI")
                                    .renderingMode(.template)
                                    .resizable()
                                    .scaledToFit()
                                    .foregroundStyle(.white)
                                    .frame(width: 24, height: 24)
                                    .padding(.leading, 2)
                                VStack(alignment: .leading, spacing: 1.5) {
                                    Text(bucketTitle(for: suggestion.emotion))
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(0.85))
                                    Text(suggestion.passion)
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .padding(.horizontal, 12)
                            .padding(.vertical, 10)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(autoWriteSuggestionBackgroundFill(isApplied: isApplied))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(autoWriteSuggestionBorderColor(isApplied: isApplied), lineWidth: 1)
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(Color.clear)
        }
    }

    private var purposeAutoWriteBottomControls: some View {
        HStack(alignment: .center, spacing: 12) {
            visionAutoWriteControls
            Spacer(minLength: 0)
            passionsAutoWriteControls
        }
        .onAppear {
            guard autoWriteOutlineAngle == 0 else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                autoWriteOutlineAngle = 360
            }
        }
    }

    private var visionAutoWriteControls: some View {
        let isLoading = isAutoWritingVision
        return ZStack(alignment: .trailing) {
            Button {
                guard !isLoading else { return }
                Task { await requestAutoWriteVisionSuggestions() }
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
                        Text(selectedVisionAutoWriteMode.label)
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
                ForEach(VisionAutoWriteMode.allCases) { mode in
                    Button {
                        selectedVisionAutoWriteMode = mode
                    } label: {
                        if selectedVisionAutoWriteMode == mode {
                            Label(mode.label, systemImage: "checkmark")
                        } else {
                            Text(mode.label)
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
        .frame(height: autoWritePillHeight)
        .onChange(of: isLoading, initial: false) { _, newValue in
            setAutoWriteLoadingAnimation(newValue)
        }
    }

    private var passionsAutoWriteControls: some View {
        let isLoading = isAutoWritingPassions
        return ZStack(alignment: .trailing) {
            Button {
                guard !isLoading else { return }
                Task { await requestAutoWritePassionSuggestions() }
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
        .frame(height: autoWritePillHeight)
        .onChange(of: isLoading, initial: false) { _, newValue in
            setAutoWriteLoadingAnimation(newValue)
        }
    }

    private func setAutoWriteLoadingAnimation(_ isLoading: Bool) {
        if isLoading {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimating = false
            autoWriteIconAnimationTask = Task { @MainActor in
                while !Task.isCancelled {
                    withAnimation(.easeInOut(duration: 0.36)) {
                        autoWriteIconAnimating.toggle()
                    }
                    try? await Task.sleep(nanoseconds: 360_000_000)
                }
            }
        } else {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
            withAnimation(.easeOut(duration: 0.16)) {
                autoWriteIconAnimating = false
            }
        }
    }
    
    var body: some View {
        List {
            drivingForceInsightsHeader
                .listRowInsets(EdgeInsets(top: 0, leading: 0, bottom: 8, trailing: 0))
                .listRowBackground(Color.clear)

            AnyView(drivingForceSections)
            AnyView(visionAutoWriteSuggestionsSection)
            AnyView(passionsHeader)
            AnyView(passionsSections)
            AnyView(passionsAutoWriteErrorSection)
            if !historicRows.isEmpty {
                AnyView(historicToggleRow)
            }
            AnyView(historicRowsSection)
        }
        .listStyle(.insetGrouped)
        .listRowSpacing(4)
        .toolbar { topToolbar }
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
        .onReceive(NotificationCenter.default.publisher(for: .vacationModeDidChange)) { _ in
            refreshPassionScoresForCurrentMonthIfNeeded(force: true)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIScreen.main.bounds.height
            keyboardHeight = max(0, screenHeight - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .onDisappear {
            autoWriteIconAnimationTask?.cancel()
            autoWriteIconAnimationTask = nil
        }
        .sheet(isPresented: $isShowingInstructions, content: instructionsSheet)
        .navigationDestination(isPresented: $showDrivingForceTrends) {
            DrivingForceTrendsView(
                snapshots: passionScoreSnapshots,
                supportingData: .init(
                    drivingForces: drivingForces,
                    lovePassions: lovePassions,
                    vowsPassions: vowsPassions,
                    thrillPassions: thrillPassions,
                    justPassions: justPassions,
                    passionJoins: passionJoins,
                    diagnosticsInsightsSnapshots: diagnosticsInsightsSnapshots,
                    purposeProfileInsightsSnapshots: purposeProfileInsightsSnapshots
                )
            )
        }
        .alert("Delete Historic Item?", isPresented: deleteHistoricBinding, actions: deleteHistoricActions, message: deleteHistoricMessage)
        .overlay {
            GeometryReader { proxy in
                if isKeyboardVisible {
                    HStack(spacing: 8) {
                        keyboardDismissButton
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, keyboardDismissBottomPadding(in: proxy))
                }
            }
        }
        .overlay(alignment: .bottom) {
            if showDeletePassionHint {
                Text(deletePassionHintText)
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
                    .padding(.bottom, isKeyboardVisible ? (keyboardHeight + 12) : 84)
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
                    .padding(.bottom, isKeyboardVisible ? (keyboardHeight + 12) : 84)
                    .transition(.opacity)
            }
        }
        .safeAreaInset(edge: .bottom) {
            if !isKeyboardVisible {
                purposeAutoWriteBottomControls
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 10)
            }
        }
        .ignoresSafeArea(.keyboard, edges: .bottom)
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

                Spacer(minLength: 0)

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

            VStack(alignment: .trailing, spacing: 8) {
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
                .frame(maxWidth: .infinity, alignment: .leading)

                HStack(spacing: 6) {
                    purposeHeaderSummaryTile(
                        title: "Strongest",
                        value: purposeHeaderStrongestTitle,
                        subtitle: purposeHeaderStrongestSubtitle
                    )
                    purposeHeaderSummaryTile(
                        title: "Mover",
                        value: purposeHeaderMoverTitle,
                        subtitle: purposeHeaderMoverSubtitle
                    )
                }

                Spacer(minLength: 0)

                if let snap = selectedHeaderPassionSnapshot {
                    let payload = purposeHeaderReadableInsightPayload(for: snap)
                    let insightKey = purposeReadableInsightKey(
                        for: payload,
                        contextSignature: readableInsightContextSignature(surfaceID: "purpose_header_readable_insight")
                    )
                    let summaryInsight = purposeReadableInsightCTAParagraph(aiPurposeHeaderInsightText(for: snap))
                    let failureMessage = readableInsightFailuresByKey[insightKey]?.userMessage
                    let isLoadingInsight = readableInsightLoadingKeys.contains(insightKey)
                    if AppleIntelligenceSupport.isAvailable && (isLoadingInsight || summaryInsight != nil || failureMessage != nil) {
                    Group {
                        if let summaryInsight {
                            PurposeInlineInsightText(
                                imageName: "LoomAI",
                                text: summaryInsight,
                                font: UIFont.preferredFont(forTextStyle: .footnote),
                                textColor: UIColor.label,
                                imageSize: CGSize(width: 32, height: 32)
                            )
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        } else if isLoadingInsight {
                            HStack(spacing: 8) {
                                Image("LoomAI")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                LoomAIReadableInsightTypingDotsIndicator()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let failureMessage {
                            PurposeInlineInsightText(
                                imageName: "LoomAI",
                                text: failureMessage,
                                font: UIFont.preferredFont(forTextStyle: .footnote),
                                textColor: UIColor.secondaryLabel,
                                imageSize: CGSize(width: 32, height: 32)
                            )
                            .frame(maxWidth: .infinity, alignment: .trailing)
                        }
                    }
                    .padding(.top, 6)
                    .padding(.bottom, 8)
                    .padding(.leading, 12)
                    .padding(.trailing, 8)
                    .overlay(
                        LoomAIReadableInsightAnimatedOutlineBorder(cornerRadius: 10)
                    )
                    }
                    Color.clear
                        .frame(width: 0, height: 0)
                        .task(id: insightKey) {
                            guard AppleIntelligenceSupport.isAvailable else { return }
                            await requestPurposeHeaderReadableInsightIfNeeded(for: snap)
                        }
                }
            }
            .frame(width: 166)
            .frame(maxHeight: .infinity, alignment: .topTrailing)
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
                if AppleIntelligenceSupport.isAvailable {
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
                }
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
        if let snapScore = latestMonthlyPassionScore(for: emotionKey) ?? latestAvailablePassionSnapshot(for: emotionKey)?.score {
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
        if let snapScore = latestMonthlyPassionScore(for: emotionKey) ?? latestAvailablePassionSnapshot(for: emotionKey)?.score {
            return PassionScoringMath.clamp(snapScore, min: 0, max: 4)
        }
        return Double(legacyUsagePoints(for: emotionKey))
    }

    private func latestMonthlyPassionScore(for emotionKey: String) -> Double? {
        latestMonthlyPassionSnapshot(for: emotionKey)?.score
    }

    private func latestMonthlyPassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        let monthStart = PassionScoringMath.latestCompletedMonthStart(for: .now)
        return latestPassionSnapshot(for: passionType, monthStart: monthStart)
    }

    private func previousMonthlyPassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        let currentMonthStart = PassionScoringMath.latestCompletedMonthStart(for: .now)
        guard let priorMonthStart = Calendar.current.date(byAdding: .month, value: -1, to: currentMonthStart) else { return nil }
        return latestPassionSnapshot(for: passionType, monthStart: priorMonthStart)
    }

    private func latestPassionSnapshot(for passionType: PassionType, monthStart: Date) -> PassionScoreSnapshot? {
        passionScoreSnapshots
            .filter {
                $0.passionTypeRaw == passionType.rawValue &&
                Calendar.current.isDate($0.monthStartDate, inSameDayAs: monthStart)
            }
            .max(by: { $0.updatedAt < $1.updatedAt })
    }

    private var selectedHeaderPassionSnapshot: PassionScoreSnapshot? {
        latestMonthlyPassionSnapshot(for: highlightedPassionEmotionKey)
            ?? latestAvailablePassionSnapshot(for: highlightedPassionEmotionKey)
    }

    private var readableInsightPersonalizationContext: PersonalizationContextValue? {
        PersonalizationStore.cachedContextForCurrentUser()
    }

    private var latestReadableInsightDiagnosticsSnapshot: DiagnosticsInsightsSnapshot? {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        return diagnosticsInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    private var latestReadableInsightPurposeProfileSnapshot: PurposeProfileInsightsSnapshot? {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        return purposeProfileInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    private func readableInsightContextSeed(surfaceID: String) -> AppleIntelligenceReadableInsightContextSeed {
        let passions = passionQueries
            .flatMap(\.query)
            .sorted { $0.date < $1.date }
        let drivingForce = drivingForces.first
        return AppleIntelligenceReadableInsightContextSeed(
            diagnostic: AppleIntelligenceReadableInsightContextSupport.diagnosticSummary(
                personalizationContext: readableInsightPersonalizationContext,
                diagnosticsSnapshot: latestReadableInsightDiagnosticsSnapshot
            ),
            drivingForce: drivingForce.map {
                .init(
                    vision: $0.ultimateVision,
                    purpose: $0.ultimatePurpose,
                    passions: Array(passions.prefix(8)).map {
                        .init(emotion: $0.emotion, title: $0.passion)
                    }
                )
            },
            purposeProfile: AppleIntelligenceReadableInsightContextSupport.purposeProfileSummary(
                personalizationContext: readableInsightPersonalizationContext,
                purposeProfileSnapshot: latestReadableInsightPurposeProfileSnapshot
            ),
            fulfillmentSetup: AppleIntelligenceReadableInsightContextSupport.fulfillmentSetupSummary(
                personalizationContext: readableInsightPersonalizationContext
            ),
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(
                quickCompletesLast7Days: 0,
                littleWinsCompletionsLast7Days: 0,
                carryoversLast7Days: 0
            ),
            appGuide: Array(LoomAIViewModel.appGuideTopics().prefix(4)),
            dataInventory: [],
            notes: [
                "surface=\(surfaceID)",
                "purpose-readable-insight-lightweight-context"
            ]
        )
    }

    private func readableInsightContextSignature(surfaceID: String) -> String {
        AppleIntelligenceInsightPromptBuilder.readableInsightContextSignature(
            surfaceID: surfaceID,
            seed: readableInsightContextSeed(surfaceID: surfaceID)
        )
    }

    private func readableInsightAppContextJSON(surfaceID: String) -> String {
        AppleIntelligenceInsightPromptBuilder.readableInsightContextJSON(
            surfaceID: surfaceID,
            seed: readableInsightContextSeed(surfaceID: surfaceID)
        )
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

    private var currentMonthPassionSnapshots: [PassionScoreSnapshot] {
        let monthStart = PassionScoringMath.latestCompletedMonthStart(for: .now)
        return passionSnapshotsForMonth(monthStart)
    }

    private func passionSnapshotsForMonth(_ monthStart: Date) -> [PassionScoreSnapshot] {
        let monthRows = passionScoreSnapshots.filter {
            Calendar.current.isDate($0.monthStartDate, inSameDayAs: monthStart)
        }
        let latestByPassion = Dictionary(grouping: monthRows, by: \.passionTypeRaw).compactMapValues {
            $0.max(by: { $0.updatedAt < $1.updatedAt })
        }
        return Array(latestByPassion.values)
    }

    private func latestAvailablePassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        return passionScoreSnapshots
            .filter { $0.passionTypeRaw == passionType.rawValue }
            .max { lhs, rhs in
                let lhsMonth = Calendar.current.startOfDay(for: lhs.monthStartDate)
                let rhsMonth = Calendar.current.startOfDay(for: rhs.monthStartDate)
                if lhsMonth == rhsMonth {
                    return lhs.updatedAt < rhs.updatedAt
                }
                return lhsMonth < rhsMonth
            }
    }

    private var purposeHeaderStrongestSnapshotIfUnique: PassionScoreSnapshot? {
        guard let best = currentMonthPassionSnapshots.max(by: { $0.score < $1.score }) else { return nil }
        let bestRounded = roundedTenth(best.score)
        let tieCount = currentMonthPassionSnapshots.filter { roundedTenth($0.score) == bestRounded }.count
        return tieCount == 1 ? best : nil
    }

    private var purposeHeaderMover: (PassionScoreSnapshot, Double)? {
        let deltas: [(PassionScoreSnapshot, Double)] = currentMonthPassionSnapshots.compactMap { snap in
            guard let delta = passionMonthOverMonthDelta(for: emotionKey(for: snap.passionType)) else { return nil }
            return (snap, delta)
        }
        let result = deltas.max(by: { abs($0.1) < abs($1.1) })
        guard let result else { return nil }
        if abs(result.1) < 0.05 { return nil }

        let topMagnitude = abs(roundedTenth(result.1))
        let tieCount = deltas.filter { abs(roundedTenth($0.1)) == topMagnitude }.count
        return tieCount >= 3 ? nil : result
    }

    private var purposeHeaderStrongestTitle: String {
        purposeHeaderStrongestSnapshotIfUnique.map { passionHeaderTitle(for: emotionKey(for: $0.passionType)) } ?? "—"
    }

    private var purposeHeaderStrongestSubtitle: String {
        purposeHeaderStrongestSnapshotIfUnique.map { String(format: "%.1f/4", $0.score) } ?? "—"
    }

    private var purposeHeaderMoverTitle: String {
        purposeHeaderMover.map { passionHeaderTitle(for: emotionKey(for: $0.0.passionType)) } ?? "—"
    }

    private var purposeHeaderMoverSubtitle: String {
        purposeHeaderMover.map { String(format: "%@%.1f", $0.1 >= 0 ? "+" : "", $0.1) } ?? "—"
    }

    private func purposeHeaderSummaryTile(title: String, value: String, subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Text(value)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(subtitle)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
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

    private func passionItems(for passionType: PassionType) -> [Passion] {
        switch passionType {
        case .love: return lovePassions
        case .vows: return vowsPassions
        case .thrill: return thrillPassions
        case .hate: return justPassions
        }
    }

    private func purposeStructureBreakdown(for passionType: PassionType) -> (itemCount: Int, linkCount: Int, itemCoverage: Double, linkCoverage: Double) {
        let items = passionItems(for: passionType)
        let itemIDs = Set(items.map(\.passion_id))
        let linkCount = passionJoins.filter { itemIDs.contains($0.passion_id) }.count
        let config = PassionScoringService.Config()
        let itemCoverage = PassionScoringMath.clamped01(Double(items.count) / max(1, config.itemSaturationCount))
        let linkCoverage = PassionScoringMath.clamped01(Double(linkCount) / max(1, config.linkSaturationCount))
        return (items.count, linkCount, itemCoverage, linkCoverage)
    }

    private func purposePrimaryLever(for snap: PassionScoreSnapshot) -> AppleIntelligenceReadableInsightLeverageAnalysis {
        let structure = PassionScoringMath.clamped01(snap.structure)
        let outcomes = PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0)
        let actionBlocks = PassionScoringMath.clamped01(snap.actionCoverage)
        let littleWins = PassionScoringMath.clamped01(snap.littleWinsCoverage)
        let carryoverPenalty = PassionScoringMath.clamped01(snap.carryoverPenalty)
        let outcomesIncluded = snap.outcomeCoverage != nil
        let structureBreakdown = purposeStructureBreakdown(for: snap.passionType)

        let itemOpportunity = 0.6 * (1 - structureBreakdown.itemCoverage)
        let linkOpportunity = 0.4 * (1 - structureBreakdown.linkCoverage)
        let structureDetail: String
        let structureAction: String
        if linkOpportunity > itemOpportunity {
            structureDetail = "Fulfillment links are thinner than the passion definition."
            structureAction = "Link this passion to one supporting Fulfillment Area."
        } else {
            structureDetail = "Passion definition is thinner than fulfillment support."
            structureAction = "Tighten or add one passion entry so this theme is more specific."
        }

        var candidates: [AppleIntelligenceReadableInsightLeverageCandidate] = [
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .structure,
                currentValue: structure,
                weight: 0.15,
                reason: "Structure is the biggest setup gap for this passion, and \(structureDetail.lowercased())",
                recommendedAction: structureAction,
                detail: structureDetail,
                actionabilityPriority: 2
            ),
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .actionBlocks,
                currentValue: actionBlocks,
                weight: outcomesIncluded ? 0.25 : (0.25 + (0.30 * (0.25 / 0.45))),
                reason: "Action Blocks have the largest direct execution gap left in this score.",
                recommendedAction: "Finish one small Action Plan that directly supports this passion.",
                actionabilityPriority: 4
            ),
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .littleWins,
                currentValue: littleWins,
                weight: outcomesIncluded ? 0.20 : (0.20 + (0.30 * (0.20 / 0.45))),
                reason: "Little Wins are the clearest missing daily support layer for this passion.",
                recommendedAction: "Complete one repeatable Little Win tied to this passion each day.",
                actionabilityPriority: 4
            ),
            AppleIntelligenceReadableInsightLeverageEngine.dragCandidate(
                metric: .carryoverPenalty,
                currentPenalty: carryoverPenalty,
                weight: 0.10,
                reason: "Carryover penalty is erasing more score than any other drag that remains.",
                recommendedAction: "Shrink or split the Action Plan most likely to carry over.",
                actionabilityPriority: 5
            )
        ]

        if outcomesIncluded {
            candidates.append(
                AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                    metric: .outcomes,
                    currentValue: outcomes,
                    weight: 0.30,
                    reason: "Outcomes connected to this passion are the largest weighted gap still in the formula.",
                    recommendedAction: "Connect or refine one Outcome that this passion clearly advances.",
                    actionabilityPriority: 3
                )
            )
        }

        return AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: candidates)
            ?? AppleIntelligenceReadableInsightLeverageAnalysis(
                metric: .actionBlocks,
                currentValue: actionBlocks,
                displayValue: AppleIntelligenceReadableInsightLeverageEngine.percentText(actionBlocks),
                weight: 0.25,
                headroom: 1 - actionBlocks,
                opportunity: 0.25 * (1 - actionBlocks),
                reason: "Action Blocks are the clearest remaining practical lever in this score.",
                recommendedAction: "Finish one small Action Plan that directly supports this passion.",
                detail: nil,
                isMissing: false
            )
    }

    private func purposeHeaderReadableInsightPayload(for snap: PassionScoreSnapshot) -> PurposeReadableInsightRequestPayload {
        let monthStart = Calendar.current.startOfDay(for: snap.monthStartDate)
        let sameMonth = passionSnapshotsForMonth(monthStart)
        let sortedByScore = sameMonth.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.passionTypeRaw < rhs.passionTypeRaw }
            return lhs.score > rhs.score
        }
        let peerRank = sortedByScore.firstIndex(where: { $0.passionTypeRaw == snap.passionTypeRaw }).map { $0 + 1 }
        let strongest = sortedByScore.first
        let peerAverage = sameMonth.isEmpty ? nil : sameMonth.map(\.score).reduce(0, +) / Double(sameMonth.count)
        let movers: [(PassionScoreSnapshot, Double)] = sameMonth.compactMap { row in
            guard let delta = passionMonthOverMonthDelta(for: emotionKey(for: row.passionType)) else { return nil }
            return (row, roundedTenth(delta))
        }
        let biggestMover = movers.max { abs($0.1) < abs($1.1) }
        let structureBreakdown = purposeStructureBreakdown(for: snap.passionType)
        let primaryLever = purposePrimaryLever(for: snap)
        let recentScores = passionScoreSnapshots
            .filter { $0.passionTypeRaw == snap.passionTypeRaw }
            .sorted { $0.monthStartDate > $1.monthStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        return .init(
            isBaseline: recentScores.count <= 1,
            passionTypeRaw: snap.passionTypeRaw,
            passionTitle: passionHeaderTitle(for: emotionKey(for: snap.passionType)),
            monthStartISO8601: monthStart.ISO8601Format(),
            score: roundedTenth(snap.score),
            monthScore: roundedTenth(snap.targetScore),
            monthOverMonthDelta: passionMonthOverMonthDelta(for: emotionKey(for: snap.passionType)).map(roundedTenth),
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: PassionScoringMath.clamped01(snap.structure),
            structureItemCoverage: structureBreakdown.itemCoverage,
            structureFulfillmentLinkCoverage: structureBreakdown.linkCoverage,
            structureItemCount: structureBreakdown.itemCount,
            structureFulfillmentLinkCount: structureBreakdown.linkCount,
            outcomes: PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0),
            outcomesIncludedInScore: snap.outcomeCoverage != nil,
            actionBlocks: PassionScoringMath.clamped01(snap.actionCoverage),
            littleWins: PassionScoringMath.clamped01(snap.littleWinsCoverage),
            evidence: PassionScoringMath.clamped01(snap.evidenceStable),
            carryoverPenalty: PassionScoringMath.clamped01(snap.carryoverPenalty),
            peerAverageScore: peerAverage.map(roundedTenth),
            peerRank: peerRank,
            peerCount: sameMonth.isEmpty ? nil : sameMonth.count,
            strongestPassion: strongest.map { passionHeaderTitle(for: emotionKey(for: $0.passionType)) },
            strongestPassionScore: strongest.map { roundedTenth($0.score) },
            biggestMoverPassion: biggestMover.map { passionHeaderTitle(for: emotionKey(for: $0.0.passionType)) },
            biggestMoverDelta: biggestMover.map { roundedTenth($0.1) },
            recentScores: recentScores,
            primaryLever: primaryLever
        )
    }

    private func aiPurposeHeaderInsightText(for snap: PassionScoreSnapshot) -> String? {
        guard AppleIntelligenceSupport.isAvailable else { return nil }
        let payload = purposeHeaderReadableInsightPayload(for: snap)
        let key = purposeReadableInsightKey(
            for: payload,
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_header_readable_insight")
        )
        guard let base = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) else { return nil }
        return ensurePurposeReadableInsightCTA(base, payload: payload)
    }

    private func isCurrentPurposeHeaderInsightKey(_ key: String) -> Bool {
        guard let current = selectedHeaderPassionSnapshot else { return false }
        return purposeReadableInsightKey(
            for: purposeHeaderReadableInsightPayload(for: current),
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_header_readable_insight")
        ) == key
    }

    @MainActor
    private func requestPurposeHeaderReadableInsightIfNeeded(for snap: PassionScoreSnapshot) async {
        guard AppleIntelligenceSupport.isAvailable else { return }
        let payload = purposeHeaderReadableInsightPayload(for: snap)
        let surfaceID = "purpose_header_readable_insight"
        let contextSignature = readableInsightContextSignature(surfaceID: surfaceID)
        let key = purposeReadableInsightKey(for: payload, contextSignature: contextSignature)
        guard !readableInsightActiveRequestKeys.contains(key) else { return }
        if !loomAIInsightsRefreshEnabled(),
           let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            readableInsightsByScoreKey[key] = cached
            readableInsightFailuresByKey[key] = nil
            return
        }
        let existingCachedInsight = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key)
        readableInsightFailuresByKey[key] = nil
        readableInsightActiveRequestKeys.insert(key)
        readableInsightLoadingKeys.insert(key)
        defer {
            readableInsightLoadingKeys.remove(key)
            readableInsightActiveRequestKeys.remove(key)
        }

        await Task.yield()
        let contextBuildStartedAt = Date()
        let appContextJSON = readableInsightAppContextJSON(surfaceID: surfaceID)
        AppDebugActivityLog.log(
            "PurposeInsights",
            "readable insight context built surface=header key=\(key) durationMs=\(Int(Date().timeIntervalSince(contextBuildStartedAt) * 1000))"
        )

        do {
            let response = try await AppleIntelligencePurposeInsightsGenerator.readableInsightLines(
                prompt: purposeReadableInsightPrompt(
                    for: payload,
                    appContextJSON: appContextJSON
                )
            )
            guard !Task.isCancelled, isCurrentPurposeHeaderInsightKey(key) else {
                AppDebugActivityLog.log("PurposeInsights", "readable insight dropped stale response surface=header key=\(key)")
                return
            }
            guard let trimmed = purposeReadableInsightStoredText(from: response, payload: payload) else {
                throw AppleIntelligencePurposeInsightsError.invalidResponse
            }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
            readableInsightFailuresByKey[key] = nil
            return
        } catch {
            AppDebugActivityLog.log(
                "PurposeInsights",
                "readable insight failed stage=primary surface=header key=\(key) error=\(error.localizedDescription)"
            )
        }

        do {
            let fallbackText = try await AppleIntelligencePurposeInsightsGenerator.readableInsight(
                prompt: purposeReadableInsightFallbackPrompt(
                    for: payload,
                    appContextJSON: appContextJSON
                )
            )
            guard !Task.isCancelled, isCurrentPurposeHeaderInsightKey(key) else {
                AppDebugActivityLog.log("PurposeInsights", "readable insight dropped stale fallback surface=header key=\(key)")
                return
            }
            let fallbackResult = AppleIntelligenceReadableInsightNormalizer.fromPlainText(fallbackText)
            guard let trimmed = purposeReadableInsightStoredText(from: fallbackResult, payload: payload) else {
                throw AppleIntelligencePurposeInsightsError.invalidResponse
            }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
            readableInsightFailuresByKey[key] = nil
        } catch {
            AppDebugActivityLog.log(
                "PurposeInsights",
                "readable insight failed stage=fallback surface=header key=\(key) error=\(error.localizedDescription)"
            )
            guard existingCachedInsight == nil else { return }
            readableInsightFailuresByKey[key] = .init(
                stage: "fallback",
                technicalMessage: error.localizedDescription,
                userMessage: purposeReadableInsightUnavailableMessage
            )
        }
    }

    private func stableDrivingForceHeaderInsightMessage(for snap: PassionScoreSnapshot) -> String? {
        let key = purposeReadableInsightKey(
            for: purposeHeaderReadableInsightPayload(for: snap),
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_header_readable_insight")
        )
        if let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            return cached
        }
        return primaryDrivingForceHeaderInsightMessage(for: snap)
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

    private func emotionKey(for passionType: PassionType) -> String {
        switch passionType {
        case .love: return "love"
        case .vows: return "vows"
        case .thrill: return "thrill"
        case .hate: return "just"
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
        let monthStart = PassionScoringMath.latestCompletedMonthStart(for: .now)
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
                    dismissCommitSignal: keyboardDismissCommitSignal,
                    onAddStateChange: { newState in
                        addStates[category.emotion] = newState
                    },
                    onActiveFieldTextChange: { text in
                        if let text {
                            focusedPassionFieldTextByEmotion[category.emotion] = text
                        } else {
                            focusedPassionFieldTextByEmotion.removeValue(forKey: category.emotion)
                        }
                    },
                    focusedField: $focusedField,
                    onCommit: { text in
                        commitPassion(text: text, emotion: category.emotion)
                    },
                    onDelete: deletePassion
                )
                passionAutoWriteSuggestionsSection(for: category.emotion)
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

    private var visionTrimmed: String {
        visionTextDraft.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func requestAutoWriteVisionSuggestions() async {
        let previousSuggestions = autoWriteVisionSuggestions
        isAutoWritingVision = true
        defer { isAutoWritingVision = false }
        autoWriteVisionErrorMessage = nil
        autoWriteVisionTroubleshootingMessage = nil
        autoWriteVisionSuggestions = []

        let effectivePreviousSuggestions: [String]
        switch selectedVisionAutoWriteMode {
        case .newVision:
            effectivePreviousSuggestions = uniqueVisionSuggestions(
                ([visionTrimmed] + previousSuggestions)
                    .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                    .filter { !$0.isEmpty }
            )
        case .rewordVision:
            effectivePreviousSuggestions = visionTrimmed.isEmpty ? [] : previousSuggestions
        }

        if AppleIntelligenceSupport.isAvailable {
            do {
                let aiSuggestions = try await AppleIntelligencePurposeVisionGenerator.suggestions(
                    personalization: nil,
                    currentVision: visionTrimmed,
                    previousSuggestions: effectivePreviousSuggestions
                )
                let resolved = selectedVisionAutoWriteMode == .newVision
                    ? filterNewVisionSuggestions(
                        aiSuggestions,
                        currentVision: visionTrimmed,
                        previousSuggestions: effectivePreviousSuggestions
                    )
                    : aiSuggestions
                let nextSuggestions = Array(resolved.prefix(2))
                if !nextSuggestions.isEmpty {
                    autoWriteVisionSuggestions = nextSuggestions
                    autoWriteVisionErrorMessage = nil
                    autoWriteVisionTroubleshootingMessage = nil
                    return
                }
            } catch {
                // Fall back to the local suggestion table below.
            }
        }

        let fallbackSuggestions = PurposeVisionAutoWriteSuggestionTable.pickSuggestions(
            personalizationSnapshot: nil,
            currentVision: visionTrimmed,
            previousSuggestions: effectivePreviousSuggestions,
            count: 2
        )
        let resolvedFallback = selectedVisionAutoWriteMode == .newVision
            ? filterNewVisionSuggestions(
                fallbackSuggestions,
                currentVision: visionTrimmed,
                previousSuggestions: effectivePreviousSuggestions
            )
            : fallbackSuggestions
        let nextSuggestions = Array(resolvedFallback.prefix(2))
        guard !nextSuggestions.isEmpty else {
            autoWriteVisionErrorMessage = selectedVisionAutoWriteMode == .newVision
                ? "No new vision suggestions yet."
                : "No suggestions yet."
            autoWriteVisionTroubleshootingMessage = nil
            return
        }
        autoWriteVisionSuggestions = nextSuggestions
        autoWriteVisionErrorMessage = nil
        autoWriteVisionTroubleshootingMessage = nil
    }

    private func uniqueVisionSuggestions(_ suggestions: [String]) -> [String] {
        var seen = Set<String>()
        var unique: [String] = []
        for suggestion in suggestions {
            let key = normalizedVisionSuggestion(suggestion)
            guard !key.isEmpty else { continue }
            if seen.insert(key).inserted {
                unique.append(suggestion)
            }
        }
        return unique
    }

    private func filterNewVisionSuggestions(
        _ suggestions: [String],
        currentVision: String,
        previousSuggestions: [String]
    ) -> [String] {
        let blocked = Set(
            ([currentVision] + previousSuggestions)
                .map { normalizedVisionSuggestion($0) }
                .filter { !$0.isEmpty }
        )

        var kept: [String] = []
        for suggestion in suggestions {
            let normalized = normalizedVisionSuggestion(suggestion)
            guard !normalized.isEmpty else { continue }
            guard !blocked.contains(normalized) else { continue }
            guard !isNearDuplicateVisionSuggestion(normalized, comparedTo: currentVision) else { continue }
            guard !kept.contains(where: { isNearDuplicateVisionSuggestion(normalized, comparedTo: $0) }) else { continue }
            kept.append(suggestion)
        }
        return kept
    }

    private func isNearDuplicateVisionSuggestion(_ suggestion: String, comparedTo other: String) -> Bool {
        let left = normalizedVisionSuggestion(suggestion)
        let right = normalizedVisionSuggestion(other)
        guard !left.isEmpty, !right.isEmpty else { return false }
        if left == right { return true }

        let leftTokens = Set(left.split(separator: " ").map(String.init).filter { $0.count > 2 })
        let rightTokens = Set(right.split(separator: " ").map(String.init).filter { $0.count > 2 })
        guard !leftTokens.isEmpty, !rightTokens.isEmpty else { return false }

        let intersection = leftTokens.intersection(rightTokens).count
        let union = leftTokens.union(rightTokens).count
        let jaccard = union > 0 ? Double(intersection) / Double(union) : 0
        if jaccard >= 0.72 {
            return true
        }

        let shorter = left.count <= right.count ? left : right
        let longer = left.count > right.count ? left : right
        if shorter.count >= 42, longer.contains(shorter) {
            return true
        }

        return false
    }

    private func requestAutoWritePassionSuggestions() async {
        isAutoWritingPassions = true
        defer { isAutoWritingPassions = false }
        autoWritePassionsErrorMessage = nil
        autoWritePassionsTroubleshootingMessage = nil
        autoWritePassionSuggestions = []
        let delayNanos = UInt64.random(in: 2_000_000_000...5_000_000_000)
        try? await Task.sleep(nanoseconds: delayNanos)
        guard !Task.isCancelled else { return }

        let existingByEmotion: [String: [String]] = [
            "love": currentPassionValues(for: "love"),
            "vows": currentPassionValues(for: "vows"),
            "thrill": currentPassionValues(for: "thrill"),
            "just": currentPassionValues(for: "just")
        ]
        let selectedEmotion = selectedPassionAutoWriteFilter == .all ? nil : selectedPassionAutoWriteFilter.rawValue
        let generated = PassionAutoWriteSuggestionTable.pickSuggestions(
            filterEmotion: selectedEmotion,
            existingByEmotion: existingByEmotion,
            singleBucketCount: 2
        )
        let suggestions = generated.map { AutoWritePassionSuggestion(emotion: $0.emotion, passion: $0.passion) }

        guard !suggestions.isEmpty else {
            autoWritePassionsErrorMessage = "No suggestions yet."
            autoWritePassionsTroubleshootingMessage = loomAITroubleshootingLocalDetails(
                feature: "purpose_view_autowrite_passions",
                reason: "No local table suggestions were available after filtering currently selected passions."
            )
            return
        }

        autoWritePassionSuggestions = suggestions
        autoWritePassionsErrorMessage = nil
        autoWritePassionsTroubleshootingMessage = nil
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

    private struct AutoWriteConfidenceValueEnvelope: Decodable {
        let confidence: String?
    }

    private func decodeAutoWriteConfidenceValue(from raw: String) -> String? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let parsed = try? JSONDecoder().decode(AutoWriteConfidenceValueEnvelope.self, from: data) else {
            return nil
        }
        let confidence = parsed.confidence?.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard let confidence, !confidence.isEmpty else { return nil }
        return confidence
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
        let normalizedSuggestion = normalizedVisionSuggestion(suggestion.passion)
        return currentPassionValues(for: suggestion.emotion).contains {
            normalizedVisionSuggestion($0) == normalizedSuggestion
        }
    }

    private func applyAutoWriteVisionSuggestion(_ suggestion: String) {
        visionTextDraft = suggestion
        saveVisionInline()
    }

    private func applyAutoWritePassionSuggestion(_ suggestion: AutoWritePassionSuggestion) {
        guard !isPassionSuggestionApplied(suggestion) else { return }
        rememberPassionSuggestion(suggestion)
        let passion = Passion(date: .now, emotion: suggestion.emotion, passion: suggestion.passion)
        context.insert(passion)
        try? context.save()
        refreshPassionScoresForCurrentMonthIfNeeded(force: true)
    }

    private func trackedPreviousPassionSuggestions() -> [AutoWritePassionSuggestion] {
        var result: [AutoWritePassionSuggestion] = []
        var seen: Set<String> = []
        for suggestion in autoWritePassionSuggestionHistory + autoWritePassionSuggestions {
            let key = normalizedPassionSuggestionKey(suggestion)
            guard !key.isEmpty, !seen.contains(key) else { continue }
            seen.insert(key)
            result.append(suggestion)
        }
        return result
    }

    private func containsPassionSuggestion(_ source: [AutoWritePassionSuggestion], suggestion: AutoWritePassionSuggestion) -> Bool {
        let candidateKey = normalizedPassionSuggestionKey(suggestion)
        guard !candidateKey.isEmpty else { return false }
        return source.contains { normalizedPassionSuggestionKey($0) == candidateKey }
    }

    private func rememberPassionSuggestion(_ suggestion: AutoWritePassionSuggestion) {
        let key = normalizedPassionSuggestionKey(suggestion)
        guard !key.isEmpty else { return }
        guard !autoWritePassionSuggestionHistory.contains(where: { normalizedPassionSuggestionKey($0) == key }) else { return }
        autoWritePassionSuggestionHistory.append(suggestion)
        if autoWritePassionSuggestionHistory.count > 40 {
            autoWritePassionSuggestionHistory = Array(autoWritePassionSuggestionHistory.suffix(40))
        }
    }

    private func normalizedPassionSuggestionKey(_ suggestion: AutoWritePassionSuggestion) -> String {
        let passion = normalizedVisionSuggestion(suggestion.passion)
        return passion
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
        let existing = currentPassionValues(for: suggestion.emotion)
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

    private func currentPassionValues(for emotion: String) -> [String] {
        let persisted: [String]
        switch emotion {
        case "love":
            persisted = lovePassions.map(\.passion)
        case "vows":
            persisted = vowsPassions.map(\.passion)
        case "thrill":
            persisted = thrillPassions.map(\.passion)
        case "just":
            persisted = justPassions.map(\.passion)
        default:
            persisted = []
        }
        let pending = (addStates[emotion]?.newText ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if pending.isEmpty { return persisted }
        return persisted + [pending]
    }

    private func bucketTitle(for emotion: String) -> String {
        switch emotion {
        case "love": return "Love"
        case "vows": return "Vow"
        case "thrill": return "Thrill"
        case "just": return "Hate"
        default: return emotion.capitalized
        }
    }

    private func normalizedVisionSuggestion(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func truncateSuggestion(_ text: String, maxLength: Int) -> String {
        guard text.count > maxLength else { return text }
        let prefix = String(text.prefix(maxLength))
        if let space = prefix.lastIndex(of: " "), space > prefix.startIndex {
            return String(prefix[..<space]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return prefix
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
        if passionCount(for: passion.emotion) <= 2 {
            showDeletePassionBlockedHint(for: passion.emotion)
            return
        }
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

    private func passionCount(for emotion: String) -> Int {
        switch emotion {
        case "love": return lovePassions.count
        case "vows": return vowsPassions.count
        case "thrill": return thrillPassions.count
        case "just": return justPassions.count
        default: return passionsForEmotion(emotion).count
        }
    }

    private func passionsForEmotion(_ emotion: String) -> [Passion] {
        switch emotion {
        case "love": return lovePassions
        case "vows": return vowsPassions
        case "thrill": return thrillPassions
        case "just": return justPassions
        default: return []
        }
    }

    private func showDeletePassionBlockedHint(for emotion: String) {
        deletePassionHintWorkItem?.cancel()
        let title = passionTitleForHint(emotion)
        deletePassionHintText = "Keep at least 2 \(title) items."
        withAnimation(.easeInOut(duration: 0.15)) {
            showDeletePassionHint = true
        }
        let work = DispatchWorkItem {
            withAnimation(.easeInOut(duration: 0.15)) {
                showDeletePassionHint = false
            }
        }
        deletePassionHintWorkItem = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.8, execute: work)
    }

    private func passionTitleForHint(_ emotion: String) -> String {
        switch emotion {
        case "love": return "Love"
        case "vows": return "Vow"
        case "thrill": return "Thrill"
        case "just": return "Hate"
        default: return "Passion"
        }
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

#if canImport(UIKit)
private func applyPurposeInsightMetricItalics(
    to attributed: inout AttributedString
) {
    let labels = [
        "Momentum",
        "Consistency",
        "Structure",
        "Outcomes",
        "Action Blocks",
        "Action blocks",
        "Little Wins",
        "Evidence",
        "Carryover penalty",
        "Carryover Penalty"
    ]
    let source = String(attributed.characters)
    let escaped = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    let pattern = "(?i)\\b(?:\(escaped))\\b(?:\\s*\\([^\\)]+\\))?"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    for match in regex.matches(in: source, range: nsRange) {
        if let range = Range(match.range, in: attributed) {
            attributed[range].inlinePresentationIntent = .emphasized
        }
    }
}

private func applyPurposeInsightMetricItalics(
    to attributed: NSMutableAttributedString,
    source: String,
    baseFont: UIFont
) {
    let labels = [
        "Momentum",
        "Consistency",
        "Structure",
        "Outcomes",
        "Action Blocks",
        "Action blocks",
        "Little Wins",
        "Evidence",
        "Carryover penalty",
        "Carryover Penalty"
    ]
    let escaped = labels.map(NSRegularExpression.escapedPattern(for:)).joined(separator: "|")
    let pattern = "(?i)\\b(?:\(escaped))\\b(?:\\s*\\([^\\)]+\\))?"
    guard let regex = try? NSRegularExpression(pattern: pattern) else { return }
    let italicDescriptor = baseFont.fontDescriptor.withSymbolicTraits([.traitItalic]) ?? baseFont.fontDescriptor
    let italicFont = UIFont(descriptor: italicDescriptor, size: baseFont.pointSize)
    let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
    for match in regex.matches(in: source, range: nsRange) {
        attributed.addAttribute(.font, value: italicFont, range: match.range)
    }
}

private func purposeInsightUIColorSignature(_ color: UIColor) -> String {
    guard let components = color.cgColor.components else { return color.description }
    return components.map { String(format: "%.4f", $0) }.joined(separator: ",")
}

private struct PurposeInlineInsightText: UIViewRepresentable {
    let imageName: String
    let text: String
    let font: UIFont
    let textColor: UIColor
    let imageSize: CGSize

    private let imageTag = 9_431
    private let imageTextSpacing: CGFloat = 8

    final class Coordinator {
        var lastRenderSignature: String?
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView()
        view.isEditable = false
        view.isSelectable = false
        view.isScrollEnabled = false
        view.backgroundColor = .clear
        view.textContainerInset = .zero
        view.textContainer.lineFragmentPadding = 0
        view.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        let imageView = UIImageView()
        imageView.tag = imageTag
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        view.addSubview(imageView)
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let renderSignature = [
            text,
            imageName,
            font.fontName,
            String(format: "%.2f", font.pointSize),
            purposeInsightUIColorSignature(textColor),
            String(format: "%.2f", imageSize.width),
            String(format: "%.2f", imageSize.height)
        ].joined(separator: "|")

        guard context.coordinator.lastRenderSignature != renderSignature else { return }

        let paragraph = NSMutableParagraphStyle()
        paragraph.lineBreakMode = .byWordWrapping

        let attrs: [NSAttributedString.Key: Any] = [
            .font: font,
            .foregroundColor: textColor,
            .paragraphStyle: paragraph
        ]
        let output = NSMutableAttributedString()
        output.append(NSAttributedString(string: text, attributes: attrs))
        applyPurposeInsightMetricItalics(to: output, source: text, baseFont: font)
        view.attributedText = output

        if let imageView = view.viewWithTag(imageTag) as? UIImageView {
            imageView.image = UIImage(named: imageName)
            imageView.frame = CGRect(origin: .zero, size: imageSize)
        }

        let exclusionRect = CGRect(
            x: 0,
            y: 0,
            width: imageSize.width + imageTextSpacing,
            height: imageSize.height
        )
        let path = UIBezierPath(rect: exclusionRect)
        view.textContainer.exclusionPaths = [path]
        context.coordinator.lastRenderSignature = renderSignature
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 160
        let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fitting)
        return CGSize(width: width, height: ceil(size.height))
    }
}
#endif

private struct DrivingForceTrendRow: Identifiable {
    let id: String
    let monthStart: Date
    let passionType: PassionType
    let title: String
    let value: Double
}

private struct DrivingForceTrendsSupportingData {
    let drivingForces: [DrivingForce]
    let lovePassions: [Passion]
    let vowsPassions: [Passion]
    let thrillPassions: [Passion]
    let justPassions: [Passion]
    let passionJoins: [PassionFulfillmentJoin]
    let diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    let purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]
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
    let supportingData: DrivingForceTrendsSupportingData

    @State private var selectedTimeline: TimelineOption = .all
    @State private var selectedMonthRaw: Date?
    @State private var selectedPassionTypeRaw: String?
    @State private var trendsContentIsReady = false
    @State private var insightsStartupEnabled = false
    @State private var cachedAllMonthStarts: [Date] = []
    @State private var cachedLatestMonthStart: Date?
    @State private var cachedVisibleMonths: [Date] = []
    @State private var cachedLatestMonthSnapshots: [PassionScoreSnapshot] = []
    @State private var cachedSelectedMonthStart: Date?
    @State private var cachedSelectedMonthSnapshots: [PassionScoreSnapshot] = []
    @State private var cachedChartRowsByMonth: [Date: [DrivingForceTrendRow]] = [:]
    @State private var cachedActualSnapshotValueByMonthPassion: [String: Double] = [:]
    @State private var cachedReadableInsightContextSignature: String = ""
    @State private var cachedReadableInsightAppContextJSON: String = "{}"
    @State private var readableInsightsByScoreKey: [String: String] = [:]
    @State private var readableInsightLoadingKeys: Set<String> = []
    @State private var readableInsightActiveRequestKeys: Set<String> = []
    @State private var readableInsightFailuresByKey: [String: AppleIntelligenceReadableInsightFailureState] = [:]
    @State private var isHowItWorksExpanded = false

    private let chartPassionOrder: [PassionType] = [.love, .vows, .thrill, .hate]
    private let plotHeight: CGFloat = 220
    private let yAxisWidth: CGFloat = 24
    private let leadingPadding: CGFloat = 14
    private let trailingPadding: CGFloat = 8

    private var allMonthStarts: [Date] { cachedAllMonthStarts }

    private var latestMonthStart: Date? { cachedLatestMonthStart }

    private var visibleMonths: [Date] { cachedVisibleMonths }

    private var timelineOptions: [TimelineOption] {
        let count = allMonthStarts.count
        var options: [TimelineOption] = [.all]
        if count >= 3 { options.append(.threeMonths) }
        if count >= 6 { options.append(.sixMonths) }
        if count >= 12 { options.append(.oneYear) }
        if count >= 24 { options.append(.threeYears) }
        return options
    }

    private var selectedMonthStart: Date? { cachedSelectedMonthStart }

    private var latestMonthSnapshots: [PassionScoreSnapshot] { cachedLatestMonthSnapshots }

    private var selectedMonthSnapshots: [PassionScoreSnapshot] { cachedSelectedMonthSnapshots }

    private func latestSnapshotsByPassion(monthStart: Date) -> [PassionScoreSnapshot] {
        let monthRows = snapshots.filter { Calendar.current.isDate($0.monthStartDate, inSameDayAs: monthStart) }
        let latestByPassion = Dictionary(grouping: monthRows, by: \.passionTypeRaw).compactMapValues {
            $0.max(by: { $0.updatedAt < $1.updatedAt })
        }
        return latestByPassion.values.sorted(by: passionSnapshotSort)
    }

    private var selectedSnapshot: PassionScoreSnapshot? {
        if let raw = selectedPassionTypeRaw,
           let row = selectedMonthSnapshots.first(where: { $0.passionTypeRaw == raw }) {
            return row
        }
        return selectedMonthSnapshots.sorted(by: passionSnapshotSort).first
    }

    private var readableInsightPersonalizationContext: PersonalizationContextValue? {
        PersonalizationStore.cachedContextForCurrentUser()
    }

    private var latestReadableInsightDiagnosticsSnapshot: DiagnosticsInsightsSnapshot? {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        return supportingData.diagnosticsInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    private var latestReadableInsightPurposeProfileSnapshot: PurposeProfileInsightsSnapshot? {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        return supportingData.purposeProfileInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    private func readableInsightContextSeed(surfaceID: String) -> AppleIntelligenceReadableInsightContextSeed {
        let passions = [
            supportingData.lovePassions,
            supportingData.vowsPassions,
            supportingData.thrillPassions,
            supportingData.justPassions
        ]
            .flatMap { $0 }
            .sorted { $0.date < $1.date }
        let drivingForce = supportingData.drivingForces.first
        return AppleIntelligenceReadableInsightContextSeed(
            diagnostic: AppleIntelligenceReadableInsightContextSupport.diagnosticSummary(
                personalizationContext: readableInsightPersonalizationContext,
                diagnosticsSnapshot: latestReadableInsightDiagnosticsSnapshot
            ),
            drivingForce: drivingForce.map {
                .init(
                    vision: $0.ultimateVision,
                    purpose: $0.ultimatePurpose,
                    passions: Array(passions.prefix(8)).map {
                        .init(emotion: $0.emotion, title: $0.passion)
                    }
                )
            },
            purposeProfile: AppleIntelligenceReadableInsightContextSupport.purposeProfileSummary(
                personalizationContext: readableInsightPersonalizationContext,
                purposeProfileSnapshot: latestReadableInsightPurposeProfileSnapshot
            ),
            fulfillmentSetup: AppleIntelligenceReadableInsightContextSupport.fulfillmentSetupSummary(
                personalizationContext: readableInsightPersonalizationContext
            ),
            fulfillmentCategories: [],
            activeOutcomes: [],
            currentWeekActionBlocks: [],
            recentActivity: .init(
                quickCompletesLast7Days: 0,
                littleWinsCompletionsLast7Days: 0,
                carryoversLast7Days: 0
            ),
            appGuide: Array(LoomAIViewModel.appGuideTopics().prefix(4)),
            dataInventory: [],
            notes: [
                "surface=\(surfaceID)",
                "purpose-readable-insight-lightweight-context"
            ]
        )
    }

    private func readableInsightContextSignature(surfaceID: String) -> String {
        cachedReadableInsightContextSignature
    }

    private func readableInsightAppContextJSON(surfaceID: String) -> String {
        cachedReadableInsightAppContextJSON
    }

    private func passionSnapshotSort(_ lhs: PassionScoreSnapshot, _ rhs: PassionScoreSnapshot) -> Bool {
        let li = chartPassionOrder.firstIndex(of: lhs.passionType) ?? Int.max
        let ri = chartPassionOrder.firstIndex(of: rhs.passionType) ?? Int.max
        return li < ri
    }

    private var chartRowsByMonth: [Date: [DrivingForceTrendRow]] {
        cachedChartRowsByMonth
    }

    private var actualSnapshotValueByMonthPassion: [String: Double] {
        cachedActualSnapshotValueByMonthPassion
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
        guard let result else { return nil }
        if abs(result.1) < 0.05 { return nil }

        // Match Strongest's tie-handling behavior, but only blank when 3+ tie on movement magnitude.
        let topMagnitude = abs(roundedTenth(result.1))
        let tieCount = deltas.filter { abs(roundedTenth($0.1)) == topMagnitude }.count
        if tieCount >= 3 { return nil }

        return result
    }

    private var supportingDataRefreshKey: String {
        let drivingForceUpdatedAt = supportingData.drivingForces.first?.updatedAt.timeIntervalSinceReferenceDate ?? 0
        let diagnosticsGeneratedAt = supportingData.diagnosticsInsightsSnapshots.first?.generatedAt.timeIntervalSinceReferenceDate ?? 0
        let purposeProfileGeneratedAt = supportingData.purposeProfileInsightsSnapshots.first?.generatedAt.timeIntervalSinceReferenceDate ?? 0
        let parts = [
            String(drivingForceUpdatedAt),
            String(supportingData.lovePassions.count),
            String(supportingData.vowsPassions.count),
            String(supportingData.thrillPassions.count),
            String(supportingData.justPassions.count),
            String(supportingData.passionJoins.count),
            String(diagnosticsGeneratedAt),
            String(purposeProfileGeneratedAt)
        ]
        return parts.joined(separator: "|")
    }

    private func rebuildReadableInsightContextCache() {
        let surfaceID = "purpose_trends_readable_insight"
        let seed = readableInsightContextSeed(surfaceID: surfaceID)
        cachedReadableInsightContextSignature = AppleIntelligenceInsightPromptBuilder.readableInsightContextSignature(
            surfaceID: surfaceID,
            seed: seed
        )
        cachedReadableInsightAppContextJSON = AppleIntelligenceInsightPromptBuilder.readableInsightContextJSON(
            surfaceID: surfaceID,
            seed: seed
        )
    }

    private func rebuildTrendsCaches() {
        let cal = Calendar.current
        let allMonthStarts = Array(Set(snapshots.map { cal.startOfDay(for: $0.monthStartDate) })).sorted()
        cachedAllMonthStarts = allMonthStarts

        let latestMonthStart = allMonthStarts.last
        cachedLatestMonthStart = latestMonthStart

        let visibleMonths: [Date] = {
            guard let latestMonthStart else { return [] }
            guard let months = selectedTimeline.rollingMonths else { return allMonthStarts }
            let start = cal.date(byAdding: .month, value: -(months - 1), to: latestMonthStart) ?? latestMonthStart
            let filtered = allMonthStarts.filter { $0 >= start && $0 <= latestMonthStart }
            return filtered.isEmpty ? [latestMonthStart] : filtered
        }()
        cachedVisibleMonths = visibleMonths

        let latestMonthSnapshots: [PassionScoreSnapshot] = {
            guard let latestMonthStart else { return [] }
            return latestSnapshotsByPassion(monthStart: latestMonthStart)
        }()
        cachedLatestMonthSnapshots = latestMonthSnapshots

        let resolvedSelectedMonth: Date? = {
            guard let latestMonthStart else { return nil }
            guard let selectedMonthRaw else { return latestMonthStart }
            let target = cal.startOfDay(for: selectedMonthRaw)
            let resolved = visibleMonths.min(by: { abs($0.timeIntervalSince(target)) < abs($1.timeIntervalSince(target)) })
            return resolved ?? latestMonthStart
        }()
        cachedSelectedMonthStart = resolvedSelectedMonth

        let selectedMonthSnapshots: [PassionScoreSnapshot] = {
            guard let resolvedSelectedMonth else { return latestMonthSnapshots }
            return latestSnapshotsByPassion(monthStart: resolvedSelectedMonth)
        }()
        cachedSelectedMonthSnapshots = selectedMonthSnapshots

        let visibleSet = Set(visibleMonths.map { cal.startOfDay(for: $0) })
        let latestVisibleSnapshots = Dictionary(grouping: snapshots.filter {
            visibleSet.contains(cal.startOfDay(for: $0.monthStartDate))
        }) {
            monthPassionKey(monthStart: $0.monthStartDate, passionType: $0.passionType)
        }.compactMapValues { rows in
            rows.max(by: { $0.updatedAt < $1.updatedAt })
        }
        cachedActualSnapshotValueByMonthPassion = latestVisibleSnapshots.mapValues(\.score)

        let chartRows = chartPassionOrder.flatMap { passion in
            visibleMonths.map { month -> DrivingForceTrendRow in
                let monthStart = cal.startOfDay(for: month)
                let key = monthPassionKey(monthStart: monthStart, passionType: passion)
                let snap = latestVisibleSnapshots[key]
                return DrivingForceTrendRow(
                    id: key,
                    monthStart: monthStart,
                    passionType: passion,
                    title: passionTitle(for: passion),
                    value: snap?.score ?? 0
                )
            }
        }
        cachedChartRowsByMonth = Dictionary(grouping: chartRows) { cal.startOfDay(for: $0.monthStart) }

        if let selectedPassionTypeRaw,
           selectedMonthSnapshots.contains(where: { $0.passionTypeRaw == selectedPassionTypeRaw }) {
            return
        }
        self.selectedPassionTypeRaw = selectedMonthSnapshots.sorted(by: passionSnapshotSort).first?.passionTypeRaw
    }

    @MainActor
    private func prepareInitialContentIfNeeded() async {
        guard !trendsContentIsReady else { return }
        await Task.yield()
        rebuildTrendsCaches()
        trendsContentIsReady = true
        await Task.yield()
        rebuildReadableInsightContextCache()
        insightsStartupEnabled = true
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                if trendsContentIsReady {
                    if shouldShowBaselineMethodologyCard {
                        baselineMethodologyCard
                    }
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
        .task {
            await prepareInitialContentIfNeeded()
        }
        .onChange(of: snapshots.count) { _, _ in
            rebuildTrendsCaches()
            if trendsContentIsReady {
                rebuildReadableInsightContextCache()
            }
        }
        .onChange(of: supportingDataRefreshKey) { _, _ in
            rebuildTrendsCaches()
            if trendsContentIsReady {
                rebuildReadableInsightContextCache()
            }
        }
        .onChange(of: selectedTimeline) { _, _ in
            rebuildTrendsCaches()
        }
        .onChange(of: selectedMonthRaw) { _, _ in
            guard trendsContentIsReady else { return }
            rebuildTrendsCaches()
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
                    rebuildTrendsCaches()
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

    private var shouldShowBaselineMethodologyCard: Bool {
        guard let snap = selectedSnapshot else { return false }
        return purposeTrendsReadableInsightPayload(for: snap).recentScores.count <= 1
    }

    private var baselineMethodologyCard: some View {
        let cautionTextColor = Color.black.opacity(0.78)
        return VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                Text("Baseline Mode")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(cautionTextColor)
            }

            Text("Your starting value is set at the midpoint so Loom can establish a neutral baseline before enough trend data exists.")
                .font(.footnote)
                .foregroundStyle(cautionTextColor)
                .fixedSize(horizontal: false, vertical: true)

            Text("What you do can move this score up to signal progress, or down to signal lack of attention.")
                .font(.footnote)
                .foregroundStyle(cautionTextColor)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(Color(red: 0.98, green: 0.92, blue: 0.72))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.orange.opacity(0.35), lineWidth: 1)
        )
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
                let payload = purposeTrendsReadableInsightPayload(for: snap)
                let insightKey = purposeReadableInsightKey(
                    for: payload,
                    contextSignature: readableInsightContextSignature(surfaceID: "purpose_trends_readable_insight")
                )
                let message = aiPurposeTrendsInsightText(for: snap)
                let failureMessage = readableInsightFailuresByKey[insightKey]?.userMessage
                let isLoadingInsight = readableInsightLoadingKeys.contains(insightKey)
                if AppleIntelligenceSupport.isAvailable && insightsStartupEnabled && (isLoadingInsight || message != nil || failureMessage != nil) {
                    DrivingForceAnimatedInsightCallout(
                        message: message ?? failureMessage ?? "",
                        isLoading: isLoadingInsight && message == nil
                    )
                }
                Color.clear
                    .frame(width: 0, height: 0)
                    .task(id: insightKey) {
                        guard AppleIntelligenceSupport.isAvailable, insightsStartupEnabled else { return }
                        await requestPurposeTrendsReadableInsightIfNeeded(for: snap)
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
                    insightRow("Evidence", percentTextOrDash(snap.evidenceStable))
                    insightRow(
                        "Carryover penalty",
                        percentTextOrDash(snap.carryoverPenalty),
                        color: snap.carryoverPenalty > 0.30 ? .red : .secondary
                    )
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                purposeInsightsMethodologySection(for: snap)
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

    @ViewBuilder
    private func purposeInsightsMethodologySection(for snap: PassionScoreSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Last update: \(insightsDateText(snap.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Next update: \(insightsDateText(nextPurposeUpdateDate(from: snap.updatedAt)))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Button {
                withAnimation(.easeInOut(duration: 0.22)) {
                    isHowItWorksExpanded.toggle()
                }
            } label: {
                HStack(spacing: 8) {
                    Text("How it works")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                    Image(systemName: isHowItWorksExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .buttonStyle(.plain)

            if isHowItWorksExpanded {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Loom combines your monthly score trend with behavior signals to estimate where progress is strengthening or stalling. It then prioritizes one clear leverage point so your next improvement is specific, measurable, and lower friction.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        purposeMetricLegendRow("Current Score", "overall passion level")
                        purposeMetricLegendRow("Month Score", "this month's target")
                        purposeMetricLegendRow("Momentum", "direction of change")
                        purposeMetricLegendRow("Consistency", "stability over time")
                        purposeMetricLegendRow("Structure", "clarity and definition")
                        purposeMetricLegendRow("Outcomes", "outcome alignment")
                        purposeMetricLegendRow("Action blocks", "planned execution support")
                        purposeMetricLegendRow("Little Wins", "daily action follow-through")
                        purposeMetricLegendRow("Evidence", "proof of progress")
                        purposeMetricLegendRow("Carryover penalty", "unfinished work drag")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func purposeMetricLegendRow(_ title: String, _ description: String) -> some View {
        HStack(alignment: .top, spacing: 6) {
            Text("•")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            Text("\(title): \(description)")
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func nextPurposeUpdateDate(from lastUpdate: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var nextDate = calendar.date(byAdding: .month, value: 1, to: calendar.startOfDay(for: lastUpdate)) ?? today
        var guardCount = 0
        while nextDate < today && guardCount < 60 {
            nextDate = calendar.date(byAdding: .month, value: 1, to: nextDate) ?? today
            guardCount += 1
        }
        return nextDate
    }

    private func insightsDateText(_ date: Date) -> String {
        let calendar = Calendar.current
        let currentYear = calendar.component(.year, from: .now)
        let dateYear = calendar.component(.year, from: date)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = (currentYear == dateYear) ? "M/d" : "M/d/yyyy"
        return formatter.string(from: date)
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
        f.setLocalizedDateFormatFromTemplate("MMM yy")
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

    private func passionItems(for passionType: PassionType) -> [Passion] {
        switch passionType {
        case .love: return supportingData.lovePassions
        case .vows: return supportingData.vowsPassions
        case .thrill: return supportingData.thrillPassions
        case .hate: return supportingData.justPassions
        }
    }

    private func purposeStructureBreakdown(for passionType: PassionType) -> (itemCount: Int, linkCount: Int, itemCoverage: Double, linkCoverage: Double) {
        let items = passionItems(for: passionType)
        let itemIDs = Set(items.map(\.passion_id))
        let linkCount = supportingData.passionJoins.filter { itemIDs.contains($0.passion_id) }.count
        let config = PassionScoringService.Config()
        let itemCoverage = PassionScoringMath.clamped01(Double(items.count) / max(1, config.itemSaturationCount))
        let linkCoverage = PassionScoringMath.clamped01(Double(linkCount) / max(1, config.linkSaturationCount))
        return (items.count, linkCount, itemCoverage, linkCoverage)
    }

    private func purposePrimaryLever(for snap: PassionScoreSnapshot) -> AppleIntelligenceReadableInsightLeverageAnalysis {
        let structure = PassionScoringMath.clamped01(snap.structure)
        let outcomes = PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0)
        let actionBlocks = PassionScoringMath.clamped01(snap.actionCoverage)
        let littleWins = PassionScoringMath.clamped01(snap.littleWinsCoverage)
        let carryoverPenalty = PassionScoringMath.clamped01(snap.carryoverPenalty)
        let outcomesIncluded = snap.outcomeCoverage != nil
        let structureBreakdown = purposeStructureBreakdown(for: snap.passionType)

        let itemOpportunity = 0.6 * (1 - structureBreakdown.itemCoverage)
        let linkOpportunity = 0.4 * (1 - structureBreakdown.linkCoverage)
        let structureDetail: String
        let structureAction: String
        if linkOpportunity > itemOpportunity {
            structureDetail = "Fulfillment links are thinner than the passion definition."
            structureAction = "Link this passion to one supporting Fulfillment Area."
        } else {
            structureDetail = "Passion definition is thinner than fulfillment support."
            structureAction = "Tighten or add one passion entry so this theme is more specific."
        }

        var candidates: [AppleIntelligenceReadableInsightLeverageCandidate] = [
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .structure,
                currentValue: structure,
                weight: 0.15,
                reason: "Structure is the biggest setup gap for this passion, and \(structureDetail.lowercased())",
                recommendedAction: structureAction,
                detail: structureDetail,
                actionabilityPriority: 2
            ),
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .actionBlocks,
                currentValue: actionBlocks,
                weight: outcomesIncluded ? 0.25 : (0.25 + (0.30 * (0.25 / 0.45))),
                reason: "Action Blocks have the largest direct execution gap left in this score.",
                recommendedAction: "Finish one small Action Plan that directly supports this passion.",
                actionabilityPriority: 4
            ),
            AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                metric: .littleWins,
                currentValue: littleWins,
                weight: outcomesIncluded ? 0.20 : (0.20 + (0.30 * (0.20 / 0.45))),
                reason: "Little Wins are the clearest missing daily support layer for this passion.",
                recommendedAction: "Complete one repeatable Little Win tied to this passion each day.",
                actionabilityPriority: 4
            ),
            AppleIntelligenceReadableInsightLeverageEngine.dragCandidate(
                metric: .carryoverPenalty,
                currentPenalty: carryoverPenalty,
                weight: 0.10,
                reason: "Carryover penalty is erasing more score than any other drag that remains.",
                recommendedAction: "Shrink or split the Action Plan most likely to carry over.",
                actionabilityPriority: 5
            )
        ]

        if outcomesIncluded {
            candidates.append(
                AppleIntelligenceReadableInsightLeverageEngine.positiveCandidate(
                    metric: .outcomes,
                    currentValue: outcomes,
                    weight: 0.30,
                    reason: "Outcomes connected to this passion are the largest weighted gap still in the formula.",
                    recommendedAction: "Connect or refine one Outcome that this passion clearly advances.",
                    actionabilityPriority: 3
                )
            )
        }

        return AppleIntelligenceReadableInsightLeverageEngine.bestAnalysis(from: candidates)
            ?? AppleIntelligenceReadableInsightLeverageAnalysis(
                metric: .actionBlocks,
                currentValue: actionBlocks,
                displayValue: AppleIntelligenceReadableInsightLeverageEngine.percentText(actionBlocks),
                weight: 0.25,
                headroom: 1 - actionBlocks,
                opportunity: 0.25 * (1 - actionBlocks),
                reason: "Action Blocks are the clearest remaining practical lever in this score.",
                recommendedAction: "Finish one small Action Plan that directly supports this passion.",
                detail: nil,
                isMissing: false
            )
    }

    private func purposeTrendsReadableInsightPayload(for snap: PassionScoreSnapshot) -> PurposeReadableInsightRequestPayload {
        let sameMonth = selectedMonthSnapshots
        let sortedByScore = sameMonth.sorted { lhs, rhs in
            if lhs.score == rhs.score { return lhs.passionTypeRaw < rhs.passionTypeRaw }
            return lhs.score > rhs.score
        }
        let peerRank = sortedByScore.firstIndex(where: { $0.passionTypeRaw == snap.passionTypeRaw }).map { $0 + 1 }
        let strongest = sortedByScore.first
        let peerAverage = sameMonth.isEmpty ? nil : sameMonth.map(\.score).reduce(0, +) / Double(sameMonth.count)
        let movers: [(PassionScoreSnapshot, Double)] = selectedMonthSnapshots.compactMap { row in
            guard let delta = displayedDelta(for: row) else { return nil }
            return (row, roundedTenth(delta))
        }
        let biggestMover = movers.max { abs($0.1) < abs($1.1) }
        let structureBreakdown = purposeStructureBreakdown(for: snap.passionType)
        let primaryLever = purposePrimaryLever(for: snap)
        let recentScores = snapshots
            .filter { $0.passionTypeRaw == snap.passionTypeRaw }
            .sorted { $0.monthStartDate > $1.monthStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        return .init(
            isBaseline: recentScores.count <= 1,
            passionTypeRaw: snap.passionTypeRaw,
            passionTitle: passionTitle(for: snap.passionType),
            monthStartISO8601: Calendar.current.startOfDay(for: snap.monthStartDate).ISO8601Format(),
            score: roundedTenth(snap.score),
            monthScore: roundedTenth(snap.targetScore),
            monthOverMonthDelta: displayedDelta(for: snap).map(roundedTenth),
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: PassionScoringMath.clamped01(snap.structure),
            structureItemCoverage: structureBreakdown.itemCoverage,
            structureFulfillmentLinkCoverage: structureBreakdown.linkCoverage,
            structureItemCount: structureBreakdown.itemCount,
            structureFulfillmentLinkCount: structureBreakdown.linkCount,
            outcomes: PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0),
            outcomesIncludedInScore: snap.outcomeCoverage != nil,
            actionBlocks: PassionScoringMath.clamped01(snap.actionCoverage),
            littleWins: PassionScoringMath.clamped01(snap.littleWinsCoverage),
            evidence: PassionScoringMath.clamped01(snap.evidenceStable),
            carryoverPenalty: PassionScoringMath.clamped01(snap.carryoverPenalty),
            peerAverageScore: peerAverage.map(roundedTenth),
            peerRank: peerRank,
            peerCount: sameMonth.isEmpty ? nil : sameMonth.count,
            strongestPassion: strongest.map { passionTitle(for: $0.passionType) },
            strongestPassionScore: strongest.map { roundedTenth($0.score) },
            biggestMoverPassion: biggestMover.map { passionTitle(for: $0.0.passionType) },
            biggestMoverDelta: biggestMover.map { roundedTenth($0.1) },
            recentScores: recentScores,
            primaryLever: primaryLever
        )
    }

    private func aiPurposeTrendsInsightText(for snap: PassionScoreSnapshot) -> String? {
        guard AppleIntelligenceSupport.isAvailable else { return nil }
        let payload = purposeTrendsReadableInsightPayload(for: snap)
        let key = purposeReadableInsightKey(
            for: payload,
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_trends_readable_insight")
        )
        guard let base = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) else { return nil }
        return ensurePurposeReadableInsightCTA(base, payload: payload)
    }

    private func isCurrentPurposeTrendsInsightKey(_ key: String) -> Bool {
        guard let current = selectedSnapshot else { return false }
        return purposeReadableInsightKey(
            for: purposeTrendsReadableInsightPayload(for: current),
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_trends_readable_insight")
        ) == key
    }

    @MainActor
    private func requestPurposeTrendsReadableInsightIfNeeded(for snap: PassionScoreSnapshot) async {
        guard AppleIntelligenceSupport.isAvailable else { return }
        let payload = purposeTrendsReadableInsightPayload(for: snap)
        let surfaceID = "purpose_trends_readable_insight"
        let contextSignature = readableInsightContextSignature(surfaceID: surfaceID)
        let key = purposeReadableInsightKey(for: payload, contextSignature: contextSignature)
        guard !readableInsightActiveRequestKeys.contains(key) else { return }
        if !loomAIInsightsRefreshEnabled(),
           let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            readableInsightsByScoreKey[key] = cached
            readableInsightFailuresByKey[key] = nil
            return
        }
        let existingCachedInsight = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key)
        readableInsightFailuresByKey[key] = nil
        readableInsightActiveRequestKeys.insert(key)
        readableInsightLoadingKeys.insert(key)
        defer {
            readableInsightLoadingKeys.remove(key)
            readableInsightActiveRequestKeys.remove(key)
        }

        await Task.yield()
        let contextBuildStartedAt = Date()
        let appContextJSON = readableInsightAppContextJSON(surfaceID: surfaceID)
        AppDebugActivityLog.log(
            "PurposeInsights",
            "readable insight context built surface=trends key=\(key) durationMs=\(Int(Date().timeIntervalSince(contextBuildStartedAt) * 1000))"
        )

        do {
            let response = try await AppleIntelligencePurposeInsightsGenerator.readableInsightLines(
                prompt: purposeReadableInsightPrompt(
                    for: payload,
                    appContextJSON: appContextJSON
                )
            )
            guard !Task.isCancelled, isCurrentPurposeTrendsInsightKey(key) else {
                AppDebugActivityLog.log("PurposeInsights", "readable insight dropped stale response surface=trends key=\(key)")
                return
            }
            guard let trimmed = purposeReadableInsightStoredText(from: response, payload: payload) else {
                throw AppleIntelligencePurposeInsightsError.invalidResponse
            }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
            readableInsightFailuresByKey[key] = nil
            return
        } catch {
            AppDebugActivityLog.log(
                "PurposeInsights",
                "readable insight failed stage=primary surface=trends key=\(key) error=\(error.localizedDescription)"
            )
        }

        do {
            let fallbackText = try await AppleIntelligencePurposeInsightsGenerator.readableInsight(
                prompt: purposeReadableInsightFallbackPrompt(
                    for: payload,
                    appContextJSON: appContextJSON
                )
            )
            guard !Task.isCancelled, isCurrentPurposeTrendsInsightKey(key) else {
                AppDebugActivityLog.log("PurposeInsights", "readable insight dropped stale fallback surface=trends key=\(key)")
                return
            }
            let fallbackResult = AppleIntelligenceReadableInsightNormalizer.fromPlainText(fallbackText)
            guard let trimmed = purposeReadableInsightStoredText(from: fallbackResult, payload: payload) else {
                throw AppleIntelligencePurposeInsightsError.invalidResponse
            }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
            readableInsightFailuresByKey[key] = nil
        } catch {
            AppDebugActivityLog.log(
                "PurposeInsights",
                "readable insight failed stage=fallback surface=trends key=\(key) error=\(error.localizedDescription)"
            )
            guard existingCachedInsight == nil else { return }
            readableInsightFailuresByKey[key] = .init(
                stage: "fallback",
                technicalMessage: error.localizedDescription,
                userMessage: purposeReadableInsightUnavailableMessage
            )
        }
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

    private func stablePrimaryInsightMessage(for snap: PassionScoreSnapshot) -> String? {
        let key = purposeReadableInsightKey(
            for: purposeTrendsReadableInsightPayload(for: snap),
            contextSignature: readableInsightContextSignature(surfaceID: "purpose_trends_readable_insight")
        )
        if let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            return cached
        }
        return primaryInsightMessage(for: snap)
    }
}

private struct DrivingForceAnimatedInsightCallout: View {
    let message: String
    var isLoading: Bool = false

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Image("LoomAI")
                .resizable()
                .scaledToFit()
                .frame(width: 26, height: 26)
            if isLoading {
                LoomAIReadableInsightTypingDotsIndicator()
                    .frame(height: 20)
            } else {
                Text(styledMessage)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(10)
        .overlay(
            LoomAIReadableInsightAnimatedOutlineBorder(cornerRadius: 12)
        )
    }

    private var styledMessage: AttributedString {
        var attributed = AttributedString(message)
        applyPurposeInsightMetricItalics(to: &attributed)
        return attributed
    }
}

private struct PurposeLoomTypingDotsIndicator: View {
    var body: some View {
        LoomAIReadableInsightTypingDotsIndicator()
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
    let dismissCommitSignal: Int
    let onAddStateChange: (AddState) -> Void
    let onActiveFieldTextChange: (String?) -> Void
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
                    set: {
                        onAddStateChange(addStateWithNewText($0))
                        if focusedField == .passion(category.emotion) {
                            onActiveFieldTextChange($0)
                        }
                    }
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
                    TextField("Edit passion", text: Binding(
                        get: { editText },
                        set: {
                            editText = $0
                            if focusedField == .passion(category.emotion) {
                                onActiveFieldTextChange($0)
                            }
                        }
                    ))
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
            if newValue == .passion(category.emotion) {
                let currentText = editingPassion != nil ? editText : addState.newText
                onActiveFieldTextChange(currentText)
            } else {
                onActiveFieldTextChange(nil)
            }
            // If focus leaves this category's inline add field, collapse back to "Add Item".
            guard addState.isAdding else { return }
            if newValue != .passion(category.emotion) {
                onAddStateChange(AddState())
            }
        }
        .onChange(of: dismissCommitSignal) { _, _ in
            guard focusedField == .passion(category.emotion) else { return }
            if let editingPassion {
                commitEdit(passion: editingPassion)
                return
            }
            if addState.isAdding {
                onCommit(addState.newText)
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
        onActiveFieldTextChange(passion.passion)
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

#Preview {
    NavigationStack {
        PurposeView(autoOpenCreateVision: false)
    }
    .loomPreviewContainer()
}
