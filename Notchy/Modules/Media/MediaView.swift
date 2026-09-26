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
    @State private var isHoveringProgress = false

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
                // Interactive Liquid Glass Scrubber
                progressBar

                // Grouped Liquid Glass Transport Capsule
                HStack {
                    Spacer(minLength: 0)
                    HStack(spacing: 16) {
                        NotchIconButton(systemName: "backward.fill", fontSize: 11, action: media.previousTrack)
                        NotchIconButton(
                            systemName: media.state.isPlaying ? "pause.fill" : "play.fill",
                            fontSize: 13,
                            action: media.togglePlayPause
                        )
                        NotchIconButton(systemName: "forward.fill", fontSize: 11, action: media.nextTrack)
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 3.5)
                    .liquidGlassCapsule()
                    Spacer(minLength: 0)
                }
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
        .liquidGlassPod(cornerRadius: 16)
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
        .overlay(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .strokeBorder(Color.white.opacity(0.12), lineWidth: 0.75)
        )
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

            VStack(spacing: 3) {
                GeometryReader { geometry in
                    let trackWidth = geometry.size.width
                    let activeWidth = max(0, min(trackWidth * progress, trackWidth))

                    ZStack(alignment: .leading) {
                        // Recessed glass track
                        Capsule()
                            .fill(Color.white.opacity(0.12))
                            .frame(height: isHoveringProgress ? 5 : 3.5)

                        // Luminous progress fill
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [Color.white.opacity(0.95), Color.white.opacity(0.70)],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(width: activeWidth, height: isHoveringProgress ? 5 : 3.5)

                        // Interactive Liquid Glass Knob
                        if isHoveringProgress {
                            Circle()
                                .fill(Color.white)
                                .frame(width: 9, height: 9)
                                .shadow(color: .black.opacity(0.4), radius: 2, y: 1)
                                .offset(x: max(0, min(activeWidth - 4.5, trackWidth - 9)))
                                .transition(.scale.combined(with: .opacity))
                        }
                    }
                    .frame(height: 10)
                    .contentShape(Rectangle())
                    .onHover { isHoveringProgress = $0 }
                }
                .frame(height: 10)
                .animation(.spring(response: 0.25, dampingFraction: 0.75), value: isHoveringProgress)

                HStack {
                    Text(formatTime(media.state.elapsed))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text(formatTime(media.state.duration))
                        .font(.system(size: 8, weight: .regular, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
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
