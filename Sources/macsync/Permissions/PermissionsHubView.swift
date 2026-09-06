import SwiftUI
import CoreLocation

public struct PermissionsHubView: View {
    @ObservedObject var appState = AppState.shared
    let permissions = PermissionsManager()

    public init() {}

    public var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Privacy & Permissions Hub", systemImage: "hand.raised.fill")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(AppTheme.accent)
                Spacer()
                Text("100% LOCAL PRIVACY")
                    .font(.system(size: 8.5, weight: .bold))
                    .foregroundStyle(.white.opacity(0.4))
                    .tracking(1)
            }

            Text("Lumen runs entirely on-device. No keystroke characters, camera video, or browser contents ever leave your Mac.")
                .font(.system(size: 10.5))
                .foregroundStyle(.white.opacity(0.65))

            VStack(spacing: 8) {
                // 1. Accessibility
                permissionCard(
                    title: "Accessibility",
                    detail: "Counts keystroke and click velocity (metadata only, never what you type)",
                    icon: "keyboard.fill",
                    isGranted: appState.accessibilityGranted,
                    action: { permissions.openAccessibilitySettings() }
                )

                // 2. Screen Recording
                permissionCard(
                    title: "Screen Recording",
                    detail: "Reads frontmost window titles (e.g. Xcode project name, Slack channel)",
                    icon: "macwindow",
                    isGranted: appState.screenRecordingGranted,
                    action: { permissions.openScreenRecordingSettings() }
                )

                // 3. Apple Events / Automation
                permissionCard(
                    title: "Automation (Browsers)",
                    detail: "Reads Safari and Chrome active tab titles for your lifelog",
                    icon: "safari.fill",
                    isGranted: true, // Automation prompts on-demand
                    action: { permissions.openAutomationSettings() }
                )

                // 4. Location Services
                let locGranted = (CLLocationManager().authorizationStatus == .authorized || CLLocationManager().authorizationStatus == .authorizedAlways)
                permissionCard(
                    title: "Location Services",
                    detail: "Records working locations (office, home, cafe) for daily context",
                    icon: "location.fill",
                    isGranted: locGranted,
                    action: { permissions.openLocationSettings() }
                )

                // 5. Full Disk Access (Storage & Screen Time Sync)
                permissionCard(
                    title: "Full Disk Access",
                    detail: "Enables zero-footprint storage sweeps & cross-device iPhone Screen Time sync",
                    icon: "internaldrive.fill",
                    isGranted: permissions.hasFullDiskAccess,
                    action: { permissions.openFullDiskAccessSettings() }
                )
            }

            if !appState.accessibilityGranted || !appState.screenRecordingGranted {
                Button {
                    appState.requestPermissions()
                } label: {
                    Label("Request Missing Permissions…", systemImage: "lock.open.fill")
                        .font(.system(size: 11.5, weight: .semibold))
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .tint(AppTheme.accent)
                .controlSize(.regular)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(AppTheme.card)
        )
    }

    private func permissionCard(title: String, detail: String, icon: String, isGranted: Bool, action: @escaping () -> Void) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(isGranted ? AppTheme.batteryGreen : .orange)
                .frame(width: 24, height: 24)
                .background(Circle().fill((isGranted ? AppTheme.batteryGreen : Color.orange).opacity(0.12)))

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.system(size: 11.5, weight: .semibold))
                        .foregroundStyle(.white)
                    Text(isGranted ? "ACTIVE" : "NEEDED")
                        .font(.system(size: 8, weight: .bold))
                        .foregroundStyle(isGranted ? AppTheme.batteryGreen : .orange)
                        .padding(.horizontal, 4).padding(.vertical, 1)
                        .background(Capsule().fill((isGranted ? AppTheme.batteryGreen : Color.orange).opacity(0.15)))
                }
                Text(detail)
                    .font(.system(size: 9.5))
                    .foregroundStyle(.white.opacity(0.45))
                    .lineLimit(2)
            }

            Spacer()

            Button {
                action()
            } label: {
                Image(systemName: "arrow.up.forward.square")
                    .font(.system(size: 12))
                    .foregroundStyle(.white.opacity(0.5))
            }
            .buttonStyle(.plain)
        }
        .padding(8)
        .background(RoundedRectangle(cornerRadius: 8).fill(Color.white.opacity(0.03)))
    }
}
