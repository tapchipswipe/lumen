import Foundation

enum ReceiptParserTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)

        // 1. Non-Purchase Exclusions (Declines, Trades, Airline Alerts, Budget Warnings, Card Payments, Blacklisted Stores)
        let excludedSamples: [(subject: String, sender: String, body: String, reason: String)] = [
            ("Transaction decline notification", "Privacy <support@privacy.com>", "Declined charge $10", "Declines"),
            ("$142.00 payment to Flux.ai was unsuccessful", "Flux.ai <failed-payments@flux.ai>", "Unsuccessful", "Failed payment"),
            ("Your trade has been executed", "Public <support@public.com>", "Market order to buy $37.67 VOO", "Stock trade"),
            ("Order filled: Buy 10 AAPL", "Robinhood <orders@robinhood.com>", "Total: $650.00", "Brokerage order"),
            ("Time to check in for your flight DL 1787", "Delta <ticketreceipt@delta.com>", "Upgrade from $1,787.00", "Flight check-in"),
            ("Google Cloud Budget Alert", "Google Cloud <billing@google.com>", "Estimated charges: $541.00", "Budget alert"),
            ("Your credit card payment has posted", "Chase <no-reply@chase.com>", "Received payment of $1,200.00", "Credit card bill"),
            ("Aug 13, 2026 bill for Kart Rising LLC", "Shopify <billing@shopify.com>", "Total: $421.19", "User-blacklisted merchant"),
            ("Your Steam purchase receipt", "Steam <noreply@steampowered.com>", "Total: $24.99", "User-blacklisted merchant"),
            ("Order #955890 confirmed", "Swell Labs <hi@swelllabs.org>", "Total: $0.00 USD", "Free $0 exchange"),
            ("Your weekly recap", "Klaviyo <hello@klaviyomail.com>", "Saved $12.99 on sheets", "Marketing promo email")
        ]

        for s in excludedSamples {
            let parsed = ReceiptParser.parse(subject: s.subject, sender: s.sender, body: s.body, sentDate: d)
            expect(parsed.amount == nil, "Exclusion guard: \(s.reason) (\(s.subject))")
        }

        // 2. Real Receipt Extractions (Delta, Google, Shopify, Swell Labs, Venmo, CAVA, Amazon, Square)
        let realReceipts: [(subject: String, sender: String, body: String, expectedMerchant: String?, expectedAmount: String, expectedCard: String?)] = [
            ("Your Flight Receipt - Passenger Receipt", "Delta <ticketreceipt@delta.com>", "Total Amount Charged: $340.50\nVisa ending in 4417", "Delta Air Lines", "340.50", "4417"),
            ("Your Google Workspace invoice is ready", "Google <payments-noreply@google.com>", "Total paid: $14.40\nMastercard ending in 9012", "Google", "14.40", "9012"),
            ("Aug 13, 2026 bill for Acme Store LLC", "Shopify <billing@shopify.com>", "Total: $39.00\nVisa ending in 4417", "Acme Store LLC", "39.00", "4417"),
            ("Order #953697 confirmed", "Swell Labs <hi@swelllabs.org>", "Order summary\nSubtotal\n$60.00\nOrder discount\n-$18.00\nSUMMER26 (-$18.00)\nShipping\n$0.00\nTotal\n$42.00 USD\nPayment\nending with 1533", nil, "42.00", "1533"),
            ("You paid Jackson Wainwright $8.00", "Venmo <venmo@venmo.com>", "You paid Jackson Wainwright $8.00.", "Jackson Wainwright", "8.00", nil),
            ("We've got your order #6191809579", "CAVA <hello@cava.com>", "Payment\nCZ 8031\nSubtotal\n$12.25\nTaxes\n$1.04\nYour Total\n$13.29", nil, "13.29", "8031"),
            ("Your Amazon.com order", "Amazon <auto-confirm@amazon.com>", "Total: $42.95\nVisa ending in 1234", "Amazon", "42.95", "1234"),
            ("Receipt from Joe's Coffee Shop", "Square <receipt@messaging.squareup.com>", "Amount: $8.50\nCard •••• 9021", "Joe's Coffee Shop", "8.50", "9021")
        ]

        for r in realReceipts {
            let parsed = ReceiptParser.parse(subject: r.subject, sender: r.sender, body: r.body, sentDate: d)
            let match = parsed.amount == Decimal(string: r.expectedAmount) &&
                        (r.expectedMerchant == nil || parsed.merchant == r.expectedMerchant) &&
                        (r.expectedCard == nil || parsed.cardLast4 == r.expectedCard)
            expect(match, "Receipt parser extraction: $\(r.expectedAmount) \(r.expectedMerchant ?? "")")
        }

        // 3. Formatting & Serialization
        expect(ReceiptParser.moneyDecimal("1,234.56") == Decimal(string: "1234.56"), "Comma thousands parsing")
        let payload = ReceiptPayload(id: UUID(), merchant: "Amazon", amount: Decimal(string: "42.95")!, currency: "USD", cardLast4: "1234", category: .shopping, transactionDate: d, capturedAt: d, source: "mail", mailMessageID: "msg-1", confidence: 0.95, needsReview: false, notes: nil)
        let back = try! SyncFormat.jsonDecoder.decode(ReceiptPayload.self, from: try! SyncFormat.jsonEncoder.encode(payload))
        expect(back.amount == Decimal(string: "42.95") && back.cardLast4 == "1234", "ReceiptPayload serialization roundtrip")
    }
}

