import Foundation
import IOKit.ps
import Darwin

/// Periodic hardware sampler: battery (IOKit), CPU load (host_processor_info),
/// memory (host_statistics64), network throughput (getifaddrs deltas).
final class HardwareMonitor {
    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.lumen.hardware", qos: .utility)
    private var timer: DispatchSourceTimer?

    private var previousCPUTicks: (user: UInt64, system: UInt64, idle: UInt64, nice: UInt64)?
    private var previousNet: (bytesIn: UInt64, bytesOut: UInt64, at: Date)?

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 30, repeating: 30.0)
        timer.setEventHandler { [weak self] in self?.sample() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
    }

    // MARK: - Sampling

    private func sample() {
        let now = Date()
        let battery = Self.readBattery()
        let cpu = readCPULoad()
        let memory = Self.readMemory()
        let net = readNetwork()

        let payload = HardwareStatusPayload(
            observedAt: now,
            batteryPercent: battery.percent,
            batteryCharging: battery.charging,
            onBattery: battery.onBattery,
            timeRemainingMinutes: battery.timeRemaining,
            cpuLoadPercent: cpu,
            memoryUsedBytes: memory.used,
            memoryTotalBytes: memory.total,
            memoryPressurePercent: memory.pressurePercent,
            networkBytesInPerSec: net.inPerSec,
            networkBytesOutPerSec: net.outPerSec,
            primaryInterface: net.interface
        )
        store.append(TrackerEvent(ts: now, kind: .hardwareStatus, payload: .hardwareStatus(payload)))
    }

    // MARK: - Battery (nil-safe on desktops)

    private struct BatteryInfo {
        var percent: Int?
        var charging: Bool?
        var onBattery: Bool?
        var timeRemaining: Int?
    }

    private static func readBattery() -> BatteryInfo {
        var info = BatteryInfo()
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
              let sources = IOPSCopyPowerSourcesList(snapshot)?.takeRetainedValue() as? [CFTypeRef] else {
            return info
        }
        for source in sources {
            guard let desc = IOPSGetPowerSourceDescription(snapshot, source)?.takeUnretainedValue() as? [String: Any],
                  let type = desc[kIOPSTypeKey] as? String, type == kIOPSInternalBatteryType else { continue }
            info.percent = desc[kIOPSCurrentCapacityKey] as? Int
            info.charging = desc[kIOPSIsChargingKey] as? Bool
            if let sourceState = desc[kIOPSPowerSourceStateKey] as? String {
                info.onBattery = (sourceState == kIOPSBatteryPowerValue)
            }
            if let remaining = desc[kIOPSTimeToEmptyKey] as? Int, remaining >= 0 {
                info.timeRemaining = remaining
            }
        }
        return info
    }


    // MARK: - CPU (delta of host_processor_info ticks)

    private func readCPULoad() -> Double {
        var numCPUs: natural_t = 0
        var cpuInfo: processor_info_array_t?
        var numCPUInfo: mach_msg_type_number_t = 0

        let result = host_processor_info(mach_host_self(), PROCESSOR_CPU_LOAD_INFO, &numCPUs, &cpuInfo, &numCPUInfo)
        guard result == KERN_SUCCESS, let info = cpuInfo else { return 0 }
        defer {
            let size = vm_size_t(numCPUInfo) * vm_size_t(MemoryLayout<integer_t>.stride)
            vm_deallocate(mach_task_self_, vm_address_t(bitPattern: info), size)
        }

        var user: UInt64 = 0, system: UInt64 = 0, idle: UInt64 = 0, nice: UInt64 = 0
        let stride = MemoryLayout<processor_cpu_load_info>.stride / MemoryLayout<integer_t>.stride
        for i in 0..<Int(numCPUs) {
            let base = i * stride
            user   += UInt64(info[base + Int(CPU_STATE_USER)])
            system += UInt64(info[base + Int(CPU_STATE_SYSTEM)])
            idle   += UInt64(info[base + Int(CPU_STATE_IDLE)])
            nice   += UInt64(info[base + Int(CPU_STATE_NICE)])
        }

        guard let prev = previousCPUTicks else {
            previousCPUTicks = (user, system, idle, nice)
            return 0
        }
        previousCPUTicks = (user, system, idle, nice)

        let dUser = user - prev.user
        let dSystem = system - prev.system
        let dIdle = idle - prev.idle
        let dNice = nice - prev.nice
        let total = dUser + dSystem + dIdle + dNice
        guard total > 0 else { return 0 }
        return Double(dUser + dSystem + dNice) / Double(total) * 100.0
    }

    // MARK: - Memory (host_statistics64)

    private static func readMemory() -> (used: UInt64, total: UInt64, pressurePercent: Double) {
        let total = ProcessInfo.processInfo.physicalMemory
        var stats = vm_statistics64()
        var count = mach_msg_type_number_t(MemoryLayout<vm_statistics64>.stride / MemoryLayout<integer_t>.stride)
        let result = withUnsafeMutablePointer(to: &stats) { ptr in
            ptr.withMemoryRebound(to: integer_t.self, capacity: Int(count)) { intPtr in
                host_statistics64(mach_host_self(), HOST_VM_INFO64, intPtr, &count)
            }
        }
        guard result == KERN_SUCCESS else { return (0, total, 0) }
        let pageSize = UInt64(vm_kernel_page_size)
        let active = UInt64(stats.active_count) * pageSize
        let wired = UInt64(stats.wire_count) * pageSize
        let compressed = UInt64(stats.compressor_page_count) * pageSize
        let used = active + wired + compressed
        let pressure = total > 0 ? Double(used) / Double(total) * 100.0 : 0
        return (used, total, pressure)
    }

    // MARK: - Network (getifaddrs byte deltas)

    private func readNetwork() -> (inPerSec: UInt64, outPerSec: UInt64, interface: String?) {
        var addrs: UnsafeMutablePointer<ifaddrs>?
        guard getifaddrs(&addrs) == 0, let first = addrs else {
            return (0, 0, nil)
        }
        defer { freeifaddrs(first) }

        var totalIn: UInt64 = 0
        var totalOut: UInt64 = 0
        var primary: String?

        var current: UnsafeMutablePointer<ifaddrs>? = first
        while let iface = current {
            let name = String(cString: iface.pointee.ifa_name)
            // Count physical interfaces only; skip loopback.
            if name != "lo0", let data = iface.pointee.ifa_data {
                let networkData = data.assumingMemoryBound(to: if_data.self).pointee
                totalIn += UInt64(networkData.ifi_ibytes)
                totalOut += UInt64(networkData.ifi_obytes)
                if primary == nil, name.hasPrefix("en") {
                    primary = name
                }
            }
            current = iface.pointee.ifa_next
        }

        let now = Date()
        defer { previousNet = (totalIn, totalOut, now) }
        guard let prev = previousNet else { return (0, 0, primary) }
        let elapsed = now.timeIntervalSince(prev.at)
        guard elapsed > 0 else { return (0, 0, primary) }
        let inPerSec = totalIn >= prev.bytesIn ? UInt64(Double(totalIn - prev.bytesIn) / elapsed) : 0
        let outPerSec = totalOut >= prev.bytesOut ? UInt64(Double(totalOut - prev.bytesOut) / elapsed) : 0
        return (inPerSec, outPerSec, primary)
    }
}
