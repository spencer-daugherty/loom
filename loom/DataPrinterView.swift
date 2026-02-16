import SwiftUI
import SwiftData

// MARK: - Flattened Display Model
struct DataItem: Identifiable, Hashable {
    let id: String
    let source: String
    let content: String
    let date: Date
    let emotion: String?
    let additionalFields: [String: String]

    static func flatten(
        forces: [DrivingForce],
        forceArch: [DrivingForceArchive],
        passions: [Passion],
        passionArch: [PassionArchive],
        fulfillments: [Fulfillment],
        fulfillmentArch: [FulfillmentArchive],
        fulfillmentRoles: [FulfillmentRoles],
        fulfillmentRolesArch: [FulfillmentRolesArchive],
        fulfillmentFocus: [FulfillmentFocus],
        fulfillmentFocusArch: [FulfillmentFocusArchive],
        fulfillmentResources: [FulfillmentResources],
        fulfillmentResourcesArch: [FulfillmentResourcesArchive],
        passionFulfillmentJoins: [PassionFulfillmentJoin],
        passionFulfillmentJoinArch: [PassionFulfillmentJoinArchive],
        outcomes: [Outcomes],
        outcomesArch: [OutcomesArchive],
        outcomesMeasures: [OutcomesMeasure],
        outcomesMeasuresArch: [OutcomesMeasureArchive]
    ) -> [DataItem] {
        var items: [DataItem] = []

        // DrivingForce
        for df in forces {
            let base = df.id.uuidString
            let ts = df.updatedAt

            items.append(.init(
                id: "vision-\(base)",
                source: "Ultimate Vision",
                content: df.ultimateVision,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": df.ultimatePurpose
                ]
            ))

            items.append(.init(
                id: "purpose-\(base)",
                source: "Ultimate Purpose",
                content: df.ultimatePurpose,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": df.ultimateVision
                ]
            ))
        }

        // DrivingForceArchive
        for arch in forceArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "visionArch-\(base)",
                source: "Ultimate Vision (Archived)",
                content: arch.visionSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Purpose": arch.purposeSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))

            items.append(.init(
                id: "purposeArch-\(base)",
                source: "Ultimate Purpose (Archived)",
                content: arch.purposeSnapshot,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Vision": arch.visionSnapshot,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Passion
        for p in passions {
            let base = p.passion_id.uuidString
            items.append(.init(
                id: "passion-\(base)",
                source: "Passion",
                content: p.passion,
                date: p.date,
                emotion: p.emotion,
                additionalFields: [
                    "ID": base
                ]
            ))
        }

        // PassionArchive
        for arch in passionArch {
            let base = arch.id.uuidString
            items.append(.init(
                id: "passionArch-\(base)",
                source: "Passion (Archived)",
                content: arch.passionSnapshot,
                date: arch.archivedAt,
                emotion: arch.emotion,
                additionalFields: [
                    "ID": base,
                    "Updated At": arch.updatedAt.formatted(),
                    "Original Date": arch.date.formatted()
                ]
            ))
        }

        // Fulfillment
        for f in fulfillments {
            let base = f.category_id.uuidString
            let ts = f.updatedAt

            items.append(.init(
                id: "fulfillment-\(base)",
                source: "Fulfillment",
                content: f.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Identity": f.category_identitiy,
                    "Vision": f.category_vision,
                    "Purpose": f.category_purpose
                ]
            ))
        }

        // FulfillmentArchive
        for arch in fulfillmentArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "fulfillmentArch-\(base)",
                source: "Fulfillment (Archived)",
                content: arch.category,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Identity": arch.category_identitiy,
                    "Vision": arch.category_vision,
                    "Purpose": arch.category_purpose,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentRoles
        for role in fulfillmentRoles {
            let base = role.id.uuidString
            let ts = role.updatedAt

            items.append(.init(
                id: "role-\(base)",
                source: "Fulfillment Role",
                content: role.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": role.category_id.uuidString,
                    "Rank": "\(role.rank)"
                ]
            ))
        }

        // FulfillmentRolesArchive
        for arch in fulfillmentRolesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "roleArch-\(base)",
                source: "Fulfillment Role (Archived)",
                content: arch.role,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentFocus
        for focus in fulfillmentFocus {
            let base = focus.id.uuidString
            let ts = focus.updatedAt

            items.append(.init(
                id: "focus-\(base)",
                source: "Fulfillment Focus",
                content: focus.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": focus.category_id.uuidString,
                    "Rank": "\(focus.rank)"
                ]
            ))
        }

        // FulfillmentFocusArchive
        for arch in fulfillmentFocusArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "focusArch-\(base)",
                source: "Fulfillment Focus (Archived)",
                content: arch.activity,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // FulfillmentResources
        for resource in fulfillmentResources {
            let base = resource.id.uuidString
            let ts = resource.updatedAt

            items.append(.init(
                id: "resource-\(base)",
                source: "Fulfillment Resource",
                content: resource.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": resource.category_id.uuidString,
                    "Rank": "\(resource.rank)"
                ]
            ))
        }

        // FulfillmentResourcesArchive
        for arch in fulfillmentResourcesArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "resourceArch-\(base)",
                source: "Fulfillment Resource (Archived)",
                content: arch.resource,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category ID": arch.category_id.uuidString,
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // PassionFulfillmentJoin
        for join in passionFulfillmentJoins {
            let base = join.id.uuidString
            let ts = Date()

            items.append(.init(
                id: "join-\(base)",
                source: "Passion-Fulfillment Join",
                content: "Passion: \(join.passion_id), Category: \(join.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": join.passion_id.uuidString,
                    "Category ID": join.category_id.uuidString
                ]
            ))
        }

        // PassionFulfillmentJoinArchive
        for arch in passionFulfillmentJoinArch {
            let base = arch.id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "joinArch-\(base)",
                source: "Passion-Fulfillment Join (Archived)",
                content: "Passion: \(arch.passion_id), Category: \(arch.category_id)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Passion ID": arch.passion_id.uuidString,
                    "Category ID": arch.category_id.uuidString,
                    "Updated At": arch.updatedAt.formatted()
                ]
            ))
        }

        // Outcomes
        for outcome in outcomes {
            let base = outcome.outcome_id.uuidString
            let ts = outcome.updatedAt

            items.append(.init(
                id: "outcome-\(base)",
                source: "Outcome",
                content: outcome.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": outcome.category,
                    "Reasons": outcome.reasons,
                    "Duration": "\(daysBetween(outcome.start, outcome.end)) days",
                    "Start": outcome.start.formatted(),
                    "End": outcome.end.formatted(),
                    "Rank": "\(outcome.rank)",
                    "Format": outcome.format ?? ""
                ]
            ))
        }

        // OutcomesArchive
        for arch in outcomesArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "outcomeArch-\(base)",
                source: "Outcome (Archived)",
                content: arch.outcome,
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Category": arch.category,
                    "Reasons": arch.reasons,
                    "Duration": "\(daysBetween(arch.start, arch.end)) days",
                    "Start": arch.start.formatted(),
                    "End": arch.end.formatted(),
                    "Rank": "\(arch.rank)",
                    "Updated At": arch.updatedAt.formatted(),
                    "Format": arch.format ?? ""
                ]
            ))
        }

        // OutcomesMeasure
        for measure in outcomesMeasures {
            let base = measure.outcome_id.uuidString
            let ts = measure.measuredAt

            items.append(.init(
                id: "measure-\(base)",
                source: "Outcome Measure",
                content: "\(measure.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(measure.measure_amt)",
                    "Measure Updated": measure.measure_updated.formatted(),
                    "Measured At": measure.measuredAt.formatted(),
                    "Direction": measure.direction ?? "",
                    "Format": measure.format ?? ""
                ]
            ))
        }

        // OutcomesMeasureArchive
        for arch in outcomesMeasuresArch {
            let base = arch.outcome_id.uuidString
            let ts = arch.archivedAt

            items.append(.init(
                id: "measureArch-\(base)",
                source: "Outcome Measure (Archived)",
                content: "\(arch.measure)",
                date: ts,
                emotion: nil,
                additionalFields: [
                    "ID": base,
                    "Measure Amount": "\(arch.measure_amt)",
                    "Measure Updated": arch.measure_updated.formatted(),
                    "Measured At": arch.measuredAt.formatted(),
                    "Updated At": arch.archivedAt.formatted(),
                    "Direction": arch.direction ?? "",
                    "Format": arch.format ?? ""
                ]
            ))
        }

        return items.sorted { $0.date > $1.date }
    }

    private static func daysBetween(_ start: Date, _ end: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: start, to: end)
        return max(0, components.day ?? 0)
    }
}

