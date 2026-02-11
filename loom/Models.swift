import Foundation
import SwiftData

@Model
final class DrivingForce {
  @Attribute(.unique) var id: UUID
  var ultimateVision: String
  var ultimatePurpose: String
  var updatedAt: Date

  init(
    id: UUID = .init(),
    ultimateVision: String = "",
    ultimatePurpose: String = "",
    updatedAt: Date = .init()
  ) {
    self.id              = id
    self.ultimateVision  = ultimateVision
    self.ultimatePurpose = ultimatePurpose
    self.updatedAt       = updatedAt
  }
}

@Model
final class DrivingForceArchive {
  @Attribute(.unique) var id: UUID
  var visionSnapshot: String
  var purposeSnapshot: String
  var updatedAt: Date
  var archivedAt: Date

  init(
    id: UUID = .init(),
    visionSnapshot: String = "",
    purposeSnapshot: String = "",
    updatedAt: Date = .init(),
    archivedAt: Date = .init()
  ) {
    self.id              = id
    self.visionSnapshot  = visionSnapshot
    self.purposeSnapshot = purposeSnapshot
    self.updatedAt       = updatedAt
    self.archivedAt      = archivedAt
  }
}

@Model
final class Passion {
  @Attribute(.unique) var passion_id: UUID
  var date: Date
  /// one of "love", "vows", "thrill", "just"
  var emotion: String
  var passion: String

  init(
    passion_id: UUID = .init(),
    date: Date = .init(),
    emotion: String = "",
    passion: String = ""
  ) {
    self.passion_id = passion_id
    self.date       = date
    self.emotion    = emotion
    self.passion    = passion
  }
}

@Model
final class PassionArchive {
  @Attribute(.unique) var id: UUID
  var date: Date
  var emotion: String
  var passionSnapshot: String
  var updatedAt: Date
  var archivedAt: Date

  init(
    id: UUID = .init(),
    date: Date,
    emotion: String,
    passionSnapshot: String,
    updatedAt: Date = .init(),
    archivedAt: Date = .init()
  ) {
    self.id              = id
    self.date            = date
    self.emotion         = emotion
    self.passionSnapshot = passionSnapshot
    self.updatedAt       = updatedAt
    self.archivedAt      = archivedAt
  }
}

@Model
final class PassionFulfillmentJoin {
  @Attribute(.unique) var id: UUID
  var passion_id: UUID
  var category_id: UUID

  init(
    id: UUID = UUID(),          // ← default here
    passion_id: UUID,
    category_id: UUID
  ) {
    self.id          = id
    self.passion_id  = passion_id
    self.category_id = category_id
  }
}

@Model
final class PassionFulfillmentJoinArchive {
  @Attribute(.unique) var id: UUID
  var passion_id: UUID
  var category_id: UUID
  var updatedAt: Date
  var archivedAt: Date

  init(
    id: UUID = .init(),
    passion_id: UUID,
    category_id: UUID,
    updatedAt: Date = .init(),
    archivedAt: Date = .init()
  ) {
    self.id = id
    self.passion_id = passion_id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.archivedAt = archivedAt
  }
}

@Model
final class Fulfillment {
  @Attribute(.unique) var category_id: UUID
  var updatedAt: Date
  var category: String
  var category_identitiy: String
  var category_vision: String
  var category_purpose: String

  init(
    category_id: UUID = .init(),
    updatedAt: Date = .init(),
    category: String = "",
    category_identitiy: String = "",
    category_vision: String = "",
    category_purpose: String = ""
  ) {
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.category = category
    self.category_identitiy = category_identitiy
    self.category_vision = category_vision
    self.category_purpose = category_purpose
  }
}

@Model
final class FulfillmentArchive {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var category: String
  var category_identitiy: String
  var category_vision: String
  var category_purpose: String
  var archivedAt: Date

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    category: String = "",
    category_identitiy: String = "",
    category_vision: String = "",
    category_purpose: String = "",
    archivedAt: Date = .init()
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.category = category
    self.category_identitiy = category_identitiy
    self.category_vision = category_vision
    self.category_purpose = category_purpose
    self.archivedAt = archivedAt
  }
}

@Model
final class FulfillmentRoles {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var role: String
  var rank: Int

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    role: String = "",
    rank: Int = 0
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.role = role
    self.rank = rank
  }
}

@Model
final class FulfillmentRolesArchive {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var role: String
  var rank: Int
  var archivedAt: Date

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    role: String = "",
    rank: Int = 0,
    archivedAt: Date = .init()
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.role = role
    self.rank = rank
    self.archivedAt = archivedAt
  }
}

@Model
final class FulfillmentFocus {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var activity: String
  var rank: Int

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    activity: String = "",
    rank: Int = 0
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.activity = activity
    self.rank = rank
  }
}

