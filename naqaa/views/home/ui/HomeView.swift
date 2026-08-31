import SwiftUI

struct HomeView: View {
    @State private var playerState = PlayerState()
    @State private var expandMiniPlayer = false
    @Namespace private var animation
    var body: some View {
        NativeTabView(playerState: playerState)
            .tabBarMinimizeBehavior(.onScrollDown)
            .tabViewBottomAccessory(isEnabled: !playerState.isEmpty) {
                PlayerBottom(playerState: playerState)
                    .matchedTransitionSource(id: "miniplayer", in: animation)
                    .onTapGesture {
                        expandMiniPlayer.toggle()
                    }
            }
            .fullScreenCover(isPresented: $expandMiniPlayer){
                ScrollView {
                }
                .safeAreaInset(edge: .top, spacing: 0){
                    VStack(spacing: 10) {
                        Capsule()
                            .fill(.primary.secondary)
                            .frame(width: 35, height: 3)
                        PlayerView()
                            .padding(.horizontal, 15)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .navigationTransition(.zoom(sourceID: "miniplayer", in: animation))
                .background(.homeBackground)
                .presentationBackground(.clear)
                
            }
        
    }
}

#Preview {
    HomeView()
}
