import Foundation
import SwiftUI
import BackgroundTasks
import UIKit

@MainActor
public final class MobileAppState: ObservableObject {
    public static let shared = MobileAppState()

    @Published public var isTracking: Bool = true
    @Published public var todayEventsCount: Int = 0
    @Published public var todaySteps: Int = 0
    @Published public var currentHeartRate: Double? = nil
    @Published public var activeActivity: String = "Stationary"
    @Published public var currentRadio: String = "Wi-Fi"
    @Published public var audioOutput: String = "AirPods Pro"
    @Published public var batteryPercent: Int = 100
    @Published public var isCharging: Bool = false
    @Published public var lastSyncStatus: String = "Local Buffer Active"

    // Crash Log Inspection
    @Published public var pendingCrashLog: String? = nil
    @Published public var showCrashLogModal: Bool = false

    public static let bgRefreshTaskIdentifier = "com.lumen.mobile.refresh"
    public static let bgProcessingTaskIdentifier = "com.lumen.mobile.processing"

    private init() {
        self.todayEventsCount = MobileDataStore.shared.todayEventCount
        MobileDataStore.shared.onEventsUpdated = { [weak self] in
            guard let self = self else { return }
            self.todayEventsCount = MobileDataStore.shared.todayEventCount
            self.todaySteps = HealthKitCollector.shared.latestSteps > 0 ? HealthKitCollector.shared.latestSteps : MotionCollector.shared.todaySteps
            self.currentHeartRate = HealthKitCollector.shared.latestHeartRate
            self.activeActivity = MotionCollector.shared.currentActivity
            self.currentRadio = CellularNetworkCollector.shared.currentRadioType
            self.audioOutput = MobileAudioRouteCollector.shared.activeOutputName
            self.batteryPercent = Int(UIDevice.current.batteryLevel >= 0 ? UIDevice.current.batteryLevel * 100 : 100)
            self.isCharging = UIDevice.current.batteryState == .charging || UIDevice.current.batteryState == .full
        }

        // Check for prior crash logs
        if CrashReporter.shared.hasPendingCrashLog(), let log = CrashReporter.shared.readCrashLog() {
            self.pendingCrashLog = log
            self.showCrashLogModal = true
        }
    }

    public func startAllCollectors() {
        CrashReporter.shared.install()
        isTracking = true
        MotionCollector.shared.start()
        MobileLocationCollector.shared.requestPermissions()
        MobileLocationCollector.shared.start()
        MobileHardwareCollector.shared.start()
        CellularNetworkCollector.shared.start()
        MobileAudioRouteCollector.shared.start()
        
        HealthKitCollector.shared.requestAuthorization { [weak self] success in
            if success {
                HealthKitCollector.shared.sampleHealthMetrics()
                DispatchQueue.main.async {
                    self?.todaySteps = HealthKitCollector.shared.latestSteps
                    self?.currentHeartRate = HealthKitCollector.shared.latestHeartRate
                }
            }
        }

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .appLifecycle,
            payload: .appLifecycle(MobileLifecyclePayload(observedAt: Date(), event: "didLaunch"))
        ))
    }

    public func stopAllCollectors() {
        isTracking = false
        MotionCollector.shared.stop()
        MobileLocationCollector.shared.stop()
        MobileHardwareCollector.shared.stop()
        CellularNetworkCollector.shared.stop()
        MobileAudioRouteCollector.shared.stop()
        MobileDataStore.shared.flush()
    }

    public func flushBufferNow() {
        MobileDataStore.shared.flush()
        lastSyncStatus = "Buffer Flushed to Disk"
    }

    public func handleEnteringBackground() {
        MobileLocationCollector.shared.setBackgroundMode(true)
        MobileHardwareCollector.shared.pauseSampling()
        MobileDataStore.shared.flush()
        scheduleBackgroundTasks()

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .appLifecycle,
            payload: .appLifecycle(MobileLifecyclePayload(observedAt: Date(), event: "didEnterBackground"))
        ))
    }

    public func handleEnteringForeground() {
        MobileLocationCollector.shared.setBackgroundMode(false)
        MobileHardwareCollector.shared.resumeForegroundSampling()
        MobileAudioRouteCollector.shared.sampleRoute()
        HealthKitCollector.shared.sampleHealthMetrics()

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .appLifecycle,
            payload: .appLifecycle(MobileLifecyclePayload(observedAt: Date(), event: "willEnterForeground"))
        ))
    }

    public func triggerManualSync() {
        lastSyncStatus = "Syncing..."
        let success = MobileDataStore.shared.syncToCloudOrDesktopContainer()
        lastSyncStatus = success ? "Saved to Exports Folder" : "Buffered locally"
    }

    public func dismissCrashLog() {
        CrashReporter.shared.clearCrashLog()
        pendingCrashLog = nil
        showCrashLogModal = false
    }

    public func scheduleBackgroundTasks() {
        BGTaskScheduler.shared.cancelAllTaskRequests()
        let request = BGAppRefreshTaskRequest(identifier: Self.bgRefreshTaskIdentifier)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 20 * 60)
        try? BGTaskScheduler.shared.submit(request)
    }
}
