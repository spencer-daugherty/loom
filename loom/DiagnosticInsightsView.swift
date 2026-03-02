import SwiftUI
import SwiftData

struct DiagnosticInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var personalizationStore: PersonalizationStore

    let onContinue: () -> Void
    let onEditAnswers: () -> Void

    @StateObject private var viewModel = DiagnosticsInsightsViewModel()

    private var currentSnapshot: PersonalizationSnapshot? {
        personalizationStore.current
    }

    private var diagnosticsSignature: String {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        guard let snapshot = currentSnapshot else {
            return "missing|\(userKey)|v\(DiagnosticsInsightsHasher.schemaVersion)"
        }
        let hash = DiagnosticsInsightsHasher.hash(for: snapshot)
        return "\(userKey)|\(hash)|v\(DiagnosticsInsightsHasher.schemaVersion)"
    }

    private var shouldDeferRefreshUntilPersonalizationLoads: Bool {
        currentSnapshot == nil && personalizationStore.isLoading
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                InsightsThinkingHeader(
                    title: "LoomAI",
                    progress: 1.0
                )

                Text("Loom sees…")
                    .font(.system(size: 38, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("This will shape your experience.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)

                if viewModel.shouldShowPersonalizingLabel {
                    Text("Personalizing")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }

                if let errorMessage = viewModel.insightsErrorMessage {
                    HStack(alignment: .top, spacing: 8) {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Spacer(minLength: 6)

                        Button("Try again") {
                            Task {
                                await refreshInsights(forceRefresh: true)
                            }
                        }
                        .font(.caption.weight(.semibold))
                        .buttonStyle(.plain)
                        .foregroundStyle(.blue)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 10, style: .continuous))
                }

                if let nudge = viewModel.insightsNudge, !nudge.isEmpty {
                    Text(nudge)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if viewModel.isShowingSkeleton {
                    DiagnosticInsightsSkeletonStack()
                } else {
                    DiagnosticInsightsCardsStack(
                        cards: viewModel.insightCards,
                        lifeAreas: currentSnapshot?.lifeAreasSelected ?? []
                    )
                }

                Button {
                    onContinue()
                } label: {
                    Text("Continue")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)

                Button("Edit diagnostic answers") {
                    onEditAnswers()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 28)
        }
        .background(Color(.systemBackground).ignoresSafeArea())
        .onAppear {
            Task {
                await refreshInsights()
            }
        }
        .onChange(of: diagnosticsSignature) { _, _ in
            Task {
                await refreshInsights()
            }
        }
        .onChange(of: personalizationStore.isLoading) { _, _ in
            Task {
                await refreshInsights()
            }
        }
    }

    private func refreshInsights(forceRefresh: Bool = false) async {
        if shouldDeferRefreshUntilPersonalizationLoads {
            viewModel.prepareForPendingPersonalizationLoad()
            return
        }
        await viewModel.refresh(
            snapshot: currentSnapshot,
            in: modelContext,
            forceRefresh: forceRefresh
        )
    }
}

@MainActor
final class DiagnosticsInsightsViewModel: ObservableObject {
    @Published fileprivate private(set) var insightCards: [DiagnosticInsightCard] = []
    @Published private(set) var isGeneratingInsights = false
    @Published private(set) var insightsErrorMessage: String?
    @Published private(set) var insightsNudge: String?
    @Published private(set) var isShowingSkeleton = false

    private var loadedSnapshotKey: String?
    private var currentDiagnosticsHash: String?
    private var currentTask: Task<DiagnosticsInsightsRemoteResult, Never>?

    var shouldShowPersonalizingLabel: Bool {
        isGeneratingInsights && isShowingSkeleton
    }

    func prepareForPendingPersonalizationLoad() {
        guard insightCards.isEmpty else { return }
        insightsErrorMessage = nil
        insightsNudge = nil
        isGeneratingInsights = false
        isShowingSkeleton = true
    }

    func refresh(
        snapshot: PersonalizationSnapshot?,
        in modelContext: ModelContext,
        forceRefresh: Bool = false
    ) async {
        guard let snapshot else {
            cancelInFlight()
            insightCards = PersonalizationInsightsComposer.missingPersonalizationCards()
            insightsNudge = PersonalizationInsightsComposer.missingPersonalizationNudge
            insightsErrorMessage = nil
            isGeneratingInsights = false
            isShowingSkeleton = false
            loadedSnapshotKey = nil
            currentDiagnosticsHash = nil
            return
        }

        let userKey = PersonalizationUserIdentity.currentUserKey()
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        let snapshotKey = DiagnosticsInsightsHasher.snapshotKey(
            userKey: userKey,
            diagnosticsHash: diagnosticsHash
        )

        if !forceRefresh,
           loadedSnapshotKey == snapshotKey,
           !insightCards.isEmpty {
            return
        }

        if !forceRefresh,
           let persisted = fetchStoredSnapshot(snapshotKey: snapshotKey, in: modelContext) {
            applyPersisted(persisted)
            loadedSnapshotKey = snapshotKey
            currentDiagnosticsHash = diagnosticsHash
            return
        }

        if let currentTask,
           currentDiagnosticsHash == diagnosticsHash {
            _ = await currentTask.value
            return
        }

        cancelInFlight()

        let contextSnapshot: LoomAIContextSnapshot
        do {
            contextSnapshot = try LoomAIViewModel().buildContextSnapshot(in: modelContext)
        } catch {
            let fallbackCards = PersonalizationInsightsComposer.defaultCards(from: snapshot)
            insightCards = fallbackCards
            insightsNudge = PersonalizationInsightsComposer.defaultNudge
            insightsErrorMessage = "Couldn’t personalize insights yet."
            isGeneratingInsights = false
            isShowingSkeleton = false
            loadedSnapshotKey = nil
            currentDiagnosticsHash = diagnosticsHash
            return
        }

        isShowingSkeleton = true
        isGeneratingInsights = true
        insightsErrorMessage = nil
        insightsNudge = nil
        insightCards = []
        currentDiagnosticsHash = diagnosticsHash

        let instruction = PersonalizationInsightsComposer.workerInstruction(for: snapshot)
        let requestID = UUID().uuidString

        let task = Task { () -> DiagnosticsInsightsRemoteResult in
            do {
                let response = try await LoomAIService().sendChat(
                    messages: [.init(role: "user", content: instruction)],
                    context: contextSnapshot,
                    intent: "onboarding_insights_diagnostics",
                    screen: "diagnostic_insights",
                    requestID: requestID,
                    requestHash: diagnosticsHash
                )
                let decoded = PersonalizationInsightsComposer.decodeRemotePayload(
                    response.message,
                    snapshot: snapshot
                )
                #if DEBUG
                if let evidence = response.debug?.evidence, !evidence.isEmpty {
                    print("[DiagnosticsInsights] evidence=\(evidence.joined(separator: ", "))")
                }
                #endif
                return DiagnosticsInsightsRemoteResult(
                    cards: decoded.cards,
                    nudge: decoded.nudge,
                    errorMessage: decoded.usedFallback ? "Couldn’t personalize insights yet." : nil
                )
            } catch {
                return DiagnosticsInsightsRemoteResult(
                    cards: PersonalizationInsightsComposer.defaultCards(from: snapshot),
                    nudge: PersonalizationInsightsComposer.defaultNudge,
                    errorMessage: "Couldn’t personalize insights yet."
                )
            }
        }
        currentTask = task

        let remote = await task.value
        guard currentDiagnosticsHash == diagnosticsHash else { return }

        if remote.errorMessage == nil {
            persist(
                cards: remote.cards,
                userKey: userKey,
                diagnosticsHash: diagnosticsHash,
                snapshotKey: snapshotKey,
                in: modelContext
            )
        }

        insightCards = remote.cards
        insightsNudge = remote.nudge
        insightsErrorMessage = remote.errorMessage
        isGeneratingInsights = false
        isShowingSkeleton = false
        loadedSnapshotKey = (remote.errorMessage == nil) ? snapshotKey : nil
        currentTask = nil
    }

    private func cancelInFlight() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func fetchStoredSnapshot(
        snapshotKey: String,
        in modelContext: ModelContext
    ) -> DiagnosticsInsightsSnapshot? {
        let key = snapshotKey
        let descriptor = FetchDescriptor<DiagnosticsInsightsSnapshot>(
            predicate: #Predicate { $0.snapshotKey == key }
        )
        return try? modelContext.fetch(descriptor).first
    }

    private func applyPersisted(_ snapshot: DiagnosticsInsightsSnapshot) {
        insightCards = [
            DiagnosticInsightCard(kind: .rootCause, body: snapshot.rootCauseText),
            DiagnosticInsightCard(kind: .fulfillmentAreas, body: snapshot.fulfillmentText),
            DiagnosticInsightCard(kind: .nextDirection, body: snapshot.nextDirectionText)
        ]
        insightsNudge = nil
        insightsErrorMessage = nil
        isGeneratingInsights = false
        isShowingSkeleton = false
    }

    private func persist(
        cards: [DiagnosticInsightCard],
        userKey: String,
        diagnosticsHash: String,
        snapshotKey: String,
        in modelContext: ModelContext
    ) {
        guard cards.count == 3 else { return }
        let root = cards.first(where: { $0.kind == .rootCause })?.body ?? ""
        let fulfillment = cards.first(where: { $0.kind == .fulfillmentAreas })?.body
            ?? PersonalizationInsightsComposer.fulfillmentAreasLine
        let nextDirection = cards.first(where: { $0.kind == .nextDirection })?.body ?? ""

        if let existing = fetchStoredSnapshot(snapshotKey: snapshotKey, in: modelContext) {
            existing.generatedAt = .now
            existing.rootCauseText = root
            existing.fulfillmentText = fulfillment
            existing.nextDirectionText = nextDirection
            existing.version = DiagnosticsInsightsHasher.schemaVersion
        } else {
            modelContext.insert(
                DiagnosticsInsightsSnapshot(
                    snapshotKey: snapshotKey,
                    userKey: userKey,
                    diagnosticsHash: diagnosticsHash,
                    generatedAt: .now,
                    rootCauseText: root,
                    fulfillmentText: fulfillment,
                    nextDirectionText: nextDirection,
                    version: DiagnosticsInsightsHasher.schemaVersion
                )
            )
        }

        try? modelContext.save()
    }
}

private struct DiagnosticsInsightsRemoteResult: Sendable {
    var cards: [DiagnosticInsightCard]
    var nudge: String?
    var errorMessage: String?
}

private struct DiagnosticsInsightsDecodedPayload: Sendable {
    var cards: [DiagnosticInsightCard]
    var nudge: String?
    var usedFallback: Bool
}

private struct DiagnosticInsightCard: Identifiable, Hashable, Sendable {
    enum Kind: String, Hashable {
        case rootCause
        case fulfillmentAreas
        case nextDirection

        var title: String {
            switch self {
            case .rootCause:
                return "Root cause"
            case .fulfillmentAreas:
                return "Fulfillment areas"
            case .nextDirection:
                return "Next direction"
            }
        }
    }

    var kind: Kind
    var body: String
    var id: String { kind.rawValue }
}

private struct DiagnosticInsightsCardsStack: View {
    let cards: [DiagnosticInsightCard]
    let lifeAreas: [String]

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                InsightsCard(title: card.kind.title) {
                    if card.kind == .fulfillmentAreas && !lifeAreas.isEmpty {
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                            ForEach(lifeAreas, id: \.self) { area in
                                InsightsChip(title: area)
                            }
                        }
                        .padding(.bottom, 2)
                    }

                    Text(card.body)
                        .font(card.kind == .nextDirection ? .body.weight(.medium) : .body)
                        .lineSpacing(card.kind == .nextDirection ? 2.6 : 1.4)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }
}

