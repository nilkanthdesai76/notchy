//
//  SettingsView.swift
//  Notchy
//
//  Advanced Multi-Tab Settings Console for Notchy.
//  Clean macOS aesthetic with full hit-target square navigation buttons,
//  dynamic page layout organizer, multi-provider AI tracker, liquid glass controls,
//  and Pro license registration.
//

import AVFoundation
import Combine
import ServiceManagement
import SwiftUI

// MARK: - Settings Tab Definitions

enum SettingsTab: String, CaseIterable, Identifiable {
    case general = "General"
    case liveActivities = "Live Activities"
    case pages = "Pages & Layout"
    case appearance = "Appearance"
    case shelf = "File Shelf"
    case ai = "AI Providers"
    case license = "License"
    case about = "About"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .general: return "gearshape.fill"
        case .liveActivities: return "waveform.badge.magnifyingglass"
        case .pages: return "square.grid.3x1.below.line.grid.1x2"
        case .appearance: return "paintpalette.fill"
        case .shelf: return "tray.and.arrow.down.fill"
        case .ai: return "sparkles"
        case .license: return "key.fill"
        case .about: return "info.circle.fill"
        }
    }
}

// MARK: - Root Settings View

struct SettingsView: View {
    @State private var selectedTab: SettingsTab = .general

