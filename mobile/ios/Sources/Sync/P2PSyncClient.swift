import Foundation
import Network

/// iOS P2P Sync Client (Bonjour Browser).
/// Automatically discovers your Mac on local Wi-Fi / USB tether and transmits
/// the day's buffered JSONL stream without any cloud intermediary.
public final class P2PSyncClient {
    public static let shared = P2PSyncClient()

    private var browser: NWBrowser?
    private var connection: NWConnection?
    private let queue = DispatchQueue(label: "com.lumen.p2p.client", qos: .utility)
    
    public private(set) var discoveredEndpoints: [NWEndpoint] = []
    public private(set) var isSearching: Bool = false
    public var onSyncStatusChanged: ((String) -> Void)?

    private init() {}

    public func startDiscovery() {
        guard !isSearching else { return }
        let parameters = NWParameters.tcp
        browser = NWBrowser(for: .bonjour(type: "_lumen-sync._tcp", domain: nil), using: parameters)

        browser?.stateUpdateHandler = { [weak self] state in
            switch state {
            case .ready:
                self?.isSearching = true
            case .failed, .cancelled:
                self?.isSearching = false
            default:
                break
            }
        }

        browser?.browseResultsChangedHandler = { [weak self] results, _ in
            guard let self = self else { return }
            self.discoveredEndpoints = results.map { $0.endpoint }
            if let first = self.discoveredEndpoints.first {
                // Auto-sync on first discovery
                self.syncWithEndpoint(first)
            }
        }

        browser?.start(queue: queue)
    }

    public func stopDiscovery() {
        browser?.cancel()
        browser = nil
        isSearching = false
    }

    public func triggerManualP2PSync() {
        if let target = discoveredEndpoints.first {
            syncWithEndpoint(target)
        } else {
            startDiscovery()
            onSyncStatusChanged?("Searching for Mac on local Wi-Fi / USB...")
        }
    }

    public func syncWithEndpoint(_ endpoint: NWEndpoint) {
        MobileDataStore.shared.flush()
        let day = MobileFormat.dayString()
        let file = MobileDataStore.shared.bufferFile(for: day)
        guard let data = try? Data(contentsOf: file), !data.isEmpty else {
            onSyncStatusChanged?("Buffer is empty")
            return
        }

        onSyncStatusChanged?("Connecting to Mac...")
        let conn = NWConnection(to: endpoint, using: .tcp)
        self.connection = conn

        conn.stateUpdateHandler = { [weak self] state in
            guard let self = self else { return }
            switch state {
            case .ready:
                self.transmitBuffer(data: data, connection: conn)
            case .failed(let err):
                self.onSyncStatusChanged?("P2P Connection failed: \(err.localizedDescription)")
                conn.cancel()
            case .cancelled:
                break
            default:
                break
            }
        }

        conn.start(queue: queue)
    }

    private func transmitBuffer(data: Data, connection: NWConnection) {
        onSyncStatusChanged?("Transmitting \(data.count) bytes...")
        
        // 4-byte length prefix
        var length = UInt32(data.count).bigEndian
        var packet = Data(bytes: &length, count: 4)
        packet.append(data)

        connection.send(content: packet, completion: .contentProcessed({ [weak self] error in
            if let error = error {
                self?.onSyncStatusChanged?("Send error: \(error.localizedDescription)")
                connection.cancel()
                return
            }

            // Await acknowledgment response
            connection.receive(minimumIncompleteLength: 1, maximumLength: 1024) { [weak self] ackData, _, _, _ in
                if let ackData = ackData, let str = String(data: ackData, encoding: .utf8), str.contains("ok") {
                    DispatchQueue.main.async {
                        self?.onSyncStatusChanged?("✓ P2P Synced to Mac successfully!")
                    }
                } else {
                    DispatchQueue.main.async {
                        self?.onSyncStatusChanged?("✓ Buffer transmitted to Mac")
                    }
                }
                connection.cancel()
            }
        }))
    }
}
