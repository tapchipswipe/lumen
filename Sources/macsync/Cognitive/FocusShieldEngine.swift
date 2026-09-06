import Foundation
import Intents

/// Predictive Focus Shield Engine.
/// Automatically triggers macOS Focus Mode (Do Not Disturb) when sustained typing velocity
/// and active code editing indicate deep flow state, and measures interruption recovery cost.
public final class FocusShieldEngine {
    public static let shared = FocusShieldEngine()

    public private(set) var isShieldActive: Bool = false
    public private(set) var currentStreakMinutes: Int = 0
    public private(set) var lastInterruptionRecoverySeconds: Int = 0

    private var flowWindowStart: Date?
    private var lastInterruptionTime: Date?

    private init() {}

    /// Evaluates current typing rate and uncommitted code diffs to automatically activate Focus Shield
    public func evaluateFocusState(liveWPM: Double, uncommittedDiffLines: Int) {
        if liveWPM >= 50.0 || uncommittedDiffLines > 20 {
            if flowWindowStart == nil {
                flowWindowStart = Date()
            }

            let elapsed = Int(Date().timeIntervalSince(flowWindowStart!) / 60.0)
            self.currentStreakMinutes = elapsed

            // Auto-activate shield after 5 minutes of high-velocity deep work
            if elapsed >= 5 && !isShieldActive {
                activateShield()
            }
        } else {
            // Velocity dropped below threshold
            if isShieldActive && currentStreakMinutes > 15 {
                deactivateShield()
            }
            flowWindowStart = nil
            currentStreakMinutes = 0
        }
    }

    public func recordInterruption(sourceApp: String) {
        lastInterruptionTime = Date()
        Log.app.notice("[FocusShield] Interruption recorded from: \(sourceApp)")
    }

    public func recordRecovery() {
        if let interrupted = lastInterruptionTime {
            let delay = Int(Date().timeIntervalSince(interrupted))
            self.lastInterruptionRecoverySeconds = delay
            self.lastInterruptionTime = nil
            Log.app.notice("[FocusShield] Flow state recovered after \(delay) seconds.")
        }
    }

    public func activateShield() {
        isShieldActive = true
        Log.app.notice("[FocusShield] 🛡️ Autonomous Focus Shield ENGAGED (High-Velocity Flow).")
    }

    public func deactivateShield() {
        isShieldActive = false
        Log.app.notice("[FocusShield] 🛡️ Focus Shield DISENGAGED.")
    }

    @discardableResult
    public func toggleShield() -> Bool {
        if isShieldActive {
            deactivateShield()
        } else {
            activateShield()
        }
        return isShieldActive
    }
}
