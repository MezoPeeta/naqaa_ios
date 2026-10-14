import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @State private var playerState: PlayerState
    @State private var expandMiniPlayer = false
    @Namespace private var animation

    init() {
        _playerState = State(initialValue: Self.makeRestoredPlayerState())
    }

    var body: some View {
        NativeTabView(playerState: playerState)
            .onChange(of: playerState.player.currentTime) {
                if playerState.isPlaying { playerState.persistThrottled() }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { playerState.persistNow() }
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory(isEnabled: !playerState.isEmpty) {
                PlayerBottom(playerState: playerState)
                    .matchedTransitionSource(id: "miniplayer", in: animation)
                    .onTapGesture {
                        expandMiniPlayer.toggle()
                    }
            }
            .fullScreenCover(isPresented: $expandMiniPlayer) {

                ScrollView {
                }

                .safeAreaInset(edge: .bottom, spacing: 0) {

                    PlayerView(playerState: playerState)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTransition(.zoom(sourceID: "miniplayer", in: animation))
                .background(.homeBackground)
                .presentationBackground(.clear)

            }

    }
}

extension HomeView {
    /// Builds the player and reopens the last track paused at its saved position. Runs while the
    /// launch screen is up, so the first frame already shows the restored mini-player.
    private static func makeRestoredPlayerState(store: PlaybackStore = PlaybackStore()) -> PlayerState {
        let state = PlayerState()
        state.onPersist = { surah, reciter, time, duration in
            store.save(PlaybackSnapshot(surahId: surah.id, item: reciter, currentTime: time, duration: duration))
        }

        let surahViewModel = SurahListViewModel()
        surahViewModel.loadLocal()
        guard case .loaded(let surahs) = surahViewModel.state else { return state }
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
}

#Preview {
    HomeView()
        .preferredColorScheme(.dark)

}