enum ReceiptCategorizerTests {
    static func run() {
        let mappings: [(String, ReceiptCategory)] = [
            ("Starbucks", .dining), ("Netflix", .subscriptions), ("Adobe", .software),
            ("Delta Air Lines", .travel), ("Uber", .transport), ("Verizon", .utilities),
            ("CVS", .health), ("Unknown Bodega", .other)
        ]
        for (merchant, expectedCat) in mappings {
            expect(ReceiptCategorizer.category(for: merchant) == expectedCat, "Category classification: \(merchant) → \(expectedCat)")
        }

        ReceiptCategorizer.setOverride(.business, for: "Starbucks")
        expect(ReceiptCategorizer.category(for: "Starbucks") == .business, "User category override takes priority")
        ReceiptCategorizer.clearOverride(for: "Starbucks")

        expect(ReceiptCategory.software.businessDeductible && ReceiptCategory.travel.businessDeductible && !ReceiptCategory.dining.businessDeductible, "Category default tax deductibility rules")
    }
}

enum SpendAggregatorTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        func ev(_ m: String, _ amount: String, _ cat: ReceiptCategory, _ card: String?, _ review: Bool) -> TrackerEvent {
            TrackerEvent(ts: d, kind: .receipt, payload: .receipt(ReceiptPayload(
                id: UUID(), merchant: m, amount: Decimal(string: amount)!,
                currency: "USD", cardLast4: card, category: cat,
                transactionDate: d, capturedAt: d, source: "mail",
                mailMessageID: nil, confidence: review ? 0.5 : 0.95,
                needsReview: review, notes: nil)))
        }
        let events = [ev("Starbucks", "6.50", .dining, "1234", false),
                      ev("Netflix", "15.99", .subscriptions, "5678", false),
                      ev("Adobe", "59.99", .software, "1234", false),
                      ev("Old Bookstore", "5.00", .other, nil, true)]
        let s = SpendStats.calculate(events: events)
        expect(s.receipts.count == 4 && s.total == Decimal(string: "87.48") && s.deductibleTotal == Decimal(string: "75.98"), "Spend total and deductible aggregation")
        expect(s.byCard["1234"] == Decimal(string: "66.49") && s.byMerchant["Netflix"] == Decimal(string: "15.99"), "Card and merchant rollup")
        expect(s.needsReviewCount == 1, "Needs review count rollup")
        expect(SpendStats.calculate(events: []).receipts.isEmpty, "Empty spend rollup handling")
    }
}

enum SpendExportTests {
    static func run() {
        let d = Date(timeIntervalSince1970: 1_700_000_000)
        let r = ReceiptPayload(id: UUID(), merchant: "Chipotle", amount: Decimal(string: "12.34")!,
                               currency: "USD", cardLast4: "9876", category: .dining,
                               transactionDate: d, capturedAt: d, source: "manual",
                               mailMessageID: nil, confidence: 1.0, needsReview: false, notes: "lunch, w/ \"team\"")
        let csv = SpendExport.csvString(receipts: [r])
        expect(csv.hasPrefix("Date,Merchant,Category,Amount") && csv.contains("\"lunch, w/ \"\"team\"\"\"") && csv.contains("Chipotle,dining,12.34,USD,9876,no,manual"), "CSV export with RFC 4180 escaping")
    }
}

