//
//  MediaManager.swift
//  Notchy
//
//  Now Playing + transport controls with full multi-browser YouTube support.
//  Combines MediaRemoteAdapter streaming, Mach port watchdog auto-recovery,
//  and asynchronous browser tab metadata extraction for YouTube, Netflix, SoundCloud,
//  Apple Music, Spotify, and all web audio/video players.
//

import AppKit
import Combine
import Foundation

struct PlaybackState: Equatable {
    var title = ""
    var artist = ""
    var album = ""
    var isPlaying = false
    var artwork: Data?
    var bundleIdentifier = ""
    var duration: Double = 0
    /// Elapsed seconds at `updatedAt` (playback advances from there).
    var elapsed: Double = 0
    var playbackRate: Double = 1
    var updatedAt = Date.distantPast
}

@MainActor
final class MediaManager: ObservableObject {
    @Published private(set) var state = PlaybackState()
    @Published private(set) var hasSession = false

    // MARK: - Runtime MediaRemote (transport only)

    private typealias SendCommandFunction = @convention(c) (Int, AnyObject?) -> Void
    private let sendCommandFunction: SendCommandFunction?

    // MARK: - Adapter Process & Watchdog

    private var adapterProcess: Process?
    private var adapterBuffer = ""
    private var adapterReceivedBytes = false
    private var watchdogTimer: Timer?
    private var isResolvingBrowserTitle = false

    var isPlaying: Bool {
        state.isPlaying && (!state.title.isEmpty || !state.bundleIdentifier.isEmpty)
    }

    init() {
        var function: SendCommandFunction?
        if let bundle = CFBundleCreate(
            kCFAllocatorDefault,
            NSURL(fileURLWithPath: "/System/Library/PrivateFrameworks/MediaRemote.framework")
        ), let pointer = CFBundleGetFunctionPointerForName(bundle, "MRMediaRemoteSendCommand" as CFString) {
            function = unsafeBitCast(pointer, to: SendCommandFunction.self)
        }
        sendCommandFunction = function

        startAdapterStream()
        startWatchdog()
    }

    deinit {
        // Nonisolated cleanup
        adapterProcess?.terminate()
        watchdogTimer?.invalidate()
    }

    func shutdown() {
        adapterProcess?.terminate()
        adapterProcess = nil
        watchdogTimer?.invalidate()
        watchdogTimer = nil
    }

    // MARK: - Transport Controls

    func togglePlayPause() {
        sendCommandFunction?(2, nil)
        // Instant optimistic feedback
        state.isPlaying.toggle()
        state.updatedAt = Date()
    }

    func nextTrack() {
        sendCommandFunction?(4, nil)
    }

    func previousTrack() {
        sendCommandFunction?(5, nil)
    }

    // MARK: - MediaRemote Adapter Stream

    private func startAdapterStream() {
        adapterProcess?.terminate()
        adapterProcess = nil
        adapterBuffer = ""

        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.resourceURL?
                .appendingPathComponent("MediaRemoteAdapter.framework")
                .path
        else {
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
        } catch {
            return
        }

        adapterProcess = process
        pipe.fileHandleForReading.readabilityHandler = { [weak self] handle in
            let data = handle.availableData
            guard !data.isEmpty, let chunk = String(data: data, encoding: .utf8) else { return }
            Task { @MainActor in
                self?.accumulateAdapterChunk(chunk)
            }
        }
    }

    private func accumulateAdapterChunk(_ chunk: String) {
        adapterReceivedBytes = true
        adapterBuffer.append(chunk)
        while let range = adapterBuffer.range(of: "\n") {
            let line = adapterBuffer[..<range.lowerBound]
            adapterBuffer = String(adapterBuffer[range.upperBound...])
            guard !line.isEmpty else { continue }
            if let data = line.data(using: .utf8),
               let update = try? JSONDecoder().decode(AdapterUpdate.self, from: data) {
                applyAdapterUpdate(update)
            }
        }
    }

