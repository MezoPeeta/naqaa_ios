import Foundation
import Observation

@Observable
@MainActor
final class PlayerState {
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

    func playNext() {
        guard let next = queue.next(after: selectedSurah) else { return }
        play(next)
    }

    func playPrevious() {
        guard let previous = queue.previous(before: selectedSurah) else { return }
        play(previous)
    }
}
