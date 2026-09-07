import SwiftUI
import UIKit

public struct MobileDashboardView: View {
    @ObservedObject var appState = MobileAppState.shared
    @State private var showingShareSheet = false
    @State private var showingDocPicker = false
    @State private var exportURL: URL? = nil

    public var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 16) {
                    // Header Status Strip
                    HStack {
                        Label("LUMEN RADAR", systemImage: "waveform.path.ecg")
                            .font(.system(size: 13, weight: .bold, design: .monospaced))
                            .foregroundColor(Color(red: 0.36, green: 0.55, blue: 1.0))
                        Spacer()
                        Circle()
                            .fill(Color.green)
                            .frame(width: 8, height: 8)
                        Text("STREAMING")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundColor(.green)
                    }
                    .padding(.horizontal, 4)

                    // Hero Biometrics & Event Counters
                    HStack(spacing: 12) {
                        heroCard(
                            title: "EVENTS TODAY",
                            value: "\(appState.todayEventsCount)",
                            subtitle: "Buffered locally",
                            icon: "tray.full.fill",
                            color: Color(red: 0.36, green: 0.55, blue: 1.0)
                        )
                        heroCard(
                            title: "STEPS",
                            value: "\(appState.todaySteps)",
                            subtitle: "CoreMotion & Health",
                            icon: "figure.walk",
                            color: Color.cyan
                        )
                    }

                    // 4-Card Sensor Matrix with SF Symbols
                    LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                        sensorCard(
                            title: "HEART RATE",
                            value: appState.currentHeartRate != nil ? String(format: "%.0f BPM", appState.currentHeartRate!) : "-- BPM",
                            icon: "heart.fill",
                            color: Color.red
                        )
                        sensorCard(
                            title: "AUDIO OUTPUT",
                            value: appState.audioOutput,
                            icon: "airpodspro",
                            color: Color.orange
                        )
                        sensorCard(
                            title: "BATTERY RUNWAY",
                            value: "\(appState.batteryPercent)% \(appState.isCharging ? "⚡" : "")",
                            icon: "bolt.batteryblock.fill",
                            color: Color.green
                        )
                        sensorCard(
                            title: "RADIO CONTEXT",
                            value: appState.currentRadio,
                            icon: "antenna.radiowaves.left.and.right",
                            color: Color.purple
                        )
                    }

                    // Action Controls: Flush, AirDrop, Save to Files
                    VStack(spacing: 10) {
                        Button(action: {
                            appState.flushBufferNow()
                        }) {
                            HStack {
                                Image(systemName: "arrow.triangle.2.circlepath")
                                Text("Flush Buffer to Disk")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                            .background(Color(white: 0.14))
                            .foregroundColor(.white)
                            .cornerRadius(12)
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.white.opacity(0.1), lineWidth: 1)
                            )
                        }

                        HStack(spacing: 10) {
                            Button(action: {
                                prepareAndShareFile()
                            }) {
                                HStack {
                                    Image(systemName: "square.and.arrow.up")
                                    Text("AirDrop / Share")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(red: 0.2, green: 0.4, blue: 0.9))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }

                            Button(action: {
                                prepareAndExportToCloud()
                            }) {
                                HStack {
                                    Image(systemName: "icloud.and.arrow.down")
                                    Text("Save to iCloud")
                                        .fontWeight(.semibold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                                .background(Color(white: 0.14))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color.white.opacity(0.1), lineWidth: 1)
                                )
                            }
                        }
                    }
                    .padding(.top, 6)

                    // Cognitive Focus Pacing & iPhone Taptic Dispatcher
                    VStack(alignment: .leading, spacing: 12) {
                        HStack {
                            Image(systemName: "brain.head.profile")
                                .foregroundColor(.pink)
                            Text("COGNITIVE FOCUS PACING")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                            Text("OPTIMAL FOCUS")
                                .font(.system(size: 10, weight: .bold, design: .monospaced))
                                .foregroundColor(.green)
                        }

                        HStack(spacing: 8) {
                            Button(action: {
                                let generator = UIImpactFeedbackGenerator(style: .heavy)
                                generator.prepare()
                                generator.impactOccurred()
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "iphone.radiowaves.left.and.right")
                                    Text("Test Phone Haptic Cue")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.pink.opacity(0.18))
                                .foregroundColor(.pink)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.pink.opacity(0.3), lineWidth: 1))
                            }

                            Button(action: {
                                LumenLiveActivityManager.shared.startLiveActivity(branch: "main", activityName: "Deep Work")
                            }) {
                                HStack(spacing: 6) {
                                    Image(systemName: "smallcircle.filled.circle.fill")
                                    Text("Start Dynamic Island HUD")
                                        .font(.system(size: 12, weight: .semibold))
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.blue.opacity(0.18))
                                .foregroundColor(Color(red: 0.36, green: 0.55, blue: 1.0))
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.blue.opacity(0.3), lineWidth: 1))
                            }
                        }
                    }
                    .padding(14)
                    .background(Color(white: 0.10))
                    .cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(Color.white.opacity(0.08), lineWidth: 1))

                    // System Storage & File Info Card
                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(Color(red: 0.36, green: 0.55, blue: 1.0))
                            Text("LOCAL DOCUMENT STORAGE")
                                .font(.system(size: 11, weight: .bold, design: .monospaced))
                                .foregroundColor(.secondary)
                            Spacer()
                        }
                        Text("Files are accessible in the iOS Files app -> 'On My iPhone' -> 'Lumen' -> 'lumen_exports'.")
                            .font(.system(size: 12))
                            .foregroundColor(Color(white: 0.8))
                    }
                    .padding(14)
                    .background(Color(white: 0.08))
                    .cornerRadius(12)
                    .padding(.top, 4)
                }
                .padding(16)
            }
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Lumen Mobile")
            .sheet(isPresented: $showingShareSheet) {
                if let url = exportURL {
                    ShareSheet(activityItems: [url])
                }
            }
            .sheet(isPresented: $showingDocPicker) {
                if let url = exportURL {
                    DocumentExportPicker(fileURL: url)
                }
            }
            .sheet(isPresented: $appState.showCrashLogModal) {
                CrashReportModalView(crashLog: appState.pendingCrashLog ?? "No log details available.") {
                    appState.dismissCrashLog()
                }
            }
        }
    }

    private func heroCard(title: String, value: String, subtitle: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }
            Text(title)
                .font(.system(size: 10, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(.white)
            Text(subtitle)
                .font(.system(size: 10))
                .foregroundColor(.secondary)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.12))
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.08), lineWidth: 1)
        )
    }

    private func sensorCard(title: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: icon)
                    .foregroundColor(color)
                    .font(.system(size: 16))
                Spacer()
            }
            Text(title)
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundColor(.secondary)
            Text(value)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(.white)
                .lineLimit(1)
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(white: 0.10))
        .cornerRadius(12)
    }

    private func prepareAndShareFile() {
        appState.flushBufferNow()
        let day = MobileFormat.dayString()
        let file = MobileDataStore.shared.bufferFile(for: day)
        self.exportURL = file
        self.showingShareSheet = true
    }

    private func prepareAndExportToCloud() {
        appState.flushBufferNow()
        let day = MobileFormat.dayString()
        let file = MobileDataStore.shared.bufferFile(for: day)
        self.exportURL = file
        self.showingDocPicker = true
    }
}