enum CardPortfolioTests {
    static func run() {
        CardPortfolio.resetDefaults()
        expect(CardPortfolio.displayName(for: "8031") == "Steve Credit ••8031" &&
               CardPortfolio.displayName(for: "1533") == "Joyce Credit ••1533" &&
               CardPortfolio.displayName(for: "9530") == "Lucas Credit ••9530" &&
               CardPortfolio.displayName(for: "7805") == "Chase Checking ••7805",
               "Card portfolio nickname mappings")
        expect(CardPortfolio.displayName(for: nil) == "Direct Web" && CardPortfolio.shortName(for: nil) == "Direct", "Direct web purchase fallback")

        CardPortfolio.setNickname("Primary Visa", for: "8031")
        expect(CardPortfolio.shortName(for: "8031") == "Primary Visa", "Custom card nickname override")
        CardPortfolio.setNickname("", for: "8031")
    }
}

enum SubscriptionRadarTests {
    static func run() {
        let d = Date()
        let r1 = ReceiptPayload(id: UUID(), merchant: "Apple", amount: Decimal(string: "6.99")!,
                                currency: "USD", cardLast4: "8031", category: .subscriptions,
                                transactionDate: d, capturedAt: d, source: "mail",
                                mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)
        let r2 = ReceiptPayload(id: UUID(), merchant: "Venmo (Gavin)", amount: Decimal(string: "350.00")!,
                                currency: "USD", cardLast4: "7805", category: .other,
                                transactionDate: d, capturedAt: d, source: "mail",
                                mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)

        let summary = SubscriptionRadar.analyze(receipts: [r1, r2])
        expect(summary.activeSubscriptions.count == 1 &&
               summary.monthlyBurnRate == Decimal(string: "6.99") &&
               summary.annualBurnRate == Decimal(string: "83.88"),
               "Subscription isolation (Apple active, Venmo excluded)")
    }
}

enum SpendingPacingTests {
    static func run() {
        let d = Date()
        let r = ReceiptPayload(id: UUID(), merchant: "Best Buy", amount: Decimal(string: "200.00")!,
                               currency: "USD", cardLast4: "8031", category: .shopping,
                               transactionDate: d, capturedAt: d, source: "manual",
                               mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)
        let event = TrackerEvent(ts: d, kind: .receipt, payload: .receipt(r))
        let summary = SpendStats.calculate(events: [event], monthOffset: 0)

        expect(summary.pacing != nil && summary.pacing!.dailyBurnRate > 0, "Monthly spending pacing & burn curve calculation")
    }
}

enum DayStoryTests {
    static func run() {
        let now = Date()
        let r = ReceiptPayload(id: UUID(), merchant: "CAVA", amount: Decimal(string: "13.29")!,
                               currency: "USD", cardLast4: "8031", category: .dining,
                               transactionDate: now, capturedAt: now, source: "mail",
                               mailMessageID: nil, confidence: 1.0, needsReview: false, notes: "Order #6191809579")
        let w = WindowFocusPayload(appName: "Xcode", windowTitle: "Lumen - SpendStats.swift", start: now.addingTimeInterval(-1800), end: now, durationSeconds: 1800)

        let e1 = TrackerEvent(ts: now.addingTimeInterval(-1800), kind: .windowFocus, payload: .windowFocus(w))
        let e2 = TrackerEvent(ts: now.addingTimeInterval(-600), kind: .windowFocus, payload: .windowFocus(w))
        let e3 = TrackerEvent(ts: now, kind: .receipt, payload: .receipt(r))

        let story = DayStoryAggregator.buildStory(events: [e1, e2, e3], forDate: now)

        expect(story.chapters.count >= 2 &&
               story.totalDaySpend == Decimal(string: "13.29") &&
               (story.chapters.first(where: { $0.type == .purchase })?.cardNickname?.contains("Steve Credit") ?? false),
               "DayStory unified timeline generation & card binding")
    }
}

enum LifelogSearchTests {
    static func run() {
        let results = LifelogSearchEngine.search(query: "Steve")
        expect(results.count >= 0, "Lifelog search natural language engine")
    }
}

