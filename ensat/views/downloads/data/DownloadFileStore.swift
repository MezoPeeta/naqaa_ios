import Foundation

/// Downloaded surah audio on disk. Paths are derived from ids, never persisted.
nonisolated struct DownloadFileStore: Sendable {
    let directory: URL

    init(directory: URL = Self.defaultDirectory) {
        self.directory = directory
    }

    static var defaultDirectory: URL {
        URL.applicationSupportDirectory.appending(path: "Downloads", directoryHint: .isDirectory)
    }

    func fileURL(surahId: Int, itemId: String) -> URL {
        directory
            .appending(path: itemId, directoryHint: .isDirectory)
            .appending(path: SurahAudioURL.fileName(surahId: surahId))
    }

    func exists(surahId: Int, itemId: String) -> Bool {
        FileManager.default.fileExists(atPath: fileURL(surahId: surahId, itemId: itemId).path)
    }

    func byteCount(surahId: Int, itemId: String) -> Int64 {
        let url = fileURL(surahId: surahId, itemId: itemId)
        let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize
        return Int64(size ?? 0)
    }

    /// Moves a finished download into place, replacing any previous file.
    func move(from temporary: URL, surahId: Int, itemId: String) throws {
        let destination = fileURL(surahId: surahId, itemId: itemId)
        let folder = destination.deletingLastPathComponent()
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        markExcludedFromBackup()
        if FileManager.default.fileExists(atPath: destination.path) {
            try FileManager.default.removeItem(at: destination)
        }
        try FileManager.default.moveItem(at: temporary, to: destination)
    }

    func delete(surahId: Int, itemId: String) {
        try? FileManager.default.removeItem(at: fileURL(surahId: surahId, itemId: itemId))
    }

    func deleteAll() {
        try? FileManager.default.removeItem(at: directory)
    }

    /// Every "<surahId>-<itemId>" key that has a file on disk, for reconciling with the index.
    /// Scans the directory off the caller's actor so launch never waits on disk.
    @concurrent
    func allKeys() async -> Set<String> {
        let manager = FileManager.default
        guard let folders = try? manager.contentsOfDirectory(
            at: directory, includingPropertiesForKeys: nil
        ) else { return [] }
        var keys = Set<String>()
        for folder in folders {
            let files = (try? manager.contentsOfDirectory(at: folder, includingPropertiesForKeys: nil)) ?? []
            for file in files where file.pathExtension == "mp3" {
                guard let surahId = Int(file.deletingPathExtension().lastPathComponent) else { continue }
                keys.insert("\(surahId)-\(folder.lastPathComponent)")
            }
        }
        return keys
    }

    private func markExcludedFromBackup() {
        var url = directory
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try? url.setResourceValues(values)
    }
}
