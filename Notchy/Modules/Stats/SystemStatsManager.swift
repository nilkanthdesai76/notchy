//
//  SystemStatsManager.swift
//  Notchy
//
//  Monitors CPU usage, memory pressure, and live network throughput.
//

import AppKit
import Combine
import Foundation
import IOKit.ps

@MainActor
final class SystemStatsManager: ObservableObject {
    static let shared = SystemStatsManager()

    @Published var cpuUsage: Double = 0.0
    @Published var memoryUsedGB: Double = 0.0
    @Published var memoryTotalGB: Double = 0.0
    @Published var memoryPercentage: Double = 0.0
    @Published var netDownloadSpeed: String = "0 KB/s"
    @Published var netUploadSpeed: String = "0 KB/s"
    @Published var batteryPercentage: Int = 100
    @Published var isCharging: Bool = false

    private var timer: AnyCancellable?
    private var prevCpuInfo: processor_info_array_t?
    private var prevCpuInfoCount: mach_msg_type_number_t = 0
    private var numCPUs: natural_t = 0
    private var prevBytesIn: UInt64 = 0
    private var prevBytesOut: UInt64 = 0
    private var prevNetTime: Date = Date()

    init() {
        let mib = [CTL_HW, HW_NCPU]
        var sizeOfNumCPUs = MemoryLayout<natural_t>.size
        sysctl(UnsafeMutablePointer(mutating: mib), 2, &numCPUs, &sizeOfNumCPUs, nil, 0)
        startMonitoring()
    }

    func startMonitoring() {
        updateStats()
        timer = Timer.publish(every: 2.0, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateStats()
            }
    }

    func stopMonitoring() {
        timer?.cancel()
    }

    private func updateStats() {
        updateCPU()
        updateMemory()
        updateNetwork()
        updateBattery()
    }

    private func updateCPU() {
        var numCPUsU: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCpuInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(
            mach_host_self(),
            PROCESSOR_CPU_LOAD_INFO,
            &numCPUsU,
            &cpuInfo,
            &numCpuInfo
        )

        guard result == KERN_SUCCESS, let cpuInfo = cpuInfo else { return }

        if let prevCpuInfo = prevCpuInfo {
            var totalUser: UInt64 = 0
            var totalSystem: UInt64 = 0
            var totalIdle: UInt64 = 0
            var totalNice: UInt64 = 0

            for i in 0..<Int(numCPUsU) {
                let offset = Int(CPU_STATE_MAX) * i
                let user = UInt64(cpuInfo[offset + Int(CPU_STATE_USER)] - prevCpuInfo[offset + Int(CPU_STATE_USER)])
                let system = UInt64(cpuInfo[offset + Int(CPU_STATE_SYSTEM)] - prevCpuInfo[offset + Int(CPU_STATE_SYSTEM)])
                let idle = UInt64(cpuInfo[offset + Int(CPU_STATE_IDLE)] - prevCpuInfo[offset + Int(CPU_STATE_IDLE)])
                let nice = UInt64(cpuInfo[offset + Int(CPU_STATE_NICE)] - prevCpuInfo[offset + Int(CPU_STATE_NICE)])

                totalUser += user
                totalSystem += system
                totalIdle += idle
                totalNice += nice
            }

            let totalTicks = totalUser + totalSystem + totalIdle + totalNice
            if totalTicks > 0 {
                let usage = Double(totalUser + totalSystem + totalNice) / Double(totalTicks)
                self.cpuUsage = min(max(usage, 0.0), 1.0)
            }

            let prevCpuInfoSize = MemoryLayout<integer_t>.size * Int(prevCpuInfoCount)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: prevCpuInfo), vm_size_t(prevCpuInfoSize))
        }

        self.prevCpuInfo = cpuInfo
        self.prevCpuInfoCount = numCpuInfo
    }

    private func updateMemory() {
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64_data_t>.size / MemoryLayout<integer_t>.size)

        let result = withUnsafeMutablePointer(to: &stats) {
            $0.withMemoryRebound(to: integer_t.self, capacity: Int(count)) {
                host_statistics64(mach_host_self(), HOST_VM_INFO64, $0, &count)
            }
        }

        if result == KERN_SUCCESS {
            let pageSize = UInt64(vm_kernel_page_size)
            let active = UInt64(stats.active_count) * pageSize
            let wired = UInt64(stats.wire_count) * pageSize
            let compressed = UInt64(stats.compressor_page_count) * pageSize
            let usedBytes = active + wired + compressed
            let totalBytes = ProcessInfo.processInfo.physicalMemory

            let usedGB = Double(usedBytes) / 1_073_741_824.0
            let totalGB = Double(totalBytes) / 1_073_741_824.0

            self.memoryUsedGB = usedGB
            self.memoryTotalGB = totalGB
            self.memoryPercentage = totalGB > 0 ? (usedGB / totalGB) : 0
        }
    }

    private func updateNetwork() {
        var ifaddr: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&ifaddr) == 0, let firstAddr = ifaddr else { return }
        defer { freeifaddrs(ifaddr) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0

        for cursor in sequence(first: firstAddr, next: { $0.pointee.ifa_next }) {
            let flags = Int32(cursor.pointee.ifa_flags)
            if (flags & IFF_UP) == 0 || (flags & IFF_LOOPBACK) != 0 { continue }
            guard let data = cursor.pointee.ifa_data else { continue }
            let ifData = data.assumingMemoryBound(to: if_data.self)
            totalIn += UInt64(ifData.pointee.ifi_ibytes)
            totalOut += UInt64(ifData.pointee.ifi_obytes)
        }

        let now = Date()
        let interval = now.timeIntervalSince(prevNetTime)
        if interval > 0 && prevBytesIn > 0 {
            let speedIn = Double(totalIn > prevBytesIn ? totalIn - prevBytesIn : 0) / interval
            let speedOut = Double(totalOut > prevBytesOut ? totalOut - prevBytesOut : 0) / interval

            self.netDownloadSpeed = formatSpeed(speedIn)
            self.netUploadSpeed = formatSpeed(speedOut)
        }

        prevBytesIn = totalIn
        prevBytesOut = totalOut
        prevNetTime = now
    }

    private func updateBattery() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [[String: Any]],
              let source = sources.first else { return }

        if let current = source[kIOPSCurrentCapacityKey as String] as? Int,
           let max = source[kIOPSMaxCapacityKey as String] as? Int, max > 0 {
            self.batteryPercentage = Int((Double(current) / Double(max)) * 100)
        }
        if let state = source[kIOPSPowerSourceStateKey as String] as? String {
            self.isCharging = state == (kIOPSACPowerValue as String)
        }
    }

    private func formatSpeed(_ bytesPerSec: Double) -> String {
        if bytesPerSec >= 1_048_576 {
            return String(format: "%.1f MB/s", bytesPerSec / 1_048_576.0)
        } else {
            return String(format: "%.0f KB/s", bytesPerSec / 1024.0)
        }
    }
}
