import Foundation

struct CarriedActionAttachmentSnapshot: Codable, Hashable {
    var kindRaw: String
    var urlString: String?
    var fileName: String?
    var fileBookmarkData: Data?
}

struct CarriedActionProfile: Codable, Hashable {
    var isMust: Bool
    var timeEstimateMinutes: Int?
    var sensitiveMorning: Bool
    var sensitiveAfternoon: Bool
    var sensitiveEvening: Bool
    var leverageKindRaw: String?
    var leverageValue: String?
    var placeNames: [String]
    var noteText: String
    var attachments: [CarriedActionAttachmentSnapshot]
    var updatedAtUnix: Double
}

enum ActionCarryProfileStore {
    private static let storageKey = "carried_action_profiles_v1"

    static func load(for text: String) -> CarriedActionProfile? {
        let key = normalizedKey(text)
        guard !key.isEmpty else { return nil }
        return decodeAll()[key]
    }

    static func save(for text: String, profile: CarriedActionProfile) {
        let key = normalizedKey(text)
        guard !key.isEmpty else { return }
        var map = decodeAll()
        map[key] = profile
        encodeAll(map)
    }

    static func remove(for text: String) {
        let key = normalizedKey(text)
        guard !key.isEmpty else { return }
        var map = decodeAll()
        map.removeValue(forKey: key)
        encodeAll(map)
    }

    static func normalizedKey(_ text: String) -> String {
        text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }

    private static func decodeAll() -> [String: CarriedActionProfile] {
        guard let data = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([String: CarriedActionProfile].self, from: data) else {
            return [:]
        }
        return decoded
    }

    private static func encodeAll(_ map: [String: CarriedActionProfile]) {
        if map.isEmpty {
            UserDefaults.standard.removeObject(forKey: storageKey)
            return
        }
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: storageKey)
    }
}
