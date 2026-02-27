import Foundation
import SwiftData

extension Notification.Name {
    static let loomAIChatThreadSelectionDidChange = Notification.Name("loomAIChatThreadSelectionDidChange")
    static let loomAIOpenAddFulfillmentAreaPrefill = Notification.Name("loomAIOpenAddFulfillmentAreaPrefill")
}

@Model
final class LoomAIChatThread {
    @Attribute(.unique) var id: UUID
    @Attribute(.unique) var threadKey: String
    var title: String
    var createdAt: Date
    var updatedAt: Date

    init(
        id: UUID = .init(),
        threadKey: String = "default",
        title: String = "Loom",
        createdAt: Date = .now,
        updatedAt: Date = .now
    ) {
        self.id = id
        self.threadKey = threadKey
        self.title = title
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

@Model
final class LoomAIChatMessage {
    @Attribute(.unique) var id: UUID
    var threadID: UUID
    var threadKey: String
    var roleRaw: String
    var content: String
    var createdAt: Date
    var actionsJSON: String?
    var debugJSON: String?

    init(
        id: UUID = .init(),
        threadID: UUID,
        threadKey: String = "default",
        roleRaw: String,
        content: String,
        createdAt: Date = .now,
        actionsJSON: String? = nil,
        debugJSON: String? = nil
    ) {
        self.id = id
        self.threadID = threadID
        self.threadKey = threadKey
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.actionsJSON = actionsJSON
        self.debugJSON = debugJSON
    }
}

enum LoomAIChatRole: String, Codable, CaseIterable {
    case system
    case user
    case assistant
}

struct LoomAISuggestedAction: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var type: String
    var payload: [String: String]

    init(id: String = UUID().uuidString, title: String, type: String, payload: [String: String] = [:]) {
        self.id = id
        self.title = title
        self.type = type
        self.payload = payload
    }
}

typealias LoomAIAction = LoomAISuggestedAction

struct LoomAIDebug: Codable, Hashable {
    var model: String?
    var usedContext: Bool?
    var contextBytes: Int?
    var contextHash: String?
    var contextKeys: [String]?
}

enum LoomAIChatMessageActionsCodec {
    static func encode(_ actions: [LoomAISuggestedAction]) -> String? {
        guard !actions.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(actions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [LoomAISuggestedAction] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        let decoded = (try? JSONDecoder().decode([LoomAISuggestedAction].self, from: data)) ?? []
        return deduplicated(decoded)
    }

    private static func deduplicated(_ actions: [LoomAISuggestedAction]) -> [LoomAISuggestedAction] {
        var seen = Set<String>()
        var unique: [LoomAISuggestedAction] = []
        unique.reserveCapacity(actions.count)

        for action in actions {
            let key = deduplicationKey(for: action)
            if seen.insert(key).inserted {
                unique.append(action)
            }
        }
        return unique
    }

    private static func deduplicationKey(for action: LoomAISuggestedAction) -> String {
        let normalizedType = action.type.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedTitle = action.title.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let normalizedPayload = action.payload
            .map { key, value in
                "\(key.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())=\(value.trimmingCharacters(in: .whitespacesAndNewlines).lowercased())"
            }
            .sorted()
            .joined(separator: "&")
        return "\(normalizedType)|\(normalizedTitle)|\(normalizedPayload)"
    }
}

enum LoomAIDebugCodec {
    static func encode(_ debug: LoomAIDebug?) -> String? {
        guard let debug else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(debug) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> LoomAIDebug? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LoomAIDebug.self, from: data)
    }
}

enum LoomAIChatThreadSelectionStore {
    private static let currentThreadKeyDefaultsKey = "loomAIChat.currentThreadKey.v1"

    static func currentThreadKey() -> String {
        let key = UserDefaults.standard.string(forKey: currentThreadKeyDefaultsKey)?.trimmingCharacters(in: .whitespacesAndNewlines)
        return (key?.isEmpty == false) ? key! : "default"
    }

    static func setCurrentThreadKey(_ key: String) {
        let normalized = key.trimmingCharacters(in: .whitespacesAndNewlines)
        let finalKey = normalized.isEmpty ? "default" : normalized
        UserDefaults.standard.set(finalKey, forKey: currentThreadKeyDefaultsKey)
        NotificationCenter.default.post(name: .loomAIChatThreadSelectionDidChange, object: nil)
    }
}

struct LoomAIFulfillmentAreaPrefill: Codable {
    var categoryName: String
    var mission: String?
    var identities: [String]
    var littleWins: [String]
    var connectedPassions: [String]
}

enum LoomAIFulfillmentAreaPrefillStore {
    private static let key = "loomAI.fulfillmentAreaPrefill.v1"

    static func save(_ prefill: LoomAIFulfillmentAreaPrefill) {
        guard let data = try? JSONEncoder().encode(prefill) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> LoomAIFulfillmentAreaPrefill? {
        guard let data = UserDefaults.standard.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(LoomAIFulfillmentAreaPrefill.self, from: data)
    }

    static func take() -> LoomAIFulfillmentAreaPrefill? {
        let value = load()
        clear()
        return value
    }

    static func clear() {
        UserDefaults.standard.removeObject(forKey: key)
    }
}
