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
    let passionTypeRaw: String
    let passionTitle: String
    let monthStartISO8601: String
    let score: Double
    let monthScore: Double
    let monthOverMonthDelta: Double?
    let momentum: Double
    let consistency: Double
    let structure: Double
    let outcomes: Double
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
}

fileprivate func purposeReadableInsightScoreKey(for snap: PassionScoreSnapshot) -> String {
    [
        "v2",
        snap.passionTypeRaw,
        Calendar.current.startOfDay(for: snap.monthStartDate).ISO8601Format(),
        String((snap.score * 10).rounded() / 10),
        String((snap.targetScore * 10).rounded() / 10),
        String((snap.momentum * 10).rounded() / 10),
        String((snap.consistency * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.structure) * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0) * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.actionCoverage) * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.littleWinsCoverage) * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.evidenceStable) * 10).rounded() / 10),
        String((PassionScoringMath.clamped01(snap.carryoverPenalty) * 10).rounded() / 10)
    ].joined(separator: "|")
}

fileprivate func purposeReadableInsightPrompt(for payload: PurposeReadableInsightRequestPayload) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let payloadJSON = ((try? encoder.encode(payload)).flatMap { String(data: $0, encoding: .utf8) }) ?? "{}"

    return """
    Create a readable insight for one Purpose passion in Loom Purpose Insights.

    Requirements:
    - Use APP_CONTEXT plus the purpose passion insight payload below.
    - Return exactly TWO short lines:
      1) one high-value insight sentence (not a recap of obvious values already shown in the UI)
      2) one very short practical call to action the user can do in Loom to improve
    - Separate the lines with a newline.
    - Keep the total under 220 characters and end each line as a complete sentence.
    - No questions, no filler.
    - Prefer the strongest supported interpretation from the available data.
    - Do not mention the passion name directly (the UI already shows it).
    - If you reference an insight metric, use the exact label and include the displayed value in parentheses.
    - Use (X%) for percentage-based metrics and score components.
    - If referencing Momentum or Consistency, use the displayed descriptor in parentheses (e.g., Momentum (Improving), Consistency (Stable)).
    - Use these labels verbatim when referenced: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Evidence, Carryover penalty.
    - If this payload has only one record (recentScores has 1 value), line 1 must explain this is a baseline month where trend/mover signals are not established yet.
    - In that one-record case, line 2 must be a starter action focused on improving score foundations (Structure, Action Blocks, Little Wins, Evidence).
    - Consider the full range of useful interpretations (choose the best fit):
      - month-over-month trend / momentum shift
      - consistency/volatility pattern
      - strong structure but weak action support
      - strong daily support but weak outcome coverage
      - carryover penalty dragging score
      - evidence stability strength/weakness
      - imbalance across support signals
      - peer-relative position (strongest / mover / rank)
    - Do not invent values.
    - Return only the readable insight text in the message field.

    Purpose passion insight payload JSON:
    \(payloadJSON)
    """
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
        .replacingOccurrences(of: "Action Block ", with: "Action Blocks ")
        .replacingOccurrences(of: "action block ", with: "Action Blocks ")
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

    return ensurePurposeReadableInsightCTA(
        repairPurposeReadableInsightLineIfNeeded(output, payload: payload),
        payload: payload
    )
}

fileprivate func isPurposeSingleRecordPayload(_ payload: PurposeReadableInsightRequestPayload) -> Bool {
    payload.recentScores.count <= 1
}

