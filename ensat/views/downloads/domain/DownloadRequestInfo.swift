import Foundation

/// Stored in `URLSessionTask.taskDescription` so a download that finishes after a relaunch
/// can still be indexed without the in-memory catalog.
nonisolated struct DownloadRequestInfo: Codable, Sendable {
    let surahId: Int
    let reciterId: Int
    let reciterName: String
    let moshafId: Int
    let moshafName: String
    let server: String

    init(surahId: Int, item: ReciterMoshafItem) {
        self.surahId = surahId
        self.reciterId = item.reciter.id
        self.reciterName = item.reciter.name
        self.moshafId = item.moshaf.id
        self.moshafName = item.moshaf.name
        self.server = item.moshaf.server
    }

    var item: ReciterMoshafItem {
        ReciterMoshafItem.make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }

    var key: String { FavoriteTrack.key(surahId: surahId, itemId: item.id) }

    var taskDescription: String? {
        (try? JSONEncoder().encode(self)).flatMap { String(data: $0, encoding: .utf8) }
    }

    init?(taskDescription: String?) {
        guard let data = taskDescription?.data(using: .utf8),
              let info = try? JSONDecoder().decode(Self.self, from: data)
        else { return nil }
        self = info
    }
}
