import SwiftUI
import SwiftData
import Charts
#if canImport(FamilyControls)
import FamilyControls
#endif

#Preview {
    NavigationStack {
        FulfillmentView()
    }
    .loomPreviewContainer()
}
#if canImport(UIKit)
import UIKit
#endif

fileprivate struct CategoryDef: Identifiable {
    let id: String
    let title: String
    let categoryID: UUID
}

fileprivate let defaultCategoryDefs: [CategoryDef] = [
    .init(id: "career",     title: "Career & Business",    categoryID: PlanLabelSeeder.categoryIDs["Career & Business"]!),
    .init(id: "leadership", title: "Leadership & Impact",  categoryID: PlanLabelSeeder.categoryIDs["Leadership & Impact"]!),
    .init(id: "wealth",     title: "Wealth & Lifestyle",   categoryID: PlanLabelSeeder.categoryIDs["Wealth & Lifestyle"]!),
    .init(id: "mind",       title: "Mind & Meaning",       categoryID: PlanLabelSeeder.categoryIDs["Mind & Meaning"]!),
    .init(id: "love",       title: "Love & Relationships", categoryID: PlanLabelSeeder.categoryIDs["Love & Relationships"]!),
    .init(id: "health",     title: "Health & Vitality",    categoryID: PlanLabelSeeder.categoryIDs["Health & Vitality"]!),
]

fileprivate let defaultFulfillmentCategoryTitles: [String] = [
    "Area 1", "Area 2", "Area 3", "Area 4", "Area 5", "Area 6"
]

fileprivate let loomAIInsightsRefreshToggleDefaultsKey = "loom.enableLoomAIInsightsRefresh"

fileprivate func loomAIInsightsRefreshEnabled() -> Bool {
    UserDefaults.standard.bool(forKey: loomAIInsightsRefreshToggleDefaultsKey)
}

fileprivate struct FulfillmentReadableInsightRequestPayload: Codable {
    let categoryID: UUID
    let categoryTitle: String
    let weekStartISO8601: String
    let score: Double
    let weekScore: Double
    let weekOverWeekDelta: Double?
    let momentum: Double
    let consistency: Double
    let structure: Double
    let outcomes: Double
    let actionBlocks: Double
    let littleWins: Double
    let engagement: Double
    let strategicBehavior: Double
    let carryoverPenalty: Double
    let peerAverageScore: Double?
    let peerRank: Int?
    let peerCount: Int?
    let strongestCategory: String?
    let strongestCategoryScore: Double?
    let biggestMoverCategory: String?
    let biggestMoverDelta: Double?
    let recentCategoryScores: [Double]
}

