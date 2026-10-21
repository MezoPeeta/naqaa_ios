import Foundation
import Testing
@testable import ensat

@Suite(.tags(.offline))
final class DownloadFileStoreTests {
    private let directory: URL
    private let files: DownloadFileStore

    init() throws {
        directory = try TestFixtures.temporaryDirectory("download-files")
        files = DownloadFileStore(directory: directory)
    }

    deinit {
        try? FileManager.default.removeItem(at: directory)
    }

    private func write(_ relativePath: String, bytes: Int = 4) throws {
        let url = directory.appending(path: relativePath)
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(count: bytes).write(to: url)
    }

    @Test(.tags(.edgeCase))
    func aMissingFileDoesNotExistAndHasNoBytes() {
        #expect(files.exists(surahId: 1, itemId: "1-2") == false)
        #expect(files.byteCount(surahId: 1, itemId: "1-2") == 0)
    }

    @Test func movingCreatesMissingFoldersAndConsumesTheTemporaryFile() throws {
        let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        try Data(count: 12).write(to: temporary)

        try files.move(from: temporary, surahId: 1, itemId: "1-2")

        #expect(files.exists(surahId: 1, itemId: "1-2"))
        #expect(files.byteCount(surahId: 1, itemId: "1-2") == 12)
        #expect(FileManager.default.fileExists(atPath: temporary.path) == false)
    }

    @Test func movingReplacesAnExistingFile() throws {
        for size in [5, 9] {
            let temporary = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
            try Data(count: size).write(to: temporary)
            try files.move(from: temporary, surahId: 18, itemId: "1-2")
        }
        #expect(files.byteCount(surahId: 18, itemId: "1-2") == 9)
    }

    @Test(.tags(.edgeCase))
    func movingAFileThatIsGoneThrows() {
        let missing = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString)
        #expect(throws: (any Error).self) {
            try files.move(from: missing, surahId: 1, itemId: "1-2")
        }
        #expect(files.exists(surahId: 1, itemId: "1-2") == false)
    }

    @Test func deleteRemovesOnlyThatSurah() throws {
        try write("1-2/001.mp3")
        try write("1-2/002.mp3")

        files.delete(surahId: 1, itemId: "1-2")

        #expect(files.exists(surahId: 1, itemId: "1-2") == false)
        #expect(files.exists(surahId: 2, itemId: "1-2"))
    }

    @Test func deleteAllRemovesEveryFile() async throws {
        try write("1-2/001.mp3")
        try write("9-1/114.mp3")

        files.deleteAll()

        #expect(await files.allKeys().isEmpty)
    }

    @Test func allKeysListsEveryDownloadedSurah() async throws {
        try write("1-2/001.mp3")
        try write("1-2/018.mp3")
        try write("9-1/114.mp3")

        #expect(await files.allKeys() == ["1-1-2", "18-1-2", "114-9-1"])
    }

    @Test(.tags(.edgeCase))
    func allKeysIgnoresFilesThatAreNotSurahMP3s() async throws {
        try write("1-2/001.mp3")
        try write("1-2/notes.txt")
        try write("1-2/abc.mp3")
        try write("1-2/001.mp3.download")

        #expect(await files.allKeys() == ["1-1-2"])
    }

    @Test(.tags(.edgeCase))
    func allKeysIsEmptyWhenTheDirectoryDoesNotExist() async {
        let missing = DownloadFileStore(directory: directory.appending(path: "never-created"))
        #expect(await missing.allKeys().isEmpty)
    }
}
