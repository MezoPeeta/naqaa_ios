import AVFoundation
import Foundation
import Observation
import PostHog
import SwiftData

@Observable
@MainActor
final class DownloadManager {
    enum State: Equatable {
        case downloading(Double)
        case failed
    }

    enum StartResult {
        case started, alreadyRunning, unavailable, insufficientSpace
    }

    static let allowsCellularKey = "downloads.allowsCellular"
    /// Files above this size ask for confirmation first.
    static let confirmationThreshold: Int64 = 50 * 1_000_000

    /// In-flight and failed downloads. Finished ones live in SwiftData as `DownloadedTrack`.
    private(set) var states: [String: State] = [:]
    /// Progress callbacks can arrive many times per frame on a fast connection; publishing each
    /// one makes observers update faster than SwiftUI can render.
    private static let minProgressStep = 0.01
    private static let minProgressInterval: Duration = .milliseconds(50)
    private var lastPublishedProgress: [String: (fraction: Double, at: ContinuousClock.Instant)] = [:]

    /// `ModelContext` doesn't keep its container alive; using the context after the container is gone traps.
    private let container: ModelContainer
    private let files: DownloadFileStore
    private let store: DownloadsStore
    private let session: URLSession
    private let availableBytes: () -> Int64
    private let isPlayable: (URL) async -> Bool
    /// Sizes already learned from a HEAD request, so repeat taps skip the network.
    private var sizeCache: [URL: Int64] = [:]
    private var sizeTasks: [URL: Task<Int64?, Never>] = [:]
    /// Size checks must not hold the control for the 60 s default; no answer means "size unknown".
    private nonisolated static let sizeSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 6
        configuration.waitsForConnectivity = false
        return URLSession(configuration: configuration)
    }()
    private var eventTask: Task<Void, Never>?
    private var removalTask: Task<Void, Never>?
    private var startupTask: Task<Void, Never>?

    /// Builds the production background session; tests pass a factory that returns an in-process one.
    nonisolated static func makeBackgroundSession(delegate: any URLSessionDelegate) -> URLSession {
        let configuration = URLSessionConfiguration.background(withIdentifier: sessionIdentifier)
        configuration.sessionSendsLaunchEvents = true
        configuration.waitsForConnectivity = true
        configuration.httpMaximumConnectionsPerHost = 2
        return URLSession(configuration: configuration, delegate: delegate, delegateQueue: nil)
    }

    init(
        container: ModelContainer,
        files: DownloadFileStore = DownloadFileStore(),
        makeSession: (any URLSessionDelegate) -> URLSession = DownloadManager.makeBackgroundSession,
        availableBytes: @escaping () -> Int64 = DownloadManager.systemAvailableBytes,
        isPlayable: @escaping (URL) async -> Bool = DownloadManager.avFoundationCanPlay
    ) {
        self.container = container
        self.files = files
        self.availableBytes = availableBytes
        self.isPlayable = isPlayable
        self.store = DownloadsStore(context: container.mainContext, files: files)

        // One stream, one consumer: events are handled in the order the session delivered them.
        let (events, continuation) = AsyncStream.makeStream(of: DownloadEvent.self)
        let delegate = DownloadSessionDelegate(files: files) { continuation.yield($0) }
        session = makeSession(delegate)

        eventTask = Task { [weak self] in
            for await event in events { await self?.handle(event) }
        }
        removalTask = Task { [weak self] in
            for await note in NotificationCenter.default.notifications(named: .downloadedFileRemoved) {
                guard let surahId = note.userInfo?["surahId"] as? Int,
                      let itemId = note.userInfo?["itemId"] as? String else { continue }
                self?.store.removeIndex(surahId: surahId, itemId: itemId)
            }
        }
        startupTask = Task { [weak self] in
            await self?.restoreInFlight()
            await self?.reconcileIndex()
        }
    }

    /// Completes once the launch-time restore and reconcile pass has finished.
    func waitForStartup() async {
        await startupTask?.value
    }

    isolated deinit {
        eventTask?.cancel()
        removalTask?.cancel()
    }

    nonisolated static var sessionIdentifier: String {
        (Bundle.main.bundleIdentifier ?? "ensat") + ".downloads"
    }

    func state(surahId: Int, item: ReciterMoshafItem) -> State? {
        states[FavoriteTrack.key(surahId: surahId, itemId: item.id)]
    }

    /// Size from a HEAD request, or nil when the server doesn't say. Cached, and a request already
    /// in flight (for example from `prefetchFileSize`) is shared instead of repeated.
    func fileSize(surah: Surah, item: ReciterMoshafItem) async -> Int64? {
        guard let url = SurahAudioURL.remote(surah: surah, reciter: item) else { return nil }
        if let cached = sizeCache[url] { return cached }

        let task: Task<Int64?, Never>
        if let running = sizeTasks[url] {
            task = running
        } else {
            let allowsCellular = allowsCellular
            task = Task { await Self.headSize(of: url, allowsCellular: allowsCellular) }
            sizeTasks[url] = task
        }
        let size = await task.value
        sizeTasks[url] = nil
        if let size { sizeCache[url] = size }
        return size
    }

    /// Starts the size check early, such as on touch-down, so the answer is ready by the time of the tap.
    func prefetchFileSize(surah: Surah, item: ReciterMoshafItem) {
        Task { _ = await fileSize(surah: surah, item: item) }
    }

    @concurrent
    private static func headSize(of url: URL, allowsCellular: Bool) async -> Int64? {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"
        request.allowsCellularAccess = allowsCellular
        guard let (_, response) = try? await sizeSession.data(for: request),
              response.expectedContentLength > 0
        else { return nil }
        return response.expectedContentLength
    }

    /// Starts a download, reporting whether one actually began.
    func download(surah: Surah, item: ReciterMoshafItem, expectedBytes: Int64? = nil) -> StartResult {
        if let expectedBytes, expectedBytes > availableBytes() { return .insufficientSpace }
        let info = DownloadRequestInfo(surahId: surah.id, item: item)
        let key = info.key
        if case .downloading = states[key] { return .alreadyRunning }
        guard let url = SurahAudioURL.remote(surah: surah, reciter: item) else { return .unavailable }

        var request = URLRequest(url: url)
        request.allowsCellularAccess = allowsCellular
        let task = session.downloadTask(with: request)
        task.taskDescription = info.taskDescription
        lastPublishedProgress[key] = nil
        states[key] = .downloading(0)
        task.resume()
        PostHogExportLogger.info("Surah download started", attributes: ["surah_id": surah.id])
        return .started
    }