// MARK: - Filter Model
struct ModelFilter: Identifiable, Hashable {
    let id: String
    let name: String
}

// MARK: - Main View
struct AccountView: View {
    @Environment(\.modelContext) private var context
    @AppStorage("enable_projects_feature") private var enableProjectsFeature = false
    @State private var showingMigrationResultAlert = false
    @State private var migrationResultMessage = ""

    private let legacyArchiveMigrationFlag = "legacy_actionblocks_archive_migration_v2_done"
    private let outcomesRecoveryFlag = "outcomes_archive_recovery_v1_done"

    var body: some View {
        List {
            Section {
                NavigationLink {
                    ManagePeoplePlacesToolsView()
                } label: {
                    HStack {
                        Text("Places, People, and Tools")
                    }
                }

                NavigationLink {
                    CompletedActionBlocksListView()
                } label: {
                    HStack {
                        Text("Completed Action Blocks")
                    }
                }

                NavigationLink {
                    RecentlyDeletedView()
                } label: {
                    HStack {
                        Text("Recently Deleted")
                    }
                }

                NavigationLink {
                    ManageRawDataView()
                } label: {
                    HStack {
                        Text("Manage Raw Data")
                    }
                }
            }

            Section {
                Toggle("Enable Projects", isOn: $enableProjectsFeature)
            }
        }
        .listStyle(.plain)
        .navigationTitle("Account Manager")
        .alert("Legacy Migration", isPresented: $showingMigrationResultAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(migrationResultMessage)
        }
        .onAppear {
            RecentlyDeletedStore.purgeExpired(in: context)
            runLegacyArchiveMigrationIfNeeded()
        }
    }

    /// One-time conservative recovery:
    /// - restores archived outcomes that no longer exist
    /// - restores likely overwritten snapshots (when archived state is not represented in active outcomes)
    /// - restores archived measure snapshots for recovered rows
    private func performOutcomeArchiveRecovery() -> String {
        if UserDefaults.standard.bool(forKey: outcomesRecoveryFlag) {
            return "Outcome recovery already ran for this device. No action taken."
        }

        let activeOutcomes = (try? context.fetch(FetchDescriptor<Outcomes>())) ?? []
        let archivedOutcomes = (try? context.fetch(FetchDescriptor<OutcomesArchive>())) ?? []
        let archivedMeasures = (try? context.fetch(FetchDescriptor<OutcomesMeasureArchive>())) ?? []
        let activeMeasures = (try? context.fetch(FetchDescriptor<OutcomesMeasure>())) ?? []

        guard !archivedOutcomes.isEmpty else {
            UserDefaults.standard.set(true, forKey: outcomesRecoveryFlag)
            return "No archived outcomes found to recover."
        }

        let activeById = Dictionary(uniqueKeysWithValues: activeOutcomes.map { ($0.outcome_id, $0) })
        let activeMeasureById = Dictionary(uniqueKeysWithValues: activeMeasures.map { ($0.outcome_id, $0) })
        let archivedMeasureById = Dictionary(uniqueKeysWithValues: archivedMeasures.map { ($0.outcome_id, $0) })

        func signature(
            category: String,
            outcome: String,
            reasons: String,
            start: Date,
            end: Date
        ) -> String {
            let cal = Calendar.current
            let s = cal.startOfDay(for: start).timeIntervalSince1970
            let e = cal.startOfDay(for: end).timeIntervalSince1970
            return [
                category.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                outcome.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                reasons.trimmingCharacters(in: .whitespacesAndNewlines).lowercased(),
                "\(Int(s))",
                "\(Int(e))"
            ].joined(separator: "|")
        }

        let activeSignatures = Set(
            activeOutcomes.map {
                signature(
                    category: $0.category,
                    outcome: $0.outcome,
                    reasons: $0.reasons,
                    start: $0.start,
                    end: $0.end
                )
            }
        )

        var restoredMissing = 0
        var restoredOverwritten = 0
        var restoredMeasures = 0
        var maxRank = activeOutcomes.map(\.rank).max() ?? 0

        for archived in archivedOutcomes {
            let archivedSignature = signature(
                category: archived.category,
                outcome: archived.outcome,
                reasons: archived.reasons,
                start: archived.start,
                end: archived.end
            )

            let hasSameId = activeById[archived.outcome_id] != nil
            let hasEquivalentActiveState = activeSignatures.contains(archivedSignature)

            // Case 1: archived row id no longer exists -> restore with same id.
            if !hasSameId {
                if !hasEquivalentActiveState {
                    let recovered = Outcomes(
                        outcome_id: archived.outcome_id,
                        category: archived.category,
                        updatedAt: .now,
                        outcome: archived.outcome,
                        reasons: archived.reasons,
                        start: archived.start,
                        end: archived.end,
                        rank: maxRank + 1,
                        format: archived.format
                    )
                    maxRank += 1
                    context.insert(recovered)
                    restoredMissing += 1

                    if let mArch = archivedMeasureById[archived.outcome_id], activeMeasureById[archived.outcome_id] == nil {
                        context.insert(
                            OutcomesMeasure(
                                outcome_id: archived.outcome_id,
                                measure: mArch.measure,
                                measuredAt: mArch.measuredAt,
                                measure_amt: mArch.measure_amt,
                                measure_updated: .now,
                                direction: mArch.direction,
                                format: mArch.format,
                                unit: mArch.unit,
                                decimalPlaces: mArch.decimalPlaces
                            )
                        )
                        restoredMeasures += 1
                    }
                }
                continue
            }

            // Case 2: same id exists but archived snapshot state no longer appears anywhere.
            // Recover as a new outcome (new UUID) to avoid overwriting existing data.
            if hasSameId && !hasEquivalentActiveState {
                let recoveredId = UUID()
                let recovered = Outcomes(
                    outcome_id: recoveredId,
                    category: archived.category,
                    updatedAt: .now,
                    outcome: archived.outcome,
                    reasons: archived.reasons,
                    start: archived.start,
                    end: archived.end,
                    rank: maxRank + 1,
                    format: archived.format
                )
                maxRank += 1
                context.insert(recovered)
                restoredOverwritten += 1

                if let mArch = archivedMeasureById[archived.outcome_id] {
                    context.insert(
                        OutcomesMeasure(
                            outcome_id: recoveredId,
                            measure: mArch.measure,
                            measuredAt: mArch.measuredAt,
                            measure_amt: mArch.measure_amt,
                            measure_updated: .now,
                            direction: mArch.direction,
                            format: mArch.format,
                            unit: mArch.unit,
                            decimalPlaces: mArch.decimalPlaces
                        )
                    )
                    restoredMeasures += 1
                }
            }
        }

        try? context.save()
        UserDefaults.standard.set(true, forKey: outcomesRecoveryFlag)

        if restoredMissing == 0 && restoredOverwritten == 0 {
            return "No recoverable overwritten/missing outcomes were found."
        }

        return "Recovered \(restoredMissing + restoredOverwritten) outcome(s) (\(restoredMissing) missing, \(restoredOverwritten) overwritten-candidate) and \(restoredMeasures) measure snapshot(s)."
    }

