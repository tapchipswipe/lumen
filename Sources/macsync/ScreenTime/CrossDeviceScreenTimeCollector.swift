import Foundation
import AppKit

public struct CrossDeviceAppUsage: Identifiable, Codable {
    public let id: UUID
    public let bundleIdentifier: String
    public let appName: String
    public let deviceName: String
    public let totalMinutes: Int
    public let category: String
    public let lastActive: Date

    public init(id: UUID = UUID(), bundleIdentifier: String, appName: String, deviceName: String = "iPhone", totalMinutes: Int, category: String = "General", lastActive: Date = Date()) {
        self.id = id
        self.bundleIdentifier = bundleIdentifier
        self.appName = appName
        self.deviceName = deviceName
        self.totalMinutes = totalMinutes
        self.category = category
        self.lastActive = lastActive
    }
}

public struct CrossDeviceScreenTimeReport: Codable {
    public let mobileFocusMinutes: Int
    public let desktopFocusMinutes: Int
    public let topMobileApps: [CrossDeviceAppUsage]
    public let appleMusicMobileMinutes: Int
    public let summary: String

    public static let empty = CrossDeviceScreenTimeReport(
        mobileFocusMinutes: 0,
        desktopFocusMinutes: 0,
        topMobileApps: [],
        appleMusicMobileMinutes: 0,
        summary: "No synced cross-device Screen Time data available."
    )
}

public final class CrossDeviceScreenTimeCollector {
    public static let shared = CrossDeviceScreenTimeCollector()

    private let queue = DispatchQueue(label: "com.lumen.screentime", qos: .utility)
    private var timer: Timer?

    public func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 900.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    public func stop() {
        timer?.invalidate()
        timer = nil
    }

    public func poll() {
        queue.async {
            _ = self.generateReport()
        }
    }

    /// Reads synced Screen Time and Cloud Music streams to generate cross-device usage breakdown.
    public func generateReport() -> CrossDeviceScreenTimeReport {
        let home = NSHomeDirectory()
        let fm = FileManager.default
        var mobileApps: [CrossDeviceAppUsage] = []
        var musicMobileMins = 0

        // 1. Check synced Apple Music cloud listening
        let syncedTracks = AppleMusicCloudSyncEngine.fetchCrossDeviceMusicHistory(limit: 20)
        let totalPlays = syncedTracks.reduce(0) { $0 + $1.playCount }
        let estimatedMusicMinutes = totalPlays * 3

        if estimatedMusicMinutes > 0 {
            musicMobileMins = estimatedMusicMinutes
            mobileApps.append(CrossDeviceAppUsage(
                bundleIdentifier: "com.apple.Music",
                appName: "Apple Music",
                deviceName: "iPhone / AirPods",
                totalMinutes: estimatedMusicMinutes,
                category: "Audio & Flow"
            ))
        }

        // 2. Scan Biome / Screen Time InFocus stream if FDA is available
        let biomeInFocusPath = "\(home)/Library/Biome/streams/restricted/App.InFocus"
        if fm.fileExists(atPath: biomeInFocusPath), let files = try? fm.contentsOfDirectory(atPath: biomeInFocusPath) {
            var safariCount = 0
            var messageCount = 0
            for file in files.prefix(30) {
                if file.contains("safari") || file.contains("Safari") { safariCount += 1 }
                if file.contains("chat") || file.contains("sms") || file.contains("MobileSMS") { messageCount += 1 }
            }

            if safariCount > 0 {
                mobileApps.append(CrossDeviceAppUsage(
                    bundleIdentifier: "com.apple.mobilesafari",
                    appName: "Mobile Safari",
                    deviceName: "iPhone",
                    totalMinutes: safariCount * 5,
                    category: "Browsing"
                ))
            }
            if messageCount > 0 {
                mobileApps.append(CrossDeviceAppUsage(
                    bundleIdentifier: "com.apple.MobileSMS",
                    appName: "Messages",
                    deviceName: "iPhone",
                    totalMinutes: messageCount * 3,
                    category: "Communication"
                ))
            }
        }

        mobileApps.sort(by: { $0.totalMinutes > $1.totalMinutes })
        let totalMobile = mobileApps.reduce(0) { $0 + $1.totalMinutes }

        let summary = totalMobile > 0
            ? "iPhone Screen Time synced: \(totalMobile)m mobile activity (\(musicMobileMins)m Apple Music)."
            : "No active cross-device screen time sessions detected."

        return CrossDeviceScreenTimeReport(
            mobileFocusMinutes: totalMobile,
            desktopFocusMinutes: 0,
            topMobileApps: mobileApps,
            appleMusicMobileMinutes: musicMobileMins,
            summary: summary
        )
    }
}
