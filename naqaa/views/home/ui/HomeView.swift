import SwiftUI

struct HomeView: View {
    @State private var playerState = PlayerState()

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {

                VStack(spacing: 0) {
                    FeedView(playerState: playerState)
                        .clipShape(
                            UnevenRoundedRectangle(
                                topLeadingRadius: 0,
                                bottomLeadingRadius: 48,
                                bottomTrailingRadius: 48,
                                topTrailingRadius: 0
                            )
                        )
                        .ignoresSafeArea()

                }
                .animation(.spring(response: 0.35, dampingFraction: 0.85), value: playerState.selectedSurah)
            }
            Tab("Favorites", systemImage: "heart") {
                FavoritesView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
            Tab(role: .search) {
                SearchView(playerState: playerState)
            }
        }
        .tabViewBottomAccessory {
            PlayerBottom(playerState: playerState)
                .transition(.move(edge: .bottom))

        }
        .tint(.selectedText)


    }
}

#Preview {
    HomeView()
}
