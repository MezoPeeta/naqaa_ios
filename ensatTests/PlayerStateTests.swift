//
//  PlayerStateTests.swift
//  ensat
//
//  Created by Mazen on 30/08/2026.
//

import XCTest
@testable import ensat

private func makeSurah(id: Int) -> Surah {
    Surah(
        id: id,
        name: "سورة \(id)",
        revelationPlace: .meccan,
        totalVerses: 1,
        transliteration: "Surah \(id)"
    )
}

@MainActor
final class SurahQueueTests: XCTestCase {

    private let surahs = [1, 2, 3].map(makeSurah)

    func testNextFromNilIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).next(after: nil))
    }

    func testNextInMiddle() {
        let queue = SurahQueue(surahs: surahs)
        XCTAssertEqual(queue.next(after: surahs[0])?.id, 2)
    }

    func testNextAtEndIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).next(after: surahs[2]))
    }

    func testNextForUnknownIdIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).next(after: makeSurah(id: 99)))
    }

    func testPreviousFromNilIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).previous(before: nil))
    }

    func testPreviousAtStartIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).previous(before: surahs[0]))
    }

    func testPreviousInMiddle() {
        let queue = SurahQueue(surahs: surahs)
        XCTAssertEqual(queue.previous(before: surahs[2])?.id, 2)
    }

    func testPreviousForUnknownIdIsNil() {
        XCTAssertNil(SurahQueue(surahs: surahs).previous(before: makeSurah(id: 99)))
    }

    func testEmptyQueue() {
        let queue = SurahQueue(surahs: [])
        XCTAssertNil(queue.next(after: makeSurah(id: 1)))
        XCTAssertNil(queue.previous(before: makeSurah(id: 1)))
    }
}

@MainActor
final class PlayerStateTests: XCTestCase {

    private func makeState() -> (PlayerState, FakeAudioPlayer) {
        let fake = FakeAudioPlayer()
        let state = PlayerState(player: fake)
        state.surahs = [1, 2, 3].map(makeSurah)
        return (state, fake)
    }

