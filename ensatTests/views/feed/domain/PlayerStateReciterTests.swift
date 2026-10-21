import Testing
@testable import ensat

@MainActor
@Suite(.tags(.reciters, .playback))
struct PlayerStateReciterTests {
    private let player = StubAudioPlayer()
    private let state: PlayerState

    init() {
        state = PlayerState(player: player)
        state.surahs = (1...3).map(TestFixtures.surah)
    }

    @Test func selectingAReciterWithNothingPlayingOnlyChangesTheReciter() {
        state.selectReciter(TestFixtures.alafasy)

        #expect(state.selectedReciter.id == TestFixtures.alafasy.id)
        #expect(state.selectedSurah == nil)
        #expect(player.played.isEmpty)
    }

    @Test func selectingAReciterPersistsTheChoice() {
        var reported: [String] = []
        state.onPersist = { _, reciter, _, _ in reported.append(reciter.id) }
        state.play(TestFixtures.surah(2))

        state.selectReciter(TestFixtures.alafasy)

        #expect(reported.last == TestFixtures.alafasy.id)
    }

    @Test func nextSurahUsesTheNewlySelectedReciter() {
        state.play(TestFixtures.surah(1))
        state.selectReciter(TestFixtures.alafasy)

        state.playNext()

        #expect(player.played.last?.surahId == 2)
        #expect(player.played.last?.reciterId == TestFixtures.alafasy.id)
    }

    @Test(.tags(.edgeCase))
    func changingReciterAndBackReplaysEachTime() {
        let original = state.selectedReciter
        state.play(TestFixtures.surah(1))

        state.selectReciter(TestFixtures.alafasy)
        state.selectReciter(original)

        #expect(player.playedReciterIds == [original.id, TestFixtures.alafasy.id, original.id])
    }

    // MARK: refreshSelectedReciter

    @Test func refreshAdoptsTheCatalogNamesForTheSameId() {
        let stale = TestFixtures.item(reciterName: "العفاسي", moshafName: "مرتل")
        state.restore(surah: TestFixtures.surah(1), reciter: stale, time: 0, duration: 0)
        let fresh = TestFixtures.item(reciterName: "Alafasy", moshafName: "Murattal")

        state.refreshSelectedReciter(from: [TestFixtures.other, fresh])

        #expect(state.selectedReciter.reciter.name == "Alafasy")
        #expect(state.selectedReciter.moshaf.name == "Murattal")
    }

    @Test func refreshDoesNotTouchPlayback() {
        state.restore(surah: TestFixtures.surah(1), reciter: TestFixtures.alafasy, time: 5, duration: 50)
        let fresh = TestFixtures.item(reciterName: "Renamed")

        state.refreshSelectedReciter(from: [fresh])

        #expect(player.played.isEmpty)
        #expect(player.currentTime == 5)
    }

    @Test(.tags(.edgeCase))
    func refreshIgnoresACatalogWithoutTheSelectedReciter() {
        state.restore(surah: TestFixtures.surah(1), reciter: TestFixtures.alafasy, time: 0, duration: 0)

        state.refreshSelectedReciter(from: [TestFixtures.other])
        #expect(state.selectedReciter == TestFixtures.alafasy)

        state.refreshSelectedReciter(from: [])
        #expect(state.selectedReciter == TestFixtures.alafasy)

        state.refreshSelectedReciter(from: [TestFixtures.alafasy])
        #expect(state.selectedReciter == TestFixtures.alafasy)
    }

}
