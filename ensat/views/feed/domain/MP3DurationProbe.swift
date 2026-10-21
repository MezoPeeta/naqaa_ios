import Foundation

/// Some MP3s carry an `Info` (CBR) header copied from a much larger master, so AVPlayer reports a
/// duration far from the file's real length. This reads the first bytes of a file and, only when the
/// header disagrees with the file size, returns the duration computed from size and bitrate.
nonisolated enum MP3DurationProbe {
    static let prefixLength = 65_536
    /// Header `bytes` field may differ from the real size by this much (ID3v1 tags, padding).
    private static let byteTolerance = 0.02
    private static let durationTolerance = 0.05
    private static let maxSyncSearch = 8_192

    /// The corrected duration in seconds, or nil when AVPlayer's own value can be trusted
    /// (no header, a consistent header, a VBR header, or data that can't be parsed).
    static func correctedDuration(prefix: Data, totalBytes: Int64) -> Double? {
        let bytes = [UInt8](prefix)
        guard totalBytes > 0, let frame = firstFrame(in: bytes) else { return nil }
        let audioBytes = Double(totalBytes - Int64(frame.offset))
        guard audioBytes > 0, frame.bitrate > 0 else { return nil }

        // Only `Info` marks a constant-bitrate file, where size / bitrate is a reliable length.
        let tagStart = frame.offset + 4 + frame.sideInfoLength
        guard tag(at: tagStart, in: bytes) == "Info" else { return nil }

        let fields = xingFields(at: tagStart, in: bytes)
        let estimate = audioBytes * 8 / Double(frame.bitrate)
        let bytesDisagree = fields.bytes.map { abs(Double($0) - audioBytes) / audioBytes > byteTolerance } ?? false
        let framesDisagree = fields.frames.map {
            let headerDuration = Double($0) * Double(frame.samplesPerFrame) / Double(frame.sampleRate)
            return abs(headerDuration - estimate) / estimate > durationTolerance
        } ?? false

        return bytesDisagree || framesDisagree ? estimate : nil
    }

    /// Reads the start of a local or remote file and runs `correctedDuration` on it.
    @concurrent
    static func probe(url: URL, session: URLSession = .shared) async -> Double? {
        if let cached = await MP3DurationCache.shared.value(for: url) { return cached.duration }
        let result = url.isFileURL ? probeFile(url) : await probeRemote(url, session: session)
        await MP3DurationCache.shared.store(result, for: url)
        return result
    }

    // MARK: Fetching

    private static func probeFile(_ url: URL) -> Double? {
        guard let handle = try? FileHandle(forReadingFrom: url) else { return nil }
        defer { try? handle.close() }
        let size = (try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize).flatMap { $0 }
        guard let size, let prefix = try? handle.read(upToCount: prefixLength) else { return nil }
        return correctedDuration(prefix: prefix, totalBytes: Int64(size))
    }

    private static func probeRemote(_ url: URL, session: URLSession) async -> Double? {
        var request = URLRequest(url: url)
        request.setValue("bytes=0-\(prefixLength - 1)", forHTTPHeaderField: "Range")
        guard let (stream, response) = try? await session.bytes(for: request),
              let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode)
        else { return nil }

        // A server that ignores Range would send the whole file; stop after the prefix either way.
        var prefix = Data()
        do {
            for try await byte in stream {
                prefix.append(byte)
                if prefix.count >= prefixLength { break }
            }
        } catch {
            return nil
        }
        guard let total = totalBytes(from: http) else { return nil }
        return correctedDuration(prefix: prefix, totalBytes: total)
    }

    private static func totalBytes(from response: HTTPURLResponse) -> Int64? {
        if let range = response.value(forHTTPHeaderField: "Content-Range"),
           let total = range.split(separator: "/").last, let value = Int64(total) {
            return value
        }
        return response.expectedContentLength > 0 ? response.expectedContentLength : nil
    }

    // MARK: Parsing

    private struct Frame {
        let offset: Int
        let bitrate: Int
        let sampleRate: Int
        let samplesPerFrame: Int
        let sideInfoLength: Int
    }

    private static func firstFrame(in bytes: [UInt8]) -> Frame? {
        var offset = id3v2Length(in: bytes)
        let limit = min(bytes.count - 4, offset + maxSyncSearch)
        while offset <= limit {
            if let frame = frame(at: offset, in: bytes) { return frame }
            offset += 1
        }
        return nil
    }

    private static func id3v2Length(in bytes: [UInt8]) -> Int {
        guard bytes.count >= 10, bytes[0] == 0x49, bytes[1] == 0x44, bytes[2] == 0x33 else { return 0 }
        let size = Int(bytes[6] & 0x7F) << 21 | Int(bytes[7] & 0x7F) << 14
            | Int(bytes[8] & 0x7F) << 7 | Int(bytes[9] & 0x7F)
        let footer = bytes[5] & 0x10 != 0 ? 10 : 0
        return 10 + size + footer
    }

    /// Parses a Layer III frame header at `offset`; nil when it isn't one.
    private static func frame(at offset: Int, in bytes: [UInt8]) -> Frame? {
        guard offset + 4 <= bytes.count, bytes[offset] == 0xFF, bytes[offset + 1] & 0xE0 == 0xE0 else { return nil }
        let header = UInt32(bytes[offset]) << 24 | UInt32(bytes[offset + 1]) << 16
            | UInt32(bytes[offset + 2]) << 8 | UInt32(bytes[offset + 3])
        let version = Int((header >> 19) & 3)      // 0: 2.5, 2: 2, 3: 1, 1: reserved
        let layer = Int((header >> 17) & 3)        // 1: Layer III
        let bitrateIndex = Int((header >> 12) & 15)
        let rateIndex = Int((header >> 10) & 3)
        let isMono = (header >> 6) & 3 == 3
        guard version != 1, layer == 1, (1..<15).contains(bitrateIndex), rateIndex != 3 else { return nil }

        let isMPEG1 = version == 3
        let bitrates = isMPEG1
            ? [0, 32, 40, 48, 56, 64, 80, 96, 112, 128, 160, 192, 224, 256, 320]
            : [0, 8, 16, 24, 32, 40, 48, 56, 64, 80, 96, 112, 128, 144, 160]
        let baseRates = [44_100, 48_000, 32_000]
        let divisor = version == 3 ? 1 : (version == 2 ? 2 : 4)
        let hasCRC = (header >> 16) & 1 == 0
        let sideInfo = isMPEG1 ? (isMono ? 17 : 32) : (isMono ? 9 : 17)
        return Frame(
            offset: offset,
            bitrate: bitrates[bitrateIndex] * 1_000,
            sampleRate: baseRates[rateIndex] / divisor,
            samplesPerFrame: isMPEG1 ? 1_152 : 576,
            sideInfoLength: sideInfo + (hasCRC ? 2 : 0)
        )
    }

    private static func tag(at index: Int, in bytes: [UInt8]) -> String? {
        guard index + 4 <= bytes.count else { return nil }
        let name = String(decoding: bytes[index..<index + 4], as: UTF8.self)
        return name == "Xing" || name == "Info" ? name : nil
    }

    private static func xingFields(at index: Int, in bytes: [UInt8]) -> (frames: UInt32?, bytes: UInt32?) {
        guard index + 8 <= bytes.count else { return (nil, nil) }
        let flags = bigEndian(bytes, at: index + 4) ?? 0
        var cursor = index + 8
        var frames: UInt32?
        var size: UInt32?
        if flags & 1 != 0 { frames = bigEndian(bytes, at: cursor); cursor += 4 }
        if flags & 2 != 0 { size = bigEndian(bytes, at: cursor) }
        return (frames, size)
    }

    private static func bigEndian(_ bytes: [UInt8], at index: Int) -> UInt32? {
        guard index + 4 <= bytes.count else { return nil }
        return UInt32(bytes[index]) << 24 | UInt32(bytes[index + 1]) << 16
            | UInt32(bytes[index + 2]) << 8 | UInt32(bytes[index + 3])
    }
}

/// Remembers probe results (including "trust AVPlayer") so each file is probed once per launch.
private actor MP3DurationCache {
    static let shared = MP3DurationCache()
    struct Entry { let duration: Double? }
    private var entries: [URL: Entry] = [:]

    func value(for url: URL) -> Entry? { entries[url] }
    func store(_ duration: Double?, for url: URL) { entries[url] = Entry(duration: duration) }
}
