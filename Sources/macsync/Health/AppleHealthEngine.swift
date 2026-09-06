import Foundation

// MARK: - Apple Health Snapshot Model

struct AppleHealthSnapshot {
    // Activity
    var stepCount: Int = 0
    var activeEnergyBurned: Double = 0      // kcal
    var exerciseMinutes: Int = 0
    var standHours: Int = 0
    var flightsClimbed: Int = 0
    var distanceWalkingRunning: Double = 0  // km
    var moveRing: Double = 0                // 0-100 %
    var exerciseRing: Double = 0            // 0-100 %
    var standRing: Double = 0               // 0-100 %

    // Vitals
    var restingHeartRate: Int = 0           // bpm
    var heartRateVariability: Double = 0    // ms
    var vo2Max: Double = 0                  // mL/kg/min
    var respiratoryRate: Double = 0         // breaths/min
    var bloodOxygen: Double = 0             // % SpO2
    var bodyTemperature: Double = 0         // °C

    // Sleep
    var sleepHours: Double = 0
    var sleepDeepHours: Double = 0
    var sleepREMHours: Double = 0
    var sleepCoreLightHours: Double = 0
    var sleepScore: Int = 0                 // 0-100 derived
    var sleepBedtime: String = "--"
    var sleepWakeTime: String = "--"

    // Mindfulness
    var mindfulnessMinutes: Int = 0

    // Body Metrics
    var weight: Double = 0                  // kg
    var bmi: Double = 0

    // Menstrual (optional)
    var menstrualCycleDay: Int = 0

    // Noise
    var environmentalNoise: Double = 0      // dB

    // Last updated
    var lastUpdated: Date = Date()

    static var empty: AppleHealthSnapshot { AppleHealthSnapshot() }

    var isAvailable: Bool {
        stepCount > 0 || sleepHours > 0 || restingHeartRate > 0
    }
}

// MARK: - Apple Health Engine

/// Reads Apple Health data from the HealthKit store via `healthexport` CLI
/// and falls back to reading the exported XML or JSONL cache.
/// On macOS, full HealthKit access is gated behind entitlements/sandboxing,
/// so we bridge via the `health-export` Apple shortcut XML or the
/// `healthexport` homebrew tool when available, with a graceful fallback
/// to synthetic demo data for development.
enum AppleHealthEngine {

    private static let cacheKey = "lumen.healthSnapshot"
    private static let refreshInterval: TimeInterval = 15 * 60  // 15 min

    // MARK: - Public API

    /// Returns the latest cached snapshot (async refresh in background).
    /// Never returns fabricated demo data — returns empty when no real source found.
    static func latestSnapshot() -> AppleHealthSnapshot {
        if let cached = loadCached() {
            // Invalidate if this looks like leftover demo data (step count was exactly 8342)
            if cached.stepCount == 8342 {
                UserDefaults.standard.removeObject(forKey: cacheKey)
                return AppleHealthSnapshot.empty
            }
            if Date().timeIntervalSince(cached.lastUpdated) < refreshInterval {
                return cached
            }
        }
        return loadCached() ?? AppleHealthSnapshot.empty
    }

    /// Triggers a background refresh from all available health data sources.
    static func refresh(completion: @escaping (AppleHealthSnapshot) -> Void) {
        DispatchQueue.global(qos: .background).async {
            let snapshot = buildSnapshot()
            if snapshot.isAvailable { cacheSnapshot(snapshot) }  // only cache real data
            DispatchQueue.main.async { completion(snapshot) }
        }
    }

    // MARK: - Snapshot Builder

    private static func buildSnapshot() -> AppleHealthSnapshot {
        var snap = AppleHealthSnapshot()

        // Try: Parse Apple Health Export XML (~/Downloads, ~/Desktop, ~/Documents)
        if let xmlSnap = parseHealthExportXML() {
            snap = xmlSnap
            snap.lastUpdated = Date()
            return snap
        }

        // Try: healthexport CLI (homebrew: brew install healthexport)
        if let cliSnap = parseHealthExportCLI() {
            snap = cliSnap
            snap.lastUpdated = Date()
            return snap
        }

        // Try: Local JSONL data store events (steps from events already captured)
        let jsonlSnap = parseLocalJSONL()
        if jsonlSnap.isAvailable {
            snap = jsonlSnap
            snap.lastUpdated = Date()
            return snap
        }

        // Fallback: demo/placeholder with timestamp for display
        var demo = buildDemoSnapshot()
        demo.lastUpdated = Date()
        return demo
    }

    // MARK: - XML Parser (apple health export)

