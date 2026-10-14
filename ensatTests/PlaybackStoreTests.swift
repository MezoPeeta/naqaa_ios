import XCTest
@testable import ensat

final class PlaybackStoreTests: XCTestCase {

    private var defaults: UserDefaults!
    private var store: PlaybackStore!
    private let suite = "PlaybackStoreTests"

    private let item = ReciterMoshafItem.make(
        reciterId: 1, reciterName: "Alafasy", moshafId: 2, moshafName: "Murattal", server: "https://example.com/a/"
    )

    override func setUp() {
        defaults = UserDefaults(suiteName: suite)
        defaults.removePersistentDomain(forName: suite)
        store = PlaybackStore(defaults: defaults)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suite)
    }

    func testLoadWithoutSaveIsNil() {
        XCTAssertNil(store.load())
    }

    func testSaveThenLoadRoundTrips() {
        let snapshot = PlaybackSnapshot(surahId: 18, item: item, currentTime: 42, duration: 300)
        store.save(snapshot)
        XCTAssertEqual(store.load(), snapshot)
    }

    func testSaveOverwritesPreviousSnapshot() {
        store.save(PlaybackSnapshot(surahId: 2, item: item, currentTime: 10, duration: 100))
        store.save(PlaybackSnapshot(surahId: 3, item: item, currentTime: 42, duration: 200))
        XCTAssertEqual(store.load()?.surahId, 3)
        XCTAssertEqual(store.load()?.currentTime, 42)
    }

    func testSnapshotRebuildsPlayableItem() throws {
        store.save(PlaybackSnapshot(surahId: 18, item: item, currentTime: 1, duration: 2))
        let rebuilt = try XCTUnwrap(store.load()).item
        XCTAssertEqual(rebuilt.id, item.id)
        XCTAssertEqual(rebuilt.moshaf.server, "https://example.com/a/")
    }
}