    var body: some View {
        VStack(spacing: 0) {
            // Top Navigation Bar with full rectangular clickable buttons
            HStack(spacing: 4) {
                ForEach(SettingsTab.allCases) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            selectedTab = tab
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: tab.iconName)
                                .font(.system(size: 15, weight: selectedTab == tab ? .semibold : .regular))
                                .foregroundStyle(selectedTab == tab ? Color.cyan : Color.secondary)
                                .frame(height: 20)
                            Text(tab.rawValue)
                                .font(.system(size: 10, weight: selectedTab == tab ? .semibold : .medium))
                                .foregroundStyle(selectedTab == tab ? .white : .secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.85)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .contentShape(Rectangle())
                        .background(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(selectedTab == tab ? Color.white.opacity(0.12) : Color.clear)
                        )
                        .overlay(
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .strokeBorder(selectedTab == tab ? Color.white.opacity(0.15) : Color.clear, lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                    .frame(height: 52)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 8)
            .background(Color(white: 0.10))

            Divider()

            // Active Tab Content Area
            Group {
                switch selectedTab {
                case .general:
                    SettingsGeneralTab()
                case .liveActivities:
                    SettingsLiveActivitiesTab()
                case .pages:
                    SettingsPagesTab()
                case .appearance:
                    SettingsAppearanceTab()
                case .shelf:
                    SettingsShelfTab()
                case .ai:
                    SettingsAITab()
                case .license:
                    SettingsLicenseTab()
                case .about:
                    SettingsAboutTab()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(minWidth: 700, minHeight: 580)
        .background(Color(white: 0.08))
    }
}

// MARK: - Tab 1: General

private struct SettingsGeneralTab: View {
    @AppStorage("showMenuBarIcon") private var showMenuBarIcon = false
    @AppStorage("hoverDelay") private var hoverDelay = 0.05
    @AppStorage("preventClosingOnMouseLeave") private var preventClosingOnMouseLeave = false
    @AppStorage("preferRoundButtons") private var preferRoundButtons = true
    @AppStorage("showFullscreenOption") private var showFullscreenOption = "all"

    var body: some View {
        Form {
            Section("System & Startup") {
                LaunchAtLoginToggle()
                Toggle("Show Menu Bar Extra Icon", isOn: $showMenuBarIcon)
            }

            Section("Notch Behavior & Hover") {
                Slider(value: $hoverDelay, in: 0...0.5, step: 0.05) {
                    Text("Hover Delay")
                } minimumValueLabel: {
                    Text("Instant").font(.caption2)
                } maximumValueLabel: {
                    Text("Slow").font(.caption2)
                }

                Toggle(isOn: $preventClosingOnMouseLeave) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Prevent Closing on Mouse Leave")
                            .font(.body)
                        Text("Keeps the expanded notch panel open until you click outside or press Escape.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle("Prefer Rounded Capsule Buttons", isOn: $preferRoundButtons)

                Picker("Show in Fullscreen", selection: $showFullscreenOption) {
                    Text("On all monitors").tag("all")
                    Text("On notched screens only").tag("notched")
                    Text("Never").tag("never")
                }
            }

            Section("Permissions") {
                PermissionRow(
                    title: "Camera",
                    subtitle: "Required for the webcam selfie mirror",
                    granted: CameraPermissionStatus.isAuthorized
                ) {
                    SystemSettings.openCameraPrivacy()
                }

                PermissionRow(
                    title: "Accessibility",
                    subtitle: "Required for notch gesture events & window detection",
                    granted: AXIsProcessTrusted()
                ) {
                    let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
                    _ = AXIsProcessTrustedWithOptions(options)
                    SystemSettings.openAccessibilityPrivacy()
                }
            }

            Section("Shortcuts Reference") {
                VStack(alignment: .leading, spacing: 6) {
                    ShortcutRow(keys: "⌘← / ⌘→", description: "Navigate to Previous / Next page")
                    ShortcutRow(keys: "Esc", description: "Retract and close expanded notch panel")
                    ShortcutRow(keys: "Space", description: "Play/Pause active media when open")
                }
                .padding(.vertical, 4)
            }

            Section("Danger Zone") {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Reset All Settings")
                            .font(.body)
                        Text("Restores all layout, appearance, and module configurations to factory defaults.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Reset All Settings") {
                        PageLayoutManager.shared.resetToDefaults()
                    }
                    .controlSize(.small)
                }

                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Quit Notchy")
                            .font(.body)
                        Text("Terminates the background process and unloads all notch monitors.")
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
        .scrollContentBackground(.hidden)
        .padding(14)
    }
}

private struct ShortcutRow: View {
    let keys: String
    let description: String

    var body: some View {
        HStack {
            Text(keys)
                .font(.system(size: 11, weight: .bold, design: .monospaced))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.1), in: RoundedRectangle(cornerRadius: 4))
            Text(description)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
            Spacer()
        }
    }
}

// MARK: - Tab 2: Live Activities

private struct SettingsLiveActivitiesTab: View {
    @State private var selectedSubTab = 0
    @AppStorage("liveActivityMediaEnabled") private var liveActivityMediaEnabled = true
    @AppStorage("liveActivityTimerEnabled") private var liveActivityTimerEnabled = true
    @AppStorage("liveActivityShelfEnabled") private var liveActivityShelfEnabled = true
    @AppStorage("liveActivityHideInFullscreen") private var liveActivityHideInFullscreen = true
    @AppStorage("visualizerEffectType") private var visualizerEffectType = "spectrograph"
    @AppStorage("coloredEffects") private var coloredEffects = true
    @AppStorage("albumCornerRadius") private var albumCornerRadius = 5.0
    @AppStorage("liveInactivityTimeout") private var liveInactivityTimeout = 10.0

    var body: some View {
        VStack(spacing: 12) {
            // Sub-Segment Switcher
            Picker("", selection: $selectedSubTab) {
                Text("General").tag(0)
                Text("Customize Activities").tag(1)
            }
            .pickerStyle(.segmented)
            .frame(width: 280)
            .padding(.top, 12)

            // Sleek Neutral Dark Simulated MacBook Notch with Wings
            ZStack {
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .fill(Color(white: 0.12))
                    .frame(height: 72)
                    .overlay(
                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                            .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
                    )

                HStack(spacing: 8) {
                    // Left ear: Album Art or Timer
                    HStack(spacing: 4) {
                        Image(systemName: "music.note")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundStyle(.cyan)
                    }
                    .frame(width: 24, height: 24)
                    .background(Color.black, in: RoundedRectangle(cornerRadius: CGFloat(albumCornerRadius)))

                    // Notch Hardware Spacer
                    RoundedRectangle(cornerRadius: 6, style: .continuous)
                        .fill(Color.black)
                        .frame(width: 140, height: 26)

                    // Right ear: Live Audio Equalizer
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(coloredEffects ? Color.cyan : Color.white)
                                .frame(width: 2.5, height: CGFloat([12, 18, 8, 14][i]))
                        }
                    }
                    .frame(width: 24, height: 24)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
                .background(Color.black, in: Capsule())
            }
            .padding(.horizontal, 18)

            if selectedSubTab == 0 {
                Form {
                    Section("Closed Notch Activity Wings") {
                        Toggle("Media Playback Wings", isOn: $liveActivityMediaEnabled)
                        Toggle("Focus Timer Countdown Wings", isOn: $liveActivityTimerEnabled)
                        Toggle("File Drop Shelf Drag Highlight", isOn: $liveActivityShelfEnabled)
                        Toggle("Hide Activities in Fullscreen", isOn: $liveActivityHideInFullscreen)
                    }

                    Section("Inactivity Timeout") {
                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Dismiss After Playback Pauses")
                                Spacer()
                                Text("\(Int(liveInactivityTimeout)) seconds")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $liveInactivityTimeout, in: 3...30, step: 1)
                        }
                    }
                }
                .formStyle(.grouped)
        .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
            } else {
                Form {
                    Section("Media Visualizer Style") {
                        Picker("Effect Type", selection: $visualizerEffectType) {
                            Text("Audio Spectrograph").tag("spectrograph")
                            Text("Smooth Waves").tag("waves")
                            Text("Vibrating Pulse").tag("pulse")
                        }

                        Toggle("Colored Effects (matches active album artwork)", isOn: $coloredEffects)

                        VStack(alignment: .leading, spacing: 4) {
                            HStack {
                                Text("Album Art Corner Radius")
                                Spacer()
                                Text("\(Int(albumCornerRadius)) pt")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Slider(value: $albumCornerRadius, in: 2...12, step: 1)
                        }
                    }
                }
                .formStyle(.grouped)
        .scrollContentBackground(.hidden)
                .padding(.horizontal, 14)
            }
        }
    }
}

// MARK: - Tab 3: Pages & Layout

private struct SettingsPagesTab: View {
    @AppStorage("defaultPage") private var defaultPage = 0
    @ObservedObject var layout = PageLayoutManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Default Open Page Picker
            HStack {
                Text("Default Open Page:")
                    .font(.subheadline)
                    .foregroundStyle(.primary)

                Picker("", selection: $defaultPage) {
                    ForEach(Array(layout.pages.enumerated()), id: \.element.id) { index, _ in
                        Text("Page \(index + 1)").tag(index)
                    }
                }
                .frame(width: 140)

                Spacer()
            }
            .padding(.horizontal, 18)
            .padding(.top, 14)

            Divider()

            // Full Dynamic Drag-and-Drop Page Organizer
            PageOrganizerView()
                .padding(.horizontal, 18)
                .padding(.bottom, 14)
        }
    }
}

