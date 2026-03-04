import SwiftUI
import SwiftData
#if canImport(UIKit)
import UIKit
#endif

struct DiagnosticInsightsView: View {
    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var personalizationStore: PersonalizationStore
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true

    let onContinue: () -> Void
    let onEditAnswers: () -> Void

    @StateObject private var viewModel = DiagnosticsInsightsViewModel()
    @State private var showErrorAlert = false
    @State private var lastFailedDiagnosticsHash: String?
    @State private var showInlineRetryButton = false
    @State private var hasTimedOutWaiting = false
    @State private var timeoutTask: Task<Void, Never>?
    @State private var timeoutAlertHash: String?

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

    private var currentDiagnosticsHash: String? {
        guard let snapshot = currentSnapshot else { return nil }
        return DiagnosticsInsightsHasher.hash(for: snapshot)
    }

    private var hasLoadedInsights: Bool {
        !viewModel.insightCards.isEmpty && viewModel.insightsErrorMessage == nil
    }

    private var isWaitingForInsights: Bool {
        !hasLoadedInsights && !hasTimedOutWaiting
    }

    var body: some View {
        ScrollView(showsIndicators: false) {
            VStack(alignment: .leading, spacing: 16) {
                InsightsThinkingHeader(
                    title: "LoomAI",
                    progress: 1.0
                )

                Text("Your quick diagnosis…")
                    .font(.system(size: 38, weight: .bold))
                    .fixedSize(horizontal: false, vertical: true)

                Text("This will shape your Loom experience and will only take a minute.")
                    .font(.title3.weight(.medium))
                    .foregroundStyle(.secondary)

                Group {
                    if viewModel.isShowingSkeleton || viewModel.insightCards.isEmpty {
                        DiagnosticInsightsSkeletonStack()
                            .transition(.opacity)
                    } else {
                        DiagnosticInsightsCardsStack(
                            cards: viewModel.insightCards,
                            lifeAreas: currentSnapshot?.lifeAreasSelected ?? [],
                            lifeAreaColorKeys: currentSnapshot?.lifeAreaColorKeys ?? [:],
                            showsAnimatedOutline: false
                        )
                        .transition(.opacity.combined(with: .move(edge: .bottom)))
                    }
                }
                .animation(.easeInOut(duration: 0.24), value: viewModel.isShowingSkeleton)
                .animation(.easeInOut(duration: 0.24), value: viewModel.insightCards.count)

                if showInlineRetryButton {
                    if loomAITroubleshootingEnabled {
                        Button("Copy troubleshooting") {
                            let details = (viewModel.troubleshootingMessage ?? "")
                                .trimmingCharacters(in: .whitespacesAndNewlines)
                            UIPasteboard.general.string = details.isEmpty
                                ? "[diagnostics_insights] troubleshooting details unavailable."
                                : details
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .center)
                    } else {
                        Button("Retry") {
                            showInlineRetryButton = false
                            restartTimeoutWindow()
                            Task { await refreshInsights(forceRefresh: true) }
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                        .controlSize(.large)
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                }

                Button {
                    onContinue()
                } label: {
                    ZStack {
                        Text("Continue")
                            .opacity(isWaitingForInsights ? 0.0 : 1.0)
                            .frame(maxWidth: .infinity)
                        if isWaitingForInsights {
                            ProgressView()
                                .progressViewStyle(.circular)
                        }
                    }
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .padding(.top, 4)
                .disabled(isWaitingForInsights)
                .opacity(isWaitingForInsights ? 0.55 : 1.0)

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
            restartTimeoutWindow()
            Task {
                await refreshInsights()
            }
        }
        .onChange(of: diagnosticsSignature) { _, _ in
            restartTimeoutWindow()
            Task {
                await refreshInsights()
            }
        }
        .onChange(of: currentDiagnosticsHash) { _, newValue in
            if newValue != lastFailedDiagnosticsHash {
                lastFailedDiagnosticsHash = nil
                showInlineRetryButton = false
            }
            if timeoutAlertHash != newValue {
                timeoutAlertHash = nil
            }
        }
        .onChange(of: hasLoadedInsights) { _, loaded in
            if loaded {
                hasTimedOutWaiting = false
                timeoutTask?.cancel()
                timeoutTask = nil
            } else if !hasTimedOutWaiting {
                restartTimeoutWindow()
            }
        }
        .onChange(of: viewModel.insightsErrorMessage) { _, newValue in
            if newValue != nil {
                lastFailedDiagnosticsHash = currentDiagnosticsHash
                if loomAITroubleshootingEnabled,
                   let details = viewModel.troubleshootingMessage,
                   !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    #if DEBUG
                    print("[DiagnosticInsights] \(details)")
                    #endif
                    loomAIReportTroubleshootingIfEnabled(details: details)
                }
            } else if !viewModel.insightCards.isEmpty {
                lastFailedDiagnosticsHash = nil
                showInlineRetryButton = false
            }
        }
        .onDisappear {
            timeoutTask?.cancel()
            timeoutTask = nil
        }
        .alert("Check your connection", isPresented: $showErrorAlert) {
            if loomAITroubleshootingEnabled,
               let details = viewModel.troubleshootingMessage,
               !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Button("Copy troubleshooting") {
                    UIPasteboard.general.string = details
                }
            }
            Button("OK", role: .cancel) {
                showInlineRetryButton = true
                onContinue()
            }
        } message: {
            Text("Generate insights later in Account > Personalization.")
        }
    }

    private func refreshInsights(forceRefresh: Bool = false) async {
        guard currentSnapshot != nil else {
            viewModel.prepareForPendingPersonalizationLoad()
            return
        }
        if !forceRefresh, showInlineRetryButton {
            return
        }
        if !forceRefresh,
           let failedHash = lastFailedDiagnosticsHash,
           failedHash == currentDiagnosticsHash {
            return
        }
        await viewModel.refresh(
            snapshot: currentSnapshot,
            in: modelContext,
            forceRefresh: forceRefresh
        )
    }

    private func restartTimeoutWindow() {
        hasTimedOutWaiting = false
        timeoutTask?.cancel()
        timeoutTask = Task {
            try? await Task.sleep(nanoseconds: 60_000_000_000)
            guard !Task.isCancelled else { return }
            await MainActor.run {
                guard !hasLoadedInsights else { return }
                hasTimedOutWaiting = true
                let currentHash = currentDiagnosticsHash
                if timeoutAlertHash != currentHash {
                    timeoutAlertHash = currentHash
                    showErrorAlert = true
                }
            }
        }
    }
}

@MainActor
final class DiagnosticsInsightsViewModel: ObservableObject {
    private static let diagnosticsInsightsConnectionError = "Couldn’t personalize insights yet. Check your connection."

    @Published fileprivate private(set) var insightCards: [DiagnosticInsightCard] = []
    @Published private(set) var isGeneratingInsights = false
    @Published private(set) var insightsErrorMessage: String?
    @Published private(set) var isShowingSkeleton = false
    @Published private(set) var troubleshootingMessage: String?

    private var loadedSnapshotKey: String?
    private var currentDiagnosticsHash: String?
    private var failedSnapshotKey: String?
    private var currentTask: Task<DiagnosticsInsightsRemoteResult, Never>?

    func prepareForPendingPersonalizationLoad() {
        guard insightCards.isEmpty else { return }
        insightsErrorMessage = nil
        troubleshootingMessage = nil
        isGeneratingInsights = false
        isShowingSkeleton = true
    }

    func refresh(
        snapshot: PersonalizationSnapshot?,
        in modelContext: ModelContext,
        forceRefresh: Bool = false,
        preserveExistingOnFailure: Bool = false,
        analysisCycleKey: String? = nil
    ) async {
        guard let snapshot else {
            cancelInFlight()
            insightCards = []
            insightsErrorMessage = Self.diagnosticsInsightsConnectionError
            troubleshootingMessage = nil
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
           failedSnapshotKey == snapshotKey {
            return
        }

        if !forceRefresh,
           let persisted = fetchStoredSnapshot(snapshotKey: snapshotKey, in: modelContext) {
            applyPersisted(persisted)
            loadedSnapshotKey = snapshotKey
            failedSnapshotKey = nil
            currentDiagnosticsHash = diagnosticsHash
            return
        }

        if let currentTask,
           currentDiagnosticsHash == diagnosticsHash {
            _ = await currentTask.value
            return
        }

        cancelInFlight()

        let previousCards = insightCards
        let shouldPreserveExistingCards = preserveExistingOnFailure && !previousCards.isEmpty

        isShowingSkeleton = !shouldPreserveExistingCards
        isGeneratingInsights = true
        insightsErrorMessage = nil
        troubleshootingMessage = nil
        if !shouldPreserveExistingCards {
            insightCards = []
        }
        currentDiagnosticsHash = diagnosticsHash

        let requestID = UUID().uuidString

        let task = Task { () -> DiagnosticsInsightsRemoteResult in
            do {
                let response = try await LoomAIService().fetchDiagnosticInsights(
                    diagnostic: DiagnosticAnswers(snapshot: snapshot),
                    client: DiagnosticInsightsClient(
                        appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                        platform: "ios",
                        screen: "diagnostic_insights"
                    )
                )
                let decoded = PersonalizationInsightsComposer.decodeRemotePayload(response)
                let fulfillmentBody = Self.fulfillmentAreasBody(from: snapshot.lifeAreasSelected)
                let rootCard = decoded.cards.first { $0.kind == .rootCause } ?? .init(kind: .rootCause, body: "")
                let nextCard = decoded.cards.first { $0.kind == .nextDirection } ?? .init(kind: .nextDirection, body: "")
                return DiagnosticsInsightsRemoteResult(
                    cards: decoded.usedFallback
                    ? []
                    : [
                        rootCard,
                        .init(kind: .fulfillmentAreas, body: fulfillmentBody),
                        nextCard
                    ],
                    errorMessage: decoded.usedFallback ? Self.diagnosticsInsightsConnectionError : nil,
                    troubleshootingMessage: decoded.usedFallback
                    ? loomAITroubleshootingLocalDetails(
                        feature: "diagnostics_insights",
                        reason: "Response payload could not be decoded into insight cards.",
                        responsePreview: "\(response.rootCause)\n\n\(response.nextDirection)",
                        requestID: requestID,
                        requestHash: diagnosticsHash
                    )
                    : nil,
                    usedFallback: decoded.usedFallback,
                    evidenceCount: 0,
                    responseCharacters: response.rootCause.count + response.nextDirection.count,
                    requestID: requestID
                )
            } catch {
                return DiagnosticsInsightsRemoteResult(
                    cards: [],
                    errorMessage: Self.diagnosticsInsightsConnectionError,
                    troubleshootingMessage: loomAITroubleshootingDetails(
                        feature: "diagnostics_insights",
                        error: error,
                        requestID: requestID,
                        requestHash: diagnosticsHash
                    ),
                    usedFallback: false,
                    evidenceCount: 0,
                    responseCharacters: 0,
                    requestID: requestID
                )
            }
        }
        currentTask = task

        let remote = await task.value
        guard currentDiagnosticsHash == diagnosticsHash else { return }

        if remote.errorMessage != nil, shouldPreserveExistingCards {
            insightCards = previousCards
            insightsErrorMessage = nil
            troubleshootingMessage = remote.troubleshootingMessage
            isGeneratingInsights = false
            isShowingSkeleton = false
            currentTask = nil
            return
        }

        if remote.errorMessage == nil {
            persist(
                cards: remote.cards,
                userKey: userKey,
                diagnosticsHash: diagnosticsHash,
                snapshotKey: snapshotKey,
                purposeRefreshCycleKey: analysisCycleKey,
                in: modelContext
            )
        }

        withAnimation(.easeInOut(duration: 0.24)) {
            insightCards = remote.cards
            insightsErrorMessage = remote.errorMessage
            troubleshootingMessage = remote.troubleshootingMessage
            isGeneratingInsights = false
            isShowingSkeleton = false
        }
        if remote.errorMessage == nil {
            loadedSnapshotKey = snapshotKey
            failedSnapshotKey = nil
        } else {
            loadedSnapshotKey = nil
            failedSnapshotKey = snapshotKey
        }
        currentTask = nil
    }

    private func cancelInFlight() {
        currentTask?.cancel()
        currentTask = nil
    }

    private func errorStateCards() -> [DiagnosticInsightCard] {
        []
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
        let fulfillment = snapshot.fulfillmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            ? Self.fulfillmentAreasBody(from: [])
            : snapshot.fulfillmentText
        insightCards = [
            DiagnosticInsightCard(kind: .rootCause, body: snapshot.rootCauseText),
            DiagnosticInsightCard(kind: .fulfillmentAreas, body: fulfillment),
            DiagnosticInsightCard(kind: .nextDirection, body: snapshot.nextDirectionText)
        ]
        insightsErrorMessage = nil
        troubleshootingMessage = nil
        isGeneratingInsights = false
        isShowingSkeleton = false
    }

    private func persist(
        cards: [DiagnosticInsightCard],
        userKey: String,
        diagnosticsHash: String,
        snapshotKey: String,
        purposeRefreshCycleKey: String?,
        in modelContext: ModelContext
    ) {
        guard cards.count == 3 else { return }
        let root = cards.first(where: { $0.kind == .rootCause })?.body ?? ""
        let fulfillment = cards.first(where: { $0.kind == .fulfillmentAreas })?.body ?? ""
        let nextDirection = cards.first(where: { $0.kind == .nextDirection })?.body ?? ""

        if let existing = fetchStoredSnapshot(snapshotKey: snapshotKey, in: modelContext) {
            existing.generatedAt = .now
            existing.rootCauseText = root
            existing.fulfillmentText = fulfillment
            existing.nextDirectionText = nextDirection
            existing.purposeRefreshCycleKey = purposeRefreshCycleKey
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
                    purposeRefreshCycleKey: purposeRefreshCycleKey,
                    version: DiagnosticsInsightsHasher.schemaVersion
                )
            )
        }

        try? modelContext.save()
    }

    private static func fulfillmentAreasBody(from areas: [String]) -> String {
        _ = areas
        return "Every task, goal, and little win will land in one of these areas, so your life stays organized."
    }
}

private struct DiagnosticsInsightsRemoteResult: Sendable {
    var cards: [DiagnosticInsightCard]
    var errorMessage: String?
    var troubleshootingMessage: String?
    var usedFallback: Bool
    var evidenceCount: Int
    var responseCharacters: Int
    var requestID: String?
}

private struct DiagnosticsInsightsDecodedPayload: Sendable {
    var cards: [DiagnosticInsightCard]
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
    let lifeAreaColorKeys: [String: String]
    var showsAnimatedOutline: Bool = true

