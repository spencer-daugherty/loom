import Foundation

struct LoomAIDailyCostSnapshot {
    var chatSpentUSD: Double
    var chatLimitUSD: Double
    var autoWriteSpentUSD: Double
    var autoWriteLimitUSD: Double
    var insightsSpentUSD: Double
    var insightsLimitUSD: Double
    var totalDailySpentUSD: Double
    var totalMonthlySpentUSD: Double
    var chatUnpricedDailyCount: Int
    var autoWriteUnpricedDailyCount: Int
    var insightsUnpricedDailyCount: Int
    var totalUnpricedDailyCount: Int
    var totalUnpricedMonthlyCount: Int
}

enum LoomAICostLedger {
    private struct DailyLedger: Codable {
        var dayKey: String
        var monthKey: String
        var userKey: String
        var chatSpentUSD: Double
        var autoWriteSpentUSD: Double
        var insightsSpentUSD: Double
        var monthlyChatSpentUSD: Double
        var monthlyAutoWriteSpentUSD: Double
        var monthlyInsightsSpentUSD: Double
        var chatUnpricedDailyCount: Int
        var autoWriteUnpricedDailyCount: Int
        var insightsUnpricedDailyCount: Int
        var monthlyChatUnpricedCount: Int
        var monthlyAutoWriteUnpricedCount: Int
        var monthlyInsightsUnpricedCount: Int
    }

    private enum Bucket {
        case chat
        case autoWrite
        case insights
    }

    private static let defaultsKey = "loom.ai.dailyCostLedger.v1"
    private static let chatLimitUSD: Double = 0.10
    private static let autoWriteLimitUSD: Double = 0.10
    private static let insightsLimitUSD: Double = 0.10

    static func record(response: LoomAIService.LoomAIResponse, intent: String?) {
        guard let bucket = bucket(for: intent) else { return }
        var ledger = dailyLedger()
        if let cost = exactCostUSD(for: response.usage) {
            switch bucket {
            case .chat:
                ledger.chatSpentUSD += cost
                ledger.monthlyChatSpentUSD += cost
            case .autoWrite:
                ledger.autoWriteSpentUSD += cost
                ledger.monthlyAutoWriteSpentUSD += cost
            case .insights:
                ledger.insightsSpentUSD += cost
                ledger.monthlyInsightsSpentUSD += cost
            }
        } else {
            switch bucket {
            case .chat:
                ledger.chatUnpricedDailyCount += 1
                ledger.monthlyChatUnpricedCount += 1
            case .autoWrite:
                ledger.autoWriteUnpricedDailyCount += 1
                ledger.monthlyAutoWriteUnpricedCount += 1
            case .insights:
                ledger.insightsUnpricedDailyCount += 1
                ledger.monthlyInsightsUnpricedCount += 1
            }
        }
        save(ledger)
    }

    static func dailySnapshot() -> LoomAIDailyCostSnapshot {
        let ledger = dailyLedger()
        let totalDaily = max(0, ledger.chatSpentUSD)
            + max(0, ledger.autoWriteSpentUSD)
            + max(0, ledger.insightsSpentUSD)
        let totalMonthly = max(0, ledger.monthlyChatSpentUSD)
            + max(0, ledger.monthlyAutoWriteSpentUSD)
            + max(0, ledger.monthlyInsightsSpentUSD)
        return LoomAIDailyCostSnapshot(
            chatSpentUSD: max(0, ledger.chatSpentUSD),
            chatLimitUSD: chatLimitUSD,
            autoWriteSpentUSD: max(0, ledger.autoWriteSpentUSD),
            autoWriteLimitUSD: autoWriteLimitUSD,
            insightsSpentUSD: max(0, ledger.insightsSpentUSD),
            insightsLimitUSD: insightsLimitUSD,
            totalDailySpentUSD: totalDaily,
            totalMonthlySpentUSD: totalMonthly,
            chatUnpricedDailyCount: max(0, ledger.chatUnpricedDailyCount),
            autoWriteUnpricedDailyCount: max(0, ledger.autoWriteUnpricedDailyCount),
            insightsUnpricedDailyCount: max(0, ledger.insightsUnpricedDailyCount),
            totalUnpricedDailyCount: max(0, ledger.chatUnpricedDailyCount + ledger.autoWriteUnpricedDailyCount + ledger.insightsUnpricedDailyCount),
            totalUnpricedMonthlyCount: max(0, ledger.monthlyChatUnpricedCount + ledger.monthlyAutoWriteUnpricedCount + ledger.monthlyInsightsUnpricedCount)
        )
    }

