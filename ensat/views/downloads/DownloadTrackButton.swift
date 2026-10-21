import SwiftData
import SwiftUI

/// Download control for the track in the full player; owns the query for its single surah.
struct DownloadTrackButton: View {
    @Query private var downloads: [DownloadedTrack]

    let surah: Surah
    let item: ReciterMoshafItem

    init(surah: Surah, item: ReciterMoshafItem) {
        self.surah = surah
        self.item = item
        let key = FavoriteTrack.key(surahId: surah.id, itemId: item.id)
        _downloads = Query(filter: #Predicate<DownloadedTrack> { $0.key == key })
    }

    var body: some View {
        DownloadControl(surah: surah, item: item, isDownloaded: !downloads.isEmpty)
    }
}
