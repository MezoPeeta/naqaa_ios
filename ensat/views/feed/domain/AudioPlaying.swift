import Foundation

@MainActor
protocol AudioPlaying {
    var isPlaying: Bool { get }
    var isBuffering: Bool { get }
    var currentTime: Double { get }
    var duration: Double { get }
    var onTrackEnded: (() -> Void)? { get set }
    var onNextTrack: (() -> Void)? { get set }
    var onPreviousTrack: (() -> Void)? { get set }
    func play(surah: Surah, reciter: ReciterMoshafItem)
    /// Loads the track and seeks to `startAt` without starting playback.
    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double)
    func togglePlayPause()
    func seek(to time: Double)
}

extension AudioPlayerManager: AudioPlaying {}
