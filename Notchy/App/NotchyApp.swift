//
//  NotchyApp.swift
//  Notchy
//
//  Menu-bar-only app: no Dock icon (LSUIElement), the notch is the UI.
//

import SwiftUI

@main
struct NotchyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    // Hidden by default — the notch IS the UI. Re-enable from Settings.
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false

    init() {
        // Kick off license / trial check as early as possible
        Task { await LicenseManager.shared.checkOnLaunch() }
    }

    var body: some Scene {
        MenuBarExtra("Notchy", systemImage: "macbook.gen2", isInserted: $showMenuBarIcon) {
            Button("Settings…") {
                SettingsWindowController.shared.show()
            }
            .keyboardShortcut(",")

            Divider()

            Button("Quit Notchy") {
                NSApplication.shared.terminate(nil)
            }
            .keyboardShortcut("q")
        }
        .menuBarExtraStyle(.menu)
    }
}
