import AppKit
import Combine
import CoreLocation
import Foundation
import ServiceManagement

@MainActor
final class AppState: ObservableObject {
    static let shared = AppState()

    let permissions = PermissionsManager()
    let locationTracker = LocationTracker()
    private let appWindowTracker = AppWindowTracker()
    private let inputMetrics = InputMetricsTracker()
    private let browserTracker = BrowserTracker()
    private let hardwareMonitor = HardwareMonitor()
    private let idleTracker = IdleTracker()
    private let sessionCollector = SessionCollector()
    private let cameraMicCollector = CameraMicCollector()
    private let mediaCollector = MediaCollector()
    private let networkContextCollector = NetworkContextCollector()
    private let clipboardCollector = ClipboardCollector()
    private let focusModeCollector = FocusModeCollector()
    private let appLifecycleCollector = AppLifecycleCollector()
    private let mailCollector = MailCollector()
    private let receiptCollector = ReceiptMailCollector()
    private let gitCollector = GitCollector()
    private let cliCollector = CLICollector()
    private let thermalCollector = ThermalCollector()
    private let audioCollector = AudioCollector()
    private let displayCollector = DisplayCollector()
    private let bluetoothBatteryCollector = BluetoothBatteryCollector()
    private let networkQualityCollector = NetworkQualityCollector()
    private let notificationTracker = NotificationTracker()
    private let diskHygieneCollector = DiskHygieneCollector()
    private let crossDeviceCollector = CrossDeviceScreenTimeCollector.shared
    private let syncEngine = iCloudSync()
    private(set) lazy var scheduler = SyncScheduler(syncEngine: syncEngine)
    let updater = UpdateChecker.shared

    @Published var isTracking = false
    @Published var stats = TodayStats.empty
    @Published var todayStory = DayStory.empty
    @Published var crossDeviceReport: CrossDeviceScreenTimeReport = .empty
    @Published var spendToday = SpendSummary.empty
    @Published var spendMonth = SpendSummary.empty
    @Published var selectedSpendMonthOffset: Int = 0 {
        didSet { refreshAggregation() }
    }
    @Published var selectedSpendFilter: SpendFilter = .all
    @Published var showBurnRateGraph: Bool = false
    @Published var showSpotlightSearch: Bool = false
    @Published var morningBrief: MorningBrief? = nil
    @Published var taxReport2026: ScheduleCTaxReport = .empty
    @Published var financialForecast: FinancialForecast = .empty
    @Published var timeMachineFrames: [TimeMachineFrame] = []
    @Published var workspaceClusters: [WorkspaceCluster] = []
    @Published var storageSnapshot: StorageSnapshot = .empty
    @Published var zombieAlerts: [ZombieSubscriptionAlert] = []
    @Published var powerSnapshot: PowerSnapshot = .empty
    @Published var powerHistoryWatts: [Double] = [3.8, 4.1, 4.5, 4.0, 5.2, 4.8, 3.9, 4.3, 4.6, 4.2]
    @Published var cognitiveSnapshot: CognitiveFragmentationSnapshot = .empty
    @Published var dailyStandup: DailyStandupReport = .empty
    @Published var selectedReceiptForEditing: ReceiptPayload? = nil
    @Published var showTransactionEditor: Bool = false
    @Published var showStandupModal: Bool = false
    @Published var gitCommits: [GitCommitNode] = []
    @Published var predictedRenewals: [PredictedRenewal] = []
    @Published var audioFlowReport: AudioFlowReport = .empty
    @Published var healthSnapshot: AppleHealthSnapshot = .empty
    @Published var aiFleetSummary: AIFleetSummary = .empty
    @Published var isHUDVisible: Bool = false
    @Published var isTurboSweeping: Bool = false
    @Published var turboSweepProgress: Double = 0.0
    @Published var turboSweepStepName: String = ""
    @Published var turboSweepReclaimedSoFar: Int64 = 0
    @Published var liveKeystrokes: Int = 0
    @Published var liveClicks: Int = 0
    @Published var spendSearchQuery: String = ""
    @Published var subscriptions: SubscriptionSummary = .empty
    @Published var todayEventCount = 0
    @Published var lastSyncDate: Date?
    @Published var lastSyncSuccess = false
    @Published var lastSyncDetail = "Never synced"
    @Published var nextScheduledSync: Date?
    @Published var missedDaysSynced = 0

