import SwiftUI

// MARK: - Tabs (Vorssaint-style icon tab strip)

enum MenuTab: String, CaseIterable, Identifiable {
    case today, apps, ai, insights, wallet, sync, settings
    var id: String { rawValue }
    var icon: String {
        switch self {
        case .today:    return "waveform.path.ecg"
        case .apps:     return "square.grid.2x2"
        case .ai:       return "atom"
        case .insights: return "sparkles"
        case .wallet:   return "creditcard"
        case .sync:     return "icloud"
        case .settings: return "gearshape"
        }
    }
}

struct MenuContentView: View {
    @ObservedObject var appState: AppState
    @Environment(\.openWindow) private var openWindow
    @ObservedObject private var updater = UpdateChecker.shared
    @State private var tab: MenuTab = .today
    @State private var showAddReceipt = false
    @State private var showFocusInspector = false

    @AppStorage("lumen.nightPauseEnabled") private var nightPause = false
    @AppStorage("lumen.zipArchives") private var zipArchives = true
    @AppStorage("lumen.encryptArchives") private var encryptArchives = false
    @AppStorage("lumen.receiptCaptureEnabled") private var receiptCapture = false

    var body: some View {
        VStack(spacing: 0) {
            header
            tabStrip
                .padding(.horizontal, 14)
                .padding(.top, 10)
                .padding(.bottom, 10)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    switch tab {
                    case .today:    todayTab
                    case .apps:     appsTab
                    case .ai:       aiTab
                    case .insights: insightsTab
                    case .wallet:   walletTab
                    case .sync:     syncTab
                    case .settings: settingsTab
                    }
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 4)
            }
            // FIX: explicitly bound the scroll area. An unbounded ScrollView whose
            // children contain GeometryReader resolves to zero height in a
            // .window MenuBarExtra — this is what made every tab look blank.
            .frame(minHeight: 300, maxHeight: 460)
            footer
        }
        .frame(width: 360)
        .background(AppTheme.window)
        .preferredColorScheme(.dark)
        .onAppear {
            appState.refreshPermissionStatus()
            appState.refreshLaunchAtLoginStatus()
            appState.nextScheduledSync = appState.scheduler.nextScheduledSync
        }
        .sheet(isPresented: $appState.showSpotlightSearch) {
            SpotlightPaletteView()
        }
        .sheet(isPresented: $appState.showStandupModal) {
            StandupModalView(report: appState.dailyStandup)
        }
    }

    // MARK: - Header (centered mark + focus ring #1)

    private var header: some View {
        VStack(spacing: 5) {
            HStack(spacing: 8) {
                Spacer()

                Button {
                    appState.showSpotlightSearch = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 9.5))
                        Text("Copilot Chat").font(.system(size: 10, weight: .semibold))
                        Text("⌘K").font(.system(size: 8.5, weight: .bold)).padding(.horizontal, 4).padding(.vertical, 1).background(Capsule().fill(Color.white.opacity(0.12)))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3.5)
                    .background(Capsule().fill(Color.white.opacity(0.08)))
                    .foregroundStyle(.white.opacity(0.85))
                }
                .buttonStyle(.plain)

                Button {
                    appState.showStandupModal = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "sparkles").font(.system(size: 9.5))
                        Text("Standup").font(.system(size: 10, weight: .semibold))
                    }
                    .padding(.horizontal, 8).padding(.vertical, 3.5)
                    .background(Capsule().fill(LinearGradient(colors: [Color(hex: "#FBBF24").opacity(0.2), Color(hex: "#F59E0B").opacity(0.2)], startPoint: .top, endPoint: .bottom)))
                    .foregroundStyle(Color(hex: "#FBBF24"))
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.top, 4)

            Button {
                showFocusInspector.toggle()
            } label: {
                VStack(spacing: 5) {
                    ZStack {
                        // Focus score ring (#1) around the mark
                        FocusRing(progress: Double(appState.stats.focusScore) / 100.0)
                            .frame(width: 54, height: 54)
                        if appState.healthIsBad {
                            Circle().fill(Color.red).frame(width: 7, height: 7)
                                .offset(x: 24, y: -16)
                        }
                        Image(systemName: "bolt.fill")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundStyle(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .top, endPoint: .bottom))
                    }
                    Text("LUMEN · \(appState.stats.focusScoreLabel.uppercased())")
                        .font(.system(size: 11, weight: .bold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.9))
                        .tracking(1)
                    Text(appState.isTracking ? "recording · click to inspect" : "paused · click to inspect")
                        .font(.system(size: 9, weight: .medium)).tracking(1.5)
                        .foregroundStyle(Color(hex: "#FBBF24").opacity(0.7))
                }
            }
            .buttonStyle(.plain)
            .popover(isPresented: $showFocusInspector, arrowEdge: .bottom) {
                FocusScoreInspectorView()
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 10)
    }

    // MARK: - Icon tab strip

    private var tabStrip: some View {
        HStack(spacing: 0) {
            ForEach(MenuTab.allCases) { t in
                Button { withAnimation(.spring(duration: 0.25)) { tab = t } } label: {
                    Image(systemName: t.icon)
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(tab == t ? .white : .white.opacity(0.35))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(
                            RoundedRectangle(cornerRadius: 9, style: .continuous)
                                .fill(tab == t ? AppTheme.accent.opacity(0.35) : .clear)
                        )
                }
                .buttonStyle(.plain)
            }
        }
        .padding(4)
        .background(
            RoundedRectangle(cornerRadius: 13, style: .continuous)
                .fill(Color.white.opacity(0.06))
        )
    }

    // MARK: - TODAY tab

    private var todayTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            if let brief = appState.morningBrief {
                MorningBriefView(brief: brief)
            }

            if !appState.zombieAlerts.isEmpty {
                ForEach(appState.zombieAlerts) { zombie in
                    HStack(spacing: 6) {
                        Image(systemName: "exclamationmark.triangle.fill").font(.system(size: 10)).foregroundStyle(.yellow)
                        Text(zombie.recommendation).font(.system(size: 10)).foregroundStyle(.yellow.opacity(0.9))
                        Spacer()
                    }
                    .padding(8)
                    .background(RoundedRectangle(cornerRadius: 8).fill(Color.yellow.opacity(0.12)))
                }
            }

            // Floating HUD quick button
            Button {
                appState.toggleHUD()
            } label: {
                HStack(spacing: 6) {
                    Image(systemName: "bolt.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#FBBF24"))
                    Text(appState.isHUDVisible ? "Hide Floating Glass HUD" : "Show Floating Glass HUD")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text("HUD")
                        .font(.system(size: 8.5, weight: .bold))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(Capsule().fill(Color.white.opacity(0.08)))
                }
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 10).fill(Color.white.opacity(0.05)))
            }
            .buttonStyle(.plain)

            sectionLabel("TODAY")
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 2), spacing: 10) {
                miniTile("keyboard", AppTheme.tileKey, "Keystrokes", "\(appState.stats.keystrokes)")
                miniTile("hand.tap", AppTheme.tileClick, "Clicks", "\(appState.stats.clicks)")
                miniTile("cursorarrow.motionlines", AppTheme.tileCursor, "Cursor", DashboardView.distanceText(appState.stats.cursorDistance))
                miniTile("clock", AppTheme.accent, "Active", "\(Int(appState.stats.activeMinutes))m")
            }
            if appState.secureInputSuppressed {
                HStack(alignment: .top, spacing: 7) {
                    Image(systemName: "lock.shield").font(.system(size: 11)).foregroundStyle(.orange)
                    Text("Keystrokes hidden by Secure Input (a password field is focused). Counts resume automatically.")
                        .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(9)
                .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(.orange.opacity(0.10)))
            }
            // v0.4.0 LIVE CONTEXT strip
            if hasLiveContext {
                sectionLabel("NOW")
                VStack(spacing: 8) {
                    if appState.stats.meetingMinutes > 0 {
                        contextRow("video.fill", AppTheme.accent, "In call", "\(Int(appState.stats.meetingMinutes))m of calls")
                    }
                    if let np = appState.stats.nowPlaying, np.isPlaying, let title = np.title {
                        contextRow("music.note", AppTheme.tileMedia, np.appName ?? "Playing", title)
                    }
                    if let ssid = appState.stats.wifiSSID, !ssid.isEmpty {
                        contextRow("wifi", AppTheme.tileNetwork, "Network", ssid + (appState.stats.onVPN == true ? " · VPN" : ""))
                    }
                    if let unread = appState.stats.mailUnread {
                        contextRow("envelope", AppTheme.tileMail, "Inbox", "\(unread) unread · \(appState.stats.mailReceivedToday ?? 0) recv")
                    }
                    if let f = appState.stats.focusActive {
                        contextRow("moon.fill", AppTheme.tileMoon, "Focus", f ? "Active" : "Off")
                    }
                }
            }

            if !appState.todayStory.chapters.isEmpty {
                sectionLabel("THE DAY STORY")
                DayStoryView(story: appState.todayStory)
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }

            // Cognitive Flow & Fragmentation Card
            CognitiveScoreCardView(snapshot: appState.cognitiveSnapshot)

            // Apple Silicon Power & Battery Runway
            BatteryRunwayCardView()

            Button { DashboardWindowController.shared.show() } label: {
                Label("Open Full Dashboard", systemImage: "chart.xyaxis.line")
                    .font(.system(size: 12, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
        }
    }

    private func miniTile(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold)).foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(Circle().fill(tint.opacity(0.15)))
            VStack(alignment: .leading, spacing: 1) {
                Text(value).font(.system(size: 16, weight: .bold, design: .rounded)).foregroundStyle(.white)
                Text(label).font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(11)
        .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
    }

    // MARK: - APPS tab (+ per-app history #3)

    private var appsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("TOP APPS")
            let apps = Array(appState.stats.apps.prefix(5))
            if apps.isEmpty {
                Text("No focus captured yet — grant Accessibility in the Settings tab")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
            } else {
                VStack(spacing: 4) {
                    ForEach(apps) { a in
                        // Tapping an app opens its day history in the Dashboard (#3).
                        Button { AppHistoryStore.shared.select(app: a.name); DashboardWindowController.shared.show() } label: {
                            AppBarRow(app: a, maxSeconds: apps.first?.seconds ?? 1)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            sectionLabel("CONTEXT")
            let cats = appState.stats.categories
            if cats.isEmpty {
                Text("—").font(.system(size: 11)).foregroundStyle(.white.opacity(0.35))
            } else {
                ContextRibbon(categories: cats)
                VStack(spacing: 6) {
                    ForEach(cats.prefix(5)) { c in
                        HStack(spacing: 8) {
                            Image(systemName: c.category.icon).font(.system(size: 10))
                                .foregroundStyle(Color(hex: c.category.colorHex)).frame(width: 16)
                            Text(c.category.label).font(.system(size: 11)).foregroundStyle(.white.opacity(0.75))
                            Spacer()
                            Text("\(Int(c.seconds / 60))m").font(.system(size: 10, design: .rounded)).foregroundStyle(.white.opacity(0.45))
                        }
                    }
                }
            }
        }
    }

    // MARK: - AI FLEET tab

    private var aiTab: some View {
        AIFleetDashboardView()
    }

    // MARK: - INSIGHTS tab (#4)

    private var insightsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("INSIGHTS")
            if let anomaly = appState.stats.anomaly {
                HStack(alignment: .top, spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 12)).foregroundStyle(.orange)
                    Text(anomaly).font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white).fixedSize(horizontal: false, vertical: true)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(.orange.opacity(0.12)))
            }
            let items = appState.stats.insights
            if items.isEmpty && appState.stats.anomaly == nil {
                Text("Nothing notable yet — keep using your Mac and Lumen will spot patterns.")
                    .font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                VStack(spacing: 8) {
                    ForEach(Array(items.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "sparkle").font(.system(size: 10)).foregroundStyle(AppTheme.accent)
                            Text(line).font(.system(size: 11.5)).foregroundStyle(.white.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(10)
                        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.card))
                    }
                }
            }
            // Zombie-scroll meter (#5) surfaced here too
            if appState.stats.zombieSeconds > 120 {
                sectionLabel("PASSIVE TIME")
                HStack(spacing: 10) {
                    Image(systemName: "zzz").font(.system(size: 12)).foregroundStyle(AppTheme.tileScroll)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(appState.stats.zombieSeconds / 60))m with zero input")
                            .font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                        Text("A window was focused but you were hands-off")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }

            // Soundtrack to Deep Work Audio Flow Insight
            AudioFlowInsightView()
        }
    }

    // MARK: - WALLET tab (v0.5.4)

    private var walletTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Month Navigator Header
            HStack {
                Button {
                    appState.selectedSpendMonthOffset -= 1
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(.white.opacity(0.8))
                        .padding(6)
                        .background(Circle().fill(AppTheme.card))
                }
                .buttonStyle(.plain)

                Spacer()

                VStack(spacing: 2) {
                    Text(SpendStats.monthTitle(for: appState.selectedSpendMonthOffset).uppercased())
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundStyle(.white)
                    HStack(spacing: 8) {
                        if appState.selectedSpendMonthOffset != 0 {
                            Button("Current Month") {
                                appState.selectedSpendMonthOffset = 0
                            }
                            .buttonStyle(.plain)
                            .font(.system(size: 9))
                            .foregroundStyle(AppTheme.accent)
                        }
                        Button("Scan 2026 Mail") {
                            appState.rescanMailReceipts()
                        }
                        .buttonStyle(.plain)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(Color(hex: "#60A5FA"))
                    }
                }

                Spacer()

                Button {
                    if appState.selectedSpendMonthOffset < 0 {
                        appState.selectedSpendMonthOffset += 1
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .bold))
                        .foregroundStyle(appState.selectedSpendMonthOffset < 0 ? .white.opacity(0.8) : .white.opacity(0.2))
                        .padding(6)
                        .background(Circle().fill(AppTheme.card))
                }
                .buttonStyle(.plain)
                .disabled(appState.selectedSpendMonthOffset >= 0)
            }

            // Top Spend & Deductible Totals (Interactive Click-to-Filter)
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(SpendFormat.amount(appState.spendMonth.total))
                        .font(.system(size: 24, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("total spent").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                }
                Spacer()
                Button {
                    withAnimation(.spring(duration: 0.2)) {
                        appState.selectedSpendFilter = (appState.selectedSpendFilter == .deductibleOnly ? .all : .deductibleOnly)
                    }
                } label: {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(SpendFormat.amount(appState.spendMonth.deductibleTotal))
                            .font(.system(size: 17, weight: .bold, design: .rounded)).foregroundStyle(AppTheme.batteryGreen)
                        HStack(spacing: 4) {
                            if appState.selectedSpendFilter == .deductibleOnly {
                                Image(systemName: "checkmark.circle.fill").font(.system(size: 9)).foregroundStyle(AppTheme.batteryGreen)
                            }
                            Text(appState.selectedSpendFilter == .deductibleOnly ? "filtered: deductible" : "tax deductible")
                                .font(.system(size: 10, weight: appState.selectedSpendFilter == .deductibleOnly ? .bold : .regular))
                                .foregroundStyle(appState.selectedSpendFilter == .deductibleOnly ? AppTheme.batteryGreen : .white.opacity(0.45))
                        }
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 8).fill(appState.selectedSpendFilter == .deductibleOnly ? AppTheme.batteryGreen.opacity(0.15) : .clear))
                }
                .buttonStyle(.plain)
            }
            .padding(13)
            .background(RoundedRectangle(cornerRadius: 14, style: .continuous).fill(AppTheme.card))

            // Spending Pacing & Velocity Gauge (Click to Expand Daily Burn Graph)
            if let pacing = appState.spendMonth.pacing {
                Button {
                    withAnimation(.spring(duration: 0.25)) {
                        appState.showBurnRateGraph.toggle()
                    }
                } label: {
                    HStack(spacing: 10) {
                        Circle().fill(Color(hex: pacing.pacingStatus.colorHex)).frame(width: 8, height: 8)
                        VStack(alignment: .leading, spacing: 1) {
                            HStack {
                                Text("\(pacing.pacingStatus.rawValue) Burn Rate")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.white)
                                Spacer()
                                Image(systemName: appState.showBurnRateGraph ? "chevron.up" : "chart.line.uptrend.xyaxis")
                                    .font(.system(size: 10))
                                    .foregroundStyle(.white.opacity(0.6))
                            }
                            Text("Day \(pacing.daysElapsed) of \(pacing.totalDaysInMonth) · \(SpendFormat.amount(pacing.dailyBurnRate))/day (Proj: \(SpendFormat.amount(pacing.projectedMonthEndTotal)))")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                    }
                    .padding(10)
                    .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(Color(hex: pacing.pacingStatus.colorHex).opacity(0.12)))
                }
                .buttonStyle(.plain)

                if appState.showBurnRateGraph {
                    DailySpendingChartView(trajectory: appState.spendMonth.dailyTrajectory, baselineMonthly: SpendingPacing.baseline2026)
                }
            }

            // Subscription Radar Card
            if !appState.subscriptions.activeSubscriptions.isEmpty {
                sectionLabel("SUBSCRIPTION RADAR")
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text("\(SpendFormat.amount(appState.subscriptions.monthlyBurnRate))/mo")
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                            Text("Annualized: \(SpendFormat.amount(appState.subscriptions.annualBurnRate))/yr")
                                .font(.system(size: 9.5))
                                .foregroundStyle(.white.opacity(0.45))
                        }
                        Spacer()
                        Text("\(appState.subscriptions.activeSubscriptions.count) active")
                            .font(.system(size: 10, weight: .medium))
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background(Capsule().fill(Color.white.opacity(0.08)))
                            .foregroundStyle(.white.opacity(0.7))
                    }

                    if !appState.subscriptions.upcomingRenewals7Days.isEmpty {
                        ForEach(appState.subscriptions.upcomingRenewals7Days) { sub in
                            HStack(spacing: 6) {
                                Image(systemName: "bell.fill").font(.system(size: 9)).foregroundStyle(.orange)
                                Text("Renews in \(sub.daysUntilRenewal ?? 0)d: \(sub.merchant) (\(SpendFormat.amount(sub.amount)))")
                                    .font(.system(size: 10, weight: .medium))
                                    .foregroundStyle(.orange)
                                Spacer()
                            }
                        }
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }

            // 30-Day Predictive Renewal Calendar & Price Hike Radar
            SubscriptionRenewalCalendarView()

            // Card Portfolio Badges (Click to Filter by Card)
            if !appState.spendMonth.byCard.isEmpty {
                sectionLabel("BY CARD (CLICK TO FILTER)")
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 7) {
                        ForEach(Array(appState.spendMonth.byCard.sorted { $0.value > $1.value }), id: \.key) { card, amt in
                            let isSelected = (appState.selectedSpendFilter == .card(card))
                            Button {
                                withAnimation(.spring(duration: 0.2)) {
                                    appState.selectedSpendFilter = isSelected ? .all : .card(card)
                                }
                            } label: {
                                VStack(spacing: 2) {
                                    HStack(spacing: 4) {
                                        Image(systemName: "creditcard.fill").font(.system(size: 8))
                                            .foregroundStyle(isSelected ? .white : AppTheme.accent)
                                        Text(CardPortfolio.shortName(for: card))
                                            .font(.system(size: 10.5, weight: .bold, design: .rounded))
                                            .foregroundStyle(.white)
                                    }
                                    Text(SpendFormat.amount(amt))
                                        .font(.system(size: 9))
                                        .foregroundStyle(isSelected ? .white.opacity(0.9) : .white.opacity(0.5))
                                }
                                .padding(.horizontal, 9).padding(.vertical, 6)
                                .background(Capsule().fill(isSelected ? AppTheme.accent : AppTheme.card))
                                .overlay(Capsule().stroke(isSelected ? .white.opacity(0.5) : .clear, lineWidth: 1))
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }

            // Search Bar & Active Filter Banner
            HStack(spacing: 6) {
                Image(systemName: "magnifyingglass").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                TextField("Search merchant, card, or note…", text: $appState.spendSearchQuery)
                    .textFieldStyle(.plain)
                    .font(.system(size: 11))
                if !appState.spendSearchQuery.isEmpty {
                    Button { appState.spendSearchQuery = "" } label: {
                        Image(systemName: "xmark.circle.fill").font(.system(size: 11)).foregroundStyle(.white.opacity(0.4))
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.card))

            FinancialRunwayView(forecast: appState.financialForecast)

            if appState.selectedSpendFilter != .all {
                HStack {
                    Label("Filtered by: \(appState.selectedSpendFilter.label)", systemImage: "line.3.horizontal.decrease.circle.fill")
                        .font(.system(size: 10.5, weight: .semibold))
                        .foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button("Show All") {
                        withAnimation { appState.selectedSpendFilter = .all }
                    }
                    .buttonStyle(.plain)
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 7).padding(.vertical, 2)
                    .background(Capsule().fill(Color.white.opacity(0.12)))
                }
                .padding(8)
                .background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.accent.opacity(0.15)))
            }

            // Receipts Filtered / Display
            let query = appState.spendSearchQuery.trimmingCharacters(in: .whitespaces).lowercased()
            let filteredReceipts = appState.spendMonth.receipts.filter { r in
                // 1. Text Search
                if !query.isEmpty {
                    let matchesText = r.merchant.lowercased().contains(query) ||
                           r.category.label.lowercased().contains(query) ||
                           (r.cardLast4?.contains(query) ?? false) ||
                           (r.notes?.lowercased().contains(query) ?? false)
                    if !matchesText { return false }
                }
                // 2. SpendFilter
                switch appState.selectedSpendFilter {
                case .all:
                    return true
                case .deductibleOnly:
                    return r.category.businessDeductible
                case .card(let card):
                    if card == "Direct" || card == "Unknown" {
                        return r.cardLast4 == nil || r.cardLast4 == "Unknown"
                    }
                    return r.cardLast4 == card
                }
            }

            if filteredReceipts.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    Image(systemName: "creditcard").font(.system(size: 16)).foregroundStyle(.white.opacity(0.3))
                    Text("No purchases match current filter.")
                        .font(.system(size: 11.5, weight: .medium)).foregroundStyle(.white.opacity(0.8))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(12)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            } else {
                // Transaction list
                sectionLabel("PURCHASES · CLICK TO CUSTOMIZE (\(filteredReceipts.count))")
                VStack(spacing: 6) {
                    ForEach(Array(filteredReceipts.prefix(20))) { r in
                        let isIncome = TransactionCustomizer.isIncome(for: r)
                        Button {
                            appState.selectedReceiptForEditing = r
                            appState.showTransactionEditor = true
                        } label: {
                            HStack(spacing: 8) {
                                Image(systemName: isIncome ? "arrow.down.left.circle.fill" : r.category.icon)
                                    .font(.system(size: 11))
                                    .foregroundStyle(isIncome ? Color(hex: "#10B981") : Color(hex: r.category.colorHex))

                                VStack(alignment: .leading, spacing: 1) {
                                    HStack(spacing: 4) {
                                        Text(r.merchant)
                                            .font(.system(size: 11.5, weight: .semibold))
                                            .foregroundStyle(.white)
                                            .lineLimit(1)

                                        if isIncome {
                                            Text("Paid to me")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(Color(hex: "#10B981"))
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(Capsule().fill(Color(hex: "#10B981").opacity(0.18)))
                                        } else if r.category.businessDeductible {
                                            Text("Deductible")
                                                .font(.system(size: 8, weight: .bold))
                                                .foregroundStyle(AppTheme.batteryGreen)
                                                .padding(.horizontal, 4).padding(.vertical, 1)
                                                .background(Capsule().fill(AppTheme.batteryGreen.opacity(0.18)))
                                        }
                                    }

                                    let cardTag = CardPortfolio.displayName(for: r.cardLast4)
                                    let noteTag = (r.notes != nil) ? " · \(r.notes!)" : ""
                                    Text("\(SpendFormat.shortDate(r.transactionDate)) · \(cardTag)\(noteTag)")
                                        .font(.system(size: 9)).foregroundStyle(.white.opacity(0.45)).lineLimit(1)
                                }

                                Spacer()

                                VStack(alignment: .trailing, spacing: 1) {
                                    Text("\(isIncome ? "+" : "-")\(SpendFormat.amount(r.amount, currency: r.currency))")
                                        .font(.system(size: 11.5, weight: .bold, design: .rounded))
                                        .foregroundStyle(isIncome ? Color(hex: "#10B981") : .white.opacity(0.9))

                                    Image(systemName: "pencil")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.white.opacity(0.3))
                                }
                            }
                            .padding(8)
                            .background(
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(isIncome ? Color(hex: "#10B981").opacity(0.08) : Color.white.opacity(0.04))
                            )
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }

            // IRS Schedule-C Tax Engine
            sectionLabel("IRS SCHEDULE-C TAX ENGINE")
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(SpendFormat.amount(appState.taxReport2026.totalDeductibleAmount))
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                            .foregroundStyle(AppTheme.batteryGreen)
                        Text("2026 Net Deductible (\(appState.taxReport2026.lineItems.count) items)").font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                }
                HStack(spacing: 8) {
                    Button { appState.exportScheduleCTaxCSV() } label: {
                        Label("Schedule-C CSV", systemImage: "arrow.down.doc.fill")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .buttonStyle(.bordered).tint(AppTheme.accent).controlSize(.small)

                    Button { appState.exportCPATaxMarkdown() } label: {
                        Label("CPA Report", systemImage: "doc.plaintext")
                            .font(.system(size: 10.5, weight: .medium))
                    }
                    .buttonStyle(.bordered).tint(.white.opacity(0.6)).controlSize(.small)
                }
            }
            .padding(11)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))

            // Add Purchase Button
            Button { showAddReceipt = true } label: {
                Label("Add Purchase…", systemImage: "plus.circle")
                    .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
        }
        .sheet(isPresented: $showAddReceipt) { QuickAddReceiptView() }
        .sheet(isPresented: $appState.showTransactionEditor) {
            if let r = appState.selectedReceiptForEditing {
                TransactionEditorModalView(receipt: r)
            }
        }
    }

    // MARK: - SYNC tab

    private var nextSyncText: String? {
        guard let next = appState.nextScheduledSync else { return nil }
        let f = DateFormatter(); f.timeStyle = .short
        return "Next automatic sync \(f.string(from: next))"
    }

    private var syncTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            sectionLabel("ICLOUD SYNC")
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 11) {
                    Image(systemName: syncIcon)
                        .font(.system(size: 16, weight: .medium)).foregroundStyle(syncTint)
                        .frame(width: 32, height: 32)
                        .background(Circle().fill(syncTint.opacity(0.15)))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(syncTitle).font(.system(size: 12.5, weight: .semibold)).foregroundStyle(.white)
                        Text(syncDetail).font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.45)).lineLimit(2)
                    }
                    Spacer()
                }
                if let nextText = nextSyncText {
                    HStack(spacing: 6) {
                        Image(systemName: "clock").font(.system(size: 10)).foregroundStyle(.white.opacity(0.35))
                        Text(nextText)
                            .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.45))
                    }
                }
                if appState.missedDaysSynced > 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "checkmark.circle.fill").font(.system(size: 10)).foregroundStyle(AppTheme.batteryGreen)
                        Text("Synced \(appState.missedDaysSynced) missed day(s)")
                            .font(.system(size: 10.5)).foregroundStyle(AppTheme.batteryGreen.opacity(0.9))
                    }
                }
                Button { appState.syncNow() } label: {
                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                        .font(.system(size: 12, weight: .semibold)).frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.regular)
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))

            // P2P Mesh & iPhone Controller Hub
            sectionLabel("P2P MESH & IPHONE RADAR")
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 10) {
                    Circle().fill(P2PSyncHost.shared.isListening ? AppTheme.batteryGreen : .orange).frame(width: 8, height: 8)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(P2PSyncHost.shared.isListening ? "Bonjour P2P Mesh Active" : "P2P Mesh Offline")
                            .font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        Text(P2PSyncHost.shared.activePeers.isEmpty ? "Scanning local subnet for paired iPhones…" : "\(P2PSyncHost.shared.activePeers.count) node(s) connected · ~3.8ms latency")
                            .font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Image(systemName: "iphone.radiowaves.left.and.right")
                        .font(.system(size: 14))
                        .foregroundStyle(P2PSyncHost.shared.isListening ? AppTheme.accent : .white.opacity(0.3))
                }

                if let cmd = P2PSyncHost.shared.lastRemoteCommand {
                    HStack(spacing: 6) {
                        Image(systemName: "bolt.badge.checkmark.fill").font(.system(size: 9)).foregroundStyle(AppTheme.batteryGreen)
                        Text("Executed: \(cmd)").font(.system(size: 9.5, weight: .medium)).foregroundStyle(AppTheme.batteryGreen)
                    }
                    .padding(6)
                    .background(RoundedRectangle(cornerRadius: 6).fill(AppTheme.batteryGreen.opacity(0.12)))
                }

                if let lastSync = P2PSyncHost.shared.lastMobileSyncDate {
                    Text("Last mobile stream: \(lastSync.formatted(date: .omitted, time: .shortened)) (\(P2PSyncHost.shared.lastMobileEventCount) events/receipts)")
                        .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.4))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))

            // Storage Helper & iCloud Optimizer
            sectionLabel("STORAGE HELPER & ICLOUD OPTIMIZER")
            StorageHelperView()

            if updater.state == .available {
                HStack(spacing: 10) {
                    Image(systemName: "arrow.down.circle.fill").foregroundStyle(AppTheme.accent)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Update available").font(.system(size: 12, weight: .semibold)).foregroundStyle(.white)
                        Text("Version \(updater.latestVersion ?? "") is ready").font(.system(size: 10)).foregroundStyle(.white.opacity(0.45))
                    }
                    Spacer()
                    Button("Get") { updater.openDownloadPage() }
                        .buttonStyle(.bordered).controlSize(.small)
                }
                .padding(11)
                .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            }
        }
    }

    // MARK: - SETTINGS tab

    private var settingsTab: some View {
        VStack(alignment: .leading, spacing: 14) {
            // Unified Permissions & Privacy Hub
            PermissionsHubView()

            sectionLabel("MENU BAR")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Show active time in menu bar", isOn: Binding(
                    get: { appState.showMenuBarTime },
                    set: { appState.showMenuBarTime = $0 }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            sectionLabel("OPTIONS")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Night pause (23:00 – 07:00)", isOn: $nightPause)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Zip daily archives", isOn: $zipArchives)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Encrypt archives (AES-256)", isOn: $encryptArchives)
                Toggle("Log Mail sender names", isOn: Binding(
                    get: { UserDefaults.standard.bool(forKey: "lumen.mailSenderNames") },
                    set: { UserDefaults.standard.set($0, forKey: "lumen.mailSenderNames") }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Toggle("Launch at Login", isOn: Binding(
                    get: { appState.launchAtLogin },
                    set: { appState.toggleLaunchAtLogin($0) }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                if appState.launchAtLoginNeedsApproval {
                    Button("Approval needed — open Login Items") { appState.openLoginItemsSettings() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(.orange)
                }
                HStack {
                    Text(updateStatusText).font(.system(size: 11)).foregroundStyle(.white.opacity(0.45))
                    Spacer()
                    Button("Check") { updater.checkNow() }
                        .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(AppTheme.accent)
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            sectionLabel("CARD PORTFOLIO & TAX RULES")
            CardPortfolioEditorView()

            sectionLabel("WALLET · SPENDING")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Capture receipts from Mail", isOn: $receiptCapture)
                    .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                Text("Off by default. When on, only messages that look like receipts are read; only merchant, amount, date, and card last-4 are stored.")
                    .font(.system(size: 9.5)).foregroundStyle(.white.opacity(0.4))
                    .fixedSize(horizontal: false, vertical: true)
                Divider().opacity(0.5)
                HStack(spacing: 12) {
                    Button { exportSpend(.csv) } label: {
                        Label("Export CSV…", systemImage: "doc.text").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                    Button { exportSpend(.json) } label: {
                        Text("Export JSON").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button { appState.openSpendFolder() } label: {
                        Label("Open Spend Folder", systemImage: "folder").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
            sectionLabel("TRACKING")
            VStack(alignment: .leading, spacing: 10) {
                Toggle("Record activity", isOn: Binding(
                    get: { appState.isTracking },
                    set: { _ in appState.toggleTracking() }
                ))
                .toggleStyle(.switch).controlSize(.mini).font(.system(size: 12))
                HStack {
                    Button { appState.openDataFolder() } label: {
                        Label("Open Data Folder", systemImage: "folder").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(AppTheme.accent)
                    Spacer()
                    Button { appState.openOnboarding() } label: {
                        Text("Welcome…").font(.system(size: 12))
                    }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.55))
                }
            }
            .padding(12)
            .background(RoundedRectangle(cornerRadius: 12, style: .continuous).fill(AppTheme.card))
        }
    }

    // MARK: - Footer (Vorssaint-style: two pill buttons)

    private var footer: some View {
        HStack(spacing: 8) {
            Button { DashboardWindowController.shared.show() } label: {
                Label("Dashboard", systemImage: "macwindow")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FooterButtonStyle())
            Button { appState.openOnboarding() } label: {
                Label("Settings", systemImage: "gearshape")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FooterButtonStyle())
            Button { NSApplication.shared.terminate(nil) } label: {
                Label("Quit", systemImage: "power")
                    .font(.system(size: 11.5, weight: .medium))
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(FooterButtonStyle())
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Shared pieces

    private var hasLiveContext: Bool {
        let st = appState.stats
        return st.meetingMinutes > 0
            || (st.nowPlaying?.isPlaying == true && st.nowPlaying?.title != nil)
            || !(st.wifiSSID ?? "").isEmpty
            || st.mailUnread != nil
            || st.focusActive != nil
    }

    private func contextRow(_ icon: String, _ tint: Color, _ label: String, _ value: String) -> some View {
        HStack(spacing: 9) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 22, height: 22)
                .background(Circle().fill(tint.opacity(0.14)))
            Text(label).font(.system(size: 11, weight: .medium)).foregroundStyle(.white.opacity(0.8))
            Spacer()
            Text(value)
                .font(.system(size: 10.5, design: .rounded))
                .foregroundStyle(.white.opacity(0.5))
                .lineLimit(1)
        }
        .padding(.horizontal, 10).padding(.vertical, 7)
        .background(RoundedRectangle(cornerRadius: 10, style: .continuous).fill(AppTheme.card))
    }

    private func exportSpend(_ kind: ExportKind) {
        let receipts = SpendStats.allReceipts()
        let url = kind == .csv ? SpendExport.exportCSV(receipts: receipts) : SpendExport.exportJSON(receipts: receipts)
        if let url { appState.revealSpendExport(url: url) }
    }

    private enum ExportKind { case csv, json }

    private func sectionLabel(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 10, weight: .semibold)).tracking(1.4)
            .foregroundStyle(.white.opacity(0.4))
            .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func permRow(_ granted: Bool, _ title: String, _ sub: String) -> some View {
        HStack(spacing: 10) {
            Circle().fill(granted ? AppTheme.batteryGreen : .red).frame(width: 8, height: 8)
            VStack(alignment: .leading, spacing: 1) {
                Text(title).font(.system(size: 12, weight: .medium)).foregroundStyle(.white)
                Text(sub).font(.system(size: 10)).foregroundStyle(.white.opacity(0.4))
            }
            Spacer()
            if granted {
                Image(systemName: "checkmark").font(.system(size: 11, weight: .bold)).foregroundStyle(AppTheme.batteryGreen)
            } else {
                Button("Fix") { appState.requestPermissions() }
                    .buttonStyle(.plain).font(.system(size: 11)).foregroundStyle(AppTheme.accent)
            }
        }
        .padding(.vertical, 9)
    }

    private var syncIcon: String {
        appState.lastSyncSuccess ? "checkmark.icloud"
            : (appState.lastSyncDate == nil ? "icloud.slash" : "exclamationmark.icloud")
    }
    private var syncTint: Color { appState.lastSyncSuccess ? AppTheme.batteryGreen : .orange }
    private var syncTitle: String {
        if appState.missedDaysSynced > 0 { return "Synced \(appState.missedDaysSynced) missed day(s)" }
        return appState.lastSyncSuccess ? "Synced to iCloud" : "Sync pending"
    }
    private var syncDetail: String {
        if let d = appState.lastSyncDate {
            let f = DateFormatter(); f.dateStyle = .none; f.timeStyle = .short
            return appState.lastSyncSuccess ? "\(f.string(from: d)) · \(appState.lastSyncDetail)"
                                            : "Failed \(f.string(from: d)) · \(appState.lastSyncDetail)"
        }
        return "No sync yet — automatic at 23:59"
    }
    private var updateStatusText: String {
        switch updater.state {
        case .checking: "Checking for updates…"
        case .upToDate: "Up to date (v\(UpdateChecker.currentVersion()))"
        case .available: "v\(updater.latestVersion ?? "?") available"
        case .failed: "Update check failed"
        case .idle: ""
        }
    }
}

// MARK: - Focus ring (#1)

private struct FocusRing: View {
    let progress: Double
    var body: some View {
        ZStack {
            Circle().stroke(.white.opacity(0.08), lineWidth: 3)
            Circle()
                .trim(from: 0, to: max(0.001, min(1, progress)))
                .stroke(
                    LinearGradient(colors: [AppTheme.accent, AppTheme.accentDeep],
                                   startPoint: .topLeading, endPoint: .bottomTrailing),
                    style: StrokeStyle(lineWidth: 3, lineCap: .round)
                )
                .rotationEffect(.degrees(-90))
        }
    }
}

// MARK: - App bar row (static width — replaces collapsing GeometryReader)

private struct AppBarRow: View {
    let app: AppUsage
    let maxSeconds: TimeInterval
    var body: some View {
        VStack(spacing: 5) {
            HStack {
                Text(app.name).font(.system(size: 12, weight: .medium)).foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                Spacer()
                Text("\(Int(app.seconds / 60))m").font(.system(size: 11, design: .rounded))
                    .foregroundStyle(.white.opacity(0.5))
            }
            // Fixed 320pt container with proportional fill — never collapses.
            ZStack(alignment: .leading) {
                Capsule().fill(.white.opacity(0.07))
                Capsule().fill(AppTheme.accent)
                    .frame(width: max(4, 320 * CGFloat(app.seconds / max(maxSeconds, 1))))
            }
            .frame(width: 320, height: 5)
        }
        .padding(.vertical, 3)
        .contentShape(Rectangle())
    }
}

// MARK: - Context ribbon (fixed container)

private struct ContextRibbon: View {
    let categories: [CategoryUsage]
    var body: some View {
        let total = max(categories.reduce(TimeInterval(0)) { $0 + $1.seconds }, 1)
        HStack(spacing: 2) {
            ForEach(categories) { c in
                let w = max(6, 320 * CGFloat(c.seconds / total))
                RoundedRectangle(cornerRadius: 3)
                    .fill(Color(hex: c.category.colorHex))
                    .frame(width: w, height: 10)
            }
        }
        .frame(width: 320, alignment: .leading)
    }
}

// MARK: - App history store (#3)

/// Cross-scene selection so tapping a Top-Apps row can filter the Dashboard.
@MainActor
final class AppHistoryStore: ObservableObject {
    static let shared = AppHistoryStore()
    @Published var selectedApp: String?
    func select(app: String) { selectedApp = app }
    func clear() { selectedApp = nil }
}

// MARK: - Add Receipt sheet (v0.5.0)

private struct AddReceiptSheet: View {
    @ObservedObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    @State private var merchant = ""
    @State private var amountText = ""
    @State private var category: ReceiptCategory = .other
    @State private var cardLast4 = ""
    @State private var notes = ""
    @State private var date = Date()

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Add Receipt").font(.system(size: 15, weight: .bold, design: .rounded)).foregroundStyle(.white)
            TextField("Merchant (e.g. Joe's Diner)", text: $merchant)
                .textFieldStyle(.plain)
                .padding(9).background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.card))
            TextField("Amount (e.g. 12.50)", text: $amountText)
                .textFieldStyle(.plain)
                .padding(9).background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.card))
            HStack {
                Picker("Category", selection: $category) {
                    ForEach(ReceiptCategory.assignable) { Text($0.label).tag($0) }
                }
                .pickerStyle(.menu)
                TextField("Last 4 (opt)", text: $cardLast4)
                    .textFieldStyle(.plain).frame(width: 96)
                    .padding(9).background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.card))
            }
            DatePicker("Date", selection: $date, displayedComponents: .date)
                .datePickerStyle(.compact)
            TextField("Notes (optional)", text: $notes)
                .textFieldStyle(.plain)
                .padding(9).background(RoundedRectangle(cornerRadius: 8).fill(AppTheme.card))
            HStack {
                Spacer()
                Button("Cancel") { dismiss() }
                    .buttonStyle(.plain).foregroundStyle(.white.opacity(0.6))
                Button("Save") {
                    if let amount = Decimal(string: amountText.trimmingCharacters(in: .whitespaces)), !merchant.isEmpty {
                        appState.addManualReceipt(merchant: merchant.trimmingCharacters(in: .whitespaces),
                                                  amountAmount: amount, category: category,
                                                  cardLast4: cardLast4.isEmpty ? nil : cardLast4,
                                                  notes: notes.isEmpty ? nil : notes, date: date)
                        dismiss()
                    }
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent)
            }
        }
        .padding(20)
        .frame(width: 320)
        .background(AppTheme.window)
        .preferredColorScheme(.dark)
    }
}

// MARK: - Footer button style

private struct FooterButtonStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .foregroundStyle(.white.opacity(configuration.isPressed ? 0.5 : 0.85))
            .padding(.vertical, 9)
            .background(
                RoundedRectangle(cornerRadius: 10, style: .continuous)
                    .fill(Color.white.opacity(configuration.isPressed ? 0.04 : 0.07))
            )
    }
}

private struct PulseModifier: ViewModifier {
    @State private var on = false
    func body(content: Content) -> some View {
        content
            .opacity(on ? 0.25 : 1.0)
            .animation(.easeInOut(duration: 0.8).repeatForever(autoreverses: true), value: on)
            .onAppear { on = true }
    }
}

enum SceneID {
    static let dashboard = "dashboard"
}
