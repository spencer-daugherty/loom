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
final class ReplacedFulfillmentCategoryArchive {
  @Attribute(.unique) var id: UUID
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

  init(
    id: UUID = .init(),
    category_id: UUID,
    category: String = "",
    category_identitiy: String = "",
    category_vision: String = "",
    category_purpose: String = "",
    rolesCSV: String = "",
    fociCSV: String = "",
    resourcesCSV: String = "",
    passionsCSV: String = "",
    replacedAt: Date = .init()
  ) {
    self.id = id
    self.category_id = category_id
    self.category = category
    self.category_identitiy = category_identitiy
    self.category_vision = category_vision
    self.category_purpose = category_purpose
    self.rolesCSV = rolesCSV
    self.fociCSV = fociCSV
    self.resourcesCSV = resourcesCSV
    self.passionsCSV = passionsCSV
    self.replacedAt = replacedAt
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
    var unit: String?
    var decimalPlaces: Int?

    init(
        outcome_id: UUID,
        measure: Double,
        measuredAt: Date = .now,
        measure_amt: Double,
        measure_updated: Date = .now,
        direction: String? = nil,
        format: String? = nil,
        unit: String? = nil,
        decimalPlaces: Int? = nil
    ) {
        self.outcome_id = outcome_id
        self.measure = measure
        self.measuredAt = measuredAt
        self.measure_amt = measure_amt
        self.measure_updated = measure_updated
        self.direction = direction
        self.format = format
        self.unit = unit
        self.decimalPlaces = decimalPlaces
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
    var unit: String?
    var decimalPlaces: Int?

    init(
        outcome_id: UUID,
        measure: Double,
        measuredAt: Date,
        measure_amt: Double,
        measure_updated: Date,
        archivedAt: Date = .now,
        direction: String? = nil,
        format: String? = nil,
        unit: String? = nil,
        decimalPlaces: Int? = nil
    ) {
        self.outcome_id = outcome_id
        self.measure = measure
        self.measuredAt = measuredAt
        self.measure_amt = measure_amt
        self.measure_updated = measure_updated
        self.archivedAt = archivedAt
        self.direction = direction
        self.format = format
        self.unit = unit
        self.decimalPlaces = decimalPlaces
    }
}

@Model
final class OutcomesMeasureEntry {
    @Attribute(.unique) var id: UUID
    var outcome_id: UUID
    var measure: Double
    var measure_amt: Double
    var measuredAt: Date
    var createdAt: Date
    var format: String?
    var unit: String?
    var decimalPlaces: Int?

    init(
        id: UUID = .init(),
        outcome_id: UUID,
        measure: Double,
        measure_amt: Double,
        measuredAt: Date = .now,
        createdAt: Date = .now,
        format: String? = nil,
        unit: String? = nil,
        decimalPlaces: Int? = nil
    ) {
        self.id = id
        self.outcome_id = outcome_id
        self.measure = measure
        self.measure_amt = measure_amt
        self.measuredAt = measuredAt
        self.createdAt = createdAt
        self.format = format
        self.unit = unit
        self.decimalPlaces = decimalPlaces
    }
}

@Model
final class OutcomeAnalyticsEvent {
    @Attribute(.unique) var id: UUID
    var outcome_id: UUID
    /// "measure_deleted", "goal_changed", "target_changed"
    var eventType: String
    var occurredAt: Date

    var measuredAt: Date?
    var oldMeasure: Double?
    var newMeasure: Double?
    var oldGoal: Double?
    var newGoal: Double?
    var oldTargetDate: Date?
    var newTargetDate: Date?
    var source: String?

    init(
        id: UUID = .init(),
        outcome_id: UUID,
        eventType: String,
        occurredAt: Date = .now,
        measuredAt: Date? = nil,
        oldMeasure: Double? = nil,
        newMeasure: Double? = nil,
        oldGoal: Double? = nil,
        newGoal: Double? = nil,
        oldTargetDate: Date? = nil,
        newTargetDate: Date? = nil,
        source: String? = nil
    ) {
        self.id = id
        self.outcome_id = outcome_id
        self.eventType = eventType
        self.occurredAt = occurredAt
        self.measuredAt = measuredAt
        self.oldMeasure = oldMeasure
        self.newMeasure = newMeasure
        self.oldGoal = oldGoal
        self.newGoal = newGoal
        self.oldTargetDate = oldTargetDate
        self.newTargetDate = newTargetDate
        self.source = source
    }
}

@Model
final class CompletedOutcomeArchive {
    @Attribute(.unique) var id: UUID
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

    init(
        id: UUID = .init(),
        originalOutcomeId: UUID,
        category: String,
        outcome: String,
        reasons: String,
        start: Date,
        end: Date,
        completedAt: Date = .now,
        format: String? = nil,
        isMeasurable: Bool,
        goalValue: Double? = nil,
        finalValue: Double? = nil,
        goalMet: Bool,
        successLevel: Int? = nil,
        daysElapsed: Int,
        goalPushCount: Int,
        dataEntryCount: Int,
        targetChangeCount: Int,
        journalWins: String,
        journalLearned: String,
        journalNext: String
    ) {
        self.id = id
        self.originalOutcomeId = originalOutcomeId
        self.category = category
        self.outcome = outcome
        self.reasons = reasons
        self.start = start
        self.end = end
        self.completedAt = completedAt
        self.format = format
        self.isMeasurable = isMeasurable
        self.goalValue = goalValue
        self.finalValue = finalValue
        self.goalMet = goalMet
        self.successLevel = successLevel
        self.daysElapsed = daysElapsed
        self.goalPushCount = goalPushCount
        self.dataEntryCount = dataEntryCount
        self.targetChangeCount = targetChangeCount
        self.journalWins = journalWins
        self.journalLearned = journalLearned
        self.journalNext = journalNext
    }
}

@Model
final class CompletedOutcomeContributionArchive {
    @Attribute(.unique) var id: UUID
    var completedOutcomeArchiveId: UUID
    var actionText: String
    var completedAt: Date

    init(
        id: UUID = .init(),
        completedOutcomeArchiveId: UUID,
        actionText: String,
        completedAt: Date
    ) {
        self.id = id
        self.completedOutcomeArchiveId = completedOutcomeArchiveId
        self.actionText = actionText
        self.completedAt = completedAt
    }
}

@Model
final class CompletedOutcomeMeasurePointArchive {
    @Attribute(.unique) var id: UUID
    var completedOutcomeArchiveId: UUID
    var measuredAt: Date
    var measure: Double
    var goal: Double

    init(
        id: UUID = .init(),
        completedOutcomeArchiveId: UUID,
        measuredAt: Date,
        measure: Double,
        goal: Double
    ) {
        self.id = id
        self.completedOutcomeArchiveId = completedOutcomeArchiveId
        self.measuredAt = measuredAt
        self.measure = measure
        self.goal = goal
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

@Model
final class QuickCompletedCaptureItem {
  @Attribute(.unique) var id: UUID
  var text: String
  var completedAt: Date

  init(
    id: UUID = .init(),
    text: String,
    completedAt: Date = .now
  ) {
    self.id = id
    self.text = text
    self.completedAt = completedAt
  }
}

@Model
final class RecurringCaptureRule {
  @Attribute(.unique) var id: UUID
  var text: String
  /// "week" | "month" | "year"
  var repeatUnit: String
  var intervalCount: Int
  /// Number of days before each due date that item is sent to Capture (minimum 7).
  var captureDaysBeforeDueDate: Int = 7
  /// Calendar weekday 1...7 when repeatUnit == "week"
  var weekday: Int?
  /// Calendar day 1...31 when repeatUnit == "month" && monthlyPattern == "dayOfMonth"
  var dayOfMonth: Int?
  /// "dayOfMonth" | "ordinalWeekday" when repeatUnit == "month"
  var monthlyPattern: String
  /// "first" | "second" | "third" | "fourth" | "fifth" | "next_to_last" | "last"
  var monthOrdinal: String?
  /// "sunday"..."saturday" | "day" | "weekday" | "weekend_day"
  var monthOrdinalWeekday: String?
  /// Anchor date for interval-based repeats (e.g., bi-weekly, every 2 months, yearly on Apr 10).
  var anchorDate: Date
  var hour: Int
  var minute: Int
  var createdAt: Date
  var nextRunAt: Date
  var lastSentAt: Date?
  /// Optional date when recurring should stop sending new actions.
  var endDate: Date?
  var isActive: Bool

  init(
    id: UUID = .init(),
    text: String,
    repeatUnit: String,
    intervalCount: Int = 1,
    captureDaysBeforeDueDate: Int = 7,
    weekday: Int? = nil,
    dayOfMonth: Int? = nil,
    monthlyPattern: String = "dayOfMonth",
    monthOrdinal: String? = nil,
    monthOrdinalWeekday: String? = nil,
    anchorDate: Date = .now,
    hour: Int,
    minute: Int,
    createdAt: Date = .now,
    nextRunAt: Date,
    lastSentAt: Date? = nil,
    endDate: Date? = nil,
    isActive: Bool = true
  ) {
    self.id = id
    self.text = text
    self.repeatUnit = repeatUnit
    self.intervalCount = max(1, intervalCount)
    self.captureDaysBeforeDueDate = max(7, captureDaysBeforeDueDate)
    self.weekday = weekday
    self.dayOfMonth = dayOfMonth
    self.monthlyPattern = monthlyPattern
    self.monthOrdinal = monthOrdinal
    self.monthOrdinalWeekday = monthOrdinalWeekday
    self.anchorDate = anchorDate
    self.hour = hour
    self.minute = minute
    self.createdAt = createdAt
    self.nextRunAt = nextRunAt
    self.lastSentAt = lastSentAt
    self.endDate = endDate
    self.isActive = isActive
  }
}

@Model
final class RecurringCaptureDispatch {
  @Attribute(.unique) var id: UUID
  var ruleID: UUID
  var captureItemID: UUID
  var sentAt: Date

  init(
    id: UUID = .init(),
    ruleID: UUID,
    captureItemID: UUID,
    sentAt: Date = .now
  ) {
    self.id = id
    self.ruleID = ruleID
    self.captureItemID = captureItemID
    self.sentAt = sentAt
  }
}

@Model
final class RecentlyDeletedItem {
    @Attribute(.unique) var id: UUID
    var entityType: String
    var entityID: String
    var titleText: String
    var subtitleText: String
    var source: String
    var payloadJSON: String?
    var deletedAt: Date
    var purgeAt: Date

    init(
        id: UUID = .init(),
        entityType: String,
        entityID: String,
        titleText: String,
        subtitleText: String = "",
        source: String = "",
        payloadJSON: String? = nil,
        deletedAt: Date = .now,
        purgeAt: Date = Calendar.current.date(byAdding: .day, value: 30, to: .now) ?? .now
    ) {
        self.id = id
        self.entityType = entityType
        self.entityID = entityID
        self.titleText = titleText
        self.subtitleText = subtitleText
        self.source = source
        self.payloadJSON = payloadJSON
        self.deletedAt = deletedAt
        self.purgeAt = purgeAt
    }
}

@Model
final class PlannedChunkActionAdHocMarker {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var plannedChunkActionId: UUID
    var createdAt: Date
    @Attribute(.unique) var weekActionKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.createdAt = createdAt

        let dayKey = PlannedChunkActionAdHocMarker.dayKey(from: weekStart)
        self.weekActionKey = "\(dayKey)|\(plannedChunkActionId.uuidString)"
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

@Model
final class ActionBlocksReflectionArchive {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var startedAt: Date
    var completedAt: Date
    var savedAt: Date

    var achievementsText: String
    var magicMomentsText: String
    var powerQuestionText: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        startedAt: Date,
        completedAt: Date,
        savedAt: Date = .now,
        achievementsText: String,
        magicMomentsText: String,
        powerQuestionText: String
    ) {
        self.id = id
        self.weekStart = weekStart
        self.startedAt = startedAt
        self.completedAt = completedAt
        self.savedAt = savedAt
        self.achievementsText = achievementsText
        self.magicMomentsText = magicMomentsText
        self.powerQuestionText = powerQuestionText
    }
}

@Model
final class ActionBlocksReflectionArchiveAction {
    @Attribute(.unique) var id: UUID
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

    init(
        id: UUID = .init(),
        archiveId: UUID,
        weekStart: Date,
        plannedChunkId: UUID,
        plannedChunkActionId: UUID,
        chunkLabel: String,
        chunkCategory: String,
        resultText: String? = nil,
        purposeText: String? = nil,
        actionText: String,
        statusRaw: String,
        isMust: Bool,
        durationMinutes: Int?,
        leverageKindRaw: String? = nil,
        leverageValue: String? = nil,
        placeNamesCSV: String = "",
        hasNote: Bool = false,
        linkAttachmentCount: Int = 0,
        fileAttachmentCount: Int = 0
    ) {
        self.id = id
        self.archiveId = archiveId
        self.weekStart = weekStart
        self.plannedChunkId = plannedChunkId
        self.plannedChunkActionId = plannedChunkActionId
        self.chunkLabel = chunkLabel
        self.chunkCategory = chunkCategory
        self.resultText = resultText
        self.purposeText = purposeText
        self.actionText = actionText
        self.statusRaw = statusRaw
        self.isMust = isMust
        self.durationMinutes = durationMinutes
        self.leverageKindRaw = leverageKindRaw
        self.leverageValue = leverageValue
        self.placeNamesCSV = placeNamesCSV
        self.hasNote = hasNote
        self.linkAttachmentCount = linkAttachmentCount
        self.fileAttachmentCount = fileAttachmentCount
    }
}

@Model
final class ActionBlocksReflectionArchiveOutcome {
    @Attribute(.unique) var id: UUID
    var archiveId: UUID
    var weekStart: Date
    var plannedChunkId: UUID
    var outcomeId: UUID
    var outcomeText: String
    var category: String

    init(
        id: UUID = .init(),
        archiveId: UUID,
        weekStart: Date,
        plannedChunkId: UUID,
        outcomeId: UUID,
        outcomeText: String,
        category: String
    ) {
        self.id = id
        self.archiveId = archiveId
        self.weekStart = weekStart
        self.plannedChunkId = plannedChunkId
        self.outcomeId = outcomeId
        self.outcomeText = outcomeText
        self.category = category
    }
}

@Model
final class ActionBlocksReflectionOutcomeContribution {
    @Attribute(.unique) var id: UUID
    var archiveId: UUID
    var weekStart: Date
    var outcomeId: UUID
    var plannedChunkActionId: UUID
    var actionText: String
    var completedAt: Date

    init(
        id: UUID = .init(),
        archiveId: UUID,
        weekStart: Date,
        outcomeId: UUID,
        plannedChunkActionId: UUID,
        actionText: String,
        completedAt: Date
    ) {
        self.id = id
        self.archiveId = archiveId
        self.weekStart = weekStart
        self.outcomeId = outcomeId
        self.plannedChunkActionId = plannedChunkActionId
        self.actionText = actionText
        self.completedAt = completedAt
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

// MARK: - Step 5 (Define) persistence
/// One row per (weekStart, PlannedChunkAction.id).
/// Stores Step 5 metadata like must, time estimate, leverage, sensitivity, attachments.
@Model
final class PlannedChunkActionDefineState {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkActionId: UUID

    /// Mirrors the action order (1-based or 0-based is up to you; we store 0-based to match sortOrder).
    var rank: Int

    /// “Must” / priority star.
    var isMust: Bool

    /// Optional time estimate in minutes.
    var timeEstimateMinutes: Int?

    /// Sensitivity: time-of-day flags
    var sensitiveMorning: Bool
    var sensitiveAfternoon: Bool
    var sensitiveEvening: Bool

    var updatedAt: Date

    /// Unique key: "\(dayKey)|\(plannedChunkActionId)"
    @Attribute(.unique) var weekActionKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        rank: Int = 0,
        isMust: Bool = false,
        timeEstimateMinutes: Int? = nil,
        sensitiveMorning: Bool = true,
        sensitiveAfternoon: Bool = true,
        sensitiveEvening: Bool = true,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.rank = rank
        self.isMust = isMust
        self.timeEstimateMinutes = timeEstimateMinutes
        self.sensitiveMorning = sensitiveMorning
        self.sensitiveAfternoon = sensitiveAfternoon
        self.sensitiveEvening = sensitiveEvening
        self.updatedAt = updatedAt

        let dayKey = PlannedChunkActionDefineState.dayKey(from: weekStart)
        self.weekActionKey = "\(dayKey)|\(plannedChunkActionId.uuidString)"
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

enum ActionLeverageKind: String, Codable, CaseIterable, Identifiable {
    case person
    case tool

    var id: String { rawValue }

    var title: String {
        switch self {
        case .person: return "Person"
        case .tool: return "Tool"
        }
    }
}

enum ActionAttachmentKind: String, Codable, CaseIterable, Identifiable {
    case link
    case note
    case file

    var id: String { rawValue }
}

enum ActionExecutionStatus: String, Codable, CaseIterable, Identifiable {
    case noAction
    case leveraged
    case inProgress
    case done
    case carriedToCapture
    case notNeeded

    var id: String { rawValue }
}

/// Per-action execution status for ActionView.
/// One row per (weekStart, PlannedChunkAction.id).
@Model
final class PlannedChunkActionExecutionState {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var plannedChunkActionId: UUID
    var statusRaw: String
    var updatedAt: Date

    @Attribute(.unique) var weekActionKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        statusRaw: String = ActionExecutionStatus.noAction.rawValue,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.statusRaw = statusRaw
        self.updatedAt = updatedAt

        let dayKey = PlannedChunkActionExecutionState.dayKey(from: weekStart)
        self.weekActionKey = "\(dayKey)|\(plannedChunkActionId.uuidString)"
    }

    var status: ActionExecutionStatus {
        get { ActionExecutionStatus(rawValue: statusRaw) ?? .noAction }
        set { statusRaw = newValue.rawValue }
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

/// Universal leverage resource catalog (shared across all actions).
@Model
final class LeverageResource {
    @Attribute(.unique) var id: UUID
    var kindRaw: String
    var value: String
    var createdAt: Date
    @Attribute(.unique) var kindValueKey: String

    init(
        id: UUID = .init(),
        kindRaw: String,
        value: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.kindRaw = kindRaw
        self.value = value
        self.createdAt = createdAt
        self.kindValueKey = "\(kindRaw.lowercased())|\(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
    }

    var kind: ActionLeverageKind {
        get { ActionLeverageKind(rawValue: kindRaw) ?? .person }
        set { kindRaw = newValue.rawValue }
    }
}

/// One leverage selection per action per week (optional).
@Model
final class PlannedChunkActionLeverageSelection {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var plannedChunkActionId: UUID
    var resourceId: UUID?
    var updatedAt: Date

    @Attribute(.unique) var weekActionKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        resourceId: UUID? = nil,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.resourceId = resourceId
        self.updatedAt = updatedAt

        let dayKey = PlannedChunkActionLeverageSelection.dayKey(from: weekStart)
        self.weekActionKey = "\(dayKey)|\(plannedChunkActionId.uuidString)"
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

/// Universal places catalog (shared across all actions).
@Model
final class SensitivityPlaceCatalogItem {
    @Attribute(.unique) var id: UUID
    var place: String
    var createdAt: Date
    @Attribute(.unique) var normalizedKey: String

    init(
        id: UUID = .init(),
        place: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.place = place
        self.createdAt = createdAt
        self.normalizedKey = place.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
    }
}

/// Many selected places per action per week.
@Model
final class PlannedChunkActionSensitivityPlaceLink {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var plannedChunkActionId: UUID
    var placeId: UUID
    var createdAt: Date

    @Attribute(.unique) var weekActionPlaceKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        placeId: UUID,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.placeId = placeId
        self.createdAt = createdAt

        let dayKey = PlannedChunkActionSensitivityPlaceLink.dayKey(from: weekStart)
        self.weekActionPlaceKey = "\(dayKey)|\(plannedChunkActionId.uuidString)|\(placeId.uuidString)"
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

/// Attachments per action.
/// - link: store urlString
/// - file: store security-scoped bookmark + filename
@Model
final class PlannedChunkActionAttachment {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkActionId: UUID

    var kindRaw: String

    /// Used for link
    var urlString: String?

    /// Used for file
    var fileName: String?
    var fileBookmarkData: Data?

    var createdAt: Date

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        kindRaw: String,
        urlString: String? = nil,
        fileName: String? = nil,
        fileBookmarkData: Data? = nil,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.kindRaw = kindRaw
        self.urlString = urlString
        self.fileName = fileName
        self.fileBookmarkData = fileBookmarkData
        self.createdAt = createdAt
    }

    var kind: ActionAttachmentKind {
        get { ActionAttachmentKind(rawValue: kindRaw) ?? .link }
        set { kindRaw = newValue.rawValue }
    }
}

/// Single notes field per action per week (stored as text, shown in TextEditor).
@Model
final class PlannedChunkActionNote {
    @Attribute(.unique) var id: UUID
    var weekStart: Date
    var plannedChunkActionId: UUID
    var noteText: String
    var updatedAt: Date
    @Attribute(.unique) var weekActionKey: String

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        noteText: String = "",
        updatedAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.noteText = noteText
        self.updatedAt = updatedAt

        let dayKey = PlannedChunkActionNote.dayKey(from: weekStart)
        self.weekActionKey = "\(dayKey)|\(plannedChunkActionId.uuidString)"
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

/// (Legacy) Many leverage entries per action (person/tool + value).
/// NOTE: Kept for migration/compatibility; Step 5 UI no longer uses this.
@Model
final class PlannedChunkActionLeverageItem {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkActionId: UUID

    /// "person" or "tool"
    var kindRaw: String
    var value: String

    var createdAt: Date

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        kindRaw: String,
        value: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.kindRaw = kindRaw
        self.value = value
        self.createdAt = createdAt
    }

    var kind: ActionLeverageKind {
        get { ActionLeverageKind(rawValue: kindRaw) ?? .person }
        set { kindRaw = newValue.rawValue }
    }
}

/// (Legacy) Sensitivity places per action (editable list).
/// NOTE: Kept for migration/compatibility; Step 5 UI no longer uses this.
@Model
final class PlannedChunkActionSensitivityPlace {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkActionId: UUID

    var place: String
    var createdAt: Date

    init(
        id: UUID = .init(),
        weekStart: Date,
        plannedChunkActionId: UUID,
        place: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.plannedChunkActionId = plannedChunkActionId
        self.place = place
        self.createdAt = createdAt
    }
}
