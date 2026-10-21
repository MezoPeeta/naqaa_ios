import Testing
@testable import ensat

@MainActor
@Suite(.tags(.playback))
struct PlayerStateTests {
    private let player = StubAudioPlayer()
    private let state: PlayerState

    init() {
        state = PlayerState(player: player)
        state.surahs = [1, 2, 3].map(TestFixtures.surah)
    }

    private func entry(_ id: Int, reciter: ReciterMoshafItem) -> QueueEntry {
        QueueEntry(surah: TestFixtures.surah(id), reciter: reciter)
    }

    private func isClose(_ value: Double, _ expected: Double) -> Bool {
        abs(value - expected) < 0.0001
    }

    // MARK: Navigation

    @Test func playSetsSelectedSurahAndForwardsToPlayer() {
        state.play(TestFixtures.surah(1))
        #expect(state.selectedSurah?.id == 1)
        #expect(player.playedSurahIds == [1])
    }

    @Test func playNextUpdatesSelectedSurahAndPlaysNext() {
        state.play(TestFixtures.surah(1))
        state.playNext()
        #expect(state.selectedSurah?.id == 2)
        #expect(player.playedSurahIds == [1, 2])
    }

    @Test func playPreviousUpdatesSelectedSurahAndPlaysPrevious() {
        state.play(TestFixtures.surah(3))
        state.playPrevious()
        #expect(state.selectedSurah?.id == 2)
        #expect(player.playedSurahIds == [3, 2])
    }

    @Test(.tags(.edgeCase), arguments: [(start: 3, forward: true), (start: 1, forward: false)])
    func skippingPastTheEndsIsANoOp(start: Int, forward: Bool) {
        state.play(TestFixtures.surah(start))

        if forward { state.playNext() } else { state.playPrevious() }

        #expect(state.selectedSurah?.id == start)
        #expect(player.playedSurahIds == [start])
    }

    @Test(.tags(.edgeCase))
    func playNextWithoutAPlaylistIsANoOp() {
        let empty = PlayerState(player: player)
        empty.playNext()
        #expect(empty.selectedSurah == nil)
        #expect(player.playedSurahIds.isEmpty)
    }

    @Test func canPlayNextAndPreviousBoundaries() {
        #expect(state.canPlayNext == false)
        #expect(state.canPlayPrevious == false)

        state.play(TestFixtures.surah(1))
        #expect(state.canPlayNext)
        #expect(state.canPlayPrevious == false)

        state.play(TestFixtures.surah(3))
        #expect(state.canPlayNext == false)
        #expect(state.canPlayPrevious)
    }

    @Test func mediaKeysAndTrackEndDriveTheSameNavigation() throws {
        state.play(TestFixtures.surah(1))

        player.onNextTrack?()
        #expect(state.selectedSurah?.id == 2)

        player.onPreviousTrack?()
        #expect(state.selectedSurah?.id == 1)

        player.onTrackEnded?()
        #expect(state.selectedSurah?.id == 2)
    }

    // MARK: Reciter

    @Test func selectReciterReplaysCurrentSurah() {
        state.play(TestFixtures.surah(2))
        let initialReciter = state.selectedReciter

        state.selectReciter(TestFixtures.alafasy)

        #expect(state.selectedReciter.id == TestFixtures.alafasy.id)
        #expect(player.playedSurahIds == [2, 2])
        #expect(player.playedReciterIds == [initialReciter.id, TestFixtures.alafasy.id])
    }

    @Test func selectingCurrentReciterDoesNotReloadTrack() {
        state.play(TestFixtures.surah(2))
        state.selectReciter(state.selectedReciter)
        #expect(player.playedSurahIds == [2])
    }

    // MARK: Custom queue

    @Test func customQueueAdvancesThroughEntriesWithTheirReciters() {
        let other = TestFixtures.alafasy
        state.play(queue: [
            entry(5, reciter: .defaultItem), entry(2, reciter: other), entry(9, reciter: .defaultItem)
        ])

        state.playNext()
        #expect(state.selectedSurah?.id == 2)
        #expect(state.selectedReciter.id == other.id)

        state.playNext()
        #expect(state.selectedSurah?.id == 9)
        #expect(player.playedSurahIds == [5, 2, 9])
        #expect(state.canPlayNext == false)

        state.playNext()
        #expect(player.playedSurahIds == [5, 2, 9])
    }

