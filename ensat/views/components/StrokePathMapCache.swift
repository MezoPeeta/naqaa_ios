//
//  StrokePathMapCache.swift
//  ensat
//

import SwiftUI

/// Shares order maps between `AnimatedText` instances. The title draws the same glyph in three
/// layers, so without this each track change would rasterize and order it three times.
@MainActor
final class StrokePathMapCache {
    static let shared = StrokePathMapCache()

    struct Request: Hashable {
        let text: String
        let font: Font?
        let startsOnRight: Bool
        let penSlant: Double
    }

    /// Enough for the text on screen and the one about to replace it.
    private static let capacity = 4

    private var maps: [Request: Image] = [:]
    /// Least recently used first.
    private var recency: [Request] = []
    private var inFlight: [Request: Task<Image?, Never>] = [:]

    func image(for request: Request) async -> Image? {
        if let cached = maps[request] {
            touch(request)
            return cached
        }
        if let running = inFlight[request] {
            return await running.value
        }

        let task = Task {
            await StrokePathMap.makeImage(
                text: request.text,
                font: request.font,
                startsOnRight: request.startsOnRight,
                penSlant: request.penSlant
            )
        }
        inFlight[request] = task
        let image = await task.value
        inFlight[request] = nil
        if let image { store(image, for: request) }
        return image
    }

    private func store(_ image: Image, for request: Request) {
        maps[request] = image
        touch(request)
        while recency.count > Self.capacity {
            maps[recency.removeFirst()] = nil
        }
    }

    private func touch(_ request: Request) {
        recency.removeAll { $0 == request }
        recency.append(request)
    }
}
