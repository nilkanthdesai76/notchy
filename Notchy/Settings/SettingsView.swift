//
//  SettingsView.swift
//  Notchy
//
//  Complete user preferences for modules, AI providers, layout, and permissions.
//  Includes full draggable 3-page layout customizer.
//

import AVFoundation
import Combine
import ServiceManagement
import SwiftUI

struct SettingsView: View {
    @AppStorage("defaultPage") private var defaultPage = 0
    @AppStorage("kimiApiKey") private var kimiApiKey = ""
    @AppStorage("customGeminiPath") private var customGeminiPath = ""
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    @AppStorage("hoverDelay") private var hoverDelay = 0.05
    @AppStorage("liveActivityMediaEnabled") private var liveActivityMediaEnabled = true
    @AppStorage("liveActivityTimerEnabled") private var liveActivityTimerEnabled = true
    @AppStorage("liveActivityShelfEnabled") private var liveActivityShelfEnabled = true
    @AppStorage("liveActivityHideInFullscreen") private var liveActivityHideInFullscreen = true
    @AppStorage("glassOpacity") private var glassOpacity = 0.58
    @AppStorage("showPanelShadow") private var showPanelShadow = false
    @AppStorage("glassMaterialStyle") private var glassMaterialStyle = "liquid"
    @AppStorage("cardGlassOpacity") private var cardGlassOpacity = 0.50
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true
    @AppStorage("showBottomGlow") private var showBottomGlow = false