@MainActor
fileprivate enum FulfillmentReadableInsightRuntimeStore {
    private static let defaultsPrefix = "loom.fulfillmentReadableInsight."
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

fileprivate func fulfillmentReadableInsightKey(for payload: FulfillmentReadableInsightRequestPayload) -> String {
    struct ScoreSignature: Codable {
        let categoryID: UUID
        let weekStartISO8601: String
        let score: Double
        let weekScore: Double
        let weekOverWeekDelta: Double?
        let momentum: Double
        let consistency: Double
        let structure: Double
        let outcomes: Double
        let actionBlocks: Double
        let littleWins: Double
        let engagement: Double
        let strategicBehavior: Double
        let carryoverPenalty: Double
    }

    let signature = ScoreSignature(
        categoryID: payload.categoryID,
        weekStartISO8601: payload.weekStartISO8601,
        score: payload.score,
        weekScore: payload.weekScore,
        weekOverWeekDelta: payload.weekOverWeekDelta,
        momentum: payload.momentum,
        consistency: payload.consistency,
        structure: payload.structure,
        outcomes: payload.outcomes,
        actionBlocks: payload.actionBlocks,
        littleWins: payload.littleWins,
        engagement: payload.engagement,
        strategicBehavior: payload.strategicBehavior,
        carryoverPenalty: payload.carryoverPenalty
    )
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    if let data = try? encoder.encode(signature),
       let string = String(data: data, encoding: .utf8) {
        return string
    }
    return "\(payload.categoryID.uuidString)|\(payload.weekStartISO8601)|\(payload.score)|\(payload.weekScore)"
}

fileprivate func fulfillmentReadableInsightPrompt(for payload: FulfillmentReadableInsightRequestPayload) -> String {
    let encoder = JSONEncoder()
    encoder.outputFormatting = [.sortedKeys]
    let payloadJSON: String
    if let data = try? encoder.encode(payload), let string = String(data: data, encoding: .utf8) {
        payloadJSON = string
    } else {
        payloadJSON = "{}"
    }

    return """
    Create a readable insight for one Fulfillment Area in Loom Fulfillment Insights.

    Requirements:
    - Use APP_CONTEXT plus the fulfillment insight payload below.
    - Return exactly TWO short lines:
      1) one high-value insight sentence (not a recap of obvious values already shown in the UI)
      2) one very short practical call to action the user can do in Loom to improve
    - Separate the lines with a newline.
    - Keep the total under 220 characters and end each line as a complete sentence.
    - No questions, no filler.
    - Prefer the most meaningful interpretation based on evidence.
    - If you reference an insight metric, use the exact label and include the displayed value in parentheses.
    - Use (X%) for percentage-based metrics and score components.
    - If referencing Momentum or Consistency, use the displayed descriptor in parentheses (e.g., Momentum (Improving), Consistency (Mixed)).
    - If referencing area rank, format it as area rank (X of Y), not just area rank (X).
    - Use these labels verbatim when referenced: Momentum, Consistency, Structure, Outcomes, Action Blocks, Little Wins, Engagement, Strategic Behavior, Carryover penalty.
    - If this payload has only one record (recentCategoryScores has 1 value), line 1 must explain this is a baseline week where trend/mover signals are not established yet.
    - In that one-record case, line 2 must be a starter action focused on improving score foundations (Structure, Action Blocks, Little Wins, Engagement).
    - Do not append duplicate raw score values after a metric reference (for example, avoid "Action Blocks (50%) score (0.5)").
    - If Outcomes is high, do not describe an "execution gap in achieving Outcomes"; frame it as a sustainability/support mismatch instead.
    - Valid interpretation types include (choose the best fit):
      - score trend / week-over-week change
      - momentum vs consistency mismatch
      - strong structure but weak action blocks
      - strong execution but weak outcomes conversion
      - little wins vs action blocks imbalance
      - strategic behavior weakness despite activity
      - carryover penalty dragging score
      - strong performance sustained vs peers
      - peer-relative context (strongest / mover / rank)
    - Do not mention the fulfillment area name (the UI already shows it).
    - Do not invent values.
    - Return only the readable insight text in the message field.

    Fulfillment insight payload JSON:
    \(payloadJSON)
    """
}

fileprivate func limitFulfillmentReadableInsightText(_ text: String, maxCharacters: Int = 150) -> String {
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

fileprivate func fulfillmentReadableInsightCTAParagraph(_ text: String?) -> String? {
    guard let text else { return nil }
    let parts = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .components(separatedBy: "\n")
        .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }
    return parts.last
}

fileprivate func fulfillmentReadableInsightMomentumDescriptor(_ value: Double) -> String {
    let v = FulfillmentScoringMath.clamp(value, -1, 1)
    if abs(v) < 0.12 { return "Stable" }
    return v > 0 ? "Improving" : "Declining"
}

fileprivate func fulfillmentReadableInsightConsistencyDescriptor(_ value: Double) -> String {
    let v = FulfillmentScoringMath.clamp(value, 0, 1)
    if v >= 0.75 { return "Stable" }
    if v >= 0.4 { return "Mixed" }
    return "Volatile"
}

fileprivate func normalizeFulfillmentReadableInsightMetricReferences(
    _ text: String,
    payload: FulfillmentReadableInsightRequestPayload
) -> String {
    var output = text
        .replacingOccurrences(of: "Enagement", with: "Engagement")
        .replacingOccurrences(of: "enagement", with: "Engagement")
        .replacingOccurrences(of: "Action Block ", with: "Action Plan ")
        .replacingOccurrences(of: "action block ", with: "Action Plan ")
        .replacingOccurrences(of: "acieving", with: "achieving")

    func pct(_ value: Double) -> String {
        "\(Int((FulfillmentScoringMath.clamped01(value) * 100).rounded()))%"
    }

    let replacements: [(label: String, value: String)] = [
        ("Momentum", fulfillmentReadableInsightMomentumDescriptor(payload.momentum)),
        ("Consistency", fulfillmentReadableInsightConsistencyDescriptor(payload.consistency)),
        ("Structure", pct(payload.structure)),
        ("Outcomes", pct(payload.outcomes)),
        ("Action Plans", pct(payload.actionBlocks)),
        ("Little Wins", pct(payload.littleWins)),
        ("Engagement", pct(payload.engagement)),
        ("Strategic Behavior", pct(payload.strategicBehavior)),
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

    if let rank = payload.peerRank, let count = payload.peerCount {
        let pattern = "(?i)\\barea rank\\b(?:\\s*\\([^\\)]*\\))?"
        if let regex = try? NSRegularExpression(pattern: pattern) {
            let source = output
            let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
            output = regex.stringByReplacingMatches(
                in: source,
                range: nsRange,
                withTemplate: "area rank (\(rank) of \(count))"
            )
        }
    }

    // Remove duplicated raw-score tails after canonical metric parentheticals, e.g. "Action Blocks (50%) score (0.5)".
    if let duplicateValueRegex = try? NSRegularExpression(
        pattern: "(?i)(\\b(?:Momentum|Consistency|Structure|Outcomes|Action Plans|Little Wins|Engagement|Strategic Behavior|Carryover penalty)\\b\\s*\\([^\\)]*\\))\\s+score\\s*\\([-+]?\\d*\\.?\\d+%?\\)"
    ) {
        let source = output
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        output = duplicateValueRegex.stringByReplacingMatches(in: source, range: nsRange, withTemplate: "$1")
    }

    // If outcomes are high, avoid contradictory "execution gap in achieving Outcomes" phrasing.
    if payload.outcomes >= 0.8,
       let contradictionRegex = try? NSRegularExpression(
        pattern: "(?i)execution gap\\s+in\\s+achiev(?:ing|e)\\s+Outcomes\\s*\\([^\\)]*\\)"
       ) {
        let source = output
        let nsRange = NSRange(source.startIndex..<source.endIndex, in: source)
        output = contradictionRegex.stringByReplacingMatches(
            in: source,
            range: nsRange,
            withTemplate: "support mismatch despite Outcomes (\(pct(payload.outcomes)))"
        )
    }

    return ensureFulfillmentReadableInsightCTA(
        repairFulfillmentReadableInsightLineIfNeeded(output, payload: payload),
        payload: payload
    )
}

fileprivate func isFulfillmentSingleRecordPayload(_ payload: FulfillmentReadableInsightRequestPayload) -> Bool {
    payload.recentCategoryScores.count <= 1
}

fileprivate func startupFulfillmentTechnicalLine(payload: FulfillmentReadableInsightRequestPayload) -> String {
    let weakest = [
        ("Action Plans", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Engagement", payload.engagement),
        ("Strategic Behavior", payload.strategicBehavior),
        ("Structure", payload.structure),
        ("Outcomes", payload.outcomes)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Plans"
    return "Baseline week only: trend and mover signals are not established yet; score gains depend on improving \(weakest) consistency."
}

fileprivate func startupFulfillmentPracticalLine(payload: FulfillmentReadableInsightRequestPayload) -> String {
    let weakest = [
        ("Action Plans", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Engagement", payload.engagement),
        ("Strategic Behavior", payload.strategicBehavior),
        ("Structure", payload.structure),
        ("Outcomes", payload.outcomes)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Plans"

    switch weakest {
    case "Action Plans":
        return "Complete one realistic Action Plan in this area today."
    case "Little Wins":
        return "Complete one Little Win in this area each day this week."
    case "Engagement":
        return "Do one small task in this area every day this week."
    case "Strategic Behavior":
        return "Revise Mission or Identity so this area guides daily choices."
    case "Structure":
        return "Clarify Mission and Identity for this area before adding more tasks."
    case "Outcomes":
        return "Connect one Outcome for this area and review it this week."
    default:
        return "Complete one Action Plan and one Little Win in this area this week."
    }
}

fileprivate func ensureFulfillmentReadableInsightCTA(
    _ text: String,
    payload: FulfillmentReadableInsightRequestPayload
) -> String {
    let lines = text
        .replacingOccurrences(of: "\r\n", with: "\n")
        .split(separator: "\n", omittingEmptySubsequences: true)
        .map { String($0).trimmingCharacters(in: .whitespacesAndNewlines) }
        .filter { !$0.isEmpty }

    if isFulfillmentSingleRecordPayload(payload) {
        let first = startupFulfillmentTechnicalLine(payload: payload)
        let cta = normalizeFulfillmentReadableInsightCTALine(startupFulfillmentPracticalLine(payload: payload))
        return first + "\n\n" + cta + (cta.hasSuffix(".") ? "" : ".")
    }

    guard let first = lines.first else {
        let cta = normalizeFulfillmentReadableInsightCTALine(defaultFulfillmentReadableInsightCTA(payload: payload))
        return cta + (cta.hasSuffix(".") ? "" : ".")
    }
    if lines.count >= 2 {
        let cta = normalizeFulfillmentReadableInsightCTALine(lines[1])
        return first + "\n\n" + cta
    }
    let cta = normalizeFulfillmentReadableInsightCTALine(defaultFulfillmentReadableInsightCTA(payload: payload))
    return first + "\n\n" + cta + (cta.hasSuffix(".") ? "" : ".")
}

fileprivate func repairFulfillmentReadableInsightLineIfNeeded(
    _ text: String,
    payload: FulfillmentReadableInsightRequestPayload
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
        lower.contains("enagement") ||
        lower.contains("score (0.") ||
        (payload.outcomes >= 0.8 && lower.contains("execution gap")) ||
        (lower.contains("action blocks") && lower.contains("imbalance") && payload.littleWins + 0.12 < payload.actionBlocks)

    guard shouldReplace else { return text }

    let replacement = practicalFulfillmentInsightLine(payload: payload)
    let remaining = lines.dropFirst().map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }.filter { !$0.isEmpty }
    return ([replacement] + remaining).joined(separator: "\n")
}

fileprivate func practicalFulfillmentInsightLine(payload: FulfillmentReadableInsightRequestPayload) -> String {
    func pct(_ value: Double) -> String { "\(Int((FulfillmentScoringMath.clamped01(value) * 100).rounded()))%" }
    let structure = payload.structure
    let outcomes = payload.outcomes
    let actionBlocks = payload.actionBlocks
    let littleWins = payload.littleWins
    let engagement = payload.engagement
    let strategic = payload.strategicBehavior
    let carry = payload.carryoverPenalty

    if carry >= 0.4 {
        return "Carryover penalty (\(pct(carry))) is dragging this area despite stronger Structure (\(pct(structure)))."
    }
    if structure >= 0.8 && outcomes >= 0.8 && littleWins + 0.18 < actionBlocks {
        return "Structure (\(pct(structure))) and Outcomes (\(pct(outcomes))) are strong, but Little Wins (\(pct(littleWins))) lag Action Plans (\(pct(actionBlocks)))."
    }
    if outcomes >= 0.8 && actionBlocks < 0.6 {
        return "Outcomes (\(pct(outcomes))) are strong, but Action Plans (\(pct(actionBlocks))) need stronger execution support."
    }
    if strategic < 0.6 && (structure >= 0.75 || outcomes >= 0.75) {
        return "Strategic Behavior (\(pct(strategic))) is lagging stronger Structure (\(pct(structure))) and Outcomes (\(pct(outcomes)))."
    }
    if engagement < 0.6 && littleWins < 0.6 {
        return "Engagement (\(pct(engagement))) and Little Wins (\(pct(littleWins))) are the clearest drag on this area."
    }
    if actionBlocks < 0.55 {
        return "Action Plans (\(pct(actionBlocks))) are the clearest execution constraint on this area right now."
    }
    if littleWins < 0.55 {
        return "Little Wins (\(pct(littleWins))) are lagging and may be weakening day-to-day support."
    }
    return "The weakest support signal is Engagement (\(pct(engagement))), which is limiting progress consistency."
}

fileprivate func defaultFulfillmentReadableInsightCTA(payload: FulfillmentReadableInsightRequestPayload) -> String {
    if payload.carryoverPenalty >= 0.4 {
        return "Balance only adding essential actions and completing more actions"
    }
    if payload.actionBlocks < 0.6 && payload.littleWins < 0.6 {
        return "Complete more Little Wins and Action Plans"
    }
    let weakest = [
        ("Action Plans", payload.actionBlocks),
        ("Little Wins", payload.littleWins),
        ("Engagement", payload.engagement),
        ("Strategic Behavior", payload.strategicBehavior),
        ("Structure", payload.structure),
        ("Outcomes", payload.outcomes)
    ].min(by: { $0.1 < $1.1 })?.0 ?? "Action Plans"

    if payload.littleWins + 0.12 < payload.actionBlocks && payload.littleWins < 0.55 {
        return "Complete more Little Wins and Action Plans"
    }
    if payload.strategicBehavior < 0.6 && (payload.structure >= 0.75 || payload.outcomes >= 0.75) {
        return "Revise Mission or Identity to improve alignment"
    }

    switch weakest {
    case "Action Plans":
        return "Complete more Action Plans with realistic durations"
    case "Little Wins":
        return "Complete more Little Wins"
    case "Engagement":
        return "Complete one small action in this area today"
    case "Strategic Behavior":
        return "Revise Mission or Identity to improve alignment"
    case "Structure":
        return "Clarify the Mission and Identity for this area"
    case "Outcomes":
        return "Connect or refine an Outcome for this area"
    default:
        return "Improve one weak support signal in this area"
    }
}

fileprivate func normalizeFulfillmentReadableInsightCTALine(_ line: String) -> String {
    var output = line.trimmingCharacters(in: .whitespacesAndNewlines)
    output = output.replacingOccurrences(of: #"^(?i)in loom,\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(of: #"^(?i)in loom\s*"#, with: "", options: .regularExpression)
    output = output.replacingOccurrences(of: "Enagement", with: "Engagement")
    output = output.replacingOccurrences(of: "enagement", with: "Engagement")
    output = output.replacingOccurrences(of: "Action Block ", with: "Action Plan ")
    output = output.replacingOccurrences(of: "action block ", with: "Action Plan ")
    output = output.replacingOccurrences(
        of: #"(?i)shorten or split one Action Blocks? to reduce carryover"#,
        with: "Balance only adding essential actions and completing more actions",
        options: .regularExpression
    )
    if output.lowercased().contains("add or replace one practical little win"),
       output.lowercased().contains("action blocks") {
        output = "Complete more Little Wins and Action Plans"
    }
    return output
}

struct PassionsSectionView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var passions: [Passion]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    let record: Fulfillment
    @State private var isSelectingPassion = false
    
    private var categoryPassions: [Passion] {
        let categoryPassionIDs = passionJoins
            .filter { $0.category_id == record.category_id }
            .map { $0.passion_id }
        return passions.filter { categoryPassionIDs.contains($0.passion_id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "infinity")
                    .foregroundColor(.black)
                Text("Passions")
                    .font(.headline)
                    .foregroundColor(.black)
            }

            if categoryPassions.isEmpty {
                Text("No passions connected yet.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(categoryPassions, id: \.passion_id) { passion in
                        Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
                            .font(.subheadline)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 10)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
                    }
                }
            }

            Button("Connect Passion") {
                isSelectingPassion = true
            }
            .foregroundColor(.blue)
            .frame(maxWidth: .infinity, alignment: .leading)
            .sheet(isPresented: $isSelectingPassion) {
                NavigationStack {
                    List {
                        ForEach(passions, id: \.passion_id) { passion in
                            Button {
                                togglePassion(passion)
                            } label: {
                                HStack {
                                    Text("\(displayEmotionLabel(for: passion.emotion)): \(passion.passion)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    if categoryPassions.contains(where: { $0.passion_id == passion.passion_id }) {
                                        Image(systemName: "checkmark")
                                            .foregroundColor(.blue)
                                    }
                                    }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .navigationTitle("Connect Passions to \(record.category)")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") { isSelectingPassion = false }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
            }
        }
    }
    
    private func togglePassion(_ passion: Passion) {
        let existingJoin = passionJoins.first {
            $0.passion_id == passion.passion_id && $0.category_id == record.category_id
        }
        
        if let join = existingJoin {
            RecentlyDeletedStore.trash(join, in: modelContext)
        } else {
            let join = PassionFulfillmentJoin(
                passion_id: passion.passion_id,
                category_id: record.category_id
            )
            modelContext.insert(join)
        }
    }

    private func displayEmotionLabel(for raw: String) -> String {
        switch raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "just": return "Hate"
        case "vows": return "Vow"
        default: return raw.capitalized
        }
    }
}

struct FulfillmentView: View {
    private struct LittleWinsManagerTarget: Identifiable {
        let id: UUID
        let categoryTitle: String
    }
    private struct RolesManagerTarget: Identifiable {
        let id: UUID
        let categoryTitle: String
    }
    private struct RoleEditorTarget: Identifiable {
        let categoryID: UUID
        let categoryTitle: String
        let roleID: UUID?
        let autoFocus: Bool
        var id: String {
            if let roleID { return "edit-\(roleID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }
    private struct ResourcesManagerTarget: Identifiable {
        let id: UUID
        let categoryTitle: String
    }
    private struct ResourceEditorTarget: Identifiable {
        let categoryID: UUID
        let categoryTitle: String
        let resourceID: UUID?
        let autoFocus: Bool
        var id: String {
            if let resourceID { return "edit-\(resourceID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }
    private struct LittleWinsEditorTarget: Identifiable {
        let categoryID: UUID
        let categoryTitle: String
        let focusID: UUID?
        let autoFocus: Bool

        var id: String {
            if let focusID { return "edit-\(focusID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    @Environment(\.modelContext) private var modelContext
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.scenePhase) private var scenePhase

    @Query private var fulfillments: [Fulfillment]
    @Query private var roles: [FulfillmentRoles]
    @Query private var foci: [FulfillmentFocus]
    @Query private var resources: [FulfillmentResources]
    @Query private var passionJoins: [PassionFulfillmentJoin]
    @Query private var passions: [Passion]
    @Query(sort: \LittleWinsDailyCompletion.completedAt, order: .reverse) private var littleWinsDailyCompletions: [LittleWinsDailyCompletion]
    @Query(sort: \ActionBlocksReflectionArchive.completedAt, order: .reverse) private var reflectionArchives: [ActionBlocksReflectionArchive]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var outcomes: [Outcomes]
    @Query(sort: \FulfillmentCategoryScoreSnapshot.weekStartDate, order: .reverse)
    private var fulfillmentCategoryScoreSnapshots: [FulfillmentCategoryScoreSnapshot]
    @Query(sort: \ReplacedFulfillmentCategoryArchive.replacedAt, order: .reverse)
    private var replacedCategoryArchives: [ReplacedFulfillmentCategoryArchive]

    @State private var expandedCardID: String? = nil
    @State private var showPreviousCategories = false
    @State private var pendingDeletePrevious: ReplacedFulfillmentCategoryArchive?
    @State private var showDeletePreviousAlert = false
    @State private var showRecoverPreviousAlert = false
    @State private var recoverPreviousAlertMessage = ""
    @State private var pendingRecoverPrevious: ReplacedFulfillmentCategoryArchive?
    @State private var showRecoverColorPicker = false
    @State private var recoverColorOptions: [String] = []
    @State private var selectedRecoverColorKey: String = ""
    @State private var expandedPreviousID: UUID? = nil
    @State private var isAddingRole = false
    @State private var newRoleText = ""
    @State private var isAddingFocus = false
    @State private var newFocusText = ""
    @State private var isAddingResource = false
    @State private var newResourceText = ""
    @State private var visionDrafts: [UUID: String] = [:]
    @State private var aiReadableInsightsByKey: [String: String] = [:]
    @State private var aiReadableInsightLoadingKeys: Set<String> = []
    @State private var purposeDrafts: [UUID: String] = [:]
    @State private var isShowingInstructions = false
    @State private var highlightedCategoryIndex: Int = 0
    @State private var radarAutoRotatePausedUntil: Date = .distantPast
    @State private var littleWinsManagerTarget: LittleWinsManagerTarget?
    @State private var littleWinsEditorTarget: LittleWinsEditorTarget?
    @State private var rolesManagerTarget: RolesManagerTarget?
    @State private var roleEditorTarget: RoleEditorTarget?
    @State private var resourcesManagerTarget: ResourcesManagerTarget?
    @State private var resourceEditorTarget: ResourceEditorTarget?
    @State private var littleWinsScheduleStoreRevision = 0
    @State private var headerInsightOutlineAngle: Double = 0
    @State private var fulfillmentRadarHeaderMeasuredWidth: CGFloat = 0
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var focusedField: Field?
    @FocusState private var focusedVisionCategoryID: UUID?
    @FocusState private var focusedPurposeCategoryID: UUID?
    private enum Field { case role, focus, resource }
    private struct SimpleManageListItem: Identifiable {
        let id: UUID
        let title: String
        let subtitle: String?
    }
    private let radarTimer = Timer.publish(every: 5, on: .main, in: .common).autoconnect()
    private let keyboardFloatingGap: CGFloat = 15

    private var isKeyboardVisible: Bool { keyboardHeight > 0 }

    private var focusedFieldHasNonBlankText: Bool {
        if let focusedField {
            switch focusedField {
            case .role:
                return !newRoleText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .focus:
                return !newFocusText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            case .resource:
                return !newResourceText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        if let focusedVisionCategoryID {
            let text = visionDrafts[focusedVisionCategoryID]
                ?? fulfillments.first(where: { $0.category_id == focusedVisionCategoryID })?.category_vision
                ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        if let focusedPurposeCategoryID {
            let text = purposeDrafts[focusedPurposeCategoryID]
                ?? fulfillments.first(where: { $0.category_id == focusedPurposeCategoryID })?.category_purpose
                ?? ""
            return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
        return false
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
            dismissFulfillmentKeyboard()
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

    @ViewBuilder
    private func styledManageListBox(
        primaryRowTitle: String,
        items: [SimpleManageListItem],
        onPrimaryTap: @escaping () -> Void,
        onItemTap: @escaping (UUID) -> Void
    ) -> some View {
        VStack(spacing: 0) {
            Button(action: onPrimaryTap) {
                HStack {
                    Text(primaryRowTitle)
                        .foregroundStyle(Color.accentColor)
                    Spacer()
                }
                .frame(minHeight: 44, alignment: .center)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 14)
                .contentShape(Rectangle())
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
            .buttonStyle(.plain)

            if !items.isEmpty {
                Divider()
                ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                    Button {
                        onItemTap(item.id)
                    } label: {
                        HStack(spacing: 0) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.title)
                                    .foregroundStyle(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                if let subtitle = item.subtitle, !subtitle.isEmpty {
                                    Text(subtitle)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer(minLength: 0)
                        }
                        .frame(minHeight: 44, alignment: .leading)
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .contentShape(Rectangle())
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
                    .buttonStyle(.plain)

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
        }
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
        )
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
        let collapsed = cleaned
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return collapsed
    }

    private var orderedFulfillments: [Fulfillment] {
        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        var ordered: [Fulfillment] = []
        var seenTitleKeys = Set<String>()
        for def in defaultCategoryDefs {
            if let record = byID.removeValue(forKey: def.categoryID) {
                let key = categoryKey(record.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { continue }
                ordered.append(record)
                seenTitleKeys.insert(key)
            }
        }
        let extras = byID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { row in
                let key = categoryKey(row.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { return false }
                seenTitleKeys.insert(key)
                return true
            }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }
        ordered.append(contentsOf: extras)
        return Array(ordered.prefix(7))
    }

    private var isAnyLittleWinsSheetPresented: Bool {
        littleWinsManagerTarget != nil || littleWinsEditorTarget != nil ||
        rolesManagerTarget != nil || roleEditorTarget != nil ||
        resourcesManagerTarget != nil || resourceEditorTarget != nil
    }

    var body: some View {
        fulfillmentScreen
    }

    private var fulfillmentBaseContent: some View {
        ScrollView {
            ZStack {
                if isAddingRole || isAddingFocus || isAddingResource {
                    Color.clear
                        .contentShape(Rectangle())
                        .onTapGesture {
                            commitInlineIfNeeded()
                            focusedField = nil
                        }
                }

                VStack(spacing: 0) {
                    fulfillmentRadarHeader
                        .padding(.horizontal)
                        .padding(.top)
                        .background(Color(.systemGray6))

                    VStack(spacing: 16) {
                        ForEach(orderedFulfillments, id: \.category_id) { record in
                            let title = record.category
                            card(
                                id: record.category_id.uuidString,
                                title: title,
                                iconName: batteryIconName(for: record),
                                color: FulfillmentCategoryTheme.color(for: title),
                                lightColor: FulfillmentCategoryTheme.lightColor(for: title),
                                record: record
                            )
                        }

                        previousCategoriesSection

                        Spacer()
                    }
                    .padding()
                }
            }
        }
    }

    private var fulfillmentScreenCore: some View {
        fulfillmentBaseContent
            .navigationTitle("Fulfillment")
            .toolbar { fulfillmentToolbarContent }
    }

    @ToolbarContentBuilder
    private var fulfillmentToolbarContent: some ToolbarContent {
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

    private var fulfillmentScreenFocusObservers: some View {
        fulfillmentScreenCore
            .onChange(of: focusedField) { _, new in
                commitInlineExcluding(new)
            }
            .onChange(of: focusedVisionCategoryID) { old, _ in
                commitVisionDraft(for: old)
            }
            .onChange(of: focusedPurposeCategoryID) { old, _ in
                commitPurposeDraft(for: old)
            }
    }

    private var fulfillmentScreenInteractionObservers: some View {
        fulfillmentScreenFocusObservers
            .onReceive(radarTimer) { _ in
                guard !orderedFulfillments.isEmpty else { return }
                guard Date() >= radarAutoRotatePausedUntil else { return }
                if highlightedCategoryIndex >= orderedFulfillments.count { highlightedCategoryIndex = 0 }
                highlightedCategoryIndex = (highlightedCategoryIndex + 1) % orderedFulfillments.count
            }
    }

    private var fulfillmentScreenAppearObserver: some View {
        fulfillmentScreenInteractionObservers
            .onAppear {
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreenLifecycleObservers: some View {
        fulfillmentScreenAppearObserver
            .onChange(of: scenePhase) { _, phase in
                guard phase == .active else { return }
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreenPrimaryDataObservers: some View {
        fulfillmentScreenLifecycleObservers
            .onChange(of: fulfillments.map(\.updatedAt)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: roles.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: foci.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: resources.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreenCoreDataObservers: some View {
        fulfillmentScreenPrimaryDataObservers
            .onChange(of: passions.map(\.passion_id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreenDataObservers: some View {
        fulfillmentScreenCoreDataObservers
            .onChange(of: passionJoins.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: littleWinsDailyCompletions.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: reflectionArchives.map(\.id)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onChange(of: outcomes.map(\.updatedAt)) { _, _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreenObserved: some View {
        fulfillmentScreenDataObservers
            .onReceive(NotificationCenter.default.publisher(for: .littleWinsScheduleDidChange)) { _ in
                littleWinsScheduleStoreRevision &+= 1
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
            .onReceive(NotificationCenter.default.publisher(for: .vacationModeDidChange)) { _ in
                refreshFulfillmentCategoryScoresForCurrentWeek()
            }
    }

    private var fulfillmentScreen: some View {
        fulfillmentScreenObserved
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
                guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
                let screenHeight = UIScreen.main.bounds.height
                keyboardHeight = max(0, screenHeight - frame.minY)
            }
            .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
                keyboardHeight = 0
            }
            .sheet(isPresented: $isShowingInstructions) {
            fulfillmentInstructionsSheet()
        }
        .sheet(item: $littleWinsManagerTarget) { target in
            LittleWinsManagerSheetView(categoryID: target.id, categoryTitle: target.categoryTitle)
        }
        .sheet(item: $littleWinsEditorTarget) { target in
            LittleWinEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                focusID: target.focusID,
                autoFocusTextField: target.autoFocus
            )
        }
        .sheet(item: $rolesManagerTarget) { target in
            RolesManagerSheetView(categoryID: target.id, categoryTitle: target.categoryTitle)
        }
        .sheet(item: $roleEditorTarget) { target in
            RoleEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                roleID: target.roleID,
                autoFocusTextField: target.autoFocus
            )
        }
        .sheet(item: $resourcesManagerTarget) { target in
            ResourcesManagerSheetView(categoryID: target.id, categoryTitle: target.categoryTitle)
        }
        .sheet(item: $resourceEditorTarget) { target in
            ResourceEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                resourceID: target.resourceID,
                autoFocusTextField: target.autoFocus
            )
        }
        .alert("Move to Recently Deleted?", isPresented: $showDeletePreviousAlert, presenting: pendingDeletePrevious) { snapshot in
            Button("Cancel", role: .cancel) {
                pendingDeletePrevious = nil
            }
            Button("Delete", role: .destructive) {
                RecentlyDeletedStore.trash(snapshot, in: modelContext)
                try? modelContext.save()
                pendingDeletePrevious = nil
            }
        } message: { _ in
            Text("This item will be available for 30 days in account management.")
        }
        .alert("Can't Recover Area", isPresented: $showRecoverPreviousAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(recoverPreviousAlertMessage)
        }
        .sheet(isPresented: $showRecoverColorPicker) {
            NavigationStack {
                List {
                    ForEach(recoverColorOptions, id: \.self) { key in
                        Button {
                            selectedRecoverColorKey = key
                        } label: {
                            HStack(spacing: 10) {
                                Circle()
                                    .fill(FulfillmentCategoryTheme.color(forKey: key))
                                    .frame(width: 16, height: 16)
                                Text(FulfillmentCategoryTheme.palette.first(where: { $0.key == key })?.name ?? key.capitalized)
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedRecoverColorKey == key {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Select New Color")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarLeading) {
                        Button("Cancel") {
                            showRecoverColorPicker = false
                            pendingRecoverPrevious = nil
                        }
                    }
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Recover") {
                            guard let archive = pendingRecoverPrevious else { return }
                            recoverPreviousCategory(archive, colorOverride: selectedRecoverColorKey)
                            showRecoverColorPicker = false
                            pendingRecoverPrevious = nil
                        }
                        .disabled(selectedRecoverColorKey.isEmpty)
                    }
                }
            }
            .presentationDetents([
                .height(min(420, max(200, 130 + CGFloat(recoverColorOptions.count) * 52)))
            ])
            .presentationDragIndicator(.visible)
        }
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
    }

    private var previousCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .center, spacing: 8) {
                if !replacedCategoryArchives.isEmpty {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            showPreviousCategories.toggle()
                            if !showPreviousCategories {
                                expandedPreviousID = nil
                            }
                        }
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: showPreviousCategories ? "chevron.up" : "chevron.down")
                                .font(.caption2.weight(.semibold))
                            Text("Previous Areas")
                                .font(.caption2.weight(.semibold))
                        }
                        .foregroundStyle(colorScheme == .dark ? Color(.systemGray2) : .black)
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
                }

                Spacer(minLength: 0)

                NavigationLink {
                    ManageFulfillmentCategoriesView()
                } label: {
                    Text("Manage Fulfillment Areas")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                .buttonStyle(.plain)
            }
            .frame(maxWidth: .infinity)

            if !replacedCategoryArchives.isEmpty, showPreviousCategories {
                ForEach(replacedCategoryArchives, id: \.id) { archive in
                    previousCategoryCard(archive)
                }
            }
        }
    }

    private func fulfillmentInstructionsSheet() -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Text("Instructions")
                    .font(.headline.weight(.semibold))
                    .frame(maxWidth: .infinity, alignment: .center)

                fulfillmentInstructionBody("You can manage and edit your categories anytime in:")
                HStack(spacing: 6) {
                    Text("Account")
                    Image(systemName: "person.circle")
                    Text("→ Manage Fulfillment Areas")
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

                fulfillmentInstructionSectionTitle("Set Fulfillment Areas")
                fulfillmentInstructionBody("Design the most important areas of your life.")
                fulfillmentInstructionBody("These are core categories that drive fulfillment. When they're out of balance, life is harder.")
                fulfillmentInstructionBody("They're never finished. You continually improve them to stay moving forward.")

                fulfillmentInstructionSectionTitle("Create Categories")
                fulfillmentInstructionBody("What 3-7 areas of your life must you consistently improve to succeed?")
                fulfillmentInstructionLabel("Need help?")
                fulfillmentInstructionBody("Fulfillment Areas are the key parts of your life you continually strengthen and maintain.")
                fulfillmentInstructionBody("They are not one-time goals. When these areas are strong, life feels stable and balanced. When neglected, progress in other areas becomes harder.")
                fulfillmentInstructionBody("Every action you take will connect to one of these areas, helping you focus on what truly matters instead of reacting to what feels urgent.")
                fulfillmentInstructionBody("Start simple. You can refine or change them anytime.")

                fulfillmentInstructionSectionTitle("Define Mission")
                fulfillmentInstructionBody("Why does improving this area truly matter?")
                fulfillmentInstructionLabel("Need ideas?")
                fulfillmentInstructionBody("Mission is your deeper reason. It keeps you consistent when motivation fades.")
                fulfillmentInstructionBody("Think about why this matters and how your life improves when this area strengthens. When strong, everything feels easier.")
                fulfillmentInstructionBody("You can refine this anytime. Start simple.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "This fuels my energy and confidence so I can show up fully every day.",
                    "This gives me stability and peace of mind instead of constant stress.",
                    "Success here creates freedom and momentum across the rest of my life.",
                    "I want to feel proud of who I am in this area.",
                    "Neglecting this always leads to bigger problems later, so it’s a must.",
                    "This helps me feel grounded, focused, and fulfilled instead of reactive."
                ])

                fulfillmentInstructionSectionTitle("Identify Identity")
                fulfillmentInstructionBody("Who do you want to be in this area of your life?")
                fulfillmentInstructionLabel("Need help?")
                fulfillmentInstructionBody("Identity defines who you are in this area.")
                fulfillmentInstructionBody("They guide how you think, act, and make decisions before results show up. Instead of focusing only on goals, focus on the person who naturally creates those outcomes.")
                fulfillmentInstructionBody("Choose identities that feel empowering and motivating. These should reflect the best version of yourself in this area.")
                fulfillmentInstructionBody("You can update these anytime as you evolve.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Athlete",
                    "Wealth Builder",
                    "Focused Student",
                    "Loving Partner",
                    "Empowering Leader",
                    "Energized Creator",
                    "Community Contributor",
                    "Prayer Warrior"
                ])

                fulfillmentInstructionSectionTitle("Choose Your Focus")
                fulfillmentInstructionBody("Which areas would improve your life the most right now?")
                fulfillmentInstructionBody("Choose 1 or more areas than need increased focus.")

                fulfillmentInstructionSectionTitle("List Little Wins")
                fulfillmentInstructionBody("What small, repeatable wins can move this area forward?")
                fulfillmentInstructionLabel("Need Help?")
                fulfillmentInstructionBody("Small actions create momentum.")
                fulfillmentInstructionBody("Focus on a few easy, high-impact 1-3 actions you can do consistently.")
                fulfillmentInstructionBody("These should be simple enough that you can follow through even on busy or low-energy days.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Stretch or walk",
                    "Pray or journal",
                    "Review budget",
                    "Call loved one",
                    "Read for 10 min"
                ])

                fulfillmentInstructionSectionTitle("Note Resources")
                fulfillmentInstructionBody("What people, tools, or environments can help you improve this area?")
                fulfillmentInstructionLabel("Need Help?")
                fulfillmentInstructionBody("Strong support makes success easier.")
                fulfillmentInstructionBody("Focus on 1–3 people, tools, or environments that support consistent growth.")
                fulfillmentInstructionBody("Choose resources that reduce friction and make the right behavior more automatic.")
                fulfillmentInstructionLabel("Examples:")
                fulfillmentInstructionBullets([
                    "Great gym",
                    "Accountability partner",
                    "Mentor or coach",
                    "Budgeting app",
                    "Supportive community",
                    "Quiet workspace",
                    "State park nearby"
                ])

                fulfillmentInstructionSectionTitle("Passions")
                fulfillmentInstructionBody("What passions drive you to improve this area?")

            }
            .padding()
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }

    @ViewBuilder
    private func fulfillmentInstructionSectionTitle(_ text: String) -> some View {
        Text(text)
            .font(.headline.weight(.semibold))
            .foregroundStyle(.primary)
    }

    @ViewBuilder
    private func fulfillmentInstructionLabel(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    @ViewBuilder
    private func fulfillmentInstructionBody(_ text: String) -> some View {
        Text(text)
            .font(.subheadline)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func fulfillmentInstructionExample(_ text: String) -> some View {
        Text(text)
            .font(.subheadline.italic())
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    @ViewBuilder
    private func fulfillmentInstructionBullets(_ items: [String]) -> some View {
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

    private func previousCategoryCard(_ archive: ReplacedFulfillmentCategoryArchive) -> some View {
        let roles = csvItems(from: archive.rolesCSV)
        let fociValues = csvItems(from: archive.fociCSV)
        let passionValues = csvItems(from: archive.passionsCSV)
        let isExpanded = (expandedPreviousID == archive.id)
        let hasPurpose = !archive.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasIdentity = !archive.category_identitiy.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let completionCount = [hasPurpose, hasIdentity, !roles.isEmpty, !fociValues.isEmpty, !passionValues.isEmpty].filter { $0 }.count
        let iconName: String = {
            switch completionCount {
            case 0: return "battery.0"
            case 1...2: return "battery.25"
            case 3...4: return "battery.50"
            case 5: return "battery.75"
            default: return "battery.100"
            }
        }()

        return VStack(spacing: 0) {
            HStack {
                Image(systemName: iconName)
                    .foregroundColor(.white)
                Text(archive.category)
                    .font(.headline)
                    .fontWeight(.black)
                    .foregroundColor(.white)
                Spacer(minLength: 8)
                Text("Replaced \(replacementDateText(archive.replacedAt))")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(Color.white.opacity(0.9))
                Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                    .foregroundColor(.white)
            }
            .padding()
            .background(Color(.systemGray2))
            .contentShape(Rectangle())
            .onTapGesture {
                withAnimation(.easeInOut) {
                    if isExpanded {
                        expandedPreviousID = nil
                    } else {
                        expandedPreviousID = archive.id
                        expandedCardID = nil
                    }
                }
            }

            if isExpanded {
                VStack(alignment: .leading, spacing: 16) {
                    Text("Mission")
                        .font(.headline)
                        .foregroundColor(.black)
                    Text(archive.category_purpose.isEmpty ? "No mission saved." : archive.category_purpose)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(10)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Identity")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: roles)

                    Text("Little Wins")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: fociValues)

                    Text("Passions")
                        .font(.headline)
                        .foregroundColor(.black)
                    readOnlyRows(values: passionValues)

                    HStack {
                        Button("Recover") {
                            handleRecoverTapped(for: archive)
                        }
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .opacity(recoverButtonOpacity(for: archive))

                        Spacer(minLength: 0)
                        Button(role: .destructive) {
                            pendingDeletePrevious = archive
                            showDeletePreviousAlert = true
                        } label: {
                            Image(systemName: "trash")
                                .font(.body.weight(.semibold))
                                .foregroundStyle(.red)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(16)
                .background(Color(.systemGray6))
            }
        }
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.systemGray3), lineWidth: 1)
        )
    }

    private func readOnlyRows(values: [String]) -> some View {
        VStack(spacing: 0) {
            if values.isEmpty {
                Text("No items saved.")
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.vertical, 10)
                    .padding(.horizontal, 10)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10))
            } else {
                ForEach(values.indices, id: \.self) { index in
                    Text(values[index])
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 10)
                        .padding(.horizontal, 10)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(Color(.secondarySystemBackground))
                        )
                }
            }
        }
    }

    private func replacementDateText(_ date: Date) -> String {
        let nowYear = Calendar.current.component(.year, from: .now)
        let year = Calendar.current.component(.year, from: date)
        if nowYear == year {
            return date.formatted(.dateTime.month().day())
        }
        return date.formatted(.dateTime.month().day().year())
    }

    private func csvItems(from value: String) -> [String] {
        value
            .components(separatedBy: "|||")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func recoverPreviousCategory(_ archive: ReplacedFulfillmentCategoryArchive, colorOverride: String? = nil) {
        switch recoverEligibility(for: archive, colorOverride: colorOverride) {
        case .allowed:
            break
        case .needsColorSelection(let available):
            pendingRecoverPrevious = archive
            recoverColorOptions = available
            selectedRecoverColorKey = available.first ?? ""
            showRecoverColorPicker = true
            return
        case .blocked(let message):
            recoverPreviousAlertMessage = message
            showRecoverPreviousAlert = true
            return
        }

        let restored = Fulfillment(
            category_id: archive.category_id,
            updatedAt: .now,
            category: archive.category,
            category_identitiy: archive.category_identitiy,
            category_vision: archive.category_vision,
            category_purpose: archive.category_purpose
        )
        modelContext.insert(restored)

        let roleValues = csvItems(from: archive.rolesCSV)
        for (idx, value) in roleValues.enumerated() {
            modelContext.insert(
                FulfillmentRoles(
                    category_id: archive.category_id,
                    role: value,
                    rank: idx
                )
            )
        }

        let focusValues = csvItems(from: archive.fociCSV)
        for (idx, value) in focusValues.enumerated() {
            modelContext.insert(
                FulfillmentFocus(
                    category_id: archive.category_id,
                    activity: value,
                    rank: idx
                )
            )
        }

        let resourceValues = csvItems(from: archive.resourcesCSV)
        for (idx, value) in resourceValues.enumerated() {
            modelContext.insert(
                FulfillmentResources(
                    category_id: archive.category_id,
                    resource: value,
                    rank: idx
                )
            )
        }

        let desiredPassionKeys = Set(csvItems(from: archive.passionsCSV).map(normalizedPassionKey))
        if !desiredPassionKeys.isEmpty {
            var existingJoinPassionIDs = Set(
                passionJoins
                    .filter { $0.category_id == archive.category_id }
                    .map(\.passion_id)
            )
            for passion in passions {
                let raw = normalizedPassionKey(passion.emotion)
                if desiredPassionKeys.contains(raw) {
                    if !existingJoinPassionIDs.contains(passion.passion_id) {
                        modelContext.insert(
                            PassionFulfillmentJoin(
                                passion_id: passion.passion_id,
                                category_id: archive.category_id
                            )
                        )
                        existingJoinPassionIDs.insert(passion.passion_id)
                    }
                }
            }
        }

        var colorMap = FulfillmentCategoryTheme.persistedColorKeys()
        let restoredColorKey = colorOverride ?? FulfillmentCategoryTheme.colorKey(for: archive.category, colorKeys: colorMap)
        colorMap[archive.category] = restoredColorKey
        FulfillmentCategoryTheme.persistColorKeys(colorMap)

        if expandedPreviousID == archive.id {
            expandedPreviousID = nil
        }
        modelContext.delete(archive)
        try? modelContext.save()
    }

    private enum RecoverEligibility {
        case allowed
        case needsColorSelection([String])
        case blocked(String)
    }

    private func recoverEligibility(for archive: ReplacedFulfillmentCategoryArchive, colorOverride: String? = nil) -> RecoverEligibility {
        if fulfillments.contains(where: { $0.category_id == archive.category_id }) {
            return .blocked("An active area with this identity already exists.")
        }

        let activeCategoryKeys = Set(
            fulfillments
                .map { categoryKey($0.category) }
                .filter { !$0.isEmpty }
        )

        if activeCategoryKeys.count > 6 {
            return .blocked("Recovery is only available when there are 6 or fewer active areas.")
        }

        let archiveCategoryKey = categoryKey(archive.category)
        if !archiveCategoryKey.isEmpty && activeCategoryKeys.contains(archiveCategoryKey) {
            return .blocked("An active area with this name already exists.")
        }

        let colorMap = FulfillmentCategoryTheme.persistedColorKeys()
        let usedColorKeys = Set(
            fulfillments.map { FulfillmentCategoryTheme.colorKey(for: $0.category, colorKeys: colorMap) }
        )
        let desiredColorKey = colorOverride ?? FulfillmentCategoryTheme.colorKey(for: archive.category, colorKeys: colorMap)
        let hasColorConflict = usedColorKeys.contains(desiredColorKey)
        if hasColorConflict {
            let available = FulfillmentCategoryTheme.palette.map(\.key).filter { !usedColorKeys.contains($0) }
            if available.isEmpty {
                return .blocked("No colors are available. Free up a color in active areas, then try again.")
            }
            return .needsColorSelection(available)
        }
        return .allowed
    }

    private func handleRecoverTapped(for archive: ReplacedFulfillmentCategoryArchive) {
        switch recoverEligibility(for: archive) {
        case .allowed:
            recoverPreviousCategory(archive)
        case .needsColorSelection(let available):
            pendingRecoverPrevious = archive
            recoverColorOptions = available
            selectedRecoverColorKey = available.first ?? ""
            showRecoverColorPicker = true
        case .blocked(let message):
            recoverPreviousAlertMessage = message
            showRecoverPreviousAlert = true
        }
    }

    private func isRecoverBlocked(for archive: ReplacedFulfillmentCategoryArchive) -> Bool {
        if case .blocked = recoverEligibility(for: archive) {
            return true
        }
        return false
    }

    private func recoverButtonOpacity(for archive: ReplacedFulfillmentCategoryArchive) -> Double {
        isRecoverBlocked(for: archive) ? 0.45 : 1.0
    }

    private func normalizedPassionKey(_ raw: String) -> String {
        let prefix = raw
            .split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
            .first
            .map(String.init) ?? raw
        let key = prefix.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        switch key {
        case "just", "hate": return "hate"
        case "vows", "vow": return "vow"
        default: return key
        }
    }

    private var fulfillmentRadarHeader: some View {
        let width = max(fulfillmentRadarHeaderMeasuredWidth, 320)
        return Group {
            let baseGraphWidth = max(120, width * 0.40)
            let graphWidth = baseGraphWidth * 1.2
            let leftWidth = max(120, width - baseGraphWidth - 28)
            if orderedFulfillments.isEmpty {
                EmptyView()
            } else {
                let selectedIndex = min(max(0, highlightedCategoryIndex), max(0, orderedFulfillments.count - 1))
                let selected = orderedFulfillments[selectedIndex]
                let selectedTitle = selected.category
                let selectedScore = roundedTenth(latestFulfillmentWeeklyScore(for: selected) ?? ((batteryPercentage(for: selected) / 100.0) * 5.0))
                let selectedDelta = fulfillmentWeekOverWeekDelta(for: selected)
                let selectedInsightSnapshot = latestFulfillmentWeeklySnapshot(for: selected)

                HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 6) {
                        Text(selectedTitle)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundStyle(FulfillmentCategoryTheme.color(for: selectedTitle))
                            .lineLimit(2)
                    Text("Tap circles on the graph")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(alignment: .center, spacing: 8) {
                        RoundedRectangle(cornerRadius: 10)
                            .fill(FulfillmentCategoryTheme.color(for: selectedTitle))
                            .frame(width: 92, height: 58)
                            .overlay {
                                Text(String(format: "%.1f/5", selectedScore))
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundStyle(.white)
                            }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text(headerCategoryDeltaGlyph(selectedDelta))
                                    .font(.title3.weight(.bold))
                                    .foregroundStyle(headerCategoryDeltaColor(selectedDelta))
                                if let selectedDelta {
                                    Text(headerCategoryDeltaText(selectedDelta))
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(headerCategoryDeltaColor(selectedDelta))
                                } else {
                                    Text("—")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Text("week")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if let snap = selectedInsightSnapshot {
                        let payload = fulfillmentReadableInsightPayload(for: snap, categoryTitle: selectedTitle, weekOverWeekDelta: selectedDelta)
                        let insightKey = fulfillmentReadableInsightKey(for: payload)
                        let summaryInsight = fulfillmentReadableInsightCTAParagraph(aiFulfillmentReadableInsightText(
                            for: snap,
                            categoryTitle: selectedTitle,
                            weekOverWeekDelta: selectedDelta
                        ))
                        let isLoadingInsight = aiReadableInsightLoadingKeys.contains(insightKey)
                        if isLoadingInsight || summaryInsight != nil {
                            FulfillmentReadableInsightCard(
                                text: summaryInsight,
                                isLoading: isLoadingInsight,
                                font: UIFont.preferredFont(forTextStyle: .footnote),
                                imageSize: CGSize(width: 35, height: 35),
                                cornerRadius: 10,
                                fillColor: Color(.secondarySystemBackground)
                            )
                            .frame(maxWidth: leftWidth - 20, alignment: .leading)
                            .padding(.trailing, 4)
                            .padding(.top, 4)
                        }
                        Color.clear
                            .frame(height: 0)
                            .task(id: insightKey) {
                                await requestFulfillmentReadableInsightIfNeeded(for: snap, categoryTitle: selectedTitle, weekOverWeekDelta: selectedDelta)
                            }
                    }

                    Spacer(minLength: 4)

                    NavigationLink {
                        FulfillmentTrendsView()
                    } label: {
                        Text("Show insights")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .buttonStyle(.plain)
                }
                .frame(width: leftWidth, alignment: .leading)

                FulfillmentInteractiveRadar(
                    metrics: fulfillmentMetrics,
                    selectedIndex: $highlightedCategoryIndex,
                    onManualSelect: {
                        radarAutoRotatePausedUntil = Date().addingTimeInterval(20)
                    }
                )
                .frame(width: graphWidth, height: graphWidth)
                .frame(width: baseGraphWidth, alignment: .center)
                .frame(minHeight: 245, alignment: .top)
                .padding(.top, 8)

                Spacer(minLength: 0)
                }
            }
        }
        .background(
            GeometryReader { proxy in
                Color.clear
                    .onAppear {
                        let newWidth = proxy.size.width
                        if abs(newWidth - fulfillmentRadarHeaderMeasuredWidth) > 0.5 {
                            fulfillmentRadarHeaderMeasuredWidth = newWidth
                        }
                    }
                    .onChange(of: proxy.size.width) { _, newWidth in
                        if abs(newWidth - fulfillmentRadarHeaderMeasuredWidth) > 0.5 {
                            fulfillmentRadarHeaderMeasuredWidth = newWidth
                        }
                    }
            }
        )
        .frame(minHeight: 245)
        .padding(.bottom, 8)
        .onAppear {
            guard headerInsightOutlineAngle == 0 else { return }
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                headerInsightOutlineAngle = 360
            }
        }
    }

    private func commitInlineIfNeeded() {
        guard let openID = expandedCardID,
              let record = orderedFulfillments.first(where: { $0.category_id.uuidString == openID })
        else { return }

        if isAddingRole {
            let trimmed = newRoleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addRole(text: trimmed, record: record) }
            newRoleText = ""
            isAddingRole = false
        }
        if isAddingFocus {
            let trimmed = newFocusText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addFocus(text: trimmed, record: record) }
            newFocusText = ""
            isAddingFocus = false
        }
        if isAddingResource {
            let trimmed = newResourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addResource(text: trimmed, record: record) }
            newResourceText = ""
            isAddingResource = false
        }
    }
    
    private func commitInlineExcluding(_ keepOpen: Field?) {
        guard let openID = expandedCardID,
              let record = orderedFulfillments.first(where: { $0.category_id.uuidString == openID })
        else { return }

        if isAddingRole && keepOpen != .role {
            let trimmed = newRoleText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addRole(text: trimmed, record: record) }
            newRoleText = ""
            isAddingRole = false
        }
        if isAddingFocus && keepOpen != .focus {
            let trimmed = newFocusText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addFocus(text: trimmed, record: record) }
            newFocusText = ""
            isAddingFocus = false
        }
        if isAddingResource && keepOpen != .resource {
            let trimmed = newResourceText.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty { addResource(text: trimmed, record: record) }
            newResourceText = ""
            isAddingResource = false
        }
    }

    @ViewBuilder
    private func card(
        id: String,
        title: String,
        iconName: String,
        color: Color,
        lightColor: Color,
        record: Fulfillment
    ) -> some View {
            let isExpanded = (expandedCardID == id)

            VStack(spacing: 0) {
                HStack {
                    Image(systemName: iconName)
                        .foregroundColor(.white)
                    Text(title)
                        .font(.headline)
                        .fontWeight(.black)
                        .foregroundColor(.white)
                    Spacer()
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .foregroundColor(.white)
                }
                .padding()
                .background(color)
                .contentShape(Rectangle())
                .onTapGesture {
                    withAnimation(.easeInOut) {
                        expandedCardID = isExpanded ? nil : id
                        if expandedCardID != nil {
                            expandedPreviousID = nil
                        }
                    }
                }

                if isExpanded {
                    let rolesForRecord = getRoles(for: record)
                    let fociForRecord = getFoci(for: record)

                    VStack(alignment: .leading, spacing: 16) {
                    Text("Mission")
                        .font(.headline)
                        .foregroundColor(.black)
                    TextEditor(text: purposeBinding(for: record))
                        .focused($focusedPurposeCategoryID, equals: record.category_id)
                        .textInputAutocapitalization(.sentences)
                        .autocorrectionDisabled(false)
                        .scrollContentBackground(.hidden)
                        .frame(minHeight: 120)
                        .padding(8)
                        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))

                    Text("Identity")
                        .font(.headline)
                        .foregroundColor(.black)
                    styledManageListBox(
                        primaryRowTitle: rolesForRecord.isEmpty ? "Add Identity" : "Manage Identity",
                        items: rolesForRecord.map { .init(id: $0.id, title: $0.role, subtitle: nil) },
                        onPrimaryTap: {
                            if rolesForRecord.isEmpty {
                                presentRoleEditorForNew(record: record)
                            } else {
                                presentRolesManager(for: record)
                            }
                        },
                        onItemTap: { id in
                            guard let role = rolesForRecord.first(where: { $0.id == id }) else { return }
                            presentRoleEditor(for: role, categoryTitle: record.category)
                        }
                    )

                    Text("Little Wins")
                        .font(.headline)
                        .foregroundColor(.black)
                    VStack(spacing: 0) {
                        Button {
                            if fociForRecord.isEmpty {
                                presentLittleWinsEditorForNew(record: record)
                            } else {
                                presentLittleWinsManager(for: record)
                            }
                        } label: {
                            HStack {
                                Text(fociForRecord.isEmpty ? "Add Little Win" : "Manage Little Wins")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 14)
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)

                        if !fociForRecord.isEmpty {
                            Divider()
                            ForEach(Array(fociForRecord.enumerated()), id: \.element.id) { index, f in
                                Button {
                                    presentLittleWinsEditor(for: f, categoryTitle: record.category)
                                } label: {
                                    HStack(spacing: 0) {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(f.activity)
                                                .foregroundStyle(.primary)
                                                .lineLimit(nil)
                                                .fixedSize(horizontal: false, vertical: true)
                                            let summary = activeWeekdaySummary(for: f)
                                            if summary != "Any day" {
                                                Text(summary)
                                                    .font(.caption)
                                                    .foregroundStyle(.secondary)
                                            }
                                        }
                                        Spacer(minLength: 0)
                                    }
                                    .frame(minHeight: 44, alignment: .leading)
                                    .padding(.vertical, 6)
                                    .padding(.horizontal, 14)
                                    .contentShape(Rectangle())
                                }
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .contentShape(Rectangle())
                                .buttonStyle(.plain)

                                if index < fociForRecord.count - 1 {
                                    Divider()
                                }
                            }
                        }
                    }
                    .background(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(.secondarySystemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .stroke(Color(.separator).opacity(0.4), lineWidth: 1)
                    )

                    PassionsSectionView(record: record)
                    }
                    .padding()
                    .background(lightColor)
                }
            }
            .onReceive(NotificationCenter.default.publisher(
                for: UIResponder.keyboardWillShowNotification
            )) { _ in
                if expandedCardID == id {
                    expandedCardID = id
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: Color.black.opacity(0.1), radius: 6, x: 0, y: 3)
    }

    private func estimatedListContentHeight(items: [String], hasInputRow: Bool) -> CGFloat {
        let textRowsHeight = items.reduce(CGFloat.zero) { partial, item in
            partial + estimatedListTextRowHeight(item)
        }
        let inputRowHeight: CGFloat = hasInputRow ? 52 : 0
        // Keep one row visible even when there are no items yet.
        return max(textRowsHeight + inputRowHeight, 56)
    }

    private func estimatedListTextRowHeight(_ text: String) -> CGFloat {
        let measured = estimatedTextHeight(for: text, width: 220)
        // Includes row insets and room for edit controls.
        return max(56, measured + 26)
    }

    private func estimatedTextHeight(for text: String, width: CGFloat) -> CGFloat {
#if canImport(UIKit)
        let font = UIFont.preferredFont(forTextStyle: .body)
        let attrs: [NSAttributedString.Key: Any] = [.font: font]
        let rect = NSString(string: text).boundingRect(
            with: CGSize(width: width, height: .greatestFiniteMagnitude),
            options: [.usesLineFragmentOrigin, .usesFontLeading],
            attributes: attrs,
            context: nil
        )
        return ceil(rect.height)
#else
        _ = text
        _ = width
        return 20
#endif
    }

    // MARK: - Completion Helpers
    private func batteryIconName(for record: Fulfillment) -> String {
        let count = completionCount(for: record)
        switch count {
        case 0: return "battery.0"
        case 1...2: return "battery.25"
        case 3...4: return "battery.50"
        case 5: return "battery.75"
        default: return "battery.100"
        }
    }

    private func completionCount(for record: Fulfillment) -> Int {
        let hasPurpose = !record.category_purpose.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let hasRole = roles.contains { $0.category_id == record.category_id }
        let hasFocus = foci.contains { $0.category_id == record.category_id }
        let passionIDs = Set(passions.map(\.passion_id))
        let hasPassion = passionJoins.contains { $0.category_id == record.category_id && passionIDs.contains($0.passion_id) }
        return [hasPurpose, hasRole, hasFocus, hasPassion].filter { $0 }.count
    }

    private var fulfillmentMetrics: [(String, Color, Double)] {
        orderedFulfillments.map { record in
            let title = record.category
            let pct = fulfillmentRadarPercentage(for: record)
            return (title, FulfillmentCategoryTheme.color(for: title), pct)
        }
    }

    private func fulfillmentRadarPercentage(for record: Fulfillment) -> Double {
        if let score = latestFulfillmentWeeklyScore(for: record) {
            return (FulfillmentScoringMath.clamp(score, 1, 5) / 5.0) * 100.0
        }
        return batteryPercentage(for: record)
    }

    private func batteryPercentage(for record: Fulfillment) -> Double {
        if let score = latestFulfillmentWeeklyScore(for: record) {
            return ((FulfillmentScoringMath.clamp(score, 1, 5) - 1.0) / 4.0) * 100.0
        }
        let count = completionCount(for: record)
        switch count {
        case 0: return 0
        case 1...2: return 25
        case 3...4: return 50
        case 5: return 75
        default: return 100
        }
    }

    private func latestFulfillmentWeeklyScore(for record: Fulfillment) -> Double? {
        let weekStart = FulfillmentScoringMath.weekWindow(for: .now).weekStart
        return fulfillmentCategoryScoreSnapshots.first(where: {
            $0.categoryID == record.category_id &&
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: weekStart)
        })?.score
    }

    private func latestFulfillmentWeeklySnapshot(for record: Fulfillment) -> FulfillmentCategoryScoreSnapshot? {
        let weekStart = FulfillmentScoringMath.weekWindow(for: .now).weekStart
        return fulfillmentCategoryScoreSnapshots.first(where: {
            $0.categoryID == record.category_id &&
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: weekStart)
        })
    }

    private func fulfillmentWeekOverWeekDelta(for record: Fulfillment) -> Double? {
        let currentWeek = FulfillmentScoringMath.weekWindow(for: .now).weekStart
        guard let priorWeek = Calendar.current.date(byAdding: .day, value: -7, to: currentWeek) else { return nil }
        guard let current = fulfillmentCategoryScoreSnapshots.first(where: {
            $0.categoryID == record.category_id && Calendar.current.isDate($0.weekStartDate, inSameDayAs: currentWeek)
        })?.score else { return nil }
        guard let prior = fulfillmentCategoryScoreSnapshots.first(where: {
            $0.categoryID == record.category_id && Calendar.current.isDate($0.weekStartDate, inSameDayAs: priorWeek)
        })?.score else { return nil }
        let currentShown = roundedTenth(current)
        let priorShown = roundedTenth(prior)
        let delta = currentShown - priorShown
        return abs(delta) < 0.05 ? 0 : delta
    }

    private func headerCategoryDeltaText(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "—" }
        return String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
    }

    private func headerCategoryDeltaGlyph(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private func headerCategoryDeltaColor(_ delta: Double?) -> Color {
        guard let delta else { return .secondary }
        if abs(delta) < 0.05 { return .secondary }
        return delta > 0 ? .green : .orange
    }

    private func fulfillmentReadableInsightPayload(
        for snap: FulfillmentCategoryScoreSnapshot,
        categoryTitle: String,
        weekOverWeekDelta: Double?
    ) -> FulfillmentReadableInsightRequestPayload {
        let weekStart = Calendar.current.startOfDay(for: snap.weekStartDate)
        let sameWeek = fulfillmentCategoryScoreSnapshots.filter {
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: weekStart)
        }
        let sortedByScore = sameWeek.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return (lhs.categoryTitleSnapshot).localizedCaseInsensitiveCompare(rhs.categoryTitleSnapshot) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
        let peerRank = sortedByScore.firstIndex(where: { $0.categoryID == snap.categoryID }).map { $0 + 1 }
        let strongest = sortedByScore.first
        let peerAverage = sameWeek.isEmpty ? nil : (sameWeek.map(\.score).reduce(0, +) / Double(sameWeek.count))

        let priorWeek = Calendar.current.date(byAdding: .day, value: -7, to: weekStart)
        let inferredDelta: Double? = {
            if let weekOverWeekDelta { return roundedTenth(weekOverWeekDelta) }
            guard let priorWeek else { return nil }
            guard let prior = fulfillmentCategoryScoreSnapshots.first(where: {
                $0.categoryID == snap.categoryID && Calendar.current.isDate($0.weekStartDate, inSameDayAs: priorWeek)
            }) else { return nil }
            return roundedTenth(snap.score) - roundedTenth(prior.score)
        }()

        let recentScores = fulfillmentCategoryScoreSnapshots
            .filter { $0.categoryID == snap.categoryID }
            .sorted { $0.weekStartDate > $1.weekStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        let movers: [(FulfillmentCategoryScoreSnapshot, Double)] = sameWeek.compactMap { row in
            guard let priorWeek else { return nil }
            guard let prior = fulfillmentCategoryScoreSnapshots.first(where: {
                $0.categoryID == row.categoryID && Calendar.current.isDate($0.weekStartDate, inSameDayAs: priorWeek)
            }) else { return nil }
            let delta = roundedTenth(row.score) - roundedTenth(prior.score)
            return (row, delta)
        }
        let biggestMover = movers.max { abs($0.1) < abs($1.1) }

        return FulfillmentReadableInsightRequestPayload(
            categoryID: snap.categoryID,
            categoryTitle: categoryTitle,
            weekStartISO8601: weekStart.ISO8601Format(),
            score: roundedTenth(snap.score),
            weekScore: roundedTenth(snap.targetScore),
            weekOverWeekDelta: inferredDelta,
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: FulfillmentScoringMath.clamped01(snap.structure),
            outcomes: FulfillmentScoringMath.clamped01(snap.outcomes),
            actionBlocks: FulfillmentScoringMath.clamped01(snap.actionBlocks),
            littleWins: FulfillmentScoringMath.clamped01(snap.littleWins),
            engagement: FulfillmentScoringMath.clamped01(snap.engagement),
            strategicBehavior: FulfillmentScoringMath.clamped01(snap.strategicBalance),
            carryoverPenalty: FulfillmentScoringMath.clamped01(snap.carryoverPenalty),
            peerAverageScore: peerAverage.map(roundedTenth),
            peerRank: peerRank,
            peerCount: sameWeek.isEmpty ? nil : sameWeek.count,
            strongestCategory: strongest?.categoryTitleSnapshot,
            strongestCategoryScore: strongest.map { roundedTenth($0.score) },
            biggestMoverCategory: biggestMover.map { $0.0.categoryTitleSnapshot },
            biggestMoverDelta: biggestMover.map { roundedTenth($0.1) },
            recentCategoryScores: recentScores
        )
    }

    private func aiFulfillmentReadableInsightText(
        for snap: FulfillmentCategoryScoreSnapshot,
        categoryTitle: String,
        weekOverWeekDelta: Double?
    ) -> String? {
        let payload = fulfillmentReadableInsightPayload(for: snap, categoryTitle: categoryTitle, weekOverWeekDelta: weekOverWeekDelta)
        let key = fulfillmentReadableInsightKey(for: payload)
        guard let base = aiReadableInsightsByKey[key] ?? FulfillmentReadableInsightRuntimeStore.value(for: key) else { return nil }
        return ensureFulfillmentReadableInsightCTA(base, payload: payload)
    }

    @MainActor
    private func requestFulfillmentReadableInsightIfNeeded(
        for snap: FulfillmentCategoryScoreSnapshot,
        categoryTitle: String,
        weekOverWeekDelta: Double?
    ) async {
        let payload = fulfillmentReadableInsightPayload(for: snap, categoryTitle: categoryTitle, weekOverWeekDelta: weekOverWeekDelta)
        let key = fulfillmentReadableInsightKey(for: payload)
        if !loomAIInsightsRefreshEnabled(),
           let cached = aiReadableInsightsByKey[key] ?? FulfillmentReadableInsightRuntimeStore.value(for: key) {
            aiReadableInsightsByKey[key] = cached
            return
        }
        aiReadableInsightLoadingKeys.insert(key)
        defer { aiReadableInsightLoadingKeys.remove(key) }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: fulfillmentReadableInsightPrompt(for: payload))],
                context: contextSnapshot,
                intent: "readable_insight_fulfillment",
                screen: "fulfillment_readable_header"
            )
            let normalized = normalizeFulfillmentReadableInsightMetricReferences(response.message, payload: payload)
            let text = limitFulfillmentReadableInsightText(normalized, maxCharacters: 220)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            FulfillmentReadableInsightRuntimeStore.set(trimmed, for: key)
            aiReadableInsightsByKey[key] = trimmed
        } catch {
            // Keep local heuristic fallback if the API is unavailable.
        }
    }

    private func primaryFulfillmentHeaderInsightMessage(for snap: FulfillmentCategoryScoreSnapshot) -> String? {
        let structure = FulfillmentScoringMath.clamped01(snap.structure)
        let outcomes = FulfillmentScoringMath.clamped01(snap.outcomes)
        let actionBlocks = FulfillmentScoringMath.clamped01(snap.actionBlocks)
        let littleWins = FulfillmentScoringMath.clamped01(snap.littleWins)
        let engagement = FulfillmentScoringMath.clamped01(snap.engagement)
        let strategic = FulfillmentScoringMath.clamped01(snap.strategicBalance)
        let carry = FulfillmentScoringMath.clamped01(snap.carryoverPenalty)

        let structurePct = Int((structure * 100).rounded())
        let outcomesPct = Int((outcomes * 100).rounded())
        let actionPct = Int((actionBlocks * 100).rounded())
        let winsPct = Int((littleWins * 100).rounded())
        let engagementPct = Int((engagement * 100).rounded())
        let strategicPct = Int((strategic * 100).rounded())
        let carryPct = Int((carry * 100).rounded())

        if carry >= 0.30 {
            return "Carryover is high (\(carryPct)% penalty). Reduce scope or break tasks into smaller chunks."
        }
        if structure >= 0.7 && actionBlocks <= 0.45 {
            return "Well designed (\(structurePct)% Structure), but execution is weak (\(actionPct)% Action blocks)."
        }
        if littleWins >= 0.65 && outcomes <= 0.45 {
            return "Little Wins are strong (\(winsPct)%), but outcomes are lagging (\(outcomesPct)%)."
        }
        if engagement <= 0.30 {
            return "Engagement is low (\(engagementPct)%). Touch this area on more days this week."
        }
        if strategic <= 0.40 && actionBlocks >= 0.40 {
            return "Strategic behavior is low (\(strategicPct)%). Prioritize must-do work first."
        }
        if structure <= 0.35 {
            return "Foundation is weak (\(structurePct)% Structure). Clarify vision, purpose, or roles."
        }
        if outcomes >= 0.7 && actionBlocks >= 0.7 && carry <= 0.15 {
            return "Strong outcomes (\(outcomesPct)%) and execution (\(actionPct)%) with low carryover."
        }
        if actionBlocks >= 0.55 && littleWins <= 0.35 {
            return "Action blocks are stronger than daily consistency (\(actionPct)% vs \(winsPct)% Little Wins)."
        }
        return "This area is stable overall. Improve one weak signal this week to raise the score."
    }

    private func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func refreshFulfillmentCategoryScoresForCurrentWeek() {
        _ = try? FulfillmentScoringService().computeAndPersistCurrentWeek(in: modelContext)
    }

    // MARK: - Data Helpers

    private func visionBinding(for record: Fulfillment) -> Binding<String> {
        Binding(
            get: { visionDrafts[record.category_id] ?? record.category_vision },
            set: { newValue in
                visionDrafts[record.category_id] = newValue
            }
        )
    }

    private func purposeBinding(for record: Fulfillment) -> Binding<String> {
        Binding(
            get: { purposeDrafts[record.category_id] ?? record.category_purpose },
            set: { newValue in
                purposeDrafts[record.category_id] = newValue
            }
        )
    }

    private func commitVisionDraft(for categoryID: UUID?) {
        guard let categoryID,
              let draft = visionDrafts[categoryID],
              let record = fulfillments.first(where: { $0.category_id == categoryID })
        else { return }
        updateVision(record: record, newText: draft)
        visionDrafts[categoryID] = record.category_vision
    }

    private func commitPurposeDraft(for categoryID: UUID?) {
        guard let categoryID,
              let draft = purposeDrafts[categoryID],
              let record = fulfillments.first(where: { $0.category_id == categoryID })
        else { return }
        updatePurpose(record: record, newText: draft)
        purposeDrafts[categoryID] = record.category_purpose
    }

    private func updateVision(record: Fulfillment, newText: String) {
        guard record.category_vision != newText else { return }
        let archive = FulfillmentArchive(
            category_id: record.category_id,
            updatedAt: record.updatedAt,
            category: record.category,
            category_identitiy: record.category_identitiy,
            category_vision: record.category_vision,
            category_purpose: record.category_purpose,
            archivedAt: Date()
        )
        modelContext.insert(archive)
        record.category_vision = newText
        record.updatedAt = Date()
    }

    private func updatePurpose(record: Fulfillment, newText: String) {
        guard record.category_purpose != newText else { return }
        let archive = FulfillmentArchive(
            category_id: record.category_id,
            updatedAt: record.updatedAt,
            category: record.category,
            category_identitiy: record.category_identitiy,
            category_vision: record.category_vision,
            category_purpose: record.category_purpose,
            archivedAt: Date()
        )
        modelContext.insert(archive)
        record.category_purpose = newText
        record.updatedAt = Date()
    }

    private func getRoles(for f: Fulfillment) -> [FulfillmentRoles] {
        roles.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addRole(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        guard getRoles(for: record).count < 3 else { return }
        let nextRank = (getRoles(for: record).map(\.rank).max() ?? 0) + 1
        let r = FulfillmentRoles(category_id: record.category_id, role: text, rank: nextRank)
        modelContext.insert(r)
        if nextRank == 1 {
            let archive = FulfillmentArchive(
                category_id: record.category_id,
                updatedAt: record.updatedAt,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            record.category_identitiy = text
            record.updatedAt = Date()
        }
    }

    private func moveRoles(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getRoles(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, r) in list.enumerated() {
            if r.rank != i + 1 {
                let archive = FulfillmentRolesArchive(
                    category_id: r.category_id,
                    updatedAt: r.updatedAt,
                    role: r.role,
                    rank: r.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                r.rank = i + 1
                r.updatedAt = Date()
            }
        }
        if let top = list.first, top.role != record.category_identitiy {
            let archive = FulfillmentArchive(
                category_id: record.category_id,
                updatedAt: record.updatedAt,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            record.category_identitiy = top.role
            record.updatedAt = Date()
        }
    }

    private func deleteRoles(at offsets: IndexSet, record: Fulfillment) {
        let list = getRoles(for: record)
        for idx in offsets {
            let r = list[idx]
            let archive = FulfillmentRolesArchive(
                category_id: r.category_id,
                updatedAt: r.updatedAt,
                role: r.role,
                rank: r.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            RecentlyDeletedStore.trash(r, in: modelContext)
        }
    }

    private func getFoci(for f: Fulfillment) -> [FulfillmentFocus] {
        foci.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func activeWeekdaySummary(for focus: FulfillmentFocus) -> String {
        _ = littleWinsScheduleStoreRevision
        let rule = LittleWinsScheduleStore.rule(for: focus.id)
        if rule.canCompleteAnyDay { return "Any day" }
        let normalizedMask = rule.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let labels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]
        let selected = labels.enumerated().compactMap { index, label in
            (normalizedMask & (1 << index)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func presentLittleWinsManager(for record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsManagerTarget(id: record.category_id, categoryTitle: record.category)
        DispatchQueue.main.async {
            littleWinsManagerTarget = target
        }
    }

    private func presentLittleWinsEditorForNew(record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsEditorTarget(
            categoryID: record.category_id,
            categoryTitle: record.category,
            focusID: nil,
            autoFocus: true
        )
        DispatchQueue.main.async {
            littleWinsEditorTarget = target
        }
    }

    private func presentLittleWinsEditor(for focus: FulfillmentFocus, categoryTitle: String) {
        prepareForLittleWinsSheetPresentation()
        let target = LittleWinsEditorTarget(
            categoryID: focus.category_id,
            categoryTitle: categoryTitle,
            focusID: focus.id,
            autoFocus: false
        )
        DispatchQueue.main.async {
            littleWinsEditorTarget = target
        }
    }

    private func prepareForLittleWinsSheetPresentation() {
        commitInlineIfNeeded()
        commitVisionDraft(for: focusedVisionCategoryID)
        commitPurposeDraft(for: focusedPurposeCategoryID)
        focusedField = nil
        focusedVisionCategoryID = nil
        focusedPurposeCategoryID = nil
    }

    private func dismissFulfillmentKeyboard() {
        commitInlineIfNeeded()
        commitVisionDraft(for: focusedVisionCategoryID)
        commitPurposeDraft(for: focusedPurposeCategoryID)
        focusedField = nil
        focusedVisionCategoryID = nil
        focusedPurposeCategoryID = nil
    }

    private func presentRolesManager(for record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = RolesManagerTarget(id: record.category_id, categoryTitle: record.category)
        DispatchQueue.main.async {
            rolesManagerTarget = target
        }
    }

    private func presentRoleEditorForNew(record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = RoleEditorTarget(categoryID: record.category_id, categoryTitle: record.category, roleID: nil, autoFocus: true)
        DispatchQueue.main.async {
            roleEditorTarget = target
        }
    }

    private func presentRoleEditor(for role: FulfillmentRoles, categoryTitle: String) {
        prepareForLittleWinsSheetPresentation()
        let target = RoleEditorTarget(categoryID: role.category_id, categoryTitle: categoryTitle, roleID: role.id, autoFocus: false)
        DispatchQueue.main.async {
            roleEditorTarget = target
        }
    }

    private func presentResourcesManager(for record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = ResourcesManagerTarget(id: record.category_id, categoryTitle: record.category)
        DispatchQueue.main.async {
            resourcesManagerTarget = target
        }
    }

    private func presentResourceEditorForNew(record: Fulfillment) {
        prepareForLittleWinsSheetPresentation()
        let target = ResourceEditorTarget(categoryID: record.category_id, categoryTitle: record.category, resourceID: nil, autoFocus: true)
        DispatchQueue.main.async {
            resourceEditorTarget = target
        }
    }

    private func presentResourceEditor(for resource: FulfillmentResources, categoryTitle: String) {
        prepareForLittleWinsSheetPresentation()
        let target = ResourceEditorTarget(categoryID: resource.category_id, categoryTitle: categoryTitle, resourceID: resource.id, autoFocus: false)
        DispatchQueue.main.async {
            resourceEditorTarget = target
        }
    }

    private func addFocus(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        guard getFoci(for: record).count < 3 else { return }
        let nextRank = (getFoci(for: record).map(\.rank).max() ?? 0) + 1
        let f = FulfillmentFocus(category_id: record.category_id, activity: text, rank: nextRank)
        modelContext.insert(f)
    }

    private func moveFoci(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getFoci(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, f) in list.enumerated() {
            if f.rank != i + 1 {
                let archive = FulfillmentFocusArchive(
                    category_id: f.category_id,
                    updatedAt: f.updatedAt,
                    activity: f.activity,
                    rank: f.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                f.rank = i + 1
                f.updatedAt = Date()
            }
        }
    }

    private func deleteFoci(at offsets: IndexSet, record: Fulfillment) {
        let list = getFoci(for: record)
        for idx in offsets {
            let f = list[idx]
            let archive = FulfillmentFocusArchive(
                category_id: f.category_id,
                updatedAt: f.updatedAt,
                activity: f.activity,
                rank: f.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            LittleWinsScheduleStore.removeRule(for: f.id)
            LittleWinsIntegrationStore.removeConfig(for: f.id)
            LittleWinsPassionsStore.removePassions(for: f.id)
            RecentlyDeletedStore.trash(f, in: modelContext)
        }
    }

    private func getResources(for f: Fulfillment) -> [FulfillmentResources] {
        resources.filter { $0.category_id == f.category_id }
            .sorted { $0.rank < $1.rank }
    }

    private func addResource(text: String, record: Fulfillment) {
        guard !text.isEmpty else { return }
        let nextRank = (getResources(for: record).map(\.rank).max() ?? 0) + 1
        let r = FulfillmentResources(category_id: record.category_id, resource: text, rank: nextRank)
        modelContext.insert(r)
    }

    private func moveResources(from offsets: IndexSet, to destination: Int, record: Fulfillment) {
        var list = getResources(for: record)
        list.move(fromOffsets: offsets, toOffset: destination)
        for (i, r) in list.enumerated() {
            if r.rank != i + 1 {
                let archive = FulfillmentResourcesArchive(
                    category_id: r.category_id,
                    updatedAt: r.updatedAt,
                    resource: r.resource,
                    rank: r.rank,
                    archivedAt: Date()
                )
                modelContext.insert(archive)
                r.rank = i + 1
                r.updatedAt = Date()
            }
        }
    }

    private func deleteResources(at offsets: IndexSet, record: Fulfillment) {
        let list = getResources(for: record)
        for idx in offsets {
            let r = list[idx]
            let archive = FulfillmentResourcesArchive(
                category_id: r.category_id,
                updatedAt: r.updatedAt,
                resource: r.resource,
                rank: r.rank,
                archivedAt: Date()
            )
            modelContext.insert(archive)
            RecentlyDeletedStore.trash(r, in: modelContext)
        }
    }
}

struct LittleWinsManagerSheetView: View {
    private struct EditorTarget: Identifiable {
        let focusID: UUID?
        let categoryID: UUID
        let categoryTitle: String
        let autoFocus: Bool

        var id: String {
            if let focusID { return "edit-\(focusID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    let categoryID: UUID
    let categoryTitle: String
    let showsAddButton: Bool
    let persistsChanges: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var foci: [FulfillmentFocus]

    @State private var isDeleteMode = false
    @State private var selectedIDsForDelete: Set<UUID> = []
    @State private var editorTarget: EditorTarget?
    @State private var showDeleteGuardHint = false

    private let weekdayLabels = ["Sun", "Mon", "Tue", "Wed", "Thu", "Fri", "Sat"]

    init(
        categoryID: UUID,
        categoryTitle: String,
        showsAddButton: Bool = true,
        persistsChanges: Bool = true
    ) {
        self.categoryID = categoryID
        self.categoryTitle = categoryTitle
        self.showsAddButton = showsAddButton
        self.persistsChanges = persistsChanges
    }

    private var littleWins: [FulfillmentFocus] {
        foci.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if showsAddButton && !isDeleteMode && littleWins.count < 3 {
                        Button {
                            startCreatingNew()
                        } label: {
                            HStack {
                                Text("Add Little Win")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    ForEach(littleWins, id: \.id) { focus in
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
                                    let summary = weekdaySummary(for: LittleWinsScheduleStore.rule(for: focus.id))
                                    if summary != "Any day" {
                                        Text(summary)
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
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Little Wins")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isDeleteMode)
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
                    } else if !littleWins.isEmpty {
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
                autoFocusTextField: target.autoFocus,
                persistsChanges: persistsChanges
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

    private func beginEditing(_ focus: FulfillmentFocus) {
        editorTarget = .init(
            focusID: focus.id,
            categoryID: categoryID,
            categoryTitle: categoryTitle,
            autoFocus: false
        )
    }

    private func startCreatingNew() {
        guard littleWins.count < 3 else { return }
        editorTarget = .init(
            focusID: nil,
            categoryID: categoryID,
            categoryTitle: categoryTitle,
            autoFocus: true
        )
    }

    private func toggleDeleteSelection(for id: UUID) {
        if selectedIDsForDelete.contains(id) {
            selectedIDsForDelete.remove(id)
        } else {
            selectedIDsForDelete.insert(id)
        }
    }

    private func weekdaySummary(for rule: LittleWinsScheduleRule) -> String {
        let normalized = rule.normalized
        if normalized.canCompleteAnyDay { return "Any day" }
        let normalizedMask = normalized.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == 0b0111110 { return "Weekdays" } // Mon-Fri
        if normalizedMask == 0b1000001 { return "Weekend" } // Sun+Sat
        let selected = weekdayLabels.enumerated().compactMap { idx, label in
            (normalizedMask & (1 << idx)) != 0 ? label : nil
        }
        return selected.isEmpty ? "No days selected" : selected.joined(separator: ", ")
    }

    private func deleteSelected() {
        let targets = littleWins.filter { selectedIDsForDelete.contains($0.id) }
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
            LittleWinsPassionsStore.removePassions(for: focus.id)
            RecentlyDeletedStore.trash(focus, in: modelContext)
        }
        if persistsChanges {
            try? modelContext.save()
        }
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

private struct RolesManagerSheetView: View {
    private struct EditorTarget: Identifiable {
        let roleID: UUID?
        let categoryID: UUID
        let categoryTitle: String
        let autoFocus: Bool

        var id: String {
            if let roleID { return "edit-\(roleID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    let categoryID: UUID
    let categoryTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var roles: [FulfillmentRoles]

    @State private var isDeleteMode = false
    @State private var selectedIDsForDelete: Set<UUID> = []
    @State private var editorTarget: EditorTarget?

    private var categoryRoles: [FulfillmentRoles] {
        roles.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !isDeleteMode && categoryRoles.count < 3 {
                        Button {
                            editorTarget = .init(roleID: nil, categoryID: categoryID, categoryTitle: categoryTitle, autoFocus: true)
                        } label: {
                            HStack {
                                Text("Add Identity")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    ForEach(categoryRoles, id: \.id) { role in
                        Button {
                            guard !isDeleteMode else {
                                toggleDeleteSelection(for: role.id)
                                return
                            }
                            editorTarget = .init(roleID: role.id, categoryID: categoryID, categoryTitle: categoryTitle, autoFocus: false)
                        } label: {
                            HStack(spacing: 10) {
                                if isDeleteMode {
                                    Image(systemName: selectedIDsForDelete.contains(role.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDsForDelete.contains(role.id) ? .red : .secondary)
                                }
                                Text(role.role)
                                    .foregroundStyle(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if !isDeleteMode {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Identity")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isDeleteMode)
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
                    } else if !categoryRoles.isEmpty {
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
            RoleEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                roleID: target.roleID,
                autoFocusTextField: target.autoFocus
            )
        }
    }

    private func toggleDeleteSelection(for id: UUID) {
        if selectedIDsForDelete.contains(id) {
            selectedIDsForDelete.remove(id)
        } else {
            selectedIDsForDelete.insert(id)
        }
    }

    private func deleteSelected() {
        let targets = categoryRoles.filter { selectedIDsForDelete.contains($0.id) }
        guard !targets.isEmpty else { return }
        for role in targets {
            modelContext.insert(
                FulfillmentRolesArchive(
                    category_id: role.category_id,
                    updatedAt: role.updatedAt,
                    role: role.role,
                    rank: role.rank,
                    archivedAt: Date()
                )
            )
            RecentlyDeletedStore.trash(role, in: modelContext)
        }
        try? modelContext.save()
        selectedIDsForDelete.removeAll()
        isDeleteMode = false
    }
}

private struct RoleEditorSheetView: View {
    let categoryID: UUID
    let categoryTitle: String
    let roleID: UUID?
    let autoFocusTextField: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    @Query private var roles: [FulfillmentRoles]
    @Query private var fulfillments: [Fulfillment]

    @State private var draftText = ""
    @State private var didHydrate = false
    @State private var autoWriteSuggestions: [String] = []
    @State private var autoWritePreviousSuggestions: [String] = []
    @State private var autoWriteAppliedSuggestion: String?
    @State private var autoWriteErrorMessage: String? = nil
    @State private var autoWriteTroubleshootingMessage: String? = nil
    @State private var autoWriteIsLoading = false
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>?
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFocused: Bool

    private struct IdentityAutoWriteSuggestionDTO: Decodable {
        let identity: String?
        let role: String?
        let text: String?
    }

    private struct IdentityAutoWriteResponse: Decodable {
        let suggestions: [IdentityAutoWriteSuggestionDTO]?
    }

    private var categoryRoles: [FulfillmentRoles] {
        roles.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private var editingRole: FulfillmentRoles? {
        guard let roleID else { return nil }
        return roles.first { $0.id == roleID }
    }

    private var categoryRecord: Fulfillment? {
        fulfillments.first { $0.category_id == categoryID }
    }

    private var isEditing: Bool { roleID != nil }
    private var doneDisabled: Bool { draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    private var showsAutoWrite: Bool { !isEditing && categoryRoles.count < 3 }
    private let autoWriteFloatingGap: CGFloat = 12
    private var keyboardAccessoryShowsCheckmark: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func autoWriteBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return 18 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + autoWriteFloatingGap
    }

    private var floatingAutoWriteButton: some View {
        Button {
            guard !autoWriteIsLoading else { return }
            Task { await requestAutoWriteSuggestions() }
        } label: {
            HStack(spacing: 6) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 27, height: 27)
                    .rotation3DEffect(
                        .degrees(autoWriteIsLoading && autoWriteIconAnimating ? 180 : 0),
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
        .disabled(autoWriteIsLoading)
        .opacity(autoWriteIsLoading ? 0.7 : 1)
        .onAppear {
            guard autoWriteOutlineAngle == 0 else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                autoWriteOutlineAngle = 360
            }
        }
    }

    private var keyboardAutoWriteButton: some View {
        Button {
            guard !autoWriteIsLoading else { return }
            Task { await requestAutoWriteSuggestions() }
        } label: {
            HStack(spacing: 5) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .rotation3DEffect(
                        .degrees(autoWriteIsLoading && autoWriteIconAnimating ? 180 : 0),
                        axis: (x: 1, y: 0, z: 0)
                    )
                Text("AutoWrite")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(autoWriteGradient)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(autoWriteGradient, lineWidth: 1.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(autoWriteIsLoading)
        .opacity(autoWriteIsLoading ? 0.7 : 1)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isEditing ? "Edit Identity" : "Add Identity") {
                    TextField("H2O lover", text: $draftText)
                        .focused($isTextFocused)
                        .textInputAutocapitalization(.sentences)

                    if showsAutoWrite {
                        if !autoWriteSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(autoWriteSuggestions, id: \.self) { suggestion in
                                    let normalized = normalizedAutoWriteText(suggestion)
                                    let isApplied = autoWriteAppliedSuggestion == normalized
                                    Button {
                                        draftText = suggestion
                                        autoWriteAppliedSuggestion = normalized
                                        isTextFocused = false
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image("LoomAI")
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                                .padding(.top, 1)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(isApplied ? "Added Identity in \(categoryTitle):" : "Add Identity in \(categoryTitle):")
                                                    .font(.subheadline.italic())
                                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                                    .multilineTextAlignment(.leading)
                                                Text(suggestion)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(nil)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                if isApplied {
                                                    Text("Tap field to edit")
                                                        .font(.caption)
                                                        .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                                }
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
                        if let errorMessage = autoWriteErrorMessage {
                            autoWriteRetryRow(
                                message: errorMessage,
                                troubleshooting: autoWriteTroubleshootingMessage
                            ) {
                                Task { await requestAutoWriteSuggestions() }
                            }
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "Edit Identity" : "Add Identity")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { saveAndDismiss() }
                        .disabled(doneDisabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isTextFocused {
                        Spacer(minLength: 0)
                        if showsAutoWrite {
                            keyboardAutoWriteButton
                        }
                        Button {
                            if keyboardAccessoryShowsCheckmark {
                                saveAndDismiss()
                            } else {
                                isTextFocused = false
                            }
                        } label: {
                            Image(systemName: keyboardAccessoryShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(keyboardAccessoryShowsCheckmark ? .white : .primary.opacity(0.85))
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle().fill(
                                        keyboardAccessoryShowsCheckmark
                                            ? Color.blue
                                            : Color(.secondarySystemBackground)
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.black.opacity(keyboardAccessoryShowsCheckmark ? 0 : 0.08),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            GeometryReader { proxy in
                if showsAutoWrite && !isTextFocused {
                    HStack(spacing: 8) {
                        floatingAutoWriteButton
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, autoWriteBottomPadding(in: proxy))
                }
            }
        }
        .presentationDetents([.height(220), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            hydrateIfNeeded()
            guard autoFocusTextField else { return }
            DispatchQueue.main.async { isTextFocused = true }
        }
        .onChange(of: draftText) { _, newValue in
            guard let applied = autoWriteAppliedSuggestion else { return }
            if normalizedAutoWriteText(newValue) != applied {
                autoWriteAppliedSuggestion = nil
            }
        }
        .onChange(of: autoWriteIsLoading, initial: false) { _, isLoading in
            setAutoWriteLoadingAnimation(isLoading)
        }
        .onDisappear {
            setAutoWriteLoadingAnimation(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIScreen.main.bounds.height
            keyboardHeight = max(0, screenHeight - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
    }

    private func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        if let editingRole {
            draftText = editingRole.role
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let editingRole {
            guard editingRole.role != trimmed else {
                dismiss()
                return
            }
            modelContext.insert(
                FulfillmentRolesArchive(
                    category_id: editingRole.category_id,
                    updatedAt: editingRole.updatedAt,
                    role: editingRole.role,
                    rank: editingRole.rank,
                    archivedAt: Date()
                )
            )
            editingRole.role = trimmed
            editingRole.updatedAt = Date()

            if editingRole.rank == 1, let categoryRecord, categoryRecord.category_identitiy != trimmed {
                archiveAndUpdateCategoryIdentity(record: categoryRecord, newIdentity: trimmed)
            }
        } else {
            guard let categoryRecord else { return }
            guard categoryRoles.count < 3 else {
                dismiss()
                return
            }
            let nextRank = (categoryRoles.map(\.rank).max() ?? 0) + 1
            let role = FulfillmentRoles(category_id: categoryID, role: trimmed, rank: nextRank)
            modelContext.insert(role)
            if nextRank == 1 {
                archiveAndUpdateCategoryIdentity(record: categoryRecord, newIdentity: trimmed)
            }
        }

        try? modelContext.save()
        dismiss()
    }

    private func archiveAndUpdateCategoryIdentity(record: Fulfillment, newIdentity: String) {
        modelContext.insert(
            FulfillmentArchive(
                category_id: record.category_id,
                updatedAt: record.updatedAt,
                category: record.category,
                category_identitiy: record.category_identitiy,
                category_vision: record.category_vision,
                category_purpose: record.category_purpose,
                archivedAt: Date()
            )
        )
        record.category_identitiy = newIdentity
        record.updatedAt = Date()
    }

    private func requestAutoWriteSuggestions() async {
        guard !autoWriteIsLoading else { return }
        autoWriteIsLoading = true
        let previousSuggestions = autoWritePreviousSuggestions
        autoWriteErrorMessage = nil
        autoWriteTroubleshootingMessage = nil
        autoWriteSuggestions = []
        defer { autoWriteIsLoading = false }

        let delaySeconds = Int.random(in: 2...4)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
            return
        }
        if Task.isCancelled { return }

        guard isSelectableDefaultCategoryForAutoWrite(categoryTitle) else {
            autoWriteSuggestions = []
            autoWriteErrorMessage = nil
            autoWriteTroubleshootingMessage = nil
            return
        }

        let candidates = identitySuggestionPool(for: categoryTitle)
        guard !candidates.isEmpty else {
            autoWriteErrorMessage = "No suggestions yet."
            autoWriteTroubleshootingMessage = nil
            return
        }

        var existingRoles = categoryRoles.map(\.role)
        let pending = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            existingRoles.append(pending)
        }
        let existingSet = Set(existingRoles.map(normalizedAutoWriteText).filter { !$0.isEmpty })
        let priorSuggestionSet = Set(previousSuggestions.map(normalizedAutoWriteText).filter { !$0.isEmpty })

        let filtered = candidates.filter { suggestion in
            let normalized = normalizedAutoWriteText(suggestion)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized) && !priorSuggestionSet.contains(normalized)
        }
        let nonExisting = candidates.filter { suggestion in
            let normalized = normalizedAutoWriteText(suggestion)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized)
        }

        let primaryPool: [String]
        if filtered.count >= 2 {
            primaryPool = filtered
        } else if nonExisting.count >= 2 {
            primaryPool = nonExisting
        } else {
            primaryPool = candidates
        }

        var picked: [String] = []
        var pickedSet = Set<String>()
        for candidate in primaryPool.shuffled() {
            let normalized = normalizedAutoWriteText(candidate)
            if normalized.isEmpty || pickedSet.contains(normalized) { continue }
            picked.append(candidate)
            pickedSet.insert(normalized)
            if picked.count == 2 { break }
        }
        if picked.count < 2 {
            for candidate in candidates.shuffled() {
                let normalized = normalizedAutoWriteText(candidate)
                if normalized.isEmpty || pickedSet.contains(normalized) { continue }
                picked.append(candidate)
                pickedSet.insert(normalized)
                if picked.count == 2 { break }
            }
        }

        let nextSuggestions = picked
            .map(clampedIdentitySuggestion)
            .filter { !$0.isEmpty }
            .prefix(2)

        guard nextSuggestions.count == 2 else {
            autoWriteErrorMessage = "No suggestions yet."
            autoWriteTroubleshootingMessage = nil
            return
        }

        autoWriteSuggestions = Array(nextSuggestions)
        autoWriteErrorMessage = nil
        autoWriteTroubleshootingMessage = nil
        for suggestion in nextSuggestions {
            let normalized = normalizedAutoWriteText(suggestion)
            let exists = autoWritePreviousSuggestions.contains { normalizedAutoWriteText($0) == normalized }
            if !exists {
                autoWritePreviousSuggestions.append(suggestion)
            }
        }
    }

    private func identitySuggestionPool(for category: String) -> [String] {
        let normalizedCategory = normalizedCategoryForAutoWrite(category)
        guard let values = fulfillmentStartIdentitySuggestionMap.first(where: {
            $0.key.caseInsensitiveCompare(normalizedCategory) == .orderedSame
        })?.value else {
            return []
        }

        return values
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .map { $0.replacingOccurrences(of: "fulfillment_area,identity", with: "") }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isSelectableDefaultCategoryForAutoWrite(_ category: String) -> Bool {
        let normalizedCategory = normalizedCategoryForAutoWrite(category)
        return fulfillmentStartSelectableDefaultCategories.contains {
            $0.caseInsensitiveCompare(normalizedCategory) == .orderedSame
        }
    }

    private func normalizedCategoryForAutoWrite(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "health & vitality":
            return "Health & Energy"
        case "wealth & lifestyle":
            return "Wealth & Finance"
        case "mind & meaning":
            return "Mindset & Resilience"
        case "leadership & impact":
            return "Service & Impact"
        default:
            return trimmed
        }
    }

    private func autoWriteRetryRow(
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
                    if hasTroubleshooting, let troubleshooting {
                        Button("Copy troubleshooting") {
                            loomAICopyTroubleshootingToClipboard(troubleshooting)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
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

    private func decodeIdentitySuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8),
           let parsed = try? JSONDecoder().decode(IdentityAutoWriteResponse.self, from: data) {
            let normalized = (parsed.suggestions ?? [])
                .compactMap { dto -> String? in
                    let rawValue = (dto.identity ?? dto.role ?? dto.text ?? "")
                        .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                        .trimmingCharacters(in: .whitespacesAndNewlines)
                    let suggestion = clampedIdentitySuggestion(rawValue)
                    return suggestion.isEmpty ? nil : suggestion
                }
            return Array(normalized.prefix(2))
        }

        let fallback = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .compactMap { line -> String? in
                let suggestion = clampedIdentitySuggestion(line)
                return suggestion.isEmpty ? nil : suggestion
            }
        return Array(fallback.prefix(2))
    }

    private func clampedIdentitySuggestion(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func normalizedAutoWriteText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionSecondaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return Color.white.opacity(0.86) }
        return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
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

private struct ResourcesManagerSheetView: View {
    private struct EditorTarget: Identifiable {
        let resourceID: UUID?
        let categoryID: UUID
        let categoryTitle: String
        let autoFocus: Bool

        var id: String {
            if let resourceID { return "edit-\(resourceID.uuidString)" }
            return "new-\(categoryID.uuidString)-\(autoFocus ? "focus" : "nofocus")"
        }
    }

    let categoryID: UUID
    let categoryTitle: String

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var resources: [FulfillmentResources]

    @State private var isDeleteMode = false
    @State private var selectedIDsForDelete: Set<UUID> = []
    @State private var editorTarget: EditorTarget?

    private var categoryResources: [FulfillmentResources] {
        resources.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    if !isDeleteMode {
                        Button {
                            editorTarget = .init(resourceID: nil, categoryID: categoryID, categoryTitle: categoryTitle, autoFocus: true)
                        } label: {
                            HStack {
                                Text("Add Resource")
                                    .foregroundStyle(Color.accentColor)
                                Spacer()
                            }
                            .frame(minHeight: 44, alignment: .center)
                            .padding(.horizontal, 14)
                        }
                        .buttonStyle(.plain)
                        .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
                    }

                    ForEach(categoryResources, id: \.id) { resource in
                        Button {
                            guard !isDeleteMode else {
                                toggleDeleteSelection(for: resource.id)
                                return
                            }
                            editorTarget = .init(resourceID: resource.id, categoryID: categoryID, categoryTitle: categoryTitle, autoFocus: false)
                        } label: {
                            HStack(spacing: 10) {
                                if isDeleteMode {
                                    Image(systemName: selectedIDsForDelete.contains(resource.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedIDsForDelete.contains(resource.id) ? .red : .secondary)
                                }
                                Text(resource.resource)
                                    .foregroundStyle(.primary)
                                    .lineLimit(nil)
                                    .fixedSize(horizontal: false, vertical: true)
                                Spacer()
                                if !isDeleteMode {
                                    Image(systemName: "chevron.right")
                                        .font(.caption2.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                        .buttonStyle(.plain)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("Manage Resources")
            .navigationBarTitleDisplayMode(.inline)
            .navigationBarBackButtonHidden(isDeleteMode)
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
                    } else if !categoryResources.isEmpty {
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
            ResourceEditorSheetView(
                categoryID: target.categoryID,
                categoryTitle: target.categoryTitle,
                resourceID: target.resourceID,
                autoFocusTextField: target.autoFocus
            )
        }
    }

    private func toggleDeleteSelection(for id: UUID) {
        if selectedIDsForDelete.contains(id) {
            selectedIDsForDelete.remove(id)
        } else {
            selectedIDsForDelete.insert(id)
        }
    }

    private func deleteSelected() {
        let targets = categoryResources.filter { selectedIDsForDelete.contains($0.id) }
        guard !targets.isEmpty else { return }
        for resource in targets {
            modelContext.insert(
                FulfillmentResourcesArchive(
                    category_id: resource.category_id,
                    updatedAt: resource.updatedAt,
                    resource: resource.resource,
                    rank: resource.rank,
                    archivedAt: Date()
                )
            )
            RecentlyDeletedStore.trash(resource, in: modelContext)
        }
        try? modelContext.save()
        selectedIDsForDelete.removeAll()
        isDeleteMode = false
    }
}

private struct ResourceEditorSheetView: View {
    let categoryID: UUID
    let categoryTitle: String
    let resourceID: UUID?
    let autoFocusTextField: Bool

    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @Query private var resources: [FulfillmentResources]

    @State private var draftText = ""
    @State private var didHydrate = false
    @FocusState private var isTextFocused: Bool

    private var categoryResources: [FulfillmentResources] {
        resources.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private var editingResource: FulfillmentResources? {
        guard let resourceID else { return nil }
        return resources.first { $0.id == resourceID }
    }

    private var isEditing: Bool { resourceID != nil }
    private var doneDisabled: Bool { draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }

    var body: some View {
        NavigationStack {
            List {
                Section(isEditing ? "Edit Resource" : "Add Resource") {
                    TextField("great gym nearby", text: $draftText)
                        .focused($isTextFocused)
                        .textInputAutocapitalization(.sentences)
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "Edit Resource" : "Add Resource")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") { saveAndDismiss() }
                        .disabled(doneDisabled)
                }
            }
        }
        .presentationDetents([.height(220), .medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            hydrateIfNeeded()
            guard autoFocusTextField else { return }
            DispatchQueue.main.async { isTextFocused = true }
        }
    }

    private func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        if let editingResource {
            draftText = editingResource.resource
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        if let editingResource {
            guard editingResource.resource != trimmed else {
                dismiss()
                return
            }
            modelContext.insert(
                FulfillmentResourcesArchive(
                    category_id: editingResource.category_id,
                    updatedAt: editingResource.updatedAt,
                    resource: editingResource.resource,
                    rank: editingResource.rank,
                    archivedAt: Date()
                )
            )
            editingResource.resource = trimmed
            editingResource.updatedAt = Date()
        } else {
            let nextRank = (categoryResources.map(\.rank).max() ?? 0) + 1
            let resource = FulfillmentResources(category_id: categoryID, resource: trimmed, rank: nextRank)
            modelContext.insert(resource)
        }

        try? modelContext.save()
        dismiss()
    }
}

struct LittleWinEditorSheetView: View {
    private struct IntegrationSetupTarget: Identifiable {
        let source: LittleWinsIntegrationConfig.Source
        var id: String { source.rawValue }
    }

    let categoryID: UUID
    let categoryTitle: String
    let focusID: UUID?
    let autoFocusTextField: Bool
    var persistsChanges: Bool = true

    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @Environment(\.modelContext) private var modelContext
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    @Query private var roles: [FulfillmentRoles]
    @Query private var fulfillments: [Fulfillment]
    @Query private var foci: [FulfillmentFocus]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]

    @State private var draftText = ""
    @State private var draftCanAnyDay = true
    @State private var draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
    @State private var draftIntegrate = false
    @State private var draftIntegrationConfig: LittleWinsIntegrationConfig? = nil
    @State private var integrationSetupTarget: IntegrationSetupTarget?
    @State private var didHydrate = false
    @State private var isShowingIntegrationDetails = false
    @State private var isShowingLittleWinPassionsSheet = false
    @State private var selectedLittleWinPassionIDs = Set<UUID>()
    @State private var autoWriteSuggestions: [String] = []
    @State private var autoWritePreviousSuggestions: [String] = []
    @State private var autoWriteAppliedSuggestion: String?
    @State private var autoWriteErrorMessage: String? = nil
    @State private var autoWriteTroubleshootingMessage: String? = nil
    @State private var autoWriteIsLoading = false
    @State private var autoWriteOutlineAngle: Double = 0
    @State private var autoWriteIconAnimating = false
    @State private var autoWriteIconAnimationTask: Task<Void, Never>?
    @State private var keyboardHeight: CGFloat = 0
    @FocusState private var isTextFocused: Bool

    private struct LittleWinAutoWriteSuggestionDTO: Decodable {
        let activity: String?
        let littleWin: String?
        let text: String?
    }

    private struct LittleWinAutoWriteResponse: Decodable {
        let suggestions: [LittleWinAutoWriteSuggestionDTO]?
    }

    private let weekdayLetterLabels = ["S", "M", "T", "W", "T", "F", "S"]

    private var littleWins: [FulfillmentFocus] {
        foci.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private var editingFocus: FulfillmentFocus? {
        guard let focusID else { return nil }
        return foci.first { $0.id == focusID }
    }

    private var categoryRoles: [FulfillmentRoles] {
        roles.filter { $0.category_id == categoryID }
            .sorted { $0.rank < $1.rank }
    }

    private var categoryRecord: Fulfillment? {
        fulfillments.first { $0.category_id == categoryID }
    }

    private var isEditing: Bool { focusID != nil }
    private var showsAutoWrite: Bool { !isEditing && littleWins.count < 3 }
    private let autoWriteFloatingGap: CGFloat = 12

    private var doneDisabled: Bool {
        draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    private var keyboardAccessoryShowsCheckmark: Bool {
        !draftText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
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

    private func autoWriteBottomPadding(in proxy: GeometryProxy) -> CGFloat {
        guard keyboardHeight > 0 else { return 18 }
        let keyboardTopGlobal = UIScreen.main.bounds.height - keyboardHeight
        let viewBottomGlobal = proxy.frame(in: .global).maxY
        let keyboardOverlapInView = max(0, viewBottomGlobal - keyboardTopGlobal)
        return keyboardOverlapInView + autoWriteFloatingGap
    }

    private var floatingAutoWriteButton: some View {
        Button {
            guard !autoWriteIsLoading else { return }
            Task { await requestAutoWriteSuggestions() }
        } label: {
            HStack(spacing: 6) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 27, height: 27)
                    .rotation3DEffect(
                        .degrees(autoWriteIsLoading && autoWriteIconAnimating ? 180 : 0),
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
        .disabled(autoWriteIsLoading)
        .opacity(autoWriteIsLoading ? 0.7 : 1)
        .onAppear {
            guard autoWriteOutlineAngle == 0 else { return }
            withAnimation(.linear(duration: 8).repeatForever(autoreverses: false)) {
                autoWriteOutlineAngle = 360
            }
        }
    }

    private var keyboardAutoWriteButton: some View {
        Button {
            guard !autoWriteIsLoading else { return }
            Task { await requestAutoWriteSuggestions() }
        } label: {
            HStack(spacing: 5) {
                Image("LoomAI")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 16, height: 16)
                    .rotation3DEffect(
                        .degrees(autoWriteIsLoading && autoWriteIconAnimating ? 180 : 0),
                        axis: (x: 1, y: 0, z: 0)
                    )
                Text("AutoWrite")
                    .font(.subheadline.weight(.semibold))
            }
            .foregroundStyle(autoWriteGradient)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule()
                    .fill(Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule()
                    .stroke(autoWriteGradient, lineWidth: 1.8)
            )
        }
        .buttonStyle(.plain)
        .disabled(autoWriteIsLoading)
        .opacity(autoWriteIsLoading ? 0.7 : 1)
    }

    var body: some View {
        NavigationStack {
            List {
                Section(isEditing ? "Edit Little Win" : "New Little Win") {
                    TextField("yoga classes", text: $draftText)
                        .focused($isTextFocused)
                        .textInputAutocapitalization(.sentences)

                    if showsAutoWrite {
                        if !autoWriteSuggestions.isEmpty {
                            VStack(alignment: .leading, spacing: 8) {
                                ForEach(autoWriteSuggestions, id: \.self) { suggestion in
                                    let normalized = normalizedAutoWriteText(suggestion)
                                    let isApplied = autoWriteAppliedSuggestion == normalized
                                    Button {
                                        draftText = suggestion
                                        autoWriteAppliedSuggestion = normalized
                                        isTextFocused = false
                                    } label: {
                                        HStack(alignment: .top, spacing: 10) {
                                            Image("LoomAI")
                                                .resizable()
                                                .renderingMode(.template)
                                                .scaledToFit()
                                                .frame(width: 16, height: 16)
                                                .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.92 : 0.95))
                                                .padding(.top, 1)

                                            VStack(alignment: .leading, spacing: 3) {
                                                Text(isApplied ? "Added Little Win in \(categoryTitle):" : "Add Little Win in \(categoryTitle):")
                                                    .font(.subheadline.italic())
                                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied).opacity(isApplied ? 0.88 : 0.95))
                                                    .multilineTextAlignment(.leading)
                                                Text(suggestion)
                                                    .font(.subheadline.weight(.bold))
                                                    .foregroundStyle(autoWriteSuggestionPrimaryColor(isApplied: isApplied))
                                                    .multilineTextAlignment(.leading)
                                                    .lineLimit(nil)
                                                    .fixedSize(horizontal: false, vertical: true)
                                                if isApplied {
                                                    Text("Tap field to edit")
                                                        .font(.caption)
                                                        .foregroundStyle(autoWriteSuggestionSecondaryColor(isApplied: isApplied))
                                                }
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
                        if let errorMessage = autoWriteErrorMessage {
                            autoWriteRetryRow(
                                message: errorMessage,
                                troubleshooting: autoWriteTroubleshootingMessage
                            ) {
                                Task { await requestAutoWriteSuggestions() }
                            }
                        }
                    }

                    HStack {
                        Text("Can be completed any day")
                        Spacer()
                        Menu {
                            Button("Yes") { setCanAnyDay(true) }
                            Button("No") { setCanAnyDay(false) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(draftCanAnyDay ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if !draftCanAnyDay {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack(spacing: 0) {
                                ForEach(Array(weekdayLetterLabels.enumerated()), id: \.offset) { index, label in
                                    let isSelected = (draftWeekdayMask & (1 << index)) != 0
                                    Button {
                                        toggleWeekday(index)
                                    } label: {
                                        Text(label)
                                            .font(.caption.weight(.semibold))
                                            .foregroundStyle(isSelected ? .white : .primary)
                                            .frame(width: 34, height: 34)
                                            .background(
                                                Circle()
                                                    .fill(isSelected ? Color.accentColor : Color(.systemGray6))
                                            )
                                            .overlay(
                                                Circle()
                                                    .stroke(Color(.separator).opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                                            )
                                            .frame(maxWidth: .infinity)
                                    }
                                    .buttonStyle(.plain)
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .padding(.vertical, 2)
                    }

                    HStack {
                        Text("Integrate")
                        Spacer()
                        Menu {
                            Button("No") { setIntegrate(false) }
                            Button("Yes") { setIntegrate(true) }
                        } label: {
                            HStack(spacing: 4) {
                                Text(draftIntegrate ? "Yes" : "No")
                                Image(systemName: "chevron.up.chevron.down")
                            }
                            .foregroundStyle(.blue)
                        }
                    }

                    if draftIntegrate {
                        VStack(spacing: 8) {
                            littleWinIntegrationSourceRow(
                                title: "Apple Health",
                                icon: "heart",
                                selected: draftIntegrationConfig?.source == .appleHealth,
                                connected: (draftIntegrationConfig?.source == .appleHealth) && (draftIntegrationConfig?.isConnected == true),
                                enabled: true
                            ) {
                                if draftIntegrationConfig?.source != .appleHealth {
                                    draftIntegrationConfig = LittleWinsIntegrationConfig.default(for: .appleHealth)
                                }
                                integrationSetupTarget = .init(source: .appleHealth)
                            }
                        }
                        .padding(.vertical, 2)
                    }

                }

                Section("Passions") {
                    HStack(alignment: .firstTextBaseline) {
                        Text("Select related passions")
                        Spacer(minLength: 8)
                        Button("Connect Passions") {
                            isShowingLittleWinPassionsSheet = true
                        }
                        .foregroundStyle(.blue)
                    }
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle(isEditing ? "Edit Little Win" : "Add Little Win")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        saveAndDismiss()
                    }
                    .disabled(doneDisabled)
                }
                ToolbarItemGroup(placement: .keyboard) {
                    if isTextFocused {
                        if showsAutoWrite {
                            keyboardAutoWriteButton
                        }
                        Spacer(minLength: 0)
                        Button {
                            if keyboardAccessoryShowsCheckmark {
                                saveAndDismiss()
                            } else {
                                isTextFocused = false
                            }
                        } label: {
                            Image(systemName: keyboardAccessoryShowsCheckmark ? "checkmark" : "keyboard.chevron.compact.down")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(keyboardAccessoryShowsCheckmark ? .white : .primary.opacity(0.85))
                                .frame(width: 30, height: 30)
                                .background(
                                    Circle().fill(
                                        keyboardAccessoryShowsCheckmark
                                            ? Color.blue
                                            : Color(.secondarySystemBackground)
                                    )
                                )
                                .overlay(
                                    Circle()
                                        .stroke(
                                            Color.black.opacity(keyboardAccessoryShowsCheckmark ? 0 : 0.08),
                                            lineWidth: 1
                                        )
                                )
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .overlay {
            GeometryReader { proxy in
                if showsAutoWrite && !isTextFocused {
                    HStack(spacing: 8) {
                        floatingAutoWriteButton
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
                    .padding(.trailing, 16)
                    .padding(.bottom, autoWriteBottomPadding(in: proxy))
                }
            }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .onAppear {
            hydrateIfNeeded()
            guard autoFocusTextField else { return }
            DispatchQueue.main.async {
                isTextFocused = true
            }
        }
        .onChange(of: draftText) { _, newValue in
            guard let applied = autoWriteAppliedSuggestion else { return }
            if normalizedAutoWriteText(newValue) != applied {
                autoWriteAppliedSuggestion = nil
            }
        }
        .onChange(of: autoWriteIsLoading, initial: false) { _, isLoading in
            setAutoWriteLoadingAnimation(isLoading)
        }
        .onDisappear {
            setAutoWriteLoadingAnimation(false)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillChangeFrameNotification)) { note in
            guard let frame = note.userInfo?[UIResponder.keyboardFrameEndUserInfoKey] as? CGRect else { return }
            let screenHeight = UIScreen.main.bounds.height
            keyboardHeight = max(0, screenHeight - frame.minY)
        }
        .onReceive(NotificationCenter.default.publisher(for: UIResponder.keyboardWillHideNotification)) { _ in
            keyboardHeight = 0
        }
        .sheet(item: $integrationSetupTarget) { target in
            LittleWinIntegrationSetupSheet(
                source: target.source,
                config: Binding(
                    get: { draftIntegrationConfig ?? .default(for: target.source) },
                    set: { draftIntegrationConfig = $0 }
                )
            )
        }
        .sheet(isPresented: $isShowingLittleWinPassionsSheet) {
            NavigationStack {
                List {
                    ForEach(passions, id: \.passion_id) { passion in
                        Button {
                            if selectedLittleWinPassionIDs.contains(passion.passion_id) {
                                selectedLittleWinPassionIDs.remove(passion.passion_id)
                            } else {
                                selectedLittleWinPassionIDs.insert(passion.passion_id)
                            }
                        } label: {
                            HStack {
                                Text("\(displayEmotionLabelForLittleWinEditor(passion.emotion)): \(passion.passion)")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if selectedLittleWinPassionIDs.contains(passion.passion_id) {
                                    Image(systemName: "checkmark")
                                        .foregroundStyle(.blue)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .navigationTitle("Connect Passions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .navigationBarTrailing) {
                        Button("Done") { isShowingLittleWinPassionsSheet = false }
                    }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }

    private func hydrateIfNeeded() {
        guard !didHydrate else { return }
        didHydrate = true
        if let focus = editingFocus {
            let rule = LittleWinsScheduleStore.rule(for: focus.id)
            draftText = focus.activity
            draftCanAnyDay = rule.canCompleteAnyDay
            draftWeekdayMask = rule.activeWeekdayMask
            if let integration = LittleWinsIntegrationStore.config(for: focus.id) {
                draftIntegrate = integration.isEnabled
                draftIntegrationConfig = integration
            } else {
                draftIntegrate = false
                draftIntegrationConfig = nil
            }
            selectedLittleWinPassionIDs = LittleWinsPassionsStore.passionIDs(for: focus.id)
        } else {
            draftText = ""
            draftCanAnyDay = true
            draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
            draftIntegrate = false
            draftIntegrationConfig = nil
            selectedLittleWinPassionIDs = []
        }
    }

    private func setIntegrate(_ value: Bool) {
        draftIntegrate = value
        if value {
            if draftIntegrationConfig == nil {
                draftIntegrationConfig = .default(for: .appleHealth)
            }
        } else {
            draftIntegrationConfig = nil
        }
    }

    private func setCanAnyDay(_ value: Bool) {
        draftCanAnyDay = value
        if value {
            draftWeekdayMask = LittleWinsScheduleRule.everyDayMask
        } else {
            draftWeekdayMask = 0
        }
    }

    private func toggleWeekday(_ index: Int) {
        let bit = 1 << index
        if (draftWeekdayMask & bit) != 0 {
            draftWeekdayMask &= ~bit
        } else {
            draftWeekdayMask |= bit
        }
    }

    private func saveAndDismiss() {
        let trimmed = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        var finalCanAnyDay = draftCanAnyDay
        var finalMask = draftWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if !finalCanAnyDay && finalMask == 0 {
            finalCanAnyDay = true
            finalMask = LittleWinsScheduleRule.everyDayMask
        }
        if !finalCanAnyDay && finalMask == LittleWinsScheduleRule.everyDayMask {
            finalCanAnyDay = true
        }

        let rule = LittleWinsScheduleRule(canCompleteAnyDay: finalCanAnyDay, activeWeekdayMask: finalMask).normalized
        let finalIntegrationConfig = (draftIntegrate ? draftIntegrationConfig : nil).flatMap { config in
            config.isConnected ? config : nil
        }

        if let focus = editingFocus {
            if focus.activity != trimmed {
                modelContext.insert(
                    FulfillmentFocusArchive(
                        category_id: focus.category_id,
                        updatedAt: focus.updatedAt,
                        activity: focus.activity,
                        rank: focus.rank,
                        archivedAt: Date()
                    )
                )
                focus.activity = trimmed
                focus.updatedAt = Date()
            }
            LittleWinsScheduleStore.setRule(rule, for: focus.id)
            LittleWinsIntegrationStore.setConfig(finalIntegrationConfig, for: focus.id)
            LittleWinsPassionsStore.setPassionIDs(selectedLittleWinPassionIDs, for: focus.id)
        } else {
            guard littleWins.count < 3 else { return }
            let nextRank = (littleWins.map(\.rank).max() ?? 0) + 1
            let focus = FulfillmentFocus(category_id: categoryID, activity: trimmed, rank: nextRank)
            modelContext.insert(focus)
            LittleWinsScheduleStore.setRule(rule, for: focus.id)
            LittleWinsIntegrationStore.setConfig(finalIntegrationConfig, for: focus.id)
            LittleWinsPassionsStore.setPassionIDs(selectedLittleWinPassionIDs, for: focus.id)
        }

        if persistsChanges {
            try? modelContext.save()
        }
        if finalIntegrationConfig == nil, draftIntegrate {
            draftIntegrate = false
            draftIntegrationConfig = nil
        }
        dismiss()
    }

    private func requestAutoWriteSuggestions() async {
        guard !autoWriteIsLoading else { return }
        autoWriteIsLoading = true
        let previousSuggestions = autoWritePreviousSuggestions
        autoWriteErrorMessage = nil
        autoWriteTroubleshootingMessage = nil
        autoWriteSuggestions = []
        defer { autoWriteIsLoading = false }

        let delaySeconds = Int.random(in: 2...4)
        do {
            try await Task.sleep(nanoseconds: UInt64(delaySeconds) * 1_000_000_000)
        } catch {
            return
        }
        if Task.isCancelled { return }

        guard isSelectableDefaultCategoryForAutoWrite(categoryTitle) else {
            autoWriteSuggestions = []
            autoWriteErrorMessage = nil
            autoWriteTroubleshootingMessage = nil
            return
        }

        let candidates = littleWinSuggestionPool(for: categoryTitle)
        guard !candidates.isEmpty else {
            autoWriteErrorMessage = "No suggestions yet."
            autoWriteTroubleshootingMessage = nil
            return
        }

        var littleWinsNow = littleWins.map(\.activity)
        let pending = draftText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !pending.isEmpty {
            littleWinsNow.append(pending)
        }
        let existingSet = Set(littleWinsNow.map(normalizedAutoWriteText).filter { !$0.isEmpty })
        let priorSuggestionSet = Set(previousSuggestions.map(normalizedAutoWriteText).filter { !$0.isEmpty })

        let filtered = candidates.filter { suggestion in
            let normalized = normalizedAutoWriteText(suggestion)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized) && !priorSuggestionSet.contains(normalized)
        }
        let nonExisting = candidates.filter { suggestion in
            let normalized = normalizedAutoWriteText(suggestion)
            if normalized.isEmpty { return false }
            return !existingSet.contains(normalized)
        }

        let primaryPool: [String]
        if filtered.count >= 2 {
            primaryPool = filtered
        } else if nonExisting.count >= 2 {
            primaryPool = nonExisting
        } else {
            primaryPool = candidates
        }

        var picked: [String] = []
        var pickedSet = Set<String>()
        for candidate in primaryPool.shuffled() {
            let normalized = normalizedAutoWriteText(candidate)
            if normalized.isEmpty || pickedSet.contains(normalized) { continue }
            picked.append(candidate)
            pickedSet.insert(normalized)
            if picked.count == 2 { break }
        }
        if picked.count < 2 {
            for candidate in candidates.shuffled() {
                let normalized = normalizedAutoWriteText(candidate)
                if normalized.isEmpty || pickedSet.contains(normalized) { continue }
                picked.append(candidate)
                pickedSet.insert(normalized)
                if picked.count == 2 { break }
            }
        }

        var nextSuggestions = picked
            .map(clampedLittleWinSuggestion)
            .filter { !$0.isEmpty }
            .filter { !isLittleWinSuggestionTooSimilarToExisting($0, existing: littleWinsNow) }
        nextSuggestions = Array(nextSuggestions.prefix(2))

        guard nextSuggestions.count == 2 else {
            autoWriteErrorMessage = "No new suggestions yet."
            autoWriteTroubleshootingMessage = nil
            return
        }

        autoWriteSuggestions = nextSuggestions
        autoWriteErrorMessage = nil
        autoWriteTroubleshootingMessage = nil
        for suggestion in nextSuggestions {
            let normalized = normalizedAutoWriteText(suggestion)
            let exists = autoWritePreviousSuggestions.contains { normalizedAutoWriteText($0) == normalized }
            if !exists {
                autoWritePreviousSuggestions.append(suggestion)
            }
        }
    }

    private func littleWinSuggestionPool(for category: String) -> [String] {
        let normalizedCategory = normalizedCategoryForAutoWrite(category)
        if isHealthEnergyCategoryForAutoWrite(normalizedCategory) {
            return fulfillmentStartHealthEnergyLittleWinFlags
                .map(\.activity)
                .map { $0.replacingOccurrences(of: "\"", with: "") }
                .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
                .filter { !$0.isEmpty }
        }

        guard let corpus = fulfillmentStartLittleWinCorpusByCategory.first(where: {
            $0.key.caseInsensitiveCompare(normalizedCategory) == .orderedSame
        })?.value else {
            return []
        }

        return corpus
            .components(separatedBy: .newlines)
            .map { $0.replacingOccurrences(of: "\"", with: "") }
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression) }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private func isSelectableDefaultCategoryForAutoWrite(_ category: String) -> Bool {
        let normalizedCategory = normalizedCategoryForAutoWrite(category)
        return fulfillmentStartSelectableDefaultCategories.contains {
            $0.caseInsensitiveCompare(normalizedCategory) == .orderedSame
        }
    }

    private func isHealthEnergyCategoryForAutoWrite(_ category: String) -> Bool {
        category.caseInsensitiveCompare("Health & Energy") == .orderedSame
    }

    private func normalizedCategoryForAutoWrite(_ category: String) -> String {
        let trimmed = category.trimmingCharacters(in: .whitespacesAndNewlines)
        switch trimmed.lowercased() {
        case "health & vitality":
            return "Health & Energy"
        case "wealth & lifestyle":
            return "Wealth & Finance"
        case "mind & meaning":
            return "Mindset & Resilience"
        case "leadership & impact":
            return "Service & Impact"
        default:
            return trimmed
        }
    }

    private func autoWriteRetryRow(
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
                    if hasTroubleshooting, let troubleshooting {
                        Button("Copy troubleshooting") {
                            loomAICopyTroubleshootingToClipboard(troubleshooting)
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                    }
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

    private func decodeLittleWinSuggestions(from raw: String) -> [String] {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        if let data = trimmed.data(using: .utf8) {
            if let parsed = try? JSONDecoder().decode(LittleWinAutoWriteResponse.self, from: data) {
                let normalized = (parsed.suggestions ?? [])
                    .compactMap { dto -> String? in
                        let rawValue = (dto.activity ?? dto.littleWin ?? dto.text ?? "")
                            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                            .trimmingCharacters(in: .whitespacesAndNewlines)
                        let suggestion = clampedLittleWinSuggestion(rawValue)
                        return suggestion.isEmpty ? nil : suggestion
                    }
                return Array(normalized.prefix(2))
            }
            if let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let suggestionsMap = root["suggestions"] as? [String: Any] {
                let mapped = suggestionsMap.values
                    .map { clampedLittleWinSuggestion(String(describing: $0)) }
                    .filter { !$0.isEmpty }
                if !mapped.isEmpty {
                    return Array(mapped.prefix(2))
                }
            }
        }

        let fallback = trimmed
            .components(separatedBy: "\n")
            .map { $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression).trimmingCharacters(in: .whitespacesAndNewlines) }
            .map { $0.replacingOccurrences(of: #"^\d+[\.\)]\s*"#, with: "", options: .regularExpression) }
            .map { $0.replacingOccurrences(of: #"^[-•]\s*"#, with: "", options: .regularExpression) }
            .compactMap { line -> String? in
                let suggestion = clampedLittleWinSuggestion(line)
                return suggestion.isEmpty ? nil : suggestion
            }
        return Array(fallback.prefix(2))
    }

    private func clampedLittleWinSuggestion(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isLittleWinSuggestionTooSimilarToExisting(_ candidate: String, existing: [String]) -> Bool {
        let candidateNorm = normalizedAutoWriteText(candidate)
        guard !candidateNorm.isEmpty else { return false }
        let candidateTokens = Set(candidateNorm.split(separator: " ").map(String.init))
        for item in existing {
            let itemNorm = normalizedAutoWriteText(item)
            if itemNorm.isEmpty { continue }
            if itemNorm == candidateNorm { return true }
            if candidateNorm.contains(itemNorm) || itemNorm.contains(candidateNorm) { return true }
            let itemTokens = Set(itemNorm.split(separator: " ").map(String.init))
            if !itemTokens.isEmpty {
                let overlap = candidateTokens.intersection(itemTokens).count
                let ratio = Double(overlap) / Double(max(1, min(candidateTokens.count, itemTokens.count)))
                if ratio >= 0.6 { return true }
            }
        }
        return false
    }

    private func normalizedAutoWriteText(_ text: String) -> String {
        text
            .folding(options: [.diacriticInsensitive, .caseInsensitive], locale: .current)
            .lowercased()
            .replacingOccurrences(of: #"[^\p{L}\p{N}\s]"#, with: " ", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func autoWriteSuggestionPrimaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return .white }
        return colorScheme == .dark ? Color.white.opacity(0.92) : Color.black.opacity(0.82)
    }

    private func autoWriteSuggestionSecondaryColor(isApplied: Bool) -> Color {
        guard isApplied else { return Color.white.opacity(0.86) }
        return colorScheme == .dark ? Color.white.opacity(0.74) : Color.black.opacity(0.62)
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

    private func displayEmotionLabelForLittleWinEditor(_ emotion: String) -> String {
        switch emotion.lowercased() {
        case "love":
            return "Love"
        case "vows", "vow":
            return "Vows"
        case "thrill":
            return "Thrill"
        case "just", "hate":
            return "Hate"
        default:
            return emotion.capitalized
        }
    }

    private func littleWinIntegrationSourceRow(
        title: String,
        icon: String,
        selected: Bool,
        connected: Bool,
        enabled: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(enabled ? .primary : .secondary)
                    .frame(width: 24, height: 24)
                    .overlay(
                        RoundedRectangle(cornerRadius: 7)
                            .stroke((enabled ? Color.primary : Color.secondary).opacity(0.9), lineWidth: 1)
                    )
                Text(title)
                    .foregroundStyle(enabled ? .primary : .secondary)
                Spacer()
                if selected && connected {
                    Image(systemName: "checkmark")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.blue)
                } else {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }
            .padding(8)
            .padding(.vertical, 2)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
    }
}

private struct LittleWinIntegrationSetupSheet: View {
    let source: LittleWinsIntegrationConfig.Source
    @Binding var config: LittleWinsIntegrationConfig
    @Environment(\.dismiss) private var dismiss
    @State private var isConnecting = false
    @State private var isRefreshingHealthProgress = false
    @State private var healthStatusMessage: String? = nil
    @State private var isShowingScreenTimePicker = false
    @State private var selectedMetric: LittleWinsIntegrationConfig.Metric? = nil
    @State private var selectedTargetValue: Double? = nil
    @State private var showAppleHealthAccessAlert = false
    @State private var appleHealthAccessAlertBody = ""
#if canImport(FamilyControls)
    @State private var screenTimeSelection = FamilyActivitySelection()
#endif

    private var metricOptions: [LittleWinsIntegrationConfig.Metric] {
        LittleWinsIntegrationConfig.Metric.options(for: source)
    }

    private var usesAppleHealth: Bool {
        source == .appleHealth
    }

    private var connectButtonTitle: String {
        if config.isConnected {
            return "Disconnect \(source.title)"
        }
        return "Connect \(source.title)"
    }

    private var lastSyncText: String? {
        guard config.isConnected, config.updatedAtUnix > 0 else { return nil }
        let date = Date(timeIntervalSince1970: config.updatedAtUnix)
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return "Last sync \(formatter.string(from: date))"
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("\(source.title) Integration")
                            .font(.headline)
                        Text("Connect and configure an automatic completion goal for this Little Win.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                }

                Section("Connect") {
                    Button(connectButtonTitle) {
                        connectSource()
                    }
                    .foregroundStyle(config.isConnected ? Color.red : Color.accentColor)
                    .disabled(isConnecting || isRefreshingHealthProgress)
                    if usesAppleHealth, config.isConnected {
                        HStack(spacing: 10) {
                            Button(isRefreshingHealthProgress ? "Syncing..." : "Sync") {
                                refreshAppleHealthProgress()
                            }
                            .disabled(isConnecting || isRefreshingHealthProgress)

                            Spacer(minLength: 8)

                            if let lastSyncText {
                                Text(lastSyncText)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)
                            }
                        }
                    }
                    if source == .screenTime, config.isConnected {
                        Button("Select Apps & Categories") {
                            openScreenTimePicker()
                        }
                        if let summary = config.screenTimeSelectionSummary, !summary.isEmpty {
                            Text(summary)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    if let healthStatusMessage, !healthStatusMessage.isEmpty {
                        Text(healthStatusMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if !usesAppleHealth || config.isConnected {
                    Section("Automation Goal") {
                        if usesAppleHealth {
                        HStack {
                            Text("Metric")
                            Spacer()
                            Picker(
                                "Metric",
                                selection: Binding(
                                    get: { selectedMetric },
                                    set: { newMetric in
                                        selectedMetric = newMetric
                                        if let metric = newMetric {
                                            config.metric = metric
                                            if usesAppleHealth, config.isConnected {
                                                refreshAppleHealthProgress()
                                            }
                                        }
                                        selectedTargetValue = nil
                                    }
                                )
                            ) {
                                Text("Select...").tag(Optional<LittleWinsIntegrationConfig.Metric>.none)
                                ForEach(metricOptions, id: \.rawValue) { metric in
                                    Text(metric.title).tag(Optional(metric))
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.blue)
                        }

                        if let metric = selectedMetric {
                            HStack {
                                Text("Target")
                                Spacer()
                                Picker(
                                    "Target",
                                    selection: Binding(
                                        get: { selectedTargetValue },
                                        set: { newTarget in
                                            selectedTargetValue = newTarget
                                            if let value = newTarget {
                                                config.targetValue = value
                                            }
                                        }
                                    )
                                ) {
                                    Text("Select...").tag(Optional<Double>.none)
                                    ForEach(targetOptions(for: metric), id: \.self) { value in
                                        Text(targetOptionLabel(value, metric: metric)).tag(Optional(value))
                                    }
                                }
                                .labelsHidden()
                                .pickerStyle(.menu)
                                .tint(.blue)
                            }

                            if config.isConnected {
                                HStack {
                                    Text("Current Progress")
                                    Spacer()
                                    TextField("", value: $config.progressValue, format: .number.precision(.fractionLength(metric == .sleepHours ? 1 : 0)))
                                        .keyboardType(.decimalPad)
                                        .multilineTextAlignment(.trailing)
                                        .frame(width: 90)
                                        .disabled(true)
                                    Text(metric.unitLabel)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        } else {
                        HStack {
                            Text("Metric")
                            Spacer()
                            Picker(
                                "Metric",
                                selection: Binding(
                                    get: { config.metric },
                                    set: { metric in
                                        config.metric = metric
                                        config.targetValue = metric.defaultTarget
                                    }
                                )
                            ) {
                                ForEach(metricOptions, id: \.rawValue) { metric in
                                    Text(metric.title).tag(metric)
                                }
                            }
                            .labelsHidden()
                            .pickerStyle(.menu)
                            .tint(.blue)
                        }

                        HStack {
                            Text("Target")
                            Spacer()
                            TextField("", value: $config.targetValue, format: .number.precision(.fractionLength(config.metric == .sleepHours ? 1 : 0)))
                                .keyboardType(.decimalPad)
                                .multilineTextAlignment(.trailing)
                                .frame(width: 90)
                            Text(config.metric.unitLabel)
                                .foregroundStyle(.secondary)
                        }

                        if config.isConnected {
                            HStack {
                                Text("Current Progress")
                                Spacer()
                                TextField("", value: $config.progressValue, format: .number.precision(.fractionLength(config.metric == .sleepHours ? 1 : 0)))
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .frame(width: 90)
                                    .disabled(usesAppleHealth)
                                Text(config.metric.unitLabel)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        }
                    }
                }
            }
            .navigationTitle(source.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        config.source = source
                        config.isEnabled = true
                        config.updatedAtUnix = Date().timeIntervalSince1970
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
        .alert("Apple Health Access Needed", isPresented: $showAppleHealthAccessAlert) {
            Button("Open Settings") { openAppSettings() }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text(appleHealthAccessAlertBody)
        }
        .onAppear {
            if usesAppleHealth {
                selectedMetric = nil
                selectedTargetValue = nil
            }
        }
#if canImport(FamilyControls)
        .sheet(isPresented: $isShowingScreenTimePicker) {
            NavigationStack {
                FamilyActivityPicker(selection: $screenTimeSelection)
                    .navigationTitle("Select Apps")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .navigationBarLeading) {
                            Button("Cancel") { isShowingScreenTimePicker = false }
                        }
                        ToolbarItem(placement: .navigationBarTrailing) {
                            Button("Done") {
                                config.screenTimeSelectionSummary = LittleWinsScreenTimeBridge.selectionSummary(for: screenTimeSelection)
                                config.updatedAtUnix = Date().timeIntervalSince1970
                                isShowingScreenTimePicker = false
                            }
                        }
                    }
            }
            .presentationDetents([.large])
        }
#endif
    }

    private func targetOptions(for metric: LittleWinsIntegrationConfig.Metric) -> [Double] {
        switch metric {
        case .steps:
            return [3_000, 5_000, 7_500, 10_000, 12_500, 15_000]
        case .workoutMinutes:
            return [10, 20, 30, 45, 60, 90]
        case .sleepHours:
            return [5.0, 6.0, 6.5, 7.0, 7.5, 8.0, 9.0]
        case .socialMediaMinutes:
            return [15, 30, 45, 60, 90, 120]
        case .totalScreenTimeMinutes:
            return [30, 60, 90, 120, 180, 240]
        }
    }

    private func targetOptionLabel(_ value: Double, metric: LittleWinsIntegrationConfig.Metric) -> String {
        if metric == .sleepHours {
            if value == floor(value) {
                return "\(Int(value)) \(metric.unitLabel)"
            }
            return String(format: "%.1f %@", value, metric.unitLabel)
        }
        return "\(Int(value)) \(metric.unitLabel)"
    }

    private func connectSource() {
        if config.isConnected {
            config.isConnected = false
            healthStatusMessage = nil
            return
        }
        if source == .screenTime {
            connectScreenTime()
            return
        }
        connectAppleHealth()
    }

    private func connectScreenTime() {
        isConnecting = true
        healthStatusMessage = nil
        LittleWinsScreenTimeBridge.requestAuthorization { result in
            DispatchQueue.main.async {
                isConnecting = false
                switch result {
                case .success:
                    config.isConnected = true
                    config.updatedAtUnix = Date().timeIntervalSince1970
                    healthStatusMessage = nil
                case .failure(let error):
                    config.isConnected = false
                    healthStatusMessage = error.localizedDescription
                }
            }
        }
    }

    private func openScreenTimePicker() {
#if canImport(FamilyControls)
        isShowingScreenTimePicker = true
#else
        healthStatusMessage = "Screen Time app/category picker is not available on this device."
#endif
    }

    private func connectAppleHealth() {
        isConnecting = true
        healthStatusMessage = nil
        LittleWinsHealthKitBridge.requestAuthorizationForLittleWins { result in
            DispatchQueue.main.async {
                isConnecting = false
                switch result {
                case .success:
                    config.isConnected = true
                    config.updatedAtUnix = Date().timeIntervalSince1970
                    healthStatusMessage = nil
                    if selectedMetric != nil {
                        refreshAppleHealthProgress()
                    }
                case .failure(let error):
                    config.isConnected = false
                    healthStatusMessage = error.localizedDescription
                    if LittleWinsHealthKitBridge.isAuthorizationDenied(error) {
                        presentAppleHealthAccessAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func refreshAppleHealthProgress() {
        guard usesAppleHealth else { return }
        guard config.isConnected else { return }
        isRefreshingHealthProgress = true
        healthStatusMessage = nil
        LittleWinsHealthKitBridge.readTodayProgress(for: config.metric) { result in
            DispatchQueue.main.async {
                isRefreshingHealthProgress = false
                switch result {
                case .success(let progress):
                    config.progressValue = progress
                    config.updatedAtUnix = Date().timeIntervalSince1970
                    healthStatusMessage = nil
                case .failure(let error):
                    healthStatusMessage = error.localizedDescription
                    if LittleWinsHealthKitBridge.isAuthorizationDenied(error) {
                        presentAppleHealthAccessAlert(message: error.localizedDescription)
                    }
                }
            }
        }
    }

    private func presentAppleHealthAccessAlert(message: String) {
        appleHealthAccessAlertBody = message
        showAppleHealthAccessAlert = true
    }

    private func openAppSettings() {
#if canImport(UIKit)
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
#endif
    }
}

private struct FulfillmentTrendRow: Identifiable {
    let id: String
    let weekStart: Date
    let categoryID: UUID
    let category: String
    let value: Double
}

private struct FulfillmentTrendsView: View {
    private enum TimelineOption: String, CaseIterable, Identifiable {
        case all = "All"
        case oneWeek = "2W"
        case oneMonth = "1M"
        case threeMonths = "3M"
        case sixMonths = "6M"
        case oneYear = "1Y"

        var id: String { rawValue }

        var rollingDays: Int? {
            switch self {
            case .all: return nil
            case .oneWeek: return 14
            case .oneMonth: return 30
            case .threeMonths: return 90
            case .sixMonths: return 180
            case .oneYear: return 365
            }
        }
    }

    private struct TrendSegment: Identifiable {
        let id: String
        let color: Color
        let height: CGFloat
    }

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \Fulfillment.updatedAt, order: .forward) private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentCategoryScoreSnapshot.weekStartDate, order: .forward)
    private var allSnapshots: [FulfillmentCategoryScoreSnapshot]

    @State private var selectedTimeline: TimelineOption = .all
    @State private var selectedWeekRaw: Date?
    @State private var selectedCategoryID: UUID?
    @State private var trendsInsightOutlineAngle: Double = 0
    @State private var cachedFilteredSnapshots: [FulfillmentCategoryScoreSnapshot] = []
    @State private var cachedDisplayCategoryTitleByID: [UUID: String] = [:]
    @State private var aiReadableInsightsByKey: [String: String] = [:]
    @State private var aiReadableInsightLoadingKeys: Set<String> = []
    @State private var isHowItWorksExpanded = false

    private var snapshots: [FulfillmentCategoryScoreSnapshot] {
        cachedFilteredSnapshots
    }

    private var allWeekStarts: [Date] {
        Array(Set(cachedFilteredSnapshots.map { Calendar.current.startOfDay(for: $0.weekStartDate) })).sorted()
    }

    private var latestWeekStart: Date? { allWeekStarts.last }

    private var visibleWeeks: [Date] {
        guard let latestWeekStart else { return [] }
        guard let days = selectedTimeline.rollingDays else { return allWeekStarts }
        let start = Calendar.current.date(byAdding: .day, value: -(days - 1), to: latestWeekStart) ?? latestWeekStart
        let filtered = allWeekStarts.filter { $0 >= start && $0 <= latestWeekStart }
        return filtered.isEmpty ? (allWeekStarts.isEmpty ? [] : [latestWeekStart]) : filtered
    }

    private var timelineOptions: [TimelineOption] {
        let count = allWeekStarts.count
        var options: [TimelineOption] = [.all]
        if count >= 1 { options.append(.oneWeek) }
        if count >= 4 { options.append(.oneMonth) }
        if count >= 12 { options.append(.threeMonths) }
        if count >= 26 { options.append(.sixMonths) }
        if count >= 52 { options.append(.oneYear) }
        return options
    }

    private var displayCategoryTitleByID: [UUID: String] {
        cachedDisplayCategoryTitleByID
    }

    private var liveFulfillmentCategoryIDs: Set<UUID> {
        Set(fulfillments.map(\.category_id))
    }

    private func trendsDisplayCategoryTitle(for snapshot: FulfillmentCategoryScoreSnapshot) -> String {
        displayCategoryTitleByID[snapshot.categoryID] ?? snapshot.categoryTitleSnapshot
    }

    private func trendsDisplayCategoryTitle(categoryID: UUID, fallbackSnapshotTitle: String) -> String {
        displayCategoryTitleByID[categoryID] ?? fallbackSnapshotTitle
    }

    private var latestWeekSnapshots: [FulfillmentCategoryScoreSnapshot] {
        guard let latestWeekStart else { return [] }
        return snapshots.filter {
            Calendar.current.isDate($0.weekStartDate, inSameDayAs: latestWeekStart) &&
            liveFulfillmentCategoryIDs.contains($0.categoryID)
        }
    }

    private var selectedWeekStart: Date? {
        guard let latest = latestWeekStart else { return nil }
        guard let selectedWeekRaw else { return latest }
        return nearestWeek(to: selectedWeekRaw) ?? latest
    }

    private var selectedWeekSnapshots: [FulfillmentCategoryScoreSnapshot] {
        guard let selectedWeekStart else { return latestWeekSnapshots }
        let isLatestSelection = latestWeekStart.map { Calendar.current.isDate($0, inSameDayAs: selectedWeekStart) } ?? false
        return snapshots.filter { snap in
            guard Calendar.current.isDate(snap.weekStartDate, inSameDayAs: selectedWeekStart) else { return false }
            if isLatestSelection {
                return liveFulfillmentCategoryIDs.contains(snap.categoryID)
            }
            return true
        }
    }

    private var chartCategoryIDs: [UUID] {
        let ids = Array(fulfillmentDisplayOrderCategoryIDs.prefix(7))
        if !ids.isEmpty { return ids }
        return Array(fulfillments.prefix(7).map(\.category_id))
    }

    private var fulfillmentDisplayOrderCategoryIDs: [UUID] {
        let defaultIDs: [UUID] = [
            "Career & Business",
            "Leadership & Impact",
            "Wealth & Lifestyle",
            "Mind & Meaning",
            "Love & Relationships",
            "Health & Vitality"
        ].compactMap { PlanLabelSeeder.categoryIDs[$0] }

        var ordered: [UUID] = []
        var seen = Set<UUID>()
        var byID = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0) })
        var seenTitleKeys = Set<String>()

        for id in defaultIDs {
            if let row = byID.removeValue(forKey: id) {
                let key = fulfillmentCategoryKey(row.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { continue }
                if seen.insert(row.category_id).inserted {
                    ordered.append(row.category_id)
                    seenTitleKeys.insert(key)
                }
            }
        }

        let extras = byID.values
            .sorted { $0.updatedAt > $1.updatedAt }
            .filter { row in
                let key = fulfillmentCategoryKey(row.category)
                guard !key.isEmpty, !seenTitleKeys.contains(key) else { return false }
                seenTitleKeys.insert(key)
                return true
            }
            .sorted { $0.category.localizedCaseInsensitiveCompare($1.category) == .orderedAscending }

        for row in extras where seen.insert(row.category_id).inserted {
            ordered.append(row.category_id)
        }

        let snapshotFallbackIDs = snapshots
            .sorted { lhs, rhs in
                if lhs.weekStartDate == rhs.weekStartDate {
                    return trendsDisplayCategoryTitle(for: lhs).localizedCaseInsensitiveCompare(trendsDisplayCategoryTitle(for: rhs)) == .orderedAscending
                }
                return lhs.weekStartDate > rhs.weekStartDate
            }
            .map(\.categoryID)

        for id in snapshotFallbackIDs where seen.insert(id).inserted {
            ordered.append(id)
        }
        return ordered
    }

    private func fulfillmentCategoryKey(_ raw: String) -> String {
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

    private var chartRows: [FulfillmentTrendRow] {
        let cal = Calendar.current
        let visibleSet = Set(visibleWeeks.map { cal.startOfDay(for: $0) })
        let latestVisibleWeek = latestWeekStart.map { cal.startOfDay(for: $0) }
        let grouped = Dictionary(grouping: snapshots.filter { visibleSet.contains(cal.startOfDay(for: $0.weekStartDate)) }) {
            "\(cal.startOfDay(for: $0.weekStartDate).timeIntervalSince1970)|\($0.categoryID.uuidString)"
        }.compactMapValues { rows in rows.max(by: { $0.updatedAt < $1.updatedAt }) }

        return chartCategoryIDs.flatMap { categoryID in
            visibleWeeks.map { week in
                let weekStart = cal.startOfDay(for: week)
                if let latestVisibleWeek, latestVisibleWeek == weekStart, !liveFulfillmentCategoryIDs.contains(categoryID) {
                    return FulfillmentTrendRow(
                        id: "\(Int(weekStart.timeIntervalSince1970))|\(categoryID.uuidString)",
                        weekStart: weekStart,
                        categoryID: categoryID,
                        category: displayCategoryTitleByID[categoryID] ?? "Category",
                        value: 0
                    )
                }
                let key = "\(weekStart.timeIntervalSince1970)|\(categoryID.uuidString)"
                let snap = grouped[key]
                let title = snap.map { trendsDisplayCategoryTitle(for: $0) }
                    ?? displayCategoryTitleByID[categoryID]
                    ?? "Category"
                return FulfillmentTrendRow(
                    id: "\(Int(weekStart.timeIntervalSince1970))|\(categoryID.uuidString)",
                    weekStart: weekStart,
                    categoryID: categoryID,
                    category: title,
                    value: snap?.score ?? 0
                )
            }
        }
    }

    private var chartRowsByWeek: [Date: [FulfillmentTrendRow]] {
        Dictionary(grouping: chartRows) { Calendar.current.startOfDay(for: $0.weekStart) }
    }

    private var categoryOrderIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: chartCategoryIDs.enumerated().map { ($0.element, $0.offset) })
    }

    private var categoriesListOrderIndex: [UUID: Int] {
        Dictionary(uniqueKeysWithValues: fulfillmentDisplayOrderCategoryIDs.enumerated().map { ($0.element, $0.offset) })
    }

    private var chartYMax: Double {
        let count = max(1, chartCategoryIDs.count)
        return max(25, ceil(Double(count * 5) / 5.0) * 5.0)
    }

    private var trendPlotHeight: CGFloat { 220 }
    private let trendYAxisWidth: CGFloat = 24
    private let trendLeadingPadding: CGFloat = 14
    private let trendTrailingPadding: CGFloat = 8

    private var columnWidth: CGFloat {
        switch selectedTimeline {
        case .oneWeek: return 34
        case .oneMonth: return 22
        case .threeMonths: return 16
        case .sixMonths: return 14
        case .oneYear: return 12
        case .all: return 12
        }
    }

    private var columnSpacing: CGFloat {
        switch selectedTimeline {
        case .oneWeek: return 4
        case .oneMonth: return 3
        default: return 2
        }
    }

    private var yTicks: [Double] {
        Array(stride(from: 0.0, through: chartYMax, by: 5.0))
    }

    private var bestSnapshot: FulfillmentCategoryScoreSnapshot? {
        selectedWeekSnapshots.max(by: { $0.score < $1.score })
    }

    private var strongestSnapshotIfUnique: FulfillmentCategoryScoreSnapshot? {
        guard let bestSnapshot else { return nil }
        let bestRounded = roundedTenth(bestSnapshot.score)
        let tiedCount = selectedWeekSnapshots.filter { roundedTenth($0.score) == bestRounded }.count
        return tiedCount == 1 ? bestSnapshot : nil
    }

    private var averageScore: Double {
        guard !selectedWeekSnapshots.isEmpty else { return 0 }
        return selectedWeekSnapshots.map(\.score).reduce(0, +) / Double(selectedWeekSnapshots.count)
    }

    private var biggestMover: (FulfillmentCategoryScoreSnapshot, Double)? {
        guard let _ = baselineVisibleWeekStart else { return nil }
        let deltas: [(FulfillmentCategoryScoreSnapshot, Double)] = selectedWeekSnapshots.compactMap { (snap: FulfillmentCategoryScoreSnapshot) -> (FulfillmentCategoryScoreSnapshot, Double)? in
            guard let delta = categoryDisplayedDelta(for: snap) else { return nil }
            return (snap, delta)
        }
        let result = deltas.max(by: { (lhs: (FulfillmentCategoryScoreSnapshot, Double), rhs: (FulfillmentCategoryScoreSnapshot, Double)) in
            abs(lhs.1) < abs(rhs.1)
        })
        if let result, abs(result.1) < 0.05 { return nil }
        return result
    }

    private var baselineVisibleWeekStart: Date? {
        visibleWeeks.first
    }

    private var chartRowValueByWeekCategory: [String: Double] {
        Dictionary(uniqueKeysWithValues: chartRows.map { row in
            (chartWeekCategoryKey(weekStart: row.weekStart, categoryID: row.categoryID), row.value)
        })
    }

    private var actualSnapshotValueByWeekCategory: [String: Double] {
        let visibleSet = Set(visibleWeeks.map { Calendar.current.startOfDay(for: $0) })
        let latestVisibleSnapshots = Dictionary(grouping: snapshots.filter {
            visibleSet.contains(Calendar.current.startOfDay(for: $0.weekStartDate))
        }) {
            chartWeekCategoryKey(weekStart: $0.weekStartDate, categoryID: $0.categoryID)
        }.compactMapValues { rows in
            rows.max(by: { $0.updatedAt < $1.updatedAt })
        }
        return latestVisibleSnapshots.mapValues(\.score)
    }

    private func categoryWeekOverWeekDelta(for snap: FulfillmentCategoryScoreSnapshot) -> Double? {
        categoryDisplayedDelta(for: snap)
    }

    private func categoryDisplayedDelta(for snap: FulfillmentCategoryScoreSnapshot) -> Double? {
        guard let baselineWeek = baselineVisibleWeekStart,
              let selectedWeekStart else { return nil }
        let baselineKey = chartWeekCategoryKey(weekStart: baselineWeek, categoryID: snap.categoryID)
        let selectedKey = chartWeekCategoryKey(weekStart: selectedWeekStart, categoryID: snap.categoryID)
        // Use actual snapshot presence so newly added categories don't compare against zero-filled graph placeholders.
        guard let baseline = actualSnapshotValueByWeekCategory[baselineKey],
              let selected = actualSnapshotValueByWeekCategory[selectedKey] else { return nil }
        let baselineShown = roundedTenth(baseline)
        let selectedShown = roundedTenth(selected)
        return selectedShown - baselineShown
    }

    private var selectedSnapshot: FulfillmentCategoryScoreSnapshot? {
        if let selectedCategoryID,
           let row = selectedWeekSnapshots.first(where: { $0.categoryID == selectedCategoryID }) {
            return row
        }
        return bestSnapshot ?? selectedWeekSnapshots.first
    }

    var body: some View {
        ScrollView(.vertical) {
            VStack(alignment: .leading, spacing: 12) {
                if shouldShowBaselineMethodologyCard {
                    baselineMethodologyCard
                }
                summaryTiles
                timelinePickerRow
                trendGraphSection
                categoriesSection
                insightsSection
            }
            .padding(.horizontal)
            .padding(.top, 4)
            .padding(.bottom, 12)
            .frame(maxWidth: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
        .navigationTitle("Fulfillment Insights")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            rebuildTrendsCaches()
            if selectedWeekRaw == nil {
                selectedWeekRaw = visibleWeeks.last ?? allWeekStarts.last
            }
            if selectedCategoryID == nil {
                selectedCategoryID = selectedSnapshot?.categoryID
            }
        }
        .onChange(of: snapshots.count) { _, _ in
            if selectedWeekRaw == nil || nearestWeek(to: selectedWeekRaw ?? .now) == nil {
                selectedWeekRaw = visibleWeeks.last ?? allWeekStarts.last
            }
            if let selectedCategoryID,
               selectedWeekSnapshots.contains(where: { $0.categoryID == selectedCategoryID }) {
                return
            }
            self.selectedCategoryID = selectedSnapshot?.categoryID
        }
        .onChange(of: selectedTimeline) { _, _ in
            selectedWeekRaw = visibleWeeks.last ?? allWeekStarts.last
        }
        .onChange(of: allSnapshots.count) { _, _ in
            rebuildTrendsCaches()
        }
        .onChange(of: fulfillments.map(\.updatedAt)) { _, _ in
            rebuildTrendsCaches()
        }
    }

    private func rebuildTrendsCaches() {
        let cal = Calendar.current
        let liveCategoryIDs = Set(fulfillments.map(\.category_id))

        var weeksByCategory: [UUID: Set<Date>] = [:]
        weeksByCategory.reserveCapacity(max(4, allSnapshots.count / 4))
        for snap in allSnapshots {
            weeksByCategory[snap.categoryID, default: []].insert(cal.startOfDay(for: snap.weekStartDate))
        }

        let filtered = allSnapshots.filter { snap in
            if liveCategoryIDs.contains(snap.categoryID) { return true }
            return (weeksByCategory[snap.categoryID]?.count ?? 0) >= 2
        }
        cachedFilteredSnapshots = filtered

        var titleMap = Dictionary(uniqueKeysWithValues: fulfillments.map { ($0.category_id, $0.category) })
        for snap in filtered where titleMap[snap.categoryID] == nil {
            titleMap[snap.categoryID] = snap.categoryTitleSnapshot
        }
        cachedDisplayCategoryTitleByID = titleMap
    }

    @ViewBuilder
    private var trendGraphSection: some View {
        if visibleWeeks.isEmpty {
            VStack(spacing: 6) {
                Text("No Fulfillment Trends Yet").font(.headline)
                Text("Weekly category scores will appear here as you use Loom.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 24)
            .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
        } else {
            VStack(spacing: 8) {
                GeometryReader { geo in
                    let plotWidth = max(0, geo.size.width - trendYAxisWidth)
                    HStack(spacing: 0) {
                        yAxisView
                        ScrollView(.horizontal, showsIndicators: false) {
                            VStack(alignment: .leading, spacing: 6) {
                                barsView(plotWidth: plotWidth)
                                xAxisView(plotWidth: plotWidth)
                            }
                        }
                    }
                }
                .frame(height: trendPlotHeight + 16)
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
                    .frame(width: 24, height: trendPlotHeight / CGFloat(max(1, yTicks.count - 1)), alignment: .trailing)
            }
        }
        .frame(height: trendPlotHeight)
        .frame(width: trendYAxisWidth, alignment: .trailing)
        .padding(.top, 2)
    }

    private func barsView(plotWidth: CGFloat) -> some View {
        let width = effectiveColumnWidth(plotWidth: plotWidth)
        let spacing = effectiveColumnSpacing
        return LazyHStack(alignment: .bottom, spacing: spacing) {
            ForEach(visibleWeeks, id: \.self) { week in
                Button {
                    selectedWeekRaw = week
                } label: {
                    ZStack(alignment: .bottom) {
                        RoundedRectangle(cornerRadius: 5)
                            .fill(Color(.systemBackground))
                            .frame(width: width, height: trendPlotHeight)
                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            ForEach(segments(for: week)) { segment in
                                Rectangle()
                                    .fill(segment.color)
                                    .frame(width: width, height: segment.height)
                            }
                        }
                        .frame(width: width, height: trendPlotHeight, alignment: .bottom)

                        if let selectedWeekStart, Calendar.current.isDate(selectedWeekStart, inSameDayAs: week) {
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
        .padding(.leading, trendLeadingPadding)
        .padding(.trailing, trendTrailingPadding)
        .frame(minWidth: trendContentWidth(plotWidth: plotWidth, columnWidth: width, spacing: spacing), alignment: .leading)
        .frame(height: trendPlotHeight, alignment: .bottom)
    }

    private func xAxisView(plotWidth: CGFloat) -> some View {
        let width = effectiveColumnWidth(plotWidth: plotWidth)
        let spacing = effectiveColumnSpacing
        return LazyHStack(alignment: .top, spacing: spacing) {
            ForEach(visibleWeeks, id: \.self) { week in
                Text(weekLabel(week))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .frame(width: width)
                    .lineLimit(1)
            }
        }
        .padding(.leading, trendLeadingPadding)
        .padding(.trailing, trendTrailingPadding)
        .frame(minWidth: trendContentWidth(plotWidth: plotWidth, columnWidth: width, spacing: spacing), alignment: .leading)
        .frame(height: 16, alignment: .top)
    }

    private var effectiveColumnSpacing: CGFloat { columnSpacing }

    private func effectiveColumnWidth(plotWidth: CGFloat) -> CGFloat {
        let count = max(1, visibleWeeks.count)
        let usable = max(
            0,
            plotWidth
            - trendLeadingPadding
            - trendTrailingPadding
            - CGFloat(max(0, count - 1)) * effectiveColumnSpacing
        )
        let fillWidth = usable / CGFloat(count)
        return max(columnWidth, fillWidth)
    }

    private func trendContentWidth(plotWidth: CGFloat, columnWidth: CGFloat, spacing: CGFloat) -> CGFloat {
        let count = max(1, visibleWeeks.count)
        let total = trendLeadingPadding
            + trendTrailingPadding
            + CGFloat(count) * columnWidth
            + CGFloat(max(0, count - 1)) * spacing
        return max(plotWidth, total)
    }

    private var timelinePickerRow: some View {
        HStack {
            Picker("", selection: $selectedTimeline) {
                ForEach(timelineOptions) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var summaryTiles: some View {
        HStack(spacing: 10) {
            summaryTile(
                title: "Average",
                value: selectedWeekSnapshots.isEmpty ? "—" : String(format: "%.1f/5", averageScore),
                subtitle: selectedWeekStart.map(weekDateLabel) ?? "—"
            )
            summaryTile(
                title: "Strongest",
                value: strongestSnapshotIfUnique.map { shortLabel(trendsDisplayCategoryTitle(for: $0)) } ?? "—",
                subtitle: strongestSnapshotIfUnique.map { String(format: "%.1f/5", $0.score) } ?? "—"
            )
            summaryTile(
                title: "Mover",
                value: biggestMover.map { shortLabel(trendsDisplayCategoryTitle(for: $0.0)) } ?? "—",
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
        return trendsReadableInsightPayload(for: snap).recentCategoryScores.count <= 1
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

    private var insightsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Insights").font(.headline)
                Spacer()
                if let snap = selectedSnapshot {
                    Text(trendsDisplayCategoryTitle(for: snap))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(FulfillmentCategoryTheme.color(for: trendsDisplayCategoryTitle(for: snap)))
                }
            }

            if let snap = selectedSnapshot {
                let payload = trendsReadableInsightPayload(for: snap)
                let insightKey = fulfillmentReadableInsightKey(for: payload)
                let summaryInsight = aiTrendsReadableInsightText(for: snap)
                let isLoadingInsight = aiReadableInsightLoadingKeys.contains(insightKey)
                if isLoadingInsight || summaryInsight != nil {
                    FulfillmentReadableInsightCard(
                        text: summaryInsight,
                        isLoading: isLoadingInsight,
                        font: UIFont.preferredFont(forTextStyle: .subheadline),
                        imageSize: CGSize(width: 33, height: 33),
                        cornerRadius: 12
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .onAppear {
                        guard trendsInsightOutlineAngle == 0 else { return }
                        withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                            trendsInsightOutlineAngle = 360
                        }
                    }
                }
                Color.clear
                    .frame(height: 0)
                    .task(id: insightKey) {
                        await requestTrendsReadableInsightIfNeeded(for: snap)
                    }

                VStack(spacing: 8) {
                    insightRow("Current Score", String(format: "%.1f/5", snap.score))
                    insightRow("Week Score", String(format: "%.1f/5", snap.targetScore))
                    insightRow("Momentum", momentumText(snap.momentum))
                    insightRow("Consistency", consistencyText(snap.consistency))
                    Divider()
                    insightRow("Structure", percentTextOrDash(snap.structure))
                    insightRow("Outcomes", percentTextOrDash(snap.outcomes))
                    insightRow("Action blocks", percentTextOrDash(snap.actionBlocks))
                    insightRow("Little Wins", percentTextOrDash(snap.littleWins))
                    insightRow("Engagement", percentTextOrDash(snap.engagement))
                    insightRow("Strategic Behavior", percentTextOrDash(snap.strategicBalance))
                    insightRow(
                        "Carryover penalty",
                        percentTextOrDash(snap.carryoverPenalty),
                        color: snap.carryoverPenalty > 0.30 ? .red : .secondary
                    )
                }
                .padding(10)
                .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))

                fulfillmentInsightsMethodologySection(for: snap)
            }
        }
    }

    private func insightRow(_ label: String, _ value: String, color: Color = .secondary) -> some View {
        HStack(spacing: 8) {
            Text(label).font(.subheadline)
            Spacer(minLength: 0)
            Text(value).font(.subheadline.weight(.semibold)).foregroundStyle(color)
        }
    }

    @ViewBuilder
    private func fulfillmentInsightsMethodologySection(for snap: FulfillmentCategoryScoreSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Text("Last update: \(insightsDateText(snap.updatedAt))")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Text("Next update: \(insightsDateText(nextFulfillmentUpdateDate(from: snap.updatedAt)))")
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
                    Text("Loom blends your weekly score trend with execution signals to identify where support is strong and where friction is blocking results. It then surfaces the highest-leverage focus so improvements are measurable, repeatable, and easier to sustain.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)

                    Divider()

                    VStack(alignment: .leading, spacing: 6) {
                        fulfillmentMetricLegendRow("Current Score", "overall area level")
                        fulfillmentMetricLegendRow("Week Score", "this week's target")
                        fulfillmentMetricLegendRow("Momentum", "direction of change")
                        fulfillmentMetricLegendRow("Consistency", "stability over time")
                        fulfillmentMetricLegendRow("Structure", "clarity and setup")
                        fulfillmentMetricLegendRow("Outcomes", "outcome alignment")
                        fulfillmentMetricLegendRow("Action blocks", "planned execution support")
                        fulfillmentMetricLegendRow("Little Wins", "daily execution follow-through")
                        fulfillmentMetricLegendRow("Engagement", "active involvement")
                        fulfillmentMetricLegendRow("Strategic Behavior", "high-value prioritization")
                        fulfillmentMetricLegendRow("Carryover penalty", "unfinished work drag")
                    }
                }
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    private func fulfillmentMetricLegendRow(_ title: String, _ description: String) -> some View {
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

    private func nextFulfillmentUpdateDate(from lastUpdate: Date) -> Date {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        var nextDate = calendar.date(byAdding: .day, value: 7, to: calendar.startOfDay(for: lastUpdate)) ?? today
        var guardCount = 0
        while nextDate < today && guardCount < 520 {
            nextDate = calendar.date(byAdding: .day, value: 7, to: nextDate) ?? today
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

    private var categoriesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Areas").font(.headline)
            ForEach(selectedWeekSnapshots.sorted(by: { lhs, rhs in
                let li = categoriesListOrderIndex[lhs.categoryID] ?? Int.max
                let ri = categoriesListOrderIndex[rhs.categoryID] ?? Int.max
                if li == ri {
                    return trendsDisplayCategoryTitle(for: lhs).localizedCaseInsensitiveCompare(trendsDisplayCategoryTitle(for: rhs)) == .orderedAscending
                }
                return li < ri
            }), id: \.categoryID) { snap in
                Button {
                    selectedCategoryID = snap.categoryID
                } label: {
                    HStack(spacing: 10) {
                        Circle()
                            .fill(FulfillmentCategoryTheme.color(for: trendsDisplayCategoryTitle(for: snap)))
                            .frame(width: 10, height: 10)
                        Text(trendsDisplayCategoryTitle(for: snap))
                            .foregroundStyle(.primary)
                            .fontWeight(selectedCategoryID == snap.categoryID ? .semibold : .regular)
                        Spacer(minLength: 0)
                        Text(String(format: "%.1f/5", snap.score))
                            .foregroundStyle(.secondary)
                        let delta = categoryWeekOverWeekDelta(for: snap)
                        Text(categoryDeltaGlyph(delta))
                            .foregroundStyle(categoryDeltaGlyphColor(delta))
                            .frame(width: 18)
                        if let delta {
                            Text(categoryDeltaText(delta))
                                .font(.subheadline)
                                .foregroundStyle(categoryDeltaColor(delta))
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
                            .fill(selectedCategoryID == snap.categoryID ? Color(.systemGray5) : Color(.secondarySystemBackground))
                    )
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func segments(for week: Date) -> [TrendSegment] {
        let weekKey = Calendar.current.startOfDay(for: week)
        let rows = (chartRowsByWeek[weekKey] ?? []).sorted { lhs, rhs in
            let li = categoryOrderIndex[lhs.categoryID] ?? Int.max
            let ri = categoryOrderIndex[rhs.categoryID] ?? Int.max
            return li < ri
        }
        return rows.compactMap { row in
            guard row.value > 0 else { return nil }
            let height = CGFloat(row.value / chartYMax) * trendPlotHeight
            guard height > 0 else { return nil }
            return TrendSegment(
                id: row.id,
                color: FulfillmentCategoryTheme.color(for: row.category).opacity(0.75),
                height: height
            )
        }
    }

    private func weekLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("M/d")
        return f.string(from: date)
    }

    private func weekDateLabel(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.setLocalizedDateFormatFromTemplate("M/d")
        return f.string(from: date)
    }

    private func nearestWeek(to date: Date) -> Date? {
        let candidates = visibleWeeks
        guard !candidates.isEmpty else { return nil }
        let target = Calendar.current.startOfDay(for: date)
        return candidates.min(by: { abs($0.timeIntervalSince(target)) < abs($1.timeIntervalSince(target)) })
    }

    private func chartWeekCategoryKey(weekStart: Date, categoryID: UUID) -> String {
        "\(Int(Calendar.current.startOfDay(for: weekStart).timeIntervalSince1970))|\(categoryID.uuidString)"
    }

    private func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private func shortLabel(_ title: String) -> String {
        switch title {
        case "Career & Business": return "Career"
        case "Love & Relationships": return "Love"
        case "Health & Vitality", "Health & Energy": return "Health"
        case "Mind & Meaning": return "Mind"
        case "Wealth & Lifestyle": return "Wealth"
        case "Leadership & Impact": return "Impact"
        default: return title
        }
    }

    private func percentText(_ value: Double) -> String {
        "\(Int((FulfillmentScoringMath.clamped01(value) * 100).rounded()))%"
    }

    private func percentTextOrDash(_ value: Double) -> String {
        let pct = Int((FulfillmentScoringMath.clamped01(value) * 100).rounded())
        return pct == 0 ? "—" : "\(pct)%"
    }

    private func momentumText(_ value: Double) -> String {
        let v = FulfillmentScoringMath.clamp(value, -1, 1)
        if abs(v) < 0.12 { return "Stable" }
        return v > 0 ? "Improving" : "Declining"
    }

    private func consistencyText(_ value: Double) -> String {
        let v = FulfillmentScoringMath.clamp(value, 0, 1)
        if v >= 0.75 { return "Stable" }
        if v >= 0.4 { return "Mixed" }
        return "Volatile"
    }

    private func momentumGlyph(_ value: Double) -> String {
        let v = FulfillmentScoringMath.clamp(value, -1, 1)
        if abs(v) < 0.12 { return "→" }
        return v > 0 ? "↑" : "↓"
    }

    private func momentumColor(_ value: Double) -> Color {
        let v = FulfillmentScoringMath.clamp(value, -1, 1)
        if abs(v) < 0.12 { return .secondary }
        return v > 0 ? .green : .orange
    }

    private func categoryDeltaText(_ delta: Double) -> String {
        if abs(delta) < 0.05 {
            return "—"
        }
        return String(format: "%@%.1f", delta > 0 ? "+" : "", delta)
    }

    private func categoryDeltaColor(_ delta: Double) -> Color {
        if abs(delta) < 0.05 {
            return .secondary
        }
        return delta > 0 ? .green : .orange
    }

    private func categoryDeltaGlyph(_ delta: Double?) -> String {
        guard let delta else { return "—" }
        if abs(delta) < 0.05 { return "→" }
        return delta > 0 ? "↑" : "↓"
    }

    private func categoryDeltaGlyphColor(_ delta: Double?) -> Color {
        guard let delta else { return .secondary }
        return categoryDeltaColor(delta)
    }

    private func trendsReadableInsightPayload(for snap: FulfillmentCategoryScoreSnapshot) -> FulfillmentReadableInsightRequestPayload {
        let categoryTitle = trendsDisplayCategoryTitle(for: snap)
        let sameWeek = selectedWeekSnapshots
        let sortedByScore = sameWeek.sorted { lhs, rhs in
            if lhs.score == rhs.score {
                return trendsDisplayCategoryTitle(for: lhs).localizedCaseInsensitiveCompare(trendsDisplayCategoryTitle(for: rhs)) == .orderedAscending
            }
            return lhs.score > rhs.score
        }
        let peerRank = sortedByScore.firstIndex(where: { $0.categoryID == snap.categoryID }).map { $0 + 1 }
        let strongest = sortedByScore.first
        let peerAverage = sameWeek.isEmpty ? nil : (sameWeek.map(\.score).reduce(0, +) / Double(sameWeek.count))
        let delta = categoryDisplayedDelta(for: snap).map(roundedTenth)
        let movers: [(FulfillmentCategoryScoreSnapshot, Double)] = selectedWeekSnapshots.compactMap { row in
            guard let d = categoryDisplayedDelta(for: row) else { return nil }
            return (row, d)
        }
        let biggestMover = movers.max { abs($0.1) < abs($1.1) }
        let recentScores = snapshots
            .filter { $0.categoryID == snap.categoryID }
            .sorted { $0.weekStartDate > $1.weekStartDate }
            .prefix(8)
            .map { roundedTenth($0.score) }

        return FulfillmentReadableInsightRequestPayload(
            categoryID: snap.categoryID,
            categoryTitle: categoryTitle,
            weekStartISO8601: Calendar.current.startOfDay(for: snap.weekStartDate).ISO8601Format(),
            score: roundedTenth(snap.score),
            weekScore: roundedTenth(snap.targetScore),
            weekOverWeekDelta: delta,
            momentum: roundedTenth(snap.momentum),
            consistency: roundedTenth(snap.consistency),
            structure: FulfillmentScoringMath.clamped01(snap.structure),
            outcomes: FulfillmentScoringMath.clamped01(snap.outcomes),
            actionBlocks: FulfillmentScoringMath.clamped01(snap.actionBlocks),
            littleWins: FulfillmentScoringMath.clamped01(snap.littleWins),
            engagement: FulfillmentScoringMath.clamped01(snap.engagement),
            strategicBehavior: FulfillmentScoringMath.clamped01(snap.strategicBalance),
            carryoverPenalty: FulfillmentScoringMath.clamped01(snap.carryoverPenalty),
            peerAverageScore: peerAverage.map(roundedTenth),
            peerRank: peerRank,
            peerCount: sameWeek.isEmpty ? nil : sameWeek.count,
            strongestCategory: strongest.map { trendsDisplayCategoryTitle(for: $0) },
            strongestCategoryScore: strongest.map { roundedTenth($0.score) },
            biggestMoverCategory: biggestMover.map { trendsDisplayCategoryTitle(for: $0.0) },
            biggestMoverDelta: biggestMover.map { roundedTenth($0.1) },
            recentCategoryScores: recentScores
        )
    }

    private func aiTrendsReadableInsightText(for snap: FulfillmentCategoryScoreSnapshot) -> String? {
        let payload = trendsReadableInsightPayload(for: snap)
        let key = fulfillmentReadableInsightKey(for: payload)
        guard let base = aiReadableInsightsByKey[key] ?? FulfillmentReadableInsightRuntimeStore.value(for: key) else { return nil }
        return ensureFulfillmentReadableInsightCTA(base, payload: payload)
    }

    @MainActor
    private func requestTrendsReadableInsightIfNeeded(for snap: FulfillmentCategoryScoreSnapshot) async {
        let payload = trendsReadableInsightPayload(for: snap)
        let key = fulfillmentReadableInsightKey(for: payload)
        if !loomAIInsightsRefreshEnabled(),
           let cached = aiReadableInsightsByKey[key] ?? FulfillmentReadableInsightRuntimeStore.value(for: key) {
            aiReadableInsightsByKey[key] = cached
            return
        }
        aiReadableInsightLoadingKeys.insert(key)
        defer { aiReadableInsightLoadingKeys.remove(key) }

        do {
            let contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
            let response = try await LoomAIService().sendChat(
                messages: [.init(role: "user", content: fulfillmentReadableInsightPrompt(for: payload))],
                context: contextSnapshot,
                intent: "readable_insight_fulfillment",
                screen: "fulfillment_readable_trends"
            )
            let normalized = normalizeFulfillmentReadableInsightMetricReferences(response.message, payload: payload)
            let text = limitFulfillmentReadableInsightText(normalized, maxCharacters: 220)
            let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmed.isEmpty else { return }
            FulfillmentReadableInsightRuntimeStore.set(trimmed, for: key)
            aiReadableInsightsByKey[key] = trimmed
        } catch {
            // Keep local heuristic fallback if the API is unavailable.
        }
    }

    private func primaryInsightMessage(for snap: FulfillmentCategoryScoreSnapshot) -> String? {
        struct InsightCandidate {
            let priority: Double
            let text: String
        }

        let structure = FulfillmentScoringMath.clamped01(snap.structure)
        let outcomes = FulfillmentScoringMath.clamped01(snap.outcomes)
        let actionBlocks = FulfillmentScoringMath.clamped01(snap.actionBlocks)
        let littleWins = FulfillmentScoringMath.clamped01(snap.littleWins)
        let engagement = FulfillmentScoringMath.clamped01(snap.engagement)
        let strategic = FulfillmentScoringMath.clamped01(snap.strategicBalance)
        let carry = FulfillmentScoringMath.clamped01(snap.carryoverPenalty)

        let structurePct = Int((structure * 100).rounded())
        let outcomesPct = Int((outcomes * 100).rounded())
        let actionPct = Int((actionBlocks * 100).rounded())
        let winsPct = Int((littleWins * 100).rounded())
        let engagementPct = Int((engagement * 100).rounded())
        let strategicPct = Int((strategic * 100).rounded())
        let carryPct = Int((carry * 100).rounded())

        var candidates: [InsightCandidate] = []

        if structure >= 0.7 && actionBlocks <= 0.45 {
            candidates.append(.init(
                priority: (1 - actionBlocks) * 1.4,
                text: "\(trendsDisplayCategoryTitle(for: snap)) is well designed (\(structurePct)% Structure), but execution is weak (\(actionPct)% Action blocks). Focus on finishing planned work this week."
            ))
        }

        if littleWins >= 0.65 && outcomes <= 0.45 {
            candidates.append(.init(
                priority: (1 - outcomes) * 1.35,
                text: "Daily follow-through is happening (\(winsPct)% Little Wins), but outcomes are lagging (\(outcomesPct)% Outcomes). Make sure this week’s actions move an active outcome forward."
            ))
        }

        if actionBlocks >= 0.65 && outcomes <= 0.45 {
            candidates.append(.init(
                priority: (1 - outcomes) * 1.25,
                text: "Execution volume looks solid (\(actionPct)% Action blocks), but outcomes are not converting (\(outcomesPct)% Outcomes). Re-check whether your actions are tied to the right outcome milestones."
            ))
        }

        if carry >= 0.30 {
            candidates.append(.init(
                priority: carry * 1.5,
                text: "Carryover is high (\(carryPct)% penalty), which is dragging this area down. Reduce weekly scope or break actions into smaller chunks."
            ))
        }

        if engagement <= 0.30 {
            candidates.append(.init(
                priority: (1 - engagement) * 1.2,
                text: "Engagement is low (\(engagementPct)%), so this area is not getting consistent attention. Touch it on more days, even with small progress."
            ))
        }

        if strategic <= 0.40 && actionBlocks >= 0.40 {
            candidates.append(.init(
                priority: (1 - strategic) * 1.2,
                text: "Work is getting done, but strategic behavior is low (\(strategicPct)%). Prioritize must-do actions before reactive tasks."
            ))
        }

        if structure <= 0.35 {
            candidates.append(.init(
                priority: (1 - structure) * 1.1,
                text: "This area lacks foundation (\(structurePct)% Structure). Clarifying vision, purpose, roles, or Little Wins would improve score stability quickly."
            ))
        }

        if littleWins <= 0.35 && actionBlocks >= 0.55 {
            candidates.append(.init(
                priority: (1 - littleWins) * 1.1,
                text: "Action blocks are stronger than daily consistency (\(actionPct)% vs \(winsPct)% Little Wins). Strengthen routine execution to sustain progress."
            ))
        }

        if outcomes >= 0.7 && actionBlocks >= 0.7 && carry <= 0.15 {
            candidates.append(.init(
                priority: 0.4,
                text: "This area is performing well: strong outcomes (\(outcomesPct)%), execution (\(actionPct)%), and low carryover (\(carryPct)%). Keep the current pace."
            ))
        }

        if candidates.isEmpty {
            return "This area is stable overall. Focus on one small improvement this week to raise the score."
        }
        return candidates.max(by: { $0.priority < $1.priority })?.text
    }
}

#if canImport(UIKit)
private func applyInsightMetricItalics(
    to attributed: NSMutableAttributedString,
    source: String,
    baseFont: UIFont
) {
    let labels = [
        "Momentum",
        "Consistency",
        "Structure",
        "Outcomes",
        "Action Plans",
        "Action plans",
        "Little Wins",
        "Engagement",
        "Strategic Behavior",
        "Strategic Behavior",
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

private struct FulfillmentReadableInsightCard: View {
    let text: String?
    let isLoading: Bool
    let font: UIFont
    let imageSize: CGSize
    let cornerRadius: CGFloat
    var fillColor: Color? = nil

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
        Group {
            if isLoading {
                HStack(spacing: 8) {
                    Image("LoomAI")
                        .resizable()
                        .scaledToFit()
                        .frame(width: imageSize.width, height: imageSize.height)
                    FulfillmentLoomTypingDotsIndicator()
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            } else if let text, !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                FulfillmentInlineInsightText(
                    imageName: "LoomAI",
                    text: text,
                    font: font,
                    textColor: UIColor.label,
                    imageSize: imageSize
                )
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            Group {
                if let fillColor {
                    RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                        .fill(fillColor)
                }
            }
        )
        .overlay(
            RoundedRectangle(cornerRadius: cornerRadius)
                .stroke(outlineGradient.opacity(0.95), lineWidth: 2)
        )
        .onAppear {
            outlineAngle = 0
            withAnimation(.linear(duration: 7).repeatForever(autoreverses: false)) {
                outlineAngle = 360
            }
        }
    }
}

private struct FulfillmentLoomTypingDotsIndicator: View {
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

private struct FulfillmentInlineInsightText: UIViewRepresentable {
    let imageName: String
    let text: String
    let font: UIFont
    let textColor: UIColor
    let imageSize: CGSize

    private let imageTag = 9_432
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
        let output = NSMutableAttributedString(string: text, attributes: attrs)
        applyInsightMetricItalics(to: output, source: text, baseFont: font)
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
        view.textContainer.exclusionPaths = [UIBezierPath(rect: exclusionRect)]
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView: UITextView, context: Context) -> CGSize? {
        let width = proposal.width ?? 160
        let fitting = CGSize(width: width, height: .greatestFiniteMagnitude)
        let size = uiView.sizeThatFits(fitting)
        return CGSize(width: width, height: ceil(size.height))
    }
}
#endif

struct FulfillmentInteractiveRadar: View {
    private static let fallbackMetrics: [(String, Color, Double)] = [
        ("Area 1", FulfillmentCategoryTheme.color(for: "Career & Business"), 20),
        ("Area 2", FulfillmentCategoryTheme.color(for: "Leadership & Impact"), 20),
        ("Area 3", FulfillmentCategoryTheme.color(for: "Wealth & Lifestyle"), 20),
        ("Area 4", FulfillmentCategoryTheme.color(for: "Mind & Meaning"), 20),
        ("Area 5", FulfillmentCategoryTheme.color(for: "Love & Relationships"), 20),
        ("Area 6", FulfillmentCategoryTheme.color(for: "Health & Vitality"), 20),
    ]

    let metrics: [(String, Color, Double)]
    @Binding var selectedIndex: Int
    let onManualSelect: () -> Void
    let enableInteraction: Bool
    let useOriginalDotStyle: Bool
    let customDotDiameter: CGFloat?
    let showOutline: Bool
    let emphasizeSelectedSlice: Bool
    let customDotShadowColor: Color?
    @State private var pulseIndex: Int? = nil

    init(
        metrics: [(String, Color, Double)],
        selectedIndex: Binding<Int>,
        onManualSelect: @escaping () -> Void,
        enableInteraction: Bool = true,
        useOriginalDotStyle: Bool = false,
        customDotDiameter: CGFloat? = nil,
        showOutline: Bool = true,
        emphasizeSelectedSlice: Bool = true,
        customDotShadowColor: Color? = nil
    ) {
        self.metrics = metrics.isEmpty ? Self.fallbackMetrics : metrics
        self._selectedIndex = selectedIndex
        self.onManualSelect = onManualSelect
        self.enableInteraction = enableInteraction
        self.useOriginalDotStyle = useOriginalDotStyle
        self.customDotDiameter = customDotDiameter
        self.showOutline = showOutline
        self.emphasizeSelectedSlice = emphasizeSelectedSlice
        self.customDotShadowColor = customDotShadowColor
    }

    var body: some View {
        GeometryReader { geo in
            let size = min(geo.size.width, geo.size.height)
            let center = CGPoint(x: size / 2, y: size / 2)
            let radius = size / 2
            let count = metrics.count

            if count == 0 {
                Color.clear
            } else {
                let safeSelectedIndex = min(max(0, selectedIndex), count - 1)
                let effectiveDotDiameter: CGFloat = customDotDiameter ?? (useOriginalDotStyle ? 14 : 20)
                let dotShadowRadius: CGFloat = useOriginalDotStyle ? 7 : max(5, effectiveDotDiameter * 0.5)

                let outerPoints: [CGPoint] = (0..<count).map { i in
                    let angle = Angle.degrees((Double(i) / Double(count)) * 360 - 90).radians
                    return CGPoint(x: center.x + cos(angle) * radius, y: center.y + sin(angle) * radius)
                }

                let renderedMetrics: [(String, Color, Double)] = (0..<count).map { i in
                    (metrics[i].0, segmentColor(i, selectedIndex: safeSelectedIndex), metrics[i].2)
                }
                let valuePoints: [CGPoint] = (0..<count).map { i in
                    let ratio = max(0.2, min(metrics[i].2 / 100.0, 1.0))
                    let outer = outerPoints[i]
                    return CGPoint(
                        x: center.x + (outer.x - center.x) * ratio,
                        y: center.y + (outer.y - center.y) * ratio
                    )
                }

                ZStack {
                    // Keep the radar internals identical to ContentView's graph style.
                    FulfillmentRadarGraph(
                        metrics: renderedMetrics,
                        showOutline: showOutline,
                        dotDiameter: effectiveDotDiameter,
                        showDotOutline: false,
                        showDotShadow: false
                    )

                    ForEach(0..<count, id: \.self) { i in
                        Circle()
                            .fill(metrics[i].1)
                            .frame(width: effectiveDotDiameter, height: effectiveDotDiameter)
                            .overlay(
                                Circle().stroke(Color(.systemBackground), lineWidth: 2)
                            )
                            .shadow(
                                color: (customDotShadowColor ?? Color(.systemBackground)).opacity(0.9),
                                radius: dotShadowRadius,
                                x: 0,
                                y: 0
                            )
                            .scaleEffect((useOriginalDotStyle || !emphasizeSelectedSlice) ? 1 : circleScale(for: i, selectedIndex: safeSelectedIndex))
                            .animation(.easeInOut(duration: 0.18), value: pulseIndex)
                            .animation(.easeInOut(duration: 0.18), value: selectedIndex)
                            .position(valuePoints[i])
                    }

                    if enableInteraction {
                        ForEach(0..<count, id: \.self) { i in
                            let next = (i + 1) % count
                            sliceTapShape(center: center, p1: outerPoints[i], p2: outerPoints[next])
                                .fill(Color.clear)
                                .contentShape(sliceTapShape(center: center, p1: outerPoints[i], p2: outerPoints[next]))
                                .onTapGesture {
                                    selectSlice(i)
                                }
                        }

                        // Larger, invisible tap targets around dots for easier selection.
                        ForEach(0..<count, id: \.self) { i in
                            Circle()
                                .fill(Color.clear)
                                .frame(width: 44, height: 44)
                                .contentShape(Circle())
                                .position(valuePoints[i])
                                .onTapGesture {
                                    selectSlice(i)
                                }
                        }
                    }
                }
            }
        }
    }

    private func segmentColor(_ index: Int, selectedIndex: Int) -> Color {
        guard emphasizeSelectedSlice else { return metrics[index].1 }
        if index == selectedIndex {
            return metrics[index].1
        }
        return muted(metrics[index].1)
    }

    private func muted(_ color: Color) -> Color {
        color.opacity(0.25)
    }

    private func selectSlice(_ index: Int) {
        selectedIndex = index
        onManualSelect()
        pulseIndex = index
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
            if pulseIndex == index {
                pulseIndex = nil
            }
        }
    }

    private func sliceTapShape(center: CGPoint, p1: CGPoint, p2: CGPoint) -> Path {
        Path { path in
            path.move(to: center)
            path.addLine(to: p1)
            path.addLine(to: p2)
            path.closeSubpath()
        }
    }

    private func circleScale(for index: Int, selectedIndex: Int) -> CGFloat {
        if pulseIndex == index { return 1.35 }
        if selectedIndex == index { return 1.20 }
        return 1.0
    }
}

#if canImport(UIKit)
private struct FulfillmentEditorTextView: UIViewRepresentable {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    final class Coordinator: NSObject, UITextViewDelegate {
        var parent: FulfillmentEditorTextView
        var lastCursorSeed: Int = -1

        init(parent: FulfillmentEditorTextView) {
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
        view.textContainer.lineFragmentPadding = 0
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
#else
private struct FulfillmentEditorTextView: View {
    @Binding var text: String
    @Binding var isFocused: Bool
    var cursorSeed: Int

    var body: some View {
        TextEditor(text: $text)
    }
}
#endif
