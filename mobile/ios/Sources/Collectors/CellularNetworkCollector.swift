import Foundation
import Network
import CoreTelephony

public final class CellularNetworkCollector {
    public static let shared = CellularNetworkCollector()
    private let monitor = NWPathMonitor()
    private let queue = DispatchQueue(label: "com.lumen.mobile.network")
    private let networkInfo = CTTelephonyNetworkInfo()

    public private(set) var currentRadioType: String = "Wi-Fi"
    public private(set) var isConnected: Bool = true

    private init() {}

    public func start() {
        monitor.pathUpdateHandler = { [weak self] path in
            self?.handlePathUpdate(path)
        }
        monitor.start(queue: queue)
    }

    public func stop() {
        monitor.cancel()
    }

    private func handlePathUpdate(_ path: NWPath) {
        let isWiFi = path.usesInterfaceType(.wifi)
        let isCellular = path.usesInterfaceType(.cellular)
        let isExpensive = path.isExpensive
        let isConstrained = path.isConstrained

        var carrier: String? = nil
        var radioTech: String? = nil

        if isCellular {
            if let providers = networkInfo.serviceSubscriberCellularProviders {
                carrier = providers.values.first?.carrierName
            }
            if let radioTechDict = networkInfo.serviceCurrentRadioAccessTechnology {
                radioTech = radioTechDict.values.first
            }
        }

        let radioSummary = isWiFi ? "Wi-Fi" : (radioTech ?? "Cellular")
        DispatchQueue.main.async {
            self.currentRadioType = radioSummary
            self.isConnected = (path.status == .satisfied)
        }

        let payload = CellularNetworkPayload(
            observedAt: Date(),
            carrierName: carrier,
            radioTechnology: radioSummary,
            isWiFi: isWiFi,
            isCellular: isCellular,
            isExpensive: isExpensive,
            isConstrained: isConstrained,
            activeSSID: nil
        )

        MobileDataStore.shared.append(MobileTrackerEvent(
            kind: .cellularContext,
            payload: .cellularContext(payload)
        ))
    }
}
