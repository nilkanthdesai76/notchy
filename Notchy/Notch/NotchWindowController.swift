//
//  NotchWindowController.swift
//  Notchy
//
//  Owns the NotchPanel for one screen: positioning, hover detection
//  (global event monitors), open/close timing and screen lock handling.
//  The window frame is fixed; only the SwiftUI reveal animates —
//  this avoids all window-frame animation glitches (NotchOTP pattern).
//

import AppKit
import SwiftUI

@MainActor
final class NotchWindowController: NSObject, NSWindowDelegate {
    private(set) var panel: NotchPanel!
    private let viewModel: NotchViewModel
    private let media: MediaManager
    private let clipboard: ClipboardManager
    private let camera: CameraManager

    let screen: NSScreen
    private var hoverMonitor: EventMonitor?
    private var openTask: Task<Void, Never>?
    private var closeTask: Task<Void, Never>?
    private var hoverPollTimer: Timer?
    private var isScreenLocked = false
    /// When the cursor last left the open panel — used by the force-close fallback.
    private var mouseOutsideSince: Date?

    init(screen: NSScreen, media: MediaManager, clipboard: ClipboardManager, camera: CameraManager) {
        self.screen = screen
        self.viewModel = NotchViewModel(screen: screen)
        self.media = media
        self.clipboard = clipboard
        self.camera = camera
        super.init()
        setupPanel(screen: screen)
        startMonitors()
        observeScreenLock()
    }

    func invalidate() {
        hoverPollTimer?.invalidate()
        hoverPollTimer = nil
        hoverMonitor?.stop()
        hoverMonitor = nil
        clickMonitor?.stop()
        clickMonitor = nil
        rightClickMonitor?.stop()
        rightClickMonitor = nil
        keyMonitor?.stop()
        keyMonitor = nil
        panel?.orderOut(nil)
        panel = nil
    }

    deinit {
        hoverPollTimer?.invalidate()
        hoverMonitor?.stop()
        clickMonitor?.stop()
        rightClickMonitor?.stop()
        keyMonitor?.stop()
        panel?.orderOut(nil)
    }

    // MARK: - Setup

