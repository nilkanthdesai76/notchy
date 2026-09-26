//
//  MediaManager.swift
//  Notchy
//
//  Now Playing + transport controls.
//
//  Transport (play/pause/next/prev) uses MRMediaRemoteSendCommand loaded
//  at runtime — this still works on modern macOS.
//
//  Metadata uses the mediaremote-adapter (ungive, BSD-3, vendored in
//  Vendor/) streamed via /usr/bin/perl, because macOS 15.4+ blocks
//  third-party apps from reading Now Playing directly. If the adapter
//  fails (missing files, stripped entitlements, future macOS changes),
//  we gracefully fall back to AppleScript polling for Music/Spotify.
//

import AppKit
import Combine
import Foundation

struct PlaybackState {
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

    // MARK: - Adapter process

    private var adapterProcess: Process?
    private var adapterBuffer = ""
    private var adapterReceivedBytes = false
    private var appleScriptTimer: Timer?

    var isPlaying: Bool {
        state.isPlaying && !state.title.isEmpty
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
    }

    deinit {
        adapterProcess?.terminate()
        appleScriptTimer?.invalidate()
    }

    /// Stop the adapter child process and timers. Called on app termination
    /// so no orphaned perl processes are left behind.
    func shutdown() {
        adapterProcess?.terminate()
        adapterProcess = nil
        appleScriptTimer?.invalidate()
        appleScriptTimer = nil
    }

    // MARK: - Transport

    func togglePlayPause() { sendCommandFunction?(2, nil) }
    func nextTrack() { sendCommandFunction?(4, nil) }
    func previousTrack() { sendCommandFunction?(5, nil) }

    // MARK: - mediaremote-adapter stream

    private func startAdapterStream() {
        guard
            let scriptURL = Bundle.main.url(forResource: "mediaremote-adapter", withExtension: "pl"),
            let frameworkPath = Bundle.main.resourceURL?
                .appendingPathComponent("MediaRemoteAdapter.framework")
                .path
        else {
            startAppleScriptFallback()
            return
        }

        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/perl")
        process.arguments = [scriptURL.path, frameworkPath, "stream"]
        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = Pipe() // swallow diagnostics

        do {
            try process.run()
        } catch {
            startAppleScriptFallback()
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

        // Probe: if nothing arrives within 10s the adapter is broken here.
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: 10_000_000_000)
            guard let self, !self.adapterReceivedBytes, !Task.isCancelled else { return }
            self.stopAdapter()
            self.startAppleScriptFallback()
        }
    }

    private func stopAdapter() {
        adapterProcess?.terminate()
        adapterProcess = nil
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
            hasSession = false
            return
        }

        var newState = state
        newState.title = payload.title ?? (isDiff ? state.title : "")
        newState.artist = payload.artist ?? (isDiff ? state.artist : "")
        newState.album = payload.album ?? (isDiff ? state.album : "")
        newState.isPlaying = payload.playing ?? (isDiff ? state.isPlaying : false)
        newState.bundleIdentifier =
            payload.parentApplicationBundleIdentifier
            ?? payload.bundleIdentifier
            ?? (isDiff ? state.bundleIdentifier : "")
        if let artworkBase64 = payload.artwork ?? payload.artworkData {
            newState.artwork = Data(base64Encoded: artworkBase64.trimmingCharacters(in: .whitespacesAndNewlines))
        } else if !isDiff {
            newState.artwork = nil
        }
        newState.duration = payload.duration ?? (isDiff ? state.duration : 0)
        newState.elapsed = payload.elapsedTime ?? (isDiff ? state.elapsed : 0)
        newState.playbackRate = payload.playbackRate ?? (isDiff ? state.playbackRate : 1)
        newState.updatedAt = payload.timestamp.flatMap { ISO8601DateFormatter().date(from: $0) } ?? Date()
        state = newState
        hasSession = !newState.title.isEmpty
    }

    // MARK: - AppleScript fallback

    private func startAppleScriptFallback() {
        let timer = Timer.scheduledTimer(withTimeInterval: 5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.pollAppleScript()
            }
        }
        appleScriptTimer = timer
        pollAppleScript()
    }

    private func pollAppleScript() {
        let source = """
        tell application "Music"
            if it is running then
                if player state is playing then
                    return "music|||" & name of current track & "|||" & artist of current track
                end if
            end if
        end tell
        tell application "Spotify"
            if it is running then
                if player state is playing then
                    return "spotify|||" & name of current track & "|||" & artist of current track
                end if
            end if
        end tell
        return ""
        """
        var error: NSDictionary?
        guard
            let result = NSAppleScript(source: source)?.executeAndReturnError(&error).stringValue,
            !result.isEmpty
        else {
            hasSession = false
            return
        }
        let parts = result.components(separatedBy: "|||")
        state.title = parts.count > 1 ? parts[1] : ""
        state.artist = parts.count > 2 ? parts[2] : ""
        state.bundleIdentifier = parts.first == "spotify" ? "com.spotify.client" : "com.apple.Music"
        state.isPlaying = true
        hasSession = !state.title.isEmpty
    }
}

// MARK: - Adapter JSON types

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
