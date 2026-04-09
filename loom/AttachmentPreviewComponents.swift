import SwiftUI
import LinkPresentation
import CoreImage
import Foundation
#if canImport(CryptoKit)
import CryptoKit
#endif
#if canImport(QuickLook)
import QuickLook
#endif
#if canImport(SafariServices)
import SafariServices
#endif
#if canImport(UIKit)
import UIKit
#endif

struct LoomLinkBannerCard: View {
    let urlString: String
    let preview: LoomLinkPreviewStore.PreviewData?

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(preview?.title ?? compactDomain)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(preview?.subtitle ?? compactDomain)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(previewTint.opacity(0.16))
                #if canImport(UIKit)
                if let image = preview?.image {
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "globe")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(.secondary)
                }
                #else
                Image(systemName: "globe")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(.secondary)
                #endif
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(previewTint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(previewTint.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private var compactDomain: String {
        loomCompactDomainText(for: urlString)
    }

    private var previewTint: Color {
        preview?.tint ?? Color(.secondarySystemGroupedBackground)
    }
}

struct LoomFileBannerCard: View {
    let title: String
    let subtitle: String
    let tint: Color
    let systemName: String
    #if canImport(UIKit)
    let thumbnail: UIImage?
    #endif

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .foregroundStyle(.primary)
                    .lineLimit(2)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            ZStack {
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(tint.opacity(0.16))
                #if canImport(UIKit)
                if let thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: systemName)
                        .font(.system(size: 18, weight: .medium))
                        .foregroundStyle(tint)
                }
                #else
                Image(systemName: systemName)
                    .font(.system(size: 18, weight: .medium))
                    .foregroundStyle(tint)
                #endif
            }
            .frame(width: 48, height: 48)
            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(minHeight: 64)
        .background(tint.opacity(0.14))
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(tint.opacity(0.3), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }
}

@MainActor
final class LoomLinkPreviewStore: ObservableObject {
    static let shared = LoomLinkPreviewStore()

    struct PreviewData {
        let title: String
        let subtitle: String
        #if canImport(UIKit)
        let image: UIImage?
        #endif
        let tint: Color
    }

    private struct PersistedPreviewData: Codable {
        let title: String
        let subtitle: String
        let red: Double
        let green: Double
        let blue: Double
        let alpha: Double
        let imageCacheKey: String?
    }

    @Published private var previews: [String: PreviewData] = [:]
    private var loadedURLs: Set<String> = []
    private let persistenceKey = "loom.linkPreviewStore.cache"

    private init() {
        restorePersistedCache()
    }

    func preview(for urlString: String?) -> PreviewData? {
        guard let normalized = normalizedURLString(urlString) else { return nil }
        return previews[normalized]
    }

    func load(urlStrings: [String]) {
        let normalized = urlStrings
            .compactMap(normalizedURLString(_:))

        for urlString in normalized where !loadedURLs.contains(urlString) {
            loadedURLs.insert(urlString)
            Task {
                await loadPreview(for: urlString)
            }
        }
    }

    private func loadPreview(for urlString: String) async {
        guard let url = URL(string: urlString) else { return }
        let provider = LPMetadataProvider()
        let metadata = await withCheckedContinuation { continuation in
            provider.startFetchingMetadata(for: url) { metadata, _ in
                continuation.resume(returning: metadata)
            }
        }
        guard let metadata else { return }

        let resolvedURL = metadata.originalURL ?? metadata.url ?? url
        let subtitle = loomCompactDomainText(for: resolvedURL.absoluteString)
        let title = loomNonEmptyString(metadata.title?.trimmingCharacters(in: .whitespacesAndNewlines)) ?? subtitle
        #if canImport(UIKit)
        let previewImage = await loadImage(from: metadata.imageProvider)
        let fallbackIcon = await loadImage(from: metadata.iconProvider)
        let image = previewImage ?? fallbackIcon
        let tint = image.flatMap { dominantColor(from: $0) }.map(Color.init) ?? Color.blue
        let previewData = PreviewData(
            title: title,
            subtitle: subtitle,
            image: image,
            tint: tint
        )
        previews[urlString] = previewData
        persist(previewData, for: urlString)
        #else
        let previewData = PreviewData(
            title: title,
            subtitle: subtitle,
            tint: Color.blue
        )
        previews[urlString] = previewData
        persist(previewData, for: urlString)
        #endif
    }

