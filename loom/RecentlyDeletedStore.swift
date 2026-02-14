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

    private struct CaptureSnapshot: Codable {
        var text: String
        var isGhost: Bool
        var createdAt: Date
        var unhideDate: Date?
        var unhiddenAt: Date?
    }

    private struct QuickCaptureSnapshot: Codable {
        var text: String
        var completedAt: Date
    }

    static func trash(_ model: any PersistentModel, in context: ModelContext, source: String = "") {
        if model is RecentlyDeletedItem {
            context.delete(model)
            return
        }

        let now = Date()
        let purgeAt = Calendar.current.date(byAdding: .day, value: 30, to: now) ?? now
        let entry = RecentlyDeletedItem(
            entityType: entityType(for: model),
            entityID: entityID(for: model),
            titleText: title(for: model),
            subtitleText: subtitle(for: model),
            source: source,
            payloadJSON: payloadJSON(for: model, in: context),
            deletedAt: now,
            purgeAt: purgeAt
        )
        context.insert(entry)
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

            let outcome = Outcomes(
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
            context.insert(outcome)

            if let m = decoded.measure {
                let measuredAt = m.measuredAt
                context.insert(
                    OutcomesMeasure(
                        outcome_id: outcomeUUID,
                        measure: m.measure,
                        measuredAt: measuredAt,
                        measure_amt: m.measureAmt,
                        measure_updated: m.measureUpdated,
                        direction: m.direction,
                        format: m.format,
                        unit: m.unit,
                        decimalPlaces: m.decimalPlaces
                    )
                )
                context.insert(
                    OutcomesMeasureEntry(
                        outcome_id: outcomeUUID,
                        measure: m.measure,
                        measure_amt: m.measureAmt,
                        measuredAt: measuredAt,
                        createdAt: .now,
                        format: m.format,
                        unit: m.unit,
                        decimalPlaces: m.decimalPlaces
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

            context.insert(
                RollingCaptureItem(
                    id: id,
                    text: decoded.text,
                    isGhost: decoded.isGhost,
                    createdAt: decoded.createdAt,
                    unhideDate: decoded.unhideDate,
                    unhiddenAt: decoded.unhiddenAt
                )
            )
            context.delete(item)
            return true

        case "QuickCompletedCaptureItem":
            guard
                let payload = item.payloadJSON,
                let data = payload.data(using: .utf8),
                let decoded = try? decoder.decode(QuickCaptureSnapshot.self, from: data),
                let id = UUID(uuidString: item.entityID)
            else { return false }

            context.insert(
                QuickCompletedCaptureItem(
                    id: id,
                    text: decoded.text,
                    completedAt: decoded.completedAt
                )
            )
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

    private static func entityType(for model: any PersistentModel) -> String {
        String(describing: type(of: model))
    }

    private static func entityID(for model: any PersistentModel) -> String {
        if let m = model as? Outcomes { return m.outcome_id.uuidString }
        if let m = model as? RollingCaptureItem { return m.id.uuidString }
        if let m = model as? QuickCompletedCaptureItem { return m.id.uuidString }
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
        if let m = model as? QuickCompletedCaptureItem { return m.text }

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
        if model is QuickCompletedCaptureItem {
            return "Quickly Completed"
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
            let latestEntry = allEntries
                .filter { $0.outcome_id == m.outcome_id }
                .max(by: { $0.measuredAt < $1.measuredAt })

            let snapMeasure = latestEntry?.measure ?? measure?.measure
            let snapMeasuredAt = latestEntry?.measuredAt ?? measure?.measuredAt
            let snapMeasureAmt = latestEntry?.measure_amt ?? measure?.measure_amt
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
                        measuredAt: snapMeasuredAt ?? .now,
                        measureAmt: snapMeasureAmt ?? 0,
                        measureUpdated: .now,
                        direction: measure?.direction,
                        format: snapFormat,
                        unit: snapUnit,
                        decimalPlaces: snapDecimals
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

        if let m = model as? QuickCompletedCaptureItem {
            let snapshot = QuickCaptureSnapshot(text: m.text, completedAt: m.completedAt)
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