    /// Rebuilds ActionView source rows (planned chunks/actions + key state) from archived reflection snapshots.
    /// Recovery is performed only for weeks that currently have no PlannedChunkAction rows.
    private func performActionBlocksRecoveryFromArchiveSnapshots() -> String {
        let calendar = Calendar.current

        let archives = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())) ?? []
        guard !archives.isEmpty else { return "No Action Block archives found to recover from." }

        let archivedActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
        guard !archivedActions.isEmpty else { return "No archived Action Block actions found to recover." }

        let archivedOutcomes = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveOutcome>())) ?? []
        let existingActions = (try? context.fetch(FetchDescriptor<PlannedChunkAction>())) ?? []
        let existingChunks = (try? context.fetch(FetchDescriptor<PlannedChunk>())) ?? []
        let existingStep4 = (try? context.fetch(FetchDescriptor<PlannedChunkStepFourState>())) ?? []
        let existingLinks = (try? context.fetch(FetchDescriptor<PlannedChunkOutcomeLink>())) ?? []
        let existingDefine = (try? context.fetch(FetchDescriptor<PlannedChunkActionDefineState>())) ?? []
        let existingExec = (try? context.fetch(FetchDescriptor<PlannedChunkActionExecutionState>())) ?? []

        let weeksWithActiveActions = Set(existingActions.map { dayKey($0.weekStart, calendar: calendar) })
        let actionsByArchive = Dictionary(grouping: archivedActions, by: \.archiveId)
        let outcomesByArchive = Dictionary(grouping: archivedOutcomes, by: \.archiveId)

        var usedChunkIDs = Set(existingChunks.map(\.id))
        var usedActionIDs = Set(existingActions.map(\.id))
        var restoredWeeks = 0
        var restoredChunks = 0
        var restoredActions = 0
        var restoredOutcomes = 0
        var lastRecoveredWeek: Date?

        for archive in archives.sorted(by: { $0.completedAt > $1.completedAt }) {
            let weekKey = dayKey(archive.weekStart, calendar: calendar)
            if weeksWithActiveActions.contains(weekKey) { continue }

            let rows = actionsByArchive[archive.id] ?? []
            if rows.isEmpty { continue }

            let weekStart = archive.weekStart
            lastRecoveredWeek = weekStart

            // Chunk mapping (archived chunk id -> recovered chunk id/index)
            let chunkGroups = Dictionary(grouping: rows, by: \.plannedChunkId)
            let orderedChunkIDs = chunkGroups.keys.sorted {
                let lhs = chunkGroups[$0]?.first?.chunkLabel ?? ""
                let rhs = chunkGroups[$1]?.first?.chunkLabel ?? ""
                if lhs == rhs { return $0.uuidString < $1.uuidString }
                return lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
            }

            var chunkMap: [UUID: (id: UUID, index: Int)] = [:]

            for (idx, archivedChunkID) in orderedChunkIDs.enumerated() {
                guard let first = chunkGroups[archivedChunkID]?.first else { continue }
                var recoveredChunkID = archivedChunkID
                if usedChunkIDs.contains(recoveredChunkID) {
                    recoveredChunkID = UUID()
                }
                usedChunkIDs.insert(recoveredChunkID)

                let chunk = PlannedChunk(
                    id: recoveredChunkID,
                    weekStart: weekStart,
                    chunkIndex: idx,
                    labelId: UUID(),
                    label: first.chunkLabel,
                    categoryId: UUID(),
                    category: first.chunkCategory
                )
                context.insert(chunk)
                chunkMap[archivedChunkID] = (recoveredChunkID, idx)
                restoredChunks += 1
            }

            // Step 4 restore per chunk from first archived row values.
            for archivedChunkID in orderedChunkIDs {
                guard
                    let mapped = chunkMap[archivedChunkID],
                    let first = chunkGroups[archivedChunkID]?.first
                else { continue }

                let chunkKey = "\(dayKey(weekStart, calendar: calendar))|\(mapped.id.uuidString)"
                if existingStep4.contains(where: { $0.weekPlannedChunkKey == chunkKey }) { continue }

                let row = PlannedChunkStepFourState(
                    weekStart: weekStart,
                    plannedChunkId: mapped.id,
                    resultText: first.resultText ?? "",
                    roleNoteText: first.purposeText ?? "",
                    connectedRoleId: nil
                )
                context.insert(row)
            }

            // Action + define/execution restore.
            for archivedChunkID in orderedChunkIDs {
                guard let mapped = chunkMap[archivedChunkID] else { continue }
                let chunkRows = (chunkGroups[archivedChunkID] ?? []).sorted {
                    if $0.actionText == $1.actionText { return $0.id.uuidString < $1.id.uuidString }
                    return $0.actionText.localizedCaseInsensitiveCompare($1.actionText) == .orderedAscending
                }

                for (order, row) in chunkRows.enumerated() {
                    var actionID = row.plannedChunkActionId
                    if usedActionIDs.contains(actionID) {
                        actionID = UUID()
                    }
                    usedActionIDs.insert(actionID)

                    let action = PlannedChunkAction(
                        id: actionID,
                        weekStart: weekStart,
                        chunkIndex: mapped.index,
                        plannedChunkId: mapped.id,
                        text: row.actionText,
                        sortOrder: order
                    )
                    context.insert(action)
                    restoredActions += 1

                    let defineKey = "\(dayKey(weekStart, calendar: calendar))|\(actionID.uuidString)"
                    if !existingDefine.contains(where: { $0.weekActionKey == defineKey }) {
                        context.insert(
                            PlannedChunkActionDefineState(
                                weekStart: weekStart,
                                plannedChunkActionId: actionID,
                                rank: order,
                                isMust: row.isMust,
                                timeEstimateMinutes: row.durationMinutes
                            )
                        )
                    }

                    if !existingExec.contains(where: { $0.weekActionKey == defineKey }) {
                        context.insert(
                            PlannedChunkActionExecutionState(
                                weekStart: weekStart,
                                plannedChunkActionId: actionID,
                                statusRaw: row.statusRaw
                            )
                        )
                    }
                }
            }

            // Restore chunk-outcome links.
            for row in outcomesByArchive[archive.id] ?? [] {
                guard let mapped = chunkMap[row.plannedChunkId] else { continue }
                let linkKey = "\(dayKey(weekStart, calendar: calendar))|\(mapped.id.uuidString)|\(row.outcomeId.uuidString)"
                if existingLinks.contains(where: { $0.weekChunkOutcomeKey == linkKey }) { continue }
                context.insert(
                    PlannedChunkOutcomeLink(
                        weekStart: weekStart,
                        plannedChunkId: mapped.id,
                        outcomeId: row.outcomeId
                    )
                )
                restoredOutcomes += 1
            }

            restoredWeeks += 1
        }

        guard restoredWeeks > 0 else {
            return "No recoverable Action Block weeks were found. Existing weeks already have active actions or no archive snapshots exist."
        }

        if let lastRecoveredWeek {
            let state = ActivePlanState.fetchOrCreate(in: context)
            state.isActive = true
            state.weekStart = lastRecoveredWeek
            state.activatedAt = .now
        }

        try? context.save()
        return "Recovered \(restoredWeeks) week(s), \(restoredChunks) chunk(s), \(restoredActions) action(s), and \(restoredOutcomes) outcome link(s) from archived Action Blocks."
    }

    private func runLegacyArchiveMigrationIfNeeded() {
        guard UserDefaults.standard.bool(forKey: legacyArchiveMigrationFlag) == false else { return }

        let result = performLegacyArchiveMigration()
        UserDefaults.standard.set(true, forKey: legacyArchiveMigrationFlag)
        migrationResultMessage = result
        showingMigrationResultAlert = true
    }

    /// One-time backfill:
    /// - Finds weeks with planned actions but no reflection archive
    /// - Enriches existing reflection archive action rows with result/purpose from Step 4 state
    /// - Migrates only weeks where all actions are in a closed status
    /// - Creates ActionBlocksReflectionArchive + action/outcome snapshot rows
    private func performLegacyArchiveMigration() -> String {
        let calendar = Calendar.current
        let closed: Set<ActionExecutionStatus> = [.done, .carriedToCapture, .notNeeded]

        let actions = (try? context.fetch(FetchDescriptor<PlannedChunkAction>())) ?? []
        guard !actions.isEmpty else { return "No legacy action-block rows found." }

        let chunks = (try? context.fetch(FetchDescriptor<PlannedChunk>())) ?? []
        let defineStates = (try? context.fetch(FetchDescriptor<PlannedChunkActionDefineState>())) ?? []
        let executionStates = (try? context.fetch(FetchDescriptor<PlannedChunkActionExecutionState>())) ?? []
        let leverageSelections = (try? context.fetch(FetchDescriptor<PlannedChunkActionLeverageSelection>())) ?? []
        let resources = (try? context.fetch(FetchDescriptor<LeverageResource>())) ?? []
        let placeLinks = (try? context.fetch(FetchDescriptor<PlannedChunkActionSensitivityPlaceLink>())) ?? []
        let placeCatalog = (try? context.fetch(FetchDescriptor<SensitivityPlaceCatalogItem>())) ?? []
        let notes = (try? context.fetch(FetchDescriptor<PlannedChunkActionNote>())) ?? []
        let attachments = (try? context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())) ?? []
        let outcomeLinks = (try? context.fetch(FetchDescriptor<PlannedChunkOutcomeLink>())) ?? []
        let stepFourStates = (try? context.fetch(FetchDescriptor<PlannedChunkStepFourState>())) ?? []
        let outcomes = (try? context.fetch(FetchDescriptor<Outcomes>())) ?? []
        let existingArchives = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())) ?? []
        let existingReflectionActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []

        let archiveWeekKeys = Set(existingArchives.map { dayKey($0.weekStart, calendar: calendar) })

        let resourceById = Dictionary(uniqueKeysWithValues: resources.map { ($0.id, $0) })
        let placeById = Dictionary(uniqueKeysWithValues: placeCatalog.map { ($0.id, $0) })
        let chunkById = Dictionary(uniqueKeysWithValues: chunks.map { ($0.id, $0) })
        let outcomeById = Dictionary(uniqueKeysWithValues: outcomes.map { ($0.outcome_id, $0) })

        let defineByAction = latestByActionId(defineStates) { $0.plannedChunkActionId } newer: { $0.updatedAt < $1.updatedAt }
        let executionByAction = latestByActionId(executionStates) { $0.plannedChunkActionId } newer: { $0.updatedAt < $1.updatedAt }
        let leverageByAction = latestByActionId(leverageSelections) { $0.plannedChunkActionId } newer: { $0.updatedAt < $1.updatedAt }
        let noteByAction = latestByActionId(notes) { $0.plannedChunkActionId } newer: { $0.updatedAt < $1.updatedAt }

        let placeLinksByAction = Dictionary(grouping: placeLinks, by: \.plannedChunkActionId)
        let attachmentsByAction = Dictionary(grouping: attachments, by: \.plannedChunkActionId)
        let outcomeLinksByWeek = Dictionary(grouping: outcomeLinks, by: { dayKey($0.weekStart, calendar: calendar) })
        let stepFourByWeekChunk: [String: PlannedChunkStepFourState] = {
            var map: [String: PlannedChunkStepFourState] = [:]
            for row in stepFourStates {
                let key = "\(dayKey(row.weekStart, calendar: calendar))|\(row.plannedChunkId.uuidString)"
                if let existing = map[key] {
                    if row.updatedAt > existing.updatedAt { map[key] = row }
                } else {
                    map[key] = row
                }
            }
            return map
        }()

        var enrichedExistingActions = 0
        for archiveAction in existingReflectionActions {
            let key = "\(dayKey(archiveAction.weekStart, calendar: calendar))|\(archiveAction.plannedChunkId.uuidString)"
            guard let step4 = stepFourByWeekChunk[key] else { continue }
            let incomingResult = step4.resultText.trimmingCharacters(in: .whitespacesAndNewlines)
            let incomingPurpose = step4.roleNoteText.trimmingCharacters(in: .whitespacesAndNewlines)

            let hasResult = !((archiveAction.resultText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            let hasPurpose = !((archiveAction.purposeText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

            var changed = false
            if !hasResult, !incomingResult.isEmpty {
                archiveAction.resultText = incomingResult
                changed = true
            }
            if !hasPurpose, !incomingPurpose.isEmpty {
                archiveAction.purposeText = incomingPurpose
                changed = true
            }
            if changed { enrichedExistingActions += 1 }
        }

        let actionsByWeek = Dictionary(grouping: actions, by: { dayKey($0.weekStart, calendar: calendar) })
        var migratedWeeks = 0
        var migratedActions = 0
        var migratedOutcomes = 0

        for (weekKey, weekActions) in actionsByWeek {
            if archiveWeekKeys.contains(weekKey) { continue }
            guard let firstAction = weekActions.first else { continue }

            let isFullyClosed = weekActions.allSatisfy { action in
                let status = executionByAction[action.id]?.status ?? .noAction
                return closed.contains(status)
            }
            if !isFullyClosed { continue }

            let startedAt = weekActions.map(\.createdAt).min() ?? firstAction.weekStart
            let completedAt = weekActions.compactMap { executionByAction[$0.id]?.updatedAt }.max() ?? startedAt

            let archive = ActionBlocksReflectionArchive(
                weekStart: firstAction.weekStart,
                startedAt: startedAt,
                completedAt: completedAt,
                achievementsText: "(Migrated legacy data)",
                magicMomentsText: "",
                powerQuestionText: ""
            )
            context.insert(archive)
            migratedWeeks += 1

            for action in weekActions {
                let define = defineByAction[action.id]
                let execution = executionByAction[action.id]
                let leverage = leverageByAction[action.id]
                let resource = leverage.flatMap { $0.resourceId.flatMap { resourceById[$0] } }
                let places = (placeLinksByAction[action.id] ?? []).compactMap { placeById[$0.placeId]?.place }
                let note = noteByAction[action.id]
                let filesAndLinks = attachmentsByAction[action.id] ?? []
                let chunk = chunkById[action.plannedChunkId]
                let step4 = stepFourByWeekChunk["\(weekKey)|\(action.plannedChunkId.uuidString)"]

                context.insert(
                    ActionBlocksReflectionArchiveAction(
                        archiveId: archive.id,
                        weekStart: firstAction.weekStart,
                        plannedChunkId: action.plannedChunkId,
                        plannedChunkActionId: action.id,
                        chunkLabel: chunk?.label ?? "",
                        chunkCategory: chunk?.category ?? "",
                        resultText: step4?.resultText,
                        purposeText: step4?.roleNoteText,
                        actionText: action.text,
                        statusRaw: (execution?.status ?? .noAction).rawValue,
                        isMust: define?.isMust ?? false,
                        durationMinutes: define?.timeEstimateMinutes,
                        leverageKindRaw: resource?.kind.rawValue,
                        leverageValue: resource?.value,
                        placeNamesCSV: places.joined(separator: ", "),
                        hasNote: !(note?.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ?? true),
                        linkAttachmentCount: filesAndLinks.filter { $0.kind == .link }.count,
                        fileAttachmentCount: filesAndLinks.filter { $0.kind == .file }.count
                    )
                )
                migratedActions += 1
            }

            for link in outcomeLinksByWeek[weekKey] ?? [] {
                guard let outcome = outcomeById[link.outcomeId] else { continue }
                context.insert(
                    ActionBlocksReflectionArchiveOutcome(
                        archiveId: archive.id,
                        weekStart: firstAction.weekStart,
                        plannedChunkId: link.plannedChunkId,
                        outcomeId: link.outcomeId,
                        outcomeText: outcome.outcome,
                        category: outcome.category
                    )
                )
                migratedOutcomes += 1
            }
        }

        try? context.save()

        if migratedWeeks == 0 && enrichedExistingActions == 0 {
            return "Migration complete. No eligible legacy completed weeks or missing result/purpose fields were found."
        }
        return "Migrated \(migratedWeeks) week(s), \(migratedActions) action snapshots, and \(migratedOutcomes) outcome links. Enriched \(enrichedExistingActions) archived action rows with result/purpose."
    }

    private func dayKey(_ date: Date, calendar: Calendar) -> String {
        let comps = calendar.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }

    private func latestByActionId<Row, ID: Hashable>(
        _ rows: [Row],
        id: (Row) -> ID,
        newer: (Row, Row) -> Bool
    ) -> [ID: Row] {
        var map: [ID: Row] = [:]
        for row in rows {
            let key = id(row)
            if let existing = map[key], newer(existing, row) == false {
                continue
            }
            map[key] = row
        }
        return map
    }
}

struct RecentlyDeletedView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \RecentlyDeletedItem.deletedAt, order: .reverse) private var items: [RecentlyDeletedItem]
    @State private var showRecoverFailedAlert = false
    private var visibleItems: [RecentlyDeletedItem] {
        items.filter {
            $0.entityType != "OutcomesMeasure" &&
            $0.entityType != "OutcomesMeasureEntry" &&
            $0.entityType != "ActionBlocksReflectionOutcomeContribution"
        }
    }

    var body: some View {
        List {
            Section {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Items remain here for 30 days, then are permanently deleted.")
                            .font(.footnote)
                            .foregroundStyle(.red)
                            .lineLimit(1)
                            .minimumScaleFactor(0.92)
                        Spacer(minLength: 0)
                    }
                    Text("Swipe right to recover and left to delete permanently.")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }

            Section {
                if visibleItems.isEmpty {
                    Text("No recently deleted items.")
                        .foregroundStyle(.secondary)
                } else {
                    ForEach(visibleItems) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.titleText)
                                .font(.body)
                            Text(item.subtitleText)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            HStack {
                                Text("Deleted \(item.deletedAt, format: .dateTime.month().day().year().hour().minute())")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                                Spacer(minLength: 8)
                                Text("Deletes in \(max(0, Calendar.current.dateComponents([.day], from: .now, to: item.purgeAt).day ?? 0))d")
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .foregroundStyle(.red)
                            }
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button("Detele Permanently", role: .destructive) {
                                RecentlyDeletedStore.permanentlyDelete(item, in: context)
                                try? context.save()
                            }
                            .tint(.red)
                        }
                        .swipeActions(edge: .leading, allowsFullSwipe: true) {
                            Button("Recover") {
                                if RecentlyDeletedStore.restore(item, in: context) {
                                    try? context.save()
                                } else {
                                    showRecoverFailedAlert = true
                                }
                            }
                            .tint(.blue)
                        }
                    }
                }
            }
        }
        .navigationTitle("Recently Deleted")
        .alert("Recovery Not Available", isPresented: $showRecoverFailedAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This item cannot be automatically recovered yet.")
        }
        .onAppear {
            RecentlyDeletedStore.purgeExpired(in: context)
        }
    }
}