    private func normalizedURLString(_ urlString: String?) -> String? {
        guard let value = urlString?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty else { return nil }
        return value
    }

    private func restorePersistedCache() {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let persisted = try? JSONDecoder().decode([String: PersistedPreviewData].self, from: data) else {
            return
        }

        var restored: [String: PreviewData] = [:]
        for (urlString, entry) in persisted {
            #if canImport(UIKit)
            let image = entry.imageCacheKey.flatMap(loadPersistedImage(cacheKey:))
            restored[urlString] = PreviewData(
                title: entry.title,
                subtitle: entry.subtitle,
                image: image,
                tint: Color(
                    red: entry.red,
                    green: entry.green,
                    blue: entry.blue,
                    opacity: entry.alpha
                )
            )
            #else
            restored[urlString] = PreviewData(
                title: entry.title,
                subtitle: entry.subtitle,
                tint: Color(
                    red: entry.red,
                    green: entry.green,
                    blue: entry.blue,
                    opacity: entry.alpha
                )
            )
            #endif
        }
        previews = restored
        loadedURLs = Set(restored.keys)
    }

    private func persist(_ previewData: PreviewData, for urlString: String) {
        var persisted = loadPersistedEntries()
        #if canImport(UIKit)
        let imageCacheKey = persistImage(previewData.image, for: urlString)
        let color = UIColor(previewData.tint)
        #else
        let imageCacheKey: String? = nil
        let color = NSColor(previewData.tint)
        #endif
        var red: CGFloat = 0
        var green: CGFloat = 0
        var blue: CGFloat = 0
        var alpha: CGFloat = 1
        color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        persisted[urlString] = PersistedPreviewData(
            title: previewData.title,
            subtitle: previewData.subtitle,
            red: red,
            green: green,
            blue: blue,
            alpha: alpha,
            imageCacheKey: imageCacheKey
        )
        guard let data = try? JSONEncoder().encode(persisted) else { return }
        UserDefaults.standard.set(data, forKey: persistenceKey)
    }

    private func loadPersistedEntries() -> [String: PersistedPreviewData] {
        guard let data = UserDefaults.standard.data(forKey: persistenceKey),
              let decoded = try? JSONDecoder().decode([String: PersistedPreviewData].self, from: data) else {
            return [:]
        }
        return decoded
    }

    #if canImport(UIKit)
    private func persistImage(_ image: UIImage?, for urlString: String) -> String? {
        guard let image,
              let data = image.pngData() else { return nil }
        let cacheKey = cacheKey(for: urlString)
        let url = imageCacheURL(for: cacheKey)
        do {
            try FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            return cacheKey
        } catch {
            return nil
        }
    }

    private func loadPersistedImage(cacheKey: String) -> UIImage? {
        let url = imageCacheURL(for: cacheKey)
        guard let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }
    #endif

    private func imageCacheURL(for cacheKey: String) -> URL {
        let baseURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        return baseURL
            .appendingPathComponent("LoomLinkPreviewCache", isDirectory: true)
            .appendingPathComponent("\(cacheKey).png")
    }

    private func cacheKey(for urlString: String) -> String {
        #if canImport(CryptoKit)
        let digest = SHA256.hash(data: Data(urlString.utf8))
        return digest.map { String(format: "%02x", $0) }.joined()
        #else
        return String(urlString.hashValue.magnitude, radix: 16)
        #endif
    }

    #if canImport(UIKit)
    private func loadImage(from provider: NSItemProvider?) async -> UIImage? {
        guard let provider, provider.canLoadObject(ofClass: UIImage.self) else { return nil }
        return await withCheckedContinuation { continuation in
            provider.loadObject(ofClass: UIImage.self) { object, _ in
                continuation.resume(returning: object as? UIImage)
            }
        }
    }

