import SwiftUI

struct FeedView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                ZStack(alignment: .top) {
                    Color.background.ignoresSafeArea()
                    ScrollView {
                        VStack(alignment: .leading) {
                            ReciterContainer(
                                reciterViewModel: reciterViewModel,
                                playerState: playerState,
                                topSafeInset: proxy.safeAreaInsets.top
                            )

                            VStack(alignment: .leading){
                                Text("Surahs -114-")
                                    .foregroundStyle(.gray)
                                    .font(.default)
                                    .bold()
                                Spacer(minLength: 16)
                                SurahListVIew(playerState: playerState)
                                   
                            }
                            .padding(20)

                        }
                    }
                    .ignoresSafeArea(edges: .top)
                }

            }
        }

    }
}

#Preview {
    FeedView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