@Model
final class FulfillmentFocusArchive {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var activity: String
  var rank: Int
  var archivedAt: Date

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    activity: String = "",
    rank: Int = 0,
    archivedAt: Date = .init()
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.activity = activity
    self.rank = rank
    self.archivedAt = archivedAt
  }
}

@Model
final class FulfillmentResources {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var resource: String
  var rank: Int

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    resource: String = "",
    rank: Int = 0
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.resource = resource
    self.rank = rank
  }
}

@Model
final class FulfillmentResourcesArchive {
  @Attribute(.unique) var id: UUID
  var category_id: UUID
  var updatedAt: Date
  var resource: String
  var rank: Int
  var archivedAt: Date

  init(
    id: UUID = .init(),
    category_id: UUID,
    updatedAt: Date = .init(),
    resource: String = "",
    rank: Int = 0,
    archivedAt: Date = .init()
  ) {
    self.id = id
    self.category_id = category_id
    self.updatedAt = updatedAt
    self.resource = resource
    self.rank = rank
    self.archivedAt = archivedAt
  }
}

@Model
final class Outcomes {
    @Attribute(.unique) var outcome_id: UUID
    var category: String
    var updatedAt: Date
    var outcome: String
    var reasons: String
    var start: Date
    var end: Date
    var rank: Int
    var format: String?

    init(
        outcome_id: UUID = .init(),
        category: String,
        updatedAt: Date = .now,
        outcome: String,
        reasons: String,
        start: Date,
        end: Date,
        rank: Int,
        format: String? = nil
    ) {
        self.outcome_id = outcome_id
        self.category = category
        self.updatedAt = updatedAt
        self.outcome = outcome
        self.reasons = reasons
        self.start = start
        self.end = end
        self.rank = rank
        self.format = format
    }
}

@Model
final class OutcomesArchive {
    @Attribute(.unique) var outcome_id: UUID
    var category: String
    var updatedAt: Date
    var outcome: String
    var reasons: String
    var start: Date
    var end: Date
    var rank: Int
    var archivedAt: Date
    var format: String?

    init(
        outcome_id: UUID,
        category: String,
        updatedAt: Date,
        outcome: String,
        reasons: String,
        start: Date,
        end: Date,
        rank: Int,
        archivedAt: Date = .now,
        format: String? = nil
    ) {
        self.outcome_id = outcome_id
        self.category = category
        self.updatedAt = updatedAt
        self.outcome = outcome
        self.reasons = reasons
        self.start = start
        self.end = end
        self.rank = rank
        self.archivedAt = archivedAt
        self.format = format
    }
}

@Model
final class OutcomesMeasure {
    @Attribute(.unique) var outcome_id: UUID
    var measure: Double
    var measuredAt: Date
    var measure_amt: Double
    var measure_updated: Date
    var direction: String?
    var format: String?

    init(
        outcome_id: UUID,
        measure: Double,
        measuredAt: Date = .now,
        measure_amt: Double,
        measure_updated: Date = .now,
        direction: String? = nil,
        format: String? = nil
    ) {
        self.outcome_id = outcome_id
        self.measure = measure
        self.measuredAt = measuredAt
        self.measure_amt = measure_amt
        self.measure_updated = measure_updated
        self.direction = direction
        self.format = format
    }
}

@Model
final class OutcomesMeasureArchive {
    @Attribute(.unique) var outcome_id: UUID
    var measure: Double
    var measuredAt: Date
    var measure_amt: Double
    var measure_updated: Date
    var archivedAt: Date
    var direction: String?
    var format: String?

    init(
        outcome_id: UUID,
        measure: Double,
        measuredAt: Date,
        measure_amt: Double,
        measure_updated: Date,
        archivedAt: Date = .now,
        direction: String? = nil,
        format: String? = nil
    ) {
        self.outcome_id = outcome_id
        self.measure = measure
        self.measuredAt = measuredAt
        self.measure_amt = measure_amt
        self.measure_updated = measure_updated
        self.archivedAt = archivedAt
        self.direction = direction
        self.format = format
    }
}

// MARK: - WeeklyMindsetEntry

enum WeeklyMindsetEntry {
  /// Returns the start of the week (in the user's current calendar) for the given date.
  static func weekStart(for date: Date, calendar: Calendar = .current) -> Date {
    calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? date
  }

  @Model
  final class Fields {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var weekStart: Date
    var morningPowerQuestion: String
    var gratitude: String
    var incantation: String

    init(
      id: UUID = .init(),
      createdAt: Date = .now,
      morningPowerQuestion: String = "",
      gratitude: String = "",
      incantation: String = ""
    ) {
      self.id = id
      self.createdAt = createdAt
      // Normalize weekStart from createdAt using helper
      self.weekStart = WeeklyMindsetEntry.weekStart(for: createdAt)
      self.morningPowerQuestion = morningPowerQuestion
      self.gratitude = gratitude
      self.incantation = incantation
    }
  }
}

// MARK: - Step 4 storage

