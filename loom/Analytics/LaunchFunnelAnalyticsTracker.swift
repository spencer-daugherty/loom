import Foundation

enum LaunchSetupStage: String, CaseIterable {
    case purpose
    case fulfillment
    case goal
    case capture
    case actionPlan = "action_plan"

    var stepIndex: Int {
        switch self {
        case .purpose: return 1
        case .fulfillment: return 2
        case .goal: return 3
        case .capture: return 4
        case .actionPlan: return 5
        }
    }
}

enum LaunchFunnelAnalyticsTracker {
    private enum Keys {
        static let installDate = "analytics_install_date"
        static let lastActiveDate = "analytics_last_active_date"
        static let didLogRetentionDay1 = "analytics_did_log_retention_day_1"
        static let didLogRetentionDay3 = "analytics_did_log_retention_day_3"
        static let didLogRetentionDay7 = "analytics_did_log_retention_day_7"
        static let quickTourStartedAt = "analytics_quick_tour_started_at"
        static let didLogQuickTourStarted = "analytics_did_log_quick_tour_started"
        static let setupStartedAt = "analytics_setup_started_at"
        static let setupStageStartedAt = "analytics_setup_stage_started_at"
        static let setupCurrentStage = "analytics_setup_current_stage"
        static let didCompleteSetup = "analytics_did_complete_setup"
        static let completedStepPrefix = "analytics_setup_completed_step."
        static let lastExitStage = "analytics_setup_last_exit_stage"
        static let lastExitDay = "analytics_setup_last_exit_day"
    }

    static func recordDailyActive(currentStage: String?, defaults: UserDefaults = .standard, now: Date = Date()) {
        guard AnalyticsCollectionPolicy.shouldCollectAnalytics else { return }
        initializeInstallDateIfNeeded(defaults: defaults, now: now)
        let today = analyticsDayString(from: now)
        guard defaults.string(forKey: Keys.lastActiveDate) != today else { return }

        let installDay = defaults.string(forKey: Keys.installDate) ?? today
        let sessionDay = daysBetween(installDay, today)
        AnalyticsLogger.log(.dailyActive(sessionDay: sessionDay, currentStage: currentStage))

        if sessionDay == 1 && !defaults.bool(forKey: Keys.didLogRetentionDay1) {
            defaults.set(true, forKey: Keys.didLogRetentionDay1)
            AnalyticsLogger.log(.retentionDay1(currentStage: currentStage))
        }
        if sessionDay == 3 && !defaults.bool(forKey: Keys.didLogRetentionDay3) {
            defaults.set(true, forKey: Keys.didLogRetentionDay3)
            AnalyticsLogger.log(.retentionDay3(currentStage: currentStage))
        }
        if sessionDay == 7 && !defaults.bool(forKey: Keys.didLogRetentionDay7) {
            defaults.set(true, forKey: Keys.didLogRetentionDay7)
            AnalyticsLogger.log(.retentionDay7(currentStage: currentStage))
        }

        defaults.set(today, forKey: Keys.lastActiveDate)
    }

    static func recordQuickTourStarted(defaults: UserDefaults = .standard, now: Date = Date()) {
        guard !defaults.bool(forKey: Keys.didLogQuickTourStarted) else { return }
        defaults.set(true, forKey: Keys.didLogQuickTourStarted)
        defaults.set(now.timeIntervalSince1970, forKey: Keys.quickTourStartedAt)
        AnalyticsLogger.log(.quickTourStarted())
    }

    static func recordQuickTourStepViewed(stepName: String, stepIndex: Int) {
        AnalyticsLogger.log(.quickTourStepViewed(stepName: stepName, stepIndex: stepIndex))
    }

    static func recordQuickTourCompleted(totalSteps: Int, defaults: UserDefaults = .standard, now: Date = Date()) {
        let duration = elapsedSeconds(since: defaults.double(forKey: Keys.quickTourStartedAt), now: now)
        AnalyticsLogger.log(.quickTourCompleted(totalSteps: totalSteps, durationSeconds: duration))
    }

