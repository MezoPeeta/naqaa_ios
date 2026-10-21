import PostHog
import SwiftData
import SwiftUI

/// Heart that favorites the reciter/moshaf currently selected in the player.
struct CurrentReciterFavoriteButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteReciter]
    /// Bumped only when favoriting, so the pop plays on add and not on remove.
    @State private var popCount = 0

    let item: ReciterMoshafItem

    init(item: ReciterMoshafItem) {
        self.item = item
        let key = item.id
        _favorites = Query(filter: #Predicate<FavoriteReciter> { $0.key == key })
    }

    var body: some View {
        let isFavorite = !favorites.isEmpty
        Button {
            if !isFavorite { popCount += 1 }
            FavoritesStore(context: modelContext).toggleReciter(item)
            PostHogSDK.shared.capture(
                isFavorite ? "remove_favorite_reciter" : "add_favorite_reciter",
                properties: ["reciter_id": item.reciter.id]
            )
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                .symbolEffect(.bounce, value: popCount)
                .frame(maxWidth: .infinity, maxHeight: .infinity)
                .contentShape(Circle())

        }
        .sensoryFeedback(.selection, trigger: isFavorite)
        
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove reciter from favorites" : "Add reciter to favorites")
    }
}
