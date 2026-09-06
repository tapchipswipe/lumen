import Foundation
import Network

/// macOS P2P Sync Host (Bonjour Listener).
/// Listens for paired Lumen Mobile devices on local Wi-Fi or USB tether,
/// receives un-synced mobile JSONL buffers, and ingests them directly into DataStore.
public final class P2PSyncHost {
    public static let shared = P2PSyncHost()
    
    private var listener: NWListener?
    private let queue = DispatchQueue(label: "com.lumen.p2p.host", qos: .utility)
    public private(set) var isListening: Bool = false
    public private(set) var lastMobileSyncDate: Date?
    public private(set) var lastMobileEventCount: Int = 0

    private init() {}

    public func start() {
        guard !isListening else { return }
        do {
            let parameters = NWParameters.tcp
            listener = try NWListener(using: parameters)
            
            // Advertise Bonjour service
            listener?.service = NWListener.Service(name: "Lumen-Mac-\(Host.current().localizedName ?? "Desktop")", type: "_lumen-sync._tcp")
            
            listener?.stateUpdateHandler = { [weak self] state in
                switch state {
                case .ready:
                    self?.isListening = true
                    Log.sync.notice("[P2PSyncHost] Bonjour Listener ready on _lumen-sync._tcp")
                case .failed(let error):
                    self?.isListening = false
                    Log.sync.error("[P2PSyncHost] Listener failed: \(error.localizedDescription)")
                case .cancelled:
                    self?.isListening = false
                default:
                    break
                }
            }

            listener?.newConnectionHandler = { [weak self] connection in
                self?.handleIncomingConnection(connection)
            }

            listener?.start(queue: queue)
        } catch {
            Log.sync.error("[P2PSyncHost] Failed to initialize NWListener: \(error.localizedDescription)")
        }
    }

    public func stop() {
        listener?.cancel()
        listener = nil
        isListening = false
    }

    private func handleIncomingConnection(_ connection: NWConnection) {
        connection.start(queue: queue)
        receivePayload(connection: connection)
    }

    private func receivePayload(connection: NWConnection) {
        // Read 4-byte big-endian length prefix first
        connection.receive(minimumIncompleteLength: 4, maximumLength: 4) { [weak self] content, _, isComplete, error in
            guard let self = self, let content = content, content.count == 4, error == nil else {
                connection.cancel()
                return
            }

            let length = content.withUnsafeBytes { $0.load(as: UInt32.self).bigEndian }
            guard length > 0 && length < 50 * 1024 * 1024 else { // 50MB safety cap
                connection.cancel()
                return
            }

            // Read the full body
            connection.receive(minimumIncompleteLength: Int(length), maximumLength: Int(length)) { [weak self] data, _, _, error in
                guard let self = self, let data = data, data.count == Int(length), error == nil else {
                    connection.cancel()
                    return
                }

                self.processMobileSyncBuffer(data: data) { success, count in
                    // Send JSON acknowledgment
                    let ack = "{\"status\":\"\(success ? "ok" : "error")\",\"syncedCount\":\(count)}\n"
                    if let ackData = ack.data(using: .utf8) {
                        connection.send(content: ackData, completion: .contentProcessed({ _ in
                            connection.cancel()
                        }))
                    } else {
                        connection.cancel()
                    }
                }
            }
        }
    }

    private func processMobileSyncBuffer(data: Data, completion: @escaping (Bool, Int) -> Void) {
        let day = SyncFormat.dayString()
        let mobileBufferFile = DataStore.shared.bufferDir.appendingPathComponent("events-\(day)-iphone.jsonl")
        
        var count = 0
        data.split(separator: 0x0A).forEach { slice in
            if !slice.isEmpty { count += 1 }
        }

        // Append to local mobile buffer on Mac
        if FileManager.default.fileExists(atPath: mobileBufferFile.path) {
            if let handle = try? FileHandle(forWritingTo: mobileBufferFile) {
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                try? handle.write(contentsOf: data)
            }
        } else {
            try? data.write(to: mobileBufferFile, options: .atomic)
        }

        DispatchQueue.main.async {
            self.lastMobileSyncDate = Date()
            self.lastMobileEventCount = count
            DataStore.shared.recordSync(date: Date(), success: true, detail: "P2P Mobile Ingest: \(count) events")
            Log.sync.notice("[P2PSyncHost] Ingested \(count) events directly from iPhone via P2P Bonjour bridge.")
            completion(true, count)
        }
    }
}
