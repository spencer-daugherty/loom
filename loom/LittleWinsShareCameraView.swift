import SwiftUI
import SwiftData
import AVFoundation
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import LinkPresentation
import UIKit
import UniformTypeIdentifiers

struct LittleWinsShareCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @AppStorage("analytics_install_date") private var analyticsInstallDate = ""
    @AppStorage(UserSessionStore.Keys.isSubscribed) private var isSubscribed = false
    @AppStorage("loom.subscription_plan") private var subscriptionPlanRaw = ""
    @AppStorage(UserSessionStore.Keys.accountName) private var accountName = ""

    @Query(sort: \Fulfillment.updatedAt, order: .forward)
    private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentFocus.rank, order: .forward)
    private var foci: [FulfillmentFocus]
    @Query(sort: \LittleWinsDailyCompletion.completedAt, order: .reverse)
    private var completions: [LittleWinsDailyCompletion]
    @Query(sort: \Outcomes.updatedAt, order: .reverse)
    private var outcomes: [Outcomes]
    @Query(sort: \OutcomesMeasureEntry.measuredAt, order: .forward)
    private var outcomeMeasureEntries: [OutcomesMeasureEntry]
    @Query(sort: \OutcomesMeasure.measuredAt, order: .forward)
    private var outcomeMeasures: [OutcomesMeasure]
    @Query(sort: \CompletedOutcomeArchive.completedAt, order: .reverse)
    private var completedOutcomes: [CompletedOutcomeArchive]
    @Query(sort: \CompletedOutcomeMeasurePointArchive.measuredAt, order: .forward)
    private var completedOutcomeMeasurePoints: [CompletedOutcomeMeasurePointArchive]
    @Query(sort: \FulfillmentCategoryScoreSnapshot.weekStartDate, order: .reverse)
    private var fulfillmentCategoryScoreSnapshots: [FulfillmentCategoryScoreSnapshot]
    @Query(sort: \DiagnosticsInsightsSnapshot.generatedAt, order: .reverse)
    private var diagnosticInsightsSnapshots: [DiagnosticsInsightsSnapshot]

    @StateObject private var cameraSession = LittleWinsShareCameraSession()
    @State private var selectedTemplateID = LittleWinsShareTemplateCatalog.sortedTemplates.first?.id ?? "todaysWins"
    @State private var selectedFilter: LittleWinsShareImageFilter = .color
    @State private var capturedImage: UIImage?
    @State private var hasRequestedCameraAccess = false
    @State private var isRenderingCapture = false
    @State private var showCaptureFailureAlert = false

    private let ciContext = CIContext()
    private let maxRenderedCaptureLongSide: CGFloat = 2048
    private var isCameraDenied: Bool {
        cameraSession.authorizationStatus == .denied || cameraSession.authorizationStatus == .restricted
    }

    private var overlayData: LittleWinsShareOverlayData {
        LittleWinsShareOverlayDataFactory.build(
            fulfillments: fulfillments,
            foci: foci,
            completions: completions,
            outcomes: outcomes,
            outcomeMeasureEntries: outcomeMeasureEntries,
            outcomeMeasures: outcomeMeasures,
            completedOutcomes: completedOutcomes,
            completedOutcomeMeasurePoints: completedOutcomeMeasurePoints,
            fulfillmentCategoryScoreSnapshots: fulfillmentCategoryScoreSnapshots,
            diagnosticInsightsSnapshots: diagnosticInsightsSnapshots,
            accountName: accountName,
            installDateRaw: analyticsInstallDate,
            isSubscribed: isSubscribed,
            subscriptionPlanRaw: subscriptionPlanRaw
        )
    }

    private var templates: [LittleWinsShareTemplateDefinition] {
        LittleWinsShareTemplateCatalog.sortedTemplates
    }

    private var selectedTemplateDefinition: LittleWinsShareTemplateDefinition {
        templates.first(where: { $0.id == selectedTemplateID }) ?? templates[0]
    }

    private var selectedTemplateLockReason: String? {
        selectedTemplateDefinition.lockReason(in: overlayData)
    }

    private var canCaptureSelectedTemplate: Bool {
        selectedTemplateLockReason == nil
    }

    var body: some View {
        Group {
            if let capturedImage {
                LittleWinsSharePreviewView(
                    image: capturedImage,
                    onRetake: {
                        self.capturedImage = nil
                        cameraSession.startSession()
                    },
                    onClose: { dismiss() }
                )
            } else if isCameraDenied {
                LittleWinsCameraPermissionDeniedView(onClose: { dismiss() })
            } else {
                liveCameraView
            }
        }
        .task {
            selectedTemplateID = LittleWinsShareTemplateCatalog.sortedTemplates.first?.id ?? "todaysWins"
            selectedFilter = LittleWinsShareImageFilter.allCases.first ?? .color
            await prepareCameraIfNeeded()
        }
        .onDisappear {
            cameraSession.stopSession()
        }
        .onChange(of: scenePhase) { _, phase in
            guard capturedImage == nil else { return }
            if phase == .active {
                cameraSession.startSession()
            } else {
                cameraSession.stopSession()
            }
        }
        .alert("Capture failed", isPresented: $showCaptureFailureAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Try again in better lighting or reopen the camera.")
        }
    }

    private var liveCameraView: some View {
        ZStack {
            LittleWinsShareCameraPreview(
                session: cameraSession.session,
                isMirrored: cameraSession.activePosition == .front
            )
            .saturation(livePreviewSaturation)
            .contrast(livePreviewContrast)
            .brightness(livePreviewBrightness)
            .overlay {
                livePreviewToneOverlay
            }
            .ignoresSafeArea()

            liveTemplatePager
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    Color.black.opacity(0.55),
                    Color.clear,
                    Color.black.opacity(0.65)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            VStack(spacing: 0) {
                topControls
                    .padding(.horizontal, 18)
                    .padding(.top, 0)

                Spacer()

                bottomControls
                    .padding(.horizontal, 16)
                    .padding(.bottom, 16)
            }

            if !cameraSession.isConfigured || isRenderingCapture {
                ZStack {
                    Color.black.opacity(0.34).ignoresSafeArea()
                    VStack(spacing: 8) {
                        ProgressView()
                            .tint(.white)
                        Text(isRenderingCapture ? "Rendering share image..." : "Preparing camera...")
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.white.opacity(0.9))
                    }
                    .padding(14)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(Color.black.opacity(0.50))
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(Color.white.opacity(0.20), lineWidth: 1)
                    )
                }
            }
        }
    }

    private var topControls: some View {
        HStack {
            Spacer()

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.white.opacity(0.14), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    private var bottomControls: some View {
        VStack(spacing: 12) {
            templateStatusRow
            captureControlsRow
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
    }

    private var templateStatusRow: some View {
        VStack(alignment: .center, spacing: 4) {
            Text(selectedTemplateDefinition.title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)

            if let lockReason = selectedTemplateLockReason {
                Text(lockReason)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            } else {
                Text(selectedTemplateDefinition.subtitle)
                    .font(.caption2.weight(.medium))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
    }

    private var captureControlsRow: some View {
        HStack {
            Button {
                selectedFilter = selectedFilter.next()
            } label: {
                VStack(spacing: 4) {
                    Image(systemName: "wand.and.stars")
                        .font(.headline.weight(.semibold))
                    Text(selectedFilter.title)
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.48), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                capturePhoto()
            } label: {
                ZStack {
                    Circle()
                        .fill(Color.white.opacity(0.20))
                        .frame(width: 78, height: 78)
                    Circle()
                        .fill(Color.white)
                        .frame(width: 62, height: 62)
                }
            }
            .buttonStyle(.plain)
            .disabled(!cameraSession.isSessionRunning || isRenderingCapture || !canCaptureSelectedTemplate)
            .opacity((cameraSession.isSessionRunning && !isRenderingCapture && canCaptureSelectedTemplate) ? 1 : 0.55)

            Spacer()

            cameraSwitchButton
        }
    }

    private var cameraSwitchButton: some View {
        Button {
            Task { await cameraSession.toggleCamera() }
        } label: {
            Image(systemName: "camera.rotate")
                .font(.headline.weight(.semibold))
                .foregroundStyle(.white)
                .frame(width: 56, height: 56)
                .background(Color.black.opacity(0.48), in: Circle())
                .overlay(Circle().stroke(Color.white.opacity(0.22), lineWidth: 1))
        }
        .buttonStyle(.plain)
        .disabled(!cameraSession.isConfigured || isRenderingCapture)
        .opacity(cameraSession.isConfigured ? 1 : 0.6)
    }

    private var liveTemplatePager: some View {
        TabView(selection: $selectedTemplateID) {
            ForEach(templates) { template in
                template.renderView(data: overlayData)
                    .tag(template.id)
                    .ignoresSafeArea()
            }
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .indexViewStyle(.page(backgroundDisplayMode: .never))
    }

    private var livePreviewSaturation: Double {
        switch selectedFilter {
        case .color:
            return 1.32
        case .mono:
            return 0
        }
    }

    private var livePreviewContrast: Double {
        switch selectedFilter {
        case .color:
            return 1.12
        case .mono:
            return 1.05
        }
    }

    private var livePreviewBrightness: Double {
        switch selectedFilter {
        case .color:
            return 0.02
        case .mono:
            return 0
        }
    }

    @ViewBuilder
    private var livePreviewToneOverlay: some View {
        switch selectedFilter {
        case .color, .mono:
            Color.clear
        }
    }

    private func prepareCameraIfNeeded() async {
        guard !hasRequestedCameraAccess else { return }
        hasRequestedCameraAccess = true

        let granted = await cameraSession.requestAccessAndConfigureIfNeeded()
        guard granted else { return }
        cameraSession.startSession()
    }

    private func capturePhoto() {
        guard !isRenderingCapture, canCaptureSelectedTemplate else { return }
        let haptic = UIImpactFeedbackGenerator(style: .medium)
        haptic.impactOccurred()

        Task {
            guard let rawImage = await cameraSession.capturePhoto() else {
                await MainActor.run {
                    showCaptureFailureAlert = true
                }
                return
            }

            await MainActor.run {
                isRenderingCapture = true
            }

            let composited = await buildCompositedImage(from: rawImage)

            await MainActor.run {
                isRenderingCapture = false
                if let composited {
                    capturedImage = composited
                    cameraSession.stopSession()
                } else {
                    showCaptureFailureAlert = true
                }
            }
        }
    }

    private func buildCompositedImage(from rawImage: UIImage) async -> UIImage? {
        let normalized = rawImage.loomNormalizedOrientation()
        let viewportCropped = cropToLiveViewportAspect(image: normalized)
        let preparedBase = viewportCropped.loomResizedToFit(maxLongSide: maxRenderedCaptureLongSide)
        guard let filtered = applyFilter(to: preparedBase, style: selectedFilter) else { return nil }
        let outputPixelSize = pixelSize(for: filtered)
        guard let overlay = renderOverlayImage(
            referencePhotoSize: filtered.size,
            outputPixelSize: outputPixelSize
        ) else { return filtered }
        return composite(base: filtered, overlay: overlay)
    }

    @MainActor
    private func renderOverlayImage(referencePhotoSize: CGSize, outputPixelSize: CGSize) -> UIImage? {
        let referenceWidth = max(UIScreen.main.bounds.width, 1)
        let referenceHeight = referenceWidth * (referencePhotoSize.height / max(referencePhotoSize.width, 1))
        let overlayScale = max(outputPixelSize.width / referenceWidth, 1)
        let overlayView = selectedTemplateDefinition.renderView(data: overlayData)
            .frame(width: referenceWidth, height: referenceHeight)
            .ignoresSafeArea()
        let renderer = ImageRenderer(content: overlayView)
        renderer.scale = overlayScale
        renderer.proposedSize = .init(width: referenceWidth, height: referenceHeight)
        return renderer.uiImage
    }

    private func applyFilter(to image: UIImage, style: LittleWinsShareImageFilter) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }

        let outputImage: CIImage
        switch style {
        case .color:
            let filter = CIFilter.colorControls()
            filter.inputImage = inputImage
            filter.saturation = 1.32
            filter.contrast = 1.12
            filter.brightness = 0.02
            guard let result = filter.outputImage else { return nil }
            outputImage = result
        case .mono:
            let filter = CIFilter.photoEffectMono()
            filter.inputImage = inputImage
            guard let result = filter.outputImage else { return nil }
            outputImage = result
        }

        guard let cgImage = ciContext.createCGImage(outputImage, from: outputImage.extent) else { return nil }
        return UIImage(cgImage: cgImage, scale: image.scale, orientation: .up)
    }

    private func composite(base: UIImage, overlay: UIImage) -> UIImage {
        let canvasSize = pixelSize(for: base)
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: canvasSize, format: format)
        return renderer.image { context in
            let bounds = CGRect(origin: .zero, size: canvasSize)
            base.draw(in: bounds)
            overlay.draw(in: bounds)
            _ = context
        }
    }

    private func pixelSize(for image: UIImage) -> CGSize {
        if let cgImage = image.cgImage {
            return CGSize(width: CGFloat(cgImage.width), height: CGFloat(cgImage.height))
        }
        return CGSize(
            width: image.size.width * image.scale,
            height: image.size.height * image.scale
        )
    }

    private func cropToLiveViewportAspect(image: UIImage) -> UIImage {
        guard let cgImage = image.cgImage else { return image }

        let sourceWidth = CGFloat(cgImage.width)
        let sourceHeight = CGFloat(cgImage.height)
        guard sourceWidth > 0, sourceHeight > 0 else { return image }

        let viewportSize = UIScreen.main.bounds.size
        let targetAspect = max(viewportSize.width, 1) / max(viewportSize.height, 1)
        let sourceAspect = sourceWidth / sourceHeight

        if abs(sourceAspect - targetAspect) < 0.001 {
            return image
        }

        let cropRect: CGRect
        if sourceAspect > targetAspect {
            let cropWidth = sourceHeight * targetAspect
            cropRect = CGRect(
                x: (sourceWidth - cropWidth) / 2,
                y: 0,
                width: cropWidth,
                height: sourceHeight
            )
        } else {
            let cropHeight = sourceWidth / targetAspect
            cropRect = CGRect(
                x: 0,
                y: (sourceHeight - cropHeight) / 2,
                width: sourceWidth,
                height: cropHeight
            )
        }

        guard let croppedCGImage = cgImage.cropping(to: cropRect.integral) else { return image }
        return UIImage(cgImage: croppedCGImage, scale: image.scale, orientation: .up)
    }
}

private struct LittleWinsSharePreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onClose: () -> Void

    @State private var isShowingShareSheet = false
    @State private var isSaving = false
    @State private var feedbackMessage = ""
    @State private var feedbackTitle = ""
    @State private var isShowingFeedback = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFill()
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(Color.white.opacity(0.18), lineWidth: 1)
                        )
                }
                .padding(.horizontal, 16)

                HStack(spacing: 12) {
                    Button {
                        saveImageToPhotoLibrary()
                    } label: {
                        Label(isSaving ? "Saving..." : "Save", systemImage: "square.and.arrow.down")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray)
                    .disabled(isSaving)

                    Button {
                        isShowingShareSheet = true
                    } label: {
                        Label("Share", systemImage: "square.and.arrow.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 44)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 16)
            }

            VStack {
                HStack {
                    Button {
                        onRetake()
                    } label: {
                        Text("Retake")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .background(Color.white.opacity(0.14), in: Capsule(style: .continuous))
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())

                    Spacer()

                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                            .font(.headline.weight(.semibold))
                            .foregroundStyle(.white)
                            .frame(width: 36, height: 36)
                            .background(Color.white.opacity(0.14), in: Circle())
                    }
                    .buttonStyle(.plain)
                    .contentShape(Rectangle())
                }
                .padding(.horizontal, 18)
                .padding(.top, 56)
                .padding(.bottom, 10)
                .background(Color.black.opacity(0.001))

                Spacer()
            }
            .ignoresSafeArea(edges: .top)
            .zIndex(5)
        }
        .sheet(isPresented: $isShowingShareSheet) {
            LittleWinsShareActivityView(image: image)
        }
        .alert(feedbackTitle, isPresented: $isShowingFeedback) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(feedbackMessage)
        }
    }

    private func saveImageToPhotoLibrary() {
        guard !isSaving else { return }
        isSaving = true

        Task {
            defer {
                Task { @MainActor in
                    isSaving = false
                }
            }

            let status = PHPhotoLibrary.authorizationStatus(for: .addOnly)
            let granted: Bool
            switch status {
            case .authorized, .limited:
                granted = true
            case .notDetermined:
                let requested = await PHPhotoLibrary.requestAuthorization(for: .addOnly)
                granted = requested == .authorized || requested == .limited
            default:
                granted = false
            }

            guard granted else {
                await MainActor.run {
                    feedbackTitle = "Photos Access Needed"
                    feedbackMessage = "Enable Photos permission to save this image."
                    isShowingFeedback = true
                }
                return
            }

            guard let data = image.jpegData(compressionQuality: 0.95) else {
                await MainActor.run {
                    feedbackTitle = "Save Failed"
                    feedbackMessage = "Could not prepare the image for saving."
                    isShowingFeedback = true
                }
                return
            }

            do {
                try await saveImageData(data)
                await MainActor.run {
                    feedbackTitle = "Saved"
                    feedbackMessage = "Image saved to your Photos library."
                    isShowingFeedback = true
                }
            } catch {
                await MainActor.run {
                    feedbackTitle = "Save Failed"
                    feedbackMessage = "Could not save this image. Please try again."
                    isShowingFeedback = true
                }
            }
        }
    }

    private func saveImageData(_ data: Data) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            PHPhotoLibrary.shared().performChanges({
                let request = PHAssetCreationRequest.forAsset()
                request.addResource(with: .photo, data: data, options: nil)
            }) { success, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if success {
                    continuation.resume(returning: ())
                } else {
                    continuation.resume(
                        throwing: NSError(
                            domain: "loom.sharecamera.save",
                            code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "Photo library save failed."]
                        )
                    )
                }
            }
        }
    }
}

