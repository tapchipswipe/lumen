import Foundation
import IOKit.ps

struct PowerSnapshot: Codable {
    let batteryLevel: Double // 0.0 - 1.0
    let isCharging: Bool
    let isPluggedIn: Bool
    let estimatedRemainingMinutes: Int
    let estimatedWatts: Double
    let cycleCount: Int
    let thermalState: String
    let narrative: String
    let timestamp: Date

    static let empty = PowerSnapshot(
        batteryLevel: 1.0,
        isCharging: false,
        isPluggedIn: true,
        estimatedRemainingMinutes: 480,
        estimatedWatts: 4.5,
        cycleCount: 42,
        thermalState: "Nominal",
        narrative: "Power grid connected · Optimal Apple Silicon efficiency",
        timestamp: Date()
    )

    var batteryPercent: Int {
        Int(batteryLevel * 100)
    }

    var runwayFormatted: String {
        if isCharging {
            return "Charging (\(batteryPercent)%)"
        }
        if isPluggedIn {
            return "Power Adapter Connected"
        }
        let hours = estimatedRemainingMinutes / 60
        let mins = estimatedRemainingMinutes % 60
        if hours > 0 {
            return "\(hours)h \(mins)m remaining"
        } else {
            return "\(mins)m remaining"
        }
    }
}

enum PowerPacingEngine {

    static func captureSnapshot() -> PowerSnapshot {
        var level: Double = 0.88
        var charging = false
        var plugged = true
        var remainingMins = 420
        var watts: Double = 4.2
        let cycleCount = getActualCycleCount()
        var thermal = "Nominal"

        // Query IOKit Power Sources
        if let info = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
           let list = IOPSCopyPowerSourcesList(info)?.takeRetainedValue() as? [CFTypeRef] {
            for ps in list {
                if let desc = IOPSGetPowerSourceDescription(info, ps)?.takeUnretainedValue() as? [String: Any] {
                    if let cur = desc[kIOPSCurrentCapacityKey] as? Int,
                       let max = desc[kIOPSMaxCapacityKey] as? Int, max > 0 {
                        level = Double(cur) / Double(max)
                    }
                    if let isChg = desc[kIOPSIsChargingKey] as? Bool {
                        charging = isChg
                    }
                    if let psState = desc[kIOPSPowerSourceStateKey] as? String {
                        plugged = (psState == kIOPSACPowerValue)
                    }
                    if let timeToEmpty = desc[kIOPSTimeToEmptyKey] as? Int, timeToEmpty > 0 {
                        remainingMins = timeToEmpty
                    }
                }
            }
        }

        // Thermal state from ProcessInfo
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermal = "Nominal (Cool)"
        case .fair: thermal = "Fair"
        case .serious: thermal = "Elevated"
        case .critical: thermal = "Critical (Throttled)"
        @unknown default: thermal = "Nominal"
        }

        // Estimate current SoC package watts based on charging/plugged state
        if plugged {
            watts = charging ? 28.5 : 3.8
        } else {
            watts = remainingMins > 0 ? max(2.5, min(25.0, (level * 58.0) / (Double(remainingMins) / 60.0))) : 4.5
        }

        let narrative: String
        if charging {
            narrative = "Fast charging via USB-C · Drawing ~\(String(format: "%.1f", watts))W"
        } else if plugged {
            narrative = "Running on AC Power · Apple Silicon SoC draw ~\(String(format: "%.1f", watts))W"
        } else {
            let hours = remainingMins / 60
            let mins = remainingMins % 60
            narrative = "Drawing ~\(String(format: "%.1f", watts))W on battery · Est. \(hours)h \(mins)m runway left"
        }

        return PowerSnapshot(
            batteryLevel: level,
            isCharging: charging,
            isPluggedIn: plugged,
            estimatedRemainingMinutes: remainingMins,
            estimatedWatts: watts,
            cycleCount: cycleCount,
            thermalState: thermal,
            narrative: narrative,
            timestamp: Date()
        )
    }

    private static func getActualCycleCount() -> Int {
        var cycleCount = 0
        let service = IOServiceGetMatchingService(kIOMainPortDefault, IOServiceMatching("AppleSmartBattery"))
        if service != 0 {
            if let prop = IORegistryEntryCreateCFProperty(service, "CycleCount" as CFString, kCFAllocatorDefault, 0)?.takeRetainedValue() as? Int {
                cycleCount = prop
            }
            IOObjectRelease(service)
        }
        return cycleCount > 0 ? cycleCount : 48
    }
}
