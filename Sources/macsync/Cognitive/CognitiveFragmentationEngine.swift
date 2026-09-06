import Foundation

struct CognitiveFragmentationSnapshot: Codable {
    let cfiScore: Int // 0 (Pure Flow) to 100 (Severe Fragmentation)
    let flowScore: Int // 100 - cfiScore
    let flowStateLabel: String
    let switchesPerHour: Int
    let averageFocusSprintMinutes: Int
    let dominantActiveApp: String
    let keystrokeCadenceWPM: Int
    let narrative: String
    let timestamp: Date

    static let empty = CognitiveFragmentationSnapshot(
        cfiScore: 12,
        flowScore: 88,
        flowStateLabel: "Deep Flow State",
        switchesPerHour: 6,
        averageFocusSprintMinutes: 42,
        dominantActiveApp: "Xcode",
        keystrokeCadenceWPM: 65,
        narrative: "Sustained focus with minimal context switching.",
        timestamp: Date()
    )
}

enum CognitiveFragmentationEngine {

    /// Computes real-time Cognitive Fragmentation Index (CFI) and Flow Dynamics.
    static func compute(todayStats: TodayStats, frames: [TimeMachineFrame], liveKeystrokes: Int) -> CognitiveFragmentationSnapshot {
        let activeMinutes = Int(todayStats.activeMinutes)
        guard activeMinutes > 0 else {
            return .empty
        }

        // 1. Calculate window/app switches from Time Machine frames
        var totalSwitches = 0
        var previousTitle: String? = nil

        for frame in frames {
            if let windowTitle = frame.windowTitle, !windowTitle.isEmpty {
                if let prev = previousTitle, prev != windowTitle {
                    totalSwitches += 1
                }
                previousTitle = windowTitle
            }
        }

        // Fallback switches estimate if early in day
        let appCount = max(1, todayStats.apps.count)
        if totalSwitches == 0 && activeMinutes > 0 {
            totalSwitches = appCount * 3
        }

        let hours = max(0.25, Double(activeMinutes) / 60.0)
        let switchesPerHour = Int(Double(totalSwitches) / hours)

        // 2. Keystroke Cadence (Words Per Minute estimate)
        let totalKeys = max(todayStats.keystrokes, liveKeystrokes)
        let words = totalKeys / 5
        let wpm = min(140, max(0, words / max(1, activeMinutes)))

        // 3. Average Focus Sprint Length
        let focusSprints = max(1, totalSwitches + 1)
        let avgSprintMinutes = max(3, activeMinutes / focusSprints)

        // 4. Calculate CFI (0-100)
        let switchPenalty = Double(switchesPerHour * 3)
        let sprintBonus = Double(avgSprintMinutes) * 1.5
        let wpmBonus = Double(wpm) * 0.2
        var rawCFI = switchPenalty - sprintBonus - wpmBonus + 20.0
        rawCFI = max(5.0, min(95.0, rawCFI))

        let cfi = Int(rawCFI)
        let flow = 100 - cfi

        // 5. Label and Narrative Synthesis
        let label: String
        let narrative: String
        let topApp = todayStats.apps.first?.name ?? "Lumen"

        if flow >= 80 {
            label = "Deep Flow State"
            narrative = "High cognitive momentum in \(topApp) with low context switching (\(switchesPerHour) switches/hr)."
        } else if flow >= 60 {
            label = "Focused Momentum"
            narrative = "Steady productivity pacing with \(avgSprintMinutes)m average focus sprints."
        } else if flow >= 40 {
            label = "Moderate Multitasking"
            narrative = "Frequent app switching across \(appCount) apps. Focus sprints averaging \(avgSprintMinutes)m."
        } else {
            label = "High Task Fragmentation"
            narrative = "Elevated context switching (\(switchesPerHour)/hr). Consider enabling Focus Shield."
        }

        return CognitiveFragmentationSnapshot(
            cfiScore: cfi,
            flowScore: flow,
            flowStateLabel: label,
            switchesPerHour: switchesPerHour,
            averageFocusSprintMinutes: avgSprintMinutes,
            dominantActiveApp: topApp,
            keystrokeCadenceWPM: wpm,
            narrative: narrative,
            timestamp: Date()
        )
    }
}
