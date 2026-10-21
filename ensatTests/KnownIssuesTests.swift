import Testing
@testable import ensat

/// Behaviors that look wrong today. Each test passes while the bug exists (`withKnownIssue`)
/// and fails once it is fixed, which is the cue to turn it into a normal test.
@MainActor
@Suite(.tags(.playback, .edgeCase))
struct KnownIssuesTests {
    private let player = StubAudioPlayer()
    private let state: PlayerState

    init() {
        state = PlayerState(player: player)
        state.surahs = (1...3).map(TestFixtures.surah)
    }

    @Test func renamedButIdenticalReciterDoesNotReloadTheTrack() {
        // A restored snapshot keeps the language it was saved in; the catalog has the same id, new names.
        let restored = TestFixtures.item(reciterName: "العفاسي", moshafName: "مرتل")
        let fromCatalog = TestFixtures.item(reciterName: "Alafasy", moshafName: "Murattal")
        state.restore(surah: TestFixtures.surah(1), reciter: restored, time: 10, duration: 100)

        state.selectReciter(fromCatalog)

        withKnownIssue("selectReciter compares whole items, so a renamed duplicate restarts playback") {
            #expect(player.played.isEmpty)
        }
    }

    @Test func customQueueStillNavigatesAfterChangingToAReciterOutsideIt() {
        let queue = (1...3).map { QueueEntry(surah: TestFixtures.surah($0), reciter: .defaultItem) }
        state.play(queue: queue)

        state.selectReciter(TestFixtures.alafasy)

        withKnownIssue("EntryQueue matches on reciter id, so the playing entry is no longer found") {
            #expect(state.canPlayNext)
        }
    }
}