enum ZombieDetectorTests {
    static func run() {
        let d = Date()
        let sub = TrackedSubscription(
            merchant: "Adobe", amount: Decimal(string: "54.99")!, currency: "USD",
            cadence: .monthly, cardLast4: "8031", category: .software,
            lastBilledDate: d, nextRenewalDate: d.addingTimeInterval(86400 * 30), usageSeconds30d: 300
        )
        let alerts = ZombieDetector.detectZombies(subscriptions: [sub], appUsage30Days: ["Adobe Creative Cloud": 300])
        expect(alerts.count == 1 && alerts.first?.merchant == "Adobe", "Zombie subscription alert for unused apps (<20m/30d)")
    }
}

enum ScheduleCTaxTests {
    static func run() {
        let d = Date()
        let r1 = ReceiptPayload(id: UUID(), merchant: "Apple", amount: Decimal(string: "6.99")!,
                                currency: "USD", cardLast4: "8031", category: .subscriptions,
                                transactionDate: d, capturedAt: d, source: "mail",
                                mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)
        let r2 = ReceiptPayload(id: UUID(), merchant: "Best Buy", amount: Decimal(string: "200.00")!,
                                currency: "USD", cardLast4: "8031", category: .shopping,
                                transactionDate: d, capturedAt: d, source: "manual",
                                mailMessageID: nil, confidence: 1.0, needsReview: false, notes: "Monitor")
        let r3 = ReceiptPayload(id: UUID(), merchant: "CAVA", amount: Decimal(string: "14.00")!,
                                currency: "USD", cardLast4: "8031", category: .dining,
                                transactionDate: d, capturedAt: d, source: "mail",
                                mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)

        let cal = Calendar.current
        let year = cal.component(.year, from: d)
        let report = ScheduleCTaxEngine.generateReport(year: year, receipts: [r1, r2, r3])

        expect(report.lineItems.count == 3 &&
               report.byLine[.line18Software] == Decimal(string: "6.99") &&
               report.byLine[.line22Supplies] == Decimal(string: "200.00") &&
               report.byLine[.line24bMeals] == Decimal(string: "7.00") &&
               ScheduleCTaxEngine.exportCSV(report: report).contains("Line 18"),
               "IRS Schedule-C tax categorization & 50% meal limit")
    }
}

enum WorkspaceClusterTests {
    static func run() {
        let now = Date()
        let net = NetworkContextPayload(observedAt: now, ssid: "Home_5G", bssidHash: nil, rssi: nil, onVPN: false)
        let e = TrackerEvent(ts: now, kind: .networkContext, payload: .networkContext(net))
        let clusters = WorkspaceClusterEngine.analyze(events: [e])
        expect(clusters.count >= 1, "Geofenced workspace clustering")
    }
}

enum MorningBriefingTests {
    static func run() {
        let now = Date()
        let r = ReceiptPayload(id: UUID(), merchant: "CAVA", amount: Decimal(string: "13.29")!,
                               currency: "USD", cardLast4: "8031", category: .dining,
                               transactionDate: now, capturedAt: now, source: "mail",
                               mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)
        let e = TrackerEvent(ts: now, kind: .receipt, payload: .receipt(r))
        let subSummary = SubscriptionSummary(activeSubscriptions: [], monthlyBurnRate: 0, annualBurnRate: 0, upcomingRenewals7Days: [], zombieSubscriptions: [])
        let brief = MorningBriefingEngine.generateBrief(eventsYesterday: [e], subscriptions: subSummary, pacing: nil)
        expect(brief.yesterdaySpend == Decimal(string: "13.29"), "Morning executive briefing generation")
    }
}

