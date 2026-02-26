import Foundation
import SwiftData

extension Notification.Name {
    static let loomAIChatThreadSelectionDidChange = Notification.Name("loomAIChatThreadSelectionDidChange")
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

    init(
        id: UUID = .init(),
        threadID: UUID,
        threadKey: String = "default",
        roleRaw: String,
        content: String,
        createdAt: Date = .now,
        actionsJSON: String? = nil
    ) {
        self.id = id
        self.threadID = threadID
        self.threadKey = threadKey
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.actionsJSON = actionsJSON
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

enum LoomAIChatMessageActionsCodec {
    static func encode(_ actions: [LoomAISuggestedAction]) -> String? {
        guard !actions.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(actions) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [LoomAISuggestedAction] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([LoomAISuggestedAction].self, from: data)) ?? []
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
