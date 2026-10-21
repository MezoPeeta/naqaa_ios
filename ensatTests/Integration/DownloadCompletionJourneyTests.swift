import AVFoundation
import Foundation
import SwiftData
import Testing
@testable import ensat

/// A download finishes, becomes playable offline, and is later removed.
/// Real: download manager event handling, file store, SwiftData index, AVFoundation's playability check, player state.
@MainActor
@Suite(.tags(.integration, .offline, .slow))
final class DownloadCompletionJourneyTests {
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let manager: DownloadManager
    private let store: DownloadsStore
    private let player = StubAudioPlayer()
    private let state: PlayerState
    private let connectivity = Connectivity()
    private let item = TestFixtures.alafasy

    private final class Connectivity {
        var offline = false
    }

    init() throws {
        container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("download-journey")
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
            availableBytes: { .max },
            isPlayable: TestAudio.looksLikeMP3
        )
        state = PlayerState(player: player)
        state.surahs = (1...5).map(TestFixtures.surah)
        // The downloads below belong to this reciter, and offline availability is checked per reciter.
        state.selectReciter(TestFixtures.alafasy)
        let connectivity = connectivity
        PlayerSession.wireOffline(state, files: files) { connectivity.offline }
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func finishDownload(_ surahId: Int, contents: Data) async throws {
        await manager.waitForStartup()
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try contents.write(to: temporary)
        try files.move(from: temporary, surahId: surahId, itemId: item.id)
        let info = DownloadRequestInfo(surahId: surahId, item: item)
        await manager.handle(.finished(info, byteCount: Int64(contents.count)))
    }

    @Test(.timeLimit(.minutes(1)))
    func aFinishedDownloadIsIndexedAndSkippableToOffline() async throws {
        _ = manager.download(surah: TestFixtures.surah(2), item: item)

        try await finishDownload(2, contents: TestAudio.silentMP3())

        #expect(store.isDownloaded(surahId: 2, item: item))
        #expect(manager.state(surahId: 2, item: item) == nil, "the in-progress state clears")

        state.play(TestFixtures.surah(1))
        connectivity.offline = true
        state.playNext()
        #expect(state.selectedSurah?.id == 2)
    }

    @Test(.timeLimit(.minutes(1)), .tags(.edgeCase))
    func aBrokenFileNeverBecomesAvailableOffline() async throws {
        try await finishDownload(2, contents: TestAudio.garbage())

        #expect(store.isDownloaded(surahId: 2, item: item) == false)
        #expect(manager.state(surahId: 2, item: item) == .failed)

        state.play(TestFixtures.surah(1))
        connectivity.offline = true
        state.playNext()
        #expect(state.selectedSurah?.id == 1, "nothing playable offline, so no move")
    }

    @Test(.timeLimit(.minutes(1)))
    func removingADownloadMakesItUnavailableAgain() async throws {
        try await finishDownload(2, contents: TestAudio.silentMP3())
        try await finishDownload(3, contents: TestAudio.silentMP3())
        state.play(TestFixtures.surah(1))
        connectivity.offline = true

        manager.remove(surahId: 2, item: item)
        state.playNext()

        #expect(store.isDownloaded(surahId: 2, item: item) == false)
        #expect(state.selectedSurah?.id == 3)
    }
}
