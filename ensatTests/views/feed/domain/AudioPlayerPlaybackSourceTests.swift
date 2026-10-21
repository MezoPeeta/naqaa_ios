import Foundation
import SwiftData
import Testing
@testable import ensat

@MainActor
@Suite(.tags(.offline, .playback))
final class AudioPlayerPlaybackSourceTests {
    private let directory: URL
    private let downloads: DownloadFileStore
    private let surah = TestFixtures.surah(18)
    private let reciter = TestFixtures.alafasy

    init() throws {
        directory = try TestFixtures.temporaryDirectory("playback-source")
        downloads = DownloadFileStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func download(surahId: Int = 18, itemId: String? = nil) throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: 4).write(to: temporary)
        try downloads.move(from: temporary, surahId: surahId, itemId: itemId ?? reciter.id)
    }

    private func source(surah: Surah? = nil, reciter: ReciterMoshafItem? = nil, preferLocal: Bool = true) -> (url: URL, isLocal: Bool)? {
        AudioPlayerManager.playbackURL(
            surah: surah ?? self.surah, reciter: reciter ?? self.reciter,
            preferLocal: preferLocal, downloads: downloads
        )
    }

    @Test func streamsWhenNothingIsDownloaded() {
        let playback = source()
        #expect(playback?.isLocal == false)
        #expect(playback?.url.absoluteString == "https://example.com/a/018.mp3")
    }

    @Test func aDownloadedFileWinsOverStreaming() throws {
        try download()

        let playback = source()

        #expect(playback?.isLocal == true)
        #expect(playback?.url == downloads.fileURL(surahId: 18, itemId: reciter.id))
    }

    @Test(.tags(.edgeCase))
    func fallbackToStreamIgnoresTheDownloadedFile() throws {
        try download()

        let playback = source(preferLocal: false)

        #expect(playback?.isLocal == false)
    }

    @Test(.tags(.edgeCase))
    func aDownloadForAnotherReciterOrSurahDoesNotCount() throws {
        try download(surahId: 19)
        try download(surahId: 18, itemId: TestFixtures.other.id)

        #expect(source()?.isLocal == false)
    }

    @Test(.tags(.edgeCase))
    func noUsableURLMeansNothingToPlay() {
        let broken = TestFixtures.item(server: "http://[bad host")
        #expect(source(reciter: broken) == nil)
    }

    @Test(.tags(.edgeCase))
    func aDownloadStillPlaysWhenTheStreamURLIsUnusable() throws {
        let broken = TestFixtures.item(server: "http://[bad host")
        try download(itemId: broken.id)

        #expect(source(reciter: broken)?.isLocal == true)
    }

    // MARK: Broken downloads

    @Test func discardingABrokenDownloadDeletesItAndAnnouncesIt() throws {
        try download()
        let center = NotificationCenter()
        var userInfo: [AnyHashable: Any]?
        let token = center.addObserver(forName: .downloadedFileRemoved, object: nil, queue: nil) {
            userInfo = $0.userInfo
        }
        defer { center.removeObserver(token) }

        AudioPlayerManager.discardBrokenDownload(
            surahId: 18, itemId: reciter.id, downloads: downloads, center: center
        )

        #expect(downloads.exists(surahId: 18, itemId: reciter.id) == false)
        #expect(userInfo?["surahId"] as? Int == 18)
        #expect(userInfo?["itemId"] as? String == reciter.id)
    }

    @Test(.tags(.edgeCase))
    func theRemovalNotificationLetsTheDownloadsIndexDropTheRow() async throws {
        let container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        let store = DownloadsStore(context: container.mainContext, files: downloads)
        store.add(surahId: 18, item: reciter, byteCount: 4)
        try download()

        let center = NotificationCenter()
        let task = Task {
            for await note in center.notifications(named: .downloadedFileRemoved) {
                if let surahId = note.userInfo?["surahId"] as? Int, let itemId = note.userInfo?["itemId"] as? String {
                    store.removeIndex(surahId: surahId, itemId: itemId)
                }
                return
            }
        }
        try await Task.sleep(for: .milliseconds(50))

        AudioPlayerManager.discardBrokenDownload(surahId: 18, itemId: reciter.id, downloads: downloads, center: center)
        await task.value

        #expect(store.isDownloaded(surahId: 18, item: reciter) == false)
    }
}
