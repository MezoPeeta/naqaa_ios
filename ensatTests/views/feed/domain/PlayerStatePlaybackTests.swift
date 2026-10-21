import Testing
@testable import ensat

@MainActor
@Suite(.tags(.playback))
struct PlayerStatePlaybackTests {
    private let player = StubAudioPlayer()
    private let state: PlayerState
    /// Collects `onPersist` calls; a class so the closure can append to it.
    final class PersistLog {
        var calls: [(surahId: Int, reciterId: String, time: Double, duration: Double)] = []
    }

    private let log = PersistLog()

    init() {
        state = PlayerState(player: player)
        state.surahs = (1...3).map(TestFixtures.surah)
        let log = log
        state.onPersist = { surah, reciter, time, duration in
            log.calls.append((surah.id, reciter.id, time, duration))
        }
    }

    // MARK: Persisting

    @Test func startingAndTogglingPersist() {
        state.play(TestFixtures.surah(2))
        #expect(log.calls.count == 1)

        state.togglePlayPause()
        #expect(log.calls.count == 2)
        #expect(log.calls.last?.surahId == 2)
    }

    @Test(.tags(.edgeCase))
    func persistingWithNothingToPersistIsSkipped() {
        state.persistNow()
        state.seek(toProgress: 0.5)
        #expect(log.calls.isEmpty, "no surah selected: nothing to save")

        state.play(TestFixtures.surah(1))
        let before = log.calls.count
        state.seek(toProgress: 0.5)
        #expect(log.calls.count == before, "unknown duration: the seek is ignored, so nothing new to save")
    }

    @Test func seekingPersistsTheNewPlayhead() {
        state.play(TestFixtures.surah(1))
        player.duration = 100

        state.seek(toProgress: 0.5)

        #expect(log.calls.last?.time == 50)
        #expect(log.calls.last?.duration == 100)
    }

    @Test func throttledPersistenceSkipsSavesWithinTheInterval() {
        state.play(TestFixtures.surah(1))  // saves once
        state.persistThrottled()           // within the interval, so skipped
        #expect(log.calls.count == 1)
    }

    // MARK: Progress

    @Test(.tags(.edgeCase), arguments: [
        (current: 0.0, duration: 0.0, expected: 0.0),
        (current: 50.0, duration: 0.0, expected: 0.0),
        (current: 0.0, duration: 100.0, expected: 0.0),
        (current: 25.0, duration: 100.0, expected: 0.25),
        (current: 100.0, duration: 100.0, expected: 1.0),
        (current: 150.0, duration: 100.0, expected: 1.0),
        (current: -5.0, duration: 100.0, expected: 0.0)
    ])
    func progressIsClampedToTheUnitRange(current: Double, duration: Double, expected: Double) {
        player.currentTime = current
        player.duration = duration
        #expect(state.progress == expected)
    }

    // MARK: Restore

    @Test(.tags(.edgeCase), arguments: [
        (time: 296.9, duration: 300.0, startsAt: 296.9),
        (time: 297.5, duration: 300.0, startsAt: 0.0),
        (time: 400.0, duration: 300.0, startsAt: 0.0),
        (time: 120.0, duration: 0.0, startsAt: 120.0)
    ])
    func restoreStartsFromZeroOnlyWhenTheSavedPlayheadIsAtTheEnd(time: Double, duration: Double, startsAt: Double) {
        state.restore(surah: TestFixtures.surah(2), reciter: TestFixtures.alafasy, time: time, duration: duration)
        #expect(player.prepared.last?.startAt == startsAt)
    }

    @Test func restoreDoesNotStartPlaybackOrPersist() {
        state.restore(surah: TestFixtures.surah(2), reciter: TestFixtures.alafasy, time: 10, duration: 100)

        #expect(state.selectedSurah?.id == 2)
        #expect(state.selectedReciter.id == TestFixtures.alafasy.id)
        #expect(player.played.isEmpty)
        #expect(log.calls.isEmpty)
    }

    @Test func restoredSurahContinuesWithTheNextOne() {
        state.restore(surah: TestFixtures.surah(2), reciter: TestFixtures.alafasy, time: 10, duration: 100)

        state.playNext()

        #expect(state.selectedSurah?.id == 3)
        #expect(player.playedReciterIds == [TestFixtures.alafasy.id], "the restored reciter keeps playing")
    }

    // MARK: Queue edges

    @Test(.tags(.edgeCase), arguments: [-1, 2, 99])
    func playingAQueueFromAnOutOfRangeIndexIsANoOp(index: Int) {
        let queue = [QueueEntry(surah: TestFixtures.surah(1), reciter: .defaultItem),
                     QueueEntry(surah: TestFixtures.surah(2), reciter: .defaultItem)]

        state.play(queue: queue, startAt: index)

        #expect(state.selectedSurah == nil)
        #expect(state.customQueue == nil)
        #expect(player.played.isEmpty)
    }

    @Test func playingAQueueAdoptsTheStartEntrysReciter() {
        let queue = [QueueEntry(surah: TestFixtures.surah(1), reciter: .defaultItem),
                     QueueEntry(surah: TestFixtures.surah(2), reciter: TestFixtures.other)]

        state.play(queue: queue, startAt: 1)

        #expect(state.selectedReciter.id == TestFixtures.other.id)
        #expect(player.playedReciterIds == [TestFixtures.other.id])
    }

    @Test(.tags(.surahs, .edgeCase))
    func aSurahOutsideTheListHasNoNeighbours() {
        state.play(TestFixtures.surah(99))

        #expect(state.canPlayNext == false)
        #expect(state.canPlayPrevious == false)
    }

    @Test(.tags(.surahs, .edgeCase))
    func trackEndingOnTheLastSurahStops() {
        state.play(TestFixtures.surah(3))

        player.onTrackEnded?()

        #expect(state.selectedSurah?.id == 3)
        #expect(player.playedSurahIds == [3])
    }
}
