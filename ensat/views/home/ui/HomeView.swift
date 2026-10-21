import SwiftUI

struct HomeView: View {
    @Environment(\.scenePhase) private var scenePhase
    @Environment(NetworkMonitor.self) private var network
    @State private var playerState: PlayerState
    @State private var expandMiniPlayer = false
    @Namespace private var animation

    init() {
        _playerState = State(initialValue: Self.makeRestoredPlayerState())
    }

    var body: some View {
        NativeTabView(playerState: playerState)
         
            .task {
                for await _ in Observations({ playerState.player.currentTime }) {
                    if playerState.isPlaying { playerState.persistThrottled() }
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase != .active { playerState.persistNow() }
            }
            .onAppear {
                PlayerSession.wireOffline(playerState) { [network] in network.isOffline }
            }
            .alert(
                "Can't play this surah",
                isPresented: Binding(
                    get: { playerState.playbackFailed },
                    set: { if !$0 { playerState.dismissPlaybackFailure() } }
                )
            ) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(network.isOffline
                     ? "You're offline. Download surahs to listen without a connection."
                     : "Check your internet connection and try again.")
            }
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory(isEnabled: !playerState.isEmpty) {
                PlayerBottom(playerState: playerState)
                    .matchedTransitionSource(id: "miniplayer", in: animation)
                    .onTapGesture {
                        expandMiniPlayer.toggle()
                    }
                    .accessibilityAddTraits(.isButton)
                    .accessibilityHint("Opens the full player")
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
    /// Runs while the launch screen is up, so the first frame already shows the restored mini-player.
    private static func makeRestoredPlayerState() -> PlayerState {
        PlayerSession.make(surahs: PlayerSession.bundledSurahs())
    }
}

#Preview {
    HomeView()
        .environment(NetworkMonitor())
        .preferredColorScheme(.dark)

}