// MARK: - Tab 4: Appearance & Liquid Glass

private struct SettingsAppearanceTab: View {
    @AppStorage("glassMaterialStyle") private var glassMaterialStyle = "liquid"
    @AppStorage("glassOpacity") private var glassOpacity = 0.58
    @AppStorage("cardGlassOpacity") private var cardGlassOpacity = 0.50
    @AppStorage("showPanelShadow") private var showPanelShadow = false
    @AppStorage("showBottomGlow") private var showBottomGlow = false
    @AppStorage("showBatteryIndicator") private var showBatteryIndicator = true

    var body: some View {
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
                            Text("Panel Background Translucency")
                            Spacer()
                            Text("\(Int((1.0 - glassOpacity) * 100))% transparent (\(Int(glassOpacity * 100))% tint)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $glassOpacity, in: 0.20...0.95, step: 0.05)
                    }

                    VStack(alignment: .leading, spacing: 6) {
                        HStack {
                            Text("Module Card Translucency")
                            Spacer()
                            Text("\(Int(cardGlassOpacity * 100))%")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Slider(value: $cardGlassOpacity, in: 0.20...0.90, step: 0.05)
                    }
                }
            }

            Section("Drop Shadow & Caustic Edges") {
                Toggle(isOn: $showPanelShadow) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Outer Panel Shadow")
                            .font(.body)
                        Text("Draws an ambient drop shadow outside the expanded notch onto your wallpaper.")
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
                    LinearGradient(
                        colors: [Color.indigo, Color.purple, Color.orange.opacity(0.8)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Notchy Liquid Glass Preview")
                                .font(.system(size: 12, weight: .bold))
                                .foregroundStyle(.white)
                            Text("Wallpaper color and luminescence softly refracts through")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.75))
                        }
                        Spacer()

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
        .scrollContentBackground(.hidden)
        .padding(14)
    }
}