    func testPlaySetsSelectedSurahAndForwardsToPlayer() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 1))
        XCTAssertEqual(state.selectedSurah?.id, 1)
        XCTAssertEqual(fake.playedSurahIds, [1])
    }

    func testPlayNextUpdatesSelectedSurahAndPlaysNext() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 1))
        state.playNext()
        XCTAssertEqual(state.selectedSurah?.id, 2)
        XCTAssertEqual(fake.playedSurahIds, [1, 2])
    }

    func testPlayNextAtEndIsNoOp() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 3))
        state.playNext()
        XCTAssertEqual(state.selectedSurah?.id, 3)
        XCTAssertEqual(fake.playedSurahIds, [3])
    }

    func testPlayPreviousUpdatesSelectedSurahAndPlaysPrevious() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 3))
        state.playPrevious()
        XCTAssertEqual(state.selectedSurah?.id, 2)
        XCTAssertEqual(fake.playedSurahIds, [3, 2])
    }

    func testPlayPreviousAtStartIsNoOp() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 1))
        state.playPrevious()
        XCTAssertEqual(state.selectedSurah?.id, 1)
        XCTAssertEqual(fake.playedSurahIds, [1])
    }

    func testPlayNextWithoutPlaylistIsNoOp() {
        let fake = FakeAudioPlayer()
        let state = PlayerState(player: fake)
        state.playNext()
        XCTAssertNil(state.selectedSurah)
        XCTAssertTrue(fake.playedSurahIds.isEmpty)
    }

    func testCanPlayNextAndPreviousBoundaries() {
        let (state, _) = makeState()
        XCTAssertFalse(state.canPlayNext)
        XCTAssertFalse(state.canPlayPrevious)

        state.play(makeSurah(id: 1))
        XCTAssertTrue(state.canPlayNext)
        XCTAssertFalse(state.canPlayPrevious)

        state.play(makeSurah(id: 3))
        XCTAssertFalse(state.canPlayNext)
        XCTAssertTrue(state.canPlayPrevious)
    }

    func testSelectReciterReplaysCurrentSurah() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 2))
        let initialReciter = state.selectedReciter
        state.selectReciter(ReciterMoshafItem.Fixture.alafasy)
        XCTAssertEqual(state.selectedReciter.id, "alafasy")
        XCTAssertEqual(fake.playedSurahIds, [2, 2])
        XCTAssertEqual(fake.playedReciterIds, [initialReciter.id, "alafasy"])
    }

    func testTogglePlayPauseDelegatesToPlayer() {
        let (state, fake) = makeState()
        state.togglePlayPause()
        XCTAssertEqual(fake.toggleCalls, 1)
    }

    func testSeekToProgressConvertsToTime() {
        let (state, fake) = makeState()
        fake.duration = 200
        state.seek(toProgress: 0.25)
        XCTAssertEqual(fake.seekTimes, [50])
    }

    func testSeekToProgressClampsOutOfRangeValues() {
        let (state, fake) = makeState()
        fake.duration = 200
        state.seek(toProgress: -1)
        state.seek(toProgress: 2)
        XCTAssertEqual(fake.seekTimes, [0, 200])
    }

    func testSeekToProgressWithoutDurationIsNoOp() {
        let (state, fake) = makeState()
        fake.duration = 0
        state.seek(toProgress: 0.5)
        XCTAssertTrue(fake.seekTimes.isEmpty)
    }

    func testOnNextTrackCallbackAdvancesPlaylist() {
        let (state, _) = makeState()
        state.play(makeSurah(id: 1))
        state.player.onNextTrack?()
        XCTAssertEqual(state.selectedSurah?.id, 2)
    }

    func testOnPreviousTrackCallbackRewindsPlaylist() {
        let (state, _) = makeState()
        state.play(makeSurah(id: 2))
        state.player.onPreviousTrack?()
        XCTAssertEqual(state.selectedSurah?.id, 1)
    }

    func testOnTrackEndedCallbackAdvancesPlaylist() {
        let (state, _) = makeState()
        state.play(makeSurah(id: 1))
        state.player.onTrackEnded?()
        XCTAssertEqual(state.selectedSurah?.id, 2)
    }

    func testExitTransitionAmountIsZeroBeforeTheTransitionWindow() {
        let (state, fake) = makeState()
        fake.duration = 300
        fake.currentTime = 296
        XCTAssertEqual(state.exitTransitionAmount, 0)
    }

    func testExitTransitionAmountRampsToOneAtTheEnd() {
        let (state, fake) = makeState()
        fake.duration = 30
        fake.currentTime = 27
        XCTAssertEqual(state.exitTransitionAmount, 0)

        fake.currentTime = 28
        XCTAssertEqual(state.exitTransitionAmount, 1.0 / 3.0, accuracy: 0.0001)

        fake.currentTime = 29
        XCTAssertEqual(state.exitTransitionAmount, 2.0 / 3.0, accuracy: 0.0001)

        fake.currentTime = 30
        XCTAssertEqual(state.exitTransitionAmount, 1, accuracy: 0.0001)

        fake.currentTime = 35
        XCTAssertEqual(state.exitTransitionAmount, 1, accuracy: 0.0001)
    }

    func testExitTransitionAmountIsZeroWhenDurationIsUnknown() {
        let (state, fake) = makeState()
        fake.duration = 0
        fake.currentTime = 0
        XCTAssertEqual(state.exitTransitionAmount, 0)
    }

    func testExitTransitionAmountResetsWhenNextTrackStarts() {
        let (state, fake) = makeState()
        state.play(makeSurah(id: 1))
        fake.duration = 300
        fake.currentTime = 300
        XCTAssertEqual(state.exitTransitionAmount, 1, accuracy: 0.0001)

        state.playNext()
        XCTAssertEqual(state.exitTransitionAmount, 0)
    }
}

@MainActor
private final class FakeAudioPlayer: AudioPlaying {
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 0
    var duration: Double = 0
    private(set) var playedSurahIds: [Int] = []
    private(set) var playedReciterIds: [String] = []
    private(set) var seekTimes: [Double] = []
    private(set) var toggleCalls = 0

    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        playedSurahIds.append(surah.id)
        playedReciterIds.append(reciter.id)
        currentTime = 0
        duration = 0
    }

    func togglePlayPause() {
        toggleCalls += 1
    }

    func seek(to time: Double) {
        seekTimes.append(time)
        currentTime = time
    }
}

private extension ReciterMoshafItem {
    enum Fixture {
        static let alafasy = ReciterMoshafItem(
            id: "alafasy",
            reciter: Reciter(id: 1, name: "Alafasy", letter: "A", moshaf: []),
            moshaf: Moshaf(id: 1, name: "Moshaf", server: "")
        )
    }
}