    @Test func customQueuePlayPreviousWalksBack() {
        state.play(queue: [entry(5, reciter: .defaultItem), entry(2, reciter: .defaultItem)], startAt: 1)
        #expect(state.canPlayPrevious)
        state.playPrevious()
        #expect(state.selectedSurah?.id == 5)
    }

    @Test func plainPlayClearsCustomQueue() {
        state.play(queue: [entry(5, reciter: .defaultItem), entry(7, reciter: .defaultItem)])
        state.play(TestFixtures.surah(1))
        #expect(state.customQueue == nil)
        state.playNext()
        #expect(state.selectedSurah?.id == 2)
    }

    @Test(.tags(.edgeCase))
    func playingAnEmptyQueueIsANoOp() {
        state.play(queue: [])
        #expect(state.selectedSurah == nil)
        #expect(player.playedSurahIds.isEmpty)
    }

    // MARK: Transport

    @Test func togglePlayPauseDelegatesToPlayerAndPersists() {
        var saves = 0
        state.onPersist = { _, _, _, _ in saves += 1 }
        state.play(TestFixtures.surah(1))

        state.togglePlayPause()

        #expect(player.toggleCalls == 1)
        #expect(saves == 2, "starting and toggling each save the position")
    }

    @Test(arguments: [
        (progress: 0.25, duration: 200.0, seeks: [50.0]),
        (progress: -1.0, duration: 200.0, seeks: [0.0]),
        (progress: 2.0, duration: 200.0, seeks: [200.0]),
        (progress: 0.5, duration: 0.0, seeks: [Double]())
    ])
    func seekConvertsProgressToClampedTime(progress: Double, duration: Double, seeks: [Double]) {
        player.duration = duration
        state.seek(toProgress: progress)
        #expect(player.seekTimes == seeks)
    }

    // MARK: Exit transition and title sweep

    @Test(arguments: [
        (current: 296.0, duration: 300.0, expected: 0.0),
        (current: 27.0, duration: 30.0, expected: 0.0),
        (current: 28.0, duration: 30.0, expected: 1.0 / 3.0),
        (current: 29.0, duration: 30.0, expected: 2.0 / 3.0),
        (current: 30.0, duration: 30.0, expected: 1.0),
        (current: 35.0, duration: 30.0, expected: 1.0),
        (current: 0.0, duration: 0.0, expected: 0.0)
    ])
    func exitTransitionRampsToOneAtTheEnd(current: Double, duration: Double, expected: Double) {
        player.duration = duration
        player.currentTime = current
        #expect(isClose(state.exitTransitionAmount, expected))
    }

    @Test func exitTransitionResetsWhenNextTrackStarts() {
        state.play(TestFixtures.surah(1))
        player.duration = 300
        player.currentTime = 300
        #expect(isClose(state.exitTransitionAmount, 1))

        state.playNext()

        #expect(state.exitTransitionAmount == 0)
    }

    @Test(arguments: [(current: 54.0, sweeps: false), (current: 56.0, sweeps: true), (current: 60.0, sweeps: true)])
    func titleSweepsOnlyInTheLastFiveSeconds(current: Double, sweeps: Bool) {
        state.play(TestFixtures.surah(1))
        player.duration = 60
        player.currentTime = current
        #expect(state.shouldSweepTitle == sweeps)
    }

    @Test(arguments: [
        (playhead: 54.0, expected: 0.0),
        (playhead: 57.5, expected: 0.5),
        (playhead: 60.0, expected: 1.0),
        (playhead: 61.0, expected: 1.0)
    ])
    func titleSweepAmountRampsWithTheGivenPlayhead(playhead: Double, expected: Double) {
        state.play(TestFixtures.surah(1))
        player.duration = 60
        player.currentTime = 0
        #expect(isClose(state.titleSweepAmount(atPlayhead: playhead), expected))
    }

    @Test(.tags(.edgeCase))
    func titleDoesNotSweepOnTheLastTrackOrWithoutADuration() {
        state.play(TestFixtures.surah(3))
        player.duration = 60
        player.currentTime = 60
        #expect(state.shouldSweepTitle == false, "nothing follows the last track")

        state.play(TestFixtures.surah(1))
        player.duration = 0
        player.currentTime = 0
        #expect(state.shouldSweepTitle == false, "unknown duration")
    }
}
