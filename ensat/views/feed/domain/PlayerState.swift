import Foundation
import Observation
import PostHog

@Observable
@MainActor
final class PlayerState {
    /// Length of the visual hand-off that runs while a track is about to finish.
    static let exitTransitionWindow: Double = 3
    /// How long before the end of a track the title starts erasing.
    static let titleSweepWindow: Double = 5

    var selectedSurah: Surah?
    var isEmpty: Bool { selectedSurah == nil }
    var selectedReciter: ReciterMoshafItem = .defaultItem
    var surahs: [Surah] = []

    let player: any AudioPlaying

    /// Set by the app: whether the device is offline, and whether a track is saved on disk.
    /// While offline, next/previous skip tracks that can't be played. Defaults keep everything playable.
    var isOffline: () -> Bool = { false }
    var isAvailableOffline: (Surah, ReciterMoshafItem) -> Bool = { _, _ in true }

    /// True after a track failed to start (e.g. streaming without a connection).
    var playbackFailed: Bool { player.didFailToPlay }
    func dismissPlaybackFailure() { player.clearPlaybackFailure() }

    /// Called with the current track and playhead whenever playback state should be persisted.
    var onPersist: ((_ surah: Surah, _ reciter: ReciterMoshafItem, _ time: Double, _ duration: Double) -> Void)?
    private var lastPersistedAt: Date = .distantPast
    private static let persistInterval: TimeInterval = 5

    var isPlaying: Bool { player.isPlaying }
    var isBuffering: Bool { player.isBuffering }
    var progress: Double {
        guard player.duration > 0 else { return 0 }
        return min(max(player.currentTime / player.duration, 0), 1)
    }

    /// Ramps from `0` to `1` across the final `exitTransitionWindow` seconds of the current
    /// track, so the player can shrink and blur out. Falls back to `0` as soon as the next
    /// queue item starts playing.
    var exitTransitionAmount: Double {
        amountThroughEnd(window: Self.exitTransitionWindow)
    }

    /// `true` once the current track is within `titleSweepWindow` seconds of its end, so the
    /// title can start erasing. `false` when no track follows, since there is nothing to
    /// reveal in its place.
    var shouldSweepTitle: Bool {
        titleSweepAmount(atPlayhead: player.currentTime) > 0
    }

    /// Ramps from `0` to `1` across the final `titleSweepWindow` seconds of the current track
    /// for the given playhead, so the title is fully erased exactly when the track ends. Takes
    /// the playhead as a parameter so callers can pass an interpolated value between the
    /// player's coarse time updates.
    func titleSweepAmount(atPlayhead playhead: Double) -> Double {
        guard canPlayNext else { return 0 }
        return amountThroughEnd(window: Self.titleSweepWindow, playhead: playhead)
    }

    private func amountThroughEnd(window: Double, playhead: Double? = nil) -> Double {
        let duration = player.duration
        guard duration > 0 else { return 0 }
        let remaining = duration - (playhead ?? player.currentTime)
        guard remaining < window else { return 0 }
        return min(max(1 - remaining / window, 0), 1)
    }

    private var queue: SurahQueue { SurahQueue(surahs: surahs) }

    /// When set (e.g. by Favorites "Play"), next/previous walk this list instead of all surahs.
    private(set) var customQueue: [QueueEntry]?

    private var nextEntry: QueueEntry? {
        if let customQueue {
            return EntryQueue(entries: customQueue).next(after: selectedSurah, reciter: selectedReciter)
        }
        return queue.next(after: selectedSurah).map { QueueEntry(surah: $0, reciter: selectedReciter) }
    }

    private var previousEntry: QueueEntry? {
        if let customQueue {
            return EntryQueue(entries: customQueue).previous(before: selectedSurah, reciter: selectedReciter)
        }
        return queue.previous(before: selectedSurah).map { QueueEntry(surah: $0, reciter: selectedReciter) }
    }

    private func entry(after current: QueueEntry) -> QueueEntry? {
        if let customQueue {
            return EntryQueue(entries: customQueue).next(after: current.surah, reciter: current.reciter)
        }
        return queue.next(after: current.surah).map { QueueEntry(surah: $0, reciter: current.reciter) }
    }

    private func entry(before current: QueueEntry) -> QueueEntry? {
        if let customQueue {
            return EntryQueue(entries: customQueue).previous(before: current.surah, reciter: current.reciter)
        }
        return queue.previous(before: current.surah).map { QueueEntry(surah: $0, reciter: current.reciter) }
    }

