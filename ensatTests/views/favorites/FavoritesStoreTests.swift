import Foundation
import SwiftData
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.favorites))
struct FavoritesStoreTests {
    private let container: ModelContainer
    private let store: FavoritesStore

    private let alafasy = TestFixtures.alafasy
    private let sameReciterOtherMoshaf = TestFixtures.item(moshafId: 3, moshafName: "Mujawwad")

    init() throws {
        container = try ModelContainer(
            for: FavoriteReciter.self, FavoriteTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        store = FavoritesStore(context: container.mainContext)
    }

    private func trackCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<FavoriteTrack>())
    }

    private func reciterCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<FavoriteReciter>())
    }

    // MARK: Basics

    @Test func toggleTrackAddsThenRemoves() {
        #expect(store.isFavorite(surahId: 18, item: alafasy) == false)
        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(store.isFavorite(surahId: 18, item: alafasy))
        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(store.isFavorite(surahId: 18, item: alafasy) == false)
    }

    @Test func trackFavoriteIsPerReciterAndSurah() {
        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(store.isFavorite(surahId: 18, item: TestFixtures.other) == false)
        #expect(store.isFavorite(surahId: 19, item: alafasy) == false)
    }

    @Test func toggleReciter() {
        store.toggleReciter(alafasy)
        #expect(store.isFavorite(reciter: alafasy))
        store.toggleReciter(alafasy)
        #expect(store.isFavorite(reciter: alafasy) == false)
    }

    @Test func favoriteTrackRebuildsPlayableItem() throws {
        store.toggleTrack(surahId: 18, item: alafasy)
        let track = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first)
        #expect(track.item.id == alafasy.id)
        #expect(track.item.moshaf.server == "https://example.com/a/")
    }

    // MARK: Independence

    @Test func trackAndReciterFavoritesAreIndependent() {
        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(store.isFavorite(reciter: alafasy) == false)

        store.toggleReciter(TestFixtures.other)
        #expect(store.isFavorite(surahId: 18, item: TestFixtures.other) == false)
    }

    @Test func favoritingAReciterLeavesTheirOtherMoshafAlone() {
        store.toggleReciter(alafasy)
        #expect(store.isFavorite(reciter: sameReciterOtherMoshaf) == false)
    }

    @Test func tracksOfTwoMoshafsOfOneReciterAreDistinct() throws {
        store.toggleTrack(surahId: 18, item: alafasy)
        store.toggleTrack(surahId: 18, item: sameReciterOtherMoshaf)
        #expect(try trackCount() == 2)

        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(store.isFavorite(surahId: 18, item: alafasy) == false)
        #expect(store.isFavorite(surahId: 18, item: sameReciterOtherMoshaf))
    }

    // MARK: Toggling

    @Test(.tags(.edgeCase))
    func togglingRepeatedlyNeverDuplicatesARow() throws {
        for _ in 0..<5 { store.toggleTrack(surahId: 18, item: alafasy) }
        #expect(try trackCount() == 1, "odd number of toggles leaves exactly one favorite")

        store.toggleTrack(surahId: 18, item: alafasy)
        #expect(try trackCount() == 0)
    }

    @Test(.tags(.edgeCase))
    func togglingARecitersFavoriteRepeatedlyNeverDuplicatesARow() throws {
        for _ in 0..<3 { store.toggleReciter(alafasy) }
        #expect(try reciterCount() == 1)
    }

    // MARK: refreshNames(from:)

    private func renamed(_ item: ReciterMoshafItem, reciter: String, moshaf: String) -> ReciterMoshafItem {
        TestFixtures.item(
            reciterId: item.reciter.id, moshafId: item.moshaf.id,
            reciterName: reciter, moshafName: moshaf, server: item.moshaf.server
        )
    }

    @Test func refreshRewritesNamesOnFavoriteRecitersAndTracks() throws {
        store.toggleReciter(alafasy)
        store.toggleTrack(surahId: 18, item: alafasy)

        store.refreshNames(from: [renamed(alafasy, reciter: "العفاسي", moshaf: "مرتل")])

        let reciter = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteReciter>()).first)
        let track = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first)
        #expect(reciter.reciterName == "العفاسي")
        #expect(reciter.moshafName == "مرتل")
        #expect(track.reciterName == "العفاسي")
        #expect(track.moshafName == "مرتل")
    }

    @Test(.tags(.edgeCase))
    func refreshLeavesFavoritesMissingFromTheCatalogUntouched() throws {
        store.toggleReciter(alafasy)
        store.toggleTrack(surahId: 18, item: alafasy)

        store.refreshNames(from: [renamed(TestFixtures.other, reciter: "X", moshaf: "Y")])
        store.refreshNames(from: [])

        let reciter = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteReciter>()).first)
        let track = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first)
        #expect(reciter.reciterName == "Alafasy")
        #expect(track.reciterName == "Alafasy")
    }

    @Test(.tags(.edgeCase))
    func refreshKeepsTheServerAndIdentityOfAFavorite() throws {
        store.toggleTrack(surahId: 18, item: alafasy)

        store.refreshNames(from: [renamed(alafasy, reciter: "New", moshaf: "New")])

        let track = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteTrack>()).first)
        #expect(track.item.id == alafasy.id)
        #expect(track.item.moshaf.server == alafasy.moshaf.server)
        #expect(store.isFavorite(surahId: 18, item: alafasy))
    }

    @Test(.tags(.edgeCase))
    func refreshWithDuplicateCatalogIdsUsesTheFirstOne() throws {
        store.toggleReciter(alafasy)

        store.refreshNames(from: [
            renamed(alafasy, reciter: "First", moshaf: "M"),
            renamed(alafasy, reciter: "Second", moshaf: "M")
        ])

        let reciter = try #require(container.mainContext.fetch(FetchDescriptor<FavoriteReciter>()).first)
        #expect(reciter.reciterName == "First")
    }

    @Test func refreshOnlyTouchesTheMatchingMoshaf() throws {
        store.toggleReciter(alafasy)
        store.toggleReciter(sameReciterOtherMoshaf)

        store.refreshNames(from: [renamed(alafasy, reciter: "Renamed", moshaf: "Renamed")])

        let all = try container.mainContext.fetch(FetchDescriptor<FavoriteReciter>())
        let names = Dictionary(uniqueKeysWithValues: all.map { ($0.key, $0.reciterName) })
        #expect(names[alafasy.id] == "Renamed")
        #expect(names[sameReciterOtherMoshaf.id] == "Alafasy")
    }
}
