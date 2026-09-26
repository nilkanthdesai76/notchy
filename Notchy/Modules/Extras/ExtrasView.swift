//
//  ExtrasView.swift
//  Notchy
//
//  Small utility strip: volume & brightness sliders (sent as system
//  media keys) plus the battery indicator.
//

import AppKit
import Combine
import IOKit.ps
import SwiftUI

struct ExtrasView: View {
    var body: some View {
        HStack(spacing: 18) {
            MediaKeySlider(
                systemName: "speaker.fill",
                keyUp: 0,   // NX_KEYTYPE_SOUND_UP
                keyDown: 1  // NX_KEYTYPE_SOUND_DOWN
            )
            MediaKeySlider(
                systemName: "sun.max.fill",
                keyUp: 2,   // NX_KEYTYPE_BRIGHTNESS_UP
                keyDown: 3  // NX_KEYTYPE_BRIGHTNESS_DOWN
            )
            Spacer(minLength: 0)
            BatteryView()
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.1), Color.white.opacity(0.05)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: .rect(cornerRadius: 14)
        )
    }
}

// MARK: - Media key slider

/// Spring-back slider: drag right/left to nudge the system
/// volume/brightness by posting the same AUX_CONTROL_BUTTON events
/// the keyboard sends. Requires Accessibility permission.
struct MediaKeySlider: View {
    let systemName: String
    let keyUp: UInt32
    let keyDown: UInt32

    @State private var value: Double = 0.5
    @State private var isEditing = false
    @State private var isAccessibilityTrusted = AXIsProcessTrusted()

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: systemName)
                .font(.system(size: 11))
                .foregroundStyle(.white.opacity(0.6))
            if isAccessibilityTrusted {
                Slider(value: $value, in: 0...1) { editing in
                    isEditing = editing
                    if !editing { value = 0.5 } // spring back to neutral
                }
                .frame(width: 90)
                .onChange(of: value) { newValue in
                    guard isEditing else { return }
                    sendSteps(for: newValue)
                }
            } else {
                Button("Enable in System Settings") {
                    // Ask macOS to show its one-time prompt, and also open the
                    // pane directly so the button always does something visible.
                    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                    isAccessibilityTrusted = AXIsProcessTrusted()
                    SystemSettings.openAccessibilityPrivacy()
                }
                .font(.system(size: 9))
                .foregroundStyle(.white.opacity(0.5))
                .buttonStyle(.plain)
            }
        }
    }

    private func sendSteps(for newValue: Double) {
        // Neutral center = no change. Each 1/16 of travel = one key press.
        let delta = newValue - 0.5
        let steps = Int((delta * 16).rounded())
        guard steps != 0 else { return }
        let key: UInt32 = steps > 0 ? keyUp : keyDown
        for _ in 0..<abs(steps) {
            postMediaKey(key)
        }
        value = 0.5
    }

    private func postMediaKey(_ key: UInt32) {
        func post(down: Bool) {
            let flags = NSEvent.ModifierFlags(rawValue: down ? 0xA00 : 0xB00)
            let data1 = Int((key << 16) | ((down ? 0xA00 : 0xB00) << 8))
            let event = NSEvent.otherEvent(
                with: .systemDefined,
                location: .zero,
                modifierFlags: flags,
                timestamp: 0,
                windowNumber: 0,
                context: nil,
                subtype: 8, // NX_SUBTYPE_AUX_CONTROL_BUTTONS
                data1: data1,
                data2: -1
            )
            event?.cgEvent?.post(tap: .cghidEventTap)
        }
        post(down: true)
        post(down: false)
    }
}

// MARK: - Battery

struct BatteryView: View {
    @State private var level: Int?
    @State private var isCharging = false

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: batterySymbol)
                .font(.system(size: 12))
                .foregroundStyle(.white.opacity(0.7))
            if let level {
                Text("\(level)%")
                    .font(.system(size: 11, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.7))
                    .monospacedDigit()
            }
        }
        .onAppear(perform: refresh)
        .onReceive(Timer.publish(every: 30, on: .main, in: .common).autoconnect()) { _ in
            refresh()
        }
    }

    private var batterySymbol: String {
        guard let level else { return "battery.0" }
        if isCharging { return "battery.100.bolt" }
        switch level {
        case 80...: return "battery.100"
        case 60..<80: return "battery.75"
        case 40..<60: return "battery.50"
        case 20..<40: return "battery.25"
        default: return "battery.0"
        }
    }

    private func refresh() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let list = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef],
              let first = list.first,
              let description = IOPSGetPowerSourceDescription(snapshot, first)?.takeUnretainedValue() as? [String: Any]
        else { return }
        level = description[kIOPSCurrentCapacityKey] as? Int
        isCharging = (description[kIOPSIsChargingKey] as? Bool) ?? false
        if description[kIOPSPowerSourceStateKey] as? String == kIOPSACPowerValue {
            isCharging = true
        }
    }
}
