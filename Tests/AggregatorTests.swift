import CryptoKit
import Foundation

enum AggregatorTests {
    static func run() {
        var events: [TrackerEvent] = []
        let now = Date()
        events.append(TrackerEvent(ts: now, kind: .inputMetrics, payload: .inputMetrics(
            InputMetricsPayload(bucketStart: now, bucketEnd: now, keystrokeCount: 42,
                                mouseClickCount: 3, scrollEvents: 1, cursorDistancePoints: 100,
                                activeSeconds: 60, tapEnabled: true))))
        events.append(TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
            AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1,
                            start: now, end: now.addingTimeInterval(120), durationSeconds: 120))))
        events.append(TrackerEvent(ts: now, kind: .idleSession, payload: .idleSession(
            IdleSessionPayload(start: now, end: now.addingTimeInterval(300), durationSeconds: 300))))

        let s = TodayAggregator.compute(events: events, archived: [])
        expect(s.keystrokes == 42, "keystrokes sum")
        expect(s.clicks == 3, "clicks sum")
        expect(s.cursorDistance == 100, "cursor sum")
        expect(s.focusSessions == 1, "focus sessions")
        expect(s.apps.first?.name == "Xcode", "top app")
        expect(s.categories.first?.category == .code, "Xcode tagged as Code (#3)")
        expect(s.idleSeconds == 300, "idle seconds")
        expect(!s.insights.isEmpty, "plain-English insights (#18)")

        // Anomaly (#4): big Xcode day vs small archived days
        var archived: [(day: String, events: [TrackerEvent])] = []
        for i in 1...3 {
            archived.append(("2026-0\(i)-0\(i)", [TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
                AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1, start: now,
                                end: now.addingTimeInterval(60), durationSeconds: 1800)))]))
        }
        let big = TodayAggregator.compute(events: [TrackerEvent(ts: now, kind: .appFocus, payload: .appFocus(
            AppFocusPayload(appName: "Xcode", bundleID: nil, pid: 1, start: now,
                            end: now.addingTimeInterval(7200), durationSeconds: 7200)))], archived: archived)
        expect(big.anomaly != nil, "anomaly fires (#4)")
        contextPack()
    }

    /// v0.4.0 context pack aggregator: meeting inference, media playback
    /// seconds, and clipboard/mail/session/network/lifecycle/focus math.
    static func contextPack() {
        let t0 = Date(timeIntervalSince1970: 1_700_000_000) // 2023-11-14

        // Meeting inference: camera on (t0..t0+30); short non-meeting gap is
        // bridged; the long gap breaks the interval at t0+300; a new meeting
        // latch closes at the last sample (t0+330, no-op).
        let meeting: [TrackerEvent] = [
            TrackerEvent(ts: t0, kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0, cameraActive: true, microphoneActive: true, frontmostApp: "Zoom"))),
            TrackerEvent(ts: t0.addingTimeInterval(30), kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0.addingTimeInterval(30), cameraActive: true, microphoneActive: true, frontmostApp: "Zoom"))),
            TrackerEvent(ts: t0.addingTimeInterval(60), kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0.addingTimeInterval(60), cameraActive: false, microphoneActive: false, frontmostApp: "Xcode"))),
            TrackerEvent(ts: t0.addingTimeInterval(300), kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0.addingTimeInterval(300), cameraActive: false, microphoneActive: false, frontmostApp: "Xcode"))),
            TrackerEvent(ts: t0.addingTimeInterval(330), kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0.addingTimeInterval(330), cameraActive: true, microphoneActive: false, frontmostApp: "Teams"))),
        ]
        let ms = TodayAggregator.compute(events: meeting, archived: [])
        expect(abs(ms.meetingSeconds - 300) < 1, "meeting inference: camera+gap bridge/break+relatch")

        // Mic-only with a NON-meeting frontmost app must NOT count as a meeting.
        let nonMeeting = [TrackerEvent(ts: t0, kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
            observedAt: t0, cameraActive: false, microphoneActive: true, frontmostApp: "Xcode")))]
        let nm = TodayAggregator.compute(events: nonMeeting, archived: [])
        expect(nm.meetingSeconds == 0, "mic-on in Xcode does not count as meeting")

        // Mic-only with a meeting app DOES count; consecutive meeting samples
        // own the interval from the first to the last sample.
        let callByMic: [TrackerEvent] = [
            TrackerEvent(ts: t0, kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0, cameraActive: false, microphoneActive: true, frontmostApp: "Zoom"))),
            TrackerEvent(ts: t0.addingTimeInterval(90), kind: .cameraMicState, payload: .cameraMicState(CameraMicPayload(
                observedAt: t0.addingTimeInterval(90), cameraActive: false, microphoneActive: true, frontmostApp: "Zoom"))),
        ]
        let cbm = TodayAggregator.compute(events: callByMic, archived: [])
        expect(abs(cbm.meetingSeconds - 90) < 1, "mic-on in Zoom = meeting")

        // Media playback seconds by app: each playing sample owns the interval
        // to the next sample (2 x 30s playing, last sample stopped -> 60s).
        let mediaEvents: [TrackerEvent] = [
            TrackerEvent(ts: t0, kind: .nowPlaying, payload: .nowPlaying(NowPlayingPayload(
                observedAt: t0, appName: "Spotify", title: "T1", artist: "A", isPlaying: true))),
            TrackerEvent(ts: t0.addingTimeInterval(30), kind: .nowPlaying, payload: .nowPlaying(NowPlayingPayload(
                observedAt: t0.addingTimeInterval(30), appName: "Spotify", title: "T1", artist: "A", isPlaying: true))),
            TrackerEvent(ts: t0.addingTimeInterval(60), kind: .nowPlaying, payload: .nowPlaying(NowPlayingPayload(
                observedAt: t0.addingTimeInterval(60), appName: "Spotify", title: "T2", artist: "A", isPlaying: false))),
        ]
        let md = TodayAggregator.compute(events: mediaEvents, archived: [])
        expect(abs((md.mediaSeconds["Spotify"] ?? 0) - 60) < 1, "media playback seconds by app")
        expect(md.nowPlaying?.isPlaying == false, "latest now-playing captured")

        // Clipboard / mail / sessions / network / lifecycle / focus.
        let cb = Date(timeIntervalSince1970: 1_700_010_000)
        var ctx: [TrackerEvent] = []
        for (i, n) in [2, 3, 6].enumerated() {
            ctx.append(TrackerEvent(ts: cb.addingTimeInterval(Double(i) * 5), kind: .clipboardMetric, payload: .clipboardMetric(
                ClipboardMetricPayload(observedAt: cb.addingTimeInterval(Double(i) * 5), copiesInInterval: n,
                                       contentTypes: ["public.utf8-plain-text"], byteSize: 42))))
        }
        ctx.append(TrackerEvent(ts: cb, kind: .mailStats, payload: .mailStats(
            MailStatsPayload(observedAt: cb, unreadCount: 4, receivedToday: 9, sentToday: 2,
                             topSenders: ["Alice", "Bob"], success: true, errorMessage: nil))))
        ctx.append(TrackerEvent(ts: cb, kind: .sessionEvent, payload: .sessionEvent(SessionEventPayload(observedAt: cb, event: .screenLocked))))
        ctx.append(TrackerEvent(ts: cb.addingTimeInterval(10), kind: .sessionEvent, payload: .sessionEvent(SessionEventPayload(observedAt: cb.addingTimeInterval(10), event: .screenLocked))))
        ctx.append(TrackerEvent(ts: cb.addingTimeInterval(20), kind: .sessionEvent, payload: .sessionEvent(SessionEventPayload(observedAt: cb.addingTimeInterval(20), event: .systemWake))))
        ctx.append(TrackerEvent(ts: cb, kind: .networkContext, payload: .networkContext(NetworkContextPayload(
            observedAt: cb, ssid: "AnselmSecure", bssidHash: "abc123", rssi: -46, onVPN: true))))
        ctx.append(TrackerEvent(ts: cb, kind: .appLifecycle, payload: .appLifecycle(AppLifecyclePayload(observedAt: cb, appName: "Xcode", bundleID: nil, event: .launched))))
        ctx.append(TrackerEvent(ts: cb, kind: .appLifecycle, payload: .appLifecycle(AppLifecyclePayload(observedAt: cb, appName: "Xcode", bundleID: nil, event: .launched))))
        ctx.append(TrackerEvent(ts: cb, kind: .appLifecycle, payload: .appLifecycle(AppLifecyclePayload(observedAt: cb, appName: "Safari", bundleID: nil, event: .launched))))
        ctx.append(TrackerEvent(ts: cb, kind: .appLifecycle, payload: .appLifecycle(AppLifecyclePayload(observedAt: cb, appName: "Safari", bundleID: nil, event: .terminated))))
        ctx.append(TrackerEvent(ts: cb, kind: .focusModeState, payload: .focusModeState(FocusModePayload(observedAt: cb, focusActive: true, authorized: true))))

        let c = TodayAggregator.compute(events: ctx, archived: [])
        expect(c.clipboardCopies == 11, "clipboard copies sum")
        expect(c.mailUnread == 4 && c.mailReceivedToday == 9 && c.mailSentToday == 2, "mail counts")
        expect(c.mailTopSenders == Optional(["Alice", "Bob"]), "mail top senders")
        expect(c.screenLockCount == 2 && c.wakeCount == 1, "session lock/wake counts")
        expect(c.wifiSSID == "AnselmSecure" && c.onVPN == true, "network context")
        expect(c.appLaunches == ["Xcode": 2, "Safari": 1], "app launch counts")
        expect(c.focusActive == true, "focus state passthrough")
    }

}