/// Stores the user's Step 4 inputs per week + planned chunk.
@Model
final class PlannedChunkStepFourState {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkId: UUID

    var resultText: String
    var roleNoteText: String

    /// Connected role for the chunk (FulfillmentRoles.id)
    var connectedRoleId: UUID?

    var updatedAt: Date

    /// Unique key to ensure only 1 row per (weekStart, plannedChunkId)
    @Attribute(.unique) var weekPlannedChunkKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkId: UUID,
        resultText: String = "",
        roleNoteText: String = "",
        connectedRoleId: UUID? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkId = plannedChunkId
        self.resultText = resultText
        self.roleNoteText = roleNoteText
        self.connectedRoleId = connectedRoleId
        self.updatedAt = updatedAt

        let dayKey = PlannedChunkStepFourState.dayKey(from: weekStart)
        self.weekPlannedChunkKey = "\(dayKey)|\(plannedChunkId.uuidString)"
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

/// Stores up to 3 connected outcomes per chunk for Step 4.
@Model
final class PlannedChunkOutcomeLink {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkId: UUID
    var outcomeId: UUID

    var createdAt: Date

    /// Unique key to ensure only 1 link per (weekStart, plannedChunkId, outcomeId)
    @Attribute(.unique) var weekChunkOutcomeKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkId: UUID,
        outcomeId: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkId = plannedChunkId
        self.outcomeId = outcomeId
        self.createdAt = createdAt

        let dayKey = PlannedChunkOutcomeLink.dayKey(from: weekStart)
        self.weekChunkOutcomeKey = "\(dayKey)|\(plannedChunkId.uuidString)|\(outcomeId.uuidString)"
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

// MARK: - ActivePlanState (Singleton)
@Model
final class ActivePlanState {
  @Attribute(.unique) var id: UUID
  var isActive: Bool
  var activatedAt: Date?
  var weekStart: Date?

  init(
    id: UUID = .init(),
    isActive: Bool = false,
    activatedAt: Date? = nil,
    weekStart: Date? = nil
  ) {
    self.id = id
    self.isActive = isActive
    self.activatedAt = activatedAt
    self.weekStart = weekStart
  }
}

extension ActivePlanState {
  /// Fetches the singleton ActivePlanState if it exists, otherwise creates, inserts, and returns a new one.
  static func fetchOrCreate(in context: ModelContext) -> ActivePlanState {
    if let existing = try? context.fetch(FetchDescriptor<ActivePlanState>()), let first = existing.first {
      return first
    } else {
      let state = ActivePlanState()
      context.insert(state)
      try? context.save()
      return state
    }
  }
}

// MARK: - Rolling Capture
@Model
final class RollingCaptureItem {
  @Attribute(.unique) var id: UUID
  var text: String
  var isGhost: Bool
  var createdAt: Date

  /// When this ghost item should become visible.
  /// (Used only while `isGhost == true`.)
  var unhideDate: Date?

  /// Optional: record of when the item was unghosted (so UI can display “Unhidden …”).
  var unhiddenAt: Date?

  init(
    id: UUID = .init(),
    text: String,
    isGhost: Bool,
    createdAt: Date = .now,
    unhideDate: Date? = nil,
    unhiddenAt: Date? = nil
  ) {
    self.id = id
    self.text = text
    self.isGhost = isGhost
    self.createdAt = createdAt
    self.unhideDate = unhideDate
    self.unhiddenAt = unhiddenAt
  }
}

// MARK: - NEW: Planned chunks (Step 3 -> Step 4 persistence)
/// A persisted chunk created in Plan Step 3 for a given plan week.
@Model
final class PlannedChunk {
    @Attribute(.unique) var id: UUID

    /// Which plan week this chunk belongs to (week start).
    var weekStart: Date

    /// Chunk index as displayed in Step 3 (0-based).
    var chunkIndex: Int

    /// Selected label/category (copied at time of planning).
    var labelId: UUID
    var label: String
    var categoryId: UUID
    var category: String

    var updatedAt: Date

    /// Unique key to ensure only 1 chunk per (weekStart, chunkIndex) if you recreate the plan.
    @Attribute(.unique) var weekChunkKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        chunkIndex: Int,
        labelId: UUID,
        label: String,
        categoryId: UUID,
        category: String,
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

        let dayKey = PlannedChunk.dayKey(from: weekStart)
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

/// A persisted action assigned into a chunk during planning (text-only; no ghost metadata).
@Model
final class PlannedChunkAction {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var chunkIndex: Int

    /// Denormalized reference: which PlannedChunk this action belongs to.
    var plannedChunkId: UUID

    var text: String
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = .init(),
        weekStart: Date,
        chunkIndex: Int,
        plannedChunkId: UUID,
        text: String,
        sortOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.chunkIndex = chunkIndex
        self.plannedChunkId = plannedChunkId
        self.text = text
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }
}

