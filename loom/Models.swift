import Foundation
import SwiftData
#if canImport(HealthKit)
import HealthKit
#endif

extension Notification.Name {
  static let littleWinsScheduleDidChange = Notification.Name("littleWinsScheduleDidChange")
  static let littleWinsOpenNewEditor = Notification.Name("littleWinsOpenNewEditor")
  static let littleWinsIntegrationDidChange = Notification.Name("littleWinsIntegrationDidChange")
  static let littleWinsPassionsDidChange = Notification.Name("littleWinsPassionsDidChange")
  static let vacationModeDidChange = Notification.Name("vacationModeDidChange")
  static let captureItemsDidChange = Notification.Name("captureItemsDidChange")
}

enum LoomDefaultsScope {
  private static let reviewDemoFlagKey = UserSessionStore.Keys.reviewDemoModeEnabled
  private static let isolatedWorkspaceKindKey = UserSessionStore.Keys.isolatedWorkspaceKind

  static func scopedKey(_ baseKey: String, defaults: UserDefaults = .standard) -> String {
    if let workspace = currentWorkspace(defaults: defaults) {
      return workspace.defaultsPrefix + baseKey
    }
    return baseKey
  }

  static func currentWorkspace(defaults: UserDefaults = .standard) -> LoomSpecialAccountWorkspace? {
    guard defaults.bool(forKey: reviewDemoFlagKey) else { return nil }
    guard let rawValue = defaults.string(forKey: isolatedWorkspaceKindKey)?
      .trimmingCharacters(in: .whitespacesAndNewlines),
      let workspace = LoomSpecialAccountWorkspace(rawValue: rawValue) else {
      return .reviewDemo
    }
    return workspace
  }

  static func clearScopedValues(
    for workspace: LoomSpecialAccountWorkspace,
    defaults: UserDefaults = .standard
  ) {
    let prefix = workspace.defaultsPrefix
    for key in defaults.dictionaryRepresentation().keys where key.hasPrefix(prefix) {
      defaults.removeObject(forKey: key)
    }
  }

  static func clearReviewDemoScopedValues(defaults: UserDefaults = .standard) {
    clearScopedValues(for: .reviewDemo, defaults: defaults)
  }

  static func clearCurrentScopedValues(defaults: UserDefaults = .standard) {
    guard let workspace = currentWorkspace(defaults: defaults) else { return }
    clearScopedValues(for: workspace, defaults: defaults)
  }
}

enum OutcomeStartingValueStore {
  private static let defaultsKey = "outcomeStartingValueEntryIDs.v1"

  private static func loadMap() -> [String: String] {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey),
          let decoded = try? JSONDecoder().decode([String: String].self, from: data) else {
      return [:]
    }
    return decoded
  }

  private static func saveMap(_ map: [String: String]) {
    guard let data = try? JSONEncoder().encode(map) else { return }
    UserDefaults.standard.set(data, forKey: LoomDefaultsScope.scopedKey(defaultsKey))
  }

  static func entryID(for outcomeID: UUID) -> UUID? {
    guard let raw = loadMap()[outcomeID.uuidString] else { return nil }
    return UUID(uuidString: raw)
  }

  static func setEntryID(_ entryID: UUID, for outcomeID: UUID) {
    var map = loadMap()
    map[outcomeID.uuidString] = entryID.uuidString
    saveMap(map)
  }

  static func clearEntryID(for outcomeID: UUID) {
    var map = loadMap()
    map.removeValue(forKey: outcomeID.uuidString)
    saveMap(map)
  }
}

struct VacationModeConfig: Codable, Equatable {
  var isEnabled: Bool
  var startDate: Date
  var returnDate: Date
  var attentionDays: Int
  var passionIDs: [UUID]

  enum CodingKeys: String, CodingKey {
    case isEnabled
    case startDate
    case returnDate
    case attentionDays
    case passionIDs
  }

  init(isEnabled: Bool, startDate: Date, returnDate: Date, attentionDays: Int = 30, passionIDs: [UUID] = []) {
    self.isEnabled = isEnabled
    self.startDate = startDate
    self.returnDate = returnDate
    self.attentionDays = attentionDays
    self.passionIDs = passionIDs
  }

  init(from decoder: Decoder) throws {
    let container = try decoder.container(keyedBy: CodingKeys.self)
    isEnabled = try container.decode(Bool.self, forKey: .isEnabled)
    startDate = try container.decode(Date.self, forKey: .startDate)
    returnDate = try container.decode(Date.self, forKey: .returnDate)
    attentionDays = try container.decodeIfPresent(Int.self, forKey: .attentionDays) ?? 30
    passionIDs = try container.decodeIfPresent([UUID].self, forKey: .passionIDs) ?? []
  }

