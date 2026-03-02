import SwiftUI
import SwiftData
import AVFoundation
import Photos
import CoreImage
import CoreImage.CIFilterBuiltins
import UIKit

struct LittleWinsShareCameraView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    @Query(sort: \Fulfillment.updatedAt, order: .forward)
    private var fulfillments: [Fulfillment]
    @Query(sort: \FulfillmentFocus.rank, order: .forward)
    private var foci: [FulfillmentFocus]
    @Query(sort: \LittleWinsDailyCompletion.completedAt, order: .reverse)
    private var completions: [LittleWinsDailyCompletion]

    @StateObject private var cameraSession = LittleWinsShareCameraSession()
    @State private var selectedTemplate: LittleWinsShareTemplate = .todaysWins
    @State private var selectedFilter: LittleWinsShareImageFilter = .vivid
    @State private var capturedImage: UIImage?
    @State private var hasRequestedCameraAccess = false
    @State private var isRenderingCapture = false
    @State private var showCaptureFailureAlert = false

    private let ciContext = CIContext()
    private let templateSwipeThreshold: CGFloat = 40

    private var isCameraDenied: Bool {
        cameraSession.authorizationStatus == .denied || cameraSession.authorizationStatus == .restricted
    }

    private var overlayData: LittleWinsShareOverlayData {
        LittleWinsShareOverlayDataFactory.build(
            fulfillments: fulfillments,
            foci: foci,
            completions: completions
        )
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
                    onDone: { dismiss() }
                )
            } else if isCameraDenied {
                LittleWinsCameraPermissionDeniedView(onClose: { dismiss() })
            } else {
                liveCameraView
            }
        }
        .task {
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

            LittleWinsShareOverlayTemplateView(template: selectedTemplate, data: overlayData)
                .ignoresSafeArea()
                .allowsHitTesting(false)

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
                    .padding(.horizontal, 16)
                    .padding(.top, 8)

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
        .contentShape(Rectangle())
        .simultaneousGesture(
            DragGesture(minimumDistance: 24)
                .onEnded(handleTemplateSwipe)
        )
    }

    private var topControls: some View {
        HStack {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)

            Spacer()

            Button {
                Task { await cameraSession.toggleCamera() }
            } label: {
                Image(systemName: "camera.rotate")
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                    .frame(width: 36, height: 36)
                    .background(Color.black.opacity(0.42), in: Circle())
            }
            .buttonStyle(.plain)
            .disabled(!cameraSession.isConfigured || isRenderingCapture)
            .opacity(cameraSession.isConfigured ? 1 : 0.6)
        }
    }

    private var bottomControls: some View {
        captureControlsRow
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
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
            .disabled(!cameraSession.isSessionRunning || isRenderingCapture)
            .opacity((cameraSession.isSessionRunning && !isRenderingCapture) ? 1 : 0.55)

            Spacer()

            Color.clear.frame(width: 56, height: 56)
        }
    }

    private var livePreviewSaturation: Double {
        switch selectedFilter {
        case .vivid:
            return 1.32
        case .warm:
            return 1.10
        case .mono:
            return 0
        }
    }

    private var livePreviewContrast: Double {
        switch selectedFilter {
        case .vivid:
            return 1.12
        case .warm:
            return 1.05
        case .mono:
            return 1.05
        }
    }

    private var livePreviewBrightness: Double {
        switch selectedFilter {
        case .vivid:
            return 0.02
        case .warm:
            return 0
        case .mono:
            return 0
        }
    }

    @ViewBuilder
    private var livePreviewToneOverlay: some View {
        switch selectedFilter {
        case .warm:
            LinearGradient(
                colors: [
                    Color(red: 1.0, green: 0.85, blue: 0.62).opacity(0.20),
                    Color.clear
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        default:
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
        guard !isRenderingCapture else { return }
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
        guard let filtered = applyFilter(to: normalized, style: selectedFilter) else { return nil }
        guard let overlay = renderOverlayImage(size: filtered.size) else { return filtered }
        return composite(base: filtered, overlay: overlay)
    }

    @MainActor
    private func renderOverlayImage(size: CGSize) -> UIImage? {
        let referenceWidth = max(UIScreen.main.bounds.width, 1)
        let referenceHeight = referenceWidth * (size.height / max(size.width, 1))
        let overlayView = LittleWinsShareOverlayTemplateView(template: selectedTemplate, data: overlayData)
            .frame(width: referenceWidth, height: referenceHeight)
            .ignoresSafeArea()
        let renderer = ImageRenderer(content: overlayView)
        renderer.scale = 1
        renderer.proposedSize = .init(width: referenceWidth, height: referenceHeight)
        return renderer.uiImage
    }

    private func handleTemplateSwipe(_ value: DragGesture.Value) {
        guard abs(value.translation.width) > abs(value.translation.height) else { return }
        guard abs(value.translation.width) >= templateSwipeThreshold else { return }
        if value.translation.width < 0 {
            selectNextTemplate()
        } else {
            selectPreviousTemplate()
        }
    }

    private func selectNextTemplate() {
        let all = LittleWinsShareTemplate.allCases
        guard let index = all.firstIndex(of: selectedTemplate) else {
            selectedTemplate = .todaysWins
            return
        }
        let nextIndex = (index + 1) % all.count
        selectedTemplate = all[nextIndex]
    }

    private func selectPreviousTemplate() {
        let all = LittleWinsShareTemplate.allCases
        guard let index = all.firstIndex(of: selectedTemplate) else {
            selectedTemplate = .todaysWins
            return
        }
        let previousIndex = (index - 1 + all.count) % all.count
        selectedTemplate = all[previousIndex]
    }

    private func applyFilter(to image: UIImage, style: LittleWinsShareImageFilter) -> UIImage? {
        guard let inputImage = CIImage(image: image) else { return nil }

        let outputImage: CIImage
        switch style {
        case .vivid:
            let filter = CIFilter.colorControls()
            filter.inputImage = inputImage
            filter.saturation = 1.32
            filter.contrast = 1.12
            filter.brightness = 0.02
            guard let result = filter.outputImage else { return nil }
            outputImage = result
        case .warm:
            let tempFilter = CIFilter.temperatureAndTint()
            tempFilter.inputImage = inputImage
            tempFilter.neutral = CIVector(x: 6500, y: 0)
            tempFilter.targetNeutral = CIVector(x: 7900, y: 0)
            guard let warmed = tempFilter.outputImage else { return nil }

            let controls = CIFilter.colorControls()
            controls.inputImage = warmed
            controls.saturation = 1.10
            controls.contrast = 1.05
            guard let result = controls.outputImage else { return nil }
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
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: base.size, format: format)
        return renderer.image { context in
            base.draw(in: CGRect(origin: .zero, size: base.size))
            overlay.draw(in: CGRect(origin: .zero, size: base.size))
            _ = context
        }
    }
}

private struct LittleWinsSharePreviewView: View {
    let image: UIImage
    let onRetake: () -> Void
    let onDone: () -> Void

    @State private var isShowingShareSheet = false
    @State private var isSaving = false
    @State private var feedbackMessage = ""
    @State private var feedbackTitle = ""
    @State private var isShowingFeedback = false

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            VStack(spacing: 14) {
                HStack {
                    Button("Retake") {
                        onRetake()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)

                    Spacer()

                    Button("Done") {
                        onDone()
                    }
                    .font(.headline.weight(.semibold))
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)

                GeometryReader { proxy in
                    Image(uiImage: image)
                        .resizable()
                        .scaledToFit()
                        .frame(width: proxy.size.width, height: proxy.size.height)
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
        }
        .sheet(isPresented: $isShowingShareSheet) {
            LittleWinsShareActivityView(items: [image])
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
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) { }
}

private enum LittleWinsShareOverlayDataFactory {
    static func build(
        fulfillments: [Fulfillment],
        foci: [FulfillmentFocus],
        completions: [LittleWinsDailyCompletion]
    ) -> LittleWinsShareOverlayData {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let categoryTitleByID = Dictionary(uniqueKeysWithValues: fulfillments.map {
            ($0.category_id, $0.category.trimmed)
        })

        let focusByID = Dictionary(uniqueKeysWithValues: foci.map { ($0.id, $0) })
        let activeFoci = foci.filter { isFocusActive($0, on: today, calendar: calendar) }
        let activeByCategory = Dictionary(grouping: activeFoci, by: \.category_id)

        var workingCards: [LittleWinsShareOverlayCard] = activeByCategory.map { entry in
            let categoryID = entry.key
            let categoryFoci = entry.value
            let cardTitle = (categoryTitleByID[categoryID] ?? "Little Wins").nonEmptyOr("Little Wins")
            let wins = categoryFoci
                .sorted { lhs, rhs in
                    if lhs.rank == rhs.rank {
                        return lhs.activity.localizedCaseInsensitiveCompare(rhs.activity) == .orderedAscending
                    }
                    return lhs.rank < rhs.rank
                }
                .map { $0.activity.trimmed }
                .filter { !$0.isEmpty }
            return LittleWinsShareOverlayCard(title: cardTitle, wins: wins)
        }
        workingCards = workingCards.filter { card in !card.wins.isEmpty }
        workingCards.sort { lhs, rhs in
            lhs.title.localizedCaseInsensitiveCompare(rhs.title) == .orderedAscending
        }

        var completionFocusIDsByDay: [Date: Set<UUID>] = [:]
        completionFocusIDsByDay.reserveCapacity(16)
        for row in completions {
            let day = calendar.startOfDay(for: row.day)
            completionFocusIDsByDay[day, default: []].insert(row.focusId)
        }

        let completedTodayFocusIDs = completionFocusIDsByDay[today] ?? []
        var completedWins: [String] = completedTodayFocusIDs.compactMap { focusID in
            let local = focusByID[focusID]?.activity ?? ""
            return local.trimmed.nonEmpty
        }
        .sorted { lhs, rhs in
            lhs.localizedCaseInsensitiveCompare(rhs) == .orderedAscending
        }

        if completedWins.isEmpty {
            var seen = Set<UUID>()
            var fallback: [String] = []
            for row in completions {
                guard seen.insert(row.focusId).inserted else { continue }
                let local = (focusByID[row.focusId]?.activity ?? "").trimmed.nonEmpty
                let snapshot = (row.focusTitleSnapshot ?? "").trimmed.nonEmpty
                if let value = local ?? snapshot {
                    fallback.append(value)
                }
                if fallback.count >= 6 { break }
            }
            completedWins = fallback
        }

        let last7DayCompletionCounts: [Int] = stride(from: 6, through: 0, by: -1).map { dayOffset in
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { return 0 }
            return completionFocusIDsByDay[calendar.startOfDay(for: day)]?.count ?? 0
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

        let totalWeekCompletions = last7DayCompletionCounts.reduce(0, +)
        let hotStreak = streak >= 5

        return LittleWinsShareOverlayData(
            workingCards: workingCards,
            completedWins: completedWins,
            last7DayCompletionCounts: last7DayCompletionCounts,
            streak: streak,
            hotStreak: hotStreak,
            totalWeekCompletions: totalWeekCompletions
        )
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
}
