import Foundation
import Testing
@testable import ensat

/// The app is closed mid-listen and reopened. Real: player session, playback store (real `UserDefaults`), restore logic.
@MainActor
@Suite(.tags(.integration, .playback))
final class RelaunchJourneyTests {
    private let defaultsName = "relaunch-\(UUID().uuidString)"
    private let defaults: UserDefaults
    private let surahs = (1...10).map(TestFixtures.surah)

    init() throws {
        defaults = try #require(UserDefaults(suiteName: defaultsName))
    }

    deinit {
        defaults.removePersistentDomain(forName: defaultsName)
    }

    private func launch() -> (state: PlayerState, player: StubAudioPlayer) {
        let player = StubAudioPlayer()
        let state = PlayerSession.make(player: player, store: PlaybackStore(defaults: defaults), surahs: surahs)
        return (state, player)
    }

    @Test func reopeningResumesTheSameSurahReciterAndPositionPaused() {
        let first = launch()
        first.state.play(TestFixtures.surah(5))
        first.state.selectReciter(TestFixtures.alafasy)
        first.player.duration = 300
        first.player.currentTime = 90
        first.state.persistNow()

        let second = launch()

        #expect(second.state.selectedSurah?.id == 5)
        #expect(second.state.selectedReciter.id == TestFixtures.alafasy.id)
        #expect(second.player.prepared.last?.startAt == 90)
        #expect(second.player.played.isEmpty, "restoring must not start playback")
    }

    @Test func playingNextAfterReopeningKeepsTheRestoredReciter() {
        let first = launch()
        first.state.play(TestFixtures.surah(5))
        first.state.selectReciter(TestFixtures.alafasy)
        first.state.persistNow()

        let second = launch()
        second.state.playNext()

        #expect(second.player.played.last?.surahId == 6)
        #expect(second.player.played.last?.reciterId == TestFixtures.alafasy.id)
    }

    @Test(.tags(.edgeCase))
    func closingJustBeforeTheEndReopensFromTheStart() {
        let first = launch()
        first.state.play(TestFixtures.surah(5))
        first.player.duration = 300
        first.player.currentTime = 299
        first.state.persistNow()

        let second = launch()

        #expect(second.state.selectedSurah?.id == 5)
        #expect(second.player.prepared.last?.startAt == 0)
    }

    @Test func everyKindOfInteractionIsSavedForTheNextLaunch() {
        let first = launch()
        first.state.play(TestFixtures.surah(2))
        first.state.playNext()
        first.player.duration = 100
        first.state.seek(toProgress: 0.25)

        let snapshot = PlaybackStore(defaults: defaults).load()

        #expect(snapshot?.surahId == 3)
        #expect(snapshot?.currentTime == 25)
        #expect(snapshot?.duration == 100)
    }

    @Test(.tags(.edgeCase))
    func aDamagedSnapshotOpensEmptyInsteadOfCrashing() {
        defaults.set(Data("garbage".utf8), forKey: "playback.snapshot")

        let launched = launch()

        #expect(launched.state.selectedSurah == nil)
        #expect(launched.state.surahs.count == 10)
        #expect(launched.player.prepared.isEmpty)
    }

    @Test(.tags(.edgeCase))
    func aSnapshotForASurahThatNoLongerExistsOpensEmpty() {
        PlaybackStore(defaults: defaults).save(
            PlaybackSnapshot(surahId: 200, item: TestFixtures.alafasy, currentTime: 5, duration: 50)
        )

        let launched = launch()

        #expect(launched.state.selectedSurah == nil)
        #expect(launched.player.prepared.isEmpty)
    }
}