fileprivate func startupPurposeTechnicalLine(payload: PurposeReadableInsightRequestPayload) -> String {
    let weakest = [
        ("Action Blocks", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Evidence", payload.evidence),
        ("Structure", payload.structure),
        ("Outcomes", payload.outcomes)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Blocks"
    return "Baseline month only: trend and mover signals are not established yet; score gains depend on strengthening \(weakest)."
}

fileprivate func startupPurposePracticalLine(payload: PurposeReadableInsightRequestPayload) -> String {
    let weakest = [
        ("Action Blocks", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Evidence", payload.evidence),
        ("Structure", payload.structure),
        ("Outcomes", payload.outcomes)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Blocks"

    switch weakest {
    case "Action Blocks":
        return "Add one small Action Block tied to this passion this week."
    case "Little Wins":
        return "Add one repeatable Little Win tied to this passion and complete it daily."
    case "Evidence":
        return "Tag one completed action to this passion to build evidence."
    case "Structure":
        return "Refine this passion wording to make it clearer and more specific."
    case "Outcomes":
        return "Connect one Outcome that directly supports this passion."
    default:
        return "Add one Action Block and one Little Win tied to this passion."
    }
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

    if isPurposeSingleRecordPayload(payload) {
        let first = startupPurposeTechnicalLine(payload: payload)
        let cta = normalizePurposeReadableInsightCTALine(startupPurposePracticalLine(payload: payload))
        return first + "\n\n" + cta + (cta.hasSuffix(".") ? "" : ".")
    }

    guard let first = lines.first else {
        let cta = normalizePurposeReadableInsightCTALine(defaultPurposeReadableInsightCTA(payload: payload))
        return cta + (cta.hasSuffix(".") ? "" : ".")
    }
    if lines.count >= 2 {
        let cta = normalizePurposeReadableInsightCTALine(lines[1])
        return first + "\n\n" + cta
    }
    let cta = normalizePurposeReadableInsightCTALine(defaultPurposeReadableInsightCTA(payload: payload))
    return first + "\n\n" + cta + (cta.hasSuffix(".") ? "" : ".")
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
    func pct(_ value: Double) -> String { "\(Int((PassionScoringMath.clamped01(value) * 100).rounded()))%" }
    let structure = payload.structure
    let outcomes = payload.outcomes
    let actionBlocks = payload.actionBlocks
    let littleWins = payload.littleWins
    let evidence = payload.evidence
    let carry = payload.carryoverPenalty

    if carry >= 0.4 {
        return "Carryover penalty (\(pct(carry))) is suppressing progress despite stronger support signals."
    }
    if outcomes >= 0.8 && actionBlocks < 0.6 {
        return "Outcomes (\(pct(outcomes))) are strong, but Action Blocks (\(pct(actionBlocks))) need more consistent follow-through."
    }
    if actionBlocks >= 0.7 && littleWins + 0.18 < actionBlocks {
        return "Action Blocks (\(pct(actionBlocks))) are stronger than Little Wins (\(pct(littleWins))), reducing daily support."
    }
    if evidence < 0.6 && (structure >= 0.7 || outcomes >= 0.7) {
        return "Evidence (\(pct(evidence))) is lagging stronger Structure (\(pct(structure))) and Outcomes (\(pct(outcomes)))."
    }
    if littleWins < 0.55 {
        return "Little Wins (\(pct(littleWins))) are the weakest support signal for sustaining this passion."
    }
    return "Action Blocks (\(pct(actionBlocks))) are the clearest practical lever to improve this passion."
}

fileprivate func defaultPurposeReadableInsightCTA(payload: PurposeReadableInsightRequestPayload) -> String {
    if payload.carryoverPenalty >= 0.4 {
        return "Balance only adding essential actions and completing more actions"
    }
    if payload.littleWins + 0.12 < payload.actionBlocks && payload.littleWins < 0.55 {
        return "Complete more Little Wins and Action Blocks"
    }
    let weakest = [
        ("Action Blocks", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Outcomes", payload.outcomes),
        ("Evidence", payload.evidence),
        ("Structure", payload.structure)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Blocks"

    switch weakest {
    case "Action Blocks":
        return "Add one Action Block tied to this passion"
    case "Little Wins":
        return "Add or revise one Little Win for this passion"
    case "Outcomes":
        return "Connect an Outcome that supports this passion"
    case "Evidence":
        return "Tag completed work to strengthen evidence"
    case "Structure":
        return "Refine your Vision or passion wording"
    default:
        return "Improve one weak support signal for this passion"
    }
}

fileprivate func normalizePurposeReadableInsightCTALine(_ line: String) -> String {
    var output = line.trimmingCharacters(in: .whitespacesAndNewlines)
    output = output.replacingOccurrences(of: #"^(?i)in loom,\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(of: #"^(?i)in loom\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(of: "Action Block ", with: "Action Blocks ")
    output = output.replacingOccurrences(of: "action block ", with: "Action Blocks ")
    output = output.replacingOccurrences(
        of: #"(?i)shorten or split one Action Blocks? to reduce carryover"#,
        with: "Balance only adding essential actions and completing more actions",
        options: .regularExpression
    )
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
    @State private var drivingForceHeaderInsightOutlineAngle: Double = 0
    @State private var readableInsightsByScoreKey: [String: String] = [:]
    @State private var readableInsightLoadingKeys: Set<String> = []
    @State private var showDeletePassionHint = false
    @State private var deletePassionHintText = ""
    @State private var deletePassionHintWorkItem: DispatchWorkItem?
    @State private var keyboardHeight: CGFloat = 0
    @State private var keyboardDismissCommitSignal: Int = 0
    @State private var autoWriteVisionSuggestions: [String] = []
    @State private var autoWritePassionSuggestions: [AutoWritePassionSuggestion] = []
    @State private var isAutoWritingVision = false
    @State private var isAutoWritingPassions = false
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
        if !suggestions.isEmpty {
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
                }
                .padding(.top, 2)
                .padding(.bottom, 2)
            }
            .listRowInsets(EdgeInsets(top: 2, leading: 16, bottom: 2, trailing: 16))
            .listRowBackground(Color.clear)
        }
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
            DrivingForceTrendsView(snapshots: passionScoreSnapshots)
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
                    let insightKey = purposeReadableInsightScoreKey(for: snap)
                    let summaryInsight = purposeReadableInsightCTAParagraph(aiPurposeHeaderInsightText(for: snap))
                    let isLoadingInsight = readableInsightLoadingKeys.contains(insightKey)
                    if isLoadingInsight || summaryInsight != nil {
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
                    Group {
                        if isLoadingInsight {
                            HStack(spacing: 8) {
                                Image("LoomAI")
                                    .resizable()
                                    .scaledToFit()
                                    .frame(width: 32, height: 32)
                                PurposeLoomTypingDotsIndicator()
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        } else if let summaryInsight {
                            PurposeInlineInsightText(
                                imageName: "LoomAI",
                                text: summaryInsight,
                                font: UIFont.preferredFont(forTextStyle: .footnote),
                                textColor: UIColor.label,
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
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(loomAIGradient.opacity(0.95), lineWidth: 2)
                    )
                    }
                    Color.clear
                        .frame(width: 0, height: 0)
                        .task(id: purposeReadableInsightScoreKey(for: snap)) {
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
            drivingForceHeaderInsightOutlineAngle = 0
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
        let monthStart = PassionScoringMath.monthWindow(for: .now).monthStart
        return latestPassionSnapshot(for: passionType, monthStart: monthStart)
    }

    private func previousMonthlyPassionSnapshot(for emotionKey: String) -> PassionScoreSnapshot? {
        guard let passionType = passionType(forEmotionKey: emotionKey) else { return nil }
        let currentMonthStart = PassionScoringMath.monthWindow(for: .now).monthStart
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
        let monthStart = PassionScoringMath.monthWindow(for: .now).monthStart
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
        let best = deltas.max(by: { abs($0.1) < abs($1.1) })
        if let best, abs(best.1) < 0.05 { return nil }
        return best
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
        let recentScores = passionScoreSnapshots
            .filter { $0.passionTypeRaw == snap.passionTypeRaw }
            .sorted { $0.monthStartDate > $1.monthStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        return .init(
            passionTypeRaw: snap.passionTypeRaw,
            passionTitle: passionHeaderTitle(for: emotionKey(for: snap.passionType)),
            monthStartISO8601: monthStart.ISO8601Format(),
            score: roundedTenth(snap.score),
            monthScore: roundedTenth(snap.targetScore),
            monthOverMonthDelta: passionMonthOverMonthDelta(for: emotionKey(for: snap.passionType)).map(roundedTenth),
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: PassionScoringMath.clamped01(snap.structure),
            outcomes: PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0),
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
            recentScores: recentScores
        )
    }

    private func aiPurposeHeaderInsightText(for snap: PassionScoreSnapshot) -> String? {
        let key = purposeReadableInsightScoreKey(for: snap)
        guard let base = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) else { return nil }
        let payload = purposeHeaderReadableInsightPayload(for: snap)
        return ensurePurposeReadableInsightCTA(base, payload: payload)
    }

    @MainActor
    private func requestPurposeHeaderReadableInsightIfNeeded(for snap: PassionScoreSnapshot) async {
        let key = purposeReadableInsightScoreKey(for: snap)
        if !loomAIInsightsRefreshEnabled(),
           let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            readableInsightsByScoreKey[key] = cached
            return
        }
        readableInsightLoadingKeys.insert(key)
        defer { readableInsightLoadingKeys.remove(key) }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: self.context)
            let payload = purposeHeaderReadableInsightPayload(for: snap)
            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: purposeReadableInsightPrompt(for: payload))],
                context: contextSnapshot
            )
            let normalized = normalizePurposeReadableInsightMetricReferences(response.message, payload: payload)
            let text = limitPurposeReadableInsightText(normalized, maxCharacters: 220)
            let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
        } catch {
            // Keep local heuristic fallback visible if API is unavailable.
        }
    }

    private func stableDrivingForceHeaderInsightMessage(for snap: PassionScoreSnapshot) -> String? {
        let key = purposeReadableInsightScoreKey(for: snap)
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
        autoWriteVisionSuggestions = []

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: context)
            let previousSuggestionsContext = previousSuggestions.isEmpty
                ? "No prior suggestions."
                : "Prior suggestions to avoid repeating: \(previousSuggestions.joined(separator: " | "))"
            let modeInstruction: String
            switch selectedVisionAutoWriteMode {
            case .newVision:
                modeInstruction = "Vision mode: New Vision. Generate fresh vision suggestions from context."
            case .rewordVision:
                modeInstruction = "Vision mode: Reword Vision. Improve and reword the current vision while preserving its core intent and direction."
            }
            let instruction = """
            You are helping with Loom Purpose Vision (AutoWrite).
            \(modeInstruction)
            Current Vision: \(visionTrimmed.isEmpty ? "<empty>" : visionTrimmed)
            \(previousSuggestionsContext)

            Vision guidance to follow:
            - If there were no limits, what life would you create?
            - This is not a goal. It's long-term direction.
            - Keep wording clear, practical, and specific.
            - If mode is Reword Vision and Current Vision is not empty, prioritize improving clarity/strength while keeping the same meaning.
            - If mode is Reword Vision but Current Vision is empty, fall back to New Vision behavior.
            - If mode is New Vision and Current Vision is not empty, suggestions must be meaningfully different from Current Vision.

            Return JSON only:
            {"suggestions":["string"],"confidence":"high|medium|low"}

            Rules:
            - Return 1-2 suggestions.
            - each suggestion must be <=150 characters
            - no numbering, no bullets
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWriteVisionSuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }
            let filtered = suggestions.filter { suggestion in
                let normalized = normalizedVisionSuggestion(suggestion)
                if previousSuggestions.contains(where: { normalizedVisionSuggestion($0) == normalized }) {
                    return false
                }
                if selectedVisionAutoWriteMode == .newVision &&
                    isVisionSuggestionTooSimilarToCurrentVision(suggestion) {
                    return false
                }
                return true
            }
            let nextSuggestions = Array(filtered.prefix(2))
            guard !nextSuggestions.isEmpty else { return }
            autoWriteVisionSuggestions = nextSuggestions
        } catch {
            return
        }
    }

    private func requestAutoWritePassionSuggestions() async {
        let previousSuggestions = autoWritePassionSuggestions
        isAutoWritingPassions = true
        defer { isAutoWritingPassions = false }
        autoWritePassionSuggestions = []

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: context)
            let selectedFilterInstruction: String = {
                if selectedPassionAutoWriteFilter == .all {
                    return "Selected filter: All (suggest across buckets)."
                }
                return "Selected filter: \(selectedPassionAutoWriteFilter.label) only. Return only that bucket."
            }()
            let currentPassions = passionQueries
                .map { bucket in
                    let items = currentPassionValues(for: bucket.emotion).joined(separator: " | ")
                    return "- \(bucketTitle(for: bucket.emotion)): \(items.isEmpty ? "<empty>" : items)"
                }
                .joined(separator: "\n")
            let previousContext = previousSuggestions.isEmpty
                ? "No prior suggestions."
                : "Prior suggestions to avoid repeating: \(previousSuggestions.map { "\(bucketTitle(for: $0.emotion)): \($0.passion)" }.joined(separator: " | "))"

            let instruction = """
            You are helping with Loom Purpose Passions (AutoWrite).
            \(selectedFilterInstruction)
            Current passions by bucket:
            \(currentPassions)
            \(previousContext)

            Use this Loom guidance from the PurposeView graduation-cap instructions sheet and Need ideas section:
            - Love examples: Time with family and close relationships; Learning, growth, and self-improvement; Building and creating something meaningful.
            - Vows (commitments) examples: Always act with integrity; Take full responsibility for my life; Keep growing and becoming better.
            - Thrill examples: Achieving difficult goals; Solving hard problems; Taking risks and pursuing new opportunities.
            - Hate examples: Wasted potential; Dishonesty and manipulation; Laziness and excuses.
            - Passions should reflect stable values, commitments, and direction.

            Return JSON only:
            {"suggestions":[{"emotion":"love|vows|thrill|just","passion":"string"}],"confidence":"high|medium|low"}

            Rules:
            - Return 2-4 suggestions.
            - Keep each passion to 1-5 words. Fewer words is preferred.
            - Keep wording concrete, strong, and value-driven.
            - Use the provided bucket context and existing items to improve quality.
            - Never repeat, paraphrase, or lightly reword existing bucket items.
            - Avoid semantic overlap with current items (must be clearly distinct concepts).
            - Prefer direct noun phrases; avoid verb-led formats like "Rejecting ...", "Challenging ...", "Avoiding ...".
            - Suggestions must make sense as standalone passion items.
            - Prefer variety across buckets when possible.
            - No numbering, no bullets, no markdown.
            """

            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: instruction)],
                context: contextSnapshot
            )
            let suggestions = decodeAutoWritePassionSuggestions(from: response.message)
            guard !suggestions.isEmpty else { return }

            let bucketFiltered = suggestions.filter { suggestion in
                if selectedPassionAutoWriteFilter == .all { return true }
                return suggestion.emotion == selectedPassionAutoWriteFilter.rawValue
            }
            let sourceSuggestions = (bucketFiltered.isEmpty ? suggestions : bucketFiltered).filter {
                !isPassionSuggestionTooSimilarToExisting($0)
            }
            guard !sourceSuggestions.isEmpty else { return }

            let nextSuggestions = sourceSuggestions.filter { suggestion in
                let normalized = normalizedVisionSuggestion(suggestion.passion)
                let wasSuggestedBefore = previousSuggestions.contains {
                    $0.emotion == suggestion.emotion && normalizedVisionSuggestion($0.passion) == normalized
                }
                return !wasSuggestedBefore
            }
            autoWritePassionSuggestions = Array((nextSuggestions.isEmpty ? sourceSuggestions : nextSuggestions).prefix(4))
        } catch {
            return
        }
    }

    private func decodeAutoWriteVisionSuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(PurposeVisionAutoWriteResponse.self, from: data) {
            return Array((parsed.suggestions ?? [])
                .map { truncateSuggestion($0, maxLength: 150) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
                .prefix(2))
        }
        return Array(trimmed
            .components(separatedBy: "\n")
            .map { truncateSuggestion($0, maxLength: 150).trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .prefix(2))
    }

    private func decodeAutoWritePassionSuggestions(from raw: String) -> [AutoWritePassionSuggestion] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(PurposePassionsAutoWriteResponse.self, from: data) {
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
        let limited = words.prefix(5).joined(separator: " ")
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
        let passion = Passion(date: .now, emotion: suggestion.emotion, passion: suggestion.passion)
        context.insert(passion)
        try? context.save()
        refreshPassionScoresForCurrentMonthIfNeeded(force: true)
    }

    private func isPassionSuggestionTooSimilarToExisting(_ suggestion: AutoWritePassionSuggestion) -> Bool {
        let existing = currentPassionValues(for: suggestion.emotion)
        let suggestionNorm = normalizedVisionSuggestion(suggestion.passion)
        let suggestionTokens = Set(suggestionNorm.split(separator: " ").map(String.init))

        for item in existing {
            let itemNorm = normalizedVisionSuggestion(item)
            if itemNorm.isEmpty { continue }
            if itemNorm == suggestionNorm { return true }
            if suggestionNorm.contains(itemNorm) || itemNorm.contains(suggestionNorm) { return true }
            let itemTokens = Set(itemNorm.split(separator: " ").map(String.init))
            if !itemTokens.isEmpty {
                let overlapCount = suggestionTokens.intersection(itemTokens).count
                let overlapRatio = Double(overlapCount) / Double(max(1, min(suggestionTokens.count, itemTokens.count)))
                if overlapRatio >= 0.6 { return true }
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
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
    }

    private func isVisionSuggestionTooSimilarToCurrentVision(_ suggestion: String) -> Bool {
        let current = normalizedVisionSuggestion(visionTextDraft)
        let candidate = normalizedVisionSuggestion(suggestion)
        guard !current.isEmpty, !candidate.isEmpty else { return false }

        if current == candidate { return true }
        if current.contains(candidate) || candidate.contains(current) { return true }

        let currentTokens = Set(current.split(whereSeparator: \.isWhitespace).map(String.init))
        let candidateTokens = Set(candidate.split(whereSeparator: \.isWhitespace).map(String.init))
        guard !currentTokens.isEmpty, !candidateTokens.isEmpty else { return false }
        let overlap = currentTokens.intersection(candidateTokens).count
        let overlapRatio = Double(overlap) / Double(max(1, min(currentTokens.count, candidateTokens.count)))
        return overlapRatio >= 0.8
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

private struct PurposeInlineInsightText: UIViewRepresentable {
    let imageName: String
    let text: String
    let font: UIFont
    let textColor: UIColor
    let imageSize: CGSize

    private let imageTag = 9_431
    private let imageTextSpacing: CGFloat = 8

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

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    let snapshots: [PassionScoreSnapshot]

    @State private var selectedTimeline: TimelineOption = .all
    @State private var selectedMonthRaw: Date?
    @State private var selectedPassionTypeRaw: String?
    @State private var trendsContentIsReady = false
    @State private var readableInsightsByScoreKey: [String: String] = [:]
    @State private var readableInsightLoadingKeys: Set<String> = []

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
        return latestSnapshotsByPassion(monthStart: latestMonthStart)
    }

    private var selectedMonthSnapshots: [PassionScoreSnapshot] {
        guard let selectedMonthStart else { return latestMonthSnapshots }
        return latestSnapshotsByPassion(monthStart: selectedMonthStart)
    }

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
        guard let result else { return nil }
        if abs(result.1) < 0.05 { return nil }

        // Match Strongest's tie-handling behavior, but only blank when 3+ tie on movement magnitude.
        let topMagnitude = abs(roundedTenth(result.1))
        let tieCount = deltas.filter { abs(roundedTenth($0.1)) == topMagnitude }.count
        if tieCount >= 3 { return nil }

        return result
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

    private var shouldShowBaselineMethodologyCard: Bool {
        guard let snap = selectedSnapshot else { return false }
        return purposeTrendsReadableInsightPayload(for: snap).recentScores.count <= 1
    }

    private var baselineMethodologyCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(Color.orange)
                Text("Baseline Mode")
                    .font(.subheadline.weight(.semibold))
            }

            Text("Loom is establishing your first Purpose baseline from score foundations like Structure, Outcomes, Action Blocks, Little Wins, and Evidence.")
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            Text("Purpose Insights update monthly, so long-term direction and momentum become clearer over time.")
                .font(.footnote)
                .foregroundStyle(.secondary)
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
                let insightKey = purposeReadableInsightScoreKey(for: snap)
                let message = aiPurposeTrendsInsightText(for: snap)
                let isLoadingInsight = readableInsightLoadingKeys.contains(insightKey)
                if isLoadingInsight || message != nil {
                    DrivingForceAnimatedInsightCallout(message: message ?? "", isLoading: isLoadingInsight)
                }
                Color.clear
                    .frame(width: 0, height: 0)
                    .task(id: insightKey) {
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
        let recentScores = snapshots
            .filter { $0.passionTypeRaw == snap.passionTypeRaw }
            .sorted { $0.monthStartDate > $1.monthStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        return .init(
            passionTypeRaw: snap.passionTypeRaw,
            passionTitle: passionTitle(for: snap.passionType),
            monthStartISO8601: Calendar.current.startOfDay(for: snap.monthStartDate).ISO8601Format(),
            score: roundedTenth(snap.score),
            monthScore: roundedTenth(snap.targetScore),
            monthOverMonthDelta: displayedDelta(for: snap).map(roundedTenth),
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: PassionScoringMath.clamped01(snap.structure),
            outcomes: PassionScoringMath.clamped01(snap.outcomeCoverage ?? 0),
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
            recentScores: recentScores
        )
    }

    private func aiPurposeTrendsInsightText(for snap: PassionScoreSnapshot) -> String? {
        let key = purposeReadableInsightScoreKey(for: snap)
        guard let base = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) else { return nil }
        let payload = purposeTrendsReadableInsightPayload(for: snap)
        return ensurePurposeReadableInsightCTA(base, payload: payload)
    }

    @MainActor
    private func requestPurposeTrendsReadableInsightIfNeeded(for snap: PassionScoreSnapshot) async {
        let key = purposeReadableInsightScoreKey(for: snap)
        if !loomAIInsightsRefreshEnabled(),
           let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            readableInsightsByScoreKey[key] = cached
            return
        }
        readableInsightLoadingKeys.insert(key)
        defer { readableInsightLoadingKeys.remove(key) }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let payload = purposeTrendsReadableInsightPayload(for: snap)
            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: purposeReadableInsightPrompt(for: payload))],
                context: contextSnapshot
            )
            let normalized = normalizePurposeReadableInsightMetricReferences(response.message, payload: payload)
            let text = limitPurposeReadableInsightText(normalized, maxCharacters: 220)
            let trimmed = text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            readableInsightsByScoreKey[key] = trimmed
            PurposeReadableInsightRuntimeStore.set(trimmed, for: key)
        } catch {
            // Keep local heuristic fallback visible if API is unavailable.
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
        let key = purposeReadableInsightScoreKey(for: snap)
        if let cached = readableInsightsByScoreKey[key] ?? PurposeReadableInsightRuntimeStore.value(for: key) {
            return cached
        }
        return primaryInsightMessage(for: snap)
    }
}

private struct DrivingForceAnimatedInsightCallout: View {
    let message: String
    var isLoading: Bool = false
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
            if isLoading {
                PurposeLoomTypingDotsIndicator()
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
            RoundedRectangle(cornerRadius: 12)
                .stroke(outlineGradient.opacity(0.95), lineWidth: 2)
        )
        .onAppear {
            outlineAngle = 0
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                outlineAngle = 360
            }
        }
    }

    private var styledMessage: AttributedString {
        var attributed = AttributedString(message)
        applyPurposeInsightMetricItalics(to: &attributed)
        return attributed
    }
}

private struct PurposeLoomTypingDotsIndicator: View {
    @State private var activeIndex: Int = 0

    private let colors: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95)
    ]

    var body: some View {
        HStack(spacing: 5) {
            ForEach(Array(colors.enumerated()), id: \.offset) { idx, color in
                Circle()
                    .fill(color.opacity(activeIndex == idx ? 1 : 0.35))
                    .frame(width: 6, height: 6)
                    .scaleEffect(activeIndex == idx ? 1.15 : 0.9)
                    .animation(.easeInOut(duration: 0.2), value: activeIndex)
            }
        }
        .onAppear {
            guard activeIndex == 0 else { return }
            animate()
        }
    }

    private func animate() {
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            activeIndex = (activeIndex + 1) % colors.count
            animate()
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
