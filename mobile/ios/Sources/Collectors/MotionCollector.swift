import Foundation
import CoreMotion

public final class MotionCollector {
    public static let shared = MotionCollector()
    private let activityManager = CMMotionActivityManager()
    private let pedometer = CMPedometer()
    private let queue = OperationQueue()

    public private(set) var currentActivity: String = "Stationary"
    public private(set) var todaySteps: Int = 0
    public private(set) var todayDistanceMeters: Double = 0.0

    private init() {
        queue.qualityOfService = .utility
    }

    public func start() {
        guard CMMotionActivityManager.isActivityAvailable() else { return }

        activityManager.startActivityUpdates(to: queue) { [weak self] activity in
            guard let activity = activity else { return }
            let conf: String
            switch activity.confidence {
            case .low: conf = "low"
            case .medium: conf = "medium"
            case .high: conf = "high"
            @unknown default: conf = "unknown"
            }

            let payload = MotionActivityPayload(
                observedAt: Date(),
                stationary: activity.stationary,
                walking: activity.walking,
                running: activity.running,
                automotive: activity.automotive,
                cycling: activity.cycling,
                confidence: conf
            )

            if activity.walking { self?.currentActivity = "Walking" }
            else if activity.running { self?.currentActivity = "Running" }
            else if activity.automotive { self?.currentActivity = "Driving" }
            else if activity.cycling { self?.currentActivity = "Cycling" }
            else { self?.currentActivity = "Stationary" }

            MobileDataStore.shared.append(MobileTrackerEvent(
                kind: .motionActivity,
                payload: .motionActivity(payload)
            ))
        }

        if CMPedometer.isStepCountingAvailable() {
            let calendar = Calendar.current
            let midnight = calendar.startOfDay(for: Date())
            pedometer.startUpdates(from: midnight) { [weak self] data, error in
                guard let data = data, error == nil else { return }
                self?.todaySteps = data.numberOfSteps.intValue
                self?.todayDistanceMeters = data.distance?.doubleValue ?? 0.0

                let payload = PedometerPayload(
                    startDate: data.startDate,
                    endDate: data.endDate,
                    numberOfSteps: data.numberOfSteps.intValue,
                    distanceMeters: data.distance?.doubleValue,
                    currentPace: data.currentPace?.doubleValue,
                    currentCadence: data.currentCadence?.doubleValue,
                    floorsAscended: data.floorsAscended?.intValue,
                    floorsDescended: data.floorsDescended?.intValue
                )

                MobileDataStore.shared.append(MobileTrackerEvent(
                    kind: .pedometerStep,
                    payload: .pedometerStep(payload)
                ))
            }
        }
    }

    public func stop() {
        activityManager.stopActivityUpdates()
        pedometer.stopUpdates()
    }
}
