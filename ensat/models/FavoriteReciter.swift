import Foundation
import SwiftData

/// A reciter/moshaf the user favorited. Stores a small snapshot so it renders and plays
/// before (or without) the reciters API response.
@Model
final class FavoriteReciter {
    @Attribute(.unique) var key: String
    var reciterId: Int
    var moshafId: Int
    var reciterName: String
    var moshafName: String
    var server: String
    var createdAt: Date

    init(item: ReciterMoshafItem, createdAt: Date = .now) {
        self.key = item.id
        self.reciterId = item.reciter.id
        self.moshafId = item.moshaf.id
        self.reciterName = item.reciter.name
        self.moshafName = item.moshaf.name
        self.server = item.moshaf.server
        self.createdAt = createdAt
    }

    var item: ReciterMoshafItem {
        ReciterMoshafItem.make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }
}
