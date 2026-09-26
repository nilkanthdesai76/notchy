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

    private var preventSystemSleepID: IOPMAssertionID = 0
    private var idleSystemSleepID: IOPMAssertionID = 0
    private var displaySleepID: IOPMAssertionID = 0
    private var caffeinateProcess: Process?

    deinit {
        // Nonisolated cleanup
        if preventSystemSleepID != 0 { IOPMAssertionRelease(preventSystemSleepID) }
        if idleSystemSleepID != 0 { IOPMAssertionRelease(idleSystemSleepID) }
        if displaySleepID != 0 { IOPMAssertionRelease(displaySleepID) }
        caffeinateProcess?.terminate()
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

        // 1. Prevent system sleep entirely (even when lid closes or AC changes)
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &preventSystemSleepID
        )

        // 2. Prevent idle system sleep
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleSystemSleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &idleSystemSleepID
        )

        // 3. Prevent idle display sleep (Screen stays on while open)
        _ = IOPMAssertionCreateWithName(
            kIOPMAssertionTypePreventUserIdleDisplaySleep as CFString,
            IOPMAssertionLevel(kIOPMAssertionLevelOn),
            reason,
            &displaySleepID
        )

        // 4. Launch caffeinate subprocess (-d: display, -i: idle system, -m: disk, -s: system sleep, -u: user active)
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/caffeinate")
        process.arguments = ["-dimsu", "-w", "\(ProcessInfo.processInfo.processIdentifier)"]
        try? process.run()
        caffeinateProcess = process

        isCaffeinated = true
        NSSound(named: "Tink")?.play()
    }

    func stopCaffeinate() {
        if preventSystemSleepID != 0 {
            IOPMAssertionRelease(preventSystemSleepID)
            preventSystemSleepID = 0
        }
        if idleSystemSleepID != 0 {
            IOPMAssertionRelease(idleSystemSleepID)
            idleSystemSleepID = 0
        }
        if displaySleepID != 0 {
            IOPMAssertionRelease(displaySleepID)
            displaySleepID = 0
        }

        if let proc = caffeinateProcess, proc.isRunning {
            proc.terminate()
        }
        caffeinateProcess = nil

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