struct PersonalizationInsightsCards: View {
    let snapshot: PersonalizationSnapshot

    var body: some View {
        DiagnosticInsightsCardsStack(
            cards: PersonalizationInsightsComposer.defaultCards(from: snapshot),
            lifeAreas: snapshot.lifeAreasSelected
        )
    }
}

private struct RemoteDiagnosticsInsightsPayload: Decodable {
    struct Card: Decodable {
        var body: String?
        var message: String?
        var text: String?
        var value: String?
    }

    var cards: [Card]?
    var nudge: String?
}

private enum PersonalizationInsightsComposer {
    static let defaultNudge = ""
    static let missingPersonalizationNudge = "Loom can personalize this once your Quick diagnostic answers are saved."
    static let fulfillmentAreasLine = "Every task, goal, and little win will land in one of these areas, so your life stays organized."

    static func workerInstruction(for snapshot: PersonalizationSnapshot) -> String {
        let payload = payloadJSONString(for: snapshot)
        return """
        Generate Quick Diagnostic insights for Loom.
        Diagnostic insights payload JSON:
        \(payload)

        Requirements:
        - Return JSON only.
        - Return exactly 3 cards in order with titles: Root cause, Fulfillment areas, Next direction.
        - Root cause must reference diagnostics A and B.
        - Fulfillment areas must mention selected areas and keep one clear sentence.
        - Next direction must be 1-2 short sentences and <=40 words total.
        - Next direction must be forward-looking, confident, and momentum-building.
        - Next direction must emphasize focus, consistency, simpler priorities, and reduced overwhelm.
        - Next direction must not restate user inputs or labels.
        - Next direction must avoid phrases like "Your current planning pattern", "You selected", and "This means".
        - Next direction must not include task instructions or immediate execution language.
        - Do not use "this week" unless explicitly requested.
        - Do not use generic productivity advice.

        Return JSON only:
        {"cards":[{"title":"Root cause","body":"string"},{"title":"Fulfillment areas","body":"string"},{"title":"Next direction","body":"string"}],"confidence":"high|medium|low","nudge":"string optional","debug":{"usedContext":true,"evidence":["path.or.field.used"],"confidence":"high|medium|low"}}
        """
    }

