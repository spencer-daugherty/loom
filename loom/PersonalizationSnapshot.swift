import Foundation

struct PersonalizationSnapshot: Codable, Identifiable, Hashable, Sendable {
    var id: UUID
    var createdAt: Date
    var stressSource: String
    var breakPoint: String
    var lifeAreasSelected: [String]
    var planningReality: String
    var desiredChange: String
    var derivedTags: [String]

    init(
        id: UUID = UUID(),
        createdAt: Date = Date(),
        stressSource: String,
        breakPoint: String,
        lifeAreasSelected: [String],
        planningReality: String,
        desiredChange: String,
        derivedTags: [String]? = nil
    ) {
        self.id = id
        self.createdAt = createdAt
        self.stressSource = stressSource
        self.breakPoint = breakPoint
        self.lifeAreasSelected = Self.uniqueOrdered(lifeAreasSelected)
        self.planningReality = planningReality
        self.desiredChange = desiredChange
        self.derivedTags = derivedTags ?? Self.deriveTags(
            stressSource: stressSource,
            breakPoint: breakPoint,
            planningReality: planningReality,
            desiredChange: desiredChange,
            lifeAreasSelected: lifeAreasSelected
        )
    }

    static func deriveTags(
        stressSource: String,
        breakPoint: String,
        planningReality: String,
        desiredChange: String,
        lifeAreasSelected: [String]
    ) -> [String] {
        var tags: [String] = []
        let stress = stressSource.lowercased()
        let breakpoint = breakPoint.lowercased()
        let planning = planningReality.lowercased()
        let change = desiredChange.lowercased()
        let areas = lifeAreasSelected.map { $0.lowercased() }

        if stress.contains("too many priorities") || stress.contains("behind") || stress.contains("disorganized") {
            tags.append("overwhelmed")
        }
        if stress.contains("distractions") {
            tags.append("distracted")
        }
        if stress.contains("work pressure") {
            tags.append("work_pressure")
        }
        if stress.contains("money pressure") {
            tags.append("financial_pressure")
        }
        if stress.contains("low energy") || stress.contains("health") {
            tags.append("low_energy")
        }
        if stress.contains("relationship tension") {
            tags.append("relationship_stress")
        }

        if breakpoint.contains("don’t start") || breakpoint.contains("don't start") {
            tags.append("activation_gap")
        }
        if breakpoint.contains("lose momentum") {
            tags.append("momentum_drop")
        }
        if breakpoint.contains("distracted") {
            tags.append("focus_drift")
        }
        if breakpoint.contains("overthink") {
            tags.append("overthinking")
        }
        if breakpoint.contains("don’t finish") || breakpoint.contains("don't finish") {
            tags.append("completion_gap")
        }

        if planning.contains("react to what’s urgent") || planning.contains("react to what's urgent") {
            tags.append("reactive")
        }
        if planning.contains("get off track") {
            tags.append("off_track")
        }
        if planning.contains("follow through consistently") {
            tags.append("consistent")
        }

        if change.contains("control") {
            tags.append("wants_control")
        }
        if change.contains("clear direction") {
            tags.append("wants_clarity")
        }
        if change.contains("consistency") {
            tags.append("wants_consistency")
        }
        if change.contains("faster progress") {
            tags.append("wants_progress")
        }
        if change.contains("balanced") {
            tags.append("wants_balance")
        }

        if areas.contains(where: { $0.contains("productivity") }) {
            tags.append("productivity_area")
        }
        if areas.contains(where: { $0.contains("career") || $0.contains("business") }) {
            tags.append("career_area")
        }
        if areas.contains(where: { $0.contains("wealth") || $0.contains("finance") }) {
            tags.append("finance_area")
        }
        if areas.contains(where: { $0.contains("health") }) {
            tags.append("health_area")
        }
        if areas.contains(where: { $0.contains("relationships") || $0.contains("love") }) {
            tags.append("relationships_area")
        }

        return uniqueOrdered(tags)
    }

    private static func uniqueOrdered(_ values: [String]) -> [String] {
        var seen = Set<String>()
        return values
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .filter { seen.insert($0.lowercased()).inserted }
    }
}

struct PersonalizationDraft: Codable, Hashable, Sendable {
    var stressSource: String?
    var breakPoint: String?
    var lifeAreasSelected: [String]
    var planningReality: String?
    var desiredChange: String?