    private func applyAdapterUpdate(_ update: AdapterUpdate) {
        let payload = update.payload
        let isDiff = update.diff ?? false

        // A full payload with no identity and no title means "nothing is playing".
        if !isDiff, payload.bundleIdentifier == nil, payload.parentApplicationBundleIdentifier == nil, payload.title == nil {
            // Check if user has active web playback before clearing
            if isBrowserBundle(state.bundleIdentifier) && state.isPlaying {
                // Keep active until confirmed stopped
            } else {
                hasSession = false
                state.isPlaying = false
                return
            }
        }

        var newState = state
        let incomingTitle = payload.title ?? (isDiff ? state.title : "")
        let incomingArtist = payload.artist ?? (isDiff ? state.artist : "")
        let incomingPlaying = payload.playing ?? (isDiff ? state.isPlaying : false)
        let incomingBundle = payload.parentApplicationBundleIdentifier
            ?? payload.bundleIdentifier
            ?? (isDiff ? state.bundleIdentifier : "")

        newState.title = incomingTitle
        newState.artist = incomingArtist
        newState.album = payload.album ?? (isDiff ? state.album : "")
        newState.isPlaying = incomingPlaying
        newState.bundleIdentifier = incomingBundle

        if let artworkBase64 = payload.artwork ?? payload.artworkData {
            newState.artwork = Data(base64Encoded: artworkBase64.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if !isDiff {
            newState.artwork = nil
        }

        newState.duration = payload.duration ?? (isDiff ? state.duration : 0)
        newState.elapsed = payload.elapsedTime ?? (isDiff ? state.elapsed : 0)
        newState.playbackRate = payload.playbackRate ?? (isDiff ? state.playbackRate : 1)
        newState.updatedAt = payload.timestamp.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()

        // Browser / YouTube Special Handling:
        // macOS MediaRemote frequently returns empty title "" for YouTube in Chrome/Brave/Arc/Safari
        if isBrowserBundle(newState.bundleIdentifier) {
            if newState.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                if newState.isPlaying || newState.duration > 0 {
                    newState.title = "YouTube Video"
                    newState.artist = friendlyBrowserName(for: newState.bundleIdentifier)
                }
                resolveBrowserMetadata(for: newState.bundleIdentifier)
            } else if newState.title.contains("YouTube") || newState.artist.isEmpty {
                newState.title = cleanYouTubeTitle(newState.title)
                if newState.artist.isEmpty {
                    newState.artist = "YouTube"
                }
            }
        }

        state = newState
        hasSession = !newState.title.isEmpty || (isBrowserBundle(newState.bundleIdentifier) && newState.isPlaying)
    }

    // MARK: - Watchdog
    private func startWatchdog() {
        watchdogTimer = Timer.scheduledTimer(withTimeInterval: 2.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self = self else { return }
                if self.adapterProcess == nil || self.adapterProcess?.isRunning == false {
                    self.startAdapterStream()
                }
            }
        }
    }

    // MARK: - Browser YouTube Resolution

    private func isBrowserBundle(_ bundleID: String) -> Bool {
        let b = bundleID.lowercased()
        return b.contains("brave") || b.contains("chrome") || b.contains("safari")
            || b.contains("thebrowser") || b.contains("edge") || b.contains("firefox")
            || b.contains("opera") || b.contains("vivaldi")
    }

    private func friendlyBrowserName(for bundleID: String) -> String {
        let b = bundleID.lowercased()
        if b.contains("brave") { return "Brave" }
        if b.contains("chrome") { return "Google Chrome" }
        if b.contains("safari") { return "Safari" }
        if b.contains("thebrowser") || b.contains("arc") { return "Arc" }
        if b.contains("edge") { return "Microsoft Edge" }
        if b.contains("firefox") { return "Firefox" }
        return "Web Media"
    }

