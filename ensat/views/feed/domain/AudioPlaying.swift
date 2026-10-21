import Foundation

@MainActor
protocol AudioPlaying: AnyObject {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var onTrackEnded: (() -> Void)? { get set }
    var onNextTrack: (() -> Void)? { get set }
    var onPreviousTrack: (() -> Void)? { get set }
    func play(surah: Surah, reciter: ReciterMoshafItem)
    /// Loads the track and seeks to `startAt` without starting playback.
    /// `knownDuration` (0 if unknown) avoids a separate network duration lookup.
    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double, knownDuration: Double)
    func togglePlayPause()
    func seek(to time: Double)
    /// True after the current track failed to load or play (e.g. streaming while offline).
    var didFailToPlay: Bool { get }
    func clearPlaybackFailure()
}

extension AudioPlaying {
    var didFailToPlay: Bool { false }
    func clearPlaybackFailure() {}
}

extension AudioPlayerManager: AudioPlaying {}
