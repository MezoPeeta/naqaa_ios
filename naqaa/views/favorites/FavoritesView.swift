//
//  FavoritesView.swift
//  naqaa
//
//  Created by Mazen on 08/08/2026.
//

import SwiftUI

struct FavoritesView: View {
    var body: some View {
        NavigationStack{
            ZStack{
                Color.favoritesBackground.ignoresSafeArea()
                
                ContentUnavailableView("No favorites now", systemImage: "heart.fill")
            }
            .navigationTitle("Favorites")
        }
      
    }
}

#Preview {
    FavoritesView()
}
