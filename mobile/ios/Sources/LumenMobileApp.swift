import SwiftUI
import BackgroundTasks

@main
struct LumenMobileApp: App {
    @StateObject private var appState = MobileAppState.shared
    @Environment(\.scenePhase) private var scenePhase

    init() {
        registerBackgroundTasks()
    }

    var body: some Scene {
        WindowGroup {
            TabView {
                MobileDashboardView()
                    .tabItem {
                        Label("Radar", systemImage: "waveform.path.ecg")
                    }

                MobileReceiptScannerView()
                    .tabItem {
                        Label("Scan Receipt", systemImage: "doc.text.viewfinder")
                    }

                MobileTimeMachineView()
                    .tabItem {
                        Label("Time Machine", systemImage: "clock.arrow.circlepath")
                    }

                MobileSettingsView()
                    .tabItem {
                        Label("Settings", systemImage: "gearshape")
                    }
            }
            .preferredColorScheme(.dark)
            .tint(Color(red: 0.36, green: 0.55, blue: 1.0))
            .onAppear {
                appState.startAllCollectors()
            }
            .onChange(of: scenePhase) { newPhase in
                switch newPhase {
                case .background:
                    appState.handleEnteringBackground()
                case .active:
                    appState.handleEnteringForeground()
                case .inactive:
                    break
                @unknown default:
                    break
                }
            }
        }
    }

    private func registerBackgroundTasks() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: MobileAppState.bgRefreshTaskIdentifier, using: nil) { task in
            guard let refreshTask = task as? BGAppRefreshTask else { return }
            handleBackgroundRefresh(task: refreshTask)
        }
    }

    private func handleBackgroundRefresh(task: BGAppRefreshTask) {
        task.expirationHandler = {
            MobileDataStore.shared.flush()
        }

        // Lightweight periodic sensor snapshot
        MobileHardwareCollector.shared.sampleHardware()
        MobileAudioRouteCollector.shared.sampleRoute()
        HealthKitCollector.shared.sampleHealthMetrics()
        let _ = MobileDataStore.shared.syncToCloudOrDesktopContainer()

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .appLifecycle,
            payload: .appLifecycle(MobileLifecyclePayload(observedAt: Date(), event: "bgRefreshExecuted"))
        ))

        MobileDataStore.shared.flush()
        MobileAppState.shared.scheduleBackgroundTasks()
        task.setTaskCompleted(success: true)
    }
}
