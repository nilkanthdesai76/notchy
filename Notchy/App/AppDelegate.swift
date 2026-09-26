//
//  AppDelegate.swift
//  Notchy
//
//  Creates the shared module managers and the notch panel,
//  and rebuilds it when the screen configuration changes.
//

import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    let media = MediaManager()
    let clipboard = ClipboardManager()
    let camera = CameraManager()

    private var notchController: NotchWindowController?
    private var rebuildTask: Task<Void, Never>?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        terminateOtherInstances()
        rebuildForCurrentScreen()

        NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            // This notification fires in a burst while displays reconfigure.
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.rebuildTask?.cancel()
                self.rebuildTask = Task { @MainActor [weak self] in
                    try? await Task.sleep(nanoseconds: 500_000_000)
                    guard !Task.isCancelled, let self else { return }
                    self.rebuildForCurrentScreen()
                }
            }
        }
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationWillTerminate(_ notification: Notification) {
        // Reap the mediaremote-adapter perl child; SIGTERM quits reach this.
        media.shutdown()
        camera.stop()
    }

    /// A notch utility must never run in two copies — terminate the previous
    /// instance (gracefully, so its adapter process is reaped) before showing
    /// our panel, otherwise two panels overlap in the notch.
    private func terminateOtherInstances() {
        guard let bundleID = Bundle.main.bundleIdentifier else { return }
        let myPID = ProcessInfo.processInfo.processIdentifier
        let others = NSRunningApplication
            .runningApplications(withBundleIdentifier: bundleID)
            .filter { $0.processIdentifier != myPID }
        guard !others.isEmpty else { return }

        for app in others {
            app.terminate()
        }
        // Briefly wait so the old panel is gone before ours appears.
        for _ in 0..<20 {
            let remaining = NSRunningApplication
                .runningApplications(withBundleIdentifier: bundleID)
                .filter { $0.processIdentifier != myPID }
            if remaining.isEmpty { break }
            Thread.sleep(forTimeInterval: 0.1)
        }
    }

    private func rebuildForCurrentScreen() {
        notchController = NotchWindowController(
            screen: targetScreen(),
            media: media,
            clipboard: clipboard,
            camera: camera
        )
    }

    /// Prefer the built-in notched screen; fall back to the main screen.
    private func targetScreen() -> NSScreen {
        NSScreen.screens.first { $0.notchGeometry.hasNotch }
            ?? NSScreen.main
            ?? NSScreen.screens[0]
    }
}