enum CryptoTests {
    static func run() {
        let key = SymmetricKey(size: .bits256)
        let secret = Data("lumen archive test payload 🔒".utf8)
        do {
            let sealed = try CryptoVault.seal(secret, key: key)
            expect(sealed != secret, "ciphertext differs")
            let opened = try CryptoVault.open(sealed, key: key)
            expect(opened == secret, "AES-GCM roundtrip (#9)")
        } catch { expect(false, "crypto threw: \(error)") }
    }
}

enum CategoryTests {
    static func run() {
        expect(ActivityCategory.forApp("Xcode") == .code, "Xcode → Code")
        expect(ActivityCategory.forApp("Slack") == .comms, "Slack → Comms")
        expect(ActivityCategory.forApp("Figma") == .design, "Figma → Design")
        expect(ActivityCategory.forURL("https://github.com/tapchipswipe/lumen") == .code, "github → Code (#3)")
        expect(ActivityCategory.forURL("https://youtube.com/watch") == .media, "youtube → Media")
    }
}


enum UpdateTests {
    static func run() {
        expect(UpdateChecker.isNewer("v0.4.0", than: "0.3.1"), "newer minor (#update)")
        expect(UpdateChecker.isNewer("0.3.2", than: "0.3.1"), "newer patch")
        expect(UpdateChecker.isNewer("1.0.0", than: "0.9.9"), "newer major")
        expect(!UpdateChecker.isNewer("v0.3.1", than: "0.3.1"), "same version not newer")
        expect(!UpdateChecker.isNewer("0.3.0", than: "0.3.1"), "older not newer")
        expect(UpdateChecker.isNewer("0.4", than: "0.3.1"), "shorter tag treated as 0.4.0")
    }
}
