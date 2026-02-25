import Foundation
import SwiftData

enum RecentlyDeletedStore {
    private struct DrivingForceArchiveSnapshot: Codable {
        var id: UUID
        var visionSnapshot: String
        var purposeSnapshot: String
        var updatedAt: Date
        var archivedAt: Date
    }

    private struct ReplacedFulfillmentCategoryArchiveSnapshot: Codable {
        var id: UUID
        var category_id: UUID
        var category: String
        var category_identitiy: String
        var category_vision: String
        var category_purpose: String
        var rolesCSV: String
        var fociCSV: String
        var resourcesCSV: String
        var passionsCSV: String
        var replacedAt: Date
    }

    enum RestoreResult {
        case restored
        case needsCategoryMapping(missingCategory: String)
        case failed
    }

    private struct ReflectionArchiveActionSnapshot: Codable {
        var id: UUID
        var archiveId: UUID
        var weekStart: Date
        var plannedChunkId: UUID
        var plannedChunkActionId: UUID
        var chunkLabel: String
        var chunkCategory: String
        var resultText: String?
        var purposeText: String?
        var actionText: String
        var statusRaw: String
        var isMust: Bool
        var durationMinutes: Int?
        var leverageKindRaw: String?
        var leverageValue: String?
        var placeNamesCSV: String
        var hasNote: Bool
        var linkAttachmentCount: Int
        var fileAttachmentCount: Int
    }

    private struct ReflectionArchiveOutcomeSnapshot: Codable {
        var id: UUID
        var archiveId: UUID
        var weekStart: Date
        var plannedChunkId: UUID
        var outcomeId: UUID
        var outcomeText: String
        var category: String
    }

    private struct ReflectionArchiveSnapshot: Codable {
        var id: UUID
        var weekStart: Date
        var startedAt: Date
        var completedAt: Date
        var savedAt: Date
        var achievementsText: String
        var magicMomentsText: String
        var powerQuestionText: String
        var actions: [ReflectionArchiveActionSnapshot]
        var outcomes: [ReflectionArchiveOutcomeSnapshot]
        var notes: [ActionNoteSnapshot]
        var attachments: [ActionAttachmentSnapshot]
        var contributions: [OutcomeContributionSnapshot]
    }

    private struct ActionAttachmentSnapshot: Codable {
        var id: UUID
        var weekStart: Date
        var plannedChunkActionId: UUID
        var kindRaw: String
        var urlString: String?
        var fileName: String?
        var fileBookmarkData: Data?
        var createdAt: Date
    }

    private struct ActionNoteSnapshot: Codable {
        var id: UUID
        var weekStart: Date
        var plannedChunkActionId: UUID
        var noteText: String
        var updatedAt: Date
    }

    private struct OutcomeSnapshot: Codable {
        var category: String
        var updatedAt: Date
        var outcome: String
        var reasons: String
        var start: Date
        var end: Date
        var rank: Int
        var format: String?
        var measure: MeasureSnapshot?
        var measureEntries: [MeasureEntrySnapshot]
        var contributions: [OutcomeContributionSnapshot]?
    }

    private struct MeasureSnapshot: Codable {
        var measure: Double
        var measuredAt: Date
        var measureAmt: Double
        var measureUpdated: Date
        var direction: String?
        var format: String?
        var unit: String?
        var decimalPlaces: Int?
    }

    private struct MeasureEntrySnapshot: Codable {
        var id: UUID
        var measure: Double
        var measureAmt: Double
        var measuredAt: Date
        var createdAt: Date
        var format: String?
        var unit: String?
        var decimalPlaces: Int?
    }

    private struct CaptureSnapshot: Codable {
        var text: String
        var isGhost: Bool
        var createdAt: Date
        var unhideDate: Date?
        var unhiddenAt: Date?
    }

    private struct OutcomeContributionSnapshot: Codable {
        var id: UUID
        var archiveId: UUID
        var weekStart: Date
        var outcomeId: UUID
        var plannedChunkActionId: UUID
        var actionText: String
        var completedAt: Date
    }

    private struct CompletedOutcomeContributionSnapshot: Codable {
        var id: UUID
        var completedOutcomeArchiveId: UUID
        var actionText: String
        var completedAt: Date
    }

    private struct CompletedOutcomeMeasurePointSnapshot: Codable {
        var id: UUID
        var completedOutcomeArchiveId: UUID
        var measuredAt: Date
        var measure: Double
        var goal: Double
    }

    private struct CompletedOutcomeArchiveSnapshot: Codable {
        var id: UUID
        var originalOutcomeId: UUID
        var category: String
        var outcome: String
        var reasons: String
        var start: Date
        var end: Date
        var completedAt: Date
        var format: String?
        var isMeasurable: Bool
        var goalValue: Double?
        var finalValue: Double?
        var goalMet: Bool
        var successLevel: Int?
        var daysElapsed: Int
        var goalPushCount: Int
        var dataEntryCount: Int
        var targetChangeCount: Int
        var journalWins: String
        var journalLearned: String
        var journalNext: String
        var contributions: [CompletedOutcomeContributionSnapshot]
        var measurePoints: [CompletedOutcomeMeasurePointSnapshot]
    }

