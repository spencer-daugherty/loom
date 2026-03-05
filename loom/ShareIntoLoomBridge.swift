import Foundation

extension Notification.Name {
    static let loomSharePayloadReceived = Notification.Name("loomSharePayloadReceived")
}

enum LoomShareSourceType {
    static let sharedIn = "shared_in"
}

struct ShareIntoLoomAttachmentPayload: Codable, Hashable {
    enum Kind: String, Codable {
        case text
        case url
        case image
        case file
    }

    var id: UUID
    var kind: Kind
    var displayName: String
    var fileName: String?
    var fileRelativePath: String?
    var urlString: String?
    var text: String?
}

struct ShareIntoLoomPayload: Codable, Hashable {
    var id: UUID
    var createdAt: Date
    var sourceApp: String?
    var sourceTitle: String?
    var text: String?
    var urlString: String?
    var attachments: [ShareIntoLoomAttachmentPayload]
    var hasDueDate: Bool? = nil
    var dueDate: Date? = nil
    var dueDateAttentionDays: Int? = nil
    var confirmedInExtension: Bool? = nil
}

enum ShareIntoLoomBridge {
    static let appGroupID = "group.srd.loom"
    private static let payloadDirectoryName = "SharedInbox"
    private static let payloadPrefix = "payload_"
    private static let payloadSuffix = ".json"
    private static var inlinePayloads: [String: ShareIntoLoomPayload] = [:]
    private static let inlinePayloadsQueue = DispatchQueue(label: "ShareIntoLoomBridge.inlinePayloads")

    static func appGroupContainerURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID)
    }

    static func payloadDirectoryURL(createIfNeeded: Bool = false) -> URL? {
        guard let root = appGroupContainerURL() else { return nil }
        let directory = root.appendingPathComponent(payloadDirectoryName, isDirectory: true)
        guard createIfNeeded else { return directory }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    static func payloadURL(for payloadID: String) -> URL? {
        guard let base = payloadDirectoryURL(createIfNeeded: false) else { return nil }
        return base.appendingPathComponent("\(payloadPrefix)\(payloadID).json")
    }

    static func newestPendingPayloadID() -> String? {
        guard let base = payloadDirectoryURL(createIfNeeded: false),
              let urls = try? FileManager.default.contentsOfDirectory(
                at: base,
                includingPropertiesForKeys: [.contentModificationDateKey],
                options: [.skipsHiddenFiles]
              ) else {
            return nil
        }

        let candidates: [(id: String, modifiedAt: Date)] = urls.compactMap { url in
            let name = url.lastPathComponent
            guard name.hasPrefix(payloadPrefix), name.hasSuffix(payloadSuffix) else { return nil }
            let id = String(name.dropFirst(payloadPrefix.count).dropLast(payloadSuffix.count))
            guard !id.isEmpty else { return nil }
            let modifiedAt = (try? url.resourceValues(forKeys: [.contentModificationDateKey]).contentModificationDate) ?? .distantPast
            return (id: id, modifiedAt: modifiedAt)
        }

        return candidates.max(by: { $0.modifiedAt < $1.modifiedAt })?.id
    }

    static func consumePayload(id payloadID: String) -> ShareIntoLoomPayload? {
        if let inline = consumeInlinePayload(id: payloadID) {
            return inline
        }
        guard let url = payloadURL(for: payloadID),
              let data = try? Data(contentsOf: url),
              let payload = try? JSONDecoder().decode(ShareIntoLoomPayload.self, from: data) else {
            return nil
        }
        try? FileManager.default.removeItem(at: url)
        return payload
    }

    static func fileURL(for attachment: ShareIntoLoomAttachmentPayload) -> URL? {
        guard let relativePath = attachment.fileRelativePath,
              let base = payloadDirectoryURL(createIfNeeded: false) else { return nil }
        return base.appendingPathComponent(relativePath)
    }

    static func storeInlinePayload(_ payload: ShareIntoLoomPayload, id: String) {
        inlinePayloadsQueue.async {
            inlinePayloads[id] = payload
        }
    }

    private static func consumeInlinePayload(id: String) -> ShareIntoLoomPayload? {
        inlinePayloadsQueue.sync {
            let payload = inlinePayloads[id]
            inlinePayloads[id] = nil
            return payload
        }
    }
}