    static func decodeRemotePayload(_ raw: String, snapshot: PersonalizationSnapshot) -> DiagnosticsInsightsDecodedPayload {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let data = trimmed.data(using: .utf8),
              let decoded = try? JSONDecoder().decode(RemoteDiagnosticsInsightsPayload.self, from: data) else {
            return DiagnosticsInsightsDecodedPayload(
                cards: defaultCards(from: snapshot),
                nudge: defaultNudge,
                usedFallback: true
            )
        }

        let bodies = (decoded.cards ?? [])
            .compactMap { item in
                let body = (item.body ?? item.message ?? item.text ?? item.value ?? "")
                    .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                return body.isEmpty ? nil : body
            }

        let fallback = defaultCards(from: snapshot)
        let rootBodyCandidate = bodies.indices.contains(0) ? bodies[0] : fallback[0].body
        let nextDirectionBodyCandidate = bodies.indices.contains(2) ? bodies[2] : fallback[2].body

        let cards: [DiagnosticInsightCard] = [
            DiagnosticInsightCard(
                kind: .rootCause,
                body: validatedRootCauseBody(
                    candidate: rootBodyCandidate,
                    fallback: fallback[0].body,
                    snapshot: snapshot
                )
            ),
            DiagnosticInsightCard(kind: .fulfillmentAreas, body: fulfillmentAreasLine),
            DiagnosticInsightCard(
                kind: .nextDirection,
                body: validatedNextDirectionBody(
                    candidate: nextDirectionBodyCandidate,
                    fallback: fallback[2].body
                )
            )
        ]

        let nudge = decoded.nudge?
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        return DiagnosticsInsightsDecodedPayload(
            cards: cards,
            nudge: nudge?.isEmpty == true ? nil : nudge,
            usedFallback: false
        )
    }

