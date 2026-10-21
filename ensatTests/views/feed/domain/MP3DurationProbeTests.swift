import Foundation
import Testing
@testable import ensat

struct MP3DurationProbeTests {

    private let id3Size = 1_000
    /// MPEG-1 Layer III, 192 kbps, 48 kHz, stereo, no CRC, no padding.
    private let frameHeader: [UInt8] = [0xFF, 0xFB, 0xB4, 0x00]
    private let audioBytes = 1_206_000
    private var totalBytes: Int64 { Int64(10 + id3Size + audioBytes) }
    private var realDuration: Double { Double(audioBytes) * 8 / 192_000 }

    private func uint32(_ value: UInt32) -> [UInt8] {
        [UInt8(value >> 24), UInt8((value >> 16) & 0xFF), UInt8((value >> 8) & 0xFF), UInt8(value & 0xFF)]
    }

    /// ID3v2 tag, then a frame whose side info is followed by `tag` ("Info"/"Xing") with the given fields.
    private func makePrefix(tag: String?, frames: UInt32 = 0, bytes: UInt32 = 0, flags: UInt32 = 3) -> Data {
        var data = Data([0x49, 0x44, 0x33, 0x03, 0x00, 0x00])
        data.append(contentsOf: [
            UInt8((id3Size >> 21) & 0x7F), UInt8((id3Size >> 14) & 0x7F),
            UInt8((id3Size >> 7) & 0x7F), UInt8(id3Size & 0x7F)
        ])
        data.append(Data(count: id3Size))
        data.append(contentsOf: frameHeader)
        data.append(Data(count: 32)) // side info
        if let tag {
            data.append(Data(tag.utf8))
            data.append(contentsOf: uint32(flags))
            if flags & 1 != 0 { data.append(contentsOf: uint32(frames)) }
            if flags & 2 != 0 { data.append(contentsOf: uint32(bytes)) }
        }
        data.append(Data(count: 512))
        return data
    }

    @Test func bogusInfoHeaderIsCorrectedFromSizeAndBitrate() throws {
        let prefix = makePrefix(tag: "Info", frames: 74_068, bytes: 42_663_744)
        let corrected = try #require(MP3DurationProbe.correctedDuration(prefix: prefix, totalBytes: totalBytes))
        #expect(abs(corrected - realDuration) < 0.01)
    }

    @Test func consistentInfoHeaderIsTrusted() {
        let frames = UInt32(realDuration * 48_000 / 1_152)
        let prefix = makePrefix(tag: "Info", frames: frames, bytes: UInt32(audioBytes))
        #expect(MP3DurationProbe.correctedDuration(prefix: prefix, totalBytes: totalBytes) == nil)
    }

    @Test func wrongFrameCountAloneIsCorrected() {
        // Bytes field matches, frame count doesn't.
        let prefix = makePrefix(tag: "Info", frames: 74_068, bytes: UInt32(audioBytes))
        #expect(MP3DurationProbe.correctedDuration(prefix: prefix, totalBytes: totalBytes) != nil)
    }

    @Test func vbrXingHeaderIsNeverOverridden() {
        let prefix = makePrefix(tag: "Xing", frames: 74_068, bytes: 42_663_744)
        #expect(MP3DurationProbe.correctedDuration(prefix: prefix, totalBytes: totalBytes) == nil)
    }

    @Test func fileWithoutHeaderIsTrusted() {
        #expect(MP3DurationProbe.correctedDuration(prefix: makePrefix(tag: nil), totalBytes: totalBytes) == nil)
    }

    @Test(arguments: [
        (prefix: Data(repeating: 0x41, count: 4_096), total: Int64(5_000)),
        (prefix: Data([0x49, 0x44]), total: Int64(2)),
        (prefix: Data(), total: Int64(0))
    ])
    func garbageAndShortDataAreIgnored(prefix: Data, total: Int64) {
        #expect(MP3DurationProbe.correctedDuration(prefix: prefix, totalBytes: total) == nil)
    }

    @Test func probeReadsLocalFiles() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: "probe-\(UUID().uuidString).mp3")
        defer { try? FileManager.default.removeItem(at: url) }
        var file = makePrefix(tag: "Info", frames: 74_068, bytes: 42_663_744)
        file.append(Data(count: Int(totalBytes) - file.count))
        try file.write(to: url)

        let duration = try #require(await MP3DurationProbe.probe(url: url))

        #expect(abs(duration - realDuration) < 0.01)
    }
}
