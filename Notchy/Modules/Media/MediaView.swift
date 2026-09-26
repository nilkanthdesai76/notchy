//
//  MediaView.swift
//  Notchy
//
//  Compact Media card partitioned for 30% panel width.
//

import SwiftUI
import Combine

struct MediaView: View {
    @EnvironmentObject private var media: MediaManager
    @State private var isHoveringVolume = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Top Row: Artwork + Title + Artist
            HStack(spacing: 10) {
                artwork
                VStack(alignment: .leading, spacing: 2) {
                    if media.hasSession {
                        Text(media.state.title)
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                        Text(media.state.artist)
                            .font(.system(size: 10))
                            .foregroundStyle(.white.opacity(0.6))
                            .lineLimit(1)
                    } else {
                        Text("No Music Playing")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("Start playback to see controls")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.3))
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
                if media.state.isPlaying {
                    MediaVisualizerView(isPlaying: true, barCount: 4, color: .green.opacity(0.9))
                }
            }

            if media.hasSession {
                // Scrubber Bar
                progressBar

                // Controls Row
                HStack(spacing: 8) {
                    NotchIconButton(systemName: "backward.fill", fontSize: 11, action: media.previousTrack)
                    Spacer()
                    NotchIconButton(
                        systemName: media.state.isPlaying ? "pause.fill" : "play.fill",
                        fontSize: 14,
                        action: media.togglePlayPause
                    )
                    Spacer()
                    NotchIconButton(systemName: "forward.fill", fontSize: 11, action: media.nextTrack)
                }
                .padding(.horizontal, 4)
            } else {
                Spacer()
                HStack {
                    Spacer()
                    Image(systemName: "music.quarternote.3")
                        .font(.system(size: 24))
                        .foregroundStyle(.white.opacity(0.15))
                    Spacer()
                }
                Spacer()
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            LinearGradient(
                colors: [Color.white.opacity(0.08), Color.white.opacity(0.03)],
                startPoint: .top,
                endPoint: .bottom
            ),
            in: RoundedRectangle(cornerRadius: 14, style: .continuous)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .strokeBorder(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private var artwork: some View {
        Group {
            if let data = media.state.artwork, let image = NSImage(data: data) {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    LinearGradient(
                        colors: [Color.purple.opacity(0.4), Color.blue.opacity(0.3)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    Image(systemName: "music.note")
                        .font(.system(size: 16, weight: .medium))
                        .foregroundStyle(.white.opacity(0.7))
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
        .shadow(color: .black.opacity(0.4), radius: 4, y: 2)
    }

    private var progressBar: some View {
        TimelineView(.periodic(from: .now, by: 0.5)) { context in
            let progress: Double = {
                guard media.state.duration > 0 else { return 0 }
                let advanced = media.state.isPlaying
                    ? max(0, context.date.timeIntervalSince(media.state.updatedAt)) * media.state.playbackRate
                    : 0
                let elapsed = media.state.elapsed + advanced
                return min(max(elapsed / media.state.duration, 0), 1)
            }()

            VStack(spacing: 2) {
                GeometryReader { geometry in
                    ZStack(alignment: .leading) {
                        Capsule().fill(.white.opacity(0.12))
                        Capsule()
                            .fill(LinearGradient(colors: [.white.opacity(0.9), .white.opacity(0.6)], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(0, geometry.size.width * progress))
                    }
                }
                .frame(height: 3)

                HStack {
                    Text(formatTime(media.state.elapsed))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    Text(formatTime(media.state.duration))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        guard !seconds.isNaN, seconds > 0 else { return "0:00" }
        let mins = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", mins, secs)
    }
}
