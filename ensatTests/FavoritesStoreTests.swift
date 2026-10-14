import SwiftData
import XCTest
@testable import ensat

@MainActor
final class FavoritesStoreTests: XCTestCase {

    private var container: ModelContainer!
    private var store: FavoritesStore!

    private let item = ReciterMoshafItem.make(
        reciterId: 1, reciterName: "Alafasy", moshafId: 2, moshafName: "Murattal", server: "https://example.com/a/"
    )

    override func setUpWithError() throws {
        container = try ModelContainer(
            for: FavoriteReciter.self, FavoriteTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = FavoritesStore(context: container.mainContext)
    }

    func testToggleTrackAddsThenRemoves() {
        XCTAssertFalse(store.isFavorite(surahId: 18, item: item))
        store.toggleTrack(surahId: 18, item: item)
        XCTAssertTrue(store.isFavorite(surahId: 18, item: item))
        store.toggleTrack(surahId: 18, item: item)
        XCTAssertFalse(store.isFavorite(surahId: 18, item: item))
    }

    func testTrackFavoriteIsPerReciterAndSurah() {
        store.toggleTrack(surahId: 18, item: item)
        let other = ReciterMoshafItem.make(
            reciterId: 9, reciterName: "Other", moshafId: 1, moshafName: "M", server: "https://example.com/b/"
        )
        XCTAssertFalse(store.isFavorite(surahId: 18, item: other))
        XCTAssertFalse(store.isFavorite(surahId: 19, item: item))
    }

    func testToggleReciter() {
        store.toggleReciter(item)
        XCTAssertTrue(store.isFavorite(reciter: item))
        store.toggleReciter(item)
        XCTAssertFalse(store.isFavorite(reciter: item))
    }

    func testFavoriteTrackRebuildsPlayableItem() throws {
        store.toggleTrack(surahId: 18, item: item)
        let track = try XCTUnwrap(container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first)
        XCTAssertEqual(track.item.id, item.id)
        XCTAssertEqual(track.item.moshaf.server, "https://example.com/a/")
    }
}