  static var `default`: VacationModeConfig {
    let today = Calendar.current.startOfDay(for: .now)
    return VacationModeConfig(
      isEnabled: false,
      startDate: today,
      returnDate: Calendar.current.date(byAdding: .day, value: 7, to: today) ?? today,
      attentionDays: 30,
      passionIDs: []
    )
  }

  var normalized: VacationModeConfig {
    let cal = Calendar.current
    var copy = self
    copy.startDate = cal.startOfDay(for: copy.startDate)
    copy.returnDate = cal.startOfDay(for: copy.returnDate)
    if copy.returnDate < copy.startDate {
      copy.returnDate = copy.startDate
    }
    copy.attentionDays = max(7, min(60, copy.attentionDays))
    copy.passionIDs = Array(Set(copy.passionIDs)).sorted { $0.uuidString < $1.uuidString }
    return copy
  }

  func overlaps(start: Date, endExclusive: Date) -> Bool {
    let cal = Calendar.current
    let vacationStart = cal.startOfDay(for: startDate)
    let vacationEndExclusive = cal.date(byAdding: .day, value: 1, to: cal.startOfDay(for: returnDate)) ?? endExclusive
    return vacationStart < endExclusive && vacationEndExclusive > start
  }
}

@Model
final class VacationModeArchive {
  @Attribute(.unique) var id: UUID
  var startDate: Date
  var returnDate: Date
  var attentionDays: Int
  var endedAt: Date
  var endedByUser: Bool
  var passionSnapshotsJSON: String
  var createdAt: Date

  init(
    id: UUID = .init(),
    startDate: Date,
    returnDate: Date,
    attentionDays: Int,
    endedAt: Date,
    endedByUser: Bool,
    passionSnapshotsJSON: String,
    createdAt: Date = .now
  ) {
    self.id = id
    self.startDate = startDate
    self.returnDate = returnDate
    self.attentionDays = attentionDays
    self.endedAt = endedAt
    self.endedByUser = endedByUser
    self.passionSnapshotsJSON = passionSnapshotsJSON
    self.createdAt = createdAt
  }
}

enum VacationModeStore {
  private static let defaultsKey = "vacationModeConfig.v1"

  static func config() -> VacationModeConfig {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey),
          let decoded = try? JSONDecoder().decode(VacationModeConfig.self, from: data) else {
      return .default
    }
    return decoded.normalized
  }

  static func setConfig(_ config: VacationModeConfig) {
    let normalized = config.normalized
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    if let data = try? JSONEncoder().encode(normalized) {
      UserDefaults.standard.set(data, forKey: scopedKey)
    }
    NotificationCenter.default.post(name: .vacationModeDidChange, object: nil)
  }

  static func activeConfig(now: Date = .now) -> VacationModeConfig? {
    let cfg = config()
    guard cfg.isEnabled else { return nil }
    let today = Calendar.current.startOfDay(for: now)
    guard today >= Calendar.current.startOfDay(for: cfg.startDate),
          today <= Calendar.current.startOfDay(for: cfg.returnDate) else { return nil }
    return cfg
  }

  static func overlappingConfig(start: Date, endExclusive: Date) -> VacationModeConfig? {
    let cfg = config()
    guard cfg.isEnabled, cfg.overlaps(start: start, endExclusive: endExclusive) else { return nil }
    return cfg
  }
}

struct LittleWinsScheduleRule: Codable, Equatable {
  static let everyDayMask = 0b1111111
  static let `default` = LittleWinsScheduleRule(canCompleteAnyDay: true, activeWeekdayMask: everyDayMask)

  var canCompleteAnyDay: Bool
  var activeWeekdayMask: Int

  var normalized: LittleWinsScheduleRule {
    if canCompleteAnyDay {
      return .default
    }
    let masked = activeWeekdayMask & Self.everyDayMask
    return LittleWinsScheduleRule(
      canCompleteAnyDay: false,
      activeWeekdayMask: masked == 0 ? Self.everyDayMask : masked
    )
  }
}

enum LittleWinsScheduleStore {
  private static let defaultsKey = "littleWinsScheduleRules.v1"

  static func rule(for focusID: UUID) -> LittleWinsScheduleRule {
    allRules()[focusID]?.normalized ?? .default
  }

