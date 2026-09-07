import AppKit
import CoreGraphics
import Carbon.HIToolbox

/// Global input METADATA tracker via CGEvent tap.
///
/// PRIVACY / SAFETY CONTRACT:
/// The tap callback reads ONLY the event type and pointer location.
/// It never reads keycodes, characters, or any event payload. Counters are
/// aggregated in memory and flushed as minute-level buckets. This keeps the
/// app firmly in "activity monitor" territory rather than keylogger territory.
final class InputMetricsTracker {
    static let flushIntervalSeconds: TimeInterval = 60

    private let store = DataStore.shared
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var flushTimer: DispatchSourceTimer?
    private let queue = DispatchQueue(label: "com.lumen.inputmetrics", qos: .userInteractive)

    private let lock = NSLock()
    private var bucketStart = Date()
    private var keystrokes = 0
    private var clicks = 0
    private var scrolls = 0
    private var cursorDistance: Double = 0
    private var activeSeconds = 0
    private var lastEventTimestamp: Date?
    private var lastMouseLocation: CGPoint?

    private(set) var tapEnabled = false
    /// True when macOS Secure Input is active AND the tap saw no keyDown events
    /// in the current bucket — meaning keystroke counts are suppressed by the OS.
    private(set) var secureInputSuppressed = false

    func start() {
        stop()
        // Restore any un-flushed counters from a previous run.
        if let snap = store.loadInputSnapshot(),
           SyncFormat.dayString(for: snap.bucketStart) == SyncFormat.dayString() {
            bucketStart = snap.bucketStart
            keystrokes = snap.keystrokes
            clicks = snap.clicks
            scrolls = snap.scrolls
            cursorDistance = snap.cursorDistance
            activeSeconds = snap.activeSeconds
        } else {
            bucketStart = Date()
        }
        // Event taps must be created and attached on the main run loop.
        if Thread.isMainThread {
            createTap()
        } else {
            DispatchQueue.main.async { self.createTap() }
        }
        startFlushTimer()
    }

    func stop() {
        flushTimer?.cancel()
        flushTimer = nil
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
        flushBucket(final: true)
    }

    // MARK: - Event tap

    private func createTap() {
        let mask: CGEventMask =
            (1 << CGEventType.keyDown.rawValue) |
            (1 << CGEventType.leftMouseDown.rawValue) |
            (1 << CGEventType.rightMouseDown.rawValue) |
            (1 << CGEventType.otherMouseDown.rawValue) |
            (1 << CGEventType.mouseMoved.rawValue) |
            (1 << CGEventType.scrollWheel.rawValue)

        let callback: CGEventTapCallBack = { proxy, type, event, refcon in
            guard let refcon else { return Unmanaged.passRetained(event) }
            let tracker = Unmanaged<InputMetricsTracker>.fromOpaque(refcon).takeUnretainedValue()

            if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
                if let tap = tracker.eventTap {
                    CGEvent.tapEnable(tap: tap, enable: true)
                }
                return Unmanaged.passRetained(event)
            }

            // METADATA ONLY: type + pointer location. Never keycodes/characters.
            switch type {
            case .keyDown:
                tracker.incrementKeystroke()
            case .leftMouseDown, .rightMouseDown, .otherMouseDown:
                tracker.incrementClick()
            case .scrollWheel:
                tracker.incrementScroll()
            case .mouseMoved:
                tracker.accumulateCursorDistance(to: event.location)
            default:
                break
            }
            return Unmanaged.passRetained(event)
        }

