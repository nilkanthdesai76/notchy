//
//  QuickToolsManager.swift
//  Notchy
//
//  Provides Caffeinate (prevent both display and system sleep via IOKit)
//  and Screen Color Eyedropper with instant clipboard copy (HEX and RGB).
//

import AppKit
import Combine
import IOKit.pwr_mgt

@MainActor
final class QuickToolsManager: ObservableObject {
    static let shared = QuickToolsManager()

    @Published var isCaffeinated: Bool = false
    @Published var lastPickedHex: String?
    @Published var lastPickedColor: NSColor?
    @Published var pickedColorFeedback: Bool = false

    private var systemSleepAssertionID: IOPMAssertionID = 0
    private var displaySleepAssertionID: IOPMAssertionID = 0

    deinit {
        // Nonisolated cleanup
        if systemSleepAssertionID != 0 {
            IOPMAssertionRelease(systemSleepAssertionID)
        }
        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
        }
    }

    // MARK: - Caffeinate (Keep Awake)

    func toggleCaffeinate() {
        if isCaffeinated {
            stopCaffeinate()
        } else {
            startCaffeinate()
        }
    }

    func startCaffeinate() {
        stopCaffeinate()

        let reason = "Notchy Keep Awake" as CFString

        // 1. Prevent idle system sleep (CPU keeps running)
        let sysResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &systemSleepAssertionID
        )

        // 2. Prevent idle display sleep (Screen stays on)
        let dispResult = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displaySleepAssertionID
        )

        if sysResult == kIOReturnSuccess || dispResult == kIOReturnSuccess {
            isCaffeinated = true
            NSSound(named: "Tink")?.play()
        }
    }

    func stopCaffeinate() {
        if systemSleepAssertionID != 0 {
            IOPMAssertionRelease(systemSleepAssertionID)
            systemSleepAssertionID = 0
        }
        if displaySleepAssertionID != 0 {
            IOPMAssertionRelease(displaySleepAssertionID)
            displaySleepAssertionID = 0
        }
        isCaffeinated = false
    }

    // MARK: - Eyedropper Screen Color Picker

    func pickScreenColor() {
        Task { @MainActor in
            guard let color = await NSColorSampler().sample() else { return }
            let hex = self.colorToHex(color)
            let rgb = self.colorToRGB(color)

            self.lastPickedColor = color
            self.lastPickedHex = hex

            // Copy hex code to clipboard
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)

            // Audio confirmation
            NSSound(named: "Pop")?.play()

            // Visual feedback
            self.pickedColorFeedback = true
            try? await Task.sleep(nanoseconds: 2_500_000_000)
            self.pickedColorFeedback = false
        }
    }

    private func colorToHex(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(max(0, min(1, srgb.redComponent)) * 255.0))
        let g = Int(round(max(0, min(1, srgb.greenComponent)) * 255.0))
        let b = Int(round(max(0, min(1, srgb.blueComponent)) * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }

    private func colorToRGB(_ color: NSColor) -> String {
        let srgb = color.usingColorSpace(.sRGB) ?? color
        let r = Int(round(max(0, min(1, srgb.redComponent)) * 255.0))
        let g = Int(round(max(0, min(1, srgb.greenComponent)) * 255.0))
        let b = Int(round(max(0, min(1, srgb.blueComponent)) * 255.0))
        return "rgb(\(r), \(g), \(b))"
    }
}