    private func setupPanel(screen: NSScreen) {
        let panelWidth = viewModel.openWidth
        let panelHeight = viewModel.topInset + viewModel.contentHeight + 40
        let panelTop = screen.frame.maxY
        let panelX = screen.notchGeometry.centerX - panelWidth / 2

        let panel = NotchPanel(
            contentRect: NSRect(x: panelX, y: panelTop - panelHeight, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        let content = NotchView(viewModel: viewModel)
            .environmentObject(media)
            .environmentObject(clipboard)
            .environmentObject(camera)
        panel.contentView = NotchHostingView(rootView: content, viewModel: viewModel)
        panel.delegate = self
        panel.ignoresMouseEvents = true // closed panel must never block the menu bar
        panel.orderFrontRegardless()
        self.panel = panel
    }

    private func startMonitors() {
        // Global monitors fire even though our app is a background accessory.
        hoverMonitor = EventMonitor(mask: [.mouseMoved, .leftMouseDragged]) { [weak self] _ in
            guard let self else { return }
            Task { @MainActor in
                self.handleMouseMoved()
            }
        }
        hoverMonitor?.start()

        // Click: opens the notch when closed; closes when clicking outside the open panel.
        let clickMonitor = EventMonitor(mask: [.leftMouseDown], scope: .both) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.handleMouseDown()
            }
        }
        clickMonitor.start()
        self.clickMonitor = clickMonitor

        // Right-click on the notch: settings / quit menu (important when the
        // menu bar icon is hidden).
        let rightClickMonitor = EventMonitor(mask: [.rightMouseDown], scope: .local) { [weak self] event in
            guard let self else { return }
            Task { @MainActor in
                self.showContextMenu(event)
            }
        }
        rightClickMonitor.start()
        self.rightClickMonitor = rightClickMonitor

        // Escape closes; Cmd+Q quits; Cmd+1/2/3 and arrows switch pages.
        let keyMonitor = EventMonitor(mask: [.keyDown], scope: .local) { [weak self] event in
            guard let self, self.viewModel.isOpen else { return }
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self.scheduleClose(immediately: true)
                }
            } else if event.modifierFlags.contains(.command) {
                if event.charactersIgnoringModifiers?.lowercased() == "q" {
                    NSApp.terminate(nil)
                } else if event.charactersIgnoringModifiers == "1" {
                    Task { @MainActor in self.viewModel.selectPage(0) }
                } else if event.charactersIgnoringModifiers == "2" {
                    Task { @MainActor in self.viewModel.selectPage(1) }
                } else if event.charactersIgnoringModifiers == "3" {
                    Task { @MainActor in self.viewModel.selectPage(2) }
                } else if event.keyCode == 123 { // Left arrow
                    Task { @MainActor in self.viewModel.rewindPage() }
                } else if event.keyCode == 124 { // Right arrow
                    Task { @MainActor in self.viewModel.advancePage() }
                }
            }
        }
        keyMonitor.start()
        self.keyMonitor = keyMonitor

        // Safety net: global mouseMoved events occasionally get dropped
        // (wake from sleep, Space switches, display changes). Poll the cursor
        // so a hovering user always opens the notch even with zero events.
        hoverPollTimer = Timer.scheduledTimer(withTimeInterval: 0.06, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.handleMouseMoved()
            }
        }
    }

    private var clickMonitor: EventMonitor?
    private var keyMonitor: EventMonitor?
    private var rightClickMonitor: EventMonitor?

    private func observeScreenLock() {
        let center = DistributedNotificationCenter.default()
        center.addObserver(self, selector: #selector(screenLocked), name: NSNotification.Name("com.apple.screenIsLocked"), object: nil)
        center.addObserver(self, selector: #selector(screenUnlocked), name: NSNotification.Name("com.apple.screenIsUnlocked"), object: nil)
    }

    @objc private func screenLocked() {
        isScreenLocked = true
        panel?.orderOut(nil)
        openTask?.cancel()
        closeTask?.cancel()
        camera.stop()
    }

    @objc private func screenUnlocked() {
        isScreenLocked = false
        panel?.orderFrontRegardless()
    }

    // MARK: - Hover / click handling

    private var notchHotScreenRect: NSRect {
        let geom = screen.notchGeometry
        let notchWidth = geom.hasNotch ? geom.size.width : 220
        let menuBarHeight = max(screen.frame.maxY - screen.visibleFrame.maxY, 28)
        let notchHeight = geom.hasNotch ? geom.size.height : menuBarHeight
        // Screen coordinates: y = screen.frame.maxY is the physical top bezel
        return NSRect(
            x: geom.centerX - notchWidth / 2 - 16,
            y: screen.frame.maxY - notchHeight - 6,
            width: notchWidth + 32,
            height: notchHeight + 10
        )
    }

    private var expandedStayScreenRect: NSRect {
        let panelWidth = viewModel.openWidth
        let totalHeight = viewModel.topInset + viewModel.contentHeight + 20
        return NSRect(
            x: screen.notchGeometry.centerX - panelWidth / 2 - 16,
            y: screen.frame.maxY - totalHeight - 16,
            width: panelWidth + 32,
            height: totalHeight + 24
        )
    }

    private func handleMouseMoved() {
        guard !isScreenLocked, panel != nil else { return }
        let mouse = NSEvent.mouseLocation
        if !viewModel.isOpen {
            let inside = notchHotScreenRect.contains(mouse)
            if panel.ignoresMouseEvents == inside {
                panel.ignoresMouseEvents = !inside
            }
            if inside {
                scheduleOpen()
            } else {
                openTask?.cancel()
                openTask = nil
            }
        } else {
            if panel.ignoresMouseEvents {
                panel.ignoresMouseEvents = false
            }
            if expandedStayScreenRect.contains(mouse) {
                closeTask?.cancel()
                closeTask = nil
                mouseOutsideSince = nil
            } else {
                if mouseOutsideSince == nil {
                    mouseOutsideSince = Date()
                }
                scheduleClose()
            }
        }

        // Force-close fallback: if cursor is outside for a while, close.
        if viewModel.isOpen, let since = mouseOutsideSince,
           Date().timeIntervalSince(since) > 1.2 {
            closeTask?.cancel()
            closeTask = nil
            mouseOutsideSince = nil
            close()
        }
    }

    private func handleMouseDown() {
        let mouse = NSEvent.mouseLocation
        if viewModel.isOpen {
            if !expandedStayScreenRect.contains(mouse) {
                scheduleClose(immediately: true)
            }
        } else {
            if notchHotScreenRect.contains(mouse) {
                open()
            }
        }
    }

    private func showContextMenu(_ event: NSEvent) {
        let menu = NSMenu(title: "Notchy")
        let settingsItem = NSMenuItem(title: "Settings…", action: #selector(openSettings), keyEquivalent: "")
        settingsItem.target = self
        let quitItem = NSMenuItem(title: "Quit Notchy", action: #selector(quitApp), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(settingsItem)
        menu.addItem(.separator())
        menu.addItem(quitItem)
        menu.popUp(positioning: nil, at: event.locationInWindow, in: panel.contentView)
    }

    @objc private func openSettings() {
        SettingsWindowController.shared.show()
    }

    @objc private func quitApp() {
        NSApp.terminate(nil)
    }

    private var hoverDelay: TimeInterval {
        if let value = UserDefaults.standard.object(forKey: "hoverDelay") as? Double {
            return value
        }
        return 0.05
    }

    /// Schedule the open after the hover delay. Repeated triggers (poll timer,
    /// continuous mouse-moved events) must NOT reschedule — a rescheduled task
    /// would never get the chance to run.
    private func scheduleOpen() {
        if openTask != nil { return }
        let delay = hoverDelay
        openTask = Task { [weak self] in
            defer { self?.openTask = nil }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.open()
        }
    }

    func scheduleClose(immediately: Bool = false) {
        if closeTask != nil { return }
        let delay: TimeInterval = immediately ? 0 : 0.12
        closeTask = Task { [weak self] in
            defer { self?.closeTask = nil }
            try? await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.close()
        }
    }

    // MARK: - Open / close

    private func open() {
        guard !viewModel.isOpen, !isScreenLocked else { return }
        openTask?.cancel()
        openTask = nil
        closeTask?.cancel()
        closeTask = nil
        mouseOutsideSince = nil
        panel.ignoresMouseEvents = false
        panel.orderFrontRegardless()
        viewModel.isOpen = true
        viewModel.reveal = 1
        NSHapticFeedbackManager.defaultPerformer.perform(.levelChange, performanceTime: .default)
    }

    private func close() {
        guard viewModel.isOpen else { return }
        viewModel.isOpen = false
        viewModel.reveal = 0
        mouseOutsideSince = nil
        camera.stop() // green light off the moment the notch starts hiding
        // Cursor-driven click-through (see handleMouseMoved) re-enables
        // interaction within one poll tick if the cursor is over the notch.
        panel.ignoresMouseEvents = true
    }
}
