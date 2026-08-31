//
//  PlayerStateTests.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import XCTest
@testable import naqaa

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
}

@MainActor
private final class FakeAudioPlayer: AudioPlaying {
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 0
    var duration: Double = 0
    private(set) var playedSurahIds: [Int] = []
    private(set) var playedReciterIds: [String] = []
    private(set) var toggleCalls = 0

    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        playedSurahIds.append(surah.id)
        playedReciterIds.append(reciter.id)
    }

    func togglePlayPause() {
        toggleCalls += 1
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
