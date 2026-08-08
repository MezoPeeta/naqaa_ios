import Foundation
import Observation

@Observable
@MainActor
final class PlayerState {
    var selectedSurah: Surah?
    var selectedReciter: ReciterMoshafItem = .defaultItem
    var surahs: [Surah] = []

    let player = AudioPlayerManager()

    var isPlaying: Bool { player.isPlaying }
    var isBuffering: Bool { player.isBuffering }

    var canPlayNext: Bool { nextSurah(after: selectedSurah) != nil }
    var canPlayPrevious: Bool { previousSurah(before: selectedSurah) != nil }

    init() {
        player.onTrackEnded = { [weak self] in self?.playNext() }
        player.onNextTrack = { [weak self] in self?.playNext() }
        player.onPreviousTrack = { [weak self] in self?.playPrevious() }
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
        guard let next = nextSurah(after: selectedSurah) else { return }
        play(next)
    }

    func playPrevious() {
        guard let previous = previousSurah(before: selectedSurah) else { return }
        play(previous)
    }

    private func nextSurah(after surah: Surah?) -> Surah? {
        guard let index = currentIndex(of: surah), index + 1 < surahs.count else { return nil }
        return surahs[index + 1]
    }

    private func previousSurah(before surah: Surah?) -> Surah? {
        guard let index = currentIndex(of: surah), index > 0 else { return nil }
        return surahs[index - 1]
    }

    private func currentIndex(of surah: Surah?) -> Int? {
        guard let surah else { return nil }
        return surahs.firstIndex(where: { $0.id == surah.id })
    }
}
