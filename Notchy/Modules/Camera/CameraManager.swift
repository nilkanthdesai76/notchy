//
//  CameraManager.swift
//  Notchy
//
//  Front-camera selfie preview. The capture session only runs while
//  the preview is visible — nothing watches you in the background.
//

@preconcurrency import AVFoundation
import AppKit
import Combine

@MainActor
final class CameraManager: ObservableObject {
    enum Authorization: Equatable {
        case notDetermined
        case authorized
        case denied
    }

    @Published private(set) var authorization: Authorization = .notDetermined
    @Published private(set) var previewLayer: AVCaptureVideoPreviewLayer?
    @Published private(set) var isRunning = false

    nonisolated private let session = AVCaptureSession()
    nonisolated private let sessionQueue = DispatchQueue(label: "com.nilkanth.Notchy.camera-session")

    init() {
        refreshAuthorization()
    }

    private func refreshAuthorization() {
        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            authorization = .authorized
        case .denied, .restricted:
            authorization = .denied
        default:
            authorization = .notDetermined
        }
    }

    // MARK: - Session control

    func start() {
        guard !isRunning else { return }
        refreshAuthorization()

        switch AVCaptureDevice.authorizationStatus(for: .video) {
        case .authorized:
            break
        case .notDetermined:
            AVCaptureDevice.requestAccess(for: .video) { [weak self] granted in
                Task { @MainActor [weak self] in
                    guard let self else { return }
                    self.refreshAuthorization()
                    if granted { self.start() }
                }
            }
            return
        default:
            authorization = .denied
            return
        }

        let session = self.session
        sessionQueue.async { [weak self, session] in
            Self.configure(session)
            guard !session.inputs.isEmpty else { return }
            session.startRunning()

            let layer = AVCaptureVideoPreviewLayer(session: session)
            layer.videoGravity = .resizeAspectFill
            Task { @MainActor [weak self] in
                self?.previewLayer = layer
                self?.isRunning = true
            }
        }
    }

    func stop() {
        guard isRunning else { return }
        isRunning = false
        previewLayer = nil
        let session = self.session
        sessionQueue.async {
            session.stopRunning()
        }
    }

    nonisolated private static func configure(_ session: AVCaptureSession) {
        session.beginConfiguration()
        defer { session.commitConfiguration() }

        for input in session.inputs {
            session.removeInput(input)
        }

        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera],
            mediaType: .video,
            position: .front
        )
        guard let device = discovery.devices.first,
              let input = try? AVCaptureDeviceInput(device: device) else { return }
        session.addInput(input)
    }
}