private struct LittleWinsCameraPermissionDeniedView: View {
    let onClose: () -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                Image(systemName: "camera.fill")
                    .font(.system(size: 42, weight: .semibold))
                    .foregroundStyle(.white)

                Text("Camera access is off")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)

                Text("Enable camera access in Settings to create Little Wins share snapshots.")
                    .font(.subheadline)
                    .foregroundStyle(.white.opacity(0.82))
                    .multilineTextAlignment(.center)

                HStack(spacing: 12) {
                    Button("Close") {
                        onClose()
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.gray.opacity(0.7))

                    Button("Open Settings") {
                        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
                        UIApplication.shared.open(url)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.blue)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .fill(Color.white.opacity(0.08))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 16, style: .continuous)
                    .stroke(Color.white.opacity(0.18), lineWidth: 1)
            )
            .padding(18)
        }
    }
}

private struct LittleWinsShareActivityView: UIViewControllerRepresentable {
    let image: UIImage

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let source = LittleWinsShareActivityItemSource(image: image)
        let controller = UIActivityViewController(activityItems: [source], applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private final class LittleWinsShareActivityItemSource: NSObject, UIActivityItemSource {
    private let image: UIImage

    init(image: UIImage) {
        self.image = image
        super.init()
    }

    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        image
    }

    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        UTType.image.identifier
    }