    private func cleanYouTubeTitle(_ raw: String) -> String {
        var clean = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip YouTube notification count e.g. "(1) " or "(12) "
        if clean.hasPrefix("(") && clean.contains(") ") {
            if let closingIdx = clean.firstIndex(of: ")") {
                let after = clean.index(after: closingIdx)
                clean = String(clean[after...]).trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        // Strip trailing " - YouTube"
        if clean.hasSuffix(" - YouTube") {
            clean = String(clean.dropLast(" - YouTube".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        if clean.hasSuffix(" - YouTube Music") {
            clean = String(clean.dropLast(" - YouTube Music".count)).trimmingCharacters(in: .whitespacesAndNewlines)
        }
        return clean.isEmpty ? raw : clean
    }

    private func resolveBrowserMetadata(for bundleID: String) {
        guard !isResolvingBrowserTitle else { return }
        isResolvingBrowserTitle = true

        Task.detached(priority: .userInitiated) {
            let title = BrowserAudioQueryEngine.queryBrowserTitle(for: bundleID)
            await MainActor.run {
                self.isResolvingBrowserTitle = false
                if let rawTitle = title, !rawTitle.isEmpty {
                    var updated = self.state
                    updated.title = self.cleanYouTubeTitle(rawTitle)
                    if updated.artist.isEmpty {
                        updated.artist = "YouTube"
                    }
                    self.state = updated
                    self.hasSession = true
                }
            }
        }
    }
}

// MARK: - Safe Browser Query Engine (Only queries running apps via Bundle ID)

enum BrowserAudioQueryEngine {
    nonisolated static func queryBrowserTitle(for bundleID: String) -> String? {
        guard !bundleID.isEmpty else { return nil }

        // Never touch AppleScript unless the application is actively running on this Mac
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: bundleID)
        guard !running.isEmpty else { return nil }

        let b = bundleID.lowercased()
        let scriptSource: String

        if b.contains("chrome") || b.contains("brave") || b.contains("edge") || b.contains("vivaldi") || b.contains("opera") {
            scriptSource = """
            try
                tell application id "\(bundleID)"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tTitle to (title of t) as text
                            if tTitle contains "YouTube" or tTitle contains "SoundCloud" or tTitle contains "Spotify" or tTitle contains "Netflix" then
                                return tTitle
                            end if
                        end repeat
                    end repeat
                end tell
            end try
            return ""
            """
        } else if b.contains("safari") {
            scriptSource = """
            try
                tell application id "com.apple.Safari"
                    repeat with w in windows
                        repeat with t in tabs of w
                            set tTitle to (name of t) as text
                            if tTitle contains "YouTube" or tTitle contains "SoundCloud" or tTitle contains "Spotify" then
                                return tTitle
                            end if
                        end repeat
                    end repeat
                end tell
            end try
            return ""
            """
        } else if b.contains("thebrowser") || b.contains("arc") {
            scriptSource = """
            try
                tell application id "company.thebrowser.Browser"
                    tell front window
                        set tTitle to (title of active tab) as text
                        if tTitle contains "YouTube" or tTitle contains "SoundCloud" then
                            return tTitle
                        end if
                    end tell
                end tell
            end try
            return ""
            """
        } else {
            return nil
        }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: scriptSource) else { return nil }
        let output = script.executeAndReturnError(&error).stringValue?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return output.isEmpty ? nil : output
    }
}

// MARK: - Adapter JSON Types

private struct AdapterUpdate: Decodable {
    let payload: AdapterPayload
    let diff: Bool?
}

private struct AdapterPayload: Decodable {
    let title: String?
    let artist: String?
    let album: String?
    let duration: Double?
    let elapsedTime: Double?
    let artwork: String?
    let artworkData: String?
    let artworkMimeType: String?
    let timestamp: String?
    let playbackRate: Double?
    let playing: Bool?
    let parentApplicationBundleIdentifier: String?
    let bundleIdentifier: String?
}