  static func allRules() -> [UUID: LittleWinsScheduleRule] {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey) else { return [:] }
    guard let raw = try? JSONDecoder().decode([String: LittleWinsScheduleRule].self, from: data) else {
      return [:]
    }
    var result: [UUID: LittleWinsScheduleRule] = [:]
    for (key, value) in raw {
      guard let id = UUID(uuidString: key) else { continue }
      result[id] = value.normalized
    }
    return result
  }

  static func setRule(_ rule: LittleWinsScheduleRule, for focusID: UUID) {
    var rules = allRules()
    let normalized = rule.normalized
    if normalized == .default {
      rules.removeValue(forKey: focusID)
    } else {
      rules[focusID] = normalized
    }
    saveAllRules(rules)
  }

  static func removeRule(for focusID: UUID) {
    var rules = allRules()
    guard rules.removeValue(forKey: focusID) != nil else { return }
    saveAllRules(rules)
  }

  static func removeRules(for focusIDs: [UUID]) {
    var rules = allRules()
    var changed = false
    for id in focusIDs {
      if rules.removeValue(forKey: id) != nil {
        changed = true
      }
    }
    if changed {
      saveAllRules(rules)
    }
  }

  private static func saveAllRules(_ rules: [UUID: LittleWinsScheduleRule]) {
    let raw = Dictionary(uniqueKeysWithValues: rules.map { ($0.key.uuidString, $0.value.normalized) })
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    if let data = try? JSONEncoder().encode(raw) {
      UserDefaults.standard.set(data, forKey: scopedKey)
    } else {
      UserDefaults.standard.removeObject(forKey: scopedKey)
    }
    NotificationCenter.default.post(name: .littleWinsScheduleDidChange, object: nil)
  }
}

struct LittleWinsIntegrationConfig: Codable, Equatable {
  enum Source: String, Codable, CaseIterable {
    case appleHealth

    var title: String {
      switch self {
      case .appleHealth: return "Apple Health"
      }
    }

    var iconName: String {
      switch self {
      case .appleHealth: return "heart"
      }
    }
  }

  enum Metric: String, Codable, CaseIterable {
    case steps
    case workoutMinutes
    case sleepHours

    var title: String {
      switch self {
      case .steps: return "Steps"
      case .workoutMinutes: return "Workout Minutes"
      case .sleepHours: return "Sleep Hours"
      }
    }

    var unitLabel: String {
      switch self {
      case .steps: return "steps"
      case .workoutMinutes: return "min"
      case .sleepHours: return "hours"
      }
    }

    var defaultTarget: Double {
      switch self {
      case .steps: return 10_000
      case .workoutMinutes: return 60
      case .sleepHours: return 7
      }
    }

    static func options(for source: Source) -> [Metric] {
      switch source {
      case .appleHealth: return [.steps, .workoutMinutes, .sleepHours]
      }
    }
  }

  var isEnabled: Bool
  var source: Source
  var metric: Metric
  var targetValue: Double
  var progressValue: Double
  var isConnected: Bool
  var updatedAtUnix: TimeInterval

  static func `default`(for source: Source) -> LittleWinsIntegrationConfig {
    let metric = Metric.options(for: source).first ?? .steps
    return LittleWinsIntegrationConfig(
      isEnabled: true,
      source: source,
      metric: metric,
      targetValue: metric.defaultTarget,
      progressValue: 0,
      isConnected: false,
      updatedAtUnix: Date().timeIntervalSince1970
    )
  }

  var normalized: LittleWinsIntegrationConfig {
    var copy = self
    if !Metric.options(for: source).contains(copy.metric) {
      copy.metric = Metric.options(for: source).first ?? .steps
    }
    copy.targetValue = max(1, copy.targetValue)
    copy.progressValue = max(0, copy.progressValue)
    return copy
  }

  var progressFraction: Double {
    guard targetValue > 0 else { return 0 }
    return min(1, max(0, progressValue / targetValue))
  }

  var isGoalAchieved: Bool {
    progressFraction >= 1
  }
}

enum LittleWinsIntegrationStore {
  private static let defaultsKey = "littleWinsIntegrationConfigs.v2"
  private static let legacyDefaultsKey = "littleWinsIntegrationConfigs.v1"

  private enum LegacySource: String, Codable {
    case appleHealth
    case screenTime
  }

  private enum LegacyMetric: String, Codable {
    case steps
    case workoutMinutes
    case sleepHours
    case socialMediaMinutes
    case totalScreenTimeMinutes
  }

  private struct LegacyConfig: Codable {
    var isEnabled: Bool
    var source: LegacySource
    var metric: LegacyMetric
    var targetValue: Double
    var progressValue: Double
    var isConnected: Bool
    var screenTimeSelectionSummary: String?
    var updatedAtUnix: TimeInterval

