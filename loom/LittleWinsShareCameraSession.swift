import SwiftUI
@preconcurrency import AVFoundation
import UIKit

final class LittleWinsShareCameraSession: NSObject, ObservableObject {
    @Published private(set) var authorizationStatus: AVAuthorizationStatus
    @Published private(set) var isConfigured = false
    @Published private(set) var isSessionRunning = false
    @Published private(set) var activePosition: AVCaptureDevice.Position = .front

    let session = AVCaptureSession()

    private let sessionQueue = DispatchQueue(
        label: "loom.littlewins.share.camera.session",
        qos: .userInitiated
    )
    private let photoOutput = AVCapturePhotoOutput()
    private let preferredCaptureLongSide: Int32 = 2560
    private var pendingContinuation: CheckedContinuation<UIImage?, Never>?

    override init() {
        authorizationStatus = AVCaptureDevice.authorizationStatus(for: .video)
        super.init()
    }

    func requestAccessAndConfigureIfNeeded() async -> Bool {
        let currentStatus = AVCaptureDevice.authorizationStatus(for: .video)
        await MainActor.run {
            authorizationStatus = currentStatus
        }

        switch currentStatus {
        case .authorized:
            break
        case .notDetermined:
            let granted = await AVCaptureDevice.requestAccess(for: .video)
            let updated = AVCaptureDevice.authorizationStatus(for: .video)
            await MainActor.run {
                authorizationStatus = updated
            }
            guard granted else { return false }
        case .denied, .restricted:
            return false
        @unknown default:
            return false
        }

        if !isConfigured {
            await configure(position: .front)
        }
        return true
    }

    func startSession() {
        sessionQueue.async {
            guard self.isConfigured, !self.session.isRunning else { return }
            self.session.startRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = true
            }
        }
    }

    func stopSession() {
        sessionQueue.async {
            guard self.session.isRunning else { return }
            self.session.stopRunning()
            DispatchQueue.main.async {
                self.isSessionRunning = false
            }
        }
    }

    func toggleCamera() async {
        let nextPosition: AVCaptureDevice.Position = (activePosition == .front) ? .back : .front
        await configure(position: nextPosition)
        startSession()
    }

    func capturePhoto() async -> UIImage? {
        await withCheckedContinuation { continuation in
            sessionQueue.async {
                guard self.isConfigured else {
                    continuation.resume(returning: nil)
                    return
                }
                guard self.pendingContinuation == nil else {
                    continuation.resume(returning: nil)
                    return
                }

                self.pendingContinuation = continuation

                let settings = AVCapturePhotoSettings()
                settings.flashMode = .off
                settings.maxPhotoDimensions = self.photoOutput.maxPhotoDimensions
                settings.photoQualityPrioritization = .balanced

                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = self.activePosition == .front
                }

                self.photoOutput.capturePhoto(with: settings, delegate: self)
            }
        }
    }

    private func configure(position: AVCaptureDevice.Position) async {
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            sessionQueue.async {
                defer { continuation.resume() }

                self.session.beginConfiguration()
                self.session.sessionPreset = .photo

                self.session.inputs.forEach { self.session.removeInput($0) }
                self.session.outputs.forEach { self.session.removeOutput($0) }

                guard let device = Self.cameraDevice(for: position),
                      let input = try? AVCaptureDeviceInput(device: device),
                      self.session.canAddInput(input) else {
                    self.session.commitConfiguration()
                    DispatchQueue.main.async {
                        self.isConfigured = false
                    }
                    return
                }

                self.session.addInput(input)

                if self.session.canAddOutput(self.photoOutput) {
                    self.session.addOutput(self.photoOutput)
                    if let preferredDimensions = self.preferredPhotoDimensions(for: device) {
                        self.photoOutput.maxPhotoDimensions = preferredDimensions
                    }
                }

                if let connection = self.photoOutput.connection(with: .video),
                   connection.isVideoMirroringSupported {
                    connection.automaticallyAdjustsVideoMirroring = false
                    connection.isVideoMirrored = position == .front
                }

                self.session.commitConfiguration()

                DispatchQueue.main.async {
                    self.activePosition = position
                    self.isConfigured = true
                }
            }
        }
    }

    private static func cameraDevice(for position: AVCaptureDevice.Position) -> AVCaptureDevice? {
        if let wide = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: position) {
            return wide
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualWideCamera, .builtInTrueDepthCamera],
            mediaType: .video,
            position: position
        )
        return discovery.devices.first
    }

    private func preferredPhotoDimensions(for device: AVCaptureDevice) -> CMVideoDimensions? {
        let supported = device.activeFormat.supportedMaxPhotoDimensions
        guard !supported.isEmpty else { return nil }

        func longSide(_ dimensions: CMVideoDimensions) -> Int32 {
            max(dimensions.width, dimensions.height)
        }

        let underOrEqualTarget = supported
            .filter { longSide($0) <= preferredCaptureLongSide }
            .max { lhs, rhs in
                Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
            }

        if let underOrEqualTarget {
            return underOrEqualTarget
        }

        return supported.min { lhs, rhs in
            Int(lhs.width) * Int(lhs.height) < Int(rhs.width) * Int(rhs.height)
        }
    }
}

extension LittleWinsShareCameraSession: @unchecked Sendable {}

extension LittleWinsShareCameraSession: AVCapturePhotoCaptureDelegate {
    nonisolated func photoOutput(
        _ output: AVCapturePhotoOutput,
        didFinishProcessingPhoto photo: AVCapturePhoto,
        error: Error?
    ) {
        let photoData = (error == nil) ? photo.fileDataRepresentation() : nil

        sessionQueue.async {
            guard let continuation = self.pendingContinuation else { return }
            self.pendingContinuation = nil

            guard let photoData,
                  let image = UIImage(data: photoData) else {
                continuation.resume(returning: nil)
                return
            }

            continuation.resume(returning: image)
        }
    }
}

struct LittleWinsShareCameraPreview: UIViewRepresentable {
    let session: AVCaptureSession
    let isMirrored: Bool

    final class PreviewView: UIView {
        override class var layerClass: AnyClass { AVCaptureVideoPreviewLayer.self }
    }

    func makeUIView(context: Context) -> PreviewView {
        let view = PreviewView()
        view.backgroundColor = .black
        configurePreviewLayer(for: view)
        return view
    }

    func updateUIView(_ uiView: PreviewView, context: Context) {
        configurePreviewLayer(for: uiView)
    }

    private func configurePreviewLayer(for view: PreviewView) {
        guard let previewLayer = view.layer as? AVCaptureVideoPreviewLayer else {
            AppDebugActivityLog.log(
                "LittleWinsCamera",
                "Preview layer was not AVCaptureVideoPreviewLayer; showing blank camera preview instead of crashing"
            )
            return
        }

        previewLayer.session = session
        previewLayer.videoGravity = .resizeAspectFill

        if let connection = previewLayer.connection, connection.isVideoMirroringSupported {
            connection.automaticallyAdjustsVideoMirroring = false
            connection.isVideoMirrored = isMirrored
        }
    }
}