#if DEBUG
    /// Drives the control from previews without touching the network.
    func simulate(_ state: State?, surahId: Int, item: ReciterMoshafItem) {
        states[FavoriteTrack.key(surahId: surahId, itemId: item.id)] = state
    }
#endif

    /// Asks AVFoundation whether a finished file can actually be played.
    nonisolated static func avFoundationCanPlay(_ url: URL) async -> Bool {
        (try? await AVURLAsset(url: url).load(.isPlayable)) ?? false
    }

    nonisolated static func systemAvailableBytes() -> Int64 {
        let values = try? URL.documentsDirectory.resourceValues(forKeys: [.volumeAvailableCapacityForImportantUsageKey])
        return values?.volumeAvailableCapacityForImportantUsage ?? .max
    }

    func cancel(surahId: Int, item: ReciterMoshafItem) {
        let key = FavoriteTrack.key(surahId: surahId, itemId: item.id)
        states[key] = nil
        Task {
            for task in await session.allTasks
            where DownloadRequestInfo(taskDescription: task.taskDescription)?.key == key {
                task.cancel()
            }
        }
    }

    func remove(surahId: Int, item: ReciterMoshafItem) {
        store.remove(surahId: surahId, item: item)
    }

    private var allowsCellular: Bool {
        UserDefaults.standard.bool(forKey: Self.allowsCellularKey)
    }

    private func restoreInFlight() async {
        for task in await session.allTasks {
            guard let info = DownloadRequestInfo(taskDescription: task.taskDescription),
                  states[info.key] == nil else { continue }
            states[info.key] = .downloading(0)
        }
    }

    /// Runs after in-flight downloads are known, so a file that just finished isn't mistaken for an orphan.
    private func reconcileIndex() async {
        let onDisk = await files.allKeys()
        store.reconcile(onDisk: onDisk, inFlight: Set(states.keys))
    }

    func handle(_ event: DownloadEvent) async {
        switch event {
        case .progress(let key, let fraction):
            if case .failed = states[key] { return }
            let now = ContinuousClock.now
            if let last = lastPublishedProgress[key], fraction < 1,
               fraction - last.fraction < Self.minProgressStep || now - last.at < Self.minProgressInterval {
                return
            }
            lastPublishedProgress[key] = (fraction, now)
            states[key] = .downloading(fraction)
        case .cancelled(let key):
            lastPublishedProgress[key] = nil
            states[key] = nil
        case .failed(let key):
            PostHogExportLogger.warn("Surah download failed", attributes: [:])
            lastPublishedProgress[key] = nil
            states[key] = .failed
        case .finished(let info, let byteCount):
            let item = info.item
            let url = files.fileURL(surahId: info.surahId, itemId: item.id)
            let playable = await isPlayable(url)
            // The user may have cancelled or removed this surah while it was being checked.
            guard files.exists(surahId: info.surahId, itemId: item.id) else {
                lastPublishedProgress[info.key] = nil
                states[info.key] = nil
                return
            }
            guard playable else {
                files.delete(surahId: info.surahId, itemId: item.id)
                states[info.key] = .failed
                return
            }
            store.add(surahId: info.surahId, item: item, byteCount: byteCount)
            PostHogSDK.shared.capture(
                "surah_downloaded",
                properties: [
                    "surah_id": info.surahId,
                    "reciter_id": item.reciter.id,
                    "moshaf_id": item.moshaf.id,
                    "byte_count": byteCount
                ]
            )
            lastPublishedProgress[info.key] = nil
            states[info.key] = nil
        }
    }
}
