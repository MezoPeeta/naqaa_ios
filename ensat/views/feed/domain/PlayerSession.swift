import Foundation

/// Builds the app's `PlayerState` and connects it to persistence and offline availability.
/// Lives outside the views so the same wiring can be exercised in tests.
@MainActor
enum PlayerSession {
    /// Builds the player and reopens the last track paused at its saved position.
    static func make(
        player: (any AudioPlaying)? = nil,
        store: PlaybackStore = PlaybackStore(),
        surahs: [Surah]
    ) -> PlayerState {
        let state = PlayerState(player: player)
        state.onPersist = { surah, reciter, time, duration in
            store.save(PlaybackSnapshot(surahId: surah.id, item: reciter, currentTime: time, duration: duration))
        }
        state.surahs = surahs

        guard let snapshot = store.load(),
              let surah = surahs.first(where: { $0.id == snapshot.surahId })
        else { return state }
        state.restore(
            surah: surah,
            reciter: snapshot.item,
            time: snapshot.currentTime,
            duration: snapshot.duration
        )
        return state
    }

    /// The bundled surah list, or empty when it can't be read.
    static func bundledSurahs() -> [Surah] {
        let viewModel = SurahListViewModel()
        viewModel.loadLocal()
        guard case .loaded(let surahs) = viewModel.state else { return [] }
        return surahs
    }

    /// While offline, next/previous skip surahs that aren't saved on disk for the current reciter.
    static func wireOffline(
        _ state: PlayerState,
        files: DownloadFileStore = DownloadFileStore(),
        isOffline: @escaping () -> Bool
    ) {
        state.isOffline = isOffline
        state.isAvailableOffline = { surah, reciter in
            files.exists(surahId: surah.id, itemId: reciter.id)
        }
    }
}
