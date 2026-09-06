import SwiftUI

public struct StorageHelperView: View {
    @ObservedObject var appState = AppState.shared
    @State private var isOptimizing = false
    @State private var statusMessage: String? = nil
    @State private var selectedSection: Int = 0
    @State private var devBloatCandidates: [DeveloperProjectCandidate] = []
    @State private var radarStatus: iCloudRadarStatus = .healthy
    @State private var triagePlan: [TriageRuleItem] = []

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with Guardian Badge
            HStack {
                Label("iCloud Storage Super-Optimizer", systemImage: "icloud.and.arrow.up.fill")
                    .font(.system(size: 11.5, weight: .bold))
                    .foregroundStyle(Color(hex: "#5B8CFF"))
                Spacer()
                HStack(spacing: 4) {
                    Circle().fill(AppTheme.batteryGreen).frame(width: 6, height: 6)
                    Text("GUARDIAN ACTIVE")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(AppTheme.batteryGreen)
                }
                .padding(.horizontal, 6).padding(.vertical, 2)
                .background(Capsule().fill(AppTheme.batteryGreen.opacity(0.12)))
            }

            // Storage Overview Bar
            let s = appState.storageSnapshot
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Text("\(s.freeDiskFormatted) Free of \(s.totalDiskFormatted)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundStyle(s.diskUsagePercentage >= 90 ? .orange : .white)
                    Spacer()
                    Text("\(Int(s.diskUsagePercentage))% Used")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.white.opacity(0.5))
                }

                // Multi-Segment Gauge
                GeometryReader { geo in
                    let totalWidth = geo.size.width
                    let usedPct = min(1.0, max(0.0, Double(s.usedDiskBytes) / Double(max(1, s.totalDiskBytes))))
                    let reclaimPct = min(usedPct, Double(s.reclaimableBytes) / Double(max(1, s.totalDiskBytes)))
                    let nonReclaimPct = max(0.0, usedPct - reclaimPct)

                    HStack(spacing: 2) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(LinearGradient(colors: [Color(hex: "#4F46E5"), Color(hex: "#3B82F6")], startPoint: .leading, endPoint: .trailing))
                            .frame(width: max(4, totalWidth * nonReclaimPct))

                        if reclaimPct > 0 {
                            RoundedRectangle(cornerRadius: 3)
                                .fill(LinearGradient(colors: [Color(hex: "#FBBF24"), Color(hex: "#F59E0B")], startPoint: .leading, endPoint: .trailing))
                                .frame(width: max(4, totalWidth * reclaimPct))
                        }

                        RoundedRectangle(cornerRadius: 3)
                            .fill(Color.white.opacity(0.1))
                    }
                }
                .frame(height: 8)
                .clipShape(Capsule())
            }

            // 3-Metric Health Grid
            HStack(spacing: 6) {
                metricPill(title: "Reclaimable", value: s.reclaimableFormatted, color: Color(hex: "#FBBF24"))
                metricPill(title: "iCloud Ghost", value: s.iCloudEvictedFormatted, color: AppTheme.batteryGreen)
                metricPill(title: "Dev Bloat", value: devBloatTotalFormatted, color: Color(hex: "#F43F5E"))
            }

            // Master 1-Click All-in-One Turbo Sweep Button
            Button {
                runMasterSweepAction()
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "bolt.shield.fill")
                        .font(.system(size: 13, weight: .bold))
                    VStack(alignment: .leading, spacing: 1) {
                        Text(appState.isTurboSweeping ? "Sweeping & Evicting to Cloud…" : "⚡ 1-Click All-in-One Cloud Turbo Sweep")
                            .font(.system(size: 11, weight: .bold))
                        Text("Evicts backups, triages downloads, trims dev bloat & clears caches")
                            .font(.system(size: 8.5))
                            .opacity(0.85)
                    }
                    Spacer()
                    if appState.isTurboSweeping {
                        ProgressView().controlSize(.mini)
                    } else {
                        Image(systemName: "arrow.right.circle.fill")
                            .font(.system(size: 14))
                    }
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 8)
                .frame(maxWidth: .infinity)
                .background(
                    RoundedRectangle(cornerRadius: 9, style: .continuous)
                        .fill(
                            LinearGradient(
                                colors: [Color(hex: "#3B82F6"), Color(hex: "#4F46E5")],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                )
                .foregroundStyle(.white)
            }
            .buttonStyle(.plain)
            .disabled(appState.isTurboSweeping)

            // Live Progress Bar & Step Inspector Card
            if appState.isTurboSweeping || appState.turboSweepProgress > 0 {
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        HStack(spacing: 5) {
                            ProgressView().controlSize(.mini)
                            Text(appState.turboSweepStepName.isEmpty ? "Turbo Sweep in progress…" : appState.turboSweepStepName)
                                .font(.system(size: 10.5, weight: .semibold))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                        }
                        Spacer()
                        Text("\(Int(appState.turboSweepProgress * 100))%")
                            .font(.system(size: 10, weight: .bold, design: .rounded))
                            .foregroundStyle(Color(hex: "#63E6BE"))
                    }

                    // Custom Multi-Hue Progress Track
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule().fill(Color.white.opacity(0.1))
                            Capsule()
                                .fill(
                                    LinearGradient(
                                        colors: [Color(hex: "#3B82F6"), Color(hex: "#63E6BE"), Color(hex: "#FBBF24")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .frame(width: max(8, geo.size.width * CGFloat(appState.turboSweepProgress)))
                        }
                    }
                    .frame(height: 6)

                    if appState.turboSweepReclaimedSoFar > 0 {
                        HStack {
                            Text("Reclaimed so far:")
                                .font(.system(size: 9))
                                .foregroundStyle(.white.opacity(0.45))
                            Text(ByteCountFormatter.string(fromByteCount: appState.turboSweepReclaimedSoFar, countStyle: .file))
                                .font(.system(size: 9.5, weight: .bold, design: .rounded))
                                .foregroundStyle(Color(hex: "#63E6BE"))
                        }
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(Color(hex: "#1E2230"))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10)
                                .stroke(Color(hex: "#3B82F6").opacity(0.3), lineWidth: 1)
                        )
                )
            }

            // Segmented Picker for the 6 Storage Tools
            Picker("", selection: $selectedSection) {
                Text("Eviction").tag(0)
                Text("Dev Trim").tag(1)
                Text("Downloads").tag(2)
                Text("Ghost Map").tag(3)
                Text("Sync Radar").tag(4)
            }
            .pickerStyle(.segmented)
            .controlSize(.mini)

            // Section Views
            if selectedSection == 0 {
                evictionSection
            } else if selectedSection == 1 {
                developerBloatSection
            } else if selectedSection == 2 {
                downloadsTriageSection
            } else if selectedSection == 3 {
                GhostFileInspectorView()
            } else if selectedSection == 4 {
                syncRadarSection
            }

            if let msg = statusMessage {
                Text(msg)
                    .font(.system(size: 9.5, weight: .medium))
                    .foregroundStyle(AppTheme.batteryGreen)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
        .onAppear {
            refreshAllTools()
        }
    }

    private func metricPill(title: String, value: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(value)
                .font(.system(size: 13, weight: .bold, design: .rounded))
                .foregroundStyle(color)
            Text(title).font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.45))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(7)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.04)))
    }

    private var devBloatTotalFormatted: String {
        let total = devBloatCandidates.reduce(0) { $0 + $1.sizeBytes }
        return ByteCountFormatter.string(fromByteCount: total, countStyle: .file)
    }

    // 1. Eviction Section
    private var evictionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Button {
                    runAction { appState.optimizeAllStorage() }
                } label: {
                    Label(isOptimizing ? "Working…" : "1-Click Cloud Evict", systemImage: "icloud.and.arrow.up")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent).tint(AppTheme.accent).controlSize(.small)

                Button {
                    runAction { appState.purgeCaches() }
                } label: {
                    Label("Clean Caches", systemImage: "trash.circle")
                        .font(.system(size: 11, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered).tint(.white.opacity(0.7)).controlSize(.small)
            }

            let candidates = appState.storageSnapshot.candidates
            if !candidates.isEmpty {
                VStack(spacing: 4) {
                    ForEach(candidates.prefix(3)) { c in
                        HStack(spacing: 6) {
                            Image(systemName: c.category.icon).font(.system(size: 11)).foregroundStyle(AppTheme.accent)
                            Text(c.title).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            Spacer()
                            Text(c.sizeFormatted).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                            Button {
                                appState.optimizeSpecificCandidate(c)
                            } label: {
                                Image(systemName: "arrow.up.circle.fill").font(.system(size: 13)).foregroundStyle(AppTheme.accent)
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(5)
                        .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                    }
                }
            }
        }
    }

    // 2. Developer Bloat Section
    private var developerBloatSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Rebuildable Project Dependencies (\(devBloatCandidates.count) found)")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("Trim All") {
                    runAction {
                        _ = DeveloperProjectTrimmer.trimAllCandidates()
                        refreshAllTools()
                    }
                }
                .buttonStyle(.borderedProminent).tint(Color(hex: "#F43F5E")).controlSize(.mini)
            }

            if devBloatCandidates.isEmpty {
                Text("✓ No bloated node_modules or build folders detected.")
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(devBloatCandidates.prefix(3)) { dev in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(dev.projectName).font(.system(size: 11, weight: .semibold)).foregroundStyle(.white)
                            Text(dev.bloatType).font(.system(size: 9)).foregroundStyle(Color(hex: "#F43F5E"))
                        }
                        Spacer()
                        Text(dev.sizeFormatted).font(.system(size: 10, weight: .bold)).foregroundStyle(.white.opacity(0.85))
                        Button {
                            runAction {
                                _ = DeveloperProjectTrimmer.trimCandidate(dev)
                                refreshAllTools()
                            }
                        } label: {
                            Image(systemName: "trash.fill").font(.system(size: 11)).foregroundStyle(Color(hex: "#F43F5E"))
                        }
                        .buttonStyle(.plain)
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                }
            }
        }
    }

    // 3. Downloads Triage Section
    private var downloadsTriageSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Stale Downloads → Auto-Route to iCloud")
                    .font(.system(size: 10, weight: .semibold)).foregroundStyle(.white.opacity(0.7))
                Spacer()
                Button("Triage All") {
                    runAction {
                        _ = DownloadTriageEngine.executeTriage()
                        refreshAllTools()
                    }
                }
                .buttonStyle(.borderedProminent).tint(Color(hex: "#63E6BE")).controlSize(.mini)
            }

            if triagePlan.isEmpty {
                Text("✓ Downloads folder clean. No stale installers or media.")
                    .font(.system(size: 10.5)).foregroundStyle(.white.opacity(0.5))
            } else {
                ForEach(triagePlan.prefix(3)) { item in
                    HStack {
                        VStack(alignment: .leading, spacing: 1) {
                            Text(item.filename).font(.system(size: 10.5, weight: .medium)).foregroundStyle(.white).lineLimit(1)
                            Text("→ iCloud \(item.targetFolderName)").font(.system(size: 8.5)).foregroundStyle(Color(hex: "#63E6BE"))
                        }
                        Spacer()
                        Text(item.sizeFormatted).font(.system(size: 9.5, weight: .bold)).foregroundStyle(.white.opacity(0.8))
                    }
                    .padding(5)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
                }
            }
        }
    }

    // 4. Sync Radar Section
    private var syncRadarSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Label("iCloud Sync Telemetry", systemImage: "antenna.radiowaves.left.and.right")
                    .font(.system(size: 10.5, weight: .bold)).foregroundStyle(AppTheme.accent)
                Spacer()
                if radarStatus.conflictCount > 0 {
                    Button("Resolve \(radarStatus.conflictCount) Conflicts") {
                        runAction {
                            _ = iCloudSyncRadar.resolveAllConflicts()
                            refreshAllTools()
                        }
                    }
                    .buttonStyle(.borderedProminent).tint(.orange).controlSize(.mini)
                }
            }

            HStack(spacing: 8) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("\(radarStatus.syncingCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(.white)
                    Text("In Progress").font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(radarStatus.pendingUploads)")
                        .font(.system(size: 14, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: "#5B8CFF"))
                    Text("Pending Queue").font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))

                VStack(alignment: .leading, spacing: 2) {
                    Text("\(radarStatus.conflictCount)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundStyle(radarStatus.conflictCount > 0 ? .orange : AppTheme.batteryGreen)
                    Text("Conflicts").font(.system(size: 8.5)).foregroundStyle(.white.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(6)
                .background(RoundedRectangle(cornerRadius: 6).fill(Color.white.opacity(0.03)))
            }
        }
    }

    private func refreshAllTools() {
        DispatchQueue.global(qos: .userInitiated).async {
            let bloat = DeveloperProjectTrimmer.scanDeveloperBloat()
            let radar = iCloudSyncRadar.inspectSyncRadar()
            let triage = DownloadTriageEngine.planTriage()
            DispatchQueue.main.async {
                self.devBloatCandidates = bloat
                self.radarStatus = radar
                self.triagePlan = triage
            }
        }
    }

    private func runMasterSweepAction() {
        statusMessage = "Executing 1-Click All-in-One Cloud Turbo Sweep…"
        appState.runMasterTurboSweep { freed in
            let freedFormatted = ByteCountFormatter.string(fromByteCount: freed, countStyle: .file)
            self.statusMessage = "✓ Cloud Turbo Sweep complete: Reclaimed \(freedFormatted)!"
            self.refreshAllTools()
            DispatchQueue.main.asyncAfter(deadline: .now() + 5.0) {
                self.statusMessage = nil
            }
        }
    }

    private func runAction(action: @escaping () -> Void) {
        isOptimizing = true
        statusMessage = "Executing optimization…"
        DispatchQueue.global(qos: .userInitiated).async {
            action()
            DispatchQueue.main.async {
                isOptimizing = false
                statusMessage = "✓ Operation complete. Reclaimed local space."
                refreshAllTools()
                DispatchQueue.main.asyncAfter(deadline: .now() + 3.5) {
                    statusMessage = nil
                }
            }
        }
    }
}
