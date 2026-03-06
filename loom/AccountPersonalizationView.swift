import SwiftUI
import SwiftData

struct AccountPersonalizationView: View {
    private enum EditorMode: String, Identifiable {
        case edit
        case reset
        var id: String { rawValue }
    }

    @Environment(\.modelContext) private var modelContext
    @EnvironmentObject private var personalizationStore: PersonalizationStore
    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse) private var diagnosticsInsightsSnapshots: [DiagnosticsInsightsSnapshot]
    @Query(sort: \PurposeProfileInsightsSnapshot.generatedAt, order: .reverse) private var purposeProfileInsightsSnapshots: [PurposeProfileInsightsSnapshot]
    @State private var editorMode: EditorMode?
    @State private var selectedHistorySnapshot: PersonalizationSnapshot?
    @State private var isSaving = false
    @State private var isRefreshingDiagnosticsInsights = false
    @State private var diagnosticsInsightsRefreshToken = UUID()

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
                    Text("LifeOS: Connecting the Dots")
                }
            }

            Section("Insights") {
                if let current = personalizationStore.current {
                    VStack(spacing: 12) {
                        if let profileSnapshot = latestPurposeProfileSnapshot {
                            purposeProfileSnapshotCard(profileSnapshot)
                            Text("Personality profile refreshes monthly based on your latest data.")
                                .font(.footnote)
                                .foregroundStyle(.secondary)
                                .frame(maxWidth: .infinity, alignment: .center)
                                .multilineTextAlignment(.center)
                        }

                        PersonalizationInsightsCards(
                            snapshot: current,
                            userKey: personalizationStore.userKey,
                            purposeRefreshCycleKey: latestPurposeProfileSnapshot?.snapshotKey,
                            refreshToken: diagnosticsInsightsRefreshToken,
                            showsInlineLoading: isRefreshingDiagnosticsInsights
                        )

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
        .task {
            await personalizationStore.reloadForCurrentUser()
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

    private func saveDiagnosticDraft(_ draft: PersonalizationDraft, mode: EditorMode) async {
        isSaving = true
        defer {
            isSaving = false
            editorMode = nil
        }

        do {
            let source: PersonalizationSaveSource = mode == .reset ? .accountReset : .accountEdit
            let savedSnapshot = try await personalizationStore.saveSnapshot(from: draft, source: source)
            AppDebugActivityLog.log(
                "Personalization",
                "Edit diagnostic saved. mode=\(mode.rawValue) snapshot=\(savedSnapshot.id.uuidString)"
            )

            let refreshStartedAt = Date()
            isRefreshingDiagnosticsInsights = true
            await refreshInsightsForUpdatedDiagnostic(savedSnapshot)
            let minimumLoadingInterval: TimeInterval = 2.0
            let elapsed = Date().timeIntervalSince(refreshStartedAt)
            if elapsed < minimumLoadingInterval {
                let remainingNanoseconds = UInt64((minimumLoadingInterval - elapsed) * 1_000_000_000)
                try? await Task.sleep(nanoseconds: remainingNanoseconds)
            }
            diagnosticsInsightsRefreshToken = UUID()
            isRefreshingDiagnosticsInsights = false
            AppDebugActivityLog.log("Personalization", "Post-save insights refresh completed")
        } catch {
            // Keep previous values if save fails.
            isRefreshingDiagnosticsInsights = false
            AppDebugActivityLog.log("Personalization", "Edit diagnostic save failed: \(error.localizedDescription)")
        }
    }

    private func refreshInsightsForUpdatedDiagnostic(_ snapshot: PersonalizationSnapshot) async {
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
            if !normalizedRoot.isEmpty, !normalizedNext.isEmpty {
                rootCause = normalizedRoot
                nextDirection = normalizedNext
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
            }
        } catch {
            // Keep fallback diagnostics values.
            AppDebugActivityLog.log("Personalization", "Diagnostic insights refresh failed: \(error.localizedDescription)")
        }

        let currentVision = currentVisionForProfileInsights()
        let currentPassions = currentPassionsForProfileInsights()
        let fallbackRecord = PurposeProfileMatcher.bestMatch(
            inputs: .init(
                stress: diagnostics.stress,
                breakPoint: diagnostics.breaksFirst,
                planning: diagnostics.planningStyle,
                desired: diagnostics.firstChange,
                rootCause: rootCause,
                nextDirection: nextDirection,
                vision: currentVision,
                passions: currentPassions
            )
        )

        let monthKey = PurposeProfileInsightsHasher.monthKey()
        let inputsHash = PurposeProfileInsightsHasher.hash(
            diagnostic: diagnostics,
            rootCause: rootCause,
            nextDirection: nextDirection,
            vision: currentVision,
            passions: currentPassions
        )
        let purposeSnapshotKey = PurposeProfileInsightsHasher.snapshotKey(
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash
        )
        AppDebugActivityLog.log(
            "Personalization",
            "Purpose profile refresh request month=\(monthKey) inputsHash=\(String(inputsHash.prefix(8)))"
        )

        let resolvedRecord: PurposeProfileRecord
        do {
            let response = try await LoomAIService().fetchPurposeProfileInsights(
                diagnostic: diagnostics,
                rootCause: rootCause,
                nextDirection: nextDirection,
                vision: currentVision,
                passions: currentPassions
            )
            resolvedRecord = PurposeProfilesCatalog.record(named: response.profile) ?? PurposeProfileRecord(
                profile: response.profile,
                strength: response.strength,
                weakness: response.weakness,
                stressTrigger: response.stressTrigger,
                breakingPoint: response.breakingPoint
            )
            AppDebugActivityLog.log("Personalization", "Purpose profile refreshed profile=\(resolvedRecord.profile)")
        } catch {
            resolvedRecord = fallbackRecord
            AppDebugActivityLog.log("Personalization", "Purpose profile refresh failed, using fallback profile=\(fallbackRecord.profile)")
        }

        upsertPurposeProfileSnapshot(
            snapshotKey: purposeSnapshotKey,
            userKey: userKey,
            monthKey: monthKey,
            inputsHash: inputsHash,
            record: resolvedRecord
        )

        upsertDiagnosticsInsightsSnapshot(
            snapshotKey: diagnosticsSnapshotKey,
            userKey: userKey,
            diagnosticsHash: diagnosticsHash,
            rootCause: rootCause,
            fulfillmentText: fulfillmentText,
            nextDirection: nextDirection,
            purposeRefreshCycleKey: purposeSnapshotKey
        )
        AppDebugActivityLog.log(
            "Personalization",
            "refreshInsightsForUpdatedDiagnostic completed profileKey=\(purposeSnapshotKey)"
        )
    }

    private func normalizeInsightsBody(_ text: String) -> String {
        text
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func latestDiagnosticsInsightsSnapshot(
        userKey: String,
        diagnosticsHash: String
    ) -> DiagnosticsInsightsSnapshot? {
        diagnosticsInsightsSnapshots.first(where: {
            $0.userKey == userKey && $0.diagnosticsHash == diagnosticsHash
        })
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
        if let existing = purposeProfileInsightsSnapshots.first(where: { $0.snapshotKey == snapshotKey }) {
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

    private var latestPurposeProfileSnapshot: PurposeProfileInsightsSnapshot? {
        let userKey = personalizationStore.userKey
        return purposeProfileInsightsSnapshots.first(where: { $0.userKey == userKey })
    }

    @ViewBuilder
    private func purposeProfileSnapshotCard(_ snapshot: PurposeProfileInsightsSnapshot) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("How Loom sees you (so far)...")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .tracking(0.4)

            Text(snapshot.profile)
                .font(.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)

            detailRow(title: "Strength", value: snapshot.strength)
            detailRow(title: "Weakness", value: snapshot.weakness)

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
                    Text(snapshot.stressTrigger)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text("Breaking point")
                        .italic()
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Text(snapshot.breakingPoint)
                        .font(.subheadline)
                        .fixedSize(horizontal: false, vertical: true)
                }
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
