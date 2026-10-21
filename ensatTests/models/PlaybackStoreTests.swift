import Foundation
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.playback))
final class PlaybackStoreTests {
    private let suiteName = "PlaybackStoreTests-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let store: PlaybackStore
    private let item = TestFixtures.alafasy

    init() throws {
        defaults = try #require(UserDefaults(suiteName: suiteName))
        store = PlaybackStore(defaults: defaults)
    }

    deinit {
        defaults.removePersistentDomain(forName: suiteName)
    }

    @Test func loadWithoutSaveIsNil() {
        #expect(store.load() == nil)
    }

    @Test func saveThenLoadRoundTrips() {
        let snapshot = PlaybackSnapshot(surahId: 18, item: item, currentTime: 42, duration: 300)
        store.save(snapshot)
        #expect(store.load() == snapshot)
    }

    @Test func saveOverwritesPreviousSnapshot() {
        store.save(PlaybackSnapshot(surahId: 2, item: item, currentTime: 10, duration: 100))
        store.save(PlaybackSnapshot(surahId: 3, item: item, currentTime: 42, duration: 200))
        #expect(store.load()?.surahId == 3)
        #expect(store.load()?.currentTime == 42)
    }

    @Test func snapshotKeepsTheReciterNamesAndServerForOfflineRestore() {
        store.save(PlaybackSnapshot(surahId: 18, item: TestFixtures.other, currentTime: 1, duration: 2))

        let restored = store.load()?.item

        #expect(restored?.reciter.name == "Other")
        #expect(restored?.moshaf.server == "https://example.com/b/")
        #expect(restored?.id == TestFixtures.other.id)
    }

    @Test(.tags(.edgeCase))
    func undecodableDataLoadsAsNothing() {
        defaults.set(Data("garbage".utf8), forKey: "playback.snapshot")
        #expect(store.load() == nil)
    }

    @Test(.tags(.edgeCase))
    func aSnapshotWithAnUnknownDurationRoundTrips() {
        let snapshot = PlaybackSnapshot(surahId: 18, item: item, currentTime: 12.5, duration: 0)
        store.save(snapshot)
        #expect(store.load() == snapshot)
    }
}
