import Foundation
import SwiftData

/// Keeps SwiftData out of the views.
@MainActor
struct DownloadsStore {
    let context: ModelContext
    let files: DownloadFileStore

    init(context: ModelContext, files: DownloadFileStore = DownloadFileStore()) {
        self.context = context
        self.files = files
    }

    func isDownloaded(surahId: Int, item: ReciterMoshafItem) -> Bool {
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        let descriptor = FetchDescriptor<DownloadedTrack>(predicate: #Predicate { $0.key == key })
        return ((try? context.fetchCount(descriptor)) ?? 0) > 0
    }

    func add(surahId: Int, item: ReciterMoshafItem, byteCount: Int64) {
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        let descriptor = FetchDescriptor<DownloadedTrack>(predicate: #Predicate { $0.key == key })
        if let existing = try? context.fetch(descriptor).first {
            existing.byteCount = byteCount
        } else {
            context.insert(DownloadedTrack(surahId: surahId, item: item, byteCount: byteCount))
        }
        try? context.save()
    }

    func remove(surahId: Int, item: ReciterMoshafItem) {
        files.delete(surahId: surahId, itemId: item.id)
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        let descriptor = FetchDescriptor<DownloadedTrack>(predicate: #Predicate { $0.key == key })
        for track in (try? context.fetch(descriptor)) ?? [] {
            context.delete(track)
        }
        try? context.save()
    }

    /// Drops only the index row (the file is already gone).
    func removeIndex(surahId: Int, itemId: String) {
        let key = FavoriteTrack.key(surahId: surahId, itemId: itemId)
        let descriptor = FetchDescriptor<DownloadedTrack>(predicate: #Predicate { $0.key == key })
        for track in (try? context.fetch(descriptor)) ?? [] {
            context.delete(track)
        }
        try? context.save()
    }

    func removeAll() {
        files.deleteAll()
        try? context.delete(model: DownloadedTrack.self)
        try? context.save()
    }

    func totalBytes() -> Int64 {
        let tracks = (try? context.fetch(FetchDescriptor<DownloadedTrack>())) ?? []
        return tracks.reduce(0) { $0 + $1.byteCount }
    }

    /// Drops index rows whose file is gone and deletes files with no index row.
    /// `inFlight` keys are skipped: their file may exist before its index row is written.
    func reconcile(onDisk: Set<String>, inFlight: Set<String>) {
        let tracks = (try? context.fetch(FetchDescriptor<DownloadedTrack>())) ?? []
        var indexed = Set<String>()
        var changed = false
        for track in tracks {
            if onDisk.contains(track.key) {
                indexed.insert(track.key)
            } else if !inFlight.contains(track.key) {
                context.delete(track)
                changed = true
            }
        }
        for key in onDisk.subtracting(indexed).subtracting(inFlight) {
            let parts = key.split(separator: "-", maxSplits: 1).map(String.init)
            guard parts.count == 2, let surahId = Int(parts[0]) else { continue }
            files.delete(surahId: surahId, itemId: parts[1])
        }
        if changed { try? context.save() }
    }
}