    static func defaultCards(from snapshot: PersonalizationSnapshot) -> [DiagnosticInsightCard] {
        [
            DiagnosticInsightCard(kind: .rootCause, body: rootCauseText(snapshot)),
            DiagnosticInsightCard(kind: .fulfillmentAreas, body: fulfillmentAreasLine),
            DiagnosticInsightCard(kind: .nextDirection, body: nextDirectionText(snapshot))
        ]
    }

    static func missingPersonalizationCards() -> [DiagnosticInsightCard] {
        [
            DiagnosticInsightCard(
                kind: .rootCause,
                body: "Loom doesn’t have your personalization yet. Tap Edit answers to set your stress source and break point."
            ),
            DiagnosticInsightCard(
                kind: .fulfillmentAreas,
                body: "Loom doesn’t have your selected life areas yet. Tap Edit answers so Loom can organize your tasks, goals, and little wins."
            ),
            DiagnosticInsightCard(
                kind: .nextDirection,
                body: "Loom will set a clear direction with simpler priorities and steadier follow-through. Your progress will feel calmer, more focused, and more reliable over time."
            )
        ]
    }

    private static func payloadJSONString(for snapshot: PersonalizationSnapshot) -> String {
        let payload: [String: Any] = [
            "diagnostics": [
                "stressSource": snapshot.stressSource,
                "breakPoint": snapshot.breakPoint,
                "lifeAreasSelected": snapshot.lifeAreasSelected,
                "planningReality": snapshot.planningReality,
                "desiredChange": snapshot.desiredChange,
                "createdAt": snapshot.createdAt.ISO8601Format(),
                "weekBasedGoal": false
            ]
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: payload, options: [.sortedKeys, .prettyPrinted]),
              let jsonString = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return jsonString
    }

