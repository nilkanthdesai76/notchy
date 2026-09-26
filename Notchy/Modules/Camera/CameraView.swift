//
//  CameraView.swift
//  Notchy
//
//  Rounded rectangle selfie mirror partitioned for panel width.
//

@preconcurrency import AVFoundation
import SwiftUI
import Combine

struct CameraView: View {
    @EnvironmentObject private var camera: CameraManager
    @Environment(\.moduleCornerRadii) private var radii
    @State private var isHovered = false

    var body: some View {
        Button {
            if camera.authorization == .denied {
                SystemSettings.openCameraPrivacy()
            } else if camera.isRunning {
                camera.stop()
            } else {
                camera.start()
            }
        } label: {
            ZStack {
                if camera.isRunning, let layer = camera.previewLayer {
                    CameraPreview(layer: layer)
                        .scaleEffect(x: -1, y: 1) // Mirror reflection flip
                        .clipShape(radii.asShape)
                        .overlay(
                            radii.asShape
                                .strokeBorder(Color.green.opacity(0.8), lineWidth: 1.5)
                        )
                        .overlay(alignment: .topTrailing) {
                            HStack(spacing: 3) {
                                Circle()
                                    .fill(Color.green)
                                    .frame(width: 5, height: 5)
                            }
                            .padding(6)
                        }
                        .overlay(alignment: .bottom) {
                            if isHovered {
                                HStack(spacing: 4) {
                                    Image(systemName: "video.slash.fill")
                                        .font(.system(size: 8))
                                    Text("Stop")
                                        .font(.system(size: 9, weight: .semibold))
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 3)
                                .background(Color.black.opacity(0.65), in: Capsule())
                                .padding(.bottom, 8)
                                .transition(.opacity.combined(with: .scale(scale: 0.9)))
                            }
                        }
                } else {
                    VStack(spacing: 6) {
                        ZStack {
                            Circle()
                                .fill(Color.white.opacity(0.08))
                                .frame(width: 32, height: 32)
                            Image(systemName: camera.authorization == .denied ? "exclamationmark.triangle" : "video.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(camera.authorization == .denied ? .orange : .white.opacity(isHovered ? 0.95 : 0.7))
                        }

                        Text(camera.authorization == .denied ? "Denied" : "Mirror")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(.white.opacity(isHovered ? 0.9 : 0.6))
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .liquidGlassPod()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .contentShape(radii.asShape)
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
        .help(camera.isRunning ? "Click to turn off mirror" : "Click to turn on selfie mirror")
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onDisappear {
            camera.stop()
        }
    }
}

/// Hosts the AVCaptureVideoPreviewLayer inside SwiftUI.
private struct CameraPreview: NSViewRepresentable {
    let layer: AVCaptureVideoPreviewLayer

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        view.wantsLayer = true
        layer.frame = view.bounds
        layer.videoGravity = .resizeAspectFill
        layer.autoresizingMask = [.layerWidthSizable, .layerHeightSizable]
        view.layer = layer
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.frame = nsView.bounds
        CATransaction.commit()
    }
}