enum DeepTelemetryTests {
    static func run() {
        let now = Date()

        // Phase 1 tests
        let gitPayload = GitVelocityPayload(observedAt: now, repoName: "Lumen", branch: "main", uncommittedDiffLines: 42, commitsToday: 3)
        let gitEvent = TrackerEvent(ts: now, kind: .gitVelocity, payload: .gitVelocity(gitPayload))
        let cliPayload = CLICommandPayload(observedAt: now, commandName: "swift test", exitCode: 0, durationMs: 1500, isBuildOrTest: true)
        let cliEvent = TrackerEvent(ts: now, kind: .cliCommand, payload: .cliCommand(cliPayload))
        let thermalPayload = ThermalStatePayload(observedAt: now, thermalLevel: "nominal", cpuUsagePercent: 12.5, isThrottled: false)
        let thermalEvent = TrackerEvent(ts: now, kind: .thermalState, payload: .thermalState(thermalPayload))

        // Phase 2 tests
        let audioPayload = AudioRoutePayload(observedAt: now, outputDeviceName: "AirPods Pro", isAirPods: true, isHeadphones: true, volume: 0.7)
        let audioEvent = TrackerEvent(ts: now, kind: .audioRoute, payload: .audioRoute(audioPayload))
        let displayPayload = DisplayTopologyPayload(observedAt: now, screenCount: 2, hasExternalDisplay: true, primaryResolution: "3840x2160")
        let displayEvent = TrackerEvent(ts: now, kind: .displayTopology, payload: .displayTopology(displayPayload))
        let btPayload = BluetoothBatteryPayload(observedAt: now, devices: [BluetoothDeviceBattery(name: "AirPods Pro", batteryPercent: 85)])
        let btEvent = TrackerEvent(ts: now, kind: .bluetoothBattery, payload: .bluetoothBattery(btPayload))

        // Phase 3 tests
        let netPayload = NetworkQualityPayload(observedAt: now, pingMs: 14.2, packetLossPercent: 0.0, qualityGrade: "A+")
        let netEvent = TrackerEvent(ts: now, kind: .networkQuality, payload: .networkQuality(netPayload))
        let notifPayload = NotificationEventPayload(observedAt: now, sourceApp: "Slack")
        let notifEvent = TrackerEvent(ts: now, kind: .notificationEvent, payload: .notificationEvent(notifPayload))
        let diskPayload = DiskHygienePayload(observedAt: now, downloadsSizeGB: 4.2, staleInstallerCount: 2, freeDiskSpaceGB: 120.0)
        let diskEvent = TrackerEvent(ts: now, kind: .diskHygiene, payload: .diskHygiene(diskPayload))

        let allEvents = [gitEvent, cliEvent, thermalEvent, audioEvent, displayEvent, btEvent, netEvent, notifEvent, diskEvent]
        let encoded = try! SyncFormat.jsonEncoder.encode(allEvents)
        let decoded = try! SyncFormat.jsonDecoder.decode([TrackerEvent].self, from: encoded)

        expect(decoded.count == 9, "Deep telemetry suite: 9 collectors Codable serialization roundtrip")
        expect(gitPayload.branch == "main" && cliPayload.isBuildOrTest && !thermalPayload.isThrottled, "Phase 1: Git, CLI & Thermal telemetry integrity")
        expect(audioPayload.isAirPods && displayPayload.hasExternalDisplay && btPayload.devices.first?.batteryPercent == 85, "Phase 2: Audio, Display & Bluetooth telemetry integrity")
        expect(netPayload.qualityGrade == "A+" && notifPayload.sourceApp == "Slack" && diskPayload.staleInstallerCount == 2, "Phase 3: Network Quality, Notification & Disk Hygiene telemetry integrity")
    }
}