    private static func rootCauseText(_ snapshot: PersonalizationSnapshot) -> String {
        let stress = normalizedPhrase(snapshot.stressSource, fallback: "competing priorities pile up")
        let breakPoint = normalizedPhrase(snapshot.breakPoint, fallback: "follow-through starts to slip")
        return "Pressure builds when \(stress), and momentum tends to break at \(breakPoint). Loom will steady progress by narrowing focus and simplifying decisions."
    }

    private static func nextDirectionText(_ snapshot: PersonalizationSnapshot) -> String {
        let desired = snapshot.desiredChange.lowercased()
        let planning = snapshot.planningReality.lowercased()
        let stress = snapshot.stressSource.lowercased()
        let signal = "\(desired) \(planning) \(stress)"

        if signal.contains("balance") || signal.contains("aligned") {
            return "Loom will align your priorities into a steadier rhythm, so progress stays sustainable. You’ll move forward with clearer focus, less overwhelm, and stronger long-term momentum."
        }
        if signal.contains("consistent") || signal.contains("consistency") || signal.contains("routine") {
            return "Loom will keep your priorities focused and repeatable, so follow-through stays steady. You’ll build reliable momentum with less friction and clearer direction."
        }
        if signal.contains("control") || signal.contains("clarity") || signal.contains("organized") || signal.contains("focus") {
            return "Loom will simplify your planning into clearer priorities, so decisions feel lighter. You’ll move forward with steady focus, less overwhelm, and stronger control."
        }
        return "Loom will narrow your priorities and keep execution consistent, so progress compounds. You’ll build reliable momentum with less overwhelm and clearer focus."
    }

