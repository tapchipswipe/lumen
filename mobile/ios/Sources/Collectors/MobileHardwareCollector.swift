import Foundation
import UIKit

/// Energy-aware hardware monitor.
/// Suppresses active timers when in background to prevent iOS watchdog termination.
public final class MobileHardwareCollector {
    public static let shared = MobileHardwareCollector()
    private var foregroundTimer: Timer?

    private init() {
        UIDevice.current.isBatteryMonitoringEnabled = true
    }

    public func start() {
        sampleHardware()
        resumeForegroundSampling()
    }

    public func stop() {
        pauseSampling()
    }

    public func resumeForegroundSampling() {
        foregroundTimer?.invalidate()
        // 5-minute sampling while user is actively in the app
        foregroundTimer = Timer.scheduledTimer(withTimeInterval: 300, repeats: true) { [weak self] _ in
            self?.sampleHardware()
        }
    }

    public func pauseSampling() {
        foregroundTimer?.invalidate()
        foregroundTimer = nil
    }

    public func sampleHardware() {
        let batteryLevel = Int(UIDevice.current.batteryLevel * 100)
        let stateStr: String
        switch UIDevice.current.batteryState {
        case .charging: stateStr = "charging"
        case .full: stateStr = "full"
        case .unplugged: stateStr = "unplugged"
        case .unknown: stateStr = "unknown"
        @unknown default: stateStr = "unknown"
        }

        let isLowPower = ProcessInfo.processInfo.isLowPowerModeEnabled
        let thermalStr: String
        switch ProcessInfo.processInfo.thermalState {
        case .nominal: thermalStr = "nominal"
        case .fair: thermalStr = "fair"
        case .serious: thermalStr = "serious"
        case .critical: thermalStr = "critical"
        @unknown default: thermalStr = "unknown"
        }

        let brightness = Double(UIScreen.main.brightness)
        let freeDisk = Double(getFreeDiskSpaceGB())

        let payload = MobileHardwarePayload(
            observedAt: Date(),
            batteryLevelPercent: batteryLevel >= 0 ? batteryLevel : 100,
            batteryState: stateStr,
            isLowPowerMode: isLowPower,
            thermalState: thermalStr,
            screenBrightness: brightness,
            freeDiskSpaceGB: freeDisk
        )

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .hardwareStatus,
            payload: .hardwareStatus(payload)
        ))
    }

    private func getFreeDiskSpaceGB() -> Double {
        if let attributes = try? FileManager.default.attributesOfFileSystem(forPath: NSHomeDirectory()),
           let freeSize = attributes[.systemFreeSize] as? NSNumber {
            return Double(freeSize.int64Value) / (1024 * 1024 * 1024)
        }
        return 0.0
    }
}
