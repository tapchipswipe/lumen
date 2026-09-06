import Foundation
import CoreLocation

/// Battery-optimized location collector.
/// Seamlessly throttles between foreground distance-filtered fixes and
/// zero-wake significant-change monitoring when in the background.
public final class MobileLocationCollector: NSObject, CLLocationManagerDelegate {
    public static let shared = MobileLocationCollector()
    private let manager = CLLocationManager()
    public private(set) var lastLocation: CLLocation?
    private var isBackgrounded: Bool = false

    private override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyHundredMeters
        manager.distanceFilter = 100.0 // 100 meters to prevent frequent wakeups
        manager.pausesLocationUpdatesAutomatically = true
        manager.activityType = .fitness
        manager.showsBackgroundLocationIndicator = false
    }

    public func requestPermissions() {
        manager.requestAlwaysAuthorization()
    }

    public func start() {
        if isBackgrounded {
            startSignificantMonitoringOnly()
        } else {
            manager.startUpdatingLocation()
            startSignificantMonitoringOnly()
        }
    }

    public func stop() {
        manager.stopUpdatingLocation()
        manager.stopMonitoringSignificantLocationChanges()
    }

    public func setBackgroundMode(_ backgrounded: Bool) {
        self.isBackgrounded = backgrounded
        if backgrounded {
            // Drop continuous GPS to save baseband battery
            manager.stopUpdatingLocation()
            startSignificantMonitoringOnly()
        } else {
            manager.startUpdatingLocation()
        }
    }

    private func startSignificantMonitoringOnly() {
        if CLLocationManager.significantLocationChangeMonitoringAvailable() {
            manager.startMonitoringSignificantLocationChanges()
        }
    }

    public func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let loc = locations.last else { return }
        self.lastLocation = loc

        let payload = MobileLocationPayload(
            observedAt: loc.timestamp,
            latitude: loc.coordinate.latitude,
            longitude: loc.coordinate.longitude,
            altitude: loc.altitude,
            horizontalAccuracy: loc.horizontalAccuracy,
            speedMetersPerSec: loc.speed,
            courseHeading: loc.course,
            isSignificantChange: isBackgrounded || (locations.count == 1 && loc.horizontalAccuracy > 80)
        )

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .locationUpdate,
            payload: .locationUpdate(payload)
        ))
    }

    public func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        // Silently handle location errors without thrashing the CPU
    }
}