    func migrated() -> LittleWinsIntegrationConfig? {
      guard source == .appleHealth else { return nil }

      let migratedMetric: LittleWinsIntegrationConfig.Metric
      switch metric {
      case .steps:
        migratedMetric = .steps
      case .workoutMinutes:
        migratedMetric = .workoutMinutes
      case .sleepHours:
        migratedMetric = .sleepHours
      case .socialMediaMinutes, .totalScreenTimeMinutes:
        return nil
      }

      return LittleWinsIntegrationConfig(
        isEnabled: isEnabled,
        source: .appleHealth,
        metric: migratedMetric,
        targetValue: targetValue,
        progressValue: progressValue,
        isConnected: isConnected,
        updatedAtUnix: updatedAtUnix
      ).normalized
    }
  }

  static func config(for focusID: UUID) -> LittleWinsIntegrationConfig? {
    allConfigs()[focusID]?.normalized
  }

  static func allConfigs() -> [UUID: LittleWinsIntegrationConfig] {
    if let current = loadCurrentConfigs() {
      return current
    }
    return migrateLegacyConfigsIfNeeded()
  }

  private static func loadCurrentConfigs() -> [UUID: LittleWinsIntegrationConfig]? {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey) else { return nil }
    guard let raw = try? JSONDecoder().decode([String: LittleWinsIntegrationConfig].self, from: data) else {
      return [:]
    }
    return normalizedMap(from: raw)
  }

  private static func migrateLegacyConfigsIfNeeded() -> [UUID: LittleWinsIntegrationConfig] {
    let scopedLegacyKey = LoomDefaultsScope.scopedKey(legacyDefaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedLegacyKey) else { return [:] }
    guard let raw = try? JSONDecoder().decode([String: LegacyConfig].self, from: data) else {
      UserDefaults.standard.removeObject(forKey: scopedLegacyKey)
      return [:]
    }

    var result: [UUID: LittleWinsIntegrationConfig] = [:]
    for (key, value) in raw {
      guard let id = UUID(uuidString: key) else { continue }
      guard let migrated = value.migrated() else { continue }
      result[id] = migrated
    }
    save(result)
    UserDefaults.standard.removeObject(forKey: scopedLegacyKey)
    return result
  }

  private static func normalizedMap(from raw: [String: LittleWinsIntegrationConfig]) -> [UUID: LittleWinsIntegrationConfig] {
    var result: [UUID: LittleWinsIntegrationConfig] = [:]
    for (key, value) in raw {
      guard let id = UUID(uuidString: key) else { continue }
      result[id] = value.normalized
    }
    return result
  }

  static func setConfig(_ config: LittleWinsIntegrationConfig?, for focusID: UUID) {
    var map = allConfigs()
    if let config, config.isEnabled {
      map[focusID] = config.normalized
    } else {
      map.removeValue(forKey: focusID)
    }
    save(map)
  }

  static func removeConfig(for focusID: UUID) {
    var map = allConfigs()
    guard map.removeValue(forKey: focusID) != nil else { return }
    save(map)
  }

  private static func save(_ map: [UUID: LittleWinsIntegrationConfig]) {
    let raw = Dictionary(uniqueKeysWithValues: map.map { ($0.key.uuidString, $0.value.normalized) })
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    if let data = try? JSONEncoder().encode(raw) {
      UserDefaults.standard.set(data, forKey: scopedKey)
    } else {
      UserDefaults.standard.removeObject(forKey: scopedKey)
    }
    NotificationCenter.default.post(name: .littleWinsIntegrationDidChange, object: nil)
  }
}

enum LittleWinsPassionsStore {
  private static let defaultsKey = "littleWinsPassionLinks.v1"

  static func passionIDs(for focusID: UUID) -> Set<UUID> {
    Set(allLinks()[focusID] ?? [])
  }

  static func allLinks() -> [UUID: [UUID]] {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey) else { return [:] }
    guard let raw = try? JSONDecoder().decode([String: [String]].self, from: data) else {
      return [:]
    }
    var result: [UUID: [UUID]] = [:]
    for (focusKey, passionKeys) in raw {
      guard let focusID = UUID(uuidString: focusKey) else { continue }
      let ids = passionKeys.compactMap(UUID.init(uuidString:))
      if !ids.isEmpty {
        result[focusID] = Array(Set(ids))
      }
    }
    return result
  }

  static func setPassionIDs(_ passionIDs: Set<UUID>, for focusID: UUID) {
    var map = allLinks()
    if passionIDs.isEmpty {
      map.removeValue(forKey: focusID)
    } else {
      map[focusID] = Array(passionIDs)
    }
    save(map)
  }

  static func removePassions(for focusID: UUID) {
    var map = allLinks()
    guard map.removeValue(forKey: focusID) != nil else { return }
    save(map)
  }

  static func removePassions(for focusIDs: [UUID]) {
    var map = allLinks()
    var changed = false
    for id in focusIDs {
      if map.removeValue(forKey: id) != nil {
        changed = true
      }
    }
    if changed {
      save(map)
    }
  }

  private static func save(_ map: [UUID: [UUID]]) {
    let raw = Dictionary(uniqueKeysWithValues: map.map { focusID, passionIDs in
      (focusID.uuidString, Array(Set(passionIDs)).map(\.uuidString))
    })
    if let data = try? JSONEncoder().encode(raw) {
      UserDefaults.standard.set(data, forKey: LoomDefaultsScope.scopedKey(defaultsKey))
    } else {
      UserDefaults.standard.removeObject(forKey: LoomDefaultsScope.scopedKey(defaultsKey))
    }
    NotificationCenter.default.post(name: .littleWinsPassionsDidChange, object: nil)
  }
}