struct ManagePeoplePlacesToolsView: View {
    @Environment(\.modelContext) private var context

    @Query(sort: \SensitivityPlaceCatalogItem.place, order: .forward)
    private var allPlaces: [SensitivityPlaceCatalogItem]
    @Query(sort: \LeverageResource.createdAt, order: .forward)
    private var allResources: [LeverageResource]

    @State private var addingPlace = false
    @State private var addingResource = false
    @State private var placeInput = ""
    @State private var resourceInput = ""
    @State private var resourceKind: ActionLeverageKind = .person
    @FocusState private var focusedEntry: EntryFocus?

    private enum EntryFocus: Hashable {
        case place
        case resource
    }

    private var combinedResources: [LeverageResource] {
        allResources
            .sorted { $0.value.localizedCaseInsensitiveCompare($1.value) == .orderedAscending }
    }

    private var isEditingResource: Bool {
        focusedEntry == .resource && addingResource
    }

    var body: some View {
        List {
            Section("Places") {
                if addingPlace {
                    TextField("New Place", text: $placeInput)
                        .submitLabel(.done)
                        .focused($focusedEntry, equals: .place)
                        .onSubmit { savePlace() }
                } else {
                    Button("+ New Place") {
                        addingPlace = true
                        placeInput = ""
                        focusedEntry = .place
                    }
                    .foregroundStyle(.blue)
                }

                ForEach(allPlaces) { place in
                    Text(place.place)
                }
                .onDelete(perform: deletePlaces)
            }

            Section("People and Tools") {
                if addingResource {
                    TextField(resourceKind == .person ? "New Person" : "New Tool", text: $resourceInput)
                        .submitLabel(.done)
                        .focused($focusedEntry, equals: .resource)
                        .onSubmit { saveResource() }
                } else {
                    Button("+ New Person or Tool") {
                        addingResource = true
                        resourceInput = ""
                        resourceKind = .person
                        focusedEntry = .resource
                    }
                    .foregroundStyle(.blue)
                }

                ForEach(combinedResources) { item in
                    HStack {
                        Text(item.value)
                        Spacer()
                        Text(item.kind.title)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .onDelete(perform: deleteResources)
            }
        }
        .listStyle(.insetGrouped)
        .safeAreaPadding(.bottom, isEditingResource ? 72 : 0)
        .navigationTitle("Places, People, and Tools")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: focusedEntry) { _, newValue in
            if newValue != .place && addingPlace {
                addingPlace = false
                placeInput = ""
            }
            if newValue != .resource && addingResource {
                addingResource = false
                resourceInput = ""
            }
        }
        .toolbar {
            ToolbarItemGroup(placement: .keyboard) {
                if isEditingResource {
                    VStack(spacing: 0) {
                        Picker("Type", selection: $resourceKind) {
                            Text("Person").tag(ActionLeverageKind.person)
                            Text("Tool").tag(ActionLeverageKind.tool)
                        }
                        .pickerStyle(.segmented)
                        .frame(maxWidth: .infinity)
                        .padding(.horizontal, 8)

                        Color.clear
                            .frame(height: 10)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
        }
    }

    private func savePlace() {
        let trimmed = placeInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingPlace = false
            return
        }

        let normalized = trimmed.lowercased()
        guard !allPlaces.contains(where: { $0.place.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) else {
            addingPlace = false
            placeInput = ""
            return
        }

        context.insert(SensitivityPlaceCatalogItem(place: trimmed))
        try? context.save()
        addingPlace = false
        placeInput = ""
    }

    private func saveResource() {
        let trimmed = resourceInput.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            addingResource = false
            return
        }

        let normalized = trimmed.lowercased()
        let existing = allResources.contains {
            $0.kind == resourceKind &&
            $0.value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized
        }
        guard !existing else {
            addingResource = false
            resourceInput = ""
            return
        }

        context.insert(LeverageResource(kindRaw: resourceKind.rawValue, value: trimmed))
        try? context.save()
        addingResource = false
        resourceInput = ""
    }

    private func deletePlaces(at offsets: IndexSet) {
        for index in offsets {
            context.delete(allPlaces[index])
        }
        try? context.save()
    }

    private func deleteResources(at offsets: IndexSet) {
        for index in offsets {
            context.delete(combinedResources[index])
        }
        try? context.save()
    }
}

struct ManageRawDataView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.editMode) private var editMode
    @State private var selection = Set<String>()
    @State private var showingDeleteAlert = false
    @State private var showingFilterSheet = false
    @State private var selectedFilters = Set<String>()
    @State private var showDeveloperData = false

    private let availableFilters: [ModelFilter] = [
        .init(id: "vision", name: "Ultimate Vision"),
        .init(id: "purpose", name: "Ultimate Purpose"),
        .init(id: "visionArch", name: "Ultimate Vision (Archived)"),
        .init(id: "purposeArch", name: "Ultimate Purpose (Archived)"),
        .init(id: "passion", name: "Passion"),
        .init(id: "passionArch", name: "Passion (Archived)"),
        .init(id: "fulfillment", name: "Fulfillment"),
        .init(id: "fulfillmentArch", name: "Fulfillment (Archived)"),
        .init(id: "role", name: "Fulfillment Role"),
        .init(id: "roleArch", name: "Fulfillment Role (Archived)"),
        .init(id: "focus", name: "Fulfillment Focus"),
        .init(id: "focusArch", name: "Fulfillment Focus (Archived)"),
        .init(id: "resource", name: "Fulfillment Resource"),
        .init(id: "resourceArch", name: "Fulfillment Resource (Archived)"),
        .init(id: "join", name: "Passion-Fulfillment Join"),
        .init(id: "joinArch", name: "Passion-Fulfillment Join (Archived)"),
        .init(id: "outcome", name: "Outcome"),
        .init(id: "outcomeArch", name: "Outcome (Archived)"),
        .init(id: "measure", name: "Outcome Measure"),
        .init(id: "measureArch", name: "Outcome Measure (Archived)"),
        .init(id: "weekly", name: "Weekly Mindset Entry"),
        .init(id: "activePlan", name: "Active Plan State"),
        .init(id: "capture", name: "Rolling Capture Item"),
        .init(id: "quickCapture", name: "Quick Completed Capture"),
        .init(id: "planLabel", name: "Plan Label"),
        .init(id: "planSelect", name: "Plan Chunk Selection"),
        .init(id: "chunk", name: "Planned Chunk"),
        .init(id: "chunkAction", name: "Planned Chunk Action"),
        .init(id: "step4", name: "Step 4 Chunk State"),
        .init(id: "chunkOutcome", name: "Step 4 Outcome Link"),
        .init(id: "define", name: "Define State"),
        .init(id: "exec", name: "Execution State"),
        .init(id: "leverageRes", name: "Leverage Resource"),
        .init(id: "leverageSel", name: "Leverage Selection"),
        .init(id: "placeCatalog", name: "Place Catalog"),
        .init(id: "placeLink", name: "Place Link"),
        .init(id: "actionNote", name: "Action Note"),
        .init(id: "actionAttachment", name: "Action Attachment"),
        .init(id: "legacyLeverage", name: "Legacy Leverage Item"),
        .init(id: "legacyPlace", name: "Legacy Sensitivity Place"),
        .init(id: "adhoc", name: "Action Ad Hoc Marker"),
        .init(id: "reflect", name: "Reflection Archive"),
        .init(id: "reflectAction", name: "Reflection Archive Action"),
        .init(id: "reflectOutcome", name: "Reflection Archive Outcome"),
    ]

    private let developerFilterIDs: Set<String> = [
        "join",
        "joinArch",
        "activePlan",
        "planLabel",
        "planSelect",
        "chunkOutcome",
        "leverageSel",
        "placeLink",
        "adhoc",
    ]

    @Query(sort: \DrivingForce.updatedAt, order: .reverse) private var drivingForces: [DrivingForce]
    @Query(sort: \DrivingForceArchive.archivedAt, order: .reverse) private var drivingForceArchives: [DrivingForceArchive]
    @Query(sort: \Passion.date, order: .forward) private var passions: [Passion]
    @Query(sort: \PassionArchive.archivedAt, order: .forward) private var passionArchives: [PassionArchive]
    @Query(sort: \Fulfillment.updatedAt, order: .reverse) private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentArchive.archivedAt, order: .reverse) private var fulfillmentArchives: [FulfillmentArchive]
    @Query(sort: \FulfillmentRoles.updatedAt, order: .reverse) private var fulfillmentRoles: [FulfillmentRoles]
    @Query(sort: \FulfillmentRolesArchive.archivedAt, order: .reverse) private var fulfillmentRolesArchives: [FulfillmentRolesArchive]
    @Query(sort: \FulfillmentFocus.updatedAt, order: .reverse) private var fulfillmentFocus: [FulfillmentFocus]
    @Query(sort: \FulfillmentFocusArchive.archivedAt, order: .reverse) private var fulfillmentFocusArchives: [FulfillmentFocusArchive]
    @Query(sort: \FulfillmentResources.updatedAt, order: .reverse) private var fulfillmentResources: [FulfillmentResources]
    @Query(sort: \FulfillmentResourcesArchive.archivedAt, order: .reverse) private var fulfillmentResourcesArchives: [FulfillmentResourcesArchive]
    @Query(sort: \PassionFulfillmentJoin.id, order: .forward) private var passionFulfillmentJoins: [PassionFulfillmentJoin]
    @Query(sort: \PassionFulfillmentJoinArchive.archivedAt, order: .forward) private var passionFulfillmentJoinArchives: [PassionFulfillmentJoinArchive]
    @Query(sort: \Outcomes.updatedAt, order: .reverse) private var outcomes: [Outcomes]
    @Query(sort: \OutcomesArchive.archivedAt, order: .reverse) private var outcomesArchives: [OutcomesArchive]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .reverse) private var outcomesMeasures: [OutcomesMeasure]
    @Query(sort: \OutcomesMeasureArchive.archivedAt, order: .reverse) private var outcomesMeasuresArchives: [OutcomesMeasureArchive]

    @Query(sort: \WeeklyMindsetEntry.Fields.createdAt, order: .reverse) private var weeklyEntries: [WeeklyMindsetEntry.Fields]
    @Query(sort: \ActivePlanState.id, order: .forward) private var activePlanStates: [ActivePlanState]
    @Query(sort: \RollingCaptureItem.createdAt, order: .reverse) private var rollingCapture: [RollingCaptureItem]
    @Query(sort: \QuickCompletedCaptureItem.completedAt, order: .reverse) private var quickCompletedCapture: [QuickCompletedCaptureItem]
    @Query(sort: \PlanLabel.label, order: .forward) private var planLabels: [PlanLabel]
    @Query(sort: \PlanChunkSelection.updatedAt, order: .reverse) private var planSelections: [PlanChunkSelection]
    @Query(sort: \PlannedChunk.updatedAt, order: .reverse) private var plannedChunks: [PlannedChunk]
    @Query(sort: \PlannedChunkAction.createdAt, order: .reverse) private var plannedActions: [PlannedChunkAction]
    @Query(sort: \PlannedChunkStepFourState.updatedAt, order: .reverse) private var stepFourStates: [PlannedChunkStepFourState]
    @Query(sort: \PlannedChunkOutcomeLink.createdAt, order: .reverse) private var chunkOutcomeLinks: [PlannedChunkOutcomeLink]
    @Query(sort: \PlannedChunkActionDefineState.updatedAt, order: .reverse) private var defineStates: [PlannedChunkActionDefineState]
    @Query(sort: \PlannedChunkActionExecutionState.updatedAt, order: .reverse) private var executionStates: [PlannedChunkActionExecutionState]
    @Query(sort: \LeverageResource.createdAt, order: .reverse) private var leverageResources: [LeverageResource]
    @Query(sort: \PlannedChunkActionLeverageSelection.updatedAt, order: .reverse) private var leverageSelections: [PlannedChunkActionLeverageSelection]
    @Query(sort: \SensitivityPlaceCatalogItem.createdAt, order: .reverse) private var placeCatalog: [SensitivityPlaceCatalogItem]
    @Query(sort: \PlannedChunkActionSensitivityPlaceLink.createdAt, order: .reverse) private var placeLinks: [PlannedChunkActionSensitivityPlaceLink]
    @Query(sort: \PlannedChunkActionNote.updatedAt, order: .reverse) private var actionNotes: [PlannedChunkActionNote]
    @Query(sort: \PlannedChunkActionAttachment.createdAt, order: .reverse) private var actionAttachments: [PlannedChunkActionAttachment]
    @Query(sort: \PlannedChunkActionLeverageItem.createdAt, order: .reverse) private var legacyLeverageItems: [PlannedChunkActionLeverageItem]
    @Query(sort: \PlannedChunkActionSensitivityPlace.createdAt, order: .reverse) private var legacyPlaces: [PlannedChunkActionSensitivityPlace]
    @Query(sort: \PlannedChunkActionAdHocMarker.createdAt, order: .reverse) private var adHocMarkers: [PlannedChunkActionAdHocMarker]
    @Query(sort: \ActionBlocksReflectionArchive.savedAt, order: .reverse) private var reflections: [ActionBlocksReflectionArchive]
    @Query(sort: \ActionBlocksReflectionArchiveAction.weekStart, order: .reverse) private var reflectionActions: [ActionBlocksReflectionArchiveAction]
    @Query(sort: \ActionBlocksReflectionArchiveOutcome.weekStart, order: .reverse) private var reflectionOutcomes: [ActionBlocksReflectionArchiveOutcome]

    private var items: [DataItem] {
        var allItems = DataItem.flatten(
            forces: drivingForces,
            forceArch: drivingForceArchives,
            passions: passions,
            passionArch: passionArchives,
            fulfillments: fulfillments,
            fulfillmentArch: fulfillmentArchives,
            fulfillmentRoles: fulfillmentRoles,
            fulfillmentRolesArch: fulfillmentRolesArchives,
            fulfillmentFocus: fulfillmentFocus,
            fulfillmentFocusArch: fulfillmentFocusArchives,
            fulfillmentResources: fulfillmentResources,
            fulfillmentResourcesArch: fulfillmentResourcesArchives,
            passionFulfillmentJoins: passionFulfillmentJoins,
            passionFulfillmentJoinArch: passionFulfillmentJoinArchives,
            outcomes: outcomes,
            outcomesArch: outcomesArchives,
            outcomesMeasures: outcomesMeasures,
            outcomesMeasuresArch: outcomesMeasuresArchives
        )

        allItems += weeklyEntries.map {
            DataItem(
                id: "weekly-\($0.id.uuidString)",
                source: "Weekly Mindset Entry",
                content: $0.morningPowerQuestion,
                date: $0.createdAt,
                emotion: nil,
                additionalFields: ["Gratitude": $0.gratitude, "Incantation": $0.incantation, "Week Start": $0.weekStart.formatted()]
            )
        }
        allItems += activePlanStates.map {
            DataItem(
                id: "activePlan-\($0.id.uuidString)",
                source: "Active Plan State",
                content: $0.isActive ? "Active" : "Inactive",
                date: $0.activatedAt ?? .distantPast,
                emotion: nil,
                additionalFields: ["Week Start": $0.weekStart?.formatted() ?? ""]
            )
        }
        allItems += rollingCapture.map {
            DataItem(id: "capture-\($0.id.uuidString)", source: "Rolling Capture Item", content: $0.text, date: $0.createdAt, emotion: nil, additionalFields: ["Ghost": "\($0.isGhost)"])
        }
        allItems += quickCompletedCapture.map {
            DataItem(id: "quickCapture-\($0.id.uuidString)", source: "Quick Completed Capture", content: $0.text, date: $0.completedAt, emotion: nil, additionalFields: [:])
        }
        allItems += planLabels.map {
            DataItem(id: "planLabel-\($0.labelId.uuidString)", source: "Plan Label", content: $0.label, date: .now, emotion: nil, additionalFields: ["Category": $0.category, "Source": $0.source])
        }
        allItems += planSelections.map {
            DataItem(id: "planSelect-\($0.id.uuidString)", source: "Plan Chunk Selection", content: $0.label ?? "(none)", date: $0.updatedAt, emotion: nil, additionalFields: ["Chunk": "\($0.chunkIndex)", "Category": $0.category ?? ""])
        }
        allItems += plannedChunks.map {
            DataItem(id: "chunk-\($0.id.uuidString)", source: "Planned Chunk", content: $0.label, date: $0.updatedAt, emotion: nil, additionalFields: ["Category": $0.category, "Index": "\($0.chunkIndex)"])
        }
        allItems += plannedActions.map {
            DataItem(id: "chunkAction-\($0.id.uuidString)", source: "Planned Chunk Action", content: $0.text, date: $0.createdAt, emotion: nil, additionalFields: ["Chunk Index": "\($0.chunkIndex)", "Sort": "\($0.sortOrder)"])
        }
        allItems += stepFourStates.map {
            DataItem(id: "step4-\($0.id.uuidString)", source: "Step 4 Chunk State", content: $0.resultText, date: $0.updatedAt, emotion: nil, additionalFields: ["Role Note": $0.roleNoteText])
        }
        allItems += chunkOutcomeLinks.map {
            DataItem(id: "chunkOutcome-\($0.id.uuidString)", source: "Step 4 Outcome Link", content: $0.outcomeId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: ["Chunk ID": $0.plannedChunkId.uuidString])
        }
        allItems += defineStates.map {
            DataItem(id: "define-\($0.id.uuidString)", source: "Define State", content: $0.isMust ? "Must" : "Optional", date: $0.updatedAt, emotion: nil, additionalFields: ["Time (min)": "\($0.timeEstimateMinutes ?? 0)", "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += executionStates.map {
            DataItem(id: "exec-\($0.id.uuidString)", source: "Execution State", content: $0.statusRaw, date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += leverageResources.map {
            DataItem(id: "leverageRes-\($0.id.uuidString)", source: "Leverage Resource", content: $0.value, date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw])
        }
        allItems += leverageSelections.map {
            DataItem(id: "leverageSel-\($0.id.uuidString)", source: "Leverage Selection", content: $0.resourceId?.uuidString ?? "(none)", date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += placeCatalog.map {
            DataItem(id: "placeCatalog-\($0.id.uuidString)", source: "Place Catalog", content: $0.place, date: $0.createdAt, emotion: nil, additionalFields: [:])
        }
        allItems += placeLinks.map {
            DataItem(id: "placeLink-\($0.id.uuidString)", source: "Place Link", content: $0.placeId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += actionNotes.map {
            DataItem(id: "actionNote-\($0.id.uuidString)", source: "Action Note", content: $0.noteText, date: $0.updatedAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += actionAttachments.map {
            DataItem(id: "actionAttachment-\($0.id.uuidString)", source: "Action Attachment", content: $0.fileName ?? $0.urlString ?? "", date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw, "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += legacyLeverageItems.map {
            DataItem(id: "legacyLeverage-\($0.id.uuidString)", source: "Legacy Leverage Item", content: $0.value, date: $0.createdAt, emotion: nil, additionalFields: ["Kind": $0.kindRaw, "Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += legacyPlaces.map {
            DataItem(id: "legacyPlace-\($0.id.uuidString)", source: "Legacy Sensitivity Place", content: $0.place, date: $0.createdAt, emotion: nil, additionalFields: ["Action ID": $0.plannedChunkActionId.uuidString])
        }
        allItems += adHocMarkers.map {
            DataItem(id: "adhoc-\($0.id.uuidString)", source: "Action Ad Hoc Marker", content: $0.plannedChunkActionId.uuidString, date: $0.createdAt, emotion: nil, additionalFields: [:])
        }
        allItems += reflections.map {
            DataItem(id: "reflect-\($0.id.uuidString)", source: "Reflection Archive", content: $0.achievementsText, date: $0.savedAt, emotion: nil, additionalFields: ["Magic Moments": $0.magicMomentsText, "Power Question": $0.powerQuestionText])
        }
        allItems += reflectionActions.map {
            DataItem(id: "reflectAction-\($0.id.uuidString)", source: "Reflection Archive Action", content: $0.actionText, date: $0.weekStart, emotion: nil, additionalFields: ["Status": $0.statusRaw, "Chunk": $0.chunkLabel])
        }
        allItems += reflectionOutcomes.map {
            DataItem(id: "reflectOutcome-\($0.id.uuidString)", source: "Reflection Archive Outcome", content: $0.outcomeText, date: $0.weekStart, emotion: nil, additionalFields: ["Category": $0.category])
        }

        let visibleItems: [DataItem]
        if showDeveloperData {
            visibleItems = allItems
        } else {
            visibleItems = allItems.filter { item in
                guard let prefix = item.id.split(separator: "-").first else { return true }
                return !developerFilterIDs.contains(String(prefix))
            }
        }

        let filtered: [DataItem]
        if selectedFilters.isEmpty {
            filtered = visibleItems
        } else {
            filtered = visibleItems.filter { item in
                guard let prefix = item.id.split(separator: "-").first else { return false }
                return selectedFilters.contains(String(prefix))
            }
        }
        return filtered.sorted { $0.date > $1.date }
    }

    private var visibleFilters: [ModelFilter] {
        if showDeveloperData { return availableFilters }
        return availableFilters.filter { !developerFilterIDs.contains($0.id) }
    }

    var body: some View {
        List(selection: $selection) {
            Toggle("Developer", isOn: $showDeveloperData)

            ForEach(items) { item in
                NavigationLink {
                    DataPrinterDetailView(item: item)
                } label: {
                    DataPrinterRow(item)
                }
                .tag(item.id)
            }
        }
        .listStyle(.plain)
        .toolbar {
            ToolbarItemGroup(placement: .bottomBar) {
                if editMode?.wrappedValue == .active {
                    Button {
                        if selection.count == items.count {
                            selection.removeAll()
                        } else {
                            selection = Set(items.map { $0.id })
                        }
                    } label: {
                        Text(selection.count == items.count ? "Deselect All" : "Select All")
                    }

                    Spacer()

                    Button {
                        showingDeleteAlert = true
                    } label: {
                        Text("Delete (\(selection.count))")
                    }
                    .foregroundColor(.red)
                    .disabled(selection.isEmpty)
                }
            }

            ToolbarItem(placement: .navigationBarTrailing) {
                HStack {
                    Button {
                        showingFilterSheet = true
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedFilters.isEmpty ? .gray : .blue)
                    }

                    EditButton()
                }
            }
        }
        .navigationTitle("Manage Raw Data")
        .alert("Permanently delete selected items?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                performBulkDelete()
            }
        } message: {
            Text("This will remove the chosen records forever.")
        }
        .sheet(isPresented: $showingFilterSheet) {
            FilterView(
                availableFilters: visibleFilters,
                selectedFilters: $selectedFilters
            )
        }
        .onChange(of: showDeveloperData) { _, isOn in
            if !isOn {
                selectedFilters.subtract(developerFilterIDs)
            }
        }
    }

    private func performBulkDelete() {
        for id in selection {
            guard let dash = id.firstIndex(of: "-") else { continue }
            let uuidString = String(id[id.index(after: dash)...])
            guard let uuid = UUID(uuidString: uuidString) else { continue }
            let prefix = String(id[..<dash])

            switch prefix {
            case "vision", "purpose": if let row = drivingForces.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "visionArch", "purposeArch": if let row = drivingForceArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "passion": if let row = passions.first(where: { $0.passion_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "passionArch": if let row = passionArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "fulfillment": if let row = fulfillments.first(where: { $0.category_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "fulfillmentArch": if let row = fulfillmentArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "role": if let row = fulfillmentRoles.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "roleArch": if let row = fulfillmentRolesArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "focus": if let row = fulfillmentFocus.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "focusArch": if let row = fulfillmentFocusArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "resource": if let row = fulfillmentResources.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "resourceArch": if let row = fulfillmentResourcesArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "join": if let row = passionFulfillmentJoins.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "joinArch": if let row = passionFulfillmentJoinArchives.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "outcome": if let row = outcomes.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "outcomeArch": if let row = outcomesArchives.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "measure": if let row = outcomesMeasures.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "measureArch": if let row = outcomesMeasuresArchives.first(where: { $0.outcome_id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "weekly": if let row = weeklyEntries.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "activePlan": if let row = activePlanStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "capture": if let row = rollingCapture.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "quickCapture": if let row = quickCompletedCapture.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "planLabel": if let row = planLabels.first(where: { $0.labelId == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "planSelect": if let row = planSelections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunk": if let row = plannedChunks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunkAction": if let row = plannedActions.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "step4": if let row = stepFourStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "chunkOutcome": if let row = chunkOutcomeLinks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "define": if let row = defineStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "exec": if let row = executionStates.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "leverageRes": if let row = leverageResources.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "leverageSel": if let row = leverageSelections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "placeCatalog": if let row = placeCatalog.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "placeLink": if let row = placeLinks.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "actionNote": if let row = actionNotes.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "actionAttachment": if let row = actionAttachments.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "legacyLeverage": if let row = legacyLeverageItems.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "legacyPlace": if let row = legacyPlaces.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "adhoc": if let row = adHocMarkers.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflect": if let row = reflections.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflectAction": if let row = reflectionActions.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            case "reflectOutcome": if let row = reflectionOutcomes.first(where: { $0.id == uuid }) { RecentlyDeletedStore.trash(row, in: context) }
            default: break
            }
        }
        try? context.save()
        selection.removeAll()
    }
}

private struct DemoPlanViewContainer: View {
    private let demoContainer: ModelContainer = {
        let schema: [any PersistentModel.Type] = [
            DrivingForce.self,
            DrivingForceArchive.self,
            Passion.self,
            PassionArchive.self,
            PassionFulfillmentJoin.self,
            PassionFulfillmentJoinArchive.self,
            Fulfillment.self,
            FulfillmentArchive.self,
            FulfillmentRoles.self,
            FulfillmentRolesArchive.self,
            FulfillmentFocus.self,
            FulfillmentFocusArchive.self,
            FulfillmentResources.self,
            FulfillmentResourcesArchive.self,
            Outcomes.self,
            OutcomesArchive.self,
            OutcomesMeasure.self,
            OutcomesMeasureArchive.self,
            WeeklyMindsetEntry.Fields.self,
            ActivePlanState.self,
            RollingCaptureItem.self,
            QuickCompletedCaptureItem.self,
            PlannedChunkActionAdHocMarker.self,
            ActionBlocksReflectionArchive.self,
            ActionBlocksReflectionArchiveAction.self,
            ActionBlocksReflectionArchiveOutcome.self,
            PlanLabel.self,
            PlanChunkSelection.self,
            PlannedChunk.self,
            PlannedChunkAction.self,
            PlannedChunkStepFourState.self,
            PlannedChunkOutcomeLink.self,
            PlannedChunkActionDefineState.self,
            PlannedChunkActionExecutionState.self,
            LeverageResource.self,
            PlannedChunkActionLeverageSelection.self,
            SensitivityPlaceCatalogItem.self,
            PlannedChunkActionSensitivityPlaceLink.self,
            PlannedChunkActionNote.self,
            PlannedChunkActionAttachment.self,
            PlannedChunkActionLeverageItem.self,
            PlannedChunkActionSensitivityPlace.self,
        ]
        let config = ModelConfiguration(isStoredInMemoryOnly: true)
        do {
            let demoSchema = Schema(schema)
            return try ModelContainer(for: demoSchema, configurations: config)
        } catch {
            fatalError("Failed to create demo model container: \(error)")
        }
    }()

    var body: some View {
        PlanView()
            .modelContainer(demoContainer)
    }
}

// MARK: - Filter View
struct FilterView: View {
    let availableFilters: [ModelFilter]
    @Binding var selectedFilters: Set<String>
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            List(availableFilters) { filter in
                HStack {
                    Text(filter.name)
                    Spacer()
                    if selectedFilters.contains(filter.id) {
                        Image(systemName: "checkmark")
                            .foregroundColor(.blue)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    if selectedFilters.contains(filter.id) {
                        selectedFilters.remove(filter.id)
                    } else {
                        selectedFilters.insert(filter.id)
                    }
                }
            }
            .navigationTitle("Filter Models")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .bottomBar) {
                    Button(selectedFilters.count == availableFilters.count ? "Deselect All" : "Select All") {
                        if selectedFilters.count == availableFilters.count {
                            selectedFilters.removeAll()
                        } else {
                            selectedFilters = Set(availableFilters.map { $0.id })
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Row View Helper
@ViewBuilder
private func DataPrinterRow(_ item: DataItem) -> some View {
    let dateText = item.date.formatted(
        .dateTime
        .month(.abbreviated)
        .day()
        .year()
        .hour(.twoDigits(amPM: .abbreviated))
        .minute()
    )

    VStack(alignment: .leading, spacing: 8) {
        Text(item.source)
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundColor(.secondary)

        if let emo = item.emotion {
            Text(emo.capitalized)
                .font(.subheadline)
                .fontWeight(.bold)
        }

        Text(item.content)
            .font(.body)

        Text(dateText)
            .font(.caption2)
            .foregroundColor(.gray)
    }
    .padding(.vertical, 4)
}

// MARK: - Detail View
struct DataPrinterDetailView: View {
    let item: DataItem

    var body: some View {
        Form {
            Section("Model") {
                Text(item.source)
            }
            Section("Content") {
                if let emo = item.emotion {
                    HStack {
                        Text("Emotion:")
                        Spacer()
                        Text(emo.capitalized)
                    }
                }
                HStack {
                    Text("Text:")
                    Spacer()
                    Text(item.content)
                        .multilineTextAlignment(.trailing)
                }
                ForEach(item.additionalFields.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                    HStack {
                        Text("\(key):")
                        Spacer()
                        Text(value)
                            .multilineTextAlignment(.trailing)
                    }
                }
            }
            Section("Timestamp") {
                Text(item.date.formatted(
                    .dateTime
                    .month(.wide)
                    .day()
                    .year()
                    .hour()
                    .minute()
                    .second()
                ))
            }
        }
        .navigationTitle("Details")
    }
}