    private static func validatedNextDirectionBody(candidate: String, fallback: String) -> String {
        let cleaned = candidate
            .replacingOccurrences(of: #"\bGoal:\s*"#, with: "", options: .regularExpression)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return fallback
        }

        let lower = cleaned.lowercased()
        if lower.contains("this week") {
            return fallback
        }
        if containsInstructionLanguage(lower)
            || repeatsRootCauseLanguage(lower)
            || containsDiagnosticsRestatementLanguage(lower)
            || containsGenericProductivityLanguage(lower) {
            return fallback
        }

        let sentences = splitSentences(cleaned)
        guard sentences.count >= 1, sentences.count <= 2 else {
            return fallback
        }

        let candidateText = Array(sentences.prefix(2)).joined(separator: " ")
        let wordCount = candidateText.split(whereSeparator: \.isWhitespace).count
        guard wordCount <= 40 else {
            return fallback
        }

        guard containsDirectionalLanguage(lower) else {
            return fallback
        }

        return truncate(candidateText, limit: 260)
    }

    private static func validatedRootCauseBody(
        candidate: String,
        fallback: String,
        snapshot: PersonalizationSnapshot
    ) -> String {
        let cleaned = candidate
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard !cleaned.isEmpty else {
            return fallback
        }

        let lower = cleaned.lowercased()
        if containsQuoteStyleRootCauseLanguage(lower: lower, raw: cleaned)
            || containsDiagnosticsRestatementLanguage(lower)
            || containsInstructionLanguage(lower) {
            return fallback
        }

        let sentences = splitSentences(cleaned)
        guard sentences.count >= 1, sentences.count <= 2 else {
            return fallback
        }

        let rootText = Array(sentences.prefix(2)).joined(separator: " ")
        guard rootText.split(whereSeparator: \.isWhitespace).count <= 55 else {
            return fallback
        }

        guard includesPersonalizationReference(rootText, rawValue: snapshot.stressSource),
              includesPersonalizationReference(rootText, rawValue: snapshot.breakPoint) else {
            return fallback
        }

        return truncate(rootText, limit: 320)
    }

    private static func splitSentences(_ text: String) -> [String] {
        text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { sentence in
                sentence.hasSuffix(".") ? sentence : "\(sentence)."
            }
    }

    private static func truncate(_ text: String, limit: Int) -> String {
        guard text.count > limit else { return text }
        let prefix = text.prefix(limit)
        if let lastSpace = prefix.lastIndex(of: " ") {
            return String(prefix[..<lastSpace]).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return String(prefix).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func containsInstructionLanguage(_ lower: String) -> Bool {
        let forbiddenFragments = [
            "start by",
            "start now",
            "do this today",
            "do this now",
            "try ",
            "open ",
            "add ",
            "create ",
            "tap ",
            "edit ",
            "save ",
            "choose ",
            "set up "
        ]
        return forbiddenFragments.contains(where: { lower.contains($0) })
    }

    private static func repeatsRootCauseLanguage(_ lower: String) -> Bool {
        let rootCauseFragments = [
            "stress is mainly",
            "you said stress",
            "progress breaks",
            "breaks at"
        ]
        return rootCauseFragments.contains(where: { lower.contains($0) })
    }

    private static func containsDiagnosticsRestatementLanguage(_ lower: String) -> Bool {
        let fragments = [
            "your current planning pattern",
            "you selected",
            "this means",
            "stress source",
            "break point",
            "planning style",
            "desired change",
            "life areas"
        ]
        return fragments.contains(where: { lower.contains($0) })
    }

    private static func containsQuoteStyleRootCauseLanguage(lower: String, raw: String) -> Bool {
        if lower.contains("you said") || lower.contains("you selected") {
            return true
        }
        return raw.contains("\"") || raw.contains("“") || raw.contains("”")
    }

    private static func containsDirectionalLanguage(_ lower: String) -> Bool {
        let directionalTokens = [
            "we'll", "we will", "you'll", "you will",
            "focus", "clarity", "consistent", "consistency",
            "momentum", "overwhelm", "priority", "priorities",
            "steady", "direction", "simpler"
        ]
        return directionalTokens.contains(where: { lower.contains($0) })
    }

    private static func includesPersonalizationReference(_ text: String, rawValue: String) -> Bool {
        let value = rawValue
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
        guard !value.isEmpty else { return false }

        let haystack = text.lowercased()
        if haystack.contains(value) {
            return true
        }

        let tokens = value
            .replacingOccurrences(of: #"[^a-z0-9\s]"#, with: " ", options: .regularExpression)
            .split(whereSeparator: \.isWhitespace)
            .map(String.init)
            .filter { $0.count > 4 }
            .prefix(6)
        return tokens.contains(where: { haystack.contains($0) })
    }

    private static func normalizedPhrase(_ value: String, fallback: String) -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return fallback }
        guard let first = trimmed.first else { return fallback }
        return "\(String(first).lowercased())\(trimmed.dropFirst())"
    }

    private static func containsGenericProductivityLanguage(_ lower: String) -> Bool {
        let genericTokens = [
            "productivity",
            "optimize",
            "hack",
            "efficiency",
            "time management",
            "maximize output"
        ]
        return genericTokens.contains(where: { lower.contains($0) })
    }
}

private struct DiagnosticInsightsSkeletonStack: View {
    @State private var pulse: Bool = false

