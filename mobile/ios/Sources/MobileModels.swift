import Foundation

// MARK: - High-Performance Cached Coders (Zero Per-Event Allocation)

public enum MobileFormat {
    public static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = .current
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    public static let jsonEncoder: JSONEncoder = {
        let e = JSONEncoder()
        e.dateEncodingStrategy = .iso8601
        e.outputFormatting = [.sortedKeys]
        return e
    }()

    public static let jsonDecoder: JSONDecoder = {
        let d = JSONDecoder()
        d.dateDecodingStrategy = .iso8601
        return d
    }()

    public static func dayString(for date: Date = Date()) -> String {
        dayFormatter.string(from: date)
    }
}

// MARK: - Unified Event Envelope

public struct MobileTrackerEvent: Codable {
    public let ts: Date
    public let device: String
    public let kind: MobileEventKind
    public let payload: MobilePayload

    public init(ts: Date = Date(), device: String = "iPhone", kind: MobileEventKind, payload: MobilePayload) {
        self.ts = ts
        self.device = device
        self.kind = kind
        self.payload = payload
    }

    public enum MobileEventKind: String, Codable {
        case motionActivity
        case pedometerStep
        case locationUpdate
        case hardwareStatus
        case cellularContext
        case audioRoute
        case healthMetrics
        case receiptScan
        case appLifecycle
        case syncBeacon
    }

    public enum MobilePayload: Codable {
        case motionActivity(MotionActivityPayload)
        case pedometerStep(PedometerPayload)
        case locationUpdate(MobileLocationPayload)
        case hardwareStatus(MobileHardwarePayload)
        case cellularContext(CellularNetworkPayload)
        case audioRoute(MobileAudioRoutePayload)
        case healthMetrics(HealthMetricPayload)
        case receiptScan(MobileReceiptPayload)
        case appLifecycle(MobileLifecyclePayload)
        case syncBeacon(MobileSyncBeaconPayload)

        private enum CodingKeys: String, CodingKey {
            case type
            case motionActivity, pedometerStep, locationUpdate, hardwareStatus
            case cellularContext, audioRoute, healthMetrics, receiptScan
            case appLifecycle, syncBeacon
        }

        private enum PayloadType: String, Codable {
            case motionActivity, pedometerStep, locationUpdate, hardwareStatus
            case cellularContext, audioRoute, healthMetrics, receiptScan
            case appLifecycle, syncBeacon
        }

        public init(from decoder: Decoder) throws {
            let c = try decoder.container(keyedBy: CodingKeys.self)
            let type = try c.decode(PayloadType.self, forKey: .type)
            switch type {
            case .motionActivity: self = .motionActivity(try c.decode(MotionActivityPayload.self, forKey: .motionActivity))
            case .pedometerStep: self = .pedometerStep(try c.decode(PedometerPayload.self, forKey: .pedometerStep))
            case .locationUpdate: self = .locationUpdate(try c.decode(MobileLocationPayload.self, forKey: .locationUpdate))
            case .hardwareStatus: self = .hardwareStatus(try c.decode(MobileHardwarePayload.self, forKey: .hardwareStatus))
            case .cellularContext: self = .cellularContext(try c.decode(CellularNetworkPayload.self, forKey: .cellularContext))
            case .audioRoute: self = .audioRoute(try c.decode(MobileAudioRoutePayload.self, forKey: .audioRoute))
            case .healthMetrics: self = .healthMetrics(try c.decode(HealthMetricPayload.self, forKey: .healthMetrics))
            case .receiptScan: self = .receiptScan(try c.decode(MobileReceiptPayload.self, forKey: .receiptScan))
            case .appLifecycle: self = .appLifecycle(try c.decode(MobileLifecyclePayload.self, forKey: .appLifecycle))
            case .syncBeacon: self = .syncBeacon(try c.decode(MobileSyncBeaconPayload.self, forKey: .syncBeacon))
            }
        }

