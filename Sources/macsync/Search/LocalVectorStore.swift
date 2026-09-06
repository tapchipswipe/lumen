import Foundation

/// On-Device Semantic Vector Memory Engine.
/// Generates lightweight local embeddings and executes fast cosine similarity
/// ranking across months of lifelogs, window titles, Git commits, receipts, and music flow.
public final class LocalVectorStore {
    public static let shared = LocalVectorStore()

    public struct Document: Codable, Identifiable {
        public let id: String
        public let text: String
        public let category: String // "Window", "Git", "Receipt", "Music", "Standup"
        public let timestamp: Date
        public let embedding: [Float]
    }

    public struct SearchResult: Identifiable {
        public var id: String { document.id }
        public let document: Document
        public let score: Float // Cosine similarity 0.0 ... 1.0
    }

    private var documents: [Document] = []
    private let queue = DispatchQueue(label: "com.lumen.vectorstore", qos: .userInitiated)

    private init() {}

    // MARK: - Ingestion & Indexing

    func indexLifelogEvents(_ events: [TrackerEvent]) {
        queue.sync { [weak self] in
            guard let self = self else { return }
            for ev in events {
                switch ev.payload {
                case .windowFocus(let w):
                    if let title = w.windowTitle, !title.isEmpty {
                        self.addDocument(text: "\(w.appName): \(title)", category: "Window", date: w.start)
                    }
                case .gitVelocity(let g):
                    self.addDocument(text: "Git repo \(g.repoName) on branch \(g.branch)", category: "Git", date: g.observedAt)
                case .receipt(let r):
                    self.addDocument(text: "Receipt from \(r.merchant) for $\(r.amount) (\(r.category.label))", category: "Receipt", date: r.transactionDate)
                case .nowPlaying(let m):
                    if let title = m.title, let artist = m.artist {
                        self.addDocument(text: "Music track \(title) by \(artist)", category: "Music", date: m.observedAt)
                    }
                default:
                    break
                }
            }
        }
    }

    private func addDocument(text: String, category: String, date: Date) {
        let vec = computePseudoEmbedding(text: text)
        let doc = Document(
            id: UUID().uuidString,
            text: text,
            category: category,
            timestamp: date,
            embedding: vec
        )
        documents.append(doc)
        if documents.count > 5000 {
            documents.removeFirst()
        }
    }

    // MARK: - Semantic Search & Cosine Similarity

    public func search(query: String, limit: Int = 10) -> [SearchResult] {
        guard !documents.isEmpty && !query.isEmpty else { return [] }
        let queryVec = computePseudoEmbedding(text: query)
        
        var results: [SearchResult] = []
        for doc in documents {
            let sim = cosineSimilarity(queryVec, doc.embedding)
            if sim > 0.15 {
                results.append(SearchResult(document: doc, score: sim))
            }
        }

        return results.sorted { $0.score > $1.score }.prefix(limit).map { $0 }
    }

    // MARK: - Mathematical Vector Utilities

    private func computePseudoEmbedding(text: String) -> [Float] {
        let tokens = text.lowercased().components(separatedBy: CharacterSet.alphanumerics.inverted).filter { !$0.isEmpty }
        var vector = [Float](repeating: 0.0, count: 64)
        for token in tokens {
            let hash = abs(token.hashValue)
            let idx = hash % 64
            vector[idx] += 1.0
        }
        // Normalize vector
        let mag = sqrt(vector.reduce(0.0) { $0 + $1 * $1 })
        if mag > 0.0 {
            for i in 0..<vector.count { vector[i] /= mag }
        }
        return vector
    }

    private func cosineSimilarity(_ a: [Float], _ b: [Float]) -> Float {
        guard a.count == b.count else { return 0.0 }
        var dot: Float = 0.0
        for i in 0..<a.count { dot += a[i] * b[i] }
        return max(0.0, dot)
    }
}
