import Foundation
import SwiftData
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.offline))
final class DownloadsStoreTests {
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let store: DownloadsStore
    private let item = TestFixtures.alafasy

    init() throws {
        container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("downloads-store")
        files = DownloadFileStore(directory: directory)
        store = DownloadsStore(context: container.mainContext, files: files)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func writeFile(surahId: Int, itemId: String? = nil) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: 8).write(to: temporary)
        try files.move(from: temporary, surahId: surahId, itemId: itemId ?? item.id)
    }

    private func rowCount() throws -> Int {
        try container.mainContext.fetchCount(FetchDescriptor<DownloadedTrack>())
    }

    // MARK: Index rows

    @Test func addingTheSameSurahTwiceUpdatesTheRowInsteadOfDuplicatingIt() throws {
        store.add(surahId: 18, item: item, byteCount: 10)
        store.add(surahId: 18, item: item, byteCount: 25)

        #expect(try rowCount() == 1)
        #expect(store.totalBytes() == 25)
    }

    @Test func totalBytesSumsEveryDownload() {
        store.add(surahId: 1, item: item, byteCount: 10)
        store.add(surahId: 2, item: item, byteCount: 20)
        store.add(surahId: 1, item: TestFixtures.other, byteCount: 5)

        #expect(store.totalBytes() == 35)
    }

    @Test(.tags(.edgeCase))
    func downloadsAreTrackedPerReciter() {
        store.add(surahId: 18, item: item, byteCount: 10)

        #expect(store.isDownloaded(surahId: 18, item: item))
        #expect(store.isDownloaded(surahId: 18, item: TestFixtures.other) == false)
        #expect(store.isDownloaded(surahId: 19, item: item) == false)
    }

    @Test(.tags(.edgeCase))
    func removingSomethingNeverDownloadedIsHarmless() throws {
        store.remove(surahId: 18, item: item)
        store.removeIndex(surahId: 18, itemId: item.id)
        store.removeAll()

        #expect(try rowCount() == 0)
        #expect(store.totalBytes() == 0)
    }

    @Test func removeIndexKeepsTheFileOnDisk() throws {
        try writeFile(surahId: 18)
        store.add(surahId: 18, item: item, byteCount: 8)

        store.removeIndex(surahId: 18, itemId: item.id)

        #expect(store.isDownloaded(surahId: 18, item: item) == false)
        #expect(files.exists(surahId: 18, itemId: item.id))
    }

    @Test func removeDeletesTheFileAndTheRowButNotOtherSurahs() throws {
        try writeFile(surahId: 18)
        try writeFile(surahId: 19)
        store.add(surahId: 18, item: item, byteCount: 8)
        store.add(surahId: 19, item: item, byteCount: 8)

        store.remove(surahId: 18, item: item)

        #expect(files.exists(surahId: 18, itemId: item.id) == false)
        #expect(files.exists(surahId: 19, itemId: item.id))
        #expect(store.isDownloaded(surahId: 19, item: item))
    }

    // MARK: reconcile

    private func reconcileFromDisk() async {
        store.reconcile(onDisk: await files.allKeys(), inFlight: [])
    }

    @Test func reconcileDropsRowsWithoutFiles() async {
        store.add(surahId: 18, item: item, byteCount: 10)
        await reconcileFromDisk()
        #expect(store.isDownloaded(surahId: 18, item: item) == false)
    }

    @Test func reconcileDeletesOrphanFiles() async throws {
        try writeFile(surahId: 18)
        await reconcileFromDisk()
        #expect(files.exists(surahId: 18, itemId: item.id) == false)
    }

    @Test func reconcileKeepsMatchingRowAndFile() async throws {
        try writeFile(surahId: 18)
        store.add(surahId: 18, item: item, byteCount: 10)
        await reconcileFromDisk()
        #expect(store.isDownloaded(surahId: 18, item: item))
        #expect(files.exists(surahId: 18, itemId: item.id))
    }

    @Test(.tags(.edgeCase))
    func reconcileKeepsAnInFlightRowWhoseFileIsNotThereYet() {
        store.add(surahId: 18, item: item, byteCount: 8)
        let key = FavoriteTrack.key(surahId: 18, itemId: item.id)

        store.reconcile(onDisk: [], inFlight: [key])

        #expect(store.isDownloaded(surahId: 18, item: item))
    }

    @Test(.tags(.edgeCase))
    func reconcileKeepsAnInFlightFileWhoseRowIsNotWrittenYet() throws {
        try writeFile(surahId: 18)
        let key = FavoriteTrack.key(surahId: 18, itemId: item.id)

        store.reconcile(onDisk: [key], inFlight: [key])

        #expect(files.exists(surahId: 18, itemId: item.id))
    }

    @Test(.tags(.edgeCase))
    func reconcileIgnoresMalformedFileKeys() throws {
        try writeFile(surahId: 18)

        store.reconcile(onDisk: ["garbage", "abc-1-2", "-", ""], inFlight: [])

        #expect(files.exists(surahId: 18, itemId: item.id), "only well-formed orphans are deleted")
    }

    @Test(.tags(.edgeCase))
    func reconcileDeletesOrphansWhoseItemIdContainsADash() throws {
        let itemId = "12-34"
        try writeFile(surahId: 7, itemId: itemId)

        store.reconcile(onDisk: ["7-\(itemId)"], inFlight: [])

        #expect(files.exists(surahId: 7, itemId: itemId) == false)
    }

    @Test func removeAllOnlyClearsDownloads() async throws {
        try writeFile(surahId: 18)
        try writeFile(surahId: 19)
        store.add(surahId: 18, item: item, byteCount: 8)
        store.add(surahId: 19, item: item, byteCount: 8)

        store.removeAll()

        #expect(try rowCount() == 0)
        #expect(await files.allKeys().isEmpty)
    }
}