        public func encode(to encoder: Encoder) throws {
            var c = encoder.container(keyedBy: CodingKeys.self)
            switch self {
            case .motionActivity(let p):
                try c.encode(PayloadType.motionActivity, forKey: .type)
                try c.encode(p, forKey: .motionActivity)
            case .pedometerStep(let p):
                try c.encode(PayloadType.pedometerStep, forKey: .type)
                try c.encode(p, forKey: .pedometerStep)
            case .locationUpdate(let p):
                try c.encode(PayloadType.locationUpdate, forKey: .type)
                try c.encode(p, forKey: .locationUpdate)
            case .hardwareStatus(let p):
                try c.encode(PayloadType.hardwareStatus, forKey: .type)
                try c.encode(p, forKey: .hardwareStatus)
            case .cellularContext(let p):
                try c.encode(PayloadType.cellularContext, forKey: .type)
                try c.encode(p, forKey: .cellularContext)
            case .audioRoute(let p):
                try c.encode(PayloadType.audioRoute, forKey: .type)
                try c.encode(p, forKey: .audioRoute)
            case .healthMetrics(let p):
                try c.encode(PayloadType.healthMetrics, forKey: .type)
                try c.encode(p, forKey: .healthMetrics)
            case .receiptScan(let p):
                try c.encode(PayloadType.receiptScan, forKey: .type)
                try c.encode(p, forKey: .receiptScan)
            case .appLifecycle(let p):
                try c.encode(PayloadType.appLifecycle, forKey: .type)
                try c.encode(p, forKey: .appLifecycle)
            case .syncBeacon(let p):
                try c.encode(PayloadType.syncBeacon, forKey: .type)
                try c.encode(p, forKey: .syncBeacon)
            }
        }
    }
}

// MARK: - Mobile Sensor Payloads

public struct MotionActivityPayload: Codable {
    public let observedAt: Date
    public let stationary: Bool
    public let walking: Bool
    public let running: Bool
    public let automotive: Bool
    public let cycling: Bool
    public let confidence: String
}

public struct PedometerPayload: Codable {
    public let startDate: Date
    public let endDate: Date
    public let numberOfSteps: Int
    public let distanceMeters: Double?
    public let currentPace: Double?
    public let currentCadence: Double?
    public let floorsAscended: Int?
    public let floorsDescended: Int?
}

public struct MobileLocationPayload: Codable {
    public let observedAt: Date
    public let latitude: Double
    public let longitude: Double
    public let altitude: Double
    public let horizontalAccuracy: Double
    public let speedMetersPerSec: Double
    public let courseHeading: Double
    public let isSignificantChange: Bool
}

public struct MobileHardwarePayload: Codable {
    public let observedAt: Date
    public let batteryLevelPercent: Int
    public let batteryState: String
    public let isLowPowerMode: Bool
    public let thermalState: String
    public let screenBrightness: Double
    public let freeDiskSpaceGB: Double
}

public struct CellularNetworkPayload: Codable {
    public let observedAt: Date
    public let carrierName: String?
    public let radioTechnology: String?
    public let isWiFi: Bool
    public let isCellular: Bool
    public let isExpensive: Bool
    public let isConstrained: Bool
    public let activeSSID: String?
}

public struct MobileAudioRoutePayload: Codable {
    public let observedAt: Date
    public let portName: String
    public let portType: String
    public let outputVolume: Float
    public let isHeadphones: Bool
}

public struct HealthMetricPayload: Codable {
    public let observedAt: Date
    public let stepCountToday: Int
    public let activeEnergyBurnedKCal: Double
    public let restingHeartRateBPM: Double?
    public let sleepDurationMinutes: Double?
    public let mindfulMinutes: Double?
}

public struct MobileReceiptPayload: Codable {
    public let id: UUID
    public let capturedAt: Date
    public let merchant: String
    public let amount: Double
    public let currency: String
    public let cardLast4: String?
    public let category: String
    public let rawOcrSnippet: String
    public let confidenceScore: Double
}

public struct MobileLifecyclePayload: Codable {
    public let observedAt: Date
    public let event: String
}

public struct MobileSyncBeaconPayload: Codable {
    public let date: String
    public let destination: String
    public let bufferedEventsCount: Int
    public let success: Bool
}