    var body: some View {
        VStack(spacing: 12) {
            ForEach(cards) { card in
                InsightsCard(title: card.kind.title, showsAnimatedOutline: showsAnimatedOutline) {
                    if card.kind == .fulfillmentAreas {
                        let areas = uniqueLifeAreas(from: lifeAreas)
                        if !areas.isEmpty {
                            LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                                ForEach(areas, id: \.self) { area in
                                    InsightsChip(title: area, colorKey: colorKey(for: area))
                                }
                            }
                            .padding(.bottom, 2)
                        }
                    }

                    if !card.body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
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

    private func uniqueLifeAreas(from items: [String]) -> [String] {
        var seen = Set<String>()
        return items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }

    private func colorKey(for area: String) -> String? {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let exact = lifeAreaColorKeys[trimmed] {
            return exact
        }
        return lifeAreaColorKeys.first(where: { $0.key.caseInsensitiveCompare(trimmed) == .orderedSame })?.value
    }
}

struct PersonalizationInsightsCards: View {
    @Environment(\.modelContext) private var modelContext
    @AppStorage(loomAITroubleshootingDefaultsKey) private var loomAITroubleshootingEnabled = true
    let snapshot: PersonalizationSnapshot
    let purposeRefreshCycleKey: String?
    @StateObject private var viewModel = DiagnosticsInsightsViewModel()

    private var diagnosticsSignature: String {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        return "\(userKey)|\(diagnosticsHash)|v\(DiagnosticsInsightsHasher.schemaVersion)"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if viewModel.isShowingSkeleton {
                DiagnosticInsightsSkeletonStack()
            } else if !viewModel.insightCards.isEmpty {
                DiagnosticInsightsCardsStack(
                    cards: viewModel.insightCards,
                    lifeAreas: snapshot.lifeAreasSelected,
                    lifeAreaColorKeys: snapshot.lifeAreaColorKeys,
                    showsAnimatedOutline: false
                )
            } else {
                InsightsCard(title: "Insights") {
                    Text(viewModel.insightsErrorMessage ?? "Couldn’t personalize insights yet. Check your connection.")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if viewModel.insightsErrorMessage != nil {
                HStack(spacing: 10) {
                    Button("Retry") {
                        Task { await refresh(forceRefresh: true) }
                    }
                    .buttonStyle(.bordered)
                    .tint(.secondary)

                    if loomAITroubleshootingEnabled,
                       let details = viewModel.troubleshootingMessage,
                       !details.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                        Button("Copy troubleshooting") {
                            #if canImport(UIKit)
                            UIPasteboard.general.string = details
                            #endif
                        }
                        .buttonStyle(.bordered)
                        .tint(.secondary)
                    }
                }
            }
        }
        .onAppear {
            viewModel.prepareForPendingPersonalizationLoad()
        }
        .task(id: diagnosticsSignature) {
            await refreshForAccountContext()
        }
    }

    private func refresh(forceRefresh: Bool = false) async {
        await viewModel.refresh(
            snapshot: snapshot,
            in: modelContext,
            forceRefresh: forceRefresh,
            preserveExistingOnFailure: forceRefresh,
            analysisCycleKey: normalizedPurposeCycleKey
        )
    }

    private var normalizedPurposeCycleKey: String? {
        let trimmed = (purposeRefreshCycleKey ?? "").trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func refreshForAccountContext() async {
        let userKey = PersonalizationUserIdentity.currentUserKey()
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        let snapshotKey = DiagnosticsInsightsHasher.snapshotKey(userKey: userKey, diagnosticsHash: diagnosticsHash)
        let storedSnapshot = fetchStoredSnapshot(snapshotKey: snapshotKey)

        // Always load persisted/current first so text remains stable in Account > Personalization.
        await refresh(forceRefresh: false)

        guard let storedSnapshot else { return }
        guard let desiredCycle = normalizedPurposeCycleKey else { return }
        let storedCycle = storedSnapshot.purposeRefreshCycleKey?.trimmingCharacters(in: .whitespacesAndNewlines)
        guard storedCycle != desiredCycle else { return }

        // Re-analyze only when the monthly Purpose Insights cycle changes.
        await refresh(forceRefresh: true)
    }

    private func fetchStoredSnapshot(snapshotKey: String) -> DiagnosticsInsightsSnapshot? {
        let key = snapshotKey
        let descriptor = FetchDescriptor<DiagnosticsInsightsSnapshot>(
            predicate: #Predicate { $0.snapshotKey == key }
        )
        return try? modelContext.fetch(descriptor).first
    }
}

private enum PersonalizationInsightsComposer {
    static func decodeRemotePayload(_ insights: DiagnosticInsights) -> DiagnosticsInsightsDecodedPayload {
        let root = normalizedBody(insights.rootCause)
        let next = normalizedBody(insights.nextDirection)

        guard isValidInsightBody(root), isValidInsightBody(next) else {
            return .init(cards: [], usedFallback: true)
        }

        return .init(
            cards: [
                .init(kind: .rootCause, body: root),
                .init(kind: .nextDirection, body: next)
            ],
            usedFallback: false
        )
    }

    private static func normalizedBody(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isValidInsightBody(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sentences.count >= 2 && sentences.count <= 3
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

                    VStack(alignment: .leading, spacing: 7) {
                        Text(index == 2 ? "Loading next-step summary..." : "Loading insight summary...")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        Text("This placeholder line represents incoming LoomAI text.")
                            .font(.body)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                        if index != 1 {
                            Text("Second placeholder sentence while diagnostics load.")
                                .font(.body)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                        }
                    }
                    .redacted(reason: .placeholder)
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
    var showsAnimatedOutline: Bool = true
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
            if showsAnimatedOutline {
                InsightsAnimatedOutlineBorder(cornerRadius: 14)
                    .opacity(0.55)
            }
        }
    }
}

private struct InsightsChip: View {
    let title: String
    let colorKey: String?

    init(title: String, colorKey: String? = nil) {
        self.title = title
        self.colorKey = colorKey
    }

    private var color: Color {
        if let colorKey, !colorKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return FulfillmentCategoryTheme.color(forKey: colorKey)
        }
        return FulfillmentCategoryTheme.color(for: title)
    }

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
                if !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
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