// MARK: - Tab 5: File Shelf

private struct SettingsShelfTab: View {
    @AppStorage("autoOpenShelfOnDrag") private var autoOpenShelfOnDrag = true
    @AppStorage("clearShelfAfterAirDrop") private var clearShelfAfterAirDrop = false
    @AppStorage("shelfCapacityLimit") private var shelfCapacityLimit = 15.0

    var body: some View {
        Form {
            Section("File Drop Shelf Behavior") {
                Toggle(isOn: $autoOpenShelfOnDrag) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Auto-Expand Notch on File Drag")
                            .font(.body)
                        Text("Automatically reveals the shelf module when dragging documents, images, or folders across your screen.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Toggle(isOn: $clearShelfAfterAirDrop) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Clear Shelf After AirDrop")
                            .font(.body)
                        Text("Automatically removes staged files once AirDrop transfer successfully completes.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Section("Storage & Capacity") {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Maximum Staged Items")
                        Spacer()
                        Text("\(Int(shelfCapacityLimit)) items")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $shelfCapacityLimit, in: 5...30, step: 5)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(14)
    }
}

// MARK: - Tab 6: AI Providers (Inspired by openusage-main)

private struct SettingsAITab: View {
    @ObservedObject var ai = AIUsageManager.shared
    @AppStorage("customGeminiPath") private var customGeminiPath = ""
    @AppStorage("kimiApiKey") private var kimiApiKey = ""
    @AppStorage("openaiApiKey") private var openaiApiKey = ""
    @AppStorage("openrouterApiKey") private var openrouterApiKey = ""
    @AppStorage("grokApiKey") private var grokApiKey = ""
    @AppStorage("devinApiKey") private var devinApiKey = ""

    var body: some View {
        Form {
            Section("Tracked AI Providers") {
                Text("Select which AI providers and local coding tools appear in your Notch AI Token monitor:")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.bottom, 2)

                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    ForEach(KnownAIProvider.allCases) { provider in
                        let isTracked = ai.isTracked(provider)
                        AIProviderCard(
                            provider: provider,
                            isTracked: isTracked
                        ) {
                            ai.setTracked(provider, tracked: !isTracked)
                        }
                    }
                }
                .padding(.vertical, 4)
            }

            Section("Provider Keys & Configuration") {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Label("Google Antigravity Path", systemImage: "sparkles")
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
                                ai.refresh()
                            }
                        }
                        .controlSize(.small)

                        if !customGeminiPath.isEmpty {
                            Button("Reset") {
                                customGeminiPath = ""
                                ai.refresh()
                            }
                            .controlSize(.small)
                        }

                        Spacer()

