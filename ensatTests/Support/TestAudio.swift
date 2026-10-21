import Foundation

/// Minimal files for download tests.
enum TestAudio {
    /// About one second of silent MPEG-1 Layer III (128 kbps, 44.1 kHz, stereo): a run of valid frame headers.
    static func silentMP3(frames: Int = 40) -> Data {
        let header: [UInt8] = [0xFF, 0xFB, 0x90, 0x00]
        let frameLength = 417
        var data = Data()
        for _ in 0..<frames {
            data.append(contentsOf: header)
            data.append(Data(count: frameLength - header.count))
        }
        return data
    }

    /// Bytes that are not audio at all.
    static func garbage(count: Int = 2_048) -> Data {
        Data((0..<count).map { UInt8(truncatingIfNeeded: $0 &* 31 &+ 7) })
    }

    /// Stand-in for AVFoundation's playability check: true for `silentMP3()` data, false for `garbage()`.
    /// Keeps the download tests about our logic, not about what the simulator's decoder accepts.
    @Sendable static func looksLikeMP3(_ url: URL) async -> Bool {
        (try? Data(contentsOf: url).first) == 0xFF
    }
}