    init(
        stressSource: String? = nil,
        breakPoint: String? = nil,
        lifeAreasSelected: [String] = [],
        planningReality: String? = nil,
        desiredChange: String? = nil
    ) {
        self.stressSource = stressSource
        self.breakPoint = breakPoint
        self.lifeAreasSelected = lifeAreasSelected
        self.planningReality = planningReality
        self.desiredChange = desiredChange
    }

    init(snapshot: PersonalizationSnapshot) {
        self.stressSource = snapshot.stressSource
        self.breakPoint = snapshot.breakPoint
        self.lifeAreasSelected = snapshot.lifeAreasSelected
        self.planningReality = snapshot.planningReality
        self.desiredChange = snapshot.desiredChange
    }

    var isComplete: Bool {
        snapshotValue() != nil
    }

    func snapshotValue(createdAt: Date = Date()) -> PersonalizationSnapshot? {
        guard let stressSource = stressSource?.trimmingCharacters(in: .whitespacesAndNewlines), !stressSource.isEmpty,
              let breakPoint = breakPoint?.trimmingCharacters(in: .whitespacesAndNewlines), !breakPoint.isEmpty,
              let planningReality = planningReality?.trimmingCharacters(in: .whitespacesAndNewlines), !planningReality.isEmpty,
              let desiredChange = desiredChange?.trimmingCharacters(in: .whitespacesAndNewlines), !desiredChange.isEmpty else {
            return nil
        }

        let cleanAreas = lifeAreasSelected
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard cleanAreas.count >= 3 && cleanAreas.count <= 7 else {
            return nil
        }

        return PersonalizationSnapshot(
            createdAt: createdAt,
            stressSource: stressSource,
            breakPoint: breakPoint,
            lifeAreasSelected: cleanAreas,
            planningReality: planningReality,
            desiredChange: desiredChange
        )
    }
}

struct PersonalizationContextValue: Codable, Hashable, Sendable {
    var current: PersonalizationSnapshot
    var recentChanges: [String]
}

enum PersonalizationHistoryDiff {
    static func summary(
        from older: PersonalizationSnapshot,
        to newer: PersonalizationSnapshot,
        maxParts: Int = 2
    ) -> String {
        let parts = changeParts(from: older, to: newer)
        if parts.isEmpty { return "No major changes" }
        return parts.prefix(maxParts).joined(separator: " • ")
    }

    static func recentChanges(
        current: PersonalizationSnapshot?,
        history: [PersonalizationSnapshot],
        limit: Int
    ) -> [String] {
        guard let current else { return [] }
        var summaries: [String] = []
        var newer = current
        for older in history.sorted(by: { $0.createdAt > $1.createdAt }).prefix(limit) {
            let diff = summary(from: older, to: newer, maxParts: 1)
            summaries.append("\(relativeDatePrefix(older.createdAt)): \(diff)")
            newer = older
        }
        return summaries
    }

    private static func changeParts(from older: PersonalizationSnapshot, to newer: PersonalizationSnapshot) -> [String] {
        var parts: [String] = []
        if older.stressSource != newer.stressSource {
            parts.append("Stress changed")
        }
        if older.breakPoint != newer.breakPoint {
            parts.append("Break point changed")
        }
        if older.planningReality != newer.planningReality {
            parts.append("Planning reality changed")
        }
        if older.desiredChange != newer.desiredChange {
            parts.append("Desired change updated")
        }

        let olderSet = Set(older.lifeAreasSelected.map { $0.lowercased() })
        let newerSet = Set(newer.lifeAreasSelected.map { $0.lowercased() })
        if olderSet != newerSet {
            let added = newer.lifeAreasSelected.filter { !olderSet.contains($0.lowercased()) }
            let removed = older.lifeAreasSelected.filter { !newerSet.contains($0.lowercased()) }
            if !added.isEmpty {
                parts.append("Added \(added.prefix(2).joined(separator: ", "))")
            }
            if !removed.isEmpty {
                parts.append("Removed \(removed.prefix(2).joined(separator: ", "))")
            }
            if added.isEmpty && removed.isEmpty {
                parts.append("Life areas changed")
            }
        }
        return parts
    }

    private static func relativeDatePrefix(_ date: Date) -> String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: date, relativeTo: Date())
    }
}