        let selfPtr = Unmanaged.passUnretained(self).toOpaque()
        eventTap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .listenOnly,
            eventsOfInterest: mask,
            callback: callback,
            userInfo: selfPtr
        )

        if let tap = eventTap {
            runLoopSource = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
            if let source = runLoopSource {
                CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
                CGEvent.tapEnable(tap: tap, enable: true)
                tapEnabled = true
            }
        } else {
            tapEnabled = false
            scheduleTapRetry()
        }
    }

    private func scheduleTapRetry() {
        queue.asyncAfter(deadline: .now() + 30) { [weak self] in
            guard let self, self.eventTap == nil else { return }
            DispatchQueue.main.async { self.createTap() }
        }
    }


    // MARK: - Counter mutations (called from tap thread)

    private var pendingLiveKeystrokes = 0
    private var pendingLiveClicks = 0
    private var isLiveInputFlushScheduled = false

    private func incrementKeystroke() {
        lock.lock()
        keystrokes += 1
        pendingLiveKeystrokes += 1
        lastEventTimestamp = Date()
        let schedule = !isLiveInputFlushScheduled
        isLiveInputFlushScheduled = true
        lock.unlock()

        if schedule {
            queue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let k = self.pendingLiveKeystrokes
                let c = self.pendingLiveClicks
                self.pendingLiveKeystrokes = 0
                self.pendingLiveClicks = 0
                self.isLiveInputFlushScheduled = false
                self.lock.unlock()

                if k > 0 || c > 0 {
                    DispatchQueue.main.async {
                        AppState.shared.recordLiveInput(keystrokes: k, clicks: c)
                    }
                }
            }
        }
    }

    private func incrementClick() {
        lock.lock()
        clicks += 1
        pendingLiveClicks += 1
        lastEventTimestamp = Date()
        let schedule = !isLiveInputFlushScheduled
        isLiveInputFlushScheduled = true
        lock.unlock()

        if schedule {
            queue.asyncAfter(deadline: .now() + 0.15) { [weak self] in
                guard let self else { return }
                self.lock.lock()
                let k = self.pendingLiveKeystrokes
                let c = self.pendingLiveClicks
                self.pendingLiveKeystrokes = 0
                self.pendingLiveClicks = 0
                self.isLiveInputFlushScheduled = false
                self.lock.unlock()

                if k > 0 || c > 0 {
                    DispatchQueue.main.async {
                        AppState.shared.recordLiveInput(keystrokes: k, clicks: c)
                    }
                }
            }
        }
    }

    private func incrementScroll() {
        lock.lock()
        scrolls += 1
        lastEventTimestamp = Date()
        lock.unlock()
    }

    private func accumulateCursorDistance(to point: CGPoint) {
        lock.lock()
        if let last = lastMouseLocation {
            let dx = point.x - last.x
            let dy = point.y - last.y
            let distSq = dx * dx + dy * dy
            if distSq >= 4.0 { // Skip sub-pixel jitter (< 2px)
                cursorDistance += distSq.squareRoot()
                lastMouseLocation = point
            }
        } else {
            lastMouseLocation = point
        }
        lastEventTimestamp = Date()
        lock.unlock()
    }

    /// Called from any tap event to note recency for activeSeconds accounting.
    private func noteEventTime() {
        lock.lock()
        lastEventTimestamp = Date()
        lock.unlock()
    }

    // MARK: - Bucket flushing

    private func startFlushTimer() {
        let timer = DispatchSource.makeTimerSource(queue: queue)
        timer.schedule(deadline: .now() + Self.flushIntervalSeconds, repeating: Self.flushIntervalSeconds)
        timer.setEventHandler { [weak self] in self?.flushBucket() }
        timer.resume()
        flushTimer = timer
    }

    private func flushBucket(final: Bool = false) {
        lock.lock()
        let now = Date()
        // Any event within the last flush window counts the whole bucket as active.
        if let last = lastEventTimestamp, now.timeIntervalSince(last) < Self.flushIntervalSeconds {
            activeSeconds += Int(now.timeIntervalSince(last))
        }
        let hadActivity = keystrokes > 0 || clicks > 0 || scrolls > 0 || cursorDistance > 0
        // Detect Secure Input suppression: OS-level flag is set AND the tap saw
        // zero keyDown events this bucket (under secure input, keyDown is withheld).
        secureInputSuppressed = IsSecureEventInputEnabled() && keystrokes == 0
        let payload = InputMetricsPayload(
            bucketStart: bucketStart,
            bucketEnd: now,
            keystrokeCount: keystrokes,
            mouseClickCount: clicks,
            scrollEvents: scrolls,
            cursorDistancePoints: cursorDistance,
            activeSeconds: activeSeconds,
            tapEnabled: tapEnabled,
            secureInputSuppressed: secureInputSuppressed
        )
        // Reset for next bucket.
        bucketStart = now
        keystrokes = 0
        clicks = 0
        scrolls = 0
        cursorDistance = 0
        activeSeconds = 0
        lock.unlock()

        // Persist a clean snapshot so a crash never loses more than a minute.
        store.saveInputSnapshot(DataStore.InputSnapshot(
            bucketStart: now, keystrokes: 0, clicks: 0, scrolls: 0,
            cursorDistance: 0, activeSeconds: 0
        ))

        if hadActivity || final {
            store.append(TrackerEvent(ts: now, kind: .inputMetrics, payload: .inputMetrics(payload)))
        }
    }
}
