import Foundation
import SwiftData
import UserNotifications

struct LoomNotificationSettings: Codable, Equatable {
    var purposeInsights: Bool = true
    var fulfillmentInsights: Bool = true
    var outcomesStarting: Bool = true
    var outcomeEndingSoon: Bool = true
    var outcomeEndingSoonDays: Int = 3
    var outcomeEndDate: Bool = true
    var actionCaptured: Bool = true
    var captureActionAttention: Bool = true
    var actionDue: Bool = true
    var actionBlockAging: Bool = true
    var littleWins: Bool = true
    var vacationModeAttention: Bool = true
    var vacationModeStarting: Bool = true

    var allNotificationsEnabled: Bool {
        get {
            purposeInsights &&
            fulfillmentInsights &&
            outcomesStarting &&
            outcomeEndingSoon &&
            outcomeEndDate &&
            actionCaptured &&
            captureActionAttention &&
            actionDue &&
            actionBlockAging &&
            littleWins &&
            vacationModeAttention &&
            vacationModeStarting
        }
        set {
            purposeInsights = newValue
            fulfillmentInsights = newValue
            outcomesStarting = newValue
            outcomeEndingSoon = newValue
            outcomeEndDate = newValue
            actionCaptured = newValue
            captureActionAttention = newValue
            actionDue = newValue
            actionBlockAging = newValue
            littleWins = newValue
            vacationModeAttention = newValue
            vacationModeStarting = newValue
        }
    }

    var hasAnyEnabled: Bool {
        allNotificationsEnabled ||
        purposeInsights ||
        fulfillmentInsights ||
        outcomesStarting ||
        outcomeEndingSoon ||
        outcomeEndDate ||
        actionCaptured ||
        captureActionAttention ||
        actionDue ||
        actionBlockAging ||
        littleWins ||
        vacationModeAttention ||
        vacationModeStarting
    }

    var normalized: LoomNotificationSettings {
        var copy = self
        copy.outcomeEndingSoonDays = min(max(copy.outcomeEndingSoonDays, 1), 30)
        return copy
    }
}

enum LoomNotificationSettingsStore {
    private static let defaultsKey = "loom.notification.settings.v1"
    private static let masterEnabledKey = "loom.notification.master.enabled"
    private static let allModeEnabledKey = "loom.notification.all_mode.enabled"

    static func load() -> LoomNotificationSettings {
        guard
            let data = UserDefaults.standard.data(forKey: defaultsKey),
            let decoded = try? JSONDecoder().decode(LoomNotificationSettings.self, from: data)
        else {
            return LoomNotificationSettings()
        }
        return decoded.normalized
    }

    static func save(_ settings: LoomNotificationSettings) {
        let normalized = settings.normalized
        if let data = try? JSONEncoder().encode(normalized) {
            UserDefaults.standard.set(data, forKey: defaultsKey)
        }
    }

    static func isMasterEnabled() -> Bool {
        UserDefaults.standard.object(forKey: masterEnabledKey) as? Bool ?? false
    }

    static func setMasterEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: masterEnabledKey)
    }

    static func isAllModeEnabled() -> Bool {
        UserDefaults.standard.object(forKey: allModeEnabledKey) as? Bool ?? true
    }

    static func setAllModeEnabled(_ enabled: Bool) {
        UserDefaults.standard.set(enabled, forKey: allModeEnabledKey)
    }
}

@MainActor
enum LoomNotificationScheduler {
    private static let idPrefix = "loom.notification."
    private static let defaultHour = 9
    private static let defaultMinute = 0

    static func authorizationStatus() async -> UNAuthorizationStatus {
        let center = UNUserNotificationCenter.current()
        let settings = await notificationSettings(center: center)
        return settings.authorizationStatus
    }

    static func requestAuthorization() async -> Bool {
        let center = UNUserNotificationCenter.current()
        return await withCheckedContinuation { continuation in
            center.requestAuthorization(options: [.alert, .sound, .badge]) { granted, _ in
                continuation.resume(returning: granted)
            }
        }
    }

    static func reschedule(using context: ModelContext, now: Date = .now) async {
        let center = UNUserNotificationCenter.current()
        let pending = await pendingRequests(center: center)
        let loomIDs = pending.map(\.identifier).filter { $0.hasPrefix(idPrefix) }
        if !loomIDs.isEmpty {
            center.removePendingNotificationRequests(withIdentifiers: loomIDs)
        }

        guard LoomNotificationSettingsStore.isMasterEnabled() else { return }

        let authStatus = await notificationSettings(center: center).authorizationStatus
        guard authStatus == .authorized || authStatus == .provisional || authStatus == .ephemeral else { return }

        let settings = LoomNotificationSettingsStore.load().normalized
        guard settings.hasAnyEnabled else { return }

        var requests: [UNNotificationRequest] = []
        requests.reserveCapacity(96)

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)
        let defaultAttentionDays = min(max(UserDefaults.standard.integer(forKey: "capture_default_due_date_attention_days"), 7), 30)