    @Published var launchAtLogin = false
    @Published var launchAtLoginNeedsApproval = false
    @Published var accessibilityGranted = false
    @Published var screenRecordingGranted = false
    /// True while macOS Secure Input is withholding keyDown events from the tap.
    @Published var secureInputSuppressed = false
    /// Menu-bar title mode (#7): show live active time next to the icon.
    @Published var showMenuBarTime = UserDefaults.standard.bool(forKey: "macsync.menuBarTime") {
        didSet { UserDefaults.standard.set(showMenuBarTime, forKey: "macsync.menuBarTime") }
    }

    private var cancellables = Set<AnyCancellable>()
    private var locationPingTimer: Timer?
    private var aggregationTimer: Timer?

    private init() {
        DataStore.shared.onStatsChanged = { [weak self] in
            Task { @MainActor in self?.refreshStats() }
        }
        refreshStats()
        refreshLaunchAtLoginStatus()
        refreshPermissionStatus()
    }

    // MARK: - Lifecycle

    func applicationDidFinishLaunching() {
        DataStore.shared.pruneBuffers(olderThan: 30)
        DataStore.shared.pruneInvalidReceipts()
        permissions.runOnboardingIfNeeded(locationTracker: locationTracker)
        startTracking()
        startAggregationTimer()
        Task { @MainActor in
            self.refreshAggregation()
        }
        scheduler.start()
        nextScheduledSync = scheduler.nextScheduledSync
        scheduler.onSyncFired = { [weak self] in
            Task { @MainActor in
                self?.nextScheduledSync = self?.scheduler.nextScheduledSync
                self?.refreshStats()
            }
        }
        scheduler.onCatchUpSynced = { [weak self] count in
            Task { @MainActor in self?.missedDaysSynced = count }
        }
        updater.start()
        startLocationPingTimer()
        startHealthFileWatcher()
        P2PSyncHost.shared.start()
    }

    func applicationWillTerminate() {
        stopTracking()
        scheduler.stop()
        P2PSyncHost.shared.stop()
    }

    // MARK: - Tracking control

    func startTracking() {
        guard !isTracking else { return }
        appWindowTracker.start()
        inputMetrics.start()
        browserTracker.start()
        hardwareMonitor.start()
        idleTracker.start()
        sessionCollector.start()
        cameraMicCollector.start()
        mediaCollector.start()
        networkContextCollector.start()
        clipboardCollector.start()
        focusModeCollector.start()
        appLifecycleCollector.start()
        mailCollector.start()
        receiptCollector.start()
        gitCollector.start()
        cliCollector.start()
        thermalCollector.start()
        audioCollector.start()
        displayCollector.start()
        bluetoothBatteryCollector.start()
        networkQualityCollector.start()
        notificationTracker.start()
        diskHygieneCollector.start()
        crossDeviceCollector.start()
        locationTracker.start()
        AutoEvictionGuardian.shared.start()
        isTracking = true
    }

    func stopTracking() {
        guard isTracking else { return }
        appWindowTracker.stop()
        inputMetrics.stop()
        browserTracker.stop()
        hardwareMonitor.stop()
        idleTracker.stop()
        sessionCollector.stop()
        cameraMicCollector.stop()
        mediaCollector.stop()
        networkContextCollector.stop()
        clipboardCollector.stop()
        focusModeCollector.stop()
        appLifecycleCollector.stop()
        mailCollector.stop()
        receiptCollector.stop()
        gitCollector.stop()
        cliCollector.stop()
        thermalCollector.stop()
        audioCollector.stop()
        displayCollector.stop()
        bluetoothBatteryCollector.stop()
        networkQualityCollector.stop()
        notificationTracker.stop()
        diskHygieneCollector.stop()
        crossDeviceCollector.stop()
        locationTracker.stop()
        AutoEvictionGuardian.shared.stop()
        isTracking = false
    }

    func toggleTracking() { isTracking ? stopTracking() : startTracking() }

