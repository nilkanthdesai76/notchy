//
//  StatsAndToolsView.swift
//  Notchy
//
//  System metrics (CPU, RAM, Net, Battery) and Quick Tools (Caffeinate, Eyedropper).
//

import SwiftUI
import Combine

struct StatsAndToolsView: View {
    @ObservedObject var stats = SystemStatsManager.shared
    @ObservedObject var tools = QuickToolsManager.shared
    @Environment(\.cardSlotCount) private var cardSlotCount

    var body: some View {
        VStack(alignment: .leading, spacing: cardSlotCount == 1 ? 9 : 8) {
            // Header Row: Title + Battery
            HStack {
                HStack(spacing: 5) {
                    Image(systemName: "cpu.fill")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.orange)
                    Text("System & Tools")
                        .font(.system(size: cardSlotCount == 1 ? 12 : 11, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.85))
                }

                if cardSlotCount == 1 {
                    Text("• Live Apple Silicon Diagnostics")
                        .font(.system(size: 9))
                        .foregroundStyle(.white.opacity(0.45))
                }

                Spacer()

                HStack(spacing: 4) {
                    Image(systemName: stats.isCharging ? "battery.100.bolt" : "battery.75")
                        .font(.system(size: 10))
                        .foregroundStyle(stats.batteryPercentage <= 20 ? .red : (stats.isCharging ? .green : .white.opacity(0.7)))
                    Text("\(stats.batteryPercentage)%")
                        .font(.system(size: 9, weight: .medium, design: .monospaced))
                        .foregroundStyle(.white.opacity(0.7))
                }
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(Color.white.opacity(0.08), in: Capsule())
            }

            if cardSlotCount == 1 {
                // Wide 4-Column Layout
                HStack(spacing: 8) {
                    MetricCard(
                        icon: "gauge.with.needle.fill",
                        title: "CPU",
                        value: "\(Int(stats.cpuUsage * 100))%",
                        progress: stats.cpuUsage,
                        color: stats.cpuUsage > 0.8 ? .red : (stats.cpuUsage > 0.5 ? .orange : .blue)
                    )

                    MetricCard(
                        icon: "memorychip",
                        title: "RAM",
                        value: String(format: "%.1f GB", stats.memoryUsedGB),
                        subtitle: String(format: "/ %.0f GB", stats.memoryTotalGB),
                        progress: stats.memoryPercentage,
                        color: stats.memoryPercentage > 0.85 ? .red : .purple
                    )

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.teal)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("DOWNLOAD")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(stats.netDownloadSpeed)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))

                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.circle.fill")
                            .font(.system(size: 14))
                            .foregroundStyle(.indigo)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("UPLOAD")
                                .font(.system(size: 7.5, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            Text(stats.netUploadSpeed)
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundStyle(.white.opacity(0.9))
                        }
                    }
                    .padding(8)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            } else {
                // 2x2 Compact Stats Grid
                VStack(spacing: 6) {
                    HStack(spacing: 6) {
                        MetricCard(
                            icon: "gauge.with.needle.fill",
                            title: "CPU",
                            value: "\(Int(stats.cpuUsage * 100))%",
                            progress: stats.cpuUsage,
                            color: stats.cpuUsage > 0.8 ? .red : (stats.cpuUsage > 0.5 ? .orange : .blue)
                        )

                        MetricCard(
                            icon: "memorychip",
                            title: "RAM",
                            value: String(format: "%.1f GB", stats.memoryUsedGB),
                            subtitle: String(format: "/ %.0f GB", stats.memoryTotalGB),
                            progress: stats.memoryPercentage,
                            color: stats.memoryPercentage > 0.85 ? .red : .purple
                        )
                    }

                    HStack(spacing: 6) {
                        Image(systemName: "network")
                            .font(.system(size: 10))
                            .foregroundStyle(.teal.opacity(0.8))
                        VStack(alignment: .leading, spacing: 1) {
                            Text("NET")
                                .font(.system(size: 8, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.4))
                            HStack(spacing: 6) {
                                Text("↓ \(stats.netDownloadSpeed)")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.85))
                                Text("↑ \(stats.netUploadSpeed)")
                                    .font(.system(size: 8, weight: .medium, design: .monospaced))
                                    .foregroundStyle(.white.opacity(0.5))
                            }
                            .lineLimit(1)
                        }
                        Spacer()
                    }
                    .padding(6)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
                }
            }

            // Quick Tools Bar
            HStack(spacing: 8) {
                // Caffeinate Button
                Button {
                    tools.toggleCaffeinate()
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: tools.isCaffeinated ? "cup.and.saucer.fill" : "cup.and.saucer")
                            .font(.system(size: 10))
                        Text(tools.isCaffeinated ? "Awake On" : "Caffeinate")
                            .font(.system(size: 9, weight: .semibold))
                    }
                    .foregroundStyle(tools.isCaffeinated ? .orange : .white.opacity(0.8))
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        tools.isCaffeinated ? Color.orange.opacity(0.2) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tools.isCaffeinated ? Color.orange.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Color Picker Button
                Button {
                    tools.pickScreenColor()
                } label: {
                    HStack(spacing: 5) {
                        if tools.pickedColorFeedback, let hex = tools.lastPickedHex {
                            if let nsCol = tools.lastPickedColor {
                                Circle()
                                    .fill(Color(nsColor: nsCol))
                                    .frame(width: 8, height: 8)
                                    .overlay(Circle().strokeBorder(Color.white.opacity(0.3), lineWidth: 0.5))
                            }
                            Text(hex)
                                .font(.system(size: 8.5, weight: .bold, design: .monospaced))
                                .foregroundStyle(.green)
                        } else {
                            Image(systemName: "eyedropper.halffull")
                                .font(.system(size: 10))
                            Text("Eyedropper")
                                .font(.system(size: 9, weight: .semibold))
                                .foregroundStyle(.white.opacity(0.8))
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 5)
                    .frame(maxWidth: .infinity)
                    .background(
                        tools.pickedColorFeedback ? Color.green.opacity(0.2) : Color.white.opacity(0.08),
                        in: RoundedRectangle(cornerRadius: 8, style: .continuous)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .strokeBorder(tools.pickedColorFeedback ? Color.green.opacity(0.5) : Color.clear, lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
                .help("Sample any color from your screen and copy HEX to clipboard")
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .liquidGlassPod()
    }
}

private struct MetricCard: View {
    let icon: String
    let title: String
    let value: String
    var subtitle: String? = nil
    let progress: Double
    let color: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack {
                Image(systemName: icon)
                    .font(.system(size: 9))
                    .foregroundStyle(color)
                Text(title)
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.4))
                Spacer()
                Text(value)
                    .font(.system(size: 9, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white.opacity(0.9))
                if let subtitle = subtitle {
                    Text(subtitle)
                        .font(.system(size: 8))
                        .foregroundStyle(.white.opacity(0.4))
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(Color.white.opacity(0.1))
                    Capsule()
                        .fill(color)
                        .frame(width: max(0, geo.size.width * CGFloat(min(max(progress, 0), 1))))
                }
            }
            .frame(height: 3)
        }
        .padding(6)
        .frame(maxWidth: .infinity)
        .background(Color.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 8, style: .continuous))
    }
}