    func activityViewControllerLinkMetadata(_ activityViewController: UIActivityViewController) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = "Little Win"
        metadata.imageProvider = NSItemProvider(object: image)
        metadata.iconProvider = nil
        return metadata
    }
}

private enum LittleWinsShareOverlayDataFactory {
    static func build(
        fulfillments: [Fulfillment],
        foci: [FulfillmentFocus],
        completions: [LittleWinsDailyCompletion],
        outcomes: [Outcomes],
        outcomeMeasureEntries: [OutcomesMeasureEntry],
        outcomeMeasures: [OutcomesMeasure],
        completedOutcomes: [CompletedOutcomeArchive],
        completedOutcomeMeasurePoints: [CompletedOutcomeMeasurePointArchive],
        fulfillmentCategoryScoreSnapshots: [FulfillmentCategoryScoreSnapshot],
        diagnosticInsightsSnapshots: [DiagnosticsInsightsSnapshot],
        accountName: String,
        installDateRaw: String,
        isSubscribed: Bool,
        subscriptionPlanRaw: String
    ) -> LittleWinsShareOverlayData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)
        let orderedFulfillments = LittleWinsFulfillmentOrdering.orderedRecords(from: fulfillments)

        var completionFocusIDsByDay: [Date: Set<UUID>] = [:]
        completionFocusIDsByDay.reserveCapacity(16)
        for row in completions {
            let day = calendar.startOfDay(for: row.day)
            completionFocusIDsByDay[day, default: []].insert(row.focusId)
        }
        let categoryTitleByID = Dictionary(uniqueKeysWithValues: fulfillments.map {
            ($0.category_id, $0.category.trimmed)
        })
        let candidateFoci = foci.filter { !$0.activity.trimmed.isEmpty }

        func cards(on day: Date) -> [LittleWinsShareOverlayCard] {
            let dayStart = calendar.startOfDay(for: day)
            let completedIDs = completionFocusIDsByDay[dayStart] ?? []
            let activeByCategory = Dictionary(
                grouping: candidateFoci.filter { isFocusActive($0, on: dayStart, calendar: calendar) },
                by: \.category_id
            )

            return orderedFulfillments.compactMap { record in
                let categoryID = record.category_id
                let categoryFoci = (activeByCategory[categoryID] ?? [])
                    .sorted { lhs, rhs in
                        if lhs.rank == rhs.rank {
                            return lhs.activity.localizedCaseInsensitiveCompare(rhs.activity) == .orderedAscending
                        }
                        return lhs.rank < rhs.rank
                    }
                guard !categoryFoci.isEmpty else { return nil }

                let cardTitle = (categoryTitleByID[categoryID] ?? "Little Wins").nonEmptyOr("Little Wins")
                let rows = categoryFoci.map { focus in
                    LittleWinsShareOverlayWin(
                        id: focus.id,
                        title: focus.activity.trimmed,
                        isCompleted: completedIDs.contains(focus.id)
                    )
                }

                return LittleWinsShareOverlayCard(
                    id: categoryID,
                    title: cardTitle,
                    cardColor: FulfillmentCategoryTheme.lightColor(for: cardTitle),
                    titleColor: FulfillmentCategoryTheme.color(for: cardTitle),
                    wins: rows
                )
            }
        }

        let todayCards = cards(on: today)
        let completedCardsToday = todayCards.filter(\.isCompleted)
        let fullHouseUnlocked = !todayCards.isEmpty && completedCardsToday.count == todayCards.count

        let daysLast7 = stride(from: 6, through: 0, by: -1).compactMap {
            calendar.date(byAdding: .day, value: -$0, to: today)
        }
        let completedCardsByDayLast7: [[LittleWinsShareOverlayCard]] = daysLast7.map { day in
            cards(on: day).filter(\.isCompleted)
        }
        let completedCardStylesLast7Days: [[LittleWinsShareOverlayMiniCardStyle]] = completedCardsByDayLast7.map { dayCards in
            dayCards.map { card in
                LittleWinsShareOverlayMiniCardStyle(
                    fillColor: card.cardColor,
                    strokeColor: card.titleColor
                )
            }
        }
        let completionCountsLast7Days = daysLast7.map { day in
            completionFocusIDsByDay[calendar.startOfDay(for: day)]?.count ?? 0
        }

        var streak = 0
        for dayOffset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let hasCompletion = !(completionFocusIDsByDay[calendar.startOfDay(for: day)]?.isEmpty ?? true)
            if hasCompletion {
                streak += 1
            } else {
                break
            }
        }

        var fullHouseStreak = 0
        for dayOffset in 0..<30 {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { break }
            let dayCards = cards(on: day)
            let isDayFullHouse = !dayCards.isEmpty && dayCards.allSatisfy(\.isCompleted)
            if isDayFullHouse {
                fullHouseStreak += 1
            } else {
                break
            }
        }

        let totalWeekCompletions = completionCountsLast7Days.reduce(0, +)
        let hotStreak = streak >= 5
        let royalFlushUnlocked = fullHouseStreak >= 7
        let fulfillmentAreaColors = orderedFulfillments.map { FulfillmentCategoryTheme.color(for: $0.category) }
        let radarSideCount = max(3, min(7, orderedFulfillments.count))
        let userProfile = buildUserProfile(
            accountName: accountName,
            installDateRaw: installDateRaw,
            isSubscribed: isSubscribed,
            subscriptionPlanRaw: subscriptionPlanRaw
        )
        let featuredActiveGoal = buildFeaturedActiveGoal(
            outcomes: outcomes,
            outcomeMeasureEntries: outcomeMeasureEntries,
            outcomeMeasures: outcomeMeasures,
            today: today,
            calendar: calendar
        )
        let appleHealthVerifiedStory = buildAppleHealthVerifiedStory(
            foci: candidateFoci,
            categoryTitleByID: categoryTitleByID,
            featuredActiveGoal: featuredActiveGoal
        )
        let latestAchievedGoal = buildLatestAchievedGoal(
            completedOutcomes: completedOutcomes,
            completedOutcomeMeasurePoints: completedOutcomeMeasurePoints
        )
        let fulfillmentStory = buildFulfillmentStory(
            fulfillments: orderedFulfillments,
            snapshots: fulfillmentCategoryScoreSnapshots
        )
        let latestInsight = buildLatestInsight(from: diagnosticInsightsSnapshots)

        return LittleWinsShareOverlayData(
            activeCards: todayCards,
            completedCardsToday: completedCardsToday,
            completedCardStylesLast7Days: completedCardStylesLast7Days,
            completionCountsLast7Days: completionCountsLast7Days,
            fulfillmentAreaColors: fulfillmentAreaColors,
            radarSideCount: radarSideCount,
            streak: streak,
            hotStreak: hotStreak,
            totalWeekCompletions: totalWeekCompletions,
            fullHouseUnlocked: fullHouseUnlocked,
            royalFlushUnlocked: royalFlushUnlocked,
            royalFlushProgressDays: min(7, fullHouseStreak),
            userProfile: userProfile,
            appleHealthVerifiedStory: appleHealthVerifiedStory,
            featuredActiveGoal: featuredActiveGoal,
            latestAchievedGoal: latestAchievedGoal,
            fulfillmentStory: fulfillmentStory,
            latestInsight: latestInsight
        )
    }

    private static func buildUserProfile(
        accountName: String,
        installDateRaw: String,
        isSubscribed: Bool,
        subscriptionPlanRaw: String
    ) -> LittleWinsShareUserProfile {
        let installDate = parseAnalyticsInstallDate(installDateRaw)
        let daysSinceInstall = installDate.map {
            max(0, Calendar(identifier: .gregorian).dateComponents([.day], from: $0, to: .now).day ?? 0)
        }

        return LittleWinsShareUserProfile(
            displayName: accountName.trimmed.nonEmpty,
            installDate: installDate,
            daysSinceInstall: daysSinceInstall,
            isSubscribed: isSubscribed,
            isFoundingMember: isSubscribed && subscriptionPlanRaw == SubscriptionPlan.lifetime.rawValue
        )
    }

    private static func buildFeaturedActiveGoal(
        outcomes: [Outcomes],
        outcomeMeasureEntries: [OutcomesMeasureEntry],
        outcomeMeasures: [OutcomesMeasure],
        today: Date,
        calendar: Calendar
    ) -> LittleWinsShareGoalProgressData? {
        let snapshotsByOutcome = latestOutcomeMeasuresByOutcomeID(outcomeMeasures)
        let entriesByOutcome = Dictionary(grouping: outcomeMeasureEntries, by: \.outcome_id)

        let candidates = outcomes.compactMap { outcome -> LittleWinsShareGoalProgressData? in
            guard calendar.startOfDay(for: outcome.end) >= today else { return nil }
            guard outcome.format != nil || snapshotsByOutcome[outcome.outcome_id] != nil || !(entriesByOutcome[outcome.outcome_id] ?? []).isEmpty else {
                return nil
            }

            let rows = dailyLatestRowsWithinOutcomeWindow(
                entriesByOutcome[outcome.outcome_id] ?? [],
                start: outcome.start,
                end: outcome.end,
                calendar: calendar
            )
            let snapshot = snapshotsByOutcome[outcome.outcome_id]
            let chartRows: [OutcomesMeasureEntry]
            if rows.isEmpty, let snapshot {
                chartRows = [
                    OutcomesMeasureEntry(
                        outcome_id: snapshot.outcome_id,
                        measure: snapshot.measure,
                        measure_amt: snapshot.measure_amt,
                        measuredAt: snapshot.measuredAt,
                        createdAt: snapshot.measure_updated,
                        format: snapshot.format,
                        unit: snapshot.unit,
                        decimalPlaces: snapshot.decimalPlaces
                    )
                ]
            } else {
                chartRows = rows
            }

            guard let firstRow = chartRows.first else { return nil }
            let latestRow = chartRows.last ?? firstRow
            let goalValue = snapshot?.measure_amt ?? latestRow.measure_amt
            let decimalPlaces = snapshot?.decimalPlaces ?? latestRow.decimalPlaces ?? 0

            return LittleWinsShareGoalProgressData(
                outcomeID: outcome.outcome_id,
                title: outcome.outcome.trimmed.nonEmptyOr("Measured Goal"),
                category: outcome.category.trimmed.nonEmptyOr("Outcome"),
                startDate: outcome.start,
                endDate: outcome.end,
                startValue: firstRow.measure,
                currentValue: latestRow.measure,
                goalValue: goalValue,
                latestDate: latestRow.measuredAt,
                chartPoints: chartRows.map {
                    LittleWinsShareGoalProgressPoint(date: $0.measuredAt, value: $0.measure)
                },
                format: snapshot?.format ?? latestRow.format ?? outcome.format,
                unit: snapshot?.unit ?? latestRow.unit,
                decimalPlaces: decimalPlaces,
                isBehindGoalPath: computeIsBehindGoalPath(
                    startValue: firstRow.measure,
                    goalValue: goalValue,
                    latestValue: latestRow.measure,
                    startDate: outcome.start,
                    endDate: outcome.end,
                    currentDate: latestRow.measuredAt
                )
            )
        }

        return candidates.sorted {
            if abs($0.progressFraction - $1.progressFraction) < 0.001 {
                return $0.latestDate > $1.latestDate
            }
            return $0.progressFraction > $1.progressFraction
        }.first
    }

    private static func buildAppleHealthVerifiedStory(
        foci: [FulfillmentFocus],
        categoryTitleByID: [UUID: String],
        featuredActiveGoal: LittleWinsShareGoalProgressData?
    ) -> LittleWinsShareAppleHealthVerifiedData? {
        let candidates = foci.compactMap { focus -> LittleWinsShareAppleHealthVerifiedData? in
            guard let config = LittleWinsIntegrationStore.config(for: focus.id) else { return nil }
            guard config.isEnabled, config.isConnected, config.source == .appleHealth else { return nil }

            let decimalPlaces = config.metric == .sleepHours ? 1 : 0
            return LittleWinsShareAppleHealthVerifiedData(
                focusID: focus.id,
                focusTitle: focus.activity.trimmed.nonEmptyOr("Verified Little Win"),
                categoryTitle: categoryTitleByID[focus.category_id]?.nonEmptyOr("Little Wins") ?? "Little Wins",
                metricTitle: config.metric.title,
                unitLabel: config.metric.unitLabel,
                progressValue: config.progressValue,
                targetValue: config.targetValue,
                decimalPlaces: decimalPlaces,
                updatedAt: config.updatedAtUnix > 0 ? Date(timeIntervalSince1970: config.updatedAtUnix) : nil,
                relatedGoalTitle: featuredActiveGoal?.title
            )
        }

        return candidates.sorted {
            if abs($0.progressFraction - $1.progressFraction) < 0.001 {
                return ($0.updatedAt ?? .distantPast) > ($1.updatedAt ?? .distantPast)
            }
            return $0.progressFraction > $1.progressFraction
        }.first
    }

    private static func buildLatestAchievedGoal(
        completedOutcomes: [CompletedOutcomeArchive],
        completedOutcomeMeasurePoints: [CompletedOutcomeMeasurePointArchive]
    ) -> LittleWinsShareAchievedGoalData? {
        guard let archive = completedOutcomes.first(where: \.goalMet) else { return nil }
        let chartPoints = completedOutcomeMeasurePoints
            .filter { $0.completedOutcomeArchiveId == archive.id }
            .sorted { $0.measuredAt < $1.measuredAt }
            .map { LittleWinsShareGoalProgressPoint(date: $0.measuredAt, value: $0.measure) }
        let decimalPlaces = inferredDecimalPlaces(
            values: chartPoints.map(\.value) + [archive.goalValue, archive.finalValue].compactMap { $0 }
        )

        return LittleWinsShareAchievedGoalData(
            archiveID: archive.id,
            title: archive.outcome.trimmed.nonEmptyOr("Completed Goal"),
            category: archive.category.trimmed.nonEmptyOr("Outcome"),
            completedAt: archive.completedAt,
            goalValue: archive.goalValue,
            finalValue: archive.finalValue,
            daysElapsed: archive.daysElapsed,
            goalMet: archive.goalMet,
            isMeasurable: archive.isMeasurable,
            chartPoints: chartPoints,
            startDate: archive.start,
            endDate: archive.end,
            format: archive.format,
            decimalPlaces: decimalPlaces
        )
    }

    private static func buildFulfillmentStory(
        fulfillments: [Fulfillment],
        snapshots: [FulfillmentCategoryScoreSnapshot]
    ) -> LittleWinsShareFulfillmentStoryData? {
        guard !fulfillments.isEmpty else { return nil }

        let calendar = Calendar.current
        let currentWeek = FulfillmentScoringMath.weekWindow(for: .now, calendar: calendar).weekStart
        guard let priorWeek = calendar.date(byAdding: .day, value: -7, to: currentWeek) else { return nil }

        struct SnapshotRow {
            let fulfillment: Fulfillment
            let snapshot: FulfillmentCategoryScoreSnapshot
            let delta: Double?
        }

        let currentRows: [SnapshotRow] = fulfillments.compactMap { fulfillment in
            guard let snapshot = snapshots.first(where: {
                $0.categoryID == fulfillment.category_id &&
                calendar.isDate($0.weekStartDate, inSameDayAs: currentWeek)
            }) else { return nil }

            let prior = snapshots.first(where: {
                $0.categoryID == fulfillment.category_id &&
                calendar.isDate($0.weekStartDate, inSameDayAs: priorWeek)
            })
            let delta = prior.map { roundedTenth(snapshot.score) - roundedTenth($0.score) }

            return SnapshotRow(fulfillment: fulfillment, snapshot: snapshot, delta: delta)
        }

        guard !currentRows.isEmpty else { return nil }

        let featuredRow = currentRows.sorted { lhs, rhs in
            switch (lhs.delta, rhs.delta) {
            case let (.some(left), .some(right)) where abs(left - right) > 0.01:
                return left > right
            case (.some, nil):
                return true
            case (nil, .some):
                return false
            default:
                return lhs.snapshot.score > rhs.snapshot.score
            }
        }.first

        guard let featuredRow else { return nil }

        let metrics = currentRows.map { row in
            LittleWinsShareFulfillmentMetric(
                title: row.fulfillment.category.trimmed.nonEmptyOr("Fulfillment"),
                color: FulfillmentCategoryTheme.color(for: row.fulfillment.category),
                percentage: (FulfillmentScoringMath.clamp(row.snapshot.score, 1, 5) / 5.0) * 100.0
            )
        }

        return LittleWinsShareFulfillmentStoryData(
            featuredCategoryTitle: featuredRow.fulfillment.category.trimmed.nonEmptyOr("Fulfillment"),
            featuredColor: FulfillmentCategoryTheme.color(for: featuredRow.fulfillment.category),
            score: featuredRow.snapshot.score,
            delta: featuredRow.delta,
            metrics: metrics
        )
    }

    private static func buildLatestInsight(
        from snapshots: [DiagnosticsInsightsSnapshot]
    ) -> LittleWinsShareInsightData? {
        guard let snapshot = snapshots.first(where: {
            !$0.rootCauseText.trimmed.isEmpty || !$0.nextDirectionText.trimmed.isEmpty
        }) else {
            return nil
        }

        let root = snapshot.rootCauseText.trimmed
        let nextDirection = snapshot.nextDirectionText.trimmed
        guard !root.isEmpty || !nextDirection.isEmpty else { return nil }

        return LittleWinsShareInsightData(
            rootCause: root.nonEmptyOr("Root cause unavailable."),
            nextDirection: nextDirection.nonEmptyOr("Next direction unavailable."),
            generatedAt: snapshot.generatedAt
        )
    }

    private static func latestOutcomeMeasuresByOutcomeID(
        _ rows: [OutcomesMeasure]
    ) -> [UUID: OutcomesMeasure] {
        rows.reduce(into: [:]) { result, row in
            let existing = result[row.outcome_id]
            if existing == nil || row.measure_updated > existing!.measure_updated {
                result[row.outcome_id] = row
            }
        }
    }

    private static func dailyLatestRowsWithinOutcomeWindow(
        _ rows: [OutcomesMeasureEntry],
        start: Date,
        end: Date,
        calendar: Calendar
    ) -> [OutcomesMeasureEntry] {
        let range = calendar.startOfDay(for: start)...calendar.startOfDay(for: end)
        let filtered = rows.filter {
            range.contains(calendar.startOfDay(for: $0.measuredAt))
        }
        let grouped = Dictionary(grouping: filtered) { calendar.startOfDay(for: $0.measuredAt) }
        return grouped.values.compactMap { rows in
            rows.max(by: { $0.createdAt < $1.createdAt })
        }
        .sorted { $0.measuredAt < $1.measuredAt }
    }

    private static func computeIsBehindGoalPath(
        startValue: Double,
        goalValue: Double,
        latestValue: Double,
        startDate: Date,
        endDate: Date,
        currentDate: Date
    ) -> Bool? {
        guard endDate > startDate else { return nil }

        let total = endDate.timeIntervalSince(startDate)
        let elapsed = min(max(0, currentDate.timeIntervalSince(startDate)), total)
        let progress = elapsed / total
        let expected = startValue + (goalValue - startValue) * progress
        let directionUp = goalValue >= startValue

        return directionUp ? (latestValue < expected) : (latestValue > expected)
    }

    private static func inferredDecimalPlaces(values: [Double]) -> Int {
        values.contains(where: { abs($0.rounded() - $0) > 0.001 }) ? 1 : 0
    }

    private static func roundedTenth(_ value: Double) -> Double {
        (value * 10).rounded() / 10
    }

    private static func parseAnalyticsInstallDate(_ raw: String) -> Date? {
        let trimmed = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return nil }

        let formatter = DateFormatter()
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.date(from: trimmed)
    }

    private static func isFocusActive(_ focus: FulfillmentFocus, on date: Date, calendar: Calendar) -> Bool {
        let rule = LittleWinsScheduleStore.rule(for: focus.id)
        if rule.canCompleteAnyDay { return true }

        let normalizedMask = rule.activeWeekdayMask & LittleWinsScheduleRule.everyDayMask
        if normalizedMask == LittleWinsScheduleRule.everyDayMask { return true }

        let weekdayIndex = max(0, min(6, calendar.component(.weekday, from: date) - 1))
        let weekdayBit = 1 << weekdayIndex
        return (normalizedMask & weekdayBit) != 0
    }
}

private extension String {
    var trimmed: String {
        trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var nonEmpty: String? {
        let value = trimmed
        return value.isEmpty ? nil : value
    }

    func nonEmptyOr(_ fallback: String) -> String {
        nonEmpty ?? fallback
    }
}

private extension UIImage {
    func loomNormalizedOrientation() -> UIImage {
        guard imageOrientation != .up else { return self }
        let renderer = UIGraphicsImageRenderer(size: size)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: size))
        }
    }

    func loomResizedToFit(maxLongSide: CGFloat) -> UIImage {
        guard maxLongSide > 0 else { return self }

        let longestSide = max(size.width, size.height)
        guard longestSide.isFinite, longestSide > maxLongSide else { return self }

        let scaleFactor = maxLongSide / longestSide
        let targetSize = CGSize(
            width: max(1, floor(size.width * scaleFactor)),
            height: max(1, floor(size.height * scaleFactor))
        )

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: targetSize, format: format)
        return renderer.image { _ in
            draw(in: CGRect(origin: .zero, size: targetSize))
        }
    }
}
