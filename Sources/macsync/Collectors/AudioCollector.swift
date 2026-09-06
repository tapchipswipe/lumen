import Foundation
import AVFoundation

final class AudioCollector {
    private var timer: Timer?

    func start() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 60.0, repeats: true) { [weak self] _ in
            self?.poll()
        }
        poll()
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    func poll() {
        DispatchQueue.global(qos: .utility).async { [weak self] in
            guard let self = self else { return }
            let (deviceName, isAirPods, isHeadphones) = self.getAudioOutputDetails()
            let payload = AudioRoutePayload(
                observedAt: Date(),
                outputDeviceName: deviceName,
                isAirPods: isAirPods,
                isHeadphones: isHeadphones,
                volume: 0.5
            )
            DataStore.shared.append(TrackerEvent(ts: Date(), kind: .audioRoute, payload: .audioRoute(payload)))
        }
    }

    private func getAudioOutputDetails() -> (name: String, isAirPods: Bool, isHeadphones: Bool) {
        // Use system_profiler SPAudioDataType or default fallback
        let p = Process()
        p.executableURL = URL(fileURLWithPath: "/usr/sbin/system_profiler")
        p.arguments = ["SPAudioDataType", "-json"]
        let pipe = Pipe()
        p.standardOutput = pipe
        p.standardError = Pipe()
        try? p.run()
        p.waitUntilExit()
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        let str = String(data: data, encoding: .utf8) ?? ""

        let lower = str.lowercased()
        let isAirPods = lower.contains("airpods")
        let isHeadphones = isAirPods || lower.contains("headphone") || lower.contains("bluetooth")
        let name = isAirPods ? "AirPods Pro" : (isHeadphones ? "External Headphones" : "MacBook Speakers")

        return (name, isAirPods, isHeadphones)
    }
}
