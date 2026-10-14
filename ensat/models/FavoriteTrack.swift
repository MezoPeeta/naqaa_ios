import Foundation
import SwiftData

/// A surah by a specific reciter/moshaf. Surah data is bundled, so only its id is stored.
@Model
final class FavoriteTrack {
    @Attribute(.unique) var key: String
    var surahId: Int
    var reciterId: Int
    var moshafId: Int
    var reciterName: String
    var moshafName: String
    var server: String
    var createdAt: Date

    init(surahId: Int, item: ReciterMoshafItem, createdAt: Date = .now) {
        self.key = Self.key(surahId: surahId, itemId: item.id)
        self.surahId = surahId
        self.reciterId = item.reciter.id
        self.moshafId = item.moshaf.id
        self.reciterName = item.reciter.name
        self.moshafName = item.moshaf.name
        self.server = item.moshaf.server
        self.createdAt = createdAt
    }

    static func key(surahId: Int, itemId: String) -> String { "\(surahId)-\(itemId)" }

    var item: ReciterMoshafItem {
        ReciterMoshafItem.make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }
}