    static func trash(_ model: any PersistentModel, in context: ModelContext, source: String = "") {
        if model is RecentlyDeletedItem {
            context.delete(model)
            return
        }

        if model is QuickCompletedCaptureItem || model is OutcomesMeasure || model is OutcomesMeasureEntry {
            context.delete(model)
            return
        }

        let payload = payloadJSON(for: model, in: context)

        let now = Date()
        let purgeAt = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let entry = RecentlyDeletedItem(
            entityType: entityType(for: model),
            entityID: entityID(for: model),
            titleText: title(for: model),
            subtitleText: subtitle(for: model),
            source: source,
            payloadJSON: payload,
            deletedAt: now,
            purgeAt: purgeAt
        )
        context.insert(entry)

        if let outcome = model as? Outcomes {
            let allMeasures = (try? context.fetch(FetchDescriptor<OutcomesMeasure>())) ?? []
            if let measure = allMeasures.first(where: { $0.outcome_id == outcome.outcome_id }) {
                context.delete(measure)
            }
            let allEntries = (try? context.fetch(FetchDescriptor<OutcomesMeasureEntry>())) ?? []
            for entry in allEntries where entry.outcome_id == outcome.outcome_id {
                context.delete(entry)
            }
        }
        if let completed = model as? CompletedOutcomeArchive {
            let allContribs = (try? context.fetch(FetchDescriptor<CompletedOutcomeContributionArchive>())) ?? []
            for row in allContribs where row.completedOutcomeArchiveId == completed.id {
                context.delete(row)
            }
            let allPoints = (try? context.fetch(FetchDescriptor<CompletedOutcomeMeasurePointArchive>())) ?? []
            for row in allPoints where row.completedOutcomeArchiveId == completed.id {
                context.delete(row)
            }
        }
        if let reflection = model as? ActionBlocksReflectionArchive {
            deleteReflectionArchiveChildren(for: reflection, in: context)
        }
        context.delete(model)
    }

