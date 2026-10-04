//
//  SearchView.swift
//  naqaa
//
//  Created by Mazen on 08/08/2026.
//

import SwiftUI

struct SearchView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    @State private var selected = 0
    @State private var query = ""
    @FocusState private var isSearchFocused: Bool
    var body: some View {
        NavigationStack {
            ZStack {
                Color.homeBackground.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading) {
                        Picker("Search", selection: $selected) {
                            Text("Surahs").tag(0)
                            Text("Reciters").tag(1)
                        }
                        .pickerStyle(.segmented)
                        .controlSize(.large)

                        Spacer(minLength: 30)

                        if selected == 1 {

                            ReciterListView(
                                reciterViewModel: reciterViewModel,
                                playerState: playerState,
                                query: query,
                                hidesNavigationBar: true
                            )

                        } else {
                            SurahListVIew(
                                playerState: playerState,
                                query: query
                            )
                        }
                    }
                    .padding(16)
                }
            }

        }

        .searchable(text: $query)
        .searchFocused($isSearchFocused)
        .task {
            try? await Task.sleep(for: .milliseconds(50))
            isSearchFocused = true
        }

    }
}

#Preview {
    SearchView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