        if settings.purposeInsights {
            requests.append(
                makeRepeatingCalendarRequest(
                    id: "\(idPrefix)purposeInsights.monthly",
                    title: "Purpose Insights",
                    body: "New Purpose Insights are available.",
                    dateComponents: DateComponents(day: 1, hour: defaultHour, minute: defaultMinute)
                )
            )
        }

        if settings.fulfillmentInsights {
            requests.append(
                makeRepeatingCalendarRequest(
                    id: "\(idPrefix)fulfillmentInsights.weekly",
                    title: "Fulfillment Insights",
                    body: "New Fulfillment Insights are available.",
                    dateComponents: DateComponents(hour: defaultHour, minute: defaultMinute, weekday: 2)
                )
            )
        }

        if settings.outcomesStarting || settings.outcomeEndingSoon || settings.outcomeEndDate {
            let outcomes = (try? context.fetch(FetchDescriptor<Outcomes>())) ?? []
            for outcome in outcomes {
                let startDay = calendar.startOfDay(for: outcome.start)
                let endDay = calendar.startOfDay(for: outcome.end)

                if settings.outcomesStarting, startDay >= today,
                   let fireDate = dateOn(day: startDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                    appendOneShot(
                        to: &requests,
                        id: "\(idPrefix)outcomesStarting.\(outcome.outcome_id.uuidString).\(dayKey(startDay))",
                        title: "Outcome Starting",
                        body: "\(outcome.outcome) starts today.",
                        fireDate: fireDate,
                        now: now,
                        calendar: calendar
                    )
                }

                if settings.outcomeEndingSoon {
                    let soonDay = calendar.date(byAdding: .day, value: -settings.outcomeEndingSoonDays, to: endDay) ?? endDay
                    if soonDay >= today,
                       soonDay < endDay,
                       let fireDate = dateOn(day: soonDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                        appendOneShot(
                            to: &requests,
                            id: "\(idPrefix)outcomeEndingSoon.\(outcome.outcome_id.uuidString).\(dayKey(soonDay)).\(settings.outcomeEndingSoonDays)",
                            title: "Outcome Ending Soon",
                            body: "\(outcome.outcome) ends in \(settings.outcomeEndingSoonDays) day\(settings.outcomeEndingSoonDays == 1 ? "" : "s").",
                            fireDate: fireDate,
                            now: now,
                            calendar: calendar
                        )
                    }
                }

                if settings.outcomeEndDate,
                   endDay >= today,
                   let fireDate = dateOn(day: endDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                    appendOneShot(
                        to: &requests,
                        id: "\(idPrefix)outcomeEndDate.\(outcome.outcome_id.uuidString).\(dayKey(endDay))",
                        title: "Outcome End Date",
                        body: "\(outcome.outcome) ends today.",
                        fireDate: fireDate,
                        now: now,
                        calendar: calendar
                    )
                }
            }
        }

        let captureItems = (try? context.fetch(FetchDescriptor<RollingCaptureItem>())) ?? []
        let recurringRules = (try? context.fetch(FetchDescriptor<RecurringCaptureRule>())) ?? []
        let recurringDispatches = (try? context.fetch(FetchDescriptor<RecurringCaptureDispatch>())) ?? []
        let dispatchByItemID: [UUID: RecurringCaptureDispatch] = {
            var map: [UUID: RecurringCaptureDispatch] = [:]
            for dispatch in recurringDispatches where map[dispatch.captureItemID] == nil {
                map[dispatch.captureItemID] = dispatch
            }
            return map
        }()
        let ruleByID = Dictionary(uniqueKeysWithValues: recurringRules.map { ($0.id, $0) })