    private func dominantColor(from image: UIImage) -> UIColor? {
        guard let cgImage = image.cgImage else { return nil }
        let ciImage = CIImage(cgImage: cgImage)
        let extent = ciImage.extent
        guard !extent.isEmpty,
              let filter = CIFilter(
                name: "CIAreaAverage",
                parameters: [
                    kCIInputImageKey: ciImage,
                    kCIInputExtentKey: CIVector(cgRect: extent)
                ]
              ),
              let outputImage = filter.outputImage else {
            return nil
        }

        let context = CIContext(options: [.workingColorSpace: NSNull()])
        var bitmap = [UInt8](repeating: 0, count: 4)
        context.render(
            outputImage,
            toBitmap: &bitmap,
            rowBytes: 4,
            bounds: CGRect(x: 0, y: 0, width: 1, height: 1),
            format: .RGBA8,
            colorSpace: nil
        )

        return UIColor(
            red: CGFloat(bitmap[0]) / 255,
            green: CGFloat(bitmap[1]) / 255,
            blue: CGFloat(bitmap[2]) / 255,
            alpha: 1
        )
    }
    #endif
}

struct LoomLinkAttachmentPreviewSheet: View {
    let urlString: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoomLinkAttachmentPreviewContent(urlString: urlString)
                .navigationTitle("Attachment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}

struct LoomLinkAttachmentPreviewContent: View {
    let urlString: String

    @ObservedObject private var previewStore = LoomLinkPreviewStore.shared

    var body: some View {
        Group {
            if let url = URL(string: urlString) {
                #if canImport(SafariServices) && canImport(UIKit)
                LoomSafariPreview(url: url)
                    .ignoresSafeArea(edges: .bottom)
                #else
                LoomAttachmentUnavailableContent(
                    title: "Attachment",
                    message: "Preview is not available on this device."
                )
                #endif
            } else {
                LoomAttachmentUnavailableContent(
                    title: "Attachment",
                    message: "This link could not be opened."
                )
            }
        }
        .task {
            previewStore.load(urlStrings: [urlString])
        }
    }
}

struct LoomAttachmentUnavailableSheet: View {
    let title: String
    let message: String

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            LoomAttachmentUnavailableContent(title: title, message: message)
                .navigationTitle("Attachment")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Done") { dismiss() }
                    }
                }
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct LoomAttachmentUnavailableContent: View {
    let title: String
    let message: String

    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 34, weight: .medium))
                .foregroundStyle(.orange)

            Text(title)
                .font(.headline)
                .multilineTextAlignment(.center)

            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Spacer(minLength: 0)
        }
        .padding(24)
    }
}

#if canImport(UIKit)
struct LoomImageAttachmentPreviewSheet: View {
    let url: URL

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let image = UIImage(contentsOfFile: url.path) {
                    GeometryReader { geometry in
                        ScrollView([.horizontal, .vertical]) {
                            Image(uiImage: image)
                                .resizable()
                                .scaledToFit()
                                .frame(
                                    minWidth: geometry.size.width,
                                    minHeight: geometry.size.height
                                )
                                .padding(20)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .background(Color.black.opacity(0.96))
                    }
                    .ignoresSafeArea(edges: .bottom)
                } else {
                    LoomAttachmentUnavailableContent(
                        title: "Attachment",
                        message: "This image could not be previewed."
                    )
                }
            }
            .navigationTitle("Attachment")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
        }
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
    }
}
#endif

#if canImport(QuickLook) && canImport(UIKit)
struct LoomQuickLookPreviewSheet: UIViewControllerRepresentable {
    let url: URL

    func makeCoordinator() -> Coordinator {
        Coordinator(url: url)
    }

    func makeUIViewController(context: Context) -> QLPreviewController {
        let controller = QLPreviewController()
        controller.dataSource = context.coordinator
        return controller
    }

    func updateUIViewController(_ controller: QLPreviewController, context: Context) {
        context.coordinator.url = url
        controller.reloadData()
    }

    final class Coordinator: NSObject, QLPreviewControllerDataSource {
        var url: URL

        init(url: URL) {
            self.url = url
        }

        func numberOfPreviewItems(in controller: QLPreviewController) -> Int {
            1
        }

        func previewController(_ controller: QLPreviewController, previewItemAt index: Int) -> QLPreviewItem {
            url as NSURL
        }
    }
}
#endif

#if canImport(SafariServices) && canImport(UIKit)
struct LoomSafariPreview: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.dismissButtonStyle = .close
        return controller
    }

    func updateUIViewController(_ controller: SFSafariViewController, context: Context) {}
}
#endif

private func loomCompactDomainText(for urlString: String) -> String {
    guard let url = URL(string: urlString) else { return urlString }
    return (url.host ?? urlString).replacingOccurrences(of: "www.", with: "")
}

private func loomNonEmptyString(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}
