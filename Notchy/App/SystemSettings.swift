//
//  SystemSettings.swift
//  Notchy
//
//  Reliable deep-linking into System Settings privacy panes.
//  Opening URLs from a background accessory app can silently fail,
//  so we activate ourselves first, try the modern pane identifiers
//  and fall back to the legacy ones.
//

import AppKit

enum SystemSettings {
    static func openCameraPrivacy() {
        openPane(
            modern: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Camera",
            legacy: "x-apple.systempreferences:com.apple.preference.security?Privacy_Camera"
        )
    }

    static func openAccessibilityPrivacy() {
        openPane(
            modern: "x-apple.systempreferences:com.apple.settings.PrivacySecurity.extension?Privacy_Accessibility",
            legacy: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility"
        )
    }

    private static func openPane(modern: String, legacy: String) {
        NSApp.activate(ignoringOtherApps: true)

        for raw in [modern, legacy] {
            guard let url = URL(string: raw) else { continue }
            if NSWorkspace.shared.open(url) {
                return
            }
        }
    }
}
