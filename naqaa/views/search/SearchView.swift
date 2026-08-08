//
//  SearchView.swift
//  naqaa
//
//  Created by Mazen on 08/08/2026.
//

import SwiftUI

struct SearchView: View {
    let playerState: PlayerState
    @State private var query = ""
    @State private var selected = 0
    var body: some View {
        NavigationStack{
            ScrollView{
                VStack(alignment:.leading){
                    Picker("Search", selection: $selected) {
                        Text("Surahs").tag(0)
                        Text("Reciters").tag(1)
                    }
                    .pickerStyle(.segmented)
                    Spacer(minLength: 30)
                    
                    SurahListVIew(playerState: playerState)
                }
                .padding(16)
            }
        }
       
        .searchable(text: $query)
        
        
        
        
        
    }
}

#Preview {
    SearchView(playerState: PlayerState())
}
