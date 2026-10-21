#if DEBUG
import Foundation

/// Silent stand-in for the real audio player so previews can show a "playing" state.
@MainActor
final class PreviewAudioPlayer: AudioPlaying {
    var isPlaying = false
    var isBuffering = false
    var currentTime: Double = 150
    var duration: Double = 300
    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    func play(surah: Surah, reciter: ReciterMoshafItem) {}
    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double, knownDuration: Double) {}
    func togglePlayPause() {}
    func seek(to time: Double) {}
}

extension PlayerState {
    /// A player state with Al-Baqarah selected and playing, halfway through.
    static func preview() -> PlayerState {
        let state = PlayerState(player: PreviewAudioPlayer())
        let surah = Surah(
            id: 2,
            name: "البقرة",
            revelationPlace: .medinan,
            totalVerses: 286,
            transliteration: "Al-Baqarah"
        )
        state.surahs = [surah]
        state.selectedSurah = surah
        return state
    }
}
#endif
