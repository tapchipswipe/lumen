import AppKit
import ApplicationServices
import CoreGraphics
import CoreLocation

/// Central place for privacy-permission checks and first-launch onboarding.
///
/// Permission map:
///   Accessibility     -> required for the CGEvent input tap (metadata counts)
///   Screen Recording  -> required for window titles via CGWindowList
///   Apple Events      -> required for Safari/Chrome tab queries (prompted on first use)
///   Location          -> requested via CLLocationManager
///   Full Disk Access  -> optional for deep cache scrubbing & protected storage offload
final class PermissionsManager {

    // MARK: - Status (read-only, no prompts)

    var isAccessibilityTrusted: Bool {
        AXIsProcessTrusted()
    }

    var hasScreenRecording: Bool {
        CGPreflightScreenCaptureAccess()
    }

    var locationStatus: CLAuthorizationStatus {
        CLLocationManager().authorizationStatus
    }

    var hasFullDiskAccess: Bool {
        let home = NSHomeDirectory()
        let testPath = "\(home)/Library/Safari"
        return FileManager.default.isReadableFile(atPath: testPath)
    }

    var allCriticalGranted: Bool {
        isAccessibilityTrusted && hasScreenRecording
    }

    // MARK: - Onboarding

    /// Runs once on first launch. After the user has been shown the onboarding
    /// flow, subsequent launches stay silent.
    func runOnboardingIfNeeded(locationTracker: LocationTracker) {
        let onboarded = UserDefaults.standard.bool(forKey: "lumen.onboarded")
        if !onboarded {
            requestAccessibility()
            requestScreenRecording()
            UserDefaults.standard.set(true, forKey: "lumen.onboarded")
            if !allCriticalGranted {
                Task { @MainActor in OnboardingWindowController.shared.show(permissions: self) }
            }
        }
        locationTracker.start()
    }

    /// Triggers the Accessibility trust prompt and opens Settings if needed.
    func requestAccessibility() {
        guard !isAccessibilityTrusted else { return }
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    /// Triggers the Screen Recording prompt (macOS 10.15+).
    func requestScreenRecording() {
        guard !hasScreenRecording else { return }
        _ = CGRequestScreenCaptureAccess()
    }

    /// Sends a no-op Apple Event to Safari to pre-trigger the Automation consent dialog.
    func requestAutomationConsent() {
        let scripts = [
            "tell application \"Safari\" to count of windows",
            "tell application \"Google Chrome\" to count of windows"
        ]
        for source in scripts {
            let target = source.contains("Safari") ? "com.apple.Safari" : "com.google.Chrome"
            guard NSWorkspace.shared.urlForApplication(withBundleIdentifier: target) != nil else { continue }
            var error: NSDictionary?
            NSAppleScript(source: source)?.executeAndReturnError(&error)
        }
    }

    // MARK: - System Settings deep links

    func openAccessibilitySettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!)
    }

    func openScreenRecordingSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_ScreenCapture")!)
    }

    func openAutomationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation")!)
    }

    func openLocationSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_LocationServices")!)
    }

    func openFullDiskAccessSettings() {
        NSWorkspace.shared.open(URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_AllFiles")!)
    }
}
