//
//  OTPView.swift
//  Notchy
//
//  Dedicated 2FA TOTP Authenticator module with adaptive single/multi-card
//  layout support, live countdown rings, and one-click code copying.
//

import Combine
import SwiftUI

struct OTPView: View {
    @ObservedObject var otp = OTPManager.shared
    @Environment(\.cardSlotCount) private var cardSlotCount
    @State private var copiedId: UUID?

    var body: some View {
        VStack(alignment: .leading, spacing: cardSlotCount == 1 ? 9 : 8) {
            // Header Row: Title + Countdown badge
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "key.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.purple)
                    Text("2FA Authenticator")
                        .font(.system(size: cardSlotCount == 1 ? 12 : 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                }

                if cardSlotCount == 1 {
                    Text("• \(otp.accounts.count) Accounts Configured")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                // Live Refresh Pill
                HStack(spacing: 4) {
                    ZStack {
                        Circle()
                            .stroke(Color.white.opacity(0.15), lineWidth: 1.5)
                        Circle()
                            .trim(from: 0, to: CGFloat(otp.progress))
                            .stroke(otp.remainingSeconds <= 5 ? Color.red : Color.purple, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                            .rotationEffect(.degrees(-90))
                    }
                    .frame(width: 10, height: 10)

                    Text("\(otp.remainingSeconds)s")
                        .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.6))
                }
                .padding(.horizontal, 5)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.06), in: Capsule())
            }

            // Accounts List or Empty State
            if otp.accounts.isEmpty {
                VStack(spacing: 6) {
                    Spacer()
                    Image(systemName: "lock.shield")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                    Text("No 2FA Accounts")
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.6))
                    Button("Add Sample Keys") {
                        otp.addAccount(issuer: "GitHub", label: "dev@github.com", secret: "JBSWY3DPEHPK3PXP")
                        otp.addAccount(issuer: "Google", label: "work@google.com", secret: "HXDMVJECJJWSRB3H")
                        otp.addAccount(issuer: "AWS", label: "infra@prod.aws", secret: "HXDMVJECJJWSRB3H")
                    }
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(.cyan)
                    .buttonStyle(.plain)
                    Spacer()
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if cardSlotCount == 1 {
                // Wide 2-Column Grid
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 6) {
                    ForEach(otp.accounts.prefix(4)) { account in
                        let code = otp.currentCodes[account.id] ?? "------"
                        OTPAccountRow(
                            account: account,
                            code: code,
                            progress: otp.progress,
                            remainingSeconds: otp.remainingSeconds,
                            isCopied: copiedId == account.id
                        ) {
                            copyCode(code, for: account.id)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            } else {
                // Compact Vertical List
                VStack(spacing: 5) {
                    ForEach(otp.accounts.prefix(3)) { account in
                        let code = otp.currentCodes[account.id] ?? "------"
                        OTPAccountRow(
                            account: account,
                            code: code,
                            progress: otp.progress,
                            remainingSeconds: otp.remainingSeconds,
                            isCopied: copiedId == account.id
                        ) {
                            copyCode(code, for: account.id)
                        }
                    }
                }
                .frame(maxHeight: .infinity, alignment: .top)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod()
    }

    private func copyCode(_ code: String, for id: UUID) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(code, forType: .string)
        copiedId = id
        NSSound(named: "Pop")?.play()
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
            if copiedId == id {
                copiedId = nil
            }
        }
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
            HStack(spacing: 8) {
                // Countdown Ring
                ZStack {
                    Circle()
                        .stroke(Color.white.opacity(0.12), lineWidth: 2)
                    Circle()
                        .trim(from: 0, to: CGFloat(progress))
                        .stroke(remainingSeconds <= 5 ? Color.red : Color.purple, style: StrokeStyle(lineWidth: 2, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                    Text("\(remainingSeconds)")
                        .font(.system(size: 7.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.75))
                }
                .frame(width: 20, height: 20)

                VStack(alignment: .leading, spacing: 0) {
                    Text(account.issuer)
                        .font(.system(size: 9.5, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Text(account.label)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.45))
                        .lineLimit(1)
                }

                Spacer()

                if isCopied {
                    HStack(spacing: 2) {
                        Image(systemName: "checkmark")
                            .font(.system(size: 8.5, weight: .bold))
                        Text("Copied")
                            .font(.system(size: 9.5, weight: .bold))
                    }
                    .foregroundStyle(.green)
                } else {
                    Text(formatted(code))
                        .font(.system(size: 11.5, weight: .bold, design: .monospaced))
                        .foregroundStyle(.white)
                }
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(
                Color.white.opacity(isHovered ? 0.12 : 0.05),
                in: RoundedRectangle(cornerRadius: 8, style: .continuous)
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
