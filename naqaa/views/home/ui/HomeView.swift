import SwiftUI

struct HomeView: View {
    @State private var playerState = PlayerState()
    @State private var reciterViewModel = ReciterViewModel()
    
    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") {
                
                VStack(spacing: 0) {
                    FeedView(
                        reciterViewModel: reciterViewModel,
                        playerState: playerState
                    )
                    
                }
                
            }
            Tab("Favorites", systemImage: "heart") {
                FavoritesView()
            }
            Tab("Settings", systemImage: "gearshape.fill") {
                SettingsView()
            }
            Tab(role: .search) {
                SearchView(
                    reciterViewModel: reciterViewModel,
                    playerState: playerState
                )
            }
        }
        .tabViewBottomAccessory {
            PlayerBottom(playerState: playerState)
                .transition(.move(edge: .bottom))
            
        }
        .tabBarMinimizeBehavior(.onScrollDown)
        
        .tint(.selectedText)
        
    }
}

#Preview {
    HomeView()
}
