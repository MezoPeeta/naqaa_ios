//
//  NativeTabView.swift
//  ensat
//
//  Created by Mazen on 30/08/2026.
//

import SwiftData
import SwiftUI

struct NativeTabView: View {
    @Environment(\.modelContext) private var modelContext
    @State private var reciterViewModel = ReciterViewModel()
    let playerState: PlayerState
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
                FavoritesView(playerState: playerState)
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
        // Load the catalog at launch (not only when the picker opens) so the player's reciter
        // gets its localized names right away. `load()` is a no-op once it has run.
        .task { await reciterViewModel.load() }
        .onChange(of: reciterViewModel.state, initial: true) { _, state in
            if case .loaded(let catalog) = state {
                playerState.refreshSelectedReciter(from: catalog)
                FavoritesStore(context: modelContext).refreshNames(from: catalog)
            }
        }
        .tint(.selectedText)
        .tabViewSearchActivation(.searchTabSelection)

    }
}

#Preview {
    NativeTabView(playerState: PlayerState())
        .preferredColorScheme(.dark)

}
