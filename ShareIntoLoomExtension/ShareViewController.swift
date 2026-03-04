import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private var didStartProcessing = false
    private let statusLabel: UILabel = {
        let label = UILabel()
        label.text = "Preparing share…"
        label.font = .preferredFont(forTextStyle: .body)
        label.textColor = .secondaryLabel
        label.textAlignment = .center
        label.numberOfLines = 0
        return label
    }()

    private let activityIndicator: UIActivityIndicatorView = {
        let view = UIActivityIndicatorView(style: .medium)
        view.hidesWhenStopped = false
        return view
    }()

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .systemBackground

        let stack = UIStackView(arrangedSubviews: [activityIndicator, statusLabel])
        stack.axis = .vertical
        stack.spacing = 12
        stack.alignment = .center
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(stack)

        NSLayoutConstraint.activate([
            stack.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            stack.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            stack.leadingAnchor.constraint(greaterThanOrEqualTo: view.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(lessThanOrEqualTo: view.trailingAnchor, constant: -20),
        ])

        activityIndicator.startAnimating()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didStartProcessing else { return }
        didStartProcessing = true

        Task { [weak self] in
            await self?.processShare()
        }
    }

    private func processShare() async {
        guard let extensionItems = extensionContext?.inputItems as? [NSExtensionItem], !extensionItems.isEmpty else {
            completeRequest()
            return
        }

        guard let inboxURL = ShareIntoLoomBridgeWriter.payloadDirectoryURL(createIfNeeded: true) else {
            completeRequest()
            return
        }

        let payloadID = UUID()
        let payloadFolderURL = inboxURL.appendingPathComponent(payloadID.uuidString, isDirectory: true)
        do {
            try FileManager.default.createDirectory(at: payloadFolderURL, withIntermediateDirectories: true)
        } catch {
            completeRequest()
            return
        }

        var attachments: [ShareIntoLoomAttachmentPayload] = []
        var seenURLValues: Set<String> = []
        var mergedTexts: [String] = []
        var rootURLString: String? = nil
        var sourceTitle: String? = nil

        for item in extensionItems {
            if sourceTitle == nil {
                sourceTitle = firstNonEmptyString([
                    item.attributedTitle?.string,
                    item.attributedContentText?.string,
                ])
            }

            let providers = item.attachments ?? []
            for provider in providers {
                if provider.hasItemConformingToTypeIdentifier(UTType.url.identifier),
                   let url = await provider.loadURL(forTypeIdentifier: UTType.url.identifier) {
                    let value = url.absoluteString
                    if !value.isEmpty {
                        if rootURLString == nil { rootURLString = value }
                        let normalized = value.lowercased()
                        if !seenURLValues.contains(normalized) {
                            seenURLValues.insert(normalized)
                            attachments.append(
                                ShareIntoLoomAttachmentPayload(
                                    id: UUID(),
                                    kind: .url,
                                    displayName: url.host ?? value,
                                    fileName: nil,
                                    fileRelativePath: nil,
                                    urlString: value,
                                    text: nil
                                )
                            )
                        }
                    }
                }

                let textTypeIdentifier: String? = {
                    if provider.hasItemConformingToTypeIdentifier(UTType.plainText.identifier) {
                        return UTType.plainText.identifier
                    }
                    if provider.hasItemConformingToTypeIdentifier(UTType.text.identifier) {
                        return UTType.text.identifier
                    }
                    return nil
                }()
                if let textTypeIdentifier,
                   let text = await provider.loadText(forTypeIdentifier: textTypeIdentifier),
                   !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    mergedTexts.append(text)
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.fileURL.identifier),
                   let sourceURL = await provider.loadURL(forTypeIdentifier: UTType.fileURL.identifier),
                   let copied = copyIntoPayloadFolder(sourceURL: sourceURL, payloadFolderURL: payloadFolderURL),
                   let relativePath = relativePath(for: copied, payloadRoot: inboxURL) {
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: inferredFileKind(for: copied),
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.image.identifier),
                   let fileURL = await provider.loadFileURL(for: .image),
                   let copied = copyIntoPayloadFolder(sourceURL: fileURL, payloadFolderURL: payloadFolderURL),
                   let relativePath = relativePath(for: copied, payloadRoot: inboxURL) {
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: .image,
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                    continue
                }

                if provider.hasItemConformingToTypeIdentifier(UTType.data.identifier),
                   let fileURL = await provider.loadFileURL(for: .data),
                   let copied = copyIntoPayloadFolder(sourceURL: fileURL, payloadFolderURL: payloadFolderURL),
                   let relativePath = relativePath(for: copied, payloadRoot: inboxURL) {
                    attachments.append(
                        ShareIntoLoomAttachmentPayload(
                            id: UUID(),
                            kind: inferredFileKind(for: copied),
                            displayName: copied.lastPathComponent,
                            fileName: copied.lastPathComponent,
                            fileRelativePath: relativePath,
                            urlString: nil,
                            text: nil
                        )
                    )
                }
            }
        }

        let mergedText = mergedTexts
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")

        let payload = ShareIntoLoomPayload(
            id: payloadID,
            createdAt: .now,
            sourceApp: sourceApplicationIdentifier(),
            sourceTitle: sourceTitle,
            text: mergedText.isEmpty ? nil : mergedText,
            urlString: rootURLString,
            attachments: attachments
        )

        let wroteSharedPayload = ShareIntoLoomBridgeWriter.write(payload: payload)

        await MainActor.run {
            statusLabel.text = "Opening Loom…"
        }

        if wroteSharedPayload {
            openLoomApp(payloadID: payloadID)
            return
        }

        guard let inline = inlinePayloadQueryValue(from: payload) else {
            DispatchQueue.main.async {
                self.activityIndicator.stopAnimating()
                self.statusLabel.text = "Share handoff failed. Please open Loom and try again."
            }
            return
        }
        openLoomApp(inlinePayloadQuery: inline)
    }

    private func openLoomApp(payloadID: UUID) {
        guard let encodedID = payloadID.uuidString.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completeRequest()
            return
        }
        openLoomApp(urlString: "loom://share?payload=\(encodedID)")
    }

    private func openLoomApp(inlinePayloadQuery: String) {
        guard let encoded = inlinePayloadQuery.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) else {
            completeRequest()
            return
        }
        openLoomApp(urlString: "loom://share?inline=\(encoded)")
    }

    private func openLoomApp(urlString: String) {
        guard let url = URL(string: urlString) else {
            completeRequest()
            return
        }

        DispatchQueue.main.async {
            self.extensionContext?.open(url) { [weak self] success in
                guard let self else { return }
                if success {
                    self.completeRequest()
                    return
                }

                if self.openLoomViaResponderChain(url) {
                    self.completeRequest()
                    return
                }

                DispatchQueue.main.async {
                    self.activityIndicator.stopAnimating()
                    self.statusLabel.text = "Couldn’t open Loom. Open Loom and try sharing again."
                }
            }
        }
    }

    private func openLoomViaResponderChain(_ url: URL) -> Bool {
        let selector = NSSelectorFromString("openURL:")
        var responder: UIResponder? = self
        while let current = responder {
            if current.responds(to: selector) {
                // Some hosts expose openURL: but still fail to launch custom schemes.
                // Only treat this fallback as success when the selector returns true.
                if let result = current.perform(selector, with: url)?
                    .takeUnretainedValue() as? Bool {
                    return result
                }
                return false
            }
            responder = current.next
        }
        return false
    }

    private func inlinePayloadQueryValue(from payload: ShareIntoLoomPayload) -> String? {
        let compactAttachments = payload.attachments.compactMap { attachment -> ShareIntoLoomAttachmentPayload? in
            switch attachment.kind {
            case .url:
                let urlString = attachment.urlString?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !urlString.isEmpty else { return nil }
                return ShareIntoLoomAttachmentPayload(
                    id: attachment.id,
                    kind: .url,
                    displayName: attachment.displayName,
                    fileName: nil,
                    fileRelativePath: nil,
                    urlString: urlString,
                    text: nil
                )
            case .text:
                let text = attachment.text?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                guard !text.isEmpty else { return nil }
                return ShareIntoLoomAttachmentPayload(
                    id: attachment.id,
                    kind: .text,
                    displayName: attachment.displayName,
                    fileName: nil,
                    fileRelativePath: nil,
                    urlString: nil,
                    text: String(text.prefix(500))
                )
            case .image, .file:
                return nil
            }
        }

        let compact = ShareIntoLoomPayload(
            id: payload.id,
            createdAt: payload.createdAt,
            sourceApp: payload.sourceApp,
            sourceTitle: payload.sourceTitle.map { String($0.prefix(160)) },
            text: payload.text.map { String($0.prefix(500)) },
            urlString: payload.urlString.map { String($0.prefix(240)) },
            attachments: Array(compactAttachments.prefix(6))
        )

        guard let data = try? JSONEncoder().encode(compact) else { return nil }
        return base64URLEncode(data)
    }

    private func base64URLEncode(_ data: Data) -> String {
        data.base64EncodedString()
            .replacingOccurrences(of: "+", with: "-")
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: "=", with: "")
    }

    private func completeRequest() {
        extensionContext?.completeRequest(returningItems: nil, completionHandler: nil)
    }

    private func sourceApplicationIdentifier() -> String? {
        nil
    }

    private func firstNonEmptyString(_ values: [String?]) -> String? {
        for value in values {
            let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if !trimmed.isEmpty { return trimmed }
        }
        return nil
    }

    private func inferredFileKind(for url: URL) -> ShareIntoLoomAttachmentPayload.Kind {
        if let type = UTType(filenameExtension: url.pathExtension), type.conforms(to: .image) {
            return .image
        }
        return .file
    }

    private func copyIntoPayloadFolder(sourceURL: URL, payloadFolderURL: URL) -> URL? {
        let fm = FileManager.default
        let baseName = sourceURL.lastPathComponent.isEmpty ? "shared_file" : sourceURL.lastPathComponent
        let destination = uniqueDestinationURL(baseName: baseName, folder: payloadFolderURL)

        do {
            if fm.fileExists(atPath: destination.path) {
                try fm.removeItem(at: destination)
            }
            try fm.copyItem(at: sourceURL, to: destination)
            return destination
        } catch {
            return nil
        }
    }

    private func uniqueDestinationURL(baseName: String, folder: URL) -> URL {
        let ext = (baseName as NSString).pathExtension
        let stem = ((baseName as NSString).deletingPathExtension).trimmingCharacters(in: .whitespacesAndNewlines)
        let safeStem = stem.isEmpty ? "shared_file" : stem

        var candidate = folder.appendingPathComponent(baseName)
        var index = 1
        while FileManager.default.fileExists(atPath: candidate.path) {
            let numbered = ext.isEmpty ? "\(safeStem)-\(index)" : "\(safeStem)-\(index).\(ext)"
            candidate = folder.appendingPathComponent(numbered)
            index += 1
        }
        return candidate
    }

    private func relativePath(for url: URL, payloadRoot: URL) -> String? {
        let rootPath = payloadRoot.path
        let fullPath = url.path
        guard fullPath.hasPrefix(rootPath) else { return nil }
        let relative = String(fullPath.dropFirst(rootPath.count)).trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        return relative.isEmpty ? nil : relative
    }
}

