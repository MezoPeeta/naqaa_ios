import Foundation
@testable import ensat

/// Records what `PlayerState` asks of its player, without touching AVFoundation.
@MainActor
final class StubAudioPlayer: AudioPlaying {
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 0
    var duration: Double = 0
    var didFailToPlay = false

    fileprivate(set) var played: [(surahId: Int, reciterId: String)] = []
    fileprivate(set) var prepared: [(surahId: Int, reciterId: String, startAt: Double)] = []
    fileprivate(set) var seekTimes: [Double] = []
    fileprivate(set) var toggleCalls = 0
    fileprivate(set) var clearFailureCalls = 0

    var playedSurahIds: [Int] { played.map(\.surahId) }
    var playedReciterIds: [String] { played.map(\.reciterId) }

    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        played.append((surah.id, reciter.id))
        currentTime = 0
        duration = 0
    }

    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double, knownDuration: Double) {
        prepared.append((surah.id, reciter.id, startAt))
        currentTime = startAt
    }

    func togglePlayPause() {
        toggleCalls += 1
    }

    func seek(to time: Double) {
        seekTimes.append(time)
        currentTime = time
    }

    fileprivate func resetRecordedCalls() {
        played = []
        prepared = []
        seekTimes = []
        toggleCalls = 0
        clearFailureCalls = 0
    }

    func clearPlaybackFailure() {
        clearFailureCalls += 1
        didFailToPlay = false
    }
}

extension StubAudioPlayer {
    /// Forgets calls made while setting a test up, so assertions only see the scenario itself.
    func clearHistory() {
        resetRecordedCalls()
    }
}
