//
//  MediaVisualizerView.swift
//  Notchy
//
//  Animated audio spectrum visualizer reacting to playback.
//

import SwiftUI

struct MediaVisualizerView: View {
    let isPlaying: Bool
    var barCount: Int = 5
    var color: Color = .white

    var body: some View {
        TimelineView(.animation(minimumInterval: 0.12, paused: !isPlaying)) { timeline in
            HStack(alignment: .bottom, spacing: 2.5) {
                ForEach(0..<barCount, id: \.self) { index in
                    let height = barHeight(for: index, date: timeline.date)
                    RoundedRectangle(cornerRadius: 1.5)
                        .fill(color)
                        .frame(width: 3, height: height)
                }
            }
            .frame(height: 16)
        }
    }

    private func barHeight(for index: Int, date: Date) -> CGFloat {
        guard isPlaying else { return 3 }
        let time = date.timeIntervalSinceReferenceDate
        // Smooth pseudo-random sine wave variations per bar
        let phase = Double(index) * 1.3
        let wave = (sin(time * 6.0 + phase) + sin(time * 3.5 + phase * 0.7) + 2.0) / 4.0
        return CGFloat(4 + wave * 12)
    }
}
