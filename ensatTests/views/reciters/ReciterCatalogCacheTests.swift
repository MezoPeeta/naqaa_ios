import Foundation
import Testing
@testable import ensat

@Suite(.tags(.reciters, .offline))
final class ReciterCatalogCacheTests {
    private let directory: URL
    private let reference = Date(timeIntervalSince1970: 2_000_000_000)
    private let day: TimeInterval = 24 * 60 * 60

    init() throws {
        directory = try TestFixtures.temporaryDirectory("catalog-cache")
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    /// A cache whose clock reads `reference`, after having written `data` `age` seconds earlier.
    private func cache(writing data: Data? = nil, age: TimeInterval = 0, language: String = "en") -> ReciterCatalogCache {
        if let data {
            ReciterCatalogCache(directory: directory, now: { [reference] in reference - age })
                .write(data, languageCode: language)
        }
        return ReciterCatalogCache(directory: directory, now: { [reference] in reference })
    }

    @Test func missingEntryReadsAsNil() {
        #expect(cache().read(languageCode: "en") == nil)
    }

    @Test func writtenDataReadsBackFresh() throws {
        let entry = try #require(cache(writing: Data("catalog".utf8)).read(languageCode: "en"))

        #expect(entry.data == Data("catalog".utf8))
        #expect(entry.isFresh)
    }

    @Test(.tags(.edgeCase), arguments: [
        (days: 6.9, fresh: true),
        (days: 7.0, fresh: false),
        (days: 8.0, fresh: false)
    ])
    func entriesGoStaleAtTheMaxAge(days: Double, fresh: Bool) throws {
        let entry = try #require(cache(writing: Data("x".utf8), age: days * day).read(languageCode: "en"))
        #expect(entry.isFresh == fresh)
    }

    @Test func staleEntriesAreStillReturnedForOfflineUse() throws {
        let entry = try #require(cache(writing: Data("old".utf8), age: 30 * day).read(languageCode: "en"))
        #expect(entry.data == Data("old".utf8))
    }

    @Test func eachLanguageHasItsOwnEntry() throws {
        _ = cache(writing: Data("english".utf8), language: "en")
        let store = cache(writing: Data("arabic".utf8), language: "ar")

        #expect(try #require(store.read(languageCode: "en")).data == Data("english".utf8))
        #expect(try #require(store.read(languageCode: "ar")).data == Data("arabic".utf8))
        #expect(store.read(languageCode: "fr") == nil)
    }

    @Test func writingAgainReplacesTheEntryAndRefreshesIt() throws {
        _ = cache(writing: Data("old".utf8), age: 30 * day)
        let store = cache(writing: Data("new".utf8))

        let entry = try #require(store.read(languageCode: "en"))
        #expect(entry.data == Data("new".utf8))
        #expect(entry.isFresh)
    }

    @Test func removeDeletesOnlyThatLanguage() {
        _ = cache(writing: Data("a".utf8), language: "en")
        let store = cache(writing: Data("b".utf8), language: "ar")

        store.remove(languageCode: "en")

        #expect(store.read(languageCode: "en") == nil)
        #expect(store.read(languageCode: "ar") != nil)
    }

}
