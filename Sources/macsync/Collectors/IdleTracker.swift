import CoreGraphics
import Foundation

/// Tracks idle sessions using CGEventSource.secondsSinceLastEventType.
/// Any inactivity >= threshold opens an idle session; the next activity closes it.
final class IdleTracker {
    static let idleThresholdSeconds: TimeInterval = 300 // 5 minutes

    private let store = DataStore.shared
    private let queue = DispatchQueue(label: "com.lumen.idle", qos: .utility)
    private var timer: DispatchSourceTimer?

    private var idleStart: Date?
    private var wasIdle = false

    func start() {
        stop()
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + 5, repeating: 5.0)
        timer.setEventHandler { [weak self] in self?.check() }
        timer.resume()
        self.timer = timer
    }

    func stop() {
        timer?.cancel()
        timer = nil
        queue.async { [weak self] in self?.closeIdleSession(at: Date()) }
    }

    private func check() {
        // Combined user input across keyboard + pointing devices.
        let keyboard = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .keyDown)
        let mouse = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .mouseMoved)
        let clicks = CGEventSource.secondsSinceLastEventType(.combinedSessionState, eventType: .leftMouseDown)
        let idleSeconds = min(keyboard, min(mouse, clicks))

        let now = Date()
        if idleSeconds >= Self.idleThresholdSeconds {
            if !wasIdle {
                wasIdle = true
                idleStart = now.addingTimeInterval(-idleSeconds)
            }
        } else if wasIdle {
            wasIdle = false
            closeIdleSession(at: now.addingTimeInterval(-idleSeconds))
        }
    }

    private func closeIdleSession(at end: Date) {
        guard let start = idleStart else { return }
        idleStart = nil
        let duration = end.timeIntervalSince(start)
        guard duration >= Self.idleThresholdSeconds else { return }
        let payload = IdleSessionPayload(start: start, end: end, durationSeconds: duration)
        store.append(TrackerEvent(ts: end, kind: .idleSession, payload: .idleSession(payload)))
    }
}
