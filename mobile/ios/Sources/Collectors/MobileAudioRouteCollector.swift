import Foundation
import AVFoundation

public final class MobileAudioRouteCollector {
    public static let shared = MobileAudioRouteCollector()
    public private(set) var activeOutputName: String = "Built-in Speaker"

    private init() {}

    public func start() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(audioRouteChanged),
            name: AVAudioSession.routeChangeNotification,
            object: nil
        )
        sampleRoute()
    }

    public func stop() {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func audioRouteChanged() {
        sampleRoute()
    }

    public func sampleRoute() {
        let session = AVAudioSession.sharedInstance()
        guard let output = session.currentRoute.outputs.first else { return }

        let portType = output.portType.rawValue
        let portName = output.portName
        let isHeadphones = (output.portType == .headphones || output.portType == .bluetoothA2DP || output.portType == .bluetoothHFP || output.portType == .bluetoothLE)
        let volume = session.outputVolume

        DispatchQueue.main.async {
            self.activeOutputName = portName
        }

        let payload = MobileAudioRoutePayload(
            observedAt: Date(),
            portName: portName,
            portType: portType,
            outputVolume: volume,
            isHeadphones: isHeadphones
        )

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .audioRoute,
            payload: .audioRoute(payload)
        ))
    }
}
