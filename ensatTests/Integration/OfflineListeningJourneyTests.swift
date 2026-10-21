import Foundation
import SwiftData
import Testing
@testable import ensat

/// A listener downloads some surahs, loses the connection, and skips around.
/// Real: player session wiring, downloads index, files on disk, network monitor. Faked: the audio player and connectivity.
@MainActor
@Suite(.tags(.integration, .offline))
final class OfflineListeningJourneyTests {
    private static let debounce = Duration.milliseconds(120)

    /// Held for the whole test: a `ModelContext` traps if its container is released.
    private let container: ModelContainer
    private let directory: URL
    private let files: DownloadFileStore
    private let downloads: DownloadsStore
    private let connectivity = StubConnectivitySource()
    private let network: NetworkMonitor
    private let player = StubAudioPlayer()
    private let state: PlayerState
    private let reciter = TestFixtures.alafasy
    private let defaultsName = "journey-\(UUID().uuidString)"

    init() throws {
        container = try ModelContainer(
            for: DownloadedTrack.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        directory = try TestFixtures.temporaryDirectory("offline-journey")
        files = DownloadFileStore(directory: directory)
        downloads = DownloadsStore(context: container.mainContext, files: files)
        network = NetworkMonitor(source: connectivity, offlineDelay: Self.debounce)

        let defaults = try #require(UserDefaults(suiteName: defaultsName))
        state = PlayerSession.make(
            player: player,
            store: PlaybackStore(defaults: defaults),
            surahs: (1...5).map(TestFixtures.surah)
        )
        let network = network
        PlayerSession.wireOffline(state, files: files) { network.isOffline }
        state.selectReciter(reciter)
        player.clearHistory()
    }

    deinit {
        UserDefaults.standard.removePersistentDomain(forName: defaultsName)
        try? FileManager.default.removeItem(at: directory)
    }

    private func download(_ surahId: Int, for item: ReciterMoshafItem? = nil) throws {
        let item = item ?? reciter
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: 8).write(to: temporary)
        try files.move(from: temporary, surahId: surahId, itemId: item.id)
        downloads.add(surahId: surahId, item: item, byteCount: 8)
    }

    private func goOffline() async {
        connectivity.send(connected: false)
        #expect(await wait { network.isOffline }, "the monitor should report offline after the debounce")
    }

    private func goOnline() async {
        connectivity.send(connected: true)
        #expect(await wait { network.isOffline == false })
    }

    private func wait(_ condition: () -> Bool) async -> Bool {
        let deadline = ContinuousClock.now + .seconds(3)
        while ContinuousClock.now < deadline {
            if condition() { return true }
            try? await Task.sleep(for: .milliseconds(10))
        }
        return condition()
    }

    @Test func offlineSkippingFollowsWhatIsReallyOnDisk() async throws {
        try download(1)
        try download(3)
        try download(4)
        state.play(TestFixtures.surah(1))
        await goOffline()

        state.playNext()
        #expect(state.selectedSurah?.id == 3, "surah 2 isn't saved, so it is skipped")
        state.playNext()
        #expect(state.selectedSurah?.id == 4)
        state.playNext()
        #expect(state.selectedSurah?.id == 4, "surah 5 isn't saved: stay on the last playable surah")

        state.playPrevious()
        state.playPrevious()
        #expect(state.selectedSurah?.id == 1)
        #expect(player.playedSurahIds == [1, 3, 4, 3, 1])
    }

    @Test func removingADownloadChangesWhatCanBePlayedOffline() async throws {
        try download(1)
        try download(2)
        try download(3)
        state.play(TestFixtures.surah(1))
        await goOffline()

        downloads.remove(surahId: 2, item: reciter)
        state.playNext()

        #expect(state.selectedSurah?.id == 3)
    }

    @Test func aDownloadFromAnotherReciterDoesNotMakeASurahPlayable() async throws {
        try download(2, for: TestFixtures.other)
        try download(3)
        state.play(TestFixtures.surah(1))
        await goOffline()

        state.playNext()

        #expect(state.selectedSurah?.id == 3)
    }

    @Test func comingBackOnlineRestoresFullNavigation() async throws {
        try download(1)
        state.play(TestFixtures.surah(1))
        await goOffline()
        state.playNext()
        #expect(state.selectedSurah?.id == 1, "offline with nothing else saved: no move")

        await goOnline()
        state.playNext()

        #expect(state.selectedSurah?.id == 2)
    }

    @Test(.tags(.edgeCase, .timing))
    func aBriefDropDoesNotChangeSkipping() async throws {
        state.play(TestFixtures.surah(1))

        connectivity.send(connected: false)
        try await Task.sleep(for: .milliseconds(30))
        connectivity.send(connected: true)
        try await Task.sleep(for: Self.debounce * 3)
        state.playNext()

        #expect(state.selectedSurah?.id == 2, "the drop was shorter than the debounce, so we are still online")
    }
}
