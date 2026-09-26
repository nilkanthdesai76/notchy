//
//  TimerView.swift
//  Notchy
//
//  Adaptive Focus & Pomodoro Timer module with conditional single/double/triple
//  card layout support, visual progress rings, and rich presets.
//

import Combine
import SwiftUI

struct TimerView: View {
    @ObservedObject var timer = TimerManager.shared
    @Environment(\.cardSlotCount) private var cardSlotCount

    var body: some View {
        VStack(alignment: .leading, spacing: cardSlotCount == 1 ? 10 : 8) {
            // Header Row: Title + State Indicator
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("Focus Timer")
                        .font(.system(size: cardSlotCount == 1 ? 12 : 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                if cardSlotCount == 1 {
                    Text(timer.isRunning ? "• Active Session" : "• Pomodoro Technique")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                if timer.isRunning {
                    HStack(spacing: 3.5) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text(timer.timeRemainingString)
                            .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2.5)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            // Main Display: Timer Ring & Countdown
            if cardSlotCount == 1 {
                // Wide Solo Layout
                HStack(spacing: 18) {
                    // Big Circular Dial Ring
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.10), lineWidth: 5)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.01, timer.progress)))
                            .stroke(
                                timer.isRunning ? Color.orange : Color.white.opacity(0.4),
                                style: StrokeStyle(lineWidth: 5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: timer.progress)

                        Image(systemName: timer.isRunning ? "bolt.fill" : "hourglass")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(timer.isRunning ? .orange : .white.opacity(0.5))
                    }
                    .frame(width: 48, height: 48)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(timer.timeRemainingString)
                            .font(.system(size: 28, weight: .bold, design: .monospaced))
                            .foregroundStyle(timer.isRunning ? .orange : .white)

                        Text(timer.isRunning ? "Focus session in progress — stay in the zone" : (timer.isFinished ? "Time is up! Great job." : "Ready to focus — select a preset below"))
                            .font(.system(size: 9.5))
                            .foregroundStyle(.white.opacity(0.55))
                    }

                    Spacer()

                    // Controls
                    HStack(spacing: 8) {
                        Button {
                            timer.togglePause()
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                    .font(.system(size: 13, weight: .bold))
                                Text(timer.isRunning ? "Pause" : "Start")
                                    .font(.system(size: 11, weight: .semibold))
                            }
                            .foregroundStyle(.white)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(
                                timer.isRunning ? Color.orange : Color.white.opacity(0.15),
                                in: Capsule()
                            )
                        }
                        .buttonStyle(.plain)

                        if timer.isRunning || timer.timeRemaining != timer.duration {
                            Button {
                                timer.reset()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .padding(8)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                            .help("Reset Timer")
                        }
                    }
                }
                .padding(.vertical, 2)
            } else {
                // Compact / Multi-card Layout
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 3.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(max(0.01, timer.progress)))
                            .stroke(
                                timer.isRunning ? Color.orange : Color.white.opacity(0.4),
                                style: StrokeStyle(lineWidth: 3.5, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .animation(.linear(duration: 0.5), value: timer.progress)

                        Image(systemName: timer.isRunning ? "bolt.fill" : "hourglass")
                            .font(.system(size: 10))
                            .foregroundStyle(timer.isRunning ? .orange : .white.opacity(0.4))
                    }
                    .frame(width: 34, height: 34)

                    VStack(alignment: .leading, spacing: 1) {
                        Text(timer.timeRemainingString)
                            .font(.system(size: 19, weight: .bold, design: .monospaced))
                            .foregroundStyle(timer.isRunning ? .orange : .white)

                        Text(timer.isRunning ? "Focusing" : (timer.isFinished ? "Finished" : "Ready"))
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.5))
                    }

                    Spacer()

                    HStack(spacing: 4) {
                        Button {
                            timer.togglePause()
                        } label: {
                            Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                                .font(.system(size: 10, weight: .bold))
                                .foregroundStyle(.white)
                                .frame(width: 26, height: 26)
                                .background(
                                    timer.isRunning ? Color.orange : Color.white.opacity(0.15),
                                    in: Circle()
                                )
                        }
                        .buttonStyle(.plain)

                        if timer.isRunning || timer.timeRemaining != timer.duration {
                            Button {
                                timer.reset()
                            } label: {
                                Image(systemName: "arrow.counterclockwise")
                                    .font(.system(size: 8.5, weight: .bold))
                                    .foregroundStyle(.white.opacity(0.6))
                                    .frame(width: 22, height: 22)
                                    .background(Color.white.opacity(0.08), in: Circle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.vertical, 1)
            }

            // Presets Bar (Evenly Stretched)
            HStack(spacing: cardSlotCount == 1 ? 8 : 4) {
                TimerPresetButton(
                    title: cardSlotCount == 1 ? "25m Pomodoro" : "25m",
                    iconName: "bolt.fill",
                    minutes: 25,
                    isRunning: timer.isRunning && timer.duration == 25 * 60,
                    isWide: cardSlotCount == 1
                ) {
                    timer.start(minutes: 25)
                }
                TimerPresetButton(
                    title: cardSlotCount == 1 ? "5m Short Break" : "5m",
                    iconName: "cup.and.saucer.fill",
                    minutes: 5,
                    isRunning: timer.isRunning && timer.duration == 5 * 60,
                    isWide: cardSlotCount == 1
                ) {
                    timer.start(minutes: 5)
                }
                TimerPresetButton(
                    title: cardSlotCount == 1 ? "15m Long Break" : "15m",
                    iconName: "leaf.fill",
                    minutes: 15,
                    isRunning: timer.isRunning && timer.duration == 15 * 60,
                    isWide: cardSlotCount == 1
                ) {
                    timer.start(minutes: 15)
                }
                TimerPresetButton(
                    title: cardSlotCount == 1 ? "45m Deep Work" : "45m",
                    iconName: "brain.head.profile",
                    minutes: 45,
                    isRunning: timer.isRunning && timer.duration == 45 * 60,
                    isWide: cardSlotCount == 1
                ) {
                    timer.start(minutes: 45)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod()
    }
}

private struct TimerPresetButton: View {
    let title: String
    let iconName: String
    let minutes: Int
    let isRunning: Bool
    let isWide: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                if isWide {
                    Image(systemName: iconName)
                        .font(.system(size: 8))
                        .foregroundStyle(isRunning ? .orange : .white.opacity(0.6))
                }
                Text(title)
                    .font(.system(size: isWide ? 9 : 8.5, weight: isRunning ? .bold : .medium))
                    .foregroundStyle(isRunning ? .orange : .white.opacity(0.85))
            }
            .padding(.horizontal, isWide ? 8 : 4)
            .padding(.vertical, isWide ? 6 : 4.5)
            .frame(maxWidth: .infinity)
            .background(
                isRunning ? Color.orange.opacity(0.25) : Color.white.opacity(0.07),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .strokeBorder(isRunning ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
