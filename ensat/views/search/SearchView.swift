//
//  SearchView.swift
//  ensat
//
//  Created by Mazen on 08/08/2026.
//

import SwiftData
import SwiftUI

struct SearchView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    @State private var selected = 0
    @State private var query = ""
    @State private var filtersToDownloaded = false
    @Query private var downloads: [DownloadedTrack]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
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

                        // Nothing saved means nothing to filter to, so no chip.
                        if !downloads.isEmpty {
                            FilterChip(
                                title: "Downloaded",
                                systemImage: "arrow.down.circle",
                                isOn: $filtersToDownloaded
                            )
                            .padding(.top, 12)
                            .transition(.scale(scale: 0.2, anchor: .leading).combined(with: .opacity))
                        }

                        Spacer(minLength: 30)

                        if selected == 1 {

                            ReciterListView(
                                reciterViewModel: reciterViewModel,
                                playerState: playerState,
                                query: query,
                                downloadedOnly: filtersToDownloaded
                            )

                        } else {
                            SurahListVIew(
                                playerState: playerState,
                                query: query,
                                downloadedOnly: filtersToDownloaded
                            )
                        }
                    }
                    .animation(reduceMotion ? nil : .bouncy(duration: 0.45), value: downloads.isEmpty)
                    .padding(16)
                }
            }
            // Removing the last download leaves nothing to filter to.
            .onChange(of: downloads.isEmpty) {
                if downloads.isEmpty { filtersToDownloaded = false }
            }
            .searchable(text: $query)
            .searchFocused($isSearchFocused)
            .task {
                try? await Task.sleep(for: .milliseconds(50))
                isSearchFocused = true
            }
        }
    }
}

#Preview {
    SearchView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