        if settings.actionCaptured {
            for item in captureItems where item.isGhost {
                guard let unhideDay = item.unhideDate.map({ calendar.startOfDay(for: $0) }) else { continue }
                guard unhideDay >= today else { continue }
                guard let fireDate = dateOn(day: unhideDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) else { continue }
                appendOneShot(
                    to: &requests,
                    id: "\(idPrefix)actionCaptured.unhide.\(item.id.uuidString).\(dayKey(unhideDay))",
                    title: "Action Captured",
                    body: "\(item.text) is now in Capture.",
                    fireDate: fireDate,
                    now: now,
                    calendar: calendar
                )
            }

            for rule in recurringRules where rule.isActive {
                let leadDays = max(7, rule.captureDaysBeforeDueDate)
                let sendAt = calendar.date(byAdding: .day, value: -leadDays, to: rule.nextRunAt) ?? rule.nextRunAt
                guard sendAt >= now else { continue }
                appendOneShot(
                    to: &requests,
                    id: "\(idPrefix)actionCaptured.recurring.\(rule.id.uuidString).\(Int(sendAt.timeIntervalSince1970))",
                    title: "Action Captured",
                    body: "\(rule.text) was added to Capture.",
                    fireDate: sendAt,
                    now: now,
                    calendar: calendar
                )
            }
        }

        if settings.captureActionAttention || settings.actionDue {
            for item in captureItems where !item.isGhost {
                guard let dueDay = resolvedDueDay(for: item, dispatchByItemID: dispatchByItemID, ruleByID: ruleByID, calendar: calendar) else {
                    continue
                }

                if settings.captureActionAttention {
                    let attention = min(max(item.dueDateAttentionDays ?? defaultAttentionDays, 7), 30)
                    let attentionDay = calendar.date(byAdding: .day, value: -attention, to: dueDay) ?? dueDay
                    if attentionDay >= today,
                       attentionDay <= dueDay,
                       let fireDate = dateOn(day: attentionDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                        appendOneShot(
                            to: &requests,
                            id: "\(idPrefix)captureActionAttention.\(item.id.uuidString).\(dayKey(attentionDay))",
                            title: "Capture Action Reminder",
                            body: "\(item.text) is now in your due date reminder window.",
                            fireDate: fireDate,
                            now: now,
                            calendar: calendar
                        )
                    }
                }

                if settings.actionDue,
                   dueDay >= today,
                   let fireDate = dateOn(day: dueDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                    appendOneShot(
                        to: &requests,
                        id: "\(idPrefix)actionDue.\(item.id.uuidString).\(dayKey(dueDay))",
                        title: "Action Due",
                        body: "\(item.text) is due today.",
                        fireDate: fireDate,
                        now: now,
                        calendar: calendar
                    )
                }
            }
        }

        if settings.actionBlockAging {
            let weekStart = WeeklyMindsetEntry.weekStart(for: now)
            let weekEnd = calendar.date(byAdding: .day, value: 1, to: weekStart) ?? weekStart
            let actions = (try? context.fetch(FetchDescriptor<PlannedChunkAction>())) ?? []
            let weekActions = actions.filter { $0.weekStart >= weekStart && $0.weekStart < weekEnd }
            if let earliestCreated = weekActions.map(\.createdAt).min() {
                let agingDay = calendar.date(byAdding: .day, value: 8, to: calendar.startOfDay(for: earliestCreated)) ?? calendar.startOfDay(for: earliestCreated)
                if agingDay >= today,
                   let fireDate = dateOn(day: agingDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                    appendOneShot(
                        to: &requests,
                        id: "\(idPrefix)actionBlockAging.\(dayKey(agingDay))",
                        title: "Action Block Aging",
                        body: "Your current Action Blocks are aging and may need a refresh.",
                        fireDate: fireDate,
                        now: now,
                        calendar: calendar
                    )
                }
            }
        }

        if settings.littleWins {
            let foci = (try? context.fetch(FetchDescriptor<FulfillmentFocus>())) ?? []
            let completions = (try? context.fetch(FetchDescriptor<LittleWinsDailyCompletion>())) ?? []
            if let nextReminder = nextLittleWinsReminderDate(now: now, foci: foci, completions: completions, calendar: calendar) {
                appendOneShot(
                    to: &requests,
                    id: "\(idPrefix)littleWins.\(dayKey(nextReminder))",
                    title: "Little Wins",
                    body: "You still have active Little Wins that are not completed today.",
                    fireDate: nextReminder,
                    now: now,
                    calendar: calendar
                )
            }
        }

        let vacationConfig = VacationModeStore.config().normalized
        if vacationConfig.isEnabled {
            let startDay = calendar.startOfDay(for: vacationConfig.startDate)
            if settings.vacationModeAttention {
                let attentionDay = calendar.date(byAdding: .day, value: -vacationConfig.attentionDays, to: startDay) ?? startDay
                if attentionDay >= today,
                   attentionDay < startDay,
                   let fireDate = dateOn(day: attentionDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                    appendOneShot(
                        to: &requests,
                        id: "\(idPrefix)vacationModeAttention.\(dayKey(attentionDay))",
                        title: "Vacation Mode Reminder",
                        body: "Vacation Mode is coming up soon.",
                        fireDate: fireDate,
                        now: now,
                        calendar: calendar
                    )
                }
            }

            if settings.vacationModeStarting,
               startDay > today,
               let fireDate = dateOn(day: startDay, hour: defaultHour, minute: defaultMinute, calendar: calendar) {
                appendOneShot(
                    to: &requests,
                    id: "\(idPrefix)vacationModeStarting.\(dayKey(startDay))",
                    title: "Vacation Mode Starting",
                    body: "Vacation Mode starts today.",
                    fireDate: fireDate,
                    now: now,
                    calendar: calendar
                )
            }
        }

