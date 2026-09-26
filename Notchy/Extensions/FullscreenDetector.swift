//
//  FullscreenDetector.swift
//  Notchy
//
//  Monitors display state and active spaces to detect when an app or video
//  is running in full screen, allowing Notchy to suppress live activities.
//

import AppKit
import Combine
import Foundation

@MainActor
final class FullscreenDetector: ObservableObject {
    static let shared = FullscreenDetector()

    @Published private(set) var isFullscreen: Bool = false

    private var pollTimer: Timer?

    private init() {
        checkFullscreen()

        // Space change (Mission Control / fullscreen desktop switch)
        NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.activeSpaceDidChangeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreen()
            }
        }

        // Screen configuration / resolution change
        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreen()
            }
        }

        // Periodic safety check for web full screen / video playback (e.g. YouTube / VLC)
        pollTimer = Timer.scheduledTimer(withTimeInterval: 1.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.checkFullscreen()
            }
        }
    }

    deinit {
        pollTimer?.invalidate()
    }

    func checkFullscreen() {
        guard let screen = NSScreen.main else { return }

        // When a window or space is in fullscreen, the menu bar is autohidden,
        // making the top gap between frame.maxY and visibleFrame.maxY close to 0.
        let topGap = screen.frame.maxY - screen.visibleFrame.maxY
        let detected = topGap < 2.0

        if isFullscreen != detected {
            isFullscreen = detected
        }
    }
}
