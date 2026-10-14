import Foundation

/// What was playing and where, so the app reopens at the same spot (paused).
/// Holds ids and a streaming fallback only, never a local file path.
struct PlaybackSnapshot: Codable, Equatable {
    var surahId: Int
    var reciterId: Int
    var moshafId: Int
    var reciterName: String
    var moshafName: String
    var server: String
    var currentTime: Double
    var duration: Double

    init(surahId: Int, item: ReciterMoshafItem, currentTime: Double, duration: Double) {
        self.surahId = surahId
        self.reciterId = item.reciter.id
        self.moshafId = item.moshaf.id
        self.reciterName = item.reciter.name
        self.moshafName = item.moshaf.name
        self.server = item.moshaf.server
        self.currentTime = currentTime
        self.duration = duration
    }

    var item: ReciterMoshafItem {
        ReciterMoshafItem.make(
            reciterId: reciterId, reciterName: reciterName,
            moshafId: moshafId, moshafName: moshafName, server: server
        )
    }
}