    static func restore(
        _ item: RecentlyDeletedItem,
        in context: ModelContext,
        categoryOverride: String? = nil
    ) -> RestoreResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch item.entityType {
        case "Outcomes":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(OutcomeSnapshot.self, from: data),
                let outcomeUUID = UUID(uuidString: item.entityID)
            else { return .failed }

            guard let finalCategory = resolveCategory(
                requested: decoded.category,
                categoryOverride: categoryOverride,
                in: context
            ) else {
                return .needsCategoryMapping(missingCategory: decoded.category)
            }

            context.insert(
                Outcomes(
                    outcome_id: outcomeUUID,
                    category: finalCategory,
                    updatedAt: .now,
                    outcome: decoded.outcome,
                    reasons: decoded.reasons,
                    start: decoded.start,
                    end: decoded.end,
                    rank: decoded.rank,
                    format: decoded.format
                )
            )

            if let m = decoded.measure {
                context.insert(
                    OutcomesMeasure(
                        outcome_id: outcomeUUID,
                        measure: m.measure,
                        measuredAt: m.measuredAt,
                        measure_amt: m.measureAmt,
                        measure_updated: m.measureUpdated,
                        direction: m.direction,
                        format: m.format,
                        unit: m.unit,
                        decimalPlaces: m.decimalPlaces
                    )
                )
            }

            for entry in decoded.measureEntries {
                context.insert(
                    OutcomesMeasureEntry(
                        id: entry.id,
                        outcome_id: outcomeUUID,
                        measure: entry.measure,
                        measure_amt: entry.measureAmt,
                        measuredAt: entry.measuredAt,
                        createdAt: entry.createdAt,
                        format: entry.format,
                        unit: entry.unit,
                        decimalPlaces: entry.decimalPlaces
                    )
                )
            }

            let existingContribs = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())) ?? []
            let existingContribIDs = Set(existingContribs.map(\.id))
            let existingContribKeys = Set(existingContribs.map {
                "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)|\($0.outcomeId.uuidString)"
            })
            for contribution in decoded.contributions ?? [] {
                let key = "\(contribution.archiveId.uuidString)|\(contribution.plannedChunkActionId.uuidString)|\(contribution.outcomeId.uuidString)"
                if existingContribIDs.contains(contribution.id) || existingContribKeys.contains(key) {
                    continue
                }
                context.insert(
                    ActionBlocksReflectionOutcomeContribution(
                        id: contribution.id,
                        archiveId: contribution.archiveId,
                        weekStart: contribution.weekStart,
                        outcomeId: contribution.outcomeId,
                        plannedChunkActionId: contribution.plannedChunkActionId,
                        actionText: contribution.actionText,
                        completedAt: contribution.completedAt
                    )
                )
            }

            context.delete(item)
            return .restored

        case "RollingCaptureItem":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(CaptureSnapshot.self, from: data),
                let id = UUID(uuidString: item.entityID)
            else { return .failed }

            let normalized = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let existingCapture = (try? context.fetch(FetchDescriptor<RollingCaptureItem>())) ?? []
            if existingCapture.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) {
                context.delete(item)
                return .restored
            }

            let finalID: UUID = existingCapture.contains(where: { $0.id == id }) ? UUID() : id

            context.insert(
                RollingCaptureItem(
                    id: finalID,
                    text: decoded.text,
                    isGhost: decoded.isGhost,
                    createdAt: decoded.createdAt,
                    unhideDate: decoded.unhideDate,
                    unhiddenAt: decoded.unhiddenAt
                )
            )
            context.delete(item)
            return .restored

        case "CompletedOutcomeArchive":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(CompletedOutcomeArchiveSnapshot.self, from: data)
            else { return .failed }

            guard let finalCategory = resolveCategory(
                requested: decoded.category,
                categoryOverride: categoryOverride,
                in: context
            ) else {
                return .needsCategoryMapping(missingCategory: decoded.category)
            }

            let existingArchives = (try? context.fetch(FetchDescriptor<CompletedOutcomeArchive>())) ?? []
            if existingArchives.contains(where: { $0.id == decoded.id }) {
                context.delete(item)
                return .restored
            }

            context.insert(
                CompletedOutcomeArchive(
                    id: decoded.id,
                    originalOutcomeId: decoded.originalOutcomeId,
                    category: finalCategory,
                    outcome: decoded.outcome,
                    reasons: decoded.reasons,
                    start: decoded.start,
                    end: decoded.end,
                    completedAt: decoded.completedAt,
                    format: decoded.format,
                    isMeasurable: decoded.isMeasurable,
                    goalValue: decoded.goalValue,
                    finalValue: decoded.finalValue,
                    goalMet: decoded.goalMet,
                    successLevel: decoded.successLevel,
                    daysElapsed: decoded.daysElapsed,
                    goalPushCount: decoded.goalPushCount,
                    dataEntryCount: decoded.dataEntryCount,
                    targetChangeCount: decoded.targetChangeCount,
                    journalWins: decoded.journalWins,
                    journalLearned: decoded.journalLearned,
                    journalNext: decoded.journalNext
                )
            )

            let existingContribIDs = Set(((try? context.fetch(FetchDescriptor<CompletedOutcomeContributionArchive>())) ?? []).map(\.id))
            for row in decoded.contributions where !existingContribIDs.contains(row.id) {
                context.insert(
                    CompletedOutcomeContributionArchive(
                        id: row.id,
                        completedOutcomeArchiveId: row.completedOutcomeArchiveId,
                        actionText: row.actionText,
                        completedAt: row.completedAt
                    )
                )
            }

            let existingPointIDs = Set(((try? context.fetch(FetchDescriptor<CompletedOutcomeMeasurePointArchive>())) ?? []).map(\.id))
            for row in decoded.measurePoints where !existingPointIDs.contains(row.id) {
                context.insert(
                    CompletedOutcomeMeasurePointArchive(
                        id: row.id,
                        completedOutcomeArchiveId: row.completedOutcomeArchiveId,
                        measuredAt: row.measuredAt,
                        measure: row.measure,
                        goal: row.goal
                    )
                )
            }

            context.delete(item)
            return .restored

        case "DrivingForceArchive":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(DrivingForceArchiveSnapshot.self, from: data)
            else { return .failed }

            let allRows = (try? context.fetch(FetchDescriptor<DrivingForceArchive>())) ?? []
            let finalID = allRows.contains(where: { $0.id == decoded.id }) ? UUID() : decoded.id
            context.insert(
                DrivingForceArchive(
                    id: finalID,
                    visionSnapshot: decoded.visionSnapshot,
                    purposeSnapshot: decoded.purposeSnapshot,
                    updatedAt: decoded.updatedAt,
                    archivedAt: decoded.archivedAt
                )
            )
            context.delete(item)
            return .restored

        case "ReplacedFulfillmentCategoryArchive":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(ReplacedFulfillmentCategoryArchiveSnapshot.self, from: data)
            else { return .failed }

            let existing = (try? context.fetch(FetchDescriptor<ReplacedFulfillmentCategoryArchive>())) ?? []
            let finalID = existing.contains(where: { $0.id == decoded.id }) ? UUID() : decoded.id
            context.insert(
                ReplacedFulfillmentCategoryArchive(
                    id: finalID,
                    category_id: decoded.category_id,
                    category: decoded.category,
                    category_identitiy: decoded.category_identitiy,
                    category_vision: decoded.category_vision,
                    category_purpose: decoded.category_purpose,
                    rolesCSV: decoded.rolesCSV,
                    fociCSV: decoded.fociCSV,
                    resourcesCSV: decoded.resourcesCSV,
                    passionsCSV: decoded.passionsCSV,
                    replacedAt: decoded.replacedAt
                )
            )
            context.delete(item)
            return .restored

        case "PlannedChunkActionAttachment":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(ActionAttachmentSnapshot.self, from: data)
            else { return .failed }

            let allLive = (try? context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())) ?? []
            let duplicate = allLive.contains {
                $0.plannedChunkActionId == decoded.plannedChunkActionId &&
                $0.kindRaw == decoded.kindRaw &&
                ($0.urlString ?? "") == (decoded.urlString ?? "") &&
                ($0.fileName ?? "") == (decoded.fileName ?? "")
            }
            if !duplicate {
                context.insert(
                    PlannedChunkActionAttachment(
                        id: allLive.contains(where: { $0.id == decoded.id }) ? UUID() : decoded.id,
                        weekStart: decoded.weekStart,
                        plannedChunkActionId: decoded.plannedChunkActionId,
                        kindRaw: decoded.kindRaw,
                        urlString: decoded.urlString,
                        fileName: decoded.fileName,
                        fileBookmarkData: decoded.fileBookmarkData,
                        createdAt: decoded.createdAt
                    )
                )

                let archiveActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
                if let archiveAction = archiveActions.first(where: { $0.plannedChunkActionId == decoded.plannedChunkActionId }) {
                    if decoded.kindRaw == ActionAttachmentKind.link.rawValue {
                        archiveAction.linkAttachmentCount += 1
                    } else if decoded.kindRaw == ActionAttachmentKind.file.rawValue {
                        archiveAction.fileAttachmentCount += 1
                    }
                }
            }

            context.delete(item)
            return .restored

        case "PlannedChunkActionNote":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(ActionNoteSnapshot.self, from: data)
            else { return .failed }

            let allNotes = (try? context.fetch(FetchDescriptor<PlannedChunkActionNote>())) ?? []
            let dayKey = {
                let comps = Calendar.current.dateComponents([.year, .month, .day], from: decoded.weekStart)
                return String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
            }()
            let weekActionKey = "\(dayKey)|\(decoded.plannedChunkActionId.uuidString)"

            if let existing = allNotes.first(where: { $0.weekActionKey == weekActionKey }) {
                existing.noteText = decoded.noteText
                existing.updatedAt = decoded.updatedAt
            } else {
                context.insert(
                    PlannedChunkActionNote(
                        id: allNotes.contains(where: { $0.id == decoded.id }) ? UUID() : decoded.id,
                        weekStart: decoded.weekStart,
                        plannedChunkActionId: decoded.plannedChunkActionId,
                        noteText: decoded.noteText,
                        updatedAt: decoded.updatedAt
                    )
                )
            }

            let archiveActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
            if let archiveAction = archiveActions.first(where: { $0.plannedChunkActionId == decoded.plannedChunkActionId }) {
                archiveAction.hasNote = !decoded.noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }

            context.delete(item)
            return .restored

        case "ActionBlocksReflectionArchive":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(ReflectionArchiveSnapshot.self, from: data)
            else { return .failed }

            let resolvedCategoryByOriginal: [String: String] = {
                let categories = Set(decoded.actions.map(\.chunkCategory) + decoded.outcomes.map(\.category))
                var result: [String: String] = [:]
                for original in categories {
                    guard let resolved = resolveCategory(
                        requested: original,
                        categoryOverride: categoryOverride,
                        in: context
                    ) else {
                        return [:]
                    }
                    result[original] = resolved
                }
                return result
            }()
            if resolvedCategoryByOriginal.isEmpty && !(decoded.actions.isEmpty && decoded.outcomes.isEmpty) {
                let missing = (decoded.actions.map(\.chunkCategory) + decoded.outcomes.map(\.category)).first ?? "Unknown"
                return .needsCategoryMapping(missingCategory: missing)
            }

            let existingArchives = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchive>())) ?? []
            if !existingArchives.contains(where: { $0.id == decoded.id }) {
                context.insert(
                    ActionBlocksReflectionArchive(
                        id: decoded.id,
                        weekStart: decoded.weekStart,
                        startedAt: decoded.startedAt,
                        completedAt: decoded.completedAt,
                        savedAt: decoded.savedAt,
                        achievementsText: decoded.achievementsText,
                        magicMomentsText: decoded.magicMomentsText,
                        powerQuestionText: decoded.powerQuestionText
                    )
                )
            }

            let existingActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
            let existingActionIDs = Set(existingActions.map(\.id))
            for row in decoded.actions where !existingActionIDs.contains(row.id) {
                context.insert(
                    ActionBlocksReflectionArchiveAction(
                        id: row.id,
                        archiveId: row.archiveId,
                        weekStart: row.weekStart,
                        plannedChunkId: row.plannedChunkId,
                        plannedChunkActionId: row.plannedChunkActionId,
                        chunkLabel: row.chunkLabel,
                        chunkCategory: resolvedCategoryByOriginal[row.chunkCategory] ?? row.chunkCategory,
                        resultText: row.resultText,
                        purposeText: row.purposeText,
                        actionText: row.actionText,
                        statusRaw: row.statusRaw,
                        isMust: row.isMust,
                        durationMinutes: row.durationMinutes,
                        leverageKindRaw: row.leverageKindRaw,
                        leverageValue: row.leverageValue,
                        placeNamesCSV: row.placeNamesCSV,
                        hasNote: row.hasNote,
                        linkAttachmentCount: row.linkAttachmentCount,
                        fileAttachmentCount: row.fileAttachmentCount
                    )
                )
            }

            let existingOutcomes = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveOutcome>())) ?? []
            let existingOutcomeIDs = Set(existingOutcomes.map(\.id))
            for row in decoded.outcomes where !existingOutcomeIDs.contains(row.id) {
                context.insert(
                    ActionBlocksReflectionArchiveOutcome(
                        id: row.id,
                        archiveId: row.archiveId,
                        weekStart: row.weekStart,
                        plannedChunkId: row.plannedChunkId,
                        outcomeId: row.outcomeId,
                        outcomeText: row.outcomeText,
                        category: resolvedCategoryByOriginal[row.category] ?? row.category
                    )
                )
            }

            let existingNotes = (try? context.fetch(FetchDescriptor<PlannedChunkActionNote>())) ?? []
            let existingNoteKeys = Set(existingNotes.map(\.weekActionKey))
            for row in decoded.notes {
                let comps = Calendar.current.dateComponents([.year, .month, .day], from: row.weekStart)
                let dayKey = String(format: "%04d-%02d-%02d", comps.year ?? 0, comps.month ?? 0, comps.day ?? 0)
                let weekActionKey = "\(dayKey)|\(row.plannedChunkActionId.uuidString)"
                if existingNoteKeys.contains(weekActionKey) { continue }
                context.insert(
                    PlannedChunkActionNote(
                        id: row.id,
                        weekStart: row.weekStart,
                        plannedChunkActionId: row.plannedChunkActionId,
                        noteText: row.noteText,
                        updatedAt: row.updatedAt
                    )
                )
            }

            let existingAttachments = (try? context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())) ?? []
            let existingAttachmentIDs = Set(existingAttachments.map(\.id))
            for row in decoded.attachments where !existingAttachmentIDs.contains(row.id) {
                context.insert(
                    PlannedChunkActionAttachment(
                        id: row.id,
                        weekStart: row.weekStart,
                        plannedChunkActionId: row.plannedChunkActionId,
                        kindRaw: row.kindRaw,
                        urlString: row.urlString,
                        fileName: row.fileName,
                        fileBookmarkData: row.fileBookmarkData,
                        createdAt: row.createdAt
                    )
                )
            }

            let existingContribs = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())) ?? []
            let existingContribIDs = Set(existingContribs.map(\.id))
            let existingContribKeys = Set(existingContribs.map {
                "\($0.archiveId.uuidString)|\($0.plannedChunkActionId.uuidString)|\($0.outcomeId.uuidString)"
            })
            for row in decoded.contributions {
                let key = "\(row.archiveId.uuidString)|\(row.plannedChunkActionId.uuidString)|\(row.outcomeId.uuidString)"
                if existingContribIDs.contains(row.id) || existingContribKeys.contains(key) { continue }
                context.insert(
                    ActionBlocksReflectionOutcomeContribution(
                        id: row.id,
                        archiveId: row.archiveId,
                        weekStart: row.weekStart,
                        outcomeId: row.outcomeId,
                        plannedChunkActionId: row.plannedChunkActionId,
                        actionText: row.actionText,
                        completedAt: row.completedAt
                    )
                )
            }

            context.delete(item)
            return .restored

        default:
            return .failed
        }
    }

    private static func resolveCategory(
        requested: String,
        categoryOverride: String?,
        in context: ModelContext
    ) -> String? {
        let trimmedRequested = requested.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedOverride = categoryOverride?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        if !trimmedOverride.isEmpty {
            return trimmedOverride
        }

        let allFulfillments = (try? context.fetch(FetchDescriptor<Fulfillment>())) ?? []
        let available = allFulfillments.map(\.category)
        if available.contains(where: { $0.caseInsensitiveCompare(trimmedRequested) == .orderedSame }) {
            return available.first(where: { $0.caseInsensitiveCompare(trimmedRequested) == .orderedSame }) ?? trimmedRequested
        }

        if let aliased = FulfillmentCategoryTheme.categoryAlias(for: trimmedRequested),
           available.contains(where: { $0.caseInsensitiveCompare(aliased) == .orderedSame }) {
            return available.first(where: { $0.caseInsensitiveCompare(aliased) == .orderedSame }) ?? aliased
        }
        return nil
    }

    static func purgeExpired(in context: ModelContext) {
        let now = Date()
        var descriptor = FetchDescriptor<RecentlyDeletedItem>(
            predicate: #Predicate<RecentlyDeletedItem> { $0.purgeAt <= now }
        )
        descriptor.includePendingChanges = false
        let rows = (try? context.fetch(descriptor)) ?? []
        guard !rows.isEmpty else { return }
        for row in rows where row.purgeAt <= now {
            context.delete(row)
        }
        try? context.save()
    }

    static func permanentlyDelete(_ item: RecentlyDeletedItem, in context: ModelContext) {
        if item.entityType == "Outcomes", let outcomeUUID = UUID(uuidString: item.entityID) {
            let events = (try? context.fetch(FetchDescriptor<OutcomeAnalyticsEvent>())) ?? []
            for event in events where event.outcome_id == outcomeUUID {
                context.delete(event)
            }
        }
        context.delete(item)
    }

    private static func entityType(for model: any PersistentModel) -> String {
        String(describing: type(of: model))
    }

    private static func entityID(for model: any PersistentModel) -> String {
        if let m = model as? Outcomes { return m.outcome_id.uuidString }
        if let m = model as? RollingCaptureItem { return m.id.uuidString }
        if let m = model as? CompletedOutcomeArchive { return m.id.uuidString }
        if let m = model as? ActionBlocksReflectionArchive { return m.id.uuidString }
        if let m = model as? ReplacedFulfillmentCategoryArchive { return m.id.uuidString }
        if let m = model as? RecentlyDeletedItem { return m.id.uuidString }

        let mirror = Mirror(reflecting: model)
        for child in mirror.children {
            if child.label == "id", let id = child.value as? UUID { return id.uuidString }
        }
        return UUID().uuidString
    }

    private static func title(for model: any PersistentModel) -> String {
        if let m = model as? Outcomes { return m.outcome }
        if let m = model as? RollingCaptureItem { return m.text }
        if let m = model as? CompletedOutcomeArchive { return m.outcome }
        if let m = model as? ActionBlocksReflectionArchive {
            return "Action Blocks • \(shortDate(m.startedAt)) - \(shortDate(m.completedAt))"
        }
        if let m = model as? DrivingForceArchive {
            let vision = m.visionSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            let purpose = m.purposeSnapshot.trimmingCharacters(in: .whitespacesAndNewlines)
            if !vision.isEmpty { return vision }
            if !purpose.isEmpty { return purpose }
            return "Purpose"
        }
        if let m = model as? ReplacedFulfillmentCategoryArchive {
            return m.category
        }

        let mirror = Mirror(reflecting: model)
        for key in ["text", "outcome", "role", "activity", "resource", "category"] {
            if let value = mirror.children.first(where: { $0.label == key })?.value as? String,
               !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return value
            }
        }
        return String(describing: type(of: model))
    }

    private static func subtitle(for model: any PersistentModel) -> String {
        if let m = model as? Outcomes {
            return "\(m.category) • \(shortDate(m.start)) - \(shortDate(m.end))"
        }
        if let m = model as? RollingCaptureItem {
            return m.isGhost ? "Capture (Hidden)" : "Capture"
        }
        if let m = model as? CompletedOutcomeArchive {
            return "Completed Outcome • \(shortDate(m.start)) - \(shortDate(m.completedAt))"
        }
        if model is ActionBlocksReflectionArchive {
            return "Completed Action Blocks"
        }
        if model is DrivingForceArchive {
            return "Purpose"
        }
        if model is ReplacedFulfillmentCategoryArchive {
            return "Previous Category"
        }
        return String(describing: type(of: model))
    }

    private static func payloadJSON(for model: any PersistentModel, in context: ModelContext) -> String? {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601

        if let m = model as? Outcomes {
            let allMeasures = (try? context.fetch(FetchDescriptor<OutcomesMeasure>())) ?? []
            let measure = allMeasures.first(where: { $0.outcome_id == m.outcome_id })
            let allEntries = (try? context.fetch(FetchDescriptor<OutcomesMeasureEntry>())) ?? []
            let outcomeEntries = allEntries.filter { $0.outcome_id == m.outcome_id }
            let allContributions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())) ?? []
            let outcomeContributions = allContributions.filter { $0.outcomeId == m.outcome_id }
            let latestEntry = outcomeEntries.max(by: { $0.measuredAt < $1.measuredAt })

            let snapMeasure = latestEntry?.measure ?? measure?.measure
            let snapMeasuredAt = latestEntry?.measuredAt ?? measure?.measuredAt ?? .now
            let snapMeasureAmt = latestEntry?.measure_amt ?? measure?.measure_amt ?? 0
            let snapFormat = latestEntry?.format ?? measure?.format
            let snapUnit = latestEntry?.unit ?? measure?.unit
            let snapDecimals = latestEntry?.decimalPlaces ?? measure?.decimalPlaces

            let snapshot = OutcomeSnapshot(
                category: m.category,
                updatedAt: m.updatedAt,
                outcome: m.outcome,
                reasons: m.reasons,
                start: m.start,
                end: m.end,
                rank: m.rank,
                format: m.format,
                measure: snapMeasure.map { current in
                    MeasureSnapshot(
                        measure: current,
                        measuredAt: snapMeasuredAt,
                        measureAmt: snapMeasureAmt,
                        measureUpdated: .now,
                        direction: measure?.direction,
                        format: snapFormat,
                        unit: snapUnit,
                        decimalPlaces: snapDecimals
                    )
                },
                measureEntries: outcomeEntries.map {
                    MeasureEntrySnapshot(
                        id: $0.id,
                        measure: $0.measure,
                        measureAmt: $0.measure_amt,
                        measuredAt: $0.measuredAt,
                        createdAt: $0.createdAt,
                        format: $0.format,
                        unit: $0.unit,
                        decimalPlaces: $0.decimalPlaces
                    )
                },
                contributions: outcomeContributions.map {
                    OutcomeContributionSnapshot(
                        id: $0.id,
                        archiveId: $0.archiveId,
                        weekStart: $0.weekStart,
                        outcomeId: $0.outcomeId,
                        plannedChunkActionId: $0.plannedChunkActionId,
                        actionText: $0.actionText,
                        completedAt: $0.completedAt
                    )
                }
            )

            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? RollingCaptureItem {
            let snapshot = CaptureSnapshot(
                text: m.text,
                isGhost: m.isGhost,
                createdAt: m.createdAt,
                unhideDate: m.unhideDate,
                unhiddenAt: m.unhiddenAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? ActionBlocksReflectionOutcomeContribution {
            let snapshot = OutcomeContributionSnapshot(
                id: m.id,
                archiveId: m.archiveId,
                weekStart: m.weekStart,
                outcomeId: m.outcomeId,
                plannedChunkActionId: m.plannedChunkActionId,
                actionText: m.actionText,
                completedAt: m.completedAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? CompletedOutcomeArchive {
            let allContribs = (try? context.fetch(FetchDescriptor<CompletedOutcomeContributionArchive>())) ?? []
            let allPoints = (try? context.fetch(FetchDescriptor<CompletedOutcomeMeasurePointArchive>())) ?? []
            let snapshot = CompletedOutcomeArchiveSnapshot(
                id: m.id,
                originalOutcomeId: m.originalOutcomeId,
                category: m.category,
                outcome: m.outcome,
                reasons: m.reasons,
                start: m.start,
                end: m.end,
                completedAt: m.completedAt,
                format: m.format,
                isMeasurable: m.isMeasurable,
                goalValue: m.goalValue,
                finalValue: m.finalValue,
                goalMet: m.goalMet,
                successLevel: m.successLevel,
                daysElapsed: m.daysElapsed,
                goalPushCount: m.goalPushCount,
                dataEntryCount: m.dataEntryCount,
                targetChangeCount: m.targetChangeCount,
                journalWins: m.journalWins,
                journalLearned: m.journalLearned,
                journalNext: m.journalNext,
                contributions: allContribs
                    .filter { $0.completedOutcomeArchiveId == m.id }
                    .map {
                        CompletedOutcomeContributionSnapshot(
                            id: $0.id,
                            completedOutcomeArchiveId: $0.completedOutcomeArchiveId,
                            actionText: $0.actionText,
                            completedAt: $0.completedAt
                        )
                    },
                measurePoints: allPoints
                    .filter { $0.completedOutcomeArchiveId == m.id }
                    .map {
                        CompletedOutcomeMeasurePointSnapshot(
                            id: $0.id,
                            completedOutcomeArchiveId: $0.completedOutcomeArchiveId,
                            measuredAt: $0.measuredAt,
                            measure: $0.measure,
                            goal: $0.goal
                        )
                    }
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? ActionBlocksReflectionArchive {
            let allArchiveActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
            let allArchiveOutcomes = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveOutcome>())) ?? []
            let relatedActions = allArchiveActions.filter { $0.archiveId == m.id }
            let relatedOutcomes = allArchiveOutcomes.filter { $0.archiveId == m.id }
            let actionIDs = Set(relatedActions.map(\.plannedChunkActionId))
            let allNotes = (try? context.fetch(FetchDescriptor<PlannedChunkActionNote>())) ?? []
            let allAttachments = (try? context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())) ?? []
            let allContributions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())) ?? []
            let relatedNotes = allNotes.filter { actionIDs.contains($0.plannedChunkActionId) }
            let relatedAttachments = allAttachments.filter { actionIDs.contains($0.plannedChunkActionId) }
            let relatedContributions = allContributions.filter { $0.archiveId == m.id }

            let snapshot = ReflectionArchiveSnapshot(
                id: m.id,
                weekStart: m.weekStart,
                startedAt: m.startedAt,
                completedAt: m.completedAt,
                savedAt: m.savedAt,
                achievementsText: m.achievementsText,
                magicMomentsText: m.magicMomentsText,
                powerQuestionText: m.powerQuestionText,
                actions: relatedActions.map {
                    ReflectionArchiveActionSnapshot(
                        id: $0.id,
                        archiveId: $0.archiveId,
                        weekStart: $0.weekStart,
                        plannedChunkId: $0.plannedChunkId,
                        plannedChunkActionId: $0.plannedChunkActionId,
                        chunkLabel: $0.chunkLabel,
                        chunkCategory: $0.chunkCategory,
                        resultText: $0.resultText,
                        purposeText: $0.purposeText,
                        actionText: $0.actionText,
                        statusRaw: $0.statusRaw,
                        isMust: $0.isMust,
                        durationMinutes: $0.durationMinutes,
                        leverageKindRaw: $0.leverageKindRaw,
                        leverageValue: $0.leverageValue,
                        placeNamesCSV: $0.placeNamesCSV,
                        hasNote: $0.hasNote,
                        linkAttachmentCount: $0.linkAttachmentCount,
                        fileAttachmentCount: $0.fileAttachmentCount
                    )
                },
                outcomes: relatedOutcomes.map {
                    ReflectionArchiveOutcomeSnapshot(
                        id: $0.id,
                        archiveId: $0.archiveId,
                        weekStart: $0.weekStart,
                        plannedChunkId: $0.plannedChunkId,
                        outcomeId: $0.outcomeId,
                        outcomeText: $0.outcomeText,
                        category: $0.category
                    )
                },
                notes: relatedNotes.map {
                    ActionNoteSnapshot(
                        id: $0.id,
                        weekStart: $0.weekStart,
                        plannedChunkActionId: $0.plannedChunkActionId,
                        noteText: $0.noteText,
                        updatedAt: $0.updatedAt
                    )
                },
                attachments: relatedAttachments.map {
                    ActionAttachmentSnapshot(
                        id: $0.id,
                        weekStart: $0.weekStart,
                        plannedChunkActionId: $0.plannedChunkActionId,
                        kindRaw: $0.kindRaw,
                        urlString: $0.urlString,
                        fileName: $0.fileName,
                        fileBookmarkData: $0.fileBookmarkData,
                        createdAt: $0.createdAt
                    )
                },
                contributions: relatedContributions.map {
                    OutcomeContributionSnapshot(
                        id: $0.id,
                        archiveId: $0.archiveId,
                        weekStart: $0.weekStart,
                        outcomeId: $0.outcomeId,
                        plannedChunkActionId: $0.plannedChunkActionId,
                        actionText: $0.actionText,
                        completedAt: $0.completedAt
                    )
                }
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? PlannedChunkActionAttachment {
            let snapshot = ActionAttachmentSnapshot(
                id: m.id,
                weekStart: m.weekStart,
                plannedChunkActionId: m.plannedChunkActionId,
                kindRaw: m.kindRaw,
                urlString: m.urlString,
                fileName: m.fileName,
                fileBookmarkData: m.fileBookmarkData,
                createdAt: m.createdAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? PlannedChunkActionNote {
            let snapshot = ActionNoteSnapshot(
                id: m.id,
                weekStart: m.weekStart,
                plannedChunkActionId: m.plannedChunkActionId,
                noteText: m.noteText,
                updatedAt: m.updatedAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? DrivingForceArchive {
            let snapshot = DrivingForceArchiveSnapshot(
                id: m.id,
                visionSnapshot: m.visionSnapshot,
                purposeSnapshot: m.purposeSnapshot,
                updatedAt: m.updatedAt,
                archivedAt: m.archivedAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        if let m = model as? ReplacedFulfillmentCategoryArchive {
            let snapshot = ReplacedFulfillmentCategoryArchiveSnapshot(
                id: m.id,
                category_id: m.category_id,
                category: m.category,
                category_identitiy: m.category_identitiy,
                category_vision: m.category_vision,
                category_purpose: m.category_purpose,
                rolesCSV: m.rolesCSV,
                fociCSV: m.fociCSV,
                resourcesCSV: m.resourcesCSV,
                passionsCSV: m.passionsCSV,
                replacedAt: m.replacedAt
            )
            if let data = try? encoder.encode(snapshot) {
                return String(data: data, encoding: .utf8)
            }
        }

        return nil
    }

    private static func deleteReflectionArchiveChildren(for archive: ActionBlocksReflectionArchive, in context: ModelContext) {
        let allArchiveActions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveAction>())) ?? []
        let allArchiveOutcomes = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionArchiveOutcome>())) ?? []
        let relatedActions = allArchiveActions.filter { $0.archiveId == archive.id }
        let relatedOutcomes = allArchiveOutcomes.filter { $0.archiveId == archive.id }
        let actionIDs = Set(relatedActions.map(\.plannedChunkActionId))

        let allNotes = (try? context.fetch(FetchDescriptor<PlannedChunkActionNote>())) ?? []
        let allAttachments = (try? context.fetch(FetchDescriptor<PlannedChunkActionAttachment>())) ?? []
        let allContributions = (try? context.fetch(FetchDescriptor<ActionBlocksReflectionOutcomeContribution>())) ?? []
        for row in allNotes where actionIDs.contains(row.plannedChunkActionId) {
            context.delete(row)
        }
        for row in allAttachments where actionIDs.contains(row.plannedChunkActionId) {
            context.delete(row)
        }
        for row in allContributions where row.archiveId == archive.id {
            context.delete(row)
        }
        for row in relatedActions {
            context.delete(row)
        }
        for row in relatedOutcomes {
            context.delete(row)
        }
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