enum ReflectionPassionsStore {
  struct Snapshot: Codable, Identifiable, Hashable {
    var id: UUID { passionID }
    let passionID: UUID
    let emotion: String
    let passion: String
  }

  private static let defaultsKey = "reflection_passions_v1"

  private static func loadMap() -> [String: [Snapshot]] {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    guard let data = UserDefaults.standard.data(forKey: scopedKey),
          let decoded = try? JSONDecoder().decode([String: [Snapshot]].self, from: data) else {
      return [:]
    }
    return decoded
  }

  private static func saveMap(_ map: [String: [Snapshot]]) {
    guard let data = try? JSONEncoder().encode(map) else { return }
    UserDefaults.standard.set(data, forKey: LoomDefaultsScope.scopedKey(defaultsKey))
    NotificationCenter.default.post(name: .littleWinsPassionsDidChange, object: nil)
  }

  static func snapshots(for reflectionArchiveID: UUID) -> [Snapshot] {
    loadMap()[reflectionArchiveID.uuidString] ?? []
  }

  static func setSnapshots(_ snapshots: [Snapshot], for reflectionArchiveID: UUID) {
    var map = loadMap()
    let key = reflectionArchiveID.uuidString
    if snapshots.isEmpty {
      map.removeValue(forKey: key)
    } else {
      map[key] = snapshots
    }
    saveMap(map)
  }

  static func archiveIDs(containingAnyPassionIDs passionIDs: Set<UUID>) -> Set<UUID> {
    guard !passionIDs.isEmpty else { return [] }
    let map = loadMap()
    var result = Set<UUID>()
    for (key, snapshots) in map {
      let snapshotIDs = Set(snapshots.map(\.passionID))
      if !snapshotIDs.isDisjoint(with: passionIDs), let archiveID = UUID(uuidString: key) {
        result.insert(archiveID)
      }
    }
    return result
  }
}

#if canImport(HealthKit)
enum LittleWinsHealthKitBridge {
  private static let store = HKHealthStore()

  private enum BridgeError: LocalizedError {
    case unavailable
    case typeUnavailable
    case authorizationDenied

    var errorDescription: String? {
      switch self {
      case .unavailable:
        return "Apple Health is not available on this device."
      case .typeUnavailable:
        return "The Apple Health data type is unavailable."
      case .authorizationDenied:
        return "Apple Health access was denied. Open Health app > Sharing > Apps > Loom and allow data access."
      }
    }
  }

  static func requestAuthorizationForLittleWins(completion: @escaping (Result<Void, Error>) -> Void) {
    guard HKHealthStore.isHealthDataAvailable() else {
      completion(.failure(BridgeError.unavailable))
      return
    }
    let readTypes = littleWinsReadTypes()
    guard !readTypes.isEmpty else {
      completion(.failure(BridgeError.typeUnavailable))
      return
    }
    store.requestAuthorization(toShare: nil, read: readTypes) { success, error in
      if let error {
        completion(.failure(error))
      } else if success {
        verifyLittleWinsReadAuthorization(completion: completion)
      } else {
        completion(.failure(BridgeError.authorizationDenied))
      }
    }
  }

  private static func verifyLittleWinsReadAuthorization(completion: @escaping (Result<Void, Error>) -> Void) {
    let metricsToProbe: [LittleWinsIntegrationConfig.Metric] = [.steps, .workoutMinutes, .sleepHours]
    var sawAuthorizationDenied = false

    func attempt(_ index: Int, _ lastError: Error?) {
      guard index < metricsToProbe.count else {
        if sawAuthorizationDenied {
          completion(.failure(BridgeError.authorizationDenied))
        } else if let lastError {
          completion(.failure(lastError))
        } else {
          completion(.success(()))
        }
        return
      }

      readTodayProgress(for: metricsToProbe[index]) { result in
        switch result {
        case .success:
          completion(.success(()))
        case .failure(let error):
          if isAuthorizationDenied(error) {
            sawAuthorizationDenied = true
          }
          attempt(index + 1, error)
        }
      }
    }

    attempt(0, nil)
  }

