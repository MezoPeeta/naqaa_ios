import PostHog
import SwiftData
import SwiftUI

/// Heart for the surah currently playing with the selected reciter.
struct FavoriteTrackButton: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var favorites: [FavoriteTrack]
    /// Bumped only when favoriting, so the pop plays on add and not on remove.
    @State private var popCount = 0

    let surahId: Int
    let item: ReciterMoshafItem

    init(surahId: Int, item: ReciterMoshafItem) {
        self.surahId = surahId
        self.item = item
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        _favorites = Query(filter: #Predicate<FavoriteTrack> { $0.key == key })
    }

    var body: some View {
        let isFavorite = !favorites.isEmpty
        Button {
            if !isFavorite { popCount += 1 }
            FavoritesStore(context: modelContext).toggleTrack(surahId: surahId, item: item)
            PostHogSDK.shared.capture(
                isFavorite ? "remove_favorite": "add_favorite",
                properties: ["surah_id": surahId]
            )
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.selectedText : .primary)

                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                .scaleEffect(isFavorite ? 1.15 : 1)
                .animation(.spring(duration: 0.35, bounce: 0.1), value: isFavorite)
                .heartPop(trigger: popCount)

        }
        .sensoryFeedback(.selection, trigger: isFavorite)

        .buttonStyle(.plain)

        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

/// Heart for a reciter row. The list owns the favorites query and passes `isFavorite` in, so
/// rows do not each keep their own SwiftData observation.
struct FavoriteReciterButton: View {
    @Environment(\.modelContext) private var modelContext
    /// Bumped only when favoriting, so the pop plays on add and not on remove.
    @State private var popCount = 0

    let item: ReciterMoshafItem
    let isFavorite: Bool

    var body: some View {
        Button {
            if !isFavorite { popCount += 1 }
            FavoritesStore(context: modelContext).toggleReciter(item)
        } label: {
            Image(systemName: isFavorite ? "heart.fill" : "heart")
                .foregroundStyle(isFavorite ? Color.selectedText : .secondary)
                .contentTransition(.symbolEffect(.replace.magic(fallback: .downUp.byLayer)))
                .scaleEffect(isFavorite ? 1.15 : 1)
                .animation(.spring(duration: 0.35, bounce: 0.1), value: isFavorite)
                .heartPop(trigger: popCount)
        }
        .buttonStyle(.plain)
        .accessibilityLabel(isFavorite ? "Remove from favorites" : "Add to favorites")
    }
}

private extension View {

    func heartPop(trigger: Int) -> some View {
        keyframeAnimator(initialValue: 1.0, trigger: trigger) { content, scale in
            content.scaleEffect(scale)
        } keyframes: { _ in
            KeyframeTrack {
                CubicKeyframe(1.25, duration: 0.12)
                SpringKeyframe(1.0, duration: 0.45, spring: Spring(duration: 0.45, bounce: 0.5))
            }
        }
    }
}

#if DEBUG
private enum PreviewData {
    static let favorited = ReciterMoshafItem.make(
        reciterId: 1, reciterName: "Mishary Alafasy", moshafId: 1, moshafName: "Murattal", server: ""
    )
    static let notFavorited = ReciterMoshafItem.make(
        reciterId: 2, reciterName: "Maher Al Muaiqly", moshafId: 1, moshafName: "Murattal", server: ""
    )

    /// In-memory container with `favorited` already saved as a favorite track and reciter.
    @MainActor
    static func container() -> ModelContainer {
        // swiftlint:disable:next force_try
        let container = try! ModelContainer(
            for: FavoriteTrack.self, FavoriteReciter.self,
            configurations: ModelConfiguration(isStoredInMemoryOnly: true)
        )
        container.mainContext.insert(FavoriteTrack(surahId: 18, item: favorited))
        container.mainContext.insert(FavoriteReciter(item: favorited))
        return container
    }
}

#Preview("Track heart") {
    HStack(spacing: 32) {
        FavoriteTrackButton(surahId: 18, item: PreviewData.favorited)
        FavoriteTrackButton(surahId: 18, item: PreviewData.notFavorited)
    }
    .modelContainer(PreviewData.container())
    .preferredColorScheme(.dark)
    .padding()
}

#Preview("Reciter heart") {
    HStack(spacing: 32) {
        FavoriteReciterButton(item: PreviewData.favorited, isFavorite: true)
        FavoriteReciterButton(item: PreviewData.notFavorited, isFavorite: false)
    }
    .modelContainer(PreviewData.container())
    .preferredColorScheme(.dark)
    .padding()
}
#endif
