import Foundation
import ActivityKit
import SwiftUI

// MARK: - Activity Attributes (Dynamic Island & Lock Screen)

public struct LumenActivityAttributes: ActivityAttributes {
    public struct ContentState: Codable, Hashable {
        public var activeFocusMinutes: Int
        public var currentBranch: String
        public var batteryRunwayWatts: Double
        public var currentActivity: String // "Deep Work", "Walking", "Transit"
        public var bufferedEvents: Int
        
        public init(activeFocusMinutes: Int, currentBranch: String, batteryRunwayWatts: Double, currentActivity: String, bufferedEvents: Int) {
            self.activeFocusMinutes = activeFocusMinutes
            self.currentBranch = currentBranch
            self.batteryRunwayWatts = batteryRunwayWatts
            self.currentActivity = currentActivity
            self.bufferedEvents = bufferedEvents
        }
    }

    public var sessionTitle: String
    public init(sessionTitle: String = "Lumen Cognitive Session") {
        self.sessionTitle = sessionTitle
    }
}

// MARK: - Live Activity Coordinator

public final class LumenLiveActivityManager {
    public static let shared = LumenLiveActivityManager()
    private var currentActivity: Activity<LumenActivityAttributes>?

    private init() {}

    public func startLiveActivity(branch: String = "main", activityName: String = "Deep Work") {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        
        let attributes = LumenActivityAttributes(sessionTitle: "Lumen Deep Work")
        let initialState = LumenActivityAttributes.ContentState(
            activeFocusMinutes: 0,
            currentBranch: branch,
            batteryRunwayWatts: 4.2,
            currentActivity: activityName,
            bufferedEvents: MobileDataStore.shared.todayEventCount
        )

        do {
            let activity = try Activity<LumenActivityAttributes>.request(
                attributes: attributes,
                content: .init(state: initialState, staleDate: nil),
                pushType: nil
            )
            self.currentActivity = activity
        } catch {
            print("[LiveActivity] Request failed: \(error.localizedDescription)")
        }
    }

    public func updateLiveActivity(focusMinutes: Int, branch: String, watts: Double, activityName: String) {
        Task {
            let updatedState = LumenActivityAttributes.ContentState(
                activeFocusMinutes: focusMinutes,
                currentBranch: branch,
                batteryRunwayWatts: watts,
                currentActivity: activityName,
                bufferedEvents: MobileDataStore.shared.todayEventCount
            )
            await currentActivity?.update(.init(state: updatedState, staleDate: nil))
        }
    }

    public func endLiveActivity() {
        Task {
            await currentActivity?.end(dismissalPolicy: .immediate)
            self.currentActivity = nil
        }
    }
}