  static func isAuthorizationDenied(_ error: Error) -> Bool {
    if let bridgeError = error as? BridgeError, case .authorizationDenied = bridgeError {
      return true
    }
    if containsHealthKitAuthorizationDenied(error) {
      return true
    }
    return false
  }

  private static func containsHealthKitAuthorizationDenied(_ error: Error) -> Bool {
    let nsError = error as NSError
    if nsError.domain == HKErrorDomain,
       nsError.code == HKError.Code.errorAuthorizationDenied.rawValue {
      return true
    }
    if let underlying = nsError.userInfo[NSUnderlyingErrorKey] as? Error {
      return containsHealthKitAuthorizationDenied(underlying)
    }
    return false
  }

  static func readTodayProgress(
    for metric: LittleWinsIntegrationConfig.Metric,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    readProgress(for: metric, on: Date(), completion: completion)
  }

  static func readProgress(
    for metric: LittleWinsIntegrationConfig.Metric,
    on day: Date,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    switch metric {
    case .steps:
      readSteps(on: day, completion: completion)
    case .workoutMinutes:
      readWorkoutMinutes(on: day, completion: completion)
    case .sleepHours:
      readSleepHours(on: day, completion: completion)
    }
  }

  private static func littleWinsReadTypes() -> Set<HKObjectType> {
    var types = Set<HKObjectType>()
    if let stepsType = HKObjectType.quantityType(forIdentifier: .stepCount) {
      types.insert(stepsType)
    }
    types.insert(HKObjectType.workoutType())
    if let sleepType = HKObjectType.categoryType(forIdentifier: .sleepAnalysis) {
      types.insert(sleepType)
    }
    return types
  }

  private static func dayBounds(for day: Date) -> (start: Date, end: Date) {
    let calendar = Calendar.current
    let start = calendar.startOfDay(for: day)
    let nextStart = calendar.date(byAdding: .day, value: 1, to: start) ?? start.addingTimeInterval(86400)
    let now = Date()
    let end = min(nextStart, now)
    return (start, end)
  }

  private static func readSteps(on day: Date, completion: @escaping (Result<Double, Error>) -> Void) {
    guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else {
      completion(.failure(BridgeError.typeUnavailable))
      return
    }
    let bounds = dayBounds(for: day)
    let predicate = HKQuery.predicateForSamples(withStart: bounds.start, end: bounds.end, options: .strictStartDate)
    let query = HKStatisticsQuery(quantityType: type, quantitySamplePredicate: predicate, options: .cumulativeSum) { _, result, error in
      if let error {
        completion(.failure(error))
        return
      }
      let value = result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0
      completion(.success(value))
    }
    store.execute(query)
  }

  private static func readWorkoutMinutes(on day: Date, completion: @escaping (Result<Double, Error>) -> Void) {
    let bounds = dayBounds(for: day)
    let predicate = HKQuery.predicateForSamples(withStart: bounds.start, end: bounds.end, options: .strictStartDate)
    let query = HKSampleQuery(
      sampleType: HKObjectType.workoutType(),
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, error in
      if let error {
        completion(.failure(error))
        return
      }
      let workouts = (samples as? [HKWorkout]) ?? []
      let totalMinutes = workouts.reduce(0.0) { $0 + ($1.duration / 60.0) }
      completion(.success(totalMinutes))
    }
    store.execute(query)
  }

  private static func readSleepHours(on day: Date, completion: @escaping (Result<Double, Error>) -> Void) {
    guard let type = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else {
      completion(.failure(BridgeError.typeUnavailable))
      return
    }
    let bounds = dayBounds(for: day)
    let predicate = HKQuery.predicateForSamples(withStart: bounds.start, end: bounds.end, options: [])
    let query = HKSampleQuery(
      sampleType: type,
      predicate: predicate,
      limit: HKObjectQueryNoLimit,
      sortDescriptors: nil
    ) { _, samples, error in
      if let error {
        completion(.failure(error))
        return
      }
      let categories = (samples as? [HKCategorySample]) ?? []
      let totalSeconds = categories.reduce(0.0) { partial, sample in
        if sample.value == HKCategoryValueSleepAnalysis.inBed.rawValue {
          return partial
        }
        let overlapStart = max(sample.startDate, bounds.start)
        let overlapEnd = min(sample.endDate, bounds.end)
        let overlap = overlapEnd.timeIntervalSince(overlapStart)
        return partial + max(0, overlap)
      }
      completion(.success(totalSeconds / 3600.0))
    }
    store.execute(query)
  }
}
#else
enum LittleWinsHealthKitBridge {
  private enum BridgeError: LocalizedError {
    case unavailable
    var errorDescription: String? { "Apple Health is not available on this device." }
  }

