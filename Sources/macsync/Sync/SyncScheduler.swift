import Foundation

final class SyncScheduler {
    static let defaultSyncHour = 23
    static let defaultSyncMinute = 59

    private let syncEngine: iCloudSync
    private var dailyTimer: Timer?
    private var backgroundActivity: NSBackgroundActivityScheduler?

    var onSyncFired: (() -> Void)?
    var onCatchUpSynced: ((Int) -> Void)?
    private(set) var nextScheduledSync: Date?

    init(syncEngine: iCloudSync) { self.syncEngine = syncEngine }

    func start() {
        scheduleDailyTimer()
        installBackgroundActivity()
    }

    func stop() {
        dailyTimer?.invalidate(); dailyTimer = nil
        backgroundActivity?.invalidate(); backgroundActivity = nil
    }

    private func scheduleDailyTimer() {
        dailyTimer?.invalidate()
        let next = Self.nextSyncDate(from: Date())
        nextScheduledSync = next
        let timer = Timer(fire: next, interval: 0, repeats: false) { [weak self] _ in
            self?.fireDailySync()
        }
        RunLoop.main.add(timer, forMode: .common)
        dailyTimer = timer
        Log.sync.info("Next daily sync scheduled for \(next, privacy: .public)")
    }

    static func nextSyncDate(from now: Date) -> Date {
        var c = Calendar.current.dateComponents([.year, .month, .day], from: now)
        c.hour = defaultSyncHour; c.minute = defaultSyncMinute; c.second = 0
        let today = Calendar.current.date(from: c)!
        if today > now { return today }
        return Calendar.current.date(byAdding: .day, value: 1, to: today)!
    }

    private func fireDailySync() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        syncEngine.syncUnsyncedDays(upToAndIncluding: SyncFormat.dayString(for: yesterday))
        onSyncFired?()
        scheduleDailyTimer()
    }

    private func installBackgroundActivity() {
        let activity = NSBackgroundActivityScheduler(identifier: "com.lumen.sync")
        activity.repeats = true
        activity.interval = 3600
        activity.tolerance = 1800
        activity.qualityOfService = .utility
        activity.schedule { [weak self] completion in
            guard let self else { completion(.finished); return }
            let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
            let yesterdayStr = SyncFormat.dayString(for: yesterday)
            let missed = DataStore.shared.bufferedDays().filter { $0 <= yesterdayStr }
            if !missed.isEmpty {
                Log.sync.info("Watchdog catching up \(missed.count) missed day(s)")
                self.syncEngine.syncUnsyncedDays(upToAndIncluding: yesterdayStr)
                self.onCatchUpSynced?(missed.count)
                self.onSyncFired?()
            }
            completion(.finished)
        }
        backgroundActivity = activity
    }

    func syncNow() {
        syncEngine.syncDay(SyncFormat.dayString(), archiveAfterSuccess: false)
        onSyncFired?()
    }
}
