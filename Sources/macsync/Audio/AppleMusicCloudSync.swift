import Foundation
import AppKit

public struct SyncedMusicTrack: Identifiable, Codable {
    public let id: UUID
    public let title: String
    public let artist: String
    public let album: String?
    public let playCount: Int
    public let lastPlayed: Date?
    public let deviceOrigin: String

    public init(id: UUID = UUID(), title: String, artist: String, album: String? = nil, playCount: Int, lastPlayed: Date? = nil, deviceOrigin: String = "Apple Music Library") {
        self.id = id
        self.title = title
        self.artist = artist
        self.album = album
        self.playCount = playCount
        self.lastPlayed = lastPlayed
        self.deviceOrigin = deviceOrigin
    }
}

public struct LibraryArtistStat: Identifiable, Codable {
    public var id: String { artist }
    public let artist: String
    public let totalPlays: Int
    public let trackCount: Int
}

public enum AppleMusicCloudSyncEngine {
    private static var cachedTracks: [SyncedMusicTrack] = []
    private static var cachedTopArtists: [LibraryArtistStat] = []
    private static var lastFetchTime: Date?
    private static let lock = NSLock()

    /// Scans the entire Apple Music library, sorting all tracks by TRUE total play count across all devices.
    public static func fetchCrossDeviceMusicHistory(limit: Int = 20) -> [SyncedMusicTrack] {
        lock.lock()
        if let last = lastFetchTime, Date().timeIntervalSince(last) < 300, !cachedTracks.isEmpty {
            let res = Array(cachedTracks.prefix(limit))
            lock.unlock()
            return res
        }
        lock.unlock()

        let script = """
        tell application "Music"
            try
                set tNames to (name of every track of library playlist 1 whose played count > 0)
                set tArtists to (artist of every track of library playlist 1 whose played count > 0)
                set tCounts to (played count of every track of library playlist 1 whose played count > 0)
                set out to ""
                set c to count of tNames
                repeat with i from 1 to c
                    set out to out & (item i of tNames) & ":::" & (item i of tArtists) & ":::" & (item i of tCounts) & linefeed
                end repeat
                return out
            on error
                return ""
            end try
        end tell
        """

        var errorDict: NSDictionary?
        let result = NSAppleScript(source: script)?.executeAndReturnError(&errorDict)

        guard let raw = result?.stringValue, !raw.isEmpty else {
            return []
        }

        var tracks: [SyncedMusicTrack] = []
        var artistPlayCounts: [String: (totalPlays: Int, tracks: Set<String>)] = [:]
        let lines = raw.components(separatedBy: .newlines)

        for line in lines {
            let parts = line.components(separatedBy: ":::")
            guard parts.count >= 3 else { continue }
            let title = parts[0].trimmingCharacters(in: .whitespacesAndNewlines)
            let artist = parts[1].trimmingCharacters(in: .whitespacesAndNewlines)
            let count = Int(parts[2].trimmingCharacters(in: .whitespacesAndNewlines)) ?? 0

            guard !title.isEmpty, count > 0 else { continue }
            let cleanArtist = artist.isEmpty ? "Unknown Artist" : artist

            tracks.append(SyncedMusicTrack(
                title: title,
                artist: cleanArtist,
                playCount: count,
                deviceOrigin: "Apple Music Library"
            ))

            var existing = artistPlayCounts[cleanArtist] ?? (totalPlays: 0, tracks: [])
            existing.totalPlays += count
            existing.tracks.insert(title)
            artistPlayCounts[cleanArtist] = existing
        }

        // Sort all library tracks by true play count descending
        let sortedTracks = tracks.sorted(by: { $0.playCount > $1.playCount })

        let sortedArtists = artistPlayCounts.map {
            LibraryArtistStat(artist: $0.key, totalPlays: $0.value.totalPlays, trackCount: $0.value.tracks.count)
        }.sorted(by: { $0.totalPlays > $1.totalPlays })

        lock.lock()
        cachedTracks = sortedTracks
        cachedTopArtists = sortedArtists
        lastFetchTime = Date()
        lock.unlock()

        return Array(sortedTracks.prefix(limit))
    }

    /// Returns top artists ranked by real aggregate play count across your full library.
    public static func fetchTopArtists(limit: Int = 10) -> [LibraryArtistStat] {
        lock.lock()
        if !cachedTopArtists.isEmpty {
            let res = Array(cachedTopArtists.prefix(limit))
            lock.unlock()
            return res
        }
        lock.unlock()

        _ = fetchCrossDeviceMusicHistory(limit: 50)
        lock.lock()
        let res = Array(cachedTopArtists.prefix(limit))
        lock.unlock()
        return res
    }
}