    var body: some View {
        VStack(spacing: 12) {
            ForEach(0..<3, id: \.self) { index in
                VStack(alignment: .leading, spacing: 12) {
                    RoundedRectangle(cornerRadius: 4, style: .continuous)
                        .fill(Color.secondary.opacity(0.22))
                        .frame(width: 140, height: 12)

                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color.secondary.opacity(0.15))
                        .frame(height: index == 2 ? 74 : 58)
                }
                .padding(16)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(Color(.secondarySystemBackground))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .stroke(Color.black.opacity(0.08), lineWidth: 1)
                )
            }
        }
        .opacity(pulse ? 1.0 : 0.72)
        .animation(.easeInOut(duration: 1.05).repeatForever(autoreverses: true), value: pulse)
        .onAppear {
            pulse = true
        }
    }
}

private struct InsightsCard<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            content()
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .overlay {
            InsightsAnimatedOutlineBorder(cornerRadius: 14)
                .opacity(0.55)
        }
    }
}

private struct InsightsChip: View {
    let title: String

    private var color: Color { FulfillmentCategoryTheme.color(for: title) }

    var body: some View {
        Text(title)
            .font(.caption.weight(.semibold))
            .foregroundStyle(color)
            .lineLimit(1)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .frame(maxWidth: .infinity, alignment: .center)
            .background(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .fill(color.opacity(0.18))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 9, style: .continuous)
                    .stroke(color.opacity(0.35), lineWidth: 1)
            )
    }
}

private struct InsightsThinkingHeader: View {
    let title: String
    let progress: Double

    @State private var shineOffset: CGFloat = -0.7

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
                                colors: InsightsGradient.tokens,
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

private struct InsightsAnimatedOutlineBorder: View {
    let cornerRadius: CGFloat
    @State private var angle: Double = 0

    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
            .stroke(
                AngularGradient(
                    colors: InsightsGradient.tokens,
                    center: .center,
                    angle: .degrees(angle)
                ),
                lineWidth: 1.2
            )
            .onAppear {
                guard angle == 0 else { return }
                withAnimation(.linear(duration: 6.5).repeatForever(autoreverses: false)) {
                    angle = 360
                }
            }
    }
}

private enum InsightsGradient {
    static let tokens: [Color] = [
        Color(red: 0.22, green: 0.47, blue: 1.0),
        Color(red: 0.15, green: 0.83, blue: 0.95),
        Color(red: 0.62, green: 0.40, blue: 0.95),
        Color(red: 0.80, green: 0.38, blue: 0.78),
        Color(red: 0.98, green: 0.36, blue: 0.58),
        Color(red: 0.22, green: 0.47, blue: 1.0)
    ]
}

#Preview {
    NavigationStack {
        DiagnosticInsightsView(onContinue: {}, onEditAnswers: {})
            .environmentObject(PersonalizationStore())
    }
}