    /// Walks from `first` in one direction, skipping tracks that can't play while offline.
    private func playableEntry(from step: (QueueEntry) -> QueueEntry?, first: QueueEntry?) -> QueueEntry? {
        var candidate = first
        while let entry = candidate {
            if !isOffline() || isAvailableOffline(entry.surah, entry.reciter) { return entry }
            candidate = step(entry)
        }
        return nil
    }

    var canPlayNext: Bool { nextEntry != nil }
    var canPlayPrevious: Bool { previousEntry != nil }

    init(player: (any AudioPlaying)? = nil) {
        let resolved: any AudioPlaying = player ?? AudioPlayerManager()
        self.player = resolved
        resolved.onTrackEnded = { [weak self] in self?.playNext() }
        resolved.onNextTrack = { [weak self] in self?.playNext() }
        resolved.onPreviousTrack = { [weak self] in self?.playPrevious() }
    }

    /// Plays a single surah and returns navigation to the full surah list.
    func play(_ surah: Surah) {
        customQueue = nil
        startPlayback(surah)
    }

    /// Plays `queue` starting at `index`; next/previous and track-end follow the queue.
    func play(queue: [QueueEntry], startAt index: Int = 0) {
        guard queue.indices.contains(index) else { return }
        customQueue = queue
        selectedReciter = queue[index].reciter
        startPlayback(queue[index].surah)
    }

    private func startPlayback(_ surah: Surah) {
        selectedSurah = surah
        player.play(surah: surah, reciter: selectedReciter)

        persistNow()
    }

    /// Restores a previously saved track paused at its saved position.
    /// A playhead within the exit window of the end restarts the track from 0.
    func restore(surah: Surah, reciter: ReciterMoshafItem, time: Double, duration: Double) {
        let nearEnd = duration > 0 && duration - time < Self.exitTransitionWindow
        selectedSurah = surah
        selectedReciter = reciter
        player.prepare(surah: surah, reciter: reciter, startAt: nearEnd ? 0 : time, knownDuration: duration)
    }

    /// Persists immediately (pause, seek, track change, backgrounding).
    func persistNow() {
        guard let surah = selectedSurah else { return }
        lastPersistedAt = .now
        onPersist?(surah, selectedReciter, player.currentTime, player.duration)
    }

    /// Persists at most every `persistInterval` seconds; call from frequent progress updates.
    func persistThrottled() {
        guard Date.now.timeIntervalSince(lastPersistedAt) >= Self.persistInterval else { return }
        persistNow()
    }

    func selectReciter(_ item: ReciterMoshafItem) {
        guard item != selectedReciter else { return }
        selectedReciter = item
        if let surah = selectedSurah {
            player.play(surah: surah, reciter: item)
            persistNow()
        }
    }

    /// Re-resolves the selected reciter against a freshly loaded catalog so its names follow the
    /// catalog language (a restored snapshot keeps the language it was saved in). Doesn't touch playback.
    func refreshSelectedReciter(from catalog: [ReciterMoshafItem]) {
        guard let match = catalog.first(where: { $0.id == selectedReciter.id }),
              match != selectedReciter else { return }
        selectedReciter = match
    }

    /// Pass `source` to record the user action in analytics; internal callers omit it.
    func togglePlayPause(source: String? = nil) {
        if source != nil {
            PostHogSDK.shared.capture(
                "playback_toggled",
                properties: ["action": isPlaying ? "pause" : "play"]
            )
        }
        player.togglePlayPause()
        persistNow()
    }

    func seek(toProgress progress: Double, reportsAnalytics: Bool = false) {
        if reportsAnalytics {
            PostHogSDK.shared.capture("playback_seeked", properties: ["target_progress": progress])
        }
        guard player.duration > 0 else { return }
        player.seek(to: min(max(progress, 0), 1) * player.duration)
        persistNow()
    }

    func playNext(source: String? = nil) {
        if let source {
            PostHogSDK.shared.capture(
                "playback_skipped",
                properties: ["direction": "next", "source": source]
            )
        }
        guard let next = playableEntry(from: { self.entry(after: $0) }, first: nextEntry) else { return }
        selectedReciter = next.reciter
        startPlayback(next.surah)
    }

    func playPrevious(source: String? = nil) {
        if let source {
            PostHogSDK.shared.capture(
                "playback_skipped",
                properties: ["direction": "previous", "source": source]
            )
        }
        guard let previous = playableEntry(from: { self.entry(before: $0) }, first: previousEntry) else { return }
        selectedReciter = previous.reciter
        startPlayback(previous.surah)
    }
}
