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
                        SystemSettings.openAccessibilityPrivacy()
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
