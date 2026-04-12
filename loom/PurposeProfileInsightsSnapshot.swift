import Foundation
import SwiftData
import CryptoKit

@Model
final class PurposeProfileInsightsSnapshot {
    @Attribute(.unique) var snapshotKey: String
    var userKey: String
    var monthKey: String
    var inputsHash: String
    var generatedAt: Date
    var profile: String
    var strength: String
    var weakness: String
    var stressTrigger: String
    var breakingPoint: String

    init(
        snapshotKey: String,
        userKey: String,
        monthKey: String,
        inputsHash: String,
        generatedAt: Date = .now,
        profile: String,
        strength: String,
        weakness: String,
        stressTrigger: String,
        breakingPoint: String
    ) {
        self.snapshotKey = snapshotKey
        self.userKey = userKey
        self.monthKey = monthKey
        self.inputsHash = inputsHash
        self.generatedAt = generatedAt
        self.profile = profile
        self.strength = strength
        self.weakness = weakness
        self.stressTrigger = stressTrigger
        self.breakingPoint = breakingPoint
    }
}

enum PurposeProfileInsightsHasher {
    static let schemaVersion = 5

    static func monthKey(from date: Date = .now) -> String {
        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM"
        return formatter.string(from: date)
    }

    static func measuredMonthStart(from date: Date = .now, calendar: Calendar = .current) -> Date {
        let currentMonthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
        return calendar.date(byAdding: .month, value: -1, to: currentMonthStart) ?? currentMonthStart
    }

    static func measuredMonthKey(from date: Date = .now, calendar: Calendar = .current) -> String {
        monthKey(from: measuredMonthStart(from: date, calendar: calendar))
    }

    static func isMonthlyRefreshBoundary(_ date: Date = .now, calendar: Calendar = .current) -> Bool {
        calendar.component(.day, from: date) == 1
    }

    static func hash(
        diagnostic: DiagnosticAnswers,
        vision: String,
        passions: [String]
    ) -> String {
        _ = vision
        _ = passions
        struct Input: Codable {
            var stress: String
            var breaksFirst: String
            var areas: [String]
            var planningStyle: String
            var firstChange: String
        }

        let normalized = Input(
            stress: normalize(diagnostic.stress),
            breaksFirst: normalize(diagnostic.breaksFirst),
            areas: diagnostic.areas.map(normalize).filter { !$0.isEmpty }.sorted(),
            planningStyle: normalize(diagnostic.planningStyle),
            firstChange: normalize(diagnostic.firstChange)
        )

        guard let data = try? JSONEncoder().encode(normalized) else {
            return "purpose_profile_hash_error_v\(schemaVersion)"
        }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }

    static func snapshotKey(userKey: String, monthKey: String, inputsHash: String) -> String {
        "\(PersonalizationUserIdentity.storageSafeKey(for: userKey))|\(schemaVersion)|\(monthKey)|\(inputsHash)"
    }

    private static func normalize(_ value: String) -> String {
        value
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .lowercased()
    }
}