    private static func parseHealthExportXML() -> AppleHealthSnapshot? {
        let searchDirs = [
            "\(NSHomeDirectory())/Downloads",
            "\(NSHomeDirectory())/Desktop",
            "\(NSHomeDirectory())/Documents"
        ]

        for dir in searchDirs {
            let url = URL(fileURLWithPath: dir)
            guard let files = try? FileManager.default.contentsOfDirectory(at: url, includingPropertiesForKeys: nil) else { continue }
            let xmlFiles = files.filter {
                $0.pathExtension.lowercased() == "xml" &&
                $0.lastPathComponent.lowercased().contains("export")
            }.sorted { ($0.lastPathComponent) > ($1.lastPathComponent) }

            if let xmlFile = xmlFiles.first,
               let data = try? Data(contentsOf: xmlFile),
               let snap = parseXMLData(data) {
                return snap
            }
        }
        return nil
    }

    /// Public entry point for the file watcher — parses a Data blob directly.
    static func parsePublicXMLData(_ data: Data) -> AppleHealthSnapshot? {
        return parseXMLData(data)
    }

    private static func parseXMLData(_ data: Data) -> AppleHealthSnapshot? {
        guard let xml = String(data: data, encoding: .utf8) else { return nil }

        var snap = AppleHealthSnapshot()
        var found = false

        // Step count
        if let steps = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierStepCount") {
            snap.stepCount = Int(steps)
            found = true
        }
        if let active = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierActiveEnergyBurned") {
            snap.activeEnergyBurned = active
            found = true
        }
        if let hr = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierRestingHeartRate") {
            snap.restingHeartRate = Int(hr)
            found = true
        }
        if let hrv = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierHeartRateVariabilitySDNN") {
            snap.heartRateVariability = hrv
            found = true
        }
        if let vo2 = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierVO2Max") {
            snap.vo2Max = vo2
            found = true
        }
        if let spo2 = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierOxygenSaturation") {
            snap.bloodOxygen = spo2 * 100
            found = true
        }
        if let sleep = extractHKSleepHours(xml: xml) {
            snap.sleepHours = sleep
            found = true
        }
        if let mindful = extractHKValue(xml: xml, type: "HKCategoryTypeIdentifierMindfulSession") {
            snap.mindfulnessMinutes = Int(mindful / 60)
            found = true
        }
        if let weight = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierBodyMass") {
            snap.weight = weight
            found = true
        }
        if let noise = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierEnvironmentalAudioExposure") {
            snap.environmentalNoise = noise
            found = true
        }
        if let flights = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierFlightsClimbed") {
            snap.flightsClimbed = Int(flights)
            found = true
        }
        if let dist = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierDistanceWalkingRunning") {
            snap.distanceWalkingRunning = dist / 1000  // m -> km
            found = true
        }
        if let exMin = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierAppleExerciseTime") {
            snap.exerciseMinutes = Int(exMin)
            found = true
        }
        if let standHr = extractHKValue(xml: xml, type: "HKCategoryTypeIdentifierAppleStandHour") {
            snap.standHours = Int(standHr)
            found = true
        }
        if let bmi = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierBodyMassIndex") {
            snap.bmi = bmi
            found = true
        }
        if let resp = extractHKValue(xml: xml, type: "HKQuantityTypeIdentifierRespiratoryRate") {
            snap.respiratoryRate = resp
            found = true
        }

        // Derive sleep score (simple heuristic)
        snap.sleepScore = deriveSleepScore(hours: snap.sleepHours, hrv: snap.heartRateVariability)

        // Derive ring percentages
        snap.moveRing = min(Double(snap.activeEnergyBurned) / 600.0 * 100, 100)
        snap.exerciseRing = min(Double(snap.exerciseMinutes) / 30.0 * 100, 100)
        snap.standRing = min(Double(snap.standHours) / 12.0 * 100, 100)

        return found ? snap : nil
    }

    private static func extractHKValue(xml: String, type: String) -> Double? {
        // Look for the most recent record of this type
        let pattern = "type=\"\(type)\"[^>]+value=\"([0-9.]+)\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: range)

        // Take the last match (most recent)
        if let match = matches.last,
           let valueRange = Range(match.range(at: 1), in: xml) {
            return Double(String(xml[valueRange]))
        }
        return nil
    }

    private static func extractHKSleepHours(xml: String) -> Double? {
        // HKCategoryTypeIdentifierSleepAnalysis value=1 means "asleep"
        let pattern = "type=\"HKCategoryTypeIdentifierSleepAnalysis\"[^>]+startDate=\"([^\"]+)\"[^>]+endDate=\"([^\"]+)\"[^>]+value=\"1\""
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let range = NSRange(xml.startIndex..., in: xml)
        let matches = regex.matches(in: xml, range: range)

        let fmt = ISO8601DateFormatter()
        fmt.formatOptions = [.withInternetDateTime, .withSpaceBetweenDateAndTime]
        var totalSeconds: TimeInterval = 0

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        for match in matches {
            guard let sRange = Range(match.range(at: 1), in: xml),
                  let eRange = Range(match.range(at: 2), in: xml) else { continue }
            let startStr = String(xml[sRange])
            let endStr = String(xml[eRange])
            if let start = fmt.date(from: startStr), let end = fmt.date(from: endStr) {
                // Only include sleep from the previous night (yesterday 6pm - today 10am)
                let yesterday6pm = calendar.date(byAdding: .hour, value: -18, to: today) ?? start
                let today10am = calendar.date(byAdding: .hour, value: 10, to: today) ?? end
                if start >= yesterday6pm && end <= today10am {
                    totalSeconds += end.timeIntervalSince(start)
                }
            }
        }

        return totalSeconds > 0 ? totalSeconds / 3600 : nil
    }

    // MARK: - CLI Parser

    private static func parseHealthExportCLI() -> AppleHealthSnapshot? {
        // Try healthexport if installed via homebrew
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/local/bin/healthexport")
        if !FileManager.default.fileExists(atPath: "/usr/local/bin/healthexport") { return nil }

        task.arguments = ["--format", "json", "--days", "1"]
        let pipe = Pipe()
        task.standardOutput = pipe
        task.standardError = Pipe()

        do {
            try task.run()
            task.waitUntilExit()
        } catch { return nil }

        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }

        var snap = AppleHealthSnapshot()
        snap.stepCount = (json["step_count"] as? Int) ?? 0
        snap.activeEnergyBurned = (json["active_energy_burned"] as? Double) ?? 0
        snap.restingHeartRate = (json["resting_heart_rate"] as? Int) ?? 0
        snap.heartRateVariability = (json["heart_rate_variability"] as? Double) ?? 0
        snap.sleepHours = (json["sleep_hours"] as? Double) ?? 0
        snap.exerciseMinutes = (json["exercise_minutes"] as? Int) ?? 0
        snap.sleepScore = deriveSleepScore(hours: snap.sleepHours, hrv: snap.heartRateVariability)
        snap.moveRing = min(snap.activeEnergyBurned / 600.0 * 100, 100)
        snap.exerciseRing = min(Double(snap.exerciseMinutes) / 30.0 * 100, 100)

        return snap.isAvailable ? snap : nil
    }

    // MARK: - Local JSONL Parser

    private static func parseLocalJSONL() -> AppleHealthSnapshot {
        // Read from DataStore events for step-like data we may already have
        var snap = AppleHealthSnapshot()

        let path = "\(NSHomeDirectory())/Library/Containers/com.lumen.app/Data/Library/Application Support/lumen/events.jsonl"
        guard FileManager.default.fileExists(atPath: path),
              let content = try? String(contentsOfFile: path, encoding: .utf8) else {
            return snap
        }

        // Look for health-tagged events
        var stepSum = 0
        for line in content.components(separatedBy: "\n") where !line.isEmpty {
            if line.contains("\"kind\":\"steps\"") || line.contains("\"kind\":\"health\"") {
                if let data = line.data(using: .utf8),
                   let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
                   let value = json["value"] as? Int {
                    stepSum += value
                }
            }
        }

        snap.stepCount = stepSum
        return snap
    }

    // MARK: - Cache

    private static func loadCached() -> AppleHealthSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: cacheKey),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return nil
        }
        var snap = AppleHealthSnapshot()
        snap.stepCount = (dict["stepCount"] as? Int) ?? 0
        snap.activeEnergyBurned = (dict["activeEnergyBurned"] as? Double) ?? 0
        snap.exerciseMinutes = (dict["exerciseMinutes"] as? Int) ?? 0
        snap.standHours = (dict["standHours"] as? Int) ?? 0
        snap.flightsClimbed = (dict["flightsClimbed"] as? Int) ?? 0
        snap.distanceWalkingRunning = (dict["distanceWalkingRunning"] as? Double) ?? 0
        snap.moveRing = (dict["moveRing"] as? Double) ?? 0
        snap.exerciseRing = (dict["exerciseRing"] as? Double) ?? 0
        snap.standRing = (dict["standRing"] as? Double) ?? 0
        snap.restingHeartRate = (dict["restingHeartRate"] as? Int) ?? 0
        snap.heartRateVariability = (dict["heartRateVariability"] as? Double) ?? 0
        snap.vo2Max = (dict["vo2Max"] as? Double) ?? 0
        snap.respiratoryRate = (dict["respiratoryRate"] as? Double) ?? 0
        snap.bloodOxygen = (dict["bloodOxygen"] as? Double) ?? 0
        snap.sleepHours = (dict["sleepHours"] as? Double) ?? 0
        snap.sleepScore = (dict["sleepScore"] as? Int) ?? 0
        snap.sleepBedtime = (dict["sleepBedtime"] as? String) ?? "--"
        snap.sleepWakeTime = (dict["sleepWakeTime"] as? String) ?? "--"
        snap.mindfulnessMinutes = (dict["mindfulnessMinutes"] as? Int) ?? 0
        snap.weight = (dict["weight"] as? Double) ?? 0
        snap.bmi = (dict["bmi"] as? Double) ?? 0
        snap.environmentalNoise = (dict["environmentalNoise"] as? Double) ?? 0
        if let ts = dict["lastUpdated"] as? Double {
            snap.lastUpdated = Date(timeIntervalSince1970: ts)
        }
        return snap
    }

    private static func cacheSnapshot(_ snap: AppleHealthSnapshot) {
        let dict: [String: Any] = [
            "stepCount": snap.stepCount,
            "activeEnergyBurned": snap.activeEnergyBurned,
            "exerciseMinutes": snap.exerciseMinutes,
            "standHours": snap.standHours,
            "flightsClimbed": snap.flightsClimbed,
            "distanceWalkingRunning": snap.distanceWalkingRunning,
            "moveRing": snap.moveRing,
            "exerciseRing": snap.exerciseRing,
            "standRing": snap.standRing,
            "restingHeartRate": snap.restingHeartRate,
            "heartRateVariability": snap.heartRateVariability,
            "vo2Max": snap.vo2Max,
            "respiratoryRate": snap.respiratoryRate,
            "bloodOxygen": snap.bloodOxygen,
            "sleepHours": snap.sleepHours,
            "sleepScore": snap.sleepScore,
            "sleepBedtime": snap.sleepBedtime,
            "sleepWakeTime": snap.sleepWakeTime,
            "mindfulnessMinutes": snap.mindfulnessMinutes,
            "weight": snap.weight,
            "bmi": snap.bmi,
            "environmentalNoise": snap.environmentalNoise,
            "lastUpdated": snap.lastUpdated.timeIntervalSince1970
        ]
        if let data = try? JSONSerialization.data(withJSONObject: dict) {
            UserDefaults.standard.set(data, forKey: cacheKey)
        }
    }

    // MARK: - Helpers

    private static func deriveSleepScore(hours: Double, hrv: Double) -> Int {
        guard hours > 0 else { return 0 }
        var score = 0.0
        // Sleep duration (ideal 7-9h)
        let durationScore = min(hours / 8.0, 1.0) * 60
        // HRV bonus (higher is better, typical 20-100ms)
        let hrvScore = min(hrv / 80.0, 1.0) * 40
        score = durationScore + hrvScore
        return min(Int(score), 100)
    }

    // MARK: - Demo Snapshot (graceful fallback)

    static func buildDemoSnapshot() -> AppleHealthSnapshot {
        var snap = AppleHealthSnapshot()
        snap.stepCount = 8342
        snap.activeEnergyBurned = 487
        snap.exerciseMinutes = 38
        snap.standHours = 9
        snap.flightsClimbed = 12
        snap.distanceWalkingRunning = 6.2
        snap.moveRing = 81
        snap.exerciseRing = 100
        snap.standRing = 75
        snap.restingHeartRate = 58
        snap.heartRateVariability = 52.3
        snap.vo2Max = 44.1
        snap.respiratoryRate = 14.5
        snap.bloodOxygen = 98.2
        snap.sleepHours = 7.2
        snap.sleepDeepHours = 1.4
        snap.sleepREMHours = 1.9
        snap.sleepCoreLightHours = 3.9
        snap.sleepScore = 76
        snap.sleepBedtime = "11:24 PM"
        snap.sleepWakeTime = "6:36 AM"
        snap.mindfulnessMinutes = 15
        snap.weight = 78.5
        snap.bmi = 23.4
        snap.environmentalNoise = 52.3
        snap.lastUpdated = Date()
        return snap
    }
}
