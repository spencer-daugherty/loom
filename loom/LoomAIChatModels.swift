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
    var chipsJSON: String?
    var actionsJSON: String?
    var debugJSON: String?
    var groundingJSON: String?
    var suggestionCardsJSON: String?
    var nextActionJSON: String?

    init(
        id: UUID = .init(),
        threadID: UUID,
        threadKey: String = "default",
        roleRaw: String,
        content: String,
        createdAt: Date = .now,
        chipsJSON: String? = nil,
        actionsJSON: String? = nil,
        debugJSON: String? = nil,
        groundingJSON: String? = nil,
        suggestionCardsJSON: String? = nil,
        nextActionJSON: String? = nil
    ) {
        self.id = id
        self.threadID = threadID
        self.threadKey = threadKey
        self.roleRaw = roleRaw
        self.content = content
        self.createdAt = createdAt
        self.chipsJSON = chipsJSON
        self.actionsJSON = actionsJSON
        self.debugJSON = debugJSON
        self.groundingJSON = groundingJSON
        self.suggestionCardsJSON = suggestionCardsJSON
        self.nextActionJSON = nextActionJSON
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

    private enum CodingKeys: String, CodingKey {
        case id
        case title
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        payload = decodePayloadStringMap(from: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(payload, forKey: .payload)
    }
}

typealias LoomAIAction = LoomAISuggestedAction

struct LoomAIGroundingItem: Codable, Identifiable, Hashable {
    var section: String
    var field: String
    var timestamp: String

    var id: String { "\(section.lowercased())|\(field.lowercased())|\(timestamp)" }
}

struct LoomAISuggestionOption: Codable, Identifiable, Hashable {
    var id: String
    var label: String
    var title: String
    var type: String
    var payload: [String: String]

    init(id: String = UUID().uuidString, label: String, title: String, type: String, payload: [String: String] = [:]) {
        self.id = id
        self.label = label
        self.title = title
        self.type = type
        self.payload = payload
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case label
        case title
        case type
        case payload
    }

    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = (try? container.decode(String.self, forKey: .id)) ?? UUID().uuidString
        label = (try? container.decode(String.self, forKey: .label)) ?? ""
        title = (try? container.decode(String.self, forKey: .title)) ?? ""
        type = (try? container.decode(String.self, forKey: .type)) ?? ""
        payload = decodePayloadStringMap(from: container)
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(label, forKey: .label)
        try container.encode(title, forKey: .title)
        try container.encode(type, forKey: .type)
        try container.encode(payload, forKey: .payload)
    }
}

struct LoomAISuggestionCard: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var description: String
    var options: [LoomAISuggestionOption]
}

struct LoomAIPromptChip: Codable, Identifiable, Hashable {
    var id: String
    var title: String
    var prompt: String

    init(id: String = UUID().uuidString, title: String, prompt: String) {
        self.id = id
        self.title = title
        self.prompt = prompt
    }
}

struct LoomAIDebug: Codable, Hashable {
    var model: String?
    var usedContext: Bool?
    var claimedUsedContext: Bool?
    var confidence: String?
    var evidence: [String]?
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

enum LoomAIChatMessageGroundingCodec {
    static func encode(_ grounding: [LoomAIGroundingItem]) -> String? {
        guard !grounding.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(grounding) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [LoomAIGroundingItem] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([LoomAIGroundingItem].self, from: data)) ?? []
    }
}

enum LoomAIChatMessageSuggestionCardsCodec {
    static func encode(_ cards: [LoomAISuggestionCard]) -> String? {
        guard !cards.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(cards) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [LoomAISuggestionCard] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        return (try? JSONDecoder().decode([LoomAISuggestionCard].self, from: data)) ?? []
    }
}

enum LoomAIChatMessageNextActionCodec {
    static func encode(_ action: LoomAISuggestedAction?) -> String? {
        guard let action else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(action) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> LoomAISuggestedAction? {
        guard let json, let data = json.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(LoomAISuggestedAction.self, from: data)
    }
}

enum LoomAIChatMessageChipsCodec {
    static func encode(_ chips: [LoomAIPromptChip]) -> String? {
        guard !chips.isEmpty else { return nil }
        let encoder = JSONEncoder()
        guard let data = try? encoder.encode(chips) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func decode(_ json: String?) -> [LoomAIPromptChip] {
        guard let json, let data = json.data(using: .utf8) else { return [] }
        let decoded = (try? JSONDecoder().decode([LoomAIPromptChip].self, from: data)) ?? []
        return deduplicated(decoded)
    }

    private static func deduplicated(_ chips: [LoomAIPromptChip]) -> [LoomAIPromptChip] {
        var seen = Set<String>()
        var unique: [LoomAIPromptChip] = []
        unique.reserveCapacity(chips.count)
        for chip in chips {
            let prompt = chip.prompt.trimmingCharacters(in: .whitespacesAndNewlines)
            let title = chip.title.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !prompt.isEmpty, !title.isEmpty else { continue }
            let key = "\(title.lowercased())|\(prompt.lowercased())"
            if seen.insert(key).inserted {
                unique.append(.init(id: chip.id, title: title, prompt: prompt))
            }
        }
        return unique
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

private enum LoomAIPayloadValue: Codable {
    case string(String)
    case number(Double)
    case bool(Bool)
    case null
    case object([String: LoomAIPayloadValue])
    case array([LoomAIPayloadValue])

    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        if container.decodeNil() {
            self = .null
        } else if let value = try? container.decode(String.self) {
            self = .string(value)
        } else if let value = try? container.decode(Bool.self) {
            self = .bool(value)
        } else if let value = try? container.decode(Double.self) {
            self = .number(value)
        } else if let value = try? container.decode([String: LoomAIPayloadValue].self) {
            self = .object(value)
        } else if let value = try? container.decode([LoomAIPayloadValue].self) {
            self = .array(value)
        } else {
            self = .null
        }
    }

    var stringified: String {
        switch self {
        case .string(let value):
            return value
        case .number(let value):
            return value.rounded() == value ? String(Int(value)) : String(value)
        case .bool(let value):
            return value ? "true" : "false"
        case .null:
            return ""
        case .object, .array:
            return ""
        }
    }
}

private func decodePayloadStringMap<Key: CodingKey>(from container: KeyedDecodingContainer<Key>) -> [String: String] {
    guard let payloadKey = Key(stringValue: "payload") else { return [:] }
    if let direct = try? container.decode([String: String].self, forKey: payloadKey) {
        return direct
    }
    if let object = try? container.decode([String: LoomAIPayloadValue].self, forKey: payloadKey) {
        var out: [String: String] = [:]
        for (key, value) in object {
            out[key] = value.stringified
        }
        return out
    }
    return [:]
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
