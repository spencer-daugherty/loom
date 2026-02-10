import Foundation
import SwiftData

/// A seeded/default (or future user-defined) label that can be selected in Plan Step 3.
///
/// Note:
/// - We store both IDs *and* display strings on the selection record (PlanChunkSelection)
///   so the plan retains what the user picked even if seed wording changes later.
/// - Uniqueness:
///   - `labelId` is unique (primary identifier for a label).
///   - `labelSourceKey` is unique to prevent duplicates across launches for the same `label` + `source`.
@Model
final class PlanLabel {
    @Attribute(.unique) var labelId: UUID

    /// Lowercased display label, e.g. "school"
    var label: String

    /// Must match Fulfillment.category_id semantics (stable per fulfillment category).
    var categoryId: UUID

    /// Display category name, e.g. "Career & Business"
    var category: String

    /// "default" for seeded records.
    var source: String

    /// Uniqueness helper: "\(source)|\(label)"
    @Attribute(.unique) var labelSourceKey: String

    init(
        labelId: UUID = .init(),
        label: String,
        categoryId: UUID,
        category: String,
        source: String = "default"
    ) {
        self.labelId = labelId
        self.label = label.lowercased()
        self.categoryId = categoryId
        self.category = category
        self.source = source
        self.labelSourceKey = "\(source)|\(label.lowercased())"
    }
}

/// Persists the user's Step 3 chunk "category/label" selection.
/// This is NEW persistence that Step 3 previously did not have.
///
/// We associate it to the current plan week via `weekStart`, which matches your existing
/// `WeeklyMindsetEntry.Fields.weekStart` and `ActivePlanState.weekStart` pattern.
@Model
final class PlanChunkSelection {
    @Attribute(.unique) var id: UUID

    /// Which plan week this selection belongs to.
    var weekStart: Date

    /// Which chunk (0-based) this selection applies to.
    var chunkIndex: Int

    /// Selected seeded label info (IDs + strings captured at selection time).
    var labelId: UUID?
    var label: String?
    var categoryId: UUID?
    var category: String?

    var updatedAt: Date

    /// Unique key to ensure only 1 row per (weekStart, chunkIndex).
    @Attribute(.unique) var weekChunkKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        chunkIndex: Int,
        labelId: UUID? = nil,
        label: String? = nil,
        categoryId: UUID? = nil,
        category: String? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.chunkIndex = chunkIndex
        self.labelId = labelId
        self.label = label
        self.categoryId = categoryId
        self.category = category
        self.updatedAt = updatedAt

        // Use an ISO-ish day string to keep it deterministic/human-debuggable.
        // weekStart is already normalized by WeeklyMindsetEntry.weekStart(for:).
        let dayKey = PlanChunkSelection.dayKey(from: weekStart)
        self.weekChunkKey = "\(dayKey)|\(chunkIndex)"
    }

    private static func dayKey(from date: Date) -> String {
        let cal = Calendar.current
        let comps = cal.dateComponents([.year, .month, .day], from: date)
        let y = comps.year ?? 0
        let m = comps.month ?? 0
        let d = comps.day ?? 0
        return String(format: "%04d-%02d-%02d", y, m, d)
    }
}

/// Seeding helper for Plan Step 3 label picker.
///
/// Seeds once by relying on unique constraints:
/// - PlanLabel.labelSourceKey is unique, so reinserting same default set won't duplicate.
/// Also fetches first to avoid doing extra work on every appear.
enum PlanLabelSeeder {

    /// Stable category IDs aligned with FulfillmentView's category concepts.
    ///
    /// Since FulfillmentView currently hardcodes categories and `Fulfillment.category_id`
    /// is generated per-record, there isn't a single global UUID we can derive from there.
    /// This mapping makes categoryId stable *within the PlanLabel system* and consistent
    /// with the six FulfillmentView categories by meaning/name.
    ///
    /// If later you migrate Fulfillment to use stable IDs too, you can swap these UUIDs
    /// to match without changing UI code.
    static let categoryIDs: [String: UUID] = [
        "Career & Business": UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
        "Leadership & Impact": UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
        "Wealth & Lifestyle": UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
        "Mind & Meaning": UUID(uuidString: "44444444-4444-4444-4444-444444444444")!,
        "Love & Relationships": UUID(uuidString: "55555555-5555-5555-5555-555555555555")!,
        "Health & Vitality": UUID(uuidString: "66666666-6666-6666-6666-666666666666")!,
    ]

    /// The seed dataset requested.
    static let defaultSeed: [(category: String, labels: [String])] = [
        ("Career & Business", ["school", "career", "work"]),
        ("Leadership & Impact", ["volunteering", "teaching", "advocacy"]),
        ("Wealth & Lifestyle", ["budgeting", "finance", "lifestyle", "administrative"]),
        ("Mind & Meaning", ["faith", "learning (non-work/school)", "peace", "organization"]),
        ("Love & Relationships", ["relationships", "social", "connection"]),
        ("Health & Vitality", ["health", "fitness", "vitality"]),
    ]

    static func seedDefaultsIfNeeded(in context: ModelContext) {
        // Fast check: if any default labels exist, assume seeded.
        let existingDefaultCount = (try? context.fetchCount(
            FetchDescriptor<PlanLabel>(predicate: #Predicate { $0.source == "default" })
        )) ?? 0

        guard existingDefaultCount == 0 else { return }

        for (categoryName, labels) in defaultSeed {
            guard let categoryId = categoryIDs[categoryName] else { continue }

            for rawLabel in labels {
                let normalized = rawLabel.lowercased()
                let key = "default|\(normalized)"

                // Extra safety (even though unique constraint will also protect).
                let alreadyExists = ((try? context.fetch(
                    FetchDescriptor<PlanLabel>(predicate: #Predicate { $0.labelSourceKey == key })
                )) ?? []).isEmpty == false

                if alreadyExists { continue }

                let label = PlanLabel(
                    labelId: UUID(), // stable uniqueness is enforced by labelSourceKey; this can be random per first seed
                    label: normalized,
                    categoryId: categoryId,
                    category: categoryName,
                    source: "default"
                )
                context.insert(label)
            }
        }

        try? context.save()
    }
}
