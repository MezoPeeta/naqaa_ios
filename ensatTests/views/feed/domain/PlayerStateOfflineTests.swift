import Testing
@testable import ensat

@MainActor
@Suite(.tags(.offline, .playback))
struct PlayerStateOfflineTests {
    private let player = StubAudioPlayer()
    private let state: PlayerState

    init() {
        state = PlayerState(player: player)
        state.surahs = (1...5).map(TestFixtures.surah)
    }

    private func goOffline(downloaded: Set<Int>) {
        state.isOffline = { true }
        state.isAvailableOffline = { surah, _ in downloaded.contains(surah.id) }
    }

    struct SkipCase: Sendable, CustomTestStringConvertible {
        let downloaded: Set<Int>
        let from: Int
        let expected: Int?

        var testDescription: String {
            "downloaded \(downloaded.sorted()), from \(from) -> \(expected.map(String.init) ?? "stay")"
        }
    }

    @Test(arguments: [
        SkipCase(downloaded: [1, 2], from: 1, expected: 2),
        SkipCase(downloaded: [1, 4], from: 1, expected: 4),
        SkipCase(downloaded: [1, 5], from: 1, expected: 5),
        SkipCase(downloaded: [1], from: 1, expected: nil),
        SkipCase(downloaded: [], from: 1, expected: nil),
        SkipCase(downloaded: [1, 2, 3, 4], from: 5, expected: nil)
    ])
    func playNextSkipsUndownloadedSurahs(_ skip: SkipCase) {
        state.play(TestFixtures.surah(skip.from))
        goOffline(downloaded: skip.downloaded)

        state.playNext()

        #expect(state.selectedSurah?.id == (skip.expected ?? skip.from))
        #expect(player.playedSurahIds == [skip.from] + (skip.expected.map { [$0] } ?? []))
    }

    @Test(arguments: [
        SkipCase(downloaded: [3, 4], from: 4, expected: 3),
        SkipCase(downloaded: [1, 4], from: 4, expected: 1),
        SkipCase(downloaded: [2, 5], from: 5, expected: 2),
        SkipCase(downloaded: [4], from: 4, expected: nil),
        SkipCase(downloaded: [], from: 5, expected: nil),
        SkipCase(downloaded: [2, 3, 4, 5], from: 1, expected: nil)
    ])
    func playPreviousSkipsUndownloadedSurahs(_ skip: SkipCase) {
        state.play(TestFixtures.surah(skip.from))
        goOffline(downloaded: skip.downloaded)

        state.playPrevious()

        #expect(state.selectedSurah?.id == (skip.expected ?? skip.from))
        #expect(player.playedSurahIds == [skip.from] + (skip.expected.map { [$0] } ?? []))
    }

    @Test func onlineNeverSkipsEvenWhenNothingIsDownloaded() {
        state.play(TestFixtures.surah(1))
        state.isOffline = { false }
        state.isAvailableOffline = { _, _ in false }

        state.playNext()

        #expect(state.selectedSurah?.id == 2)
    }

    @Test func connectivityIsReadAtCallTimeNotAtSetup() {
        var offline = true
        state.isOffline = { offline }
        state.isAvailableOffline = { _, _ in false }
        state.play(TestFixtures.surah(1))

        state.playNext()
        #expect(state.selectedSurah?.id == 1, "offline with nothing downloaded: stay put")

        offline = false
        state.playNext()
        #expect(state.selectedSurah?.id == 2, "back online: streaming is allowed again")
    }

    @Test(.tags(.edgeCase))
    func trackEndingOfflineWithNothingDownloadedAheadDoesNotAdvance() {
        state.play(TestFixtures.surah(2))
        goOffline(downloaded: [2])

        player.onTrackEnded?()

        #expect(state.selectedSurah?.id == 2)
        #expect(player.playedSurahIds == [2])
    }

    @Test(.tags(.edgeCase))
    func mediaKeysSkipUndownloadedSurahsToo() {
        state.play(TestFixtures.surah(1))
        goOffline(downloaded: [1, 3])

        player.onNextTrack?()
        #expect(state.selectedSurah?.id == 3)

        player.onPreviousTrack?()
        #expect(state.selectedSurah?.id == 1)
    }

    @Test(.tags(.edgeCase))
    func offlineSkipInCustomQueueFollowsEachEntrysReciter() {
        let other = TestFixtures.other
        let queue = [
            QueueEntry(surah: TestFixtures.surah(1), reciter: .defaultItem),
            QueueEntry(surah: TestFixtures.surah(2), reciter: other),
            QueueEntry(surah: TestFixtures.surah(3), reciter: .defaultItem),
            QueueEntry(surah: TestFixtures.surah(4), reciter: other)
        ]
        state.play(queue: queue)
        state.isOffline = { true }
        state.isAvailableOffline = { surah, reciter in
            (surah.id == 1 && reciter.id == ReciterMoshafItem.defaultItem.id) ||
            (surah.id == 4 && reciter.id == other.id)
        }

        state.playNext()

        #expect(state.selectedSurah?.id == 4)
        #expect(state.selectedReciter.id == other.id)
    }

    @Test(.tags(.edgeCase))
    func availabilityIsPerReciterNotPerSurah() {
        let queue = [
            QueueEntry(surah: TestFixtures.surah(5), reciter: .defaultItem),
            QueueEntry(surah: TestFixtures.surah(5), reciter: TestFixtures.other)
        ]
        state.play(queue: queue)
        state.isOffline = { true }
        state.isAvailableOffline = { _, reciter in reciter.id == ReciterMoshafItem.defaultItem.id }

        state.playNext()

        #expect(state.selectedReciter.id == ReciterMoshafItem.defaultItem.id)
        #expect(player.playedSurahIds == [5], "the other reciter's copy of surah 5 isn't downloaded")
    }

    // MARK: Playback failure

    @Test func dismissingTheFailureClearsItOnThePlayer() {
        player.didFailToPlay = true

        state.dismissPlaybackFailure()

        #expect(player.clearFailureCalls == 1)
        #expect(state.playbackFailed == false)
    }
}