                        Button("Sync Quota") {
                            ai.refresh()
                        }
                        .controlSize(.small)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Kimi (Moonshot AI)", systemImage: "moon.stars.fill")
                    SecureField("Kimi API Key (sk-...)", text: $kimiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("OpenAI / Codex", systemImage: "circle.hexagongrid.fill")
                    SecureField("OpenAI API Key (sk-...)", text: $openaiApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("OpenRouter", systemImage: "network")
                    SecureField("OpenRouter API Key (sk-or-...)", text: $openrouterApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Grok (xAI)", systemImage: "bolt.shield.fill")
                    SecureField("Grok API Key (xai-...)", text: $grokApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Label("Devin", systemImage: "terminal.fill")
                    SecureField("Devin API Key (apk_...)", text: $devinApiKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.caption)
                }
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(14)
    }
}

private struct AIProviderCard: View {
    let provider: KnownAIProvider
    let isTracked: Bool
    let onToggle: () -> Void

    @State private var isHovered = false

    private var accentColor: Color {
        Color(nsColor: provider.accentColor)
    }

    var body: some View {
        Button(action: onToggle) {
            HStack(spacing: 9) {
                // Provider App Icon Badge
                ZStack {
                    RoundedRectangle(cornerRadius: 7, style: .continuous)
                        .fill(accentColor.opacity(isTracked ? 0.22 : 0.08))
                        .frame(width: 28, height: 28)
                    Image(systemName: provider.iconName)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(isTracked ? accentColor : Color.secondary.opacity(0.8))
                }

                // Title & Subtitle Info
                VStack(alignment: .leading, spacing: 1) {
                    Text(provider.displayName)
                        .font(.system(size: 11.5, weight: isTracked ? .semibold : .medium))
                        .foregroundStyle(isTracked ? .primary : .secondary)
                        .lineLimit(1)
                    Text(provider.categoryDescription)
                        .font(.system(size: 8.5))
                        .foregroundStyle(.secondary.opacity(0.8))
                        .lineLimit(1)
                }

                Spacer(minLength: 4)

                // Active Check Indicator
                ZStack {
                    if isTracked {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.cyan)
                    } else {
                        Image(systemName: "circle")
                            .font(.system(size: 15))
                            .foregroundStyle(Color.secondary.opacity(0.3))
                    }
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .fill(isTracked ? Color.white.opacity(0.08) : Color.white.opacity(isHovered ? 0.05 : 0.02))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8, style: .continuous)
                    .strokeBorder(isTracked ? Color.cyan.opacity(0.4) : Color.white.opacity(0.06), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }
}

// MARK: - Tab 7: License (Monetization)

private struct SettingsLicenseTab: View {
    @AppStorage("licenseEmail") private var licenseEmail = ""
    @AppStorage("licenseKey") private var licenseKey = ""
    @AppStorage("isLicensed") private var isLicensed = false
    @State private var registrationError: String? = nil

    var body: some View {
        Form {
            Section("Status") {
                HStack(spacing: 12) {
                    Image(systemName: isLicensed ? "checkmark.circle.fill" : "xmark.circle.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(isLicensed ? Color.green : Color.red)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(isLicensed ? "Status: Registered (Pro Active)" : "Status: Unregistered")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(isLicensed ? Color.green : Color.red)

                        Text(isLicensed ? "Thank you for supporting Notchy! All Pro features, token counters, and unlimited clipboard history are unlocked." : "Enjoy core features for free, or enter your Notchy Pro license key to unlock AI Token Quotas, 2FA, and custom liquid glass.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }

            Section("License Details") {
                HStack {
                    Label("Email", systemImage: "at")
                        .frame(width: 100, alignment: .leading)
                    TextField("john.doe@email.com", text: $licenseEmail)
                        .textFieldStyle(.roundedBorder)
                        .disabled(isLicensed)
                }

                HStack {
                    Label("License Key", systemImage: "key.fill")
                        .frame(width: 100, alignment: .leading)
                    TextField("Ex: NOTCHY-XXXX-XXXX-XXXX", text: $licenseKey)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(.body, design: .monospaced))
                        .disabled(isLicensed)
                }

                if let error = registrationError {
                    Text(error)
                        .font(.caption)
                        .foregroundStyle(.red)
                }

                HStack {
                    Spacer()

                    if !isLicensed {
                        Button("Get a License") {
                            if let url = URL(string: "https://notchy.app/buy") {
                                NSWorkspace.shared.open(url)
                            }
                        }
                        .controlSize(.regular)

                        Button("Register") {
                            validateAndActivateLicense()
                        }
                        .buttonStyle(.borderedProminent)
                        .controlSize(.regular)
                        .disabled(licenseKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    } else {
                        Button("Deactivate License") {
                            isLicensed = false
                            licenseKey = ""
                        }
                        .controlSize(.regular)
                    }
                }
                .padding(.top, 4)
            }

            Section("Included with Notchy Pro") {
                VStack(alignment: .leading, spacing: 6) {
                    FeatureCheckRow("Real-Time AI Token Metrics (11 Providers Supported)")
                    FeatureCheckRow("Unlimited Clipboard History with full search")
                    FeatureCheckRow("2FA Authenticator & Pomodoro Focus Timer")
                    FeatureCheckRow("Customizable Liquid Glass blur & caustic bloom controls")
                    FeatureCheckRow("Lifetime updates & priority developer support")
                }
                .padding(.vertical, 4)
            }
        }
        .formStyle(.grouped)
        .scrollContentBackground(.hidden)
        .padding(14)
    }

    private func validateAndActivateLicense() {
        let key = licenseKey.trimmingCharacters(in: .whitespacesAndNewlines)
        if key.count >= 8 {
            isLicensed = true
            registrationError = nil
        } else {
            registrationError = "Invalid license key format. Please verify and try again."
        }
    }
}

private struct FeatureCheckRow: View {
    let title: String
    init(_ title: String) { self.title = title }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.cyan)
            Text(title)
                .font(.system(size: 11))
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Tab 8: About

private struct SettingsAboutTab: View {
    @AppStorage("autoDownloadUpdates") private var autoDownloadUpdates = true
    @AppStorage("autoCheckUpdates") private var autoCheckUpdates = true
    @State private var showingUpdateAlert = false
    @State private var isCheckingUpdates = false

    var body: some View {
        VStack(spacing: 16) {
            // App Icon Header with glowing halo
            VStack(spacing: 8) {
                ZStack {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(red: 0.15, green: 0.05, blue: 0.25), Color(red: 0.05, green: 0.02, blue: 0.12)],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .frame(width: 80, height: 80)
                        .shadow(color: Color.purple.opacity(0.4), radius: 14, x: 0, y: 6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .strokeBorder(Color.white.opacity(0.2), lineWidth: 1)
                        )

                    // Minimal Notch Smiley Logo
                    VStack(spacing: 6) {
                        HStack(spacing: 12) {
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.white)
                                .frame(width: 3.5, height: 10)
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.white)
                                .frame(width: 3.5, height: 10)
                        }
                        Text("‿")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .offset(y: -4)
                    }
                }

                Text("Notchy")
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .foregroundStyle(.white)

                Text("v1.0.0 (Build 1)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 14)

            // Update Options
            HStack(spacing: 18) {
                Toggle("Auto download updates", isOn: $autoDownloadUpdates)
                Toggle("Auto check for updates", isOn: $autoCheckUpdates)
            }
            .font(.caption)

            Button {
                isCheckingUpdates = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    isCheckingUpdates = false
                    showingUpdateAlert = true
                }
            } label: {
                HStack(spacing: 6) {
                    if isCheckingUpdates {
                        ProgressView().controlSize(.small)
                    }
                    Text(isCheckingUpdates ? "Checking…" : "Check for Updates…")
                }
            }
            .controlSize(.regular)
            .disabled(isCheckingUpdates)
            .alert("You're Up to Date!", isPresented: $showingUpdateAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Notchy v1.0.0 is currently the newest version available.")
            }

            Divider()
                .padding(.horizontal, 40)

            // Mission & Philosophy Statement
            VStack(spacing: 6) {
                Text("Notchy is designed for MacBook Notch & Dynamic Island enthusiasts")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                Text("Crafted with passion using pure SwiftUI & AppKit for native macOS efficiency.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            // Quick Links Capsules
            HStack(spacing: 8) {
                LinkButton(title: "Website", systemImage: "globe", url: "https://notchy.app")
                LinkButton(title: "Email Us", systemImage: "envelope.fill", url: "mailto:nildesai76@gmail.com")
                LinkButton(title: "Privacy Policy", systemImage: "hand.raised.fill", url: "https://notchy.app/privacy")
            }
            .padding(.bottom, 16)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 24)
    }
}

private struct LinkButton: View {
    let title: String
    let systemImage: String
    let url: String

    var body: some View {
        Button {
            if let link = URL(string: url) {
                NSWorkspace.shared.open(link)
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: systemImage)
                    .font(.system(size: 9))
                Text(title)
                    .font(.system(size: 10, weight: .medium))
            }
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.08), in: Capsule())
            .overlay(
                Capsule()
                    .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
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
