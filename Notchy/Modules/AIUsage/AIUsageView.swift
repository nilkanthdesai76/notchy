//
//  AIUsageView.swift
//  Notchy
//
//  AI Token Usage monitor partitioned for 50% panel width.
//  Displays real token usage and model statistics from local sessions
//  with zero dummy or simulated data.
//

import SwiftUI
import Combine

struct AIUsageView: View {
    @ObservedObject var usage = AIUsageManager.shared
    @Environment(\.cardSlotCount) private var cardSlotCount

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header Row: Title + Refresh Button + Settings link
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "sparkles")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.cyan)
                    Text("AI Token Usage")
                        .font(.system(size: cardSlotCount == 1 ? 12 : 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                if cardSlotCount == 1 {
                    Text("• Local Token Quotas & Live API Gauges")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                Button {
                    usage.refresh()
                } label: {
                    HStack(spacing: 3) {
                        Image(systemName: "arrow.clockwise")
                            .font(.system(size: 9))
                            .rotationEffect(.degrees(usage.isRefreshing ? 360 : 0))
                            .animation(usage.isRefreshing ? .linear(duration: 0.8).repeatForever(autoreverses: false) : .default, value: usage.isRefreshing)
                        Text(usage.isRefreshing ? "Scanning" : "Sync")
                            .font(.system(size: 8, weight: .medium))
                    }
                    .foregroundStyle(.white.opacity(0.6))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.white.opacity(0.08), in: RoundedRectangle(cornerRadius: 5, style: .continuous))
                }
                .buttonStyle(.plain)
            }

            // Cards List
            ScrollView(.vertical, showsIndicators: false) {
                if cardSlotCount == 1 {
                    // 2-Column Grid
                    LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                        ForEach(usage.providers) { provider in
                            AIProviderUsageCard(provider: provider)
                        }
                    }
                } else {
                    // Vertical Stack
                    VStack(spacing: 7) {
                        ForEach(usage.providers) { provider in
                            AIProviderUsageCard(provider: provider)
                        }
                    }
                }

                if usage.providers.isEmpty {
                    VStack(spacing: 6) {
                        Image(systemName: "cpu")
                            .font(.system(size: 16))
                            .foregroundStyle(.white.opacity(0.3))
                        Text("No AI Tools Connected")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Configure API keys or launch Antigravity to view real token analytics.")
                            .font(.system(size: 8))
                            .foregroundStyle(.white.opacity(0.4))
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod()
    }
}

// MARK: - Real Usage Card

private struct AIProviderUsageCard: View {
    let provider: AIProviderUsage

    private var accentColor: Color {
        Color(nsColor: provider.accentColor)
    }

    private func formatTokens(_ count: Int) -> String {
        if count >= 1_000_000 {
            return String(format: "%.1fM", Double(count) / 1_000_000.0)
        } else if count >= 1_000 {
            return String(format: "%.1fK", Double(count) / 1_000.0)
        } else {
            return "\(count)"
        }
    }

    private func limitColor(for percent: Double) -> Color {
        if percent >= 0.85 {
            return .red
        } else if percent >= 0.60 {
            return .orange
        } else {
            return accentColor
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            // Header: Icon + Name + Connection pill
            HStack(spacing: 5) {
                Image(systemName: provider.iconName)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(accentColor)
                Text(provider.name)
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))

                Spacer()

                if provider.isConnected {
                    HStack(spacing: 3) {
                        Circle()
                            .fill(Color.green)
                            .frame(width: 4, height: 4)
                        Text("Active")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.green.opacity(0.12), in: Capsule())
                } else {
                    Text(provider.details)
                        .font(.system(size: 7.5, weight: .medium))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            // ── Limit Gauges: 5h Session & Weekly Limits ──────────
            if provider.fiveHourUsagePercentage != nil || provider.weeklyUsagePercentage != nil {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .top, spacing: 8) {
                        // 5h Session Limit
                        if let fiveHour = provider.fiveHourUsagePercentage {
                            VStack(alignment: .leading, spacing: 2.5) {
                                HStack {
                                    Text("5h Limit")
                                        .font(.system(size: 7.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                    Spacer()
                                    Text("\(Int(fiveHour * 100))%")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(limitColor(for: fiveHour))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.12))
                                        Capsule()
                                            .fill(limitColor(for: fiveHour))
                                            .frame(width: max(0, geo.size.width * CGFloat(min(max(fiveHour, 0), 1))))
                                    }
                                }
                                .frame(height: 3)
                            }
                            .frame(maxWidth: .infinity)
                        }

                        // Weekly Limit
                        if let weekly = provider.weeklyUsagePercentage {
                            VStack(alignment: .leading, spacing: 2.5) {
                                HStack {
                                    Text("Weekly Limit")
                                        .font(.system(size: 7.5, weight: .medium))
                                        .foregroundStyle(.white.opacity(0.6))
                                    Spacer()
                                    Text("\(Int(weekly * 100))%")
                                        .font(.system(size: 8, weight: .bold, design: .monospaced))
                                        .foregroundStyle(limitColor(for: weekly))
                                }
                                GeometryReader { geo in
                                    ZStack(alignment: .leading) {
                                        Capsule().fill(Color.white.opacity(0.12))
                                        Capsule()
                                            .fill(limitColor(for: weekly))
                                            .frame(width: max(0, geo.size.width * CGFloat(min(max(weekly, 0), 1))))
                                    }
                                }
                                .frame(height: 3)
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }

                    if let desc = provider.resetTimeDescription, !desc.isEmpty {
                        HStack(spacing: 3) {
                            Image(systemName: "clock.arrow.circlepath")
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.35))
                            Text("Resets: \(desc)")
                                .font(.system(size: 7))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        .padding(.top, 1)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4.5)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }

            if provider.isConnected && provider.totalTokens > 0 {
                // Real Token Metrics Grid
                HStack(spacing: 8) {
                    // Today Tokens
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Today")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(formatTokens(provider.todayTokens))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.95))
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Week Tokens
                    VStack(alignment: .leading, spacing: 1) {
                        Text("7 Days")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Text(formatTokens(provider.weekTokens))
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(accentColor)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Total Calls
                    VStack(alignment: .trailing, spacing: 1) {
                        Text("Calls")
                            .font(.system(size: 7.5, weight: .medium))
                            .foregroundStyle(.white.opacity(0.4))
                        Text("\(provider.totalCalls)")
                            .font(.system(size: 11, weight: .bold, design: .rounded))
                            .foregroundStyle(.white.opacity(0.85))
                    }
                    .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 6, style: .continuous))

                // Bottom bar: Primary Model + Lifetime Count
                HStack {
                    Text(provider.primaryModel)
                        .font(.system(size: 8, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Text("Total: \(formatTokens(provider.totalTokens)) tok")
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(.white.opacity(0.5))
                }
            } else if provider.isConnected {
                HStack {
                    Text(provider.primaryModel)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.6))
                    Spacer()
                    Text(provider.details)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 5)
                .background(Color.white.opacity(0.03), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            } else {
                HStack {
                    Text(provider.details)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                    Spacer()
                    if provider.id == "kimi" {
                        Button("API Key") {
                            SettingsWindowController.shared.show()
                        }
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(accentColor)
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 4)
                .background(Color.white.opacity(0.02), in: RoundedRectangle(cornerRadius: 6, style: .continuous))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(Color.white.opacity(0.04), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
