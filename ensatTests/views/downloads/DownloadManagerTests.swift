import Foundation
import SwiftData
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.offline))
final class DownloadManagerTests {
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let item = TestFixtures.alafasy

    /// Free space the manager sees, adjustable per test.
    private final class FreeSpace {
        var bytes: Int64 = 1_000_000
    }
    private let freeSpace = FreeSpace()

    init() throws {
        container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("download-manager")
        files = DownloadFileStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func makeManager() -> DownloadManager {
        let freeSpace = freeSpace
        return DownloadManager(
            container: container,
            files: files,
            makeSession: { delegate in
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [HangingURLProtocol.self]
                return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            },
            availableBytes: { freeSpace.bytes }
        )
    }

    private func key(_ surahId: Int = 18) -> String {
        FavoriteTrack.key(surahId: surahId, itemId: item.id)
    }

    private func placeFile(bytes: Int = 16) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: bytes).write(to: temporary)
        try files.move(from: temporary, surahId: 18, itemId: item.id)
    }

    // MARK: Starting

    @Test func startingADownloadMarksItInProgress() {
        let manager = makeManager()

        let result = manager.download(surah: TestFixtures.surah(18), item: item)

        #expect(result == .started)
        #expect(manager.state(surahId: 18, item: item) == .downloading(0))
    }

    @Test(.tags(.edgeCase))
    func startingTheSameDownloadTwiceIsRejected() {
        let manager = makeManager()
        _ = manager.download(surah: TestFixtures.surah(18), item: item)

        #expect(manager.download(surah: TestFixtures.surah(18), item: item) == .alreadyRunning)
    }

    @Test(.tags(.edgeCase))
    func aServerWithoutAUsableURLIsUnavailable() {
        let manager = makeManager()
        let broken = TestFixtures.item(server: "http://[bad host")

        #expect(manager.download(surah: TestFixtures.surah(18), item: broken) == .unavailable)
        #expect(manager.state(surahId: 18, item: broken) == nil)
    }

    @Test(.tags(.edgeCase), arguments: [
        (expected: Int64(1_000_001), result: DownloadManager.StartResult.insufficientSpace),
        (expected: Int64(1_000_000), result: DownloadManager.StartResult.started),
        (expected: Int64(1), result: DownloadManager.StartResult.started)
    ])
    func downloadsNeedEnoughFreeSpace(expected: Int64, result: DownloadManager.StartResult) {
        let manager = makeManager()

        #expect(manager.download(surah: TestFixtures.surah(18), item: item, expectedBytes: expected) == result)
        if result == .insufficientSpace {
            #expect(manager.state(surahId: 18, item: item) == nil, "no state is left behind when it can't start")
        }
    }

    @Test(.tags(.edgeCase))
    func anUnknownSizeStartsEvenWhenSpaceIsTight() {
        freeSpace.bytes = 0
        let manager = makeManager()

        #expect(manager.download(surah: TestFixtures.surah(18), item: item, expectedBytes: nil) == .started)
    }

    @Test func cancellingClearsTheDownloadAndAllowsARestart() {
        let manager = makeManager()
        _ = manager.download(surah: TestFixtures.surah(18), item: item)

        manager.cancel(surahId: 18, item: item)

        #expect(manager.state(surahId: 18, item: item) == nil)
        #expect(manager.download(surah: TestFixtures.surah(18), item: item) == .started)
    }

    // MARK: Events

    @Test func progressEventsUpdateTheState() async {
        let manager = makeManager()

        await manager.handle(.progress(key: key(), fraction: 0.4))

        #expect(manager.state(surahId: 18, item: item) == .downloading(0.4))
    }

    @Test(.tags(.edgeCase))
    func tinyProgressStepsAreNotPublished() async {
        let manager = makeManager()
        await manager.handle(.progress(key: key(), fraction: 0.40))

        await manager.handle(.progress(key: key(), fraction: 0.405))

        #expect(manager.state(surahId: 18, item: item) == .downloading(0.40))
    }

    @Test(.tags(.edgeCase))
    func completionAlwaysGetsThroughTheThrottle() async {
        let manager = makeManager()
        await manager.handle(.progress(key: key(), fraction: 0.995))

        await manager.handle(.progress(key: key(), fraction: 1))

        #expect(manager.state(surahId: 18, item: item) == .downloading(1))
    }

    @Test func aFailureIsRecordedAndCanBeRetried() async {
        let manager = makeManager()
        _ = manager.download(surah: TestFixtures.surah(18), item: item)

        await manager.handle(.failed(key: key()))

        #expect(manager.state(surahId: 18, item: item) == .failed)
        #expect(manager.download(surah: TestFixtures.surah(18), item: item) == .started)
    }

    @Test(.tags(.edgeCase))
    func lateProgressDoesNotReviveAFailedDownload() async {
        let manager = makeManager()
        await manager.handle(.failed(key: key()))

        await manager.handle(.progress(key: key(), fraction: 0.5))

        #expect(manager.state(surahId: 18, item: item) == .failed)
    }

    @Test func aCancelledEventClearsTheState() async {
        let manager = makeManager()
        await manager.handle(.progress(key: key(), fraction: 0.4))

        await manager.handle(.cancelled(key: key()))

        #expect(manager.state(surahId: 18, item: item) == nil)
    }

    @Test(.tags(.edgeCase))
    func aFinishedFileThatCannotBePlayedIsDeletedAndMarkedFailed() async throws {
        let manager = makeManager()
        await manager.waitForStartup()
        try placeFile()
        let info = DownloadRequestInfo(surahId: 18, item: item)

        await manager.handle(.finished(info, byteCount: 16))

        #expect(files.exists(surahId: 18, itemId: item.id) == false)
        #expect(manager.state(surahId: 18, item: item) == .failed)
        let rows = try container.mainContext.fetchCount(FetchDescriptor<DownloadedTrack>())
        #expect(rows == 0, "a broken file must never be indexed as downloaded")
    }

    @Test(.tags(.edgeCase))
    func aFinishedEventForAFileRemovedMeanwhileLeavesNothingBehind() async throws {
        let manager = makeManager()
        await manager.waitForStartup()
        await manager.handle(.progress(key: key(), fraction: 0.9))
        let info = DownloadRequestInfo(surahId: 18, item: item)

        await manager.handle(.finished(info, byteCount: 16))

        #expect(manager.state(surahId: 18, item: item) == nil)
        let rows = try container.mainContext.fetchCount(FetchDescriptor<DownloadedTrack>())
        #expect(rows == 0)
    }

    @Test func removingADownloadDropsItsFileAndRow() throws {
        let manager = makeManager()
        try placeFile()
        let store = DownloadsStore(context: container.mainContext, files: files)
        store.add(surahId: 18, item: item, byteCount: 16)

        manager.remove(surahId: 18, item: item)

        #expect(store.isDownloaded(surahId: 18, item: item) == false)
        #expect(files.exists(surahId: 18, itemId: item.id) == false)
    }
}
