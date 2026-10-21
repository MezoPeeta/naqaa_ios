import Foundation
import SwiftData
import Testing
@testable import ensat

/// A saved file turns out to be unplayable. Real: `AudioPlayerManager` with `AVPlayer`, files on disk,
/// the download manager listening for removals, and the global notification center.
@MainActor
@Suite(.tags(.integration, .offline, .slow))
final class BrokenDownloadFallbackTests {
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let store: DownloadsStore
    private let manager: DownloadManager
    /// Nothing listens on port 1, so streaming fails right away, like having no connection.
    private let item = TestFixtures.item(server: "http://127.0.0.1:1/")
    private let surah = TestFixtures.surah(18)

    init() throws {
        container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("broken-download")
        files = DownloadFileStore(directory: directory)
        store = DownloadsStore(context: container.mainContext, files: files)
        manager = DownloadManager(
            container: container,
            files: files,
            makeSession: { delegate in
                let configuration = URLSessionConfiguration.ephemeral
                configuration.protocolClasses = [HangingURLProtocol.self]
                return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
            },
            availableBytes: { .max }
        )
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func wait(seconds: Double = 20, _ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(seconds)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(50))
        }
        return condition()
    }

    @Test(.timeLimit(.minutes(1)))
    func anUnplayableDownloadIsRemovedEverywhereAndTheFailureIsReported() async throws {
        await manager.waitForStartup()
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try TestAudio.garbage().write(to: temporary)
        try files.move(from: temporary, surahId: surah.id, itemId: item.id)
        store.add(surahId: surah.id, item: item, byteCount: 2_048)
        let player = AudioPlayerManager(downloads: files)

        player.play(surah: surah, reciter: item)

        #expect(await wait { files.exists(surahId: surah.id, itemId: item.id) == false },
                "the broken file is deleted once AVPlayer rejects it")
        #expect(await wait { store.isDownloaded(surahId: surah.id, item: item) == false },
                "the downloads index hears about it through the notification")
        #expect(await wait { player.didFailToPlay },
                "with no connection to stream from, the failure is surfaced for the alert")
        #expect(player.isPlayingLocal == false)
    }

    @Test(.timeLimit(.minutes(1)), .tags(.edgeCase))
    func dismissingTheFailureClearsIt() async throws {
        let player = AudioPlayerManager(downloads: files)
        player.play(surah: surah, reciter: item)
        #expect(await wait { player.didFailToPlay })

        player.clearPlaybackFailure()

        #expect(player.didFailToPlay == false)
    }
}
