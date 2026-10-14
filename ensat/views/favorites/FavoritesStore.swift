import Foundation
import SwiftData

/// Keeps SwiftData out of the views.
@MainActor
struct FavoritesStore {
    let context: ModelContext

    // MARK: Favorite tracks

    func isFavorite(surahId: Int, item: ReciterMoshafItem) -> Bool {
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        let descriptor = FetchDescriptor<FavoriteTrack>(predicate: #Predicate { $0.key == key })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func toggleTrack(surahId: Int, item: ReciterMoshafItem) {
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        let descriptor = FetchDescriptor<FavoriteTrack>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            context.insert(FavoriteTrack(surahId: surahId, item: item))
        }
        try? context.save()
    }

    // MARK: Favorite reciters

    func isFavorite(reciter item: ReciterMoshafItem) -> Bool {
        let key = item.id
        let descriptor = FetchDescriptor<FavoriteReciter>(predicate: #Predicate { $0.key == key })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func toggleReciter(_ item: ReciterMoshafItem) {
        let key = item.id
        let descriptor = FetchDescriptor<FavoriteReciter>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            context.delete(existing)
        } else {
            context.insert(FavoriteReciter(item: item))
        }
        try? context.save()
    }

    // MARK: Localization

    /// Favorites keep a name snapshot from when they were saved. Rewrites those names from a freshly
    /// loaded catalog so they follow its language. Saves only if something changed.
    func refreshNames(from catalog: [ReciterMoshafItem]) {
        let byId = Dictionary(catalog.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        var changed = false

        for favorite in (try? context.fetch(FetchDescriptor<FavoriteReciter>())) ?? [] {
            guard let item = byId["\(favorite.reciterId)-\(favorite.moshafId)"],
                  favorite.reciterName != item.reciter.name || favorite.moshafName != item.moshaf.name
            else { continue }
            favorite.reciterName = item.reciter.name
            favorite.moshafName = item.moshaf.name
            changed = true
        }
        for track in (try? context.fetch(FetchDescriptor<FavoriteTrack>())) ?? [] {
            guard let item = byId["\(track.reciterId)-\(track.moshafId)"],
                  track.reciterName != item.reciter.name || track.moshafName != item.moshaf.name
            else { continue }
            track.reciterName = item.reciter.name
            track.moshafName = item.moshaf.name
            changed = true
        }
        if changed { try? context.save() }
    }
}
