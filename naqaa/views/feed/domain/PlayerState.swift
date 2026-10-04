import Foundation
import Observation

@Observable
@MainActor
final class PlayerState {
    /// Length of the visual hand-off that runs while a track is about to finish.
    static let exitTransitionWindow: Double = 3

    var selectedSurah: Surah?
    var isEmpty: Bool { selectedSurah == nil }
    var selectedReciter: ReciterMoshafItem = .defaultItem
    var surahs: [Surah] = []

    let player: any AudioPlaying

    var isPlaying: Bool { player.isPlaying }
    var isBuffering: Bool { player.isBuffering }
    var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    /// Ramps from `0` to `1` across the final `exitTransitionWindow` seconds of the current
    /// track, so the player can shrink and blur out. Falls back to `0` as soon as the next
    /// queue item starts playing.
    var exitTransitionAmount: Double {
        let duration = player.duration
        guard duration > 0 else { return 0 }
        let remaining = duration - player.currentTime
        guard remaining < Self.exitTransitionWindow else { return 0 }
        return min(max(1 - remaining / Self.exitTransitionWindow, 0), 1)
    }

    private var queue: SurahQueue { SurahQueue(surahs: surahs) }

    var canPlayNext: Bool { queue.next(after: selectedSurah) != nil }
    var canPlayPrevious: Bool { queue.previous(before: selectedSurah) != nil }

    init(player: (any AudioPlaying)? = nil) {
        var resolved: any AudioPlaying = player ?? AudioPlayerManager()
        self.player = resolved
        resolved.onTrackEnded = { [weak self] in self?.playNext() }
        resolved.onNextTrack = { [weak self] in self?.playNext() }
        resolved.onPreviousTrack = { [weak self] in self?.playPrevious() }
    }

    func play(_ surah: Surah) {
        selectedSurah = surah
        player.play(surah: surah, reciter: selectedReciter)
    }

    func selectReciter(_ item: ReciterMoshafItem) {
        selectedReciter = item
        if let surah = selectedSurah {
            player.play(surah: surah, reciter: item)
        }
    }

    func togglePlayPause() {
        player.togglePlayPause()
    }

    func seek(toProgress progress: Double) {
        guard player.duration > 0 else { return }
        player.seek(to: min(max(progress, 0), 1) * player.duration)
    }

    func playNext() {
        guard let next = queue.next(after: selectedSurah) else { return }
        play(next)
    }

    func playPrevious() {
        guard let previous = queue.previous(before: selectedSurah) else { return }
        play(previous)
    }
}
