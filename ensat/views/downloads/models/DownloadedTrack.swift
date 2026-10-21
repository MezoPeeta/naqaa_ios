import Foundation
import SwiftData

/// Index row for a surah audio file saved on disk. The file path is derived from the ids.
@Model
final class DownloadedTrack {
    @Attribute(.unique) var key: String
    var surahId: Int
    var reciterId: Int
    var moshafId: Int
    var reciterName: String
    var moshafName: String
    var server: String
    var byteCount: Int64
    var createdAt: Date

    init(surahId: Int, item: ReciterMoshafItem, byteCount: Int64, createdAt: Date = .now) {
        self.key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        self.surahId = surahId
        self.reciterId = item.reciter.id
        self.moshafId = item.moshaf.id
        self.reciterName = item.reciter.name
        self.moshafName = item.moshaf.name
        self.server = item.moshaf.server
        self.byteCount = byteCount
        self.createdAt = createdAt
    }

    var item: ReciterMoshafItem {
        ReciterMoshafItem.make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }
}
