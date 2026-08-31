//
//  NativeTabView.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import SwiftUI

struct NativeTabView: View {
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
        .tint(.selectedText)

    }
}

#Preview {
    NativeTabView(playerState: PlayerState())
}