    // MARK: - Stats / sync

    func refreshStats() {
        let store = DataStore.shared
        todayEventCount = store.todayEventCount
        lastSyncDate = store.lastSyncDate
        lastSyncSuccess = store.lastSyncSuccess
        lastSyncDetail = store.lastSyncDetail
    }

    func refreshAggregation() {
        enforceNightPause()
        let day = SyncFormat.dayString()
        let events = DataStore.shared.events(forDay: day)
        let archived = HistoryLoader.archivedEvents(daysBack: 7)
        stats = TodayAggregator.compute(events: events, archived: archived)
        liveKeystrokes = max(liveKeystrokes, stats.keystrokes)
        liveClicks = max(liveClicks, stats.clicks)
        todayStory = DayStoryAggregator.buildStory(events: events)
        spendToday = SpendStats.calculate(events: SpendStats.eventsForToday())
        spendMonth = SpendStats.calculate(events: SpendStats.eventsForMonth(monthOffset: selectedSpendMonthOffset), monthOffset: selectedSpendMonthOffset)

        let allReceipts = SpendStats.allReceipts()
        subscriptions = SubscriptionRadar.analyze(receipts: allReceipts)
        predictedRenewals = SubscriptionRenewalCalendar.forecastRenewals(subscriptions: subscriptions.activeSubscriptions, receipts: allReceipts)
        taxReport2026 = ScheduleCTaxEngine.generateReport(year: 2026, receipts: allReceipts)
        financialForecast = FinancialForecaster.computeForecast(spendMonth: spendMonth, taxReport: taxReport2026)
        
        powerSnapshot = PowerPacingEngine.captureSnapshot()
        powerHistoryWatts.append(powerSnapshot.estimatedWatts)
        if powerHistoryWatts.count > 30 {
            powerHistoryWatts.removeFirst()
        }

        gitCommits = GitVelocityLinker.scanRecentCommits()
        timeMachineFrames = TimeMachineEngine.buildTimeline(events: events, gitCommits: gitCommits)
        cognitiveSnapshot = CognitiveFragmentationEngine.compute(todayStats: stats, frames: timeMachineFrames, liveKeystrokes: liveKeystrokes)
        dailyStandup = StandupGeneratorEngine.generate(stats: stats, frames: timeMachineFrames, cognitive: cognitiveSnapshot)

        audioFlowReport = AudioFlowProfiler.analyzeAudioFlow(events: events)
        crossDeviceReport = crossDeviceCollector.generateReport()
        workspaceClusters = WorkspaceClusterEngine.analyze(events: events)
        storageSnapshot = iCloudStorageOptimizer.scanStorage()

        let yesterdayEvents = archived.first?.events ?? []
        morningBrief = MorningBriefingEngine.generateBrief(eventsYesterday: yesterdayEvents, subscriptions: subscriptions, pacing: spendMonth.pacing)
        var appMap: [String: TimeInterval] = [:]
        for app in stats.apps {
            appMap[app.name] = app.seconds
        }
        zombieAlerts = ZombieDetector.detectZombies(subscriptions: subscriptions.activeSubscriptions, appUsage30Days: appMap)

        // Apple Health — load from cache synchronously, refresh async in background
        healthSnapshot = AppleHealthEngine.latestSnapshot()
        AppleHealthEngine.refresh { [weak self] snap in
            self?.healthSnapshot = snap
        }

        // AI Fleet Telemetry & Multi-Account Quota Radar
        aiFleetSummary = AIFleetTelemetryCollector.scanFleet()
    }

    func refreshAIFleet() {
        aiFleetSummary = AIFleetTelemetryCollector.scanFleet()
    }

    func toggleHUD() {
        HUDWindowController.shared.toggle()
        isHUDVisible = HUDWindowController.shared.isVisible
    }

    func recordLiveInput(keystrokes: Int, clicks: Int) {
        self.liveKeystrokes += keystrokes
        self.liveClicks += clicks
    }

    func refreshSpend() {
        refreshAggregation()
    }

    func rescanMailReceipts() {
        receiptCollector.forceRescan()
        DispatchQueue.main.asyncAfter(deadline: .now() + 4.0) {
            self.refreshAggregation()
        }
    }

