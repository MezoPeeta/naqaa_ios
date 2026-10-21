import Foundation
import SwiftData
import Testing
@testable import ensat

/// A listener favorites tracks from two reciters, plays the favorites, and goes offline.
/// Real: favorites and downloads in SwiftData, queue building, player state. Faked: audio and connectivity.
@MainActor
@Suite(.tags(.integration, .favorites, .offline))
final class FavoritesPlaybackJourneyTests {
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let downloads: DownloadsStore
    private let favorites: FavoritesStore
    private let player = StubAudioPlayer()
    private let state: PlayerState
    private let surahs = (1...10).map(TestFixtures.surah)
    private let alafasy = TestFixtures.alafasy
    private let other = TestFixtures.other

    private final class Connectivity {
        var offline = false
    }
    private let connectivity = Connectivity()

    init() throws {
        container = try ModelContainer(
            for: FavoriteTrack.self, FavoriteReciter.self, DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("favorites-journey")
        files = DownloadFileStore(directory: directory)
        downloads = DownloadsStore(context: container.mainContext, files: files)
        favorites = FavoritesStore(context: container.mainContext)
        state = PlayerState(player: player)
        state.surahs = surahs
        let connectivity = connectivity
        PlayerSession.wireOffline(state, files: files) { connectivity.offline }
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Inserts favorites with explicit dates so the list order is deterministic.
    private func favorite(_ pairs: [(surah: Int, item: ReciterMoshafItem)]) {
        for (offset, pair) in pairs.enumerated() {
            container.mainContext.insert(
                FavoriteTrack(surahId: pair.surah, item: pair.item, createdAt: Date(timeIntervalSince1970: Double(offset)))
            )
        }
        try? container.mainContext.save()
    }

    private func favoriteTracks() throws -> [FavoriteTrack] {
        try container.mainContext.fetch(FetchDescriptor<FavoriteTrack>(sortBy: [SortDescriptor(\.createdAt)]))
    }

    private func download(_ surahId: Int, _ item: ReciterMoshafItem) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: 8).write(to: temporary)
        try files.move(from: temporary, surahId: surahId, itemId: item.id)
        downloads.add(surahId: surahId, item: item, byteCount: 8)
    }

    @Test func theQueueKeepsEachFavoritesOwnReciterAndOrder() throws {
        favorite([(3, alafasy), (7, other), (5, alafasy)])

        let queue = try favoriteTracks().queueEntries(surahs: surahs)
        state.play(queue: queue)
        state.playNext()
        state.playNext()

        #expect(player.played.map(\.surahId) == [3, 7, 5])
        #expect(player.played.map(\.reciterId) == [alafasy.id, other.id, alafasy.id])
    }

    @Test func startingFromAMiddleFavoriteContinuesFromThere() throws {
        favorite([(3, alafasy), (7, other), (5, alafasy)])
        let tracks = try favoriteTracks()
        let queue = tracks.queueEntries(surahs: surahs)

        let index = try #require(queue.queueIndex(of: tracks[1]))
        state.play(queue: queue, startAt: index)
        state.playNext()

        #expect(index == 1)
        #expect(player.played.map(\.surahId) == [7, 5])
        #expect(state.canPlayNext == false)
        #expect(state.canPlayPrevious)
    }

    @Test func offlineOnlyDownloadedFavoritesArePlayedAndTheReciterMatters() throws {
        favorite([(3, alafasy), (5, alafasy), (7, other), (9, alafasy)])
        try download(3, alafasy)
        try download(7, other)
        try download(5, other)  // same surah as a favorite, but by a different reciter
        connectivity.offline = true

        state.play(queue: try favoriteTracks().queueEntries(surahs: surahs))
        state.playNext()

        #expect(state.selectedSurah?.id == 7, "5 by alafasy isn't saved; 5 by another reciter doesn't count")
        #expect(state.selectedReciter.id == other.id)

        state.playNext()
        #expect(state.selectedSurah?.id == 7, "9 by alafasy isn't saved: no further move")
    }

    @Test func unfavoritingRemovesTheTrackFromTheNextQueue() throws {
        favorite([(3, alafasy), (5, alafasy), (7, other)])

        favorites.toggleTrack(surahId: 5, item: alafasy)
        let queue = try favoriteTracks().queueEntries(surahs: surahs)

        #expect(queue.map(\.surah.id) == [3, 7])
        #expect(favorites.isFavorite(surahId: 5, item: alafasy) == false)
    }

    @Test(.tags(.edgeCase))
    func favoritesForSurahsMissingFromTheListAreSkipped() throws {
        favorite([(3, alafasy), (200, alafasy), (5, alafasy)])

        let queue = try favoriteTracks().queueEntries(surahs: surahs)

        #expect(queue.map(\.surah.id) == [3, 5])
    }

    @Test(.tags(.edgeCase))
    func theSameSurahByTwoReciterNamesIsTwoQueueEntries() throws {
        favorite([(5, alafasy), (5, other)])
        let tracks = try favoriteTracks()
        let queue = tracks.queueEntries(surahs: surahs)

        #expect(queue.count == 2)
        #expect(queue.queueIndex(of: tracks[0]) == 0)
        #expect(queue.queueIndex(of: tracks[1]) == 1)
    }
}
