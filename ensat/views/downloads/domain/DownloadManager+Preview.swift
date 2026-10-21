#if DEBUG
import SwiftData

extension DownloadManager {
    /// In-memory manager for previews.
    @MainActor static let preview: DownloadManager = {
        // swiftlint:disable:next force_try
        DownloadManager(container: try! ModelContainer.preview)
    }()
}

extension ModelContainer {
    /// In-memory container with every model, for previews.
    @MainActor static var preview: ModelContainer {
        get throws {
            try ModelContainer(
                for: FavoriteReciter.self, FavoriteTrack.self, DownloadedTrack.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }
}
#endif
