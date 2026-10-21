import Foundation
import SwiftData
import Testing
@testable import ensat

/// The reciter catalog is reloaded with new names while a reciter is playing and favorited.
/// Real: catalog cache on disk, view model, favorites in SwiftData, player state. Faked: the network and the audio player.
@MainActor
@Suite(.tags(.integration, .reciters, .favorites, .offline))
final class LanguageChangeJourneyTests {
    private let path = "/reciters-\(UUID().uuidString)"
    private let directory: URL
    private let container: ModelContainer
    private let favorites: FavoritesStore
    private let player = StubAudioPlayer()
    private let state: PlayerState

    init() throws {
        directory = try TestFixtures.temporaryDirectory("language-journey")
        container = try ModelContainer(
            for: FavoriteTrack.self, FavoriteReciter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        favorites = FavoritesStore(context: container.mainContext)
        state = PlayerState(player: player)
        state.surahs = (1...5).map(TestFixtures.surah)
    }

    deinit {
        RoutedURLProtocol.unregister(path: path)
        try? FileManager.default.removeItem(at: directory)
    }

    /// A one-reciter catalog whose item has the same id as `TestFixtures.alafasy` ("1-2").
    private func catalog(reciter: String, moshaf: String) -> Data {
        Data("""
        {"reciters": [{"id": 1, "name": "\(reciter)", "letter": "A",
          "moshaf": [{"id": 2, "name": "\(moshaf)", "server": "https://example.com/a/"}]}]}
        """.utf8)
    }

    private func viewModel(cacheClock: @escaping @Sendable () -> Date = { Date() }) -> ReciterViewModel {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RoutedURLProtocol.self]
        return ReciterViewModel(
            session: URLSession(configuration: configuration),
            endpoint: URL(string: "https://example.com\(path)")!,
            cache: ReciterCatalogCache(directory: directory, now: cacheClock)
        )
    }

    private func loadedItems(_ viewModel: ReciterViewModel) -> [ReciterMoshafItem] {
        guard case .loaded(let items) = viewModel.state else { return [] }
        return items
    }

    private func favoriteNames() throws -> (reciter: String?, track: String?) {
        let reciter = try container.mainContext.fetch(FetchDescriptor<FavoriteReciter>()).first?.reciterName
        let track = try container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first?.reciterName
        return (reciter, track)
    }

    @Test func aRefreshedCatalogRenamesTheSelectedReciterAndFavoritesWithoutInterruptingPlayback() async throws {
        RoutedURLProtocol.respond(path: path, data: catalog(reciter: "Alafasy", moshaf: "Murattal"))
        await viewModel().load()
        let english = TestFixtures.alafasy
        favorites.toggleReciter(english)
        favorites.toggleTrack(surahId: 2, item: english)
        state.play(TestFixtures.surah(2))
        state.selectReciter(english)
        let callsBefore = player.played.count

        // A week later the cached catalog is stale and the server now answers with Arabic names.
        RoutedURLProtocol.respond(path: path, data: catalog(reciter: "العفاسي", moshaf: "مرتل"))
        let later = viewModel(cacheClock: { Date().addingTimeInterval(8 * 24 * 60 * 60) })
        await later.load()
        let items = loadedItems(later)
        favorites.refreshNames(from: items)
        state.refreshSelectedReciter(from: items)

        let names = try favoriteNames()
        #expect(names.reciter == "العفاسي")
        #expect(names.track == "العفاسي")
        #expect(state.selectedReciter.reciter.name == "العفاسي")
        #expect(state.selectedReciter.id == english.id)
        #expect(player.played.count == callsBefore, "renaming must not restart the track")
        #expect(favorites.isFavorite(surahId: 2, item: english), "favorites keep their identity")
    }

    @Test(.tags(.edgeCase))
    func offlineWithAStaleCacheKeepsEveryNameUnchanged() async throws {
        RoutedURLProtocol.respond(path: path, data: catalog(reciter: "Alafasy", moshaf: "Murattal"))
        let first = viewModel()
        await first.load()
        favorites.toggleReciter(TestFixtures.alafasy)
        state.restore(surah: TestFixtures.surah(2), reciter: TestFixtures.alafasy, time: 10, duration: 100)

        RoutedURLProtocol.fail(path: path)
        let offline = viewModel(cacheClock: { Date().addingTimeInterval(30 * 24 * 60 * 60) })
        await offline.load()
        let items = loadedItems(offline)
        favorites.refreshNames(from: items)
        state.refreshSelectedReciter(from: items)

        #expect(items.map(\.id) == ["1-2"], "the stale catalog is still served offline")
        #expect(try favoriteNames().reciter == "Alafasy")
        #expect(state.selectedReciter.reciter.name == "Alafasy")
    }

    @Test(.tags(.edgeCase))
    func aReciterMissingFromTheNewCatalogKeepsItsSavedNames() async throws {
        favorites.toggleReciter(TestFixtures.other)
        state.restore(surah: TestFixtures.surah(2), reciter: TestFixtures.other, time: 0, duration: 0)
        RoutedURLProtocol.respond(path: path, data: catalog(reciter: "العفاسي", moshaf: "مرتل"))
        let vm = viewModel()
        await vm.load()

        favorites.refreshNames(from: loadedItems(vm))
        state.refreshSelectedReciter(from: loadedItems(vm))

        #expect(try favoriteNames().reciter == "Other")
        #expect(state.selectedReciter.reciter.name == "Other")
    }
}