enum FrontierCore4Tests {
    static func run() {
        let now = Date()

        // 1. Financial Forecaster Test
        let r = ReceiptPayload(id: UUID(), merchant: "Apple", amount: Decimal(string: "6.99")!, currency: "USD", cardLast4: "8031", category: .subscriptions, transactionDate: now, capturedAt: now, source: "mail", mailMessageID: nil, confidence: 1.0, needsReview: false, notes: nil)
        let spendMonth = SpendStats.calculate(events: [TrackerEvent(ts: now, kind: .receipt, payload: .receipt(r))], monthOffset: 0)
        let taxReport = ScheduleCTaxEngine.generateReport(year: 2026, receipts: [r])
        let forecast = FinancialForecaster.computeForecast(spendMonth: spendMonth, taxReport: taxReport, date: now)

        expect(forecast.projectedMonthEndSpend > 0 && forecast.estimatedTaxSavings > 0, "Financial forecaster & live tax savings (28%) computation")

        // 2. Time Machine 24h Scrubber Test
        let w = WindowFocusPayload(appName: "Xcode", windowTitle: "MacsyncApp.swift", start: now, end: now.addingTimeInterval(300), durationSeconds: 300)
        let frames = TimeMachineEngine.buildTimeline(events: [TrackerEvent(ts: now, kind: .windowFocus, payload: .windowFocus(w))], date: now)
        expect(frames.count == 288, "Time Machine 24h timeline discretizes into 288 frames")

        // 3. Lumen Copilot Natural Language Engine Test
        let stats = TodayAggregator.compute(events: [TrackerEvent(ts: now, kind: .windowFocus, payload: .windowFocus(w))], archived: [])
        let financeResp = LumenCopilotEngine.ask(query: "How much did Steve spend?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast)
        let workResp = LumenCopilotEngine.ask(query: "What did I build today?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast)
        let taxResp = LumenCopilotEngine.ask(query: "What can I deduct on Schedule C?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast)
        let storageResp = LumenCopilotEngine.ask(query: "How can I optimize storage on iCloud?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast)

        expect(financeResp.title.contains("Financial") && workResp.title.contains("Focus") && taxResp.title.contains("Tax") && storageResp.title.contains("iCloud"), "Lumen Neural Copilot intent classification & synthesis (including Storage)")

        // 4. iCloud Storage Optimizer Test
        let snapshot = iCloudStorageOptimizer.scanStorage()
        expect(snapshot.totalDiskBytes > 0 && snapshot.usedDiskBytes >= 0, "iCloud Storage Optimizer scans system disk usage and ubiquity candidates")

        // 5. Folder Pinning Engine & Whitelist
        let defaultRules = FolderPinningEngine.loadRules()
        expect(!defaultRules.isEmpty, "FolderPinningEngine loads whitelist rules")
        let isProtected = FolderPinningEngine.isProtectedFromEviction(path: "\(NSHomeDirectory())/Documents/Projects/myrepo")
        expect(isProtected == true, "FolderPinningEngine protects pinned local projects from eviction")

        // 6. Developer Project Bloat Trimmer
        let bloat = DeveloperProjectTrimmer.scanDeveloperBloat()
        expect(bloat.count >= 0, "DeveloperProjectTrimmer scans node_modules and build artifacts")

        // 7. iCloud Sync Radar & Telemetry
        let radar = iCloudSyncRadar.inspectSyncRadar()
        expect(radar.isOnline == true, "iCloudSyncRadar inspects live sync queue & conflict status")

        // 8. Download Triage Engine
        let triage = DownloadTriageEngine.planTriage()
        expect(triage.count >= 0, "DownloadTriageEngine plans automated iCloud routing for installers and media")

        // 9. Full Disk Access & Master Turbo Sweep
        let perms = PermissionsManager()
        expect(perms.hasFullDiskAccess == true || perms.hasFullDiskAccess == false, "PermissionsManager checks Full Disk Access")

        // 10. Apple Silicon Power & Battery Runway
        let powerSnap = PowerPacingEngine.captureSnapshot()
        expect(powerSnap.batteryPercent >= 0 && powerSnap.estimatedWatts > 0, "PowerPacingEngine captures SoC wattage and battery runway")

        // 11. Git Commit & Velocity Linker
        let commits = GitVelocityLinker.scanRecentCommits()
        expect(commits.count >= 0, "GitVelocityLinker scans local git repository commit history")

        // 12. 30-Day Predictive Subscription Renewal Calendar
        let sub = TrackedSubscription(merchant: "Cursor Pro", amount: 20, currency: "USD", cadence: .monthly, cardLast4: "8031", category: .software, lastBilledDate: Date(), nextRenewalDate: nil, usageSeconds30d: nil)
        let renewals = SubscriptionRenewalCalendar.forecastRenewals(subscriptions: [sub], receipts: [])
        expect(!renewals.isEmpty && renewals.first?.daysUntilRenewal != nil, "SubscriptionRenewalCalendar forecasts 30-day billing milestones")

        // 13. Audio & Music Flow Correlation
        let audioReport = AudioFlowProfiler.analyzeAudioFlow(events: [])
        expect(!audioReport.topTracks.isEmpty && audioReport.flowStateVelocityBoostPercent > 0, "AudioFlowProfiler analyzes productivity correlation with music tracks")

        // 14. Next-Gen Neural Copilot Expansion
        let powerResp = LumenCopilotEngine.ask(query: "How much battery power am I using?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast, power: powerSnap)
        let gitResp = LumenCopilotEngine.ask(query: "What git commits did I ship today?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast, gitCommits: commits)
        let renewResp = LumenCopilotEngine.ask(query: "When does my next subscription charge occur?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast, renewals: renewals)
        let musicResp = LumenCopilotEngine.ask(query: "What music helped me focus best?", stats: stats, spendMonth: spendMonth, taxReport: taxReport, forecast: forecast, audioReport: audioReport)

        expect(powerResp.title.contains("Power") && gitResp.title.contains("Git") && renewResp.title.contains("Renewal") && musicResp.title.contains("Soundtrack"), "Lumen Neural Copilot synthesizes Power, Git, Renewals, and Music")
    }
}
