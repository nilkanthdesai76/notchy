//
//  TimerManager.swift
//  Notchy
//
//  Pomodoro & countdown timer with audio alerts and live activity integration.
//

import AppKit
import Combine
import Foundation

@MainActor
final class TimerManager: ObservableObject {
    static let shared = TimerManager()

    @Published var duration: TimeInterval = 25 * 60
    @Published var timeRemaining: TimeInterval = 25 * 60
    @Published var isRunning: Bool = false
    @Published var isFinished: Bool = false

    private var timer: AnyCancellable?
    private var targetTime: Date?

    var timeRemainingString: String {
        let mins = Int(timeRemaining) / 60
        let secs = Int(timeRemaining) % 60
        return String(format: "%02d:%02d", mins, secs)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return 1.0 - (timeRemaining / duration)
    }

    func start(minutes: Int) {
        duration = TimeInterval(minutes * 60)
        timeRemaining = duration
        isFinished = false
        targetTime = Date().addingTimeInterval(duration)
        isRunning = true

        startTicking()
    }

    func togglePause() {
        if isRunning {
            pause()
        } else {
            resume()
        }
    }

    func pause() {
        isRunning = false
        timer?.cancel()
    }

    func resume() {
        guard timeRemaining > 0 else { return }
        isRunning = true
        targetTime = Date().addingTimeInterval(timeRemaining)
        startTicking()
    }

    func reset() {
        isRunning = false
        isFinished = false
        timer?.cancel()
        timeRemaining = duration
    }

    private func startTicking() {
        timer?.cancel()
        timer = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self = self, let target = self.targetTime else { return }
                let rem = target.timeIntervalSinceNow
                if rem <= 0 {
                    self.timeRemaining = 0
                    self.isRunning = false
                    self.isFinished = true
                    self.timer?.cancel()
                    NSSound(named: "Glass")?.play()
                } else {
                    self.timeRemaining = rem
                }
            }
    }
}
