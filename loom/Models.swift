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
  var archivedAt: Date

  init(
    id: UUID = .init(),
    visionSnapshot: String = "",
    purposeSnapshot: String = "",
    archivedAt: Date = .init()
  ) {
    self.id               = id
    self.visionSnapshot   = visionSnapshot
    self.purposeSnapshot  = purposeSnapshot
    self.archivedAt       = archivedAt
  }
}

// ——— NEW: Passions model ———
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

// ——— NEW: PassionArchive model ———
@Model
final class PassionArchive {
  @Attribute(.unique) var id: UUID
  var date: Date
  var emotion: String
  var passionSnapshot: String
  var archivedAt: Date

  init(
    id: UUID = .init(),
    date: Date,
    emotion: String,
    passionSnapshot: String,
    archivedAt: Date = .init()
  ) {
    self.id              = id
    self.date            = date
    self.emotion         = emotion
    self.passionSnapshot = passionSnapshot
    self.archivedAt      = archivedAt
  }
}