// MARK: - UIKit Bridges (ShareSheet & Document Picker)

struct ShareSheet: UIViewControllerRepresentable {
    var activityItems: [Any]
    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }
    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

struct DocumentExportPicker: UIViewControllerRepresentable {
    var fileURL: URL
    func makeUIViewController(context: Context) -> UIDocumentPickerViewController {
        let picker = UIDocumentPickerViewController(forExporting: [fileURL], asCopy: true)
        return picker
    }
    func updateUIViewController(_ uiViewController: UIDocumentPickerViewController, context: Context) {}
}

// MARK: - Crash Reporter Diagnostic Modal

struct CrashReportModalView: View {
    let crashLog: String
    var onDismiss: () -> Void

    var body: some View {
        NavigationView {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundColor(.yellow)
                        .font(.system(size: 24))
                    Text("Previous Launch Diagnostic")
                        .font(.system(size: 18, weight: .bold))
                        .foregroundColor(.white)
                }

                Text("A crash or unhandled signal occurred during the prior session. The stack trace below was safely preserved:")
                    .font(.system(size: 13))
                    .foregroundColor(.secondary)

                ScrollView {
                    Text(crashLog)
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundColor(.green)
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color(white: 0.08))
                        .cornerRadius(10)
                }

                Button(action: onDismiss) {
                    Text("Dismiss & Clear Crash Log")
                        .fontWeight(.bold)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.red.opacity(0.8))
                        .foregroundColor(.white)
                        .cornerRadius(12)
                }
            }
            .padding()
            .background(Color.black.edgesIgnoringSafeArea(.all))
            .navigationTitle("Diagnostic Log")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