private enum ShareIntoLoomBridgeWriter {
    static let appGroupID = "group.srd.loom"
    private static let payloadDirectoryName = "SharedInbox"
    private static let payloadPrefix = "payload_"

    static func payloadDirectoryURL(createIfNeeded: Bool) -> URL? {
        guard let root = FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroupID) else {
            return nil
        }
        let directory = root.appendingPathComponent(payloadDirectoryName, isDirectory: true)
        guard createIfNeeded else { return directory }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            return directory
        } catch {
            return nil
        }
    }

    static func payloadURL(for payloadID: UUID) -> URL? {
        guard let base = payloadDirectoryURL(createIfNeeded: true) else { return nil }
        return base.appendingPathComponent("\(payloadPrefix)\(payloadID.uuidString).json")
    }

    static func write(payload: ShareIntoLoomPayload) -> Bool {
        guard let destination = payloadURL(for: payload.id),
              let data = try? JSONEncoder().encode(payload) else {
            return false
        }
        do {
            try data.write(to: destination, options: [.atomic])
            return true
        } catch {
            return false
        }
    }
}

private struct ShareIntoLoomAttachmentPayload: Codable {
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

private struct ShareIntoLoomPayload: Codable {
    var id: UUID
    var createdAt: Date
    var sourceApp: String?
    var sourceTitle: String?
    var text: String?
    var urlString: String?
    var attachments: [ShareIntoLoomAttachmentPayload]
}

private extension NSItemProvider {
    func loadURL(forTypeIdentifier identifier: String) async -> URL? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let url = item as? URL {
                    continuation.resume(returning: url)
                    return
                }
                if let str = item as? String, let url = URL(string: str) {
                    continuation.resume(returning: url)
                    return
                }
                if let nsurl = item as? NSURL {
                    continuation.resume(returning: nsurl as URL)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    func loadText(forTypeIdentifier identifier: String) async -> String? {
        await withCheckedContinuation { continuation in
            loadItem(forTypeIdentifier: identifier, options: nil) { item, _ in
                if let str = item as? String {
                    continuation.resume(returning: str)
                    return
                }
                if let ns = item as? NSString {
                    continuation.resume(returning: ns as String)
                    return
                }
                continuation.resume(returning: nil)
            }
        }
    }

    func loadFileURL(for type: UTType) async -> URL? {
        await withCheckedContinuation { continuation in
            loadFileRepresentation(forTypeIdentifier: type.identifier) { url, _ in
                continuation.resume(returning: url)
            }
        }
    }
}
