import Foundation
import SwiftData

enum RecentlyDeletedStore {
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
        context.delete(model)
    }

    static func restore(_ item: RecentlyDeletedItem, in context: ModelContext) -> Bool {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601

        switch item.entityType {
        case "Outcomes":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(OutcomeSnapshot.self, from: data),
                let outcomeUUID = UUID(uuidString: item.entityID)
            else { return false }

            context.insert(
                Outcomes(
                    outcome_id: outcomeUUID,
                    category: decoded.category,
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
            return true

        case "RollingCaptureItem":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(CaptureSnapshot.self, from: data),
                let id = UUID(uuidString: item.entityID)
            else { return false }

            let normalized = decoded.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            let existingCapture = (try? context.fetch(FetchDescriptor<RollingCaptureItem>())) ?? []
            if existingCapture.contains(where: { $0.text.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() == normalized }) {
                context.delete(item)
                return true
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
            return true

        case "CompletedOutcomeArchive":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(CompletedOutcomeArchiveSnapshot.self, from: data)
            else { return false }

            let existingArchives = (try? context.fetch(FetchDescriptor<CompletedOutcomeArchive>())) ?? []
            if existingArchives.contains(where: { $0.id == decoded.id }) {
                context.delete(item)
                return true
            }

            context.insert(
                CompletedOutcomeArchive(
                    id: decoded.id,
                    originalOutcomeId: decoded.originalOutcomeId,
                    category: decoded.category,
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
            return true

        default:
            return false
        }
    }

    static func purgeExpired(in context: ModelContext) {
        let rows = (try? context.fetch(FetchDescriptor<RecentlyDeletedItem>())) ?? []
        let now = Date()
        for row in rows where row.purgeAt <= now {
            context.delete(row)
        }
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

        return nil
    }

    private static func shortDate(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateStyle = .medium
        return f.string(from: date)
    }
}