  static func requestAuthorizationForLittleWins(completion: @escaping (Result<Void, Error>) -> Void) {
    completion(.failure(BridgeError.unavailable))
  }

  static func readTodayProgress(
    for metric: LittleWinsIntegrationConfig.Metric,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    completion(.failure(BridgeError.unavailable))
  }

  static func readProgress(
    for metric: LittleWinsIntegrationConfig.Metric,
    on day: Date,
    completion: @escaping (Result<Double, Error>) -> Void
  ) {
    completion(.failure(BridgeError.unavailable))
  }

  static func isAuthorizationDenied(_ error: Error) -> Bool { false }
}
#endif

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
final class LittleWinsDailyCompletion {
  @Attribute(.unique) var id: UUID
  var focusId: UUID
  var day: Date
  var completedAt: Date
  var categoryIdSnapshot: UUID?
  var categoryTitleSnapshot: String?
  var focusTitleSnapshot: String?
  var categoryFocusCountSnapshot: Int?

  init(
    id: UUID = .init(),
    focusId: UUID,
    day: Date,
    completedAt: Date = .now,
    categoryIdSnapshot: UUID? = nil,
    categoryTitleSnapshot: String? = nil,
    focusTitleSnapshot: String? = nil,
    categoryFocusCountSnapshot: Int? = nil
  ) {
    self.id = id
    self.focusId = focusId
    self.day = day
    self.completedAt = completedAt
    self.categoryIdSnapshot = categoryIdSnapshot
    self.categoryTitleSnapshot = categoryTitleSnapshot
    self.focusTitleSnapshot = focusTitleSnapshot
    self.categoryFocusCountSnapshot = categoryFocusCountSnapshot
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
final class CompletedOutcomePassionLinkArchive {
    @Attribute(.unique) var id: UUID
    var completedOutcomeArchiveId: UUID
    var passionID: UUID
    var emotionSnapshot: String
    var passionSnapshot: String
    var createdAt: Date

    init(
        id: UUID = .init(),
        completedOutcomeArchiveId: UUID,
        passionID: UUID,
        emotionSnapshot: String,
        passionSnapshot: String,
        createdAt: Date = .now
    ) {
        self.id = id
        self.completedOutcomeArchiveId = completedOutcomeArchiveId
        self.passionID = passionID
        self.emotionSnapshot = emotionSnapshot
        self.passionSnapshot = passionSnapshot
        self.createdAt = createdAt
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
    AppWeekStartStore.weekStart(for: date, base: calendar)
  }

  @Model
  final class Fields {
    @Attribute(.unique) var id: UUID
    var createdAt: Date
    var weekStart: Date
    var morningPowerQuestion: String
    var gratitude: String
    var incantation: String

    // Backward-compatible aliases for updated weekly planning wording.
    var happyOrGratefulNow: String {
      get { morningPowerQuestion }
      set { morningPowerQuestion = newValue }
    }
    var gratitudeNotes: String {
      get { gratitude }
      set { gratitude = newValue }
    }
    var inspiringPhrase: String {
      get { incantation }
      set { incantation = newValue }
    }

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

/// Stores the user's Step 4 inputs per week + planned group.
@Model
final class PlannedChunkStepFourState {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var plannedChunkId: UUID

    var resultText: String
    var roleNoteText: String

    /// Connected role for the group (FulfillmentRoles.id)
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

/// Stores up to 3 connected outcomes per group for Step 4.
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

enum ActivePlanSessionStore {
  private static let defaultsKey = "activePlanWeekStart.v1"

  static func weekStart() -> Date? {
    UserDefaults.standard.object(forKey: LoomDefaultsScope.scopedKey(defaultsKey)) as? Date
  }

  static func setWeekStart(_ date: Date?) {
    let scopedKey = LoomDefaultsScope.scopedKey(defaultsKey)
    if let date {
      UserDefaults.standard.set(date, forKey: scopedKey)
    } else {
      UserDefaults.standard.removeObject(forKey: scopedKey)
    }
  }
}

// MARK: - Rolling Capture
enum CaptureActionSource: String, Codable, CaseIterable, Identifiable {
  case normal = "normal"
  case sharedIn = "shared_in"
  case integrated = "integrated"

  var id: String { rawValue }
}

@Model
final class RollingCaptureItem {
  @Attribute(.unique) var id: UUID
  var text: String
  var isGhost: Bool
  var createdAt: Date
  /// Optional due date for countdown/attention display.
  var dueDate: Date?
  /// Optional per-item attention window (7...30 days) for due countdown display.
  var dueDateAttentionDays: Int?
  /// Optional source provider for synced items (e.g., "apple_reminder").
  var sourceType: String?
  /// Optional external source identifier (e.g., EKReminder identifier).
  var sourceExternalID: String?
  /// Optional leverage metadata carried with this action.
  /// kind is "person" or "tool"; value is display text.
  var leverageKindRaw: String?
  var leverageValue: String?

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
    dueDate: Date? = nil,
    dueDateAttentionDays: Int? = nil,
    sourceType: String? = nil,
    sourceExternalID: String? = nil,
    leverageKindRaw: String? = nil,
    leverageValue: String? = nil,
    unhideDate: Date? = nil,
    unhiddenAt: Date? = nil
  ) {
    self.id = id
    self.text = text
    self.isGhost = isGhost
    self.createdAt = createdAt
    self.dueDate = dueDate
    self.dueDateAttentionDays = dueDateAttentionDays
    self.sourceType = sourceType
    self.sourceExternalID = sourceExternalID
    self.leverageKindRaw = leverageKindRaw
    self.leverageValue = leverageValue
    self.unhideDate = unhideDate
    self.unhiddenAt = unhiddenAt
  }

  var actionSource: CaptureActionSource {
    get {
      guard let sourceType = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines),
            !sourceType.isEmpty else { return .normal }
      return CaptureActionSource(rawValue: sourceType) ?? .integrated
    }
    set {
      switch newValue {
      case .normal:
        sourceType = nil
      default:
        sourceType = newValue.rawValue
      }
    }
  }

  var isShareCreated: Bool {
    actionSource == .sharedIn
  }
}

@Model
final class QuickCompletedCaptureItem {
  @Attribute(.unique) var id: UUID
  var text: String
  var completedAt: Date
  var sourceType: String?
  var sourceExternalID: String?

  init(
    id: UUID = .init(),
    text: String,
    completedAt: Date = .now,
    sourceType: String? = nil,
    sourceExternalID: String? = nil
  ) {
    self.id = id
    self.text = text
    self.completedAt = completedAt
    self.sourceType = sourceType
    self.sourceExternalID = sourceExternalID
  }

  var actionSource: CaptureActionSource {
    guard let sourceType = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines),
          !sourceType.isEmpty else { return .normal }
    return CaptureActionSource(rawValue: sourceType) ?? .integrated
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
/// A persisted group created in Plan Step 3 for a given plan week.
@Model
final class PlannedChunk {
    @Attribute(.unique) var id: UUID

    /// Which plan week this group belongs to (week start).
    var weekStart: Date

    /// Group index as displayed in Step 3 (0-based).
    var chunkIndex: Int

    /// Selected label/category (copied at time of planning).
    var labelId: UUID
    var label: String
    var categoryId: UUID
    var category: String

    var updatedAt: Date

    /// Unique key to ensure only 1 group per (weekStart, chunkIndex) if you recreate the plan.
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

/// A persisted action assigned into a group during planning (text-only; no ghost metadata).
@Model
final class PlannedChunkAction {
    @Attribute(.unique) var id: UUID

    var weekStart: Date
    var chunkIndex: Int

    /// Denormalized reference: which PlannedChunk this action belongs to.
    var plannedChunkId: UUID

    var text: String
    var sourceType: String?
    var sortOrder: Int
    var createdAt: Date

    init(
        id: UUID = .init(),
        weekStart: Date,
        chunkIndex: Int,
        plannedChunkId: UUID,
        text: String,
        sourceType: String? = nil,
        sortOrder: Int,
        createdAt: Date = .now
    ) {
        self.id = id
        self.weekStart = weekStart
        self.chunkIndex = chunkIndex
        self.plannedChunkId = plannedChunkId
        self.text = text
        self.sourceType = sourceType
        self.sortOrder = sortOrder
        self.createdAt = createdAt
    }

    var actionSource: CaptureActionSource {
        guard let sourceType = sourceType?.trimmingCharacters(in: .whitespacesAndNewlines),
              !sourceType.isEmpty else { return .normal }
        return CaptureActionSource(rawValue: sourceType) ?? .integrated
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
        get {
            if let explicit = ActionAttachmentKind(rawValue: kindRaw) {
                return explicit
            }
            if fileBookmarkData != nil || fileName != nil {
                return .file
            }
            if let urlString, !urlString.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                return .link
            }
            return .note
        }
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
