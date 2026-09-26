//
//  TimerView.swift
//  Notchy
//
//  Dedicated Focus & Pomodoro Timer module with visual progress ring
//  and quick preset buttons.
//

import Combine
import SwiftUI

struct TimerView: View {
    @ObservedObject var timer = TimerManager.shared

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Title + State Indicator
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "timer")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("Focus Timer")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                Spacer()

                if timer.isRunning {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.orange)
                            .frame(width: 5, height: 5)
                        Text("Active")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.orange)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            // Main Display: Timer Ring & Countdown
            HStack(spacing: 12) {
                // Circular Progress Dial
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: CGFloat(max(0.01, timer.progress)))
                        .stroke(
                            timer.isRunning ? Color.orange : Color.white.opacity(0.4),
                            style: StrokeStyle(lineWidth: 4, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 0.5), value: timer.progress)

                    Image(systemName: timer.isRunning ? "bolt.fill" : "hourglass")
                        .font(.system(size: 11))
                        .foregroundStyle(timer.isRunning ? .orange : .white.opacity(0.4))
                }
                .frame(width: 38, height: 38)

                VStack(alignment: .leading, spacing: 1) {
                    Text(timer.timeRemainingString)
                        .font(.system(size: 20, weight: .bold, design: .monospaced))
                        .foregroundStyle(timer.isRunning ? .orange : .white)

                    Text(timer.isRunning ? "Pomodoro session in progress" : (timer.isFinished ? "Time is up!" : "Ready to focus"))
                        .font(.system(size: 8.5))
                        .foregroundStyle(.white.opacity(0.5))
                }

                Spacer()

                // Primary Play/Pause and Reset Buttons
                HStack(spacing: 5) {
                    Button {
                        timer.togglePause()
                    } label: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 11, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 28, height: 28)
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
                                .font(.system(size: 9, weight: .bold))
                                .foregroundStyle(.white.opacity(0.6))
                                .frame(width: 24, height: 24)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(.vertical, 2)

            // Preset Buttons
            HStack(spacing: 5) {
                TimerPresetButton(title: "25m Pomo", minutes: 25, isRunning: timer.isRunning && timer.duration == 25 * 60) {
                    timer.start(minutes: 25)
                }
                TimerPresetButton(title: "5m Break", minutes: 5, isRunning: timer.isRunning && timer.duration == 5 * 60) {
                    timer.start(minutes: 5)
                }
                TimerPresetButton(title: "15m Focus", minutes: 15, isRunning: timer.isRunning && timer.duration == 15 * 60) {
                    timer.start(minutes: 15)
                }
                TimerPresetButton(title: "45m Deep", minutes: 45, isRunning: timer.isRunning && timer.duration == 45 * 60) {
                    timer.start(minutes: 45)
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod(cornerRadius: 16)
    }
}

private struct TimerPresetButton: View {
    let title: String
    let minutes: Int
    let isRunning: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 8.5, weight: .medium))
                .foregroundStyle(isRunning ? .orange : .white.opacity(0.8))
                .padding(.horizontal, 4)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    isRunning ? Color.orange.opacity(0.25) : Color.white.opacity(0.07),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
