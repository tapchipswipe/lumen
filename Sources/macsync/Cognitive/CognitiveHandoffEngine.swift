import Foundation

/// Cross-Device Cognitive Fusion Engine.
/// Fuses Mac desk focus with iPhone kinetic movement to classify breaks
/// and generate intelligent Context Resumption cards upon returning to the desk.
public final class CognitiveHandoffEngine {

    public struct BreakContext: Codable {
        public let breakDurationMinutes: Int
        public let classification: String // "Kinetic Recharge (Walk)", "Transit", "Mobile Triage", "Away"
        public let stepsDuringBreak: Int
        public let previousProject: String
        public let previousBranch: String
        public let resumptionPrompt: String
        
        public init(breakDurationMinutes: Int, classification: String, stepsDuringBreak: Int, previousProject: String, previousBranch: String, resumptionPrompt: String) {
            self.breakDurationMinutes = breakDurationMinutes
            self.classification = classification
            self.stepsDuringBreak = stepsDuringBreak
            self.previousProject = previousProject
            self.previousBranch = previousBranch
            self.resumptionPrompt = resumptionPrompt
        }
    }

    public static func evaluateHandoff(
        lastActiveProject: String,
        lastBranch: String,
        idleDurationSeconds: TimeInterval,
        stepCount: Int = 0,
        isWalking: Bool = false,
        isDriving: Bool = false
    ) -> BreakContext {
        let mins = Int(idleDurationSeconds / 60.0)

        let classification: String
        let prompt: String

        if isWalking && stepCount > 200 {
            classification = "Kinetic Walk & Recharge"
            prompt = "You took a \(mins)m walk (\(stepCount) steps). Ready to resume '\(lastActiveProject)' on branch '\(lastBranch)'."
        } else if isDriving {
            classification = "Transit / Commute"
            prompt = "Returned from transit. Context restore: '\(lastActiveProject)' (\(lastBranch))."
        } else if mins < 15 {
            classification = "Short Micro-Break"
            prompt = "Back at desk after \(mins)m. Pick back up on '\(lastActiveProject)'."
        } else {
            classification = "Away from Desk"
            prompt = "Resuming after \(mins)m. Open branch: '\(lastBranch)'."
        }

        return BreakContext(
            breakDurationMinutes: mins,
            classification: classification,
            stepsDuringBreak: stepCount,
            previousProject: lastActiveProject,
            previousBranch: lastBranch,
            resumptionPrompt: prompt
        )
    }
}