    static func recordSetupStageViewed(_ stage: LaunchSetupStage, defaults: UserDefaults = .standard, now: Date = Date()) {
        guard !defaults.bool(forKey: Keys.didCompleteSetup) else { return }
        if defaults.double(forKey: Keys.setupStartedAt) <= 0 {
            defaults.set(now.timeIntervalSince1970, forKey: Keys.setupStartedAt)
            defaults.set(now.timeIntervalSince1970, forKey: Keys.setupStageStartedAt)
            AnalyticsLogger.log(.setupStarted(currentStage: stage.rawValue))
        }

        let previousStage = defaults.string(forKey: Keys.setupCurrentStage)
        if previousStage != stage.rawValue {
            defaults.set(stage.rawValue, forKey: Keys.setupCurrentStage)
            defaults.set(now.timeIntervalSince1970, forKey: Keys.setupStageStartedAt)
        }

        AnalyticsLogger.log(
            .setupStepViewed(
                stepName: stage.rawValue,
                stepIndex: stage.stepIndex,
                elapsedSeconds: setupElapsedSeconds(defaults: defaults, now: now)
            )
        )
    }

    static func recordSetupStepCompleted(
        _ stage: LaunchSetupStage,
        outcome: String = "completed",
        defaults: UserDefaults = .standard,
        now: Date = Date()
    ) {
        guard !defaults.bool(forKey: Keys.didCompleteSetup) else { return }
        let completedKey = Keys.completedStepPrefix + stage.rawValue
        guard !defaults.bool(forKey: completedKey) else { return }
        defaults.set(true, forKey: completedKey)
        AnalyticsLogger.log(
            .setupStepCompleted(
                stepName: stage.rawValue,
                stepIndex: stage.stepIndex,
                completionOutcome: outcome,
                elapsedSeconds: setupElapsedSeconds(defaults: defaults, now: now),
                stepDurationSeconds: stageElapsedSeconds(defaults: defaults, now: now)
            )
        )
    }

    static func recordSetupCompleted(defaults: UserDefaults = .standard, now: Date = Date()) {
        guard !defaults.bool(forKey: Keys.didCompleteSetup) else { return }
        defaults.set(true, forKey: Keys.didCompleteSetup)
        AnalyticsLogger.log(.setupCompleted(elapsedSeconds: setupElapsedSeconds(defaults: defaults, now: now)))
    }

    static func recordSetupExitIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) {
        guard !defaults.bool(forKey: Keys.didCompleteSetup) else { return }
        guard defaults.double(forKey: Keys.setupStartedAt) > 0 else { return }
        guard let rawStage = defaults.string(forKey: Keys.setupCurrentStage),
              let stage = LaunchSetupStage(rawValue: rawStage) else { return }

        let today = analyticsDayString(from: now)
        if defaults.string(forKey: Keys.lastExitStage) == rawStage,
           defaults.string(forKey: Keys.lastExitDay) == today {
            return
        }

        defaults.set(rawStage, forKey: Keys.lastExitStage)
        defaults.set(today, forKey: Keys.lastExitDay)
        AnalyticsLogger.log(
            .setupExited(
                stepName: stage.rawValue,
                stepIndex: stage.stepIndex,
                elapsedSeconds: setupElapsedSeconds(defaults: defaults, now: now),
                stepDurationSeconds: stageElapsedSeconds(defaults: defaults, now: now)
            )
        )
    }

    static func initializeInstallDateIfNeeded(defaults: UserDefaults = .standard, now: Date = Date()) {
        guard AnalyticsCollectionPolicy.shouldCollectAnalytics else { return }
        if (defaults.string(forKey: Keys.installDate) ?? "").isEmpty {
            defaults.set(analyticsDayString(from: now), forKey: Keys.installDate)
        }
    }

    private static func setupElapsedSeconds(defaults: UserDefaults, now: Date) -> Int {
        elapsedSeconds(since: defaults.double(forKey: Keys.setupStartedAt), now: now)
    }

    private static func stageElapsedSeconds(defaults: UserDefaults, now: Date) -> Int {
        elapsedSeconds(since: defaults.double(forKey: Keys.setupStageStartedAt), now: now)
    }

    private static func elapsedSeconds(since timestamp: TimeInterval, now: Date) -> Int {
        guard timestamp > 0 else { return 0 }
        return max(0, Int(now.timeIntervalSince1970 - timestamp))
    }

    private static func analyticsDayString(from date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func daysBetween(_ startDay: String, _ endDay: String) -> Int {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        guard let startDate = formatter.date(from: startDay),
              let endDate = formatter.date(from: endDay) else {
            return 0
        }
        let calendar = Calendar(identifier: .gregorian)
        return max(0, calendar.dateComponents([.day], from: startDate, to: endDate).day ?? 0)
    }
}
