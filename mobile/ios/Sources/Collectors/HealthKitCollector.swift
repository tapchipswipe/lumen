import Foundation
import HealthKit

public final class HealthKitCollector {
    public static let shared = HealthKitCollector()
    private let healthStore = HKHealthStore()
    public private(set) var isAuthorized: Bool = false
    public private(set) var latestHeartRate: Double?
    public private(set) var latestSteps: Int = 0

    private init() {}

    public func requestAuthorization(completion: @escaping (Bool) -> Void) {
        guard HKHealthStore.isHealthDataAvailable() else {
            completion(false)
            return
        }

        guard let stepType = HKObjectType.quantityType(forIdentifier: .stepCount),
              let hrType = HKObjectType.quantityType(forIdentifier: .heartRate),
              let restingHrType = HKObjectType.quantityType(forIdentifier: .restingHeartRate),
              let energyType = HKObjectType.quantityType(forIdentifier: .activeEnergyBurned) else {
            completion(false)
            return
        }

        let readTypes: Set<HKObjectType> = [stepType, hrType, restingHrType, energyType]
        healthStore.requestAuthorization(toShare: nil, read: readTypes) { [weak self] success, _ in
            self?.isAuthorized = success
            if success {
                self?.sampleHealthMetrics()
            }
            completion(success)
        }
    }

    public func sampleHealthMetrics() {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let calendar = Calendar.current
        let startOfDay = calendar.startOfDay(for: Date())
        let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: Date(), options: .strictStartDate)

        guard let stepType = HKQuantityType.quantityType(forIdentifier: .stepCount),
              let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

        // Fetch today's step count
        let stepQuery = HKStatisticsQuery(quantityType: stepType, quantitySamplePredicate: predicate, options: .cumulativeSum) { [weak self] _, result, _ in
            let steps = Int(result?.sumQuantity()?.doubleValue(for: HKUnit.count()) ?? 0.0)
            self?.latestSteps = steps

            // Fetch most recent heart rate
            let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierEndDate, ascending: false)
            let hrQuery = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { _, samples, _ in
                var hrVal: Double? = nil
                if let sample = samples?.first as? HKQuantitySample {
                    hrVal = sample.quantity.doubleValue(for: HKUnit(from: "count/min"))
                    self?.latestHeartRate = hrVal
                }

                let payload = HealthMetricPayload(
                    observedAt: Date(),
                    stepCountToday: steps,
                    activeEnergyBurnedKCal: 0.0,
                    restingHeartRateBPM: hrVal,
                    sleepDurationMinutes: nil,
                    mindfulMinutes: nil
                )

                MobileDataStore.shared.append(MobileTrackerEvent(
                    kind: .healthMetrics,
                    payload: .healthMetrics(payload)
                ))
            }
            self?.healthStore.execute(hrQuery)
        }
        healthStore.execute(stepQuery)
    }
}