        // Keep a reasonable upper bound for reliability on device.
        for request in requests.prefix(60) {
            await addRequest(center: center, request: request)
        }
    }

    private static func resolvedDueDay(
        for item: RollingCaptureItem,
        dispatchByItemID: [UUID: RecurringCaptureDispatch],
        ruleByID: [UUID: RecurringCaptureRule],
        calendar: Calendar
    ) -> Date? {
        if let dueDate = item.dueDate {
            return calendar.startOfDay(for: dueDate)
        }
        guard let dispatch = dispatchByItemID[item.id],
              let rule = ruleByID[dispatch.ruleID] else {
            return nil
        }
        let leadDays = max(7, rule.captureDaysBeforeDueDate)
        let due = calendar.date(byAdding: .day, value: leadDays, to: dispatch.sentAt) ?? dispatch.sentAt
        return calendar.startOfDay(for: due)
    }

    private static func nextLittleWinsReminderDate(
        now: Date,
        foci: [FulfillmentFocus],
        completions: [LittleWinsDailyCompletion],
        calendar: Calendar
    ) -> Date? {
        guard !foci.isEmpty else { return nil }

        for dayOffset in 0...14 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: calendar.startOfDay(for: now)) else { continue }
            guard let candidate = dateOn(day: day, hour: 14, minute: 30, calendar: calendar) else { continue }
            guard candidate > now else { continue }

            let activeFocusIDs: Set<UUID> = Set(
                foci
                    .filter { focus in
                        let rule = LittleWinsScheduleStore.rule(for: focus.id)
                        if rule.canCompleteAnyDay { return true }
                        return (rule.activeWeekdayMask & littleWinsWeekdayBit(for: day, calendar: calendar)) != 0
                    }
                    .map(\.id)
            )
            if activeFocusIDs.isEmpty { continue }

            let completedFocusIDs = Set(
                completions
                    .filter { calendar.isDate($0.day, inSameDayAs: day) }
                    .map(\.focusId)
            )
            if !activeFocusIDs.isSubset(of: completedFocusIDs) {
                return candidate
            }
        }

        return nil
    }

    private static func littleWinsWeekdayBit(for date: Date, calendar: Calendar) -> Int {
        let weekday = calendar.component(.weekday, from: date)
        return 1 << max(0, min(6, weekday - 1))
    }

    private static func appendOneShot(
        to requests: inout [UNNotificationRequest],
        id: String,
        title: String,
        body: String,
        fireDate: Date,
        now: Date,
        calendar: Calendar
    ) {
        guard fireDate > now else { return }
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        let components = calendar.dateComponents([.year, .month, .day, .hour, .minute], from: fireDate)
        let trigger = UNCalendarNotificationTrigger(dateMatching: components, repeats: false)
        requests.append(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }

    private static func makeRepeatingCalendarRequest(
        id: String,
        title: String,
        body: String,
        dateComponents: DateComponents
    ) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default
        let trigger = UNCalendarNotificationTrigger(dateMatching: dateComponents, repeats: true)
        return UNNotificationRequest(identifier: id, content: content, trigger: trigger)
    }

    private static func dateOn(day: Date, hour: Int, minute: Int, calendar: Calendar) -> Date? {
        let start = calendar.startOfDay(for: day)
        return calendar.date(bySettingHour: hour, minute: minute, second: 0, of: start)
    }

    private static func dayKey(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar.current
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: date)
    }

    private static func notificationSettings(center: UNUserNotificationCenter) async -> UNNotificationSettings {
        await withCheckedContinuation { continuation in
            center.getNotificationSettings { settings in
                continuation.resume(returning: settings)
            }
        }
    }

    private static func pendingRequests(center: UNUserNotificationCenter) async -> [UNNotificationRequest] {
        await withCheckedContinuation { continuation in
            center.getPendingNotificationRequests { requests in
                continuation.resume(returning: requests)
            }
        }
    }

    private static func addRequest(center: UNUserNotificationCenter, request: UNNotificationRequest) async {
        await withCheckedContinuation { continuation in
            center.add(request) { _ in
                continuation.resume()
            }
        }
    }
}
