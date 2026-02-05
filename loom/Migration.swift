import Foundation
import SwiftData

enum MigrationManager {
    private static let migrationFlagKey = "OutcomeMeasurementMigrationCompleted"

    static func runIfNeeded() {
        // Ensure we run only once per install unless the flag is reset.
        if UserDefaults.standard.bool(forKey: migrationFlagKey) { return }

        guard let container = ModelContainer.default else {
            // If container isn't available yet, try again shortly.
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) { runIfNeeded() }
            return
        }

        Task { @MainActor in
            do {
                try await migrateMeasurements(using: container)
                UserDefaults.standard.set(true, forKey: migrationFlagKey)
            } catch {
                // Do not set the flag on failure; we can retry next launch.
                print("Migration failed: \(error)")
            }
        }
    }

    @MainActor
    private static func migrateMeasurements(using container: ModelContainer) async throws {
        let context = ModelContext(container)

        // Fetch existing current measures
        let currentMeasures = try context.fetch(FetchDescriptor<OutcomesMeasure>())
        // Fetch archived measures
        let archivedMeasures = try context.fetch(FetchDescriptor<OutcomesMeasureArchive>())

        // Build de-duplication map: key is (outcome_id, startOfDay(measuredAt))
        struct Key: Hashable { let outcome_id: UUID; let day: Date }
        var bestByKey: [Key: (value: Double, measuredAt: Date, direction: String?, format: String?, measureUpdated: Date?)] = [:]

        // Helper to normalize to start of day
        func startOfDay(_ date: Date) -> Date {
            Calendar.current.startOfDay(for: date)
        }

        // Consider current measures; prefer newer measure_updated
        for m in currentMeasures {
            let key = Key(outcome_id: m.outcome_id, day: startOfDay(m.measuredAt))
            let candidate = (value: m.measure, measuredAt: m.measuredAt, direction: m.direction, format: m.format, measureUpdated: m.measure_updated)
            if let existing = bestByKey[key] {
                if let eUpd = existing.measureUpdated, eUpd < m.measure_updated {
                    bestByKey[key] = candidate
                }
            } else {
                bestByKey[key] = candidate
            }
        }

        // Consider archived measures; prefer newer measure_updated
        for a in archivedMeasures {
            let key = Key(outcome_id: a.outcome_id, day: startOfDay(a.measuredAt))
            let candidate = (value: a.measure, measuredAt: a.measuredAt, direction: a.direction, format: a.format, measureUpdated: a.measure_updated)
            if let existing = bestByKey[key] {
                if let eUpd = existing.measureUpdated, eUpd < a.measure_updated {
                    bestByKey[key] = candidate
                }
            } else {
                bestByKey[key] = candidate
            }
        }

        // Insert OutcomeMeasurement for each best entry if not already present
        let existingNew = try context.fetch(FetchDescriptor<OutcomeMeasurement>())
        var existingIndex: Set<Key> = []
        for nm in existingNew {
            let k = Key(outcome_id: nm.outcome_id, day: startOfDay(nm.measuredAt))
            existingIndex.insert(k)
        }

        for (key, best) in bestByKey {
            if existingIndex.contains(key) { continue }
            let new = OutcomeMeasurement(
                outcome_id: key.outcome_id,
                value: best.value,
                measuredAt: best.measuredAt,
                direction: best.direction,
                format: best.format
            )
            context.insert(new)
        }

        try context.save()
    }
}
