import SwiftUI
import LinkPresentation
import CoreImage
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
    struct PreviewData {
        let title: String
        let subtitle: String
        #if canImport(UIKit)
        let image: UIImage?
        #endif
        let tint: Color
    }

    @Published private var previews: [String: PreviewData] = [:]
    private var loadedURLs: Set<String> = []

    func preview(for urlString: String?) -> PreviewData? {
        guard let urlString else { return nil }
        return previews[urlString]
    }

    func load(urlStrings: [String]) {
        let normalized = urlStrings
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }

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
        previews[urlString] = PreviewData(
            title: title,
            subtitle: subtitle,
            image: image,
            tint: tint
        )
        #else
        previews[urlString] = PreviewData(
            title: title,
            subtitle: subtitle,
            tint: Color.blue
        )
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
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
}

struct LoomLinkAttachmentPreviewContent: View {
    let urlString: String

    @Environment(\.openURL) private var openURL
    @StateObject private var previewStore = LoomLinkPreviewStore()

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            LoomLinkBannerCard(
                urlString: urlString,
                preview: previewStore.preview(for: urlString)
            )

            VStack(alignment: .leading, spacing: 6) {
                Text("Link")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(urlString)
                    .font(.footnote)
                    .foregroundStyle(.primary)
                    .textSelection(.enabled)
            }

            Spacer(minLength: 0)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .toolbar {
            ToolbarItem(placement: .confirmationAction) {
                Button("Open") {
                    guard let url = URL(string: urlString) else { return }
                    openURL(url)
                }
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

private func loomCompactDomainText(for urlString: String) -> String {
    guard let url = URL(string: urlString) else { return urlString }
    return (url.host ?? urlString).replacingOccurrences(of: "www.", with: "")
}

private func loomNonEmptyString(_ value: String?) -> String? {
    guard let value, !value.isEmpty else { return nil }
    return value
}
