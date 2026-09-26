//
//  OTPAndTimerView.swift
//  Notchy
//
//  2FA TOTP accounts with countdown rings and Pomodoro Quick Timer.
//

import SwiftUI
import Combine

struct OTPAndTimerView: View {
    @ObservedObject var otp = OTPManager.shared
    @ObservedObject var timer = TimerManager.shared
    @State private var copiedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Title + Status
            HStack {
                Label("2FA & Timer", systemImage: "key.fill")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.85))

                Spacer()

                if timer.isRunning {
                    HStack(spacing: 3) {
                        Image(systemName: "timer")
                            .font(.system(size: 9))
                        Text(timer.timeRemainingString)
                            .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.orange.opacity(0.15), in: Capsule())
                }
            }

            // 2FA Accounts List (Top Half)
            VStack(spacing: 4) {
                ForEach(otp.accounts.prefix(2)) { account in
                    let code = otp.currentCodes[account.id] ?? "------"
                    OTPAccountRow(
                        account: account,
                        code: code,
                        progress: otp.progress,
                        remainingSeconds: otp.remainingSeconds,
                        isCopied: copiedId == account.id
                    ) {
                        NSPasteboard.general.clearContents()
                        NSPasteboard.general.setString(code, forType: .string)
                        copiedId = account.id
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                            if copiedId == account.id {
                                copiedId = nil
                            }
                        }
                    }
                }
            }

            Divider().overlay(Color.white.opacity(0.08))

            // Quick Timer Section (Bottom Half)
            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    HStack(spacing: 4) {
                        Image(systemName: "hourglass")
                            .font(.system(size: 9))
                            .foregroundStyle(.white.opacity(0.5))
                        Text("TIMER")
                            .font(.system(size: 8, weight: .bold))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                    Spacer()

                    Text(timer.timeRemainingString)
                        .font(.system(size: 13, weight: .bold, design: .monospaced))
                        .foregroundStyle(timer.isRunning ? .orange : .white.opacity(0.85))

                    Button {
                        timer.togglePause()
                    } label: {
                        Image(systemName: timer.isRunning ? "pause.fill" : "play.fill")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundStyle(.white)
                            .padding(4)
                            .background(Color.white.opacity(0.12), in: Circle())
                    }
                    .buttonStyle(.plain)

                    if timer.isRunning || timer.timeRemaining != timer.duration {
                        Button {
                            timer.reset()
                        } label: {
                            Image(systemName: "arrow.counterclockwise")
                                .font(.system(size: 8, weight: .bold))
                                .foregroundStyle(.white.opacity(0.5))
                                .padding(4)
                                .background(Color.white.opacity(0.08), in: Circle())
                        }
                        .buttonStyle(.plain)
                    }
                }

                // Presets Bar
                HStack(spacing: 5) {
                    TimerPresetButton(title: "25m Pomo", minutes: 25, isRunning: timer.isRunning && timer.duration == 25*60) {
                        timer.start(minutes: 25)
                    }
                    TimerPresetButton(title: "5m Break", minutes: 5, isRunning: timer.isRunning && timer.duration == 5*60) {
                        timer.start(minutes: 5)
                    }
                    TimerPresetButton(title: "15m Focus", minutes: 15, isRunning: timer.isRunning && timer.duration == 15*60) {
                        timer.start(minutes: 15)
                    }
                }
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod(cornerRadius: 16)
    }
}

private struct OTPAccountRow: View {
    let account: OTPAccount
    let code: String
    let progress: Double
    let remainingSeconds: Int
    let isCopied: Bool
    let onCopy: () -> Void

    @State private var isHovered = false

    var body: some View {
        Button(action: onCopy) {
            HStack(spacing: 7) {
                // Countdown Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(remainingSeconds <= 5 ? Color.red : Color.blue, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remainingSeconds)")
                        .font(.system(size: 7, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .frame(width: 18, height: 18)

                VStack(alignment: .leading, spacing: 0) {
                    Text(account.issuer)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(account.label)
                        .font(.system(size: 7.5))
                        .foregroundStyle(.white.opacity(0.4))
                        .lineLimit(1)
                }

                Spacer()

                if isCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8, weight: .bold))
                        Text("Copied")
                            .font(.system(size: 9, weight: .bold))
                    }
                    .foregroundStyle(.green)
                } else {
                    Text(formatted(code))
                        .font(.system(size: 11, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 7)
            .padding(.vertical, 4.5)
            .background(
                Color.white.opacity(isHovered ? 0.10 : 0.04),
                in: RoundedRectangle(cornerRadius: 7, style: .continuous)
            )
        }
        .buttonStyle(.plain)
        .onHover { isHovered = $0 }
    }

    private func formatted(_ code: String) -> String {
        guard code.count == 6 else { return code }
        let idx = code.index(code.startIndex, offsetBy: 3)
        return "\(code[..<idx]) \(code[idx...])"
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
                .foregroundStyle(isRunning ? .orange : .white.opacity(0.75))
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .frame(maxWidth: .infinity)
                .background(
                    isRunning ? Color.orange.opacity(0.2) : Color.white.opacity(0.06),
                    in: RoundedRectangle(cornerRadius: 6, style: .continuous)
                )
        }
        .buttonStyle(.plain)
    }
}
