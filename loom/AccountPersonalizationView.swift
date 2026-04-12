import SwiftUI
import SwiftData

struct AccountPersonalizationView: View {
    private static let diagnosticsFallbackMessage = "Processing error. Please try again later."
    private typealias RefreshedDiagnosticsInsights = (diagnosticsHash: String, rootCause: String, nextDirection: String)
    private static let diagnosticsDisplayCachePrefix = "loom.personalization.diagnostics-display.v1"

    private struct CachedDiagnosticsDisplay: Codable {
        var diagnosticsHash: String
        var rootCause: String
        var nextDirection: String
    }

    private struct PurposeProfileDisplay {
        var profile: String
        var strength: String
        var weakness: String
        var stressTrigger: String
        var breakingPoint: String
        var confidence: Double?
        var lowConfidence: Bool
        var alternatives: [String]
    }

    private enum EditorMode: String, Identifiable {
        case edit
        case reset
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var personalizationStore: PersonalizationStore
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \Fulfillment.updatedAt, order: .forward) private var fulfillmentCategories: [Fulfillment]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse) private var diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    @Query(sort: \PurposeProfileInsightsSnapshot.generatedAt, order: .reverse) private var purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]
    @State private var editorMode: EditorMode?
    @State private var selectedHistorySnapshot: PersonalizationSnapshot?
    @State private var isSaving = false
    @State private var isRefreshingDiagnosticsInsights = false
    @State private var displayedDiagnosticsHash: String?
    @State private var displayedRootCause = ""
    @State private var displayedNextDirection = ""
    @State private var postSaveRefreshTask: Task<Void, Never>?
    @State private var pendingDiagnosticsHydrationKey: String?

    private var diagnosticsSnapshotsSignature: String {
        diagnosticsInsightsSnapshots
            .map { "\($0.snapshotKey)|\($0.generatedAt.timeIntervalSince1970)" }
            .joined(separator: ",")
    }

    var body: some View {
        List {
            Section {
                NavigationLink {
                    FulfillmentStartView(
                        entryMode: .lifeOSInsights,
                        showsProgressStrip: false,
                        openedFromPersonalization: true
                    )
                } label: {
                    Text("Loom Ecosystem")
                }
            }

            Section("Insights") {
                if let current = personalizationStore.current {
                    VStack(spacing: 12) {
                        if let profileDisplay = latestPurposeProfileDisplay {
                            purposeProfileSnapshotCard(profileDisplay)
                            Text("Personality profile updates on-device from your current diagnostic answers.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }

                        personalizationDiagnosticInsightsCards(for: current)

                        Button("Edit diagnostic answers") {
                            editorMode = .edit
                        }
                        .buttonStyle(.plain)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .listRowInsets(EdgeInsets(top: 10, leading: 16, bottom: 10, trailing: 16))
                } else {
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Finish your diagnostic")
                            .font(.headline)

                        Text("Answer 6 quick questions. Loom will personalize your insights and AutoWrite.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        Button("Start diagnostic") {
                            editorMode = .reset
                        }
                        .buttonStyle(.borderedProminent)
                    }
                    .padding(.vertical, 4)
                }
            }

            if let current = personalizationStore.current {
                Section("Current") {
                    snapshotRows(current)
                }
            }

            Section("History") {
                if personalizationStore.history.isEmpty {
                    Text("Old diagnostics will appear here when you update.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(Array(personalizationStore.history.prefix(10).enumerated()), id: \.element.id) { index, snapshot in
                        Button {
                            selectedHistorySnapshot = snapshot
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(snapshot.createdAt.formatted(date: .abbreviated, time: .shortened))
                                    .font(.subheadline.weight(.semibold))
                                Text(summaryForHistoryItem(snapshot, at: index))
                                    .font(.footnote)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .background(Color(.systemBackground))
        .navigationTitle("Personalization")
        .navigationBarTitleDisplayMode(.inline)
        .overlay {
            if isSaving {
                ProgressView("Saving…")
                    .padding()
                    .background(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .fill(Color(.systemBackground))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .stroke(Color.black.opacity(0.08), lineWidth: 1)
                    )
            }
        }
        .task(id: personalizationStore.userKey) {
            guard personalizationStore.current == nil, !personalizationStore.isLoading else { return }
            await personalizationStore.reloadForCurrentUser()
        }
        .onAppear {
            syncDisplayedDiagnosticInsightsWithCurrentSnapshot()
        }
        .onChange(of: personalizationStore.current?.id) { _, _ in
            syncDisplayedDiagnosticInsightsWithCurrentSnapshot()
        }
        .onChange(of: diagnosticsSnapshotsSignature) { _, _ in
            syncDisplayedDiagnosticInsightsWithCurrentSnapshot()
        }
        .sheet(item: $editorMode) { mode in
            NavigationStack {
                DiagnosticFlowView(
                    mode: .accountEdit,
                    initialDraft: mode == .edit ? personalizationStore.current.map(PersonalizationDraft.init(snapshot:)) : nil
                ) { draft, _ in
                    await saveDiagnosticDraft(draft, mode: mode)
                }
                .navigationTitle("Quick Diagnostic")
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            editorMode = nil
                        }
                    }
                }
            }
        }
        .sheet(item: $selectedHistorySnapshot) { snapshot in
            NavigationStack {
                List {
                    snapshotRows(snapshot)
                }
                .navigationTitle("Snapshot")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") {
                            selectedHistorySnapshot = nil
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func snapshotRows(_ snapshot: PersonalizationSnapshot) -> some View {
        row("Most stress", value: snapshot.stressSource)
        row("Break point", value: snapshot.breakPoint)
        row("Most days", value: snapshot.planningReality)
        row("First change", value: snapshot.desiredChange)
        row(
            "Saved",
            value: snapshot.createdAt.formatted(
                .dateTime.month(.abbreviated).day().year().hour().minute()
            )
        )
    }

    @ViewBuilder
    private func row(_ title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.footnote)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.body.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(.vertical, 2)
    }

    private func summaryForHistoryItem(_ snapshot: PersonalizationSnapshot, at index: Int) -> String {
        let newer: PersonalizationSnapshot? = {
            if index == 0 {
                return personalizationStore.current
            }
            return personalizationStore.history[index - 1]
        }()
        guard let newer else { return "Snapshot archived." }
        return PersonalizationHistoryDiff.summary(from: snapshot, to: newer)
    }

    @ViewBuilder
    private func personalizationDiagnosticInsightsCards(for snapshot: PersonalizationSnapshot) -> some View {
        let resolved = resolvedDiagnosticsDisplay(for: snapshot)
        VStack(spacing: 12) {
            personalizationInsightCard(
                title: "Root cause",
                body: resolved.rootCause,
                showsLoading: isRefreshingDiagnosticsInsights
            )
            personalizationInsightCard(
                title: "Fulfillment areas",
                body: "Every task, goal, and little win will land in one of these areas, so your life stays organized.",
                chips: officialFulfillmentAreaTitles,
                colorKeys: officialFulfillmentAreaColorKeys,
                showsLoading: false
            )
            personalizationInsightCard(
                title: "Next direction",
                body: resolved.nextDirection,
                showsLoading: isRefreshingDiagnosticsInsights
            )
        }
    }

    @ViewBuilder
    private func personalizationInsightCard(
        title: String,
        body: String,
        chips: [String] = [],
        colorKeys: [String: String] = [:],
        showsLoading: Bool
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            if showsLoading {
                ProgressView()
                    .progressViewStyle(.circular)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.bottom, 4)
            }

            if !chips.isEmpty {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], spacing: 8) {
                    ForEach(uniqueLifeAreas(from: chips), id: \.self) { area in
                        personalizationInsightsChip(title: area, colorKey: colorKey(for: area, map: colorKeys))
                    }
                }
                .padding(.bottom, 2)
            }

            if !body.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text(body)
                    .font(title == "Next direction" ? .body.weight(.medium) : .body)
                    .lineSpacing(title == "Next direction" ? 2.6 : 1.4)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
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

    private func uniqueLifeAreas(from items: [String]) -> [String] {
        var seen = Set<String>()
        return items
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert(normalizedFulfillmentAreaKey(for: $0)).inserted }
    }

    private func normalizedFulfillmentAreaKey(for raw: String) -> String {
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

    private func colorKey(for area: String, map: [String: String]) -> String? {
        let trimmed = area.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }
        if let exact = map[trimmed] {
            return exact
        }
        return map.first(where: { $0.key.caseInsensitiveCompare(trimmed) == .orderedSame })?.value
    }

    @ViewBuilder
    private func personalizationInsightsChip(title: String, colorKey: String?) -> some View {
        let accent = personalizationChipColor(for: colorKey)
        Text(title)
            .font(.footnote.weight(.semibold))
            .foregroundStyle(accent)
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(accent.opacity(0.12))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .stroke(accent.opacity(0.24), lineWidth: 1)
            )
    }

    private func personalizationChipColor(for key: String?) -> Color {
        switch key?.lowercased() {
        case "green":
            return .green
        case "indigo":
            return .indigo
        case "purple":
            return .purple
        case "red":
            return .red
        case "orange":
            return .orange
        case "brown":
            return .brown
        case "pink":
            return .pink
        default:
            return .blue
        }
    }

    private var officialFulfillmentAreaTitles: [String] {
        let titles = fulfillmentCategories
            .map(\.category)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        let unique = uniqueLifeAreas(from: titles)
        if !unique.isEmpty {
            return unique
        }
        return personalizationStore.current?.lifeAreasSelected ?? []
    }

    private var officialFulfillmentAreaColorKeys: [String: String] {
        var map: [String: String] = [:]
        for title in officialFulfillmentAreaTitles {
            map[title] = FulfillmentCategoryTheme.colorKey(for: title)
        }
        if !map.isEmpty {
            return map
        }
        return personalizationStore.current?.lifeAreaColorKeys ?? [:]
    }

    private func syncDisplayedDiagnosticInsightsWithCurrentSnapshot() {
        guard let current = personalizationStore.current else {
            displayedDiagnosticsHash = nil
            displayedRootCause = ""
            displayedNextDirection = ""
            pendingDiagnosticsHydrationKey = nil
            return
        }
        guard !isRefreshingDiagnosticsInsights else { return }

        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: current)
        let hydrationKey = "\(current.id.uuidString)|\(diagnosticsHash)"
        let storedRoot = current.diagnosticRootCause?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let storedNext = current.diagnosticNextDirection?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !storedRoot.isEmpty, !storedNext.isEmpty {
            displayedDiagnosticsHash = diagnosticsHash
            displayedRootCause = storedRoot
            displayedNextDirection = storedNext
            pendingDiagnosticsHydrationKey = nil
            cacheDisplayedDiagnostics(
                diagnosticsHash: diagnosticsHash,
                rootCause: storedRoot,
                nextDirection: storedNext
            )
            return
        }
        let snapshotKey = DiagnosticsInsightsHasher.snapshotKey(
            userKey: personalizationStore.userKey,
            diagnosticsHash: diagnosticsHash
        )
        if let persisted = latestDiagnosticsInsightsSnapshot(
            userKey: personalizationStore.userKey,
            diagnosticsHash: diagnosticsHash
        ) ?? fetchStoredDiagnosticsInsightsSnapshot(snapshotKey: snapshotKey) {
            displayedDiagnosticsHash = diagnosticsHash
            displayedRootCause = persisted.rootCauseText
            displayedNextDirection = persisted.nextDirectionText
            cacheDisplayedDiagnostics(
                diagnosticsHash: diagnosticsHash,
                rootCause: persisted.rootCauseText,
                nextDirection: persisted.nextDirectionText
            )
            if pendingDiagnosticsHydrationKey != hydrationKey {
                pendingDiagnosticsHydrationKey = hydrationKey
                Task {
                    await personalizationStore.persistDiagnosticInsights(
                        snapshotID: current.id,
                        rootCause: persisted.rootCauseText,
                        nextDirection: persisted.nextDirectionText
                    )
                    await MainActor.run {
                        if pendingDiagnosticsHydrationKey == hydrationKey {
                            pendingDiagnosticsHydrationKey = nil
                        }
                    }
                }
            }
        } else if let cached = cachedDisplayedDiagnostics(diagnosticsHash: diagnosticsHash) {
            displayedDiagnosticsHash = diagnosticsHash
            displayedRootCause = cached.rootCause
            displayedNextDirection = cached.nextDirection
        } else {
            // Do not inject the fallback during load races on page re-entry.
            // Keep whatever is currently rendered until a persisted snapshot arrives.
            if displayedDiagnosticsHash == nil {
                displayedDiagnosticsHash = diagnosticsHash
            }
        }
    }

    private func saveDiagnosticDraft(_ draft: PersonalizationDraft, mode: EditorMode) async {
        isSaving = true
        let previousRootCause = displayedRootCause
        let previousNextDirection = displayedNextDirection

        do {
            let source: PersonalizationSaveSource = mode == .reset ? .accountReset : .accountEdit
            let savedSnapshot = try await personalizationStore.saveSnapshot(from: draft, source: source)
            AppDebugActivityLog.log(
                "Personalization",
                "Edit diagnostic saved. mode=\(mode.rawValue) snapshot=\(savedSnapshot.id.uuidString)"
            )

            // Dismiss the diagnostic flow before starting the visible refresh so the
            // Personalization page can show the loading state instead of burning it
            // down behind the modal.
            editorMode = nil
            isSaving = false
            postSaveRefreshTask?.cancel()
            postSaveRefreshTask = Task { @MainActor in
                await Task.yield()
                await performPostSaveInsightsRefresh(
                    savedSnapshot: savedSnapshot,
                    previousRootCause: previousRootCause,
                    previousNextDirection: previousNextDirection
                )
            }
        } catch {
            // Keep previous values if save fails.
            isSaving = false
            editorMode = nil
            isRefreshingDiagnosticsInsights = false
            AppDebugActivityLog.log("Personalization", "Edit diagnostic save failed: \(error.localizedDescription)")
        }
    }

    private func performPostSaveInsightsRefresh(
        savedSnapshot: PersonalizationSnapshot,
        previousRootCause: String,
        previousNextDirection: String
    ) async {
        let refreshStartedAt = Date()
        isRefreshingDiagnosticsInsights = true
        let refreshedInsights = await refreshInsightsForUpdatedDiagnostic(savedSnapshot)
        let minimumLoadingInterval: TimeInterval = 2.0
        let elapsed = Date().timeIntervalSince(refreshStartedAt)
        if elapsed < minimumLoadingInterval {
            let remainingNanoseconds = UInt64((minimumLoadingInterval - elapsed) * 1_000_000_000)
            try? await Task.sleep(nanoseconds: remainingNanoseconds)
        }
        guard !Task.isCancelled else { return }
        if let refreshedInsights {
            await personalizationStore.persistDiagnosticInsights(
                snapshotID: savedSnapshot.id,
                rootCause: refreshedInsights.rootCause,
                nextDirection: refreshedInsights.nextDirection
            )
            displayedDiagnosticsHash = refreshedInsights.diagnosticsHash
            displayedRootCause = refreshedInsights.rootCause
            displayedNextDirection = refreshedInsights.nextDirection
            pendingDiagnosticsHydrationKey = nil
            cacheDisplayedDiagnostics(
                diagnosticsHash: refreshedInsights.diagnosticsHash,
                rootCause: refreshedInsights.rootCause,
                nextDirection: refreshedInsights.nextDirection
            )
        } else {
            displayedDiagnosticsHash = DiagnosticsInsightsHasher.hash(for: savedSnapshot)
            displayedRootCause = previousRootCause.isEmpty ? Self.diagnosticsFallbackMessage : previousRootCause
            displayedNextDirection = previousNextDirection.isEmpty ? Self.diagnosticsFallbackMessage : previousNextDirection
        }
        isRefreshingDiagnosticsInsights = false
        AppDebugActivityLog.log("Personalization", "Post-save insights refresh completed")
    }

    private func refreshInsightsForUpdatedDiagnostic(_ snapshot: PersonalizationSnapshot) async -> RefreshedDiagnosticsInsights? {
        let userKey = personalizationStore.userKey
        let diagnostics = DiagnosticAnswers(snapshot: snapshot)
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        let diagnosticsSnapshotKey = DiagnosticsInsightsHasher.snapshotKey(
            userKey: userKey,
            diagnosticsHash: diagnosticsHash
        )
        AppDebugActivityLog.log(
            "Personalization",
            "refreshInsightsForUpdatedDiagnostic start user=\(userKey) diagnosticsHash=\(String(diagnosticsHash.prefix(8)))"
        )

        let fallbackDiagnosticsSnapshot = latestDiagnosticsInsightsSnapshot(
            userKey: userKey,
            diagnosticsHash: diagnosticsHash
        )

        var rootCause = fallbackDiagnosticsSnapshot?.rootCauseText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var nextDirection = fallbackDiagnosticsSnapshot?.nextDirectionText.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        var receivedFreshValidInsights = false
        let fulfillmentText = fallbackDiagnosticsSnapshot?.fulfillmentText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
            ? fallbackDiagnosticsSnapshot!.fulfillmentText
            : "Every task, goal, and little win will land in one of these areas, so your life stays organized."

        do {
            let response = try await LoomAIService().fetchDiagnosticInsights(
                diagnostic: diagnostics,
                client: DiagnosticInsightsClient(
                    appVersion: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String,
                    platform: "ios",
                    screen: "account_personalization"
                )
            )
            let normalizedRoot = normalizeInsightsBody(response.rootCause)
            let normalizedNext = normalizeInsightsBody(response.nextDirection)
            if isRenderableDiagnosticInsightBody(normalizedRoot),
               isRenderableDiagnosticInsightBody(normalizedNext),
               normalizedRoot != Self.diagnosticsFallbackMessage,
               normalizedNext != Self.diagnosticsFallbackMessage {
                rootCause = normalizedRoot
                nextDirection = normalizedNext
                receivedFreshValidInsights = true
                AppDebugActivityLog.log(
                    "Personalization",
                    "Diagnostic insights refreshed from API root/next chars=\(rootCause.count)/\(nextDirection.count)"
                )
                upsertDiagnosticsInsightsSnapshot(
                    snapshotKey: diagnosticsSnapshotKey,
                    userKey: userKey,
                    diagnosticsHash: diagnosticsHash,
                    rootCause: rootCause,
                    fulfillmentText: fulfillmentText,
                    nextDirection: nextDirection,
                    purposeRefreshCycleKey: fallbackDiagnosticsSnapshot?.purposeRefreshCycleKey
                )
            } else {
                AppDebugActivityLog.log(
                    "Personalization",
                    "Diagnostic insights response rejected; preserving prior root/next"
                )
            }
        } catch {
            // Keep fallback diagnostics values.
            AppDebugActivityLog.log("Personalization", "Diagnostic insights refresh failed: \(error.localizedDescription)")
        }

        let resolvedRecord = snapshot.personalityMatch.winnerRecord

        let monthKey = PurposeProfileInsightsHasher.measuredMonthKey()
        let inputsHash = PurposeProfileInsightsHasher.hash(
            diagnostic: diagnostics,
            vision: currentVisionForProfileInsights(),
            passions: currentPassionsForProfileInsights()
        )
        let purposeSnapshotKey = PurposeProfileInsightsHasher.snapshotKey(
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash
        )
        AppDebugActivityLog.log(
            "Personalization",
            "Purpose profile refresh request month=\(monthKey) inputsHash=\(String(inputsHash.prefix(8))) profile=\(resolvedRecord.profile)"
        )
        upsertPurposeProfileSnapshot(
            snapshotKey: purposeSnapshotKey,
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash,
            record: resolvedRecord
        )

        if receivedFreshValidInsights || fallbackDiagnosticsSnapshot != nil {
            upsertDiagnosticsInsightsSnapshot(
                snapshotKey: diagnosticsSnapshotKey,
                userKey: userKey,
                diagnosticsHash: diagnosticsHash,
                rootCause: rootCause,
                fulfillmentText: fulfillmentText,
                nextDirection: nextDirection,
                purposeRefreshCycleKey: purposeSnapshotKey
            )
        }
        AppDebugActivityLog.log(
            "Personalization",
            "refreshInsightsForUpdatedDiagnostic completed profileKey=\(purposeSnapshotKey)"
        )

        guard receivedFreshValidInsights else { return nil }
        return (diagnosticsHash, rootCause, nextDirection)
    }

    private func normalizeInsightsBody(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func isRenderableDiagnosticInsightBody(_ text: String) -> Bool {
        guard !text.isEmpty else { return false }
        let sentences = text
            .split(whereSeparator: { ".!?".contains($0) })
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        return sentences.count >= 2 && sentences.count <= 3
    }

    private func latestDiagnosticsInsightsSnapshot(
        userKey: String,
        diagnosticsHash: String
    ) -> DiagnosticsInsightsSnapshot? {
        diagnosticsInsightsSnapshots.first(where: {
            $0.userKey == userKey && $0.diagnosticsHash == diagnosticsHash
        })
    }

    private func fetchStoredDiagnosticsInsightsSnapshot(snapshotKey: String) -> DiagnosticsInsightsSnapshot? {
        let key = snapshotKey
        let descriptor = FetchDescriptor<DiagnosticsInsightsSnapshot>(
            predicate: #Predicate { $0.snapshotKey == key }
        )
        return (try? modelContext.fetch(descriptor))?
            .sorted(by: { $0.generatedAt > $1.generatedAt })
            .first
    }

    private func cacheDisplayedDiagnostics(
        diagnosticsHash: String,
        rootCause: String,
        nextDirection: String
    ) {
        let payload = CachedDiagnosticsDisplay(
            diagnosticsHash: diagnosticsHash,
            rootCause: rootCause,
            nextDirection: nextDirection
        )
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(payload) else { return }
        UserDefaults.standard.set(data, forKey: diagnosticsDisplayCacheKey(diagnosticsHash: diagnosticsHash))
    }

    private func cachedDisplayedDiagnostics(diagnosticsHash: String) -> CachedDiagnosticsDisplay? {
        guard let data = UserDefaults.standard.data(forKey: diagnosticsDisplayCacheKey(diagnosticsHash: diagnosticsHash)) else {
            return nil
        }
        return try? JSONDecoder().decode(CachedDiagnosticsDisplay.self, from: data)
    }

    private func diagnosticsDisplayCacheKey(diagnosticsHash: String) -> String {
        "\(Self.diagnosticsDisplayCachePrefix).\(PersonalizationUserIdentity.storageSafeKey(for: personalizationStore.userKey)).\(diagnosticsHash)"
    }

    private func resolvedDiagnosticsDisplay(for snapshot: PersonalizationSnapshot) -> (rootCause: String, nextDirection: String) {
        let diagnosticsHash = DiagnosticsInsightsHasher.hash(for: snapshot)
        let storedRoot = snapshot.diagnosticRootCause?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        let storedNext = snapshot.diagnosticNextDirection?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""

        if !storedRoot.isEmpty, !storedNext.isEmpty {
            return (storedRoot, storedNext)
        }

        if displayedDiagnosticsHash == diagnosticsHash,
           (!displayedRootCause.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ||
            !displayedNextDirection.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty) {
            return (displayedRootCause, displayedNextDirection)
        }

        let snapshotKey = DiagnosticsInsightsHasher.snapshotKey(
            userKey: personalizationStore.userKey,
            diagnosticsHash: diagnosticsHash
        )
        if let persisted = latestDiagnosticsInsightsSnapshot(
            userKey: personalizationStore.userKey,
            diagnosticsHash: diagnosticsHash
        ) ?? fetchStoredDiagnosticsInsightsSnapshot(snapshotKey: snapshotKey) {
            return (persisted.rootCauseText, persisted.nextDirectionText)
        }

        if let cached = cachedDisplayedDiagnostics(diagnosticsHash: diagnosticsHash) {
            return (cached.rootCause, cached.nextDirection)
        }

        return (displayedRootCause, displayedNextDirection)
    }

    private func currentVisionForProfileInsights() -> String {
        (drivingForces.first?.ultimateVision ?? "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func currentPassionsForProfileInsights() -> [String] {
        let normalized = passions
            .map { $0.passion }
            .map {
                $0.replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .filter { !$0.isEmpty }
        return Array(Set(normalized)).sorted { $0.localizedCaseInsensitiveCompare($1) == .orderedAscending }
    }

    private func upsertDiagnosticsInsightsSnapshot(
        snapshotKey: String,
        userKey: String,
        diagnosticsHash: String,
        rootCause: String,
        fulfillmentText: String,
        nextDirection: String,
        purposeRefreshCycleKey: String?
    ) {
        if let existing = diagnosticsInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
            existing.generatedAt = .now
            existing.userKey = userKey
            existing.diagnosticsHash = diagnosticsHash
            existing.rootCauseText = rootCause
            existing.fulfillmentText = fulfillmentText
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
                    rootCauseText: rootCause,
                    fulfillmentText: fulfillmentText,
                    nextDirectionText: nextDirection,
                    purposeRefreshCycleKey: purposeRefreshCycleKey,
                    version: DiagnosticsInsightsHasher.schemaVersion
                )
            )
        }
        try? modelContext.save()
    }

    private func upsertPurposeProfileSnapshot(
        snapshotKey: String,
        userKey: String,
        monthKey: String,
        inputsHash: String,
        record: PurposeProfileRecord
    ) {
        if purposeProfileInsightsSnapshots.contains(where: { $0.userKey == userKey && $0.monthKey == monthKey }) {
            return
        } else if let existing = purposeProfileInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
            existing.generatedAt = .now
            existing.userKey = userKey
            existing.monthKey = monthKey
            existing.inputsHash = inputsHash
            existing.profile = record.profile
            existing.strength = record.strength
            existing.weakness = record.weakness
            existing.stressTrigger = record.stressTrigger
            existing.breakingPoint = record.breakingPoint
        } else {
            modelContext.insert(
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
        try? modelContext.save()
    }

    private var latestPurposeProfileDisplay: PurposeProfileDisplay? {
        if let match = personalizationStore.current?.personalityMatch {
            let record = match.winnerRecord
            return PurposeProfileDisplay(
                profile: record.profile,
                strength: record.strength,
                weakness: record.weakness,
                stressTrigger: record.stressTrigger,
                breakingPoint: record.breakingPoint,
                confidence: match.confidence,
                lowConfidence: match.lowConfidence,
                alternatives: match.alternativeProfileNames
            )
        }

        let userKey = personalizationStore.userKey
        guard let snapshot = purposeProfileInsightsSnapshots.first(where: { $0.userKey == userKey }) else { return nil }
        return PurposeProfileDisplay(
            profile: snapshot.profile,
            strength: snapshot.strength,
            weakness: snapshot.weakness,
            stressTrigger: snapshot.stressTrigger,
            breakingPoint: snapshot.breakingPoint,
            confidence: nil,
            lowConfidence: false,
            alternatives: []
        )
    }

    @ViewBuilder
    private func purposeProfileSnapshotCard(_ profile: PurposeProfileDisplay) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Loom sees you (so far)...")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(profile.profile)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            if let confidence = profile.confidence {
                Text(profile.lowConfidence ? "Low-confidence match" : "Confidence \(Int((confidence * 100).rounded()))%")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(profile.lowConfidence ? .orange : .secondary)
            }

            detailRow(title: "Strength", value: profile.strength)
            detailRow(title: "Weakness", value: profile.weakness)

            VStack(alignment: .leading, spacing: 4) {
                Text("Signals")
                    .font(.footnote.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                    .tracking(0.4)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Stress trigger")
                        .italic()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(profile.stressTrigger)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Breaking point")
                        .italic()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(profile.breakingPoint)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !profile.alternatives.isEmpty {
                detailRow(title: "Also close", value: profile.alternatives.prefix(2).joined(separator: " • "))
            }
        }
        .padding(14)
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

    @ViewBuilder
    private func detailRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(title)
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)
            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#Preview {
    NavigationStack {
        AccountPersonalizationView()
            .environmentObject(PersonalizationStore())
    }
}
