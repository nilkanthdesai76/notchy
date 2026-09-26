//
//  SettingsWindowController.swift
//  Notchy
//
//  Singleton settings window. An accessory (LSUIElement) app cannot key
//  a window, so we temporarily switch to .regular activation while the
//  settings window is open (proven boring.notch pattern).
//

import AppKit
import SwiftUI

@MainActor
final class SettingsWindowController: NSObject, NSWindowDelegate {
    static let shared = SettingsWindowController()

    private var windowController: NSWindowController?

    func show() {
        NSApp.setActivationPolicy(.regular)
        NSApp.activate(ignoringOtherApps: true)

        if windowController == nil {
            let window = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 720, height: 620),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            window.title = "Notchy Settings"
            window.titlebarAppearsTransparent = true
            window.appearance = NSAppearance(named: .darkAqua)
            window.backgroundColor = NSColor(calibratedWhite: 0.08, alpha: 1.0)
            window.minSize = NSSize(width: 680, height: 560)
            window.center()
            window.contentView = NSHostingView(rootView: SettingsView())
            window.delegate = self
            window.isReleasedWhenClosed = false
            windowController = NSWindowController(window: window)
        }

        windowController?.showWindow(nil)
        windowController?.window?.makeKeyAndOrderFront(nil)
    }

    func windowWillClose(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }
}