    static func resetToday() {
        var ledger = dailyLedger()
        ledger.chatSpentUSD = 0
        ledger.autoWriteSpentUSD = 0
        ledger.insightsSpentUSD = 0
        ledger.chatUnpricedDailyCount = 0
        ledger.autoWriteUnpricedDailyCount = 0
        ledger.insightsUnpricedDailyCount = 0
        save(ledger)
    }

    private static func bucket(for intent: String?) -> Bucket? {
        let normalized = intent?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased() ?? ""
        guard !normalized.isEmpty else { return nil }
        if normalized == "loomai_chat" || normalized == "chat_thread_title" {
            return .chat
        }
        if normalized == "diagnostic_insights" || normalized == "purpose_profile_insights" {
            return .insights
        }
        if normalized == "autogroup_plan" || normalized.contains("autowrite") {
            return .autoWrite
        }
        return nil
    }

    private static func dailyLedger(now: Date = Date()) -> DailyLedger {
        let dayKey = dayKeyFormatter.string(from: now)
        let monthKey = monthKeyFormatter.string(from: now)
        let userKey = PersonalizationUserIdentity.currentUserKey()
        guard let data = UserDefaults.standard.data(forKey: defaultsKey),
              var decoded = try? JSONDecoder().decode(DailyLedger.self, from: data),
              decoded.userKey == userKey else {
            return DailyLedger(
                dayKey: dayKey,
                monthKey: monthKey,
                userKey: userKey,
                chatSpentUSD: 0,
                autoWriteSpentUSD: 0,
                insightsSpentUSD: 0,
                monthlyChatSpentUSD: 0,
                monthlyAutoWriteSpentUSD: 0,
                monthlyInsightsSpentUSD: 0,
                chatUnpricedDailyCount: 0,
                autoWriteUnpricedDailyCount: 0,
                insightsUnpricedDailyCount: 0,
                monthlyChatUnpricedCount: 0,
                monthlyAutoWriteUnpricedCount: 0,
                monthlyInsightsUnpricedCount: 0
            )
        }
        if decoded.monthKey != monthKey {
            decoded.monthKey = monthKey
            decoded.monthlyChatSpentUSD = 0
            decoded.monthlyAutoWriteSpentUSD = 0
            decoded.monthlyInsightsSpentUSD = 0
            decoded.monthlyChatUnpricedCount = 0
            decoded.monthlyAutoWriteUnpricedCount = 0
            decoded.monthlyInsightsUnpricedCount = 0
        }
        if decoded.dayKey != dayKey {
            decoded.dayKey = dayKey
            decoded.chatSpentUSD = 0
            decoded.autoWriteSpentUSD = 0
            decoded.insightsSpentUSD = 0
            decoded.chatUnpricedDailyCount = 0
            decoded.autoWriteUnpricedDailyCount = 0
            decoded.insightsUnpricedDailyCount = 0
        }
        return decoded
    }

    private static func save(_ ledger: DailyLedger) {
        guard let data = try? JSONEncoder().encode(ledger) else { return }
        UserDefaults.standard.set(data, forKey: defaultsKey)
    }

    private static func exactCostUSD(for usage: LoomAIUsage?) -> Double? {
        guard let usage else { return nil }
        return LoomAIUsageCostCalculator.exactCostUSD(
            model: usage.model,
            inputTokens: usage.inputTokens,
            cachedInputTokens: usage.cachedInputTokens,
            outputTokens: usage.outputTokens
        )
    }

    private static let dayKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter
    }()

    private static let monthKeyFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.timeZone = .current
        formatter.dateFormat = "yyyy-MM"
        return formatter
    }()
}
