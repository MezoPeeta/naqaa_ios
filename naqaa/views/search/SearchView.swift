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
    var body: some View {
        NavigationStack{
            ZStack{
                Color.background.ignoresSafeArea()
                ScrollView{
                    VStack(alignment:.leading){
                        Picker("Search", selection: $selected) {
                            Text("Surahs").tag(0)
                            Text("Reciters").tag(1)
                        }
                        .pickerStyle(.segmented)
                        Spacer(minLength: 30)
                        
                        if selected == 1 {
                            
                            ReciterListView(
                                reciterViewModel: reciterViewModel,
                                playerState: playerState,
                                query: query
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

    }
}

#Preview {
    SearchView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
