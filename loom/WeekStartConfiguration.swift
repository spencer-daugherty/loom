import Foundation

enum AppWeekStartOption: String, CaseIterable, Codable, Identifiable {
    case sunday
    case saturday
    case monday

    var id: String { rawValue }

    var title: String {
        switch self {
        case .sunday: return "Sunday"
        case .saturday: return "Saturday"
        case .monday: return "Monday"
        }
    }

    var firstWeekday: Int {
        switch self {
        case .sunday: return 1
        case .monday: return 2
        case .saturday: return 7
        }
    }
}

struct AppWeekStartRecord: Codable, Equatable {
    var optionRawValue: String
    var effectiveAt: Date

    var option: AppWeekStartOption {
        AppWeekStartOption(rawValue: optionRawValue) ?? .sunday
    }
}

enum AppWeekStartStore {
    private static let currentKey = "loom.calendar.week_start.current.v1"
    private static let historyKey = "loom.calendar.week_start.history.v1"

    static func current() -> AppWeekStartOption {
        if let rawValue = UserDefaults.standard.string(forKey: currentKey),
           let option = AppWeekStartOption(rawValue: rawValue) {
            return option
        }
        return .sunday
    }

    static func setCurrent(_ option: AppWeekStartOption, now: Date = .now) {
        let existing = current()
        guard existing != option else { return }

        UserDefaults.standard.set(option.rawValue, forKey: currentKey)

        var records = explicitHistory()
        let effectiveAt = Calendar.current.startOfDay(for: now)
        if let last = records.last,
           Calendar.current.isDate(last.effectiveAt, inSameDayAs: effectiveAt) {
            if last.option == option {
                return
            }
            records[records.count - 1] = AppWeekStartRecord(
                optionRawValue: option.rawValue,
                effectiveAt: effectiveAt
            )
            saveExplicitHistory(records)
            return
        }

        records.append(
            AppWeekStartRecord(
                optionRawValue: option.rawValue,
                effectiveAt: effectiveAt
            )
        )
        saveExplicitHistory(records)
    }

    static func option(for date: Date) -> AppWeekStartOption {
        let day = Calendar.current.startOfDay(for: date)
        let matching = history().last { $0.effectiveAt <= day }
        return matching?.option ?? .sunday
    }

    static func configuredCalendar(for date: Date, base: Calendar = .current) -> Calendar {
        var calendar = base
        calendar.firstWeekday = option(for: date).firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        return calendar
    }

    static func weekStart(for date: Date, base: Calendar = .current) -> Date {
        let calendar = configuredCalendar(for: date, base: base)
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    static func firstFullWeekStartForCurrentSetting(base: Calendar = .current) -> Date? {
        guard let latestChange = explicitHistory().last else { return nil }
        var calendar = base
        calendar.firstWeekday = latestChange.option.firstWeekday
        calendar.minimumDaysInFirstWeek = 1

        let effectiveDay = calendar.startOfDay(for: latestChange.effectiveAt)
        let currentWeekStart = weekStart(for: effectiveDay, option: latestChange.option, base: calendar)
        if currentWeekStart < effectiveDay {
            return calendar.date(byAdding: .day, value: 7, to: currentWeekStart)
        }
        return currentWeekStart
    }

    private static func weekStart(for date: Date, option: AppWeekStartOption, base: Calendar) -> Date {
        var calendar = base
        calendar.firstWeekday = option.firstWeekday
        calendar.minimumDaysInFirstWeek = 1
        let day = calendar.startOfDay(for: date)
        let weekday = calendar.component(.weekday, from: day)
        let offset = (weekday - calendar.firstWeekday + 7) % 7
        return calendar.date(byAdding: .day, value: -offset, to: day) ?? day
    }

    private static func history() -> [AppWeekStartRecord] {
        let baseline = AppWeekStartRecord(optionRawValue: AppWeekStartOption.sunday.rawValue, effectiveAt: .distantPast)
        return ([baseline] + explicitHistory()).sorted { $0.effectiveAt < $1.effectiveAt }
    }

    private static func explicitHistory() -> [AppWeekStartRecord] {
        guard
            let data = UserDefaults.standard.data(forKey: historyKey),
            let decoded = try? JSONDecoder().decode([AppWeekStartRecord].self, from: data)
        else {
            return []
        }
        return decoded.sorted { $0.effectiveAt < $1.effectiveAt }
    }

    private static func saveExplicitHistory(_ records: [AppWeekStartRecord]) {
        guard let data = try? JSONEncoder().encode(records) else { return }
        UserDefaults.standard.set(data, forKey: historyKey)
    }
}