    var body: some View {
        TabView {
            // Tab 1: Draggable Pages Layout
            VStack(alignment: .leading, spacing: 14) {
                // Default Open Page Picker
                HStack {
                    Text("Default Open Page:")
                        .font(.subheadline)
                    Picker("", selection: $defaultPage) {
                        Text("Page 1").tag(0)
                        Text("Page 2").tag(1)
                        Text("Page 3").tag(2)
                    }
                    .frame(width: 140)
                    Spacer()
                }
                .padding(.horizontal, 4)

                Divider()

                // Draggable 3-Page Reorganizer
                PageOrganizerView()
            }
            .padding(18)
            .tabItem {
                Label("Pages & Layout", systemImage: "square.grid.3x1.below.line.grid.1x2")
            }

            // Tab 2: Appearance & Liquid Glass Customization
            Form {
                Section("Liquid Glass Theme") {
                    Picker("Theme Style", selection: $glassMaterialStyle) {
                        Text("Liquid Glass (Frosted & Translucent)").tag("liquid")
                        Text("Crystal Clear (Maximum Transparency)").tag("crystal")
                        Text("Deep Graphite (Subtle Blur)").tag("graphite")
                        Text("Classic Opaque (Solid Black)").tag("opaque")
                    }
                    .onChange(of: glassMaterialStyle) { newStyle in
                        switch newStyle {
                        case "crystal":
                            glassOpacity = 0.35
                            cardGlassOpacity = 0.35
                        case "liquid":
                            glassOpacity = 0.58
                            cardGlassOpacity = 0.50
                        case "graphite":
                            glassOpacity = 0.80
                            cardGlassOpacity = 0.65
                        case "opaque":
                            glassOpacity = 1.0
                            cardGlassOpacity = 0.85
                        default:
                            break
                        }
                    }

                    if glassMaterialStyle != "opaque" {
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Panel Transparency / Tint")
                                Spacer()
                                Text("\(Int((1.0 - glassOpacity) * 100))% transparent (\(Int(glassOpacity * 100))% tint)")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $glassOpacity, in: 0.20...0.95, step: 0.05) {
                                Text("Glass Opacity")
                            } minimumValueLabel: {
                                Text("Crystal")
                                    .font(.caption2)
                            } maximumValueLabel: {
                                Text("Dark")
                                    .font(.caption2)
                            }
                        }

                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text("Module Card Translucency")
                                Spacer()
                                Text("\(Int(cardGlassOpacity * 100))%")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $cardGlassOpacity, in: 0.20...0.90, step: 0.05) {
                                Text("Card Opacity")
                            } minimumValueLabel: {
                                Text("Clear")
                                    .font(.caption2)
                            } maximumValueLabel: {
                                Text("Solid")
                                    .font(.caption2)
                            }
                        }
                    }
                }

                Section("Drop Shadow & Edges") {
                    Toggle(isOn: $showPanelShadow) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Outer Panel Shadow")
                                .font(.body)
                            Text("Draws an ambient drop shadow outside the expanded notch onto your wallpaper. Disabled by default for razor-sharp flush edges.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $showBottomGlow) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Bottom Edge Caustic Glow")
                                .font(.body)
                            Text("Warm ambient caustic light bloom along the bottom squircle of the expanded notch.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("Header & Controls") {
                    Toggle("Show Battery Indicator in Header", isOn: $showBatteryIndicator)
                }

                Section("Live Material Preview") {
                    ZStack {
                        // Simulated colorful desktop wallpaper background (like macOS wallpaper)
                        LinearGradient(
                            colors: [Color.red.opacity(0.85), Color.purple.opacity(0.85), Color.blue.opacity(0.85)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                        // Preview Glass Plate
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 3) {
                                Text("Notchy Glass Preview")
                                    .font(.system(size: 12, weight: .bold))
                                    .foregroundStyle(.white)
                                Text("Wallpaper vibrancy softly showing through")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.white.opacity(0.7))
                            }
                            Spacer()

                            // Sample mini module pod
                            HStack(spacing: 6) {
                                Image(systemName: "sparkles")
                                    .font(.system(size: 11))
                                    .foregroundStyle(.cyan)
                                Text("Liquid Glass")
                                    .font(.system(size: 10, weight: .semibold))
                                    .foregroundStyle(.white)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(.ultraThinMaterial.opacity(cardGlassOpacity))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                                            .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                                    )
                            )
                        }
                        .padding(14)
                        .background(
                            ZStack {
                                if glassMaterialStyle == "opaque" {
                                    Color.black
                                } else {
                                    VisualEffectView(material: .hudWindow, blendingMode: .withinWindow)
                                    Color.black.opacity(glassOpacity)
                                }
                            }
                        )
                        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.25), lineWidth: 1)
                        )
                        .padding(10)
                    }
                    .frame(height: 90)
                }
            }
            .formStyle(.grouped)
            .padding(14)
            .tabItem {
                Label("Appearance", systemImage: "paintpalette")
            }

            // Tab 2: Live Activities
            Form {
                Section {
                    Toggle(isOn: $liveActivityMediaEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Media Playback")
                                .font(.body)
                            Text("Shows album art and animated equalizer wings while music or video is playing")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $liveActivityTimerEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Timer Countdown")
                                .font(.body)
                            Text("Shows the timer icon and real-time countdown when a timer is running")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Toggle(isOn: $liveActivityShelfEnabled) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("File Drop Shelf")
                                .font(.body)
                            Text("Highlights the notch wings when dragging files across the display")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Closed Notch Live Activities")
                } footer: {
                    Text("When the notch is closed, Notchy stays completely hidden behind the hardware bezel unless an enabled activity is running.")
                }

                Section {
                    Toggle(isOn: $liveActivityHideInFullscreen) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Hide in Fullscreen")
                                .font(.body)
                            Text("Automatically suppresses all notch live activities while watching full screen videos or working in full screen spaces")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                } header: {
                    Text("Fullscreen Behavior")
                }
            }
            .formStyle(.grouped)
            .padding(14)
            .tabItem {
                Label("Live Activities", systemImage: "waveform.badge.magnifyingglass")
            }

            // Tab 2: AI Providers & Usage
            Form {
                Section("Antigravity & Local AI") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Google Antigravity", systemImage: "sparkles")
                            Spacer()
                            Text(customGeminiPath.isEmpty ? "Auto-detected (~/.gemini)" : customGeminiPath)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .truncationMode(.middle)
                        }

                        HStack(spacing: 8) {
                            Button("Locate .gemini Folder…") {
                                let panel = NSOpenPanel()
                                panel.canChooseFiles = false
                                panel.canChooseDirectories = true
                                panel.allowsMultipleSelection = false
                                panel.showsHiddenFiles = true
                                panel.directoryURL = URL(fileURLWithPath: NSHomeDirectory())
                                if panel.runModal() == .OK, let url = panel.url {
                                    customGeminiPath = url.path
                                    AIUsageManager.shared.refresh()
                                }
                            }
                            .controlSize(.small)

                            if !customGeminiPath.isEmpty {
                                Button("Reset") {
                                    customGeminiPath = ""
                                    AIUsageManager.shared.refresh()
                                }
                                .controlSize(.small)
                            }

                            Spacer()

                            Button("Sync Quota") {
                                AIUsageManager.shared.refresh()
                            }
                            .controlSize(.small)
                        }
                    }

                    HStack {
                        Label("OpenCode", systemImage: "chevron.left.forwardslash.chevron.right")
                        Spacer()
                        Text("Auto-detected (~/.config/opencode)")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Section("API Key Providers") {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Label("Kimi (Moonshot AI)", systemImage: "moon.stars.fill")
                            Spacer()
                        }
                        SecureField("Enter Kimi API Key (sk-...)", text: $kimiApiKey)
                            .textFieldStyle(.roundedBorder)
                            .font(.caption)
                    }

                    Text("Note: Only AI tools with active local sessions or configured keys are displayed. Simulated data is never shown.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .formStyle(.grouped)
            .padding(14)
            .tabItem {
                Label("AI Providers", systemImage: "sparkles")
            }

            // Tab 3: General & Permissions
            Form {
                Section("Behavior") {
                    Slider(value: $hoverDelay, in: 0...0.6) {
                        Text("Hover delay")
                    } minimumValueLabel: {
                        Text("Instant")
                    } maximumValueLabel: {
                        Text("Slow")
                    }

                    LaunchAtLoginToggle()
                    Toggle("Show menu bar icon", isOn: $showMenuBarIcon)
                }

                Section("Shortcuts") {
                    VStack(alignment: .leading, spacing: 5) {
                        Text("• Two-finger horizontal trackpad swipe: flip pages")
                        Text("• ⌘1: Page 1   • ⌘2: Page 2   • ⌘3: Page 3")
                        Text("• ⌘← / ⌘→: Previous / Next page")
                        Text("• Esc: Close notch panel")
                    }
                    .font(.caption)
                    .foregroundStyle(.secondary)
                }

                Section("Permissions") {
                    PermissionRow(
                        title: "Camera",
                        subtitle: "Needed for the webcam selfie mirror",
                        granted: CameraPermissionStatus.isAuthorized
                    ) {
                        SystemSettings.openCameraPrivacy()
                    }
                    PermissionRow(
                        title: "Accessibility",
                        subtitle: "Needed for volume & brightness shortcuts",
                        granted: AXIsProcessTrusted()
                    ) {
                        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                        _ = AXIsProcessTrustedWithOptions(options)
                    }
                }

                Section {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Quit Notchy")
                                .font(.body)
                            Text("Completely terminate the background application and release all system resources.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Button(role: .destructive) {
                            NSApplication.shared.terminate(nil)
                        } label: {
                            Label("Quit Notchy", systemImage: "power")
                        }
                        .controlSize(.regular)
                    }
                }
            }
            .formStyle(.grouped)
            .padding(14)
            .tabItem {
                Label("General", systemImage: "gearshape")
            }
        }
        .frame(minWidth: 620, minHeight: 520)
    }
}

// MARK: - Launch at login

private struct LaunchAtLoginToggle: View {
    @State private var isEnabled = SMAppService.mainApp.status == .enabled

    var body: some View {
        Toggle("Launch at login", isOn: $isEnabled)
            .onChange(of: isEnabled) { newValue in
                do {
                    if newValue {
                        try SMAppService.mainApp.register()
                    } else {
                        try SMAppService.mainApp.unregister()
                    }
                } catch {
                    isEnabled = SMAppService.mainApp.status == .enabled
                }
            }
    }
}

// MARK: - Permissions

private enum CameraPermissionStatus {
    static var isAuthorized: Bool {
        AVCaptureDevice.authorizationStatus(for: .video) == .authorized
    }
}

private struct PermissionRow: View {
    let title: String
    let subtitle: String
    let granted: Bool
    let action: () -> Void

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                Text(subtitle)
                    .font(.callout)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if granted {
                Label("Granted", systemImage: "checkmark.circle.fill")
                    .foregroundStyle(.green)
            } else {
                Button("Open System Settings", action: action)
            }
        }
    }
}
