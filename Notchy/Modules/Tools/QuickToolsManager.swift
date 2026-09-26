//
//  QuickToolsManager.swift
//  Notchy
//
//  Provides Caffeinate (prevent sleep) and Screen Color Eyedropper tools.
//

import AppKit
import Combine
import IOKit.pwr_mgt

@MainActor
final class QuickToolsManager: ObservableObject {
    static let shared = QuickToolsManager()

    @Published var isCaffeinated: Bool = false
    @Published var lastPickedHex: String?
    @Published var pickedColorFeedback: Bool = false

    private var sleepAssertionID: IOPMAssertionID = 0

    func toggleCaffeinate() {
        if isCaffeinated {
            stopCaffeinate()
        } else {
            startCaffeinate()
        }
    }

    func startCaffeinate() {
        let reason = "Notchy Keep Awake" as CFString
        let success = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &sleepAssertionID
        )
        if success == kIOReturnSuccess {
            isCaffeinated = true
        }
    }

    func stopCaffeinate() {
        if sleepAssertionID != 0 {
            IOPMAssertionRelease(sleepAssertionID)
            sleepAssertionID = 0
        }
        isCaffeinated = false
    }

    func pickScreenColor() {
        Task { @MainActor in
            guard let color = await NSColorSampler().sample() else { return }
            let hex = self.colorToHex(color)
            self.lastPickedHex = hex
            NSPasteboard.general.clearContents()
            NSPasteboard.general.setString(hex, forType: .string)

            self.pickedColorFeedback = true
            try? await Task.sleep(nanoseconds: 1_500_000_000)
            self.pickedColorFeedback = false
        }
    }

    private func colorToHex(_ color: NSColor) -> String {
        guard let rgb = color.usingColorSpace(.sRGB) else {
            return String(format: "#%02X%02X%02X", Int(color.redComponent * 255), Int(color.greenComponent * 255), Int(color.blueComponent * 255))
        }
        let r = Int(round(rgb.redComponent * 255.0))
        let g = Int(round(rgb.greenComponent * 255.0))
        let b = Int(round(rgb.blueComponent * 255.0))
        return String(format: "#%02X%02X%02X", r, g, b)
    }
}