    func refreshStorage() {
        storageSnapshot = iCloudStorageOptimizer.scanStorage()
    }

    func optimizeAllStorage() {
        runMasterTurboSweep()
    }

    /// Master 1-Click Zero-Footprint Turbo Sweep: executes all 6 storage optimizations on a background queue with live progress reporting on the MainActor.
    func runMasterTurboSweep(completion: (@MainActor @Sendable (Int64) -> Void)? = nil) {
        guard !isTurboSweeping else { return }
        isTurboSweeping = true
        turboSweepProgress = 0.05
        turboSweepStepName = "Scanning storage candidates & calculating sizes…"
        turboSweepReclaimedSoFar = 0

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            var totalReclaimed: Int64 = 0

            // 1. Triage downloads (DMGs, media, stale docs moved to iCloud and evicted)
            let triagePlan = DownloadTriageEngine.planTriage()
            let totalTriage = max(1, triagePlan.count)
            DispatchQueue.main.async {
                self?.turboSweepProgress = 0.15
                self?.turboSweepStepName = triagePlan.isEmpty ? "Step 1/5: Downloads folder clean (0 to triage)" : "Step 1/5: Triaging \(triagePlan.count) downloads to iCloud…"
            }

            for (idx, item) in triagePlan.enumerated() {
                let p = 0.15 + (0.25 * Double(idx + 1) / Double(totalTriage))
                DispatchQueue.main.async {
                    self?.turboSweepProgress = min(0.40, p)
                    self?.turboSweepStepName = "Step 1/5: Archiving \(item.filename) (\(idx + 1)/\(triagePlan.count))…"
                }

                let targetDir = (item.targetCloudPath as NSString).deletingLastPathComponent
                try? FileManager.default.createDirectory(atPath: targetDir, withIntermediateDirectories: true)
                do {
                    if FileManager.default.fileExists(atPath: item.targetCloudPath) {
                        try FileManager.default.removeItem(atPath: item.targetCloudPath)
                    }
                    try FileManager.default.moveItem(atPath: item.sourcePath, toPath: item.targetCloudPath)
                    _ = iCloudStorageOptimizer.evictItem(atPath: item.targetCloudPath)
                    totalReclaimed += item.sizeBytes
                    let cur = totalReclaimed
                    DispatchQueue.main.async {
                        self?.turboSweepReclaimedSoFar = cur
                    }
                } catch {
                    continue
                }
            }

            // 2. Evict unpinned iCloud items & backup snapshots
            let snapshot = iCloudStorageOptimizer.scanStorage()
            let evictable = snapshot.candidates.filter {
                $0.category == .iCloudEvictable && !FolderPinningEngine.isProtectedFromEviction(path: $0.path)
            }
            let totalEvictable = max(1, evictable.count)

            DispatchQueue.main.async {
                self?.turboSweepProgress = 0.45
                self?.turboSweepStepName = evictable.isEmpty ? "Step 2/5: All iCloud files already offloaded to cloud" : "Step 2/5: Evicting \(evictable.count) unpinned iCloud files…"
            }

            for (idx, candidate) in evictable.enumerated() {
                let p = 0.45 + (0.25 * Double(idx + 1) / Double(totalEvictable))
                DispatchQueue.main.async {
                    self?.turboSweepProgress = min(0.70, p)
                    self?.turboSweepStepName = "Step 2/5: Evicting \(candidate.title) (\(idx + 1)/\(evictable.count))…"
                }
                if iCloudStorageOptimizer.evictItem(atPath: candidate.path) {
                    totalReclaimed += candidate.sizeBytes
                    let cur = totalReclaimed
                    DispatchQueue.main.async {
                        self?.turboSweepReclaimedSoFar = cur
                    }
                }
            }

            // 3. Trim all developer bloat (node_modules, .venv, .build)
            let bloatList = DeveloperProjectTrimmer.scanDeveloperBloat()
            let totalBloat = max(1, bloatList.count)
            DispatchQueue.main.async {
                self?.turboSweepProgress = 0.70
                self?.turboSweepStepName = bloatList.isEmpty ? "Step 3/5: Developer build caches clean" : "Step 3/5: Trimming \(bloatList.count) dev bloat folders…"
            }

            for (idx, b) in bloatList.enumerated() {
                let p = 0.70 + (0.15 * Double(idx + 1) / Double(totalBloat))
                DispatchQueue.main.async {
                    self?.turboSweepProgress = min(0.85, p)
                    self?.turboSweepStepName = "Step 3/5: Trimming \(b.projectName)/\(b.bloatType)…"
                }
                if DeveloperProjectTrimmer.trimCandidate(b) {
                    totalReclaimed += b.sizeBytes
                    let cur = totalReclaimed
                    DispatchQueue.main.async {
                        self?.turboSweepReclaimedSoFar = cur
                    }
                }
            }

            // 4. Resolve conflicted duplicate files
            DispatchQueue.main.async {
                self?.turboSweepProgress = 0.85
                self?.turboSweepStepName = "Step 4/5: Resolving conflicted duplicate cloud files…"
            }
            _ = iCloudSyncRadar.resolveAllConflicts()

            // 5. Purge disposable system caches
            DispatchQueue.main.async {
                self?.turboSweepProgress = 0.95
                self?.turboSweepStepName = "Step 5/5: Purging disposable system caches & DerivedData…"
            }
            let cacheBytes = iCloudStorageOptimizer.purgeUserCaches()
            totalReclaimed += cacheBytes
            let finalReclaimed = totalReclaimed

            let newSnapshot = iCloudStorageOptimizer.scanStorage()

            DispatchQueue.main.async {
                self?.storageSnapshot = newSnapshot
                self?.turboSweepProgress = 1.0
                self?.turboSweepReclaimedSoFar = finalReclaimed
                let formatted = ByteCountFormatter.string(fromByteCount: finalReclaimed, countStyle: .file)
                self?.turboSweepStepName = "✓ Complete! Reclaimed \(formatted) local disk space."
                completion?(finalReclaimed)

                DispatchQueue.main.asyncAfter(deadline: .now() + 4.5) { [weak self] in
                    self?.isTurboSweeping = false
                    self?.turboSweepProgress = 0.0
                    self?.turboSweepStepName = ""
                }
            }
        }
    }

    func optimizeSpecificCandidate(_ candidate: StorageOptimizationCandidate) {
        if candidate.category == .iCloudEvictable || candidate.category == .duplicateFile {
            _ = iCloudStorageOptimizer.evictItem(atPath: candidate.path)
        } else if candidate.category == .downloadsArchive {
            _ = iCloudStorageOptimizer.archiveToCloudAndEvict(sourcePath: candidate.path)
        } else if candidate.category == .cachePurge {
            _ = try? FileManager.default.removeItem(atPath: candidate.path)
        }
        refreshStorage()
    }

    func purgeCaches() {
        _ = iCloudStorageOptimizer.purgeUserCaches()
        refreshStorage()
    }

    // MARK: - Manual receipts (v0.5.0)

    /// Adds a hand-entered receipt (cash / paper / anything email missed).
    func addManualReceipt(merchant: String, amountAmount: Decimal, category: ReceiptCategory,
                          cardLast4: String?, notes: String?, date: Date) {
        let payload = ReceiptPayload(
            id: UUID(), merchant: merchant, amount: amountAmount, currency: "USD",
            cardLast4: cardLast4, category: category, transactionDate: date,
            capturedAt: Date(), source: "manual", mailMessageID: nil,
            confidence: 1.0, needsReview: false, notes: notes)
        DataStore.shared.append(TrackerEvent(ts: date, kind: .receipt, payload: .receipt(payload)))
        refreshAggregation()
    }

    func syncNow() { scheduler.syncNow() }

    func openOnboarding() {
        OnboardingWindowController.shared.show(permissions: permissions)
    }

    func exportScheduleCTaxCSV() {
        let csv = ScheduleCTaxEngine.exportCSV(report: taxReport2026)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "macsync_ScheduleC_\(taxReport2026.year).csv"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? csv.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    func exportCPATaxMarkdown() {
        let md = ScheduleCTaxEngine.exportCPAMarkdown(report: taxReport2026)
        let savePanel = NSSavePanel()
        savePanel.nameFieldStringValue = "macsync_CPA_Report_\(taxReport2026.year).md"
        if savePanel.runModal() == .OK, let url = savePanel.url {
            try? md.write(to: url, atomically: true, encoding: .utf8)
        }
    }

    // MARK: - Night pause (#17)

    private func enforceNightPause() {
        guard SyncOptions.nightPauseEnabled else {
            if !isTracking && pausedForNight { pausedForNight = false; startTracking() }
            return
        }
        if SyncOptions.isInNightPauseWindow() {
            if isTracking { stopTracking(); pausedForNight = true }
        } else if pausedForNight {
            pausedForNight = false
            startTracking()
        }
    }
    private var pausedForNight = false

    // MARK: - Health for menu-bar icon (#10)

    var healthIsBad: Bool {
        !accessibilityGranted || !screenRecordingGranted
            || (lastSyncDate != nil && !lastSyncSuccess)
    }

        private func startAggregationTimer() {
        aggregationTimer?.invalidate()
        // immediate first tick at 0.5s so the menu shows fresh stats on launch
        Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] _ in
            Task { @MainActor in self?.refreshAggregation(); self?.refreshPermissionStatus() }
        }
        let timer = Timer(timeInterval: 30, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.refreshAggregation()
                self?.refreshPermissionStatus()
            }
        }
        RunLoop.main.add(timer, forMode: .common)
        aggregationTimer = timer
    }

    private func startLocationPingTimer() {
        locationPingTimer?.invalidate()
        let timer = Timer(timeInterval: 3600, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.locationTracker.ping() }
        }
        RunLoop.main.add(timer, forMode: .common)
        locationPingTimer = timer
    }

    private func startHealthFileWatcher() {
        AppleHealthFileWatcher.shared.start { [weak self] snap in
            guard let self else { return }
            self.healthSnapshot = snap
            AppleHealthEngine.refresh { [weak self] fresh in
                self?.healthSnapshot = fresh
            }
        }
    }

    @MainActor
    func triggerHealthShortcut() {
        LumenHealthShortcuts.runShortcut { success in
            if success {
                // Watcher will pick up the new file automatically
            }
        }
    }

    // MARK: - Permissions

    func refreshPermissionStatus() {
        accessibilityGranted = permissions.isAccessibilityTrusted
        screenRecordingGranted = permissions.hasScreenRecording
        secureInputSuppressed = inputMetrics.secureInputSuppressed
    }

    func requestPermissions() {
        permissions.requestAccessibility()
        permissions.requestScreenRecording()
        permissions.requestAutomationConsent()
        refreshPermissionStatus()
    }

    // MARK: - Launch at Login (SMAppService)

    func refreshLaunchAtLoginStatus() {
        switch SMAppService.mainApp.status {
        case .enabled:
            launchAtLogin = true; launchAtLoginNeedsApproval = false
        case .requiresApproval:
            launchAtLogin = true; launchAtLoginNeedsApproval = true
        case .notRegistered, .notFound:
            launchAtLogin = false; launchAtLoginNeedsApproval = false
        @unknown default:
            launchAtLogin = false; launchAtLoginNeedsApproval = false
        }
    }

    func toggleLaunchAtLogin(_ enable: Bool) {
        if enable {
            do { try SMAppService.mainApp.register() }
            catch { Log.app.error("SMAppService register failed: \(error.localizedDescription)") }
        } else {
            Task {
                do { try await SMAppService.mainApp.unregister() }
                catch { Log.app.error("SMAppService unregister failed: \(error.localizedDescription)") }
                await MainActor.run { self.refreshLaunchAtLoginStatus() }
            }
            return
        }
        refreshLaunchAtLoginStatus()
    }

    func openLoginItemsSettings() { SMAppService.openSystemSettingsLoginItems() }
    func openDataFolder() { NSWorkspace.shared.open(DataStore.shared.root) }
    func openSpendFolder() { NSWorkspace.shared.open(SpendExport.exportDir) }
    func revealSpendExport(url: URL) { NSWorkspace.shared.activateFileViewerSelecting([url]) }
}
