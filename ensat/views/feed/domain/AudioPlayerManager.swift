import AVFoundation
import MediaPlayer
import Observation

@Observable
@MainActor
final class AudioPlayerManager {
    private(set) var isPlaying = false
    private(set) var isBuffering = false
    private(set) var currentTime: Double = 0
    private(set) var duration: Double = 0
    private(set) var isPlayingLocal = false
    private(set) var didFailToPlay = false

    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    private static let forwardBufferDuration: TimeInterval = 60
    /// Exact seeks on VBR MP3s make AVPlayer scan the file with extra range requests.
    private static let seekTolerance = CMTime(seconds: 1, preferredTimescale: 600)

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var itemObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var interruptionTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?
    private var durationTask: Task<Void, Never>?
    private var probeTask: Task<Void, Never>?
    /// Set when the file's header lies about its length (see `MP3DurationProbe`); wins over AVPlayer's value.
    private var durationOverride: Double?
    /// Guards `onTrackEnded` so the real end-of-item notification and the override check can't both fire.
    private var didSignalEnd = false

    private var didConfigureSession = false
    private var currentURL: URL?
    private var currentSurah: Surah?
    private var currentReciter: ReciterMoshafItem?
    private let downloads: DownloadFileStore

    init(downloads: DownloadFileStore = DownloadFileStore()) {
        self.downloads = downloads
    }
    private var currentTitle = ""
    private var currentArtist = ""

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        PostHogExportLogger.info(
            "Surah playback requested",
            attributes: ["surah_id": surah.id]
        )
        // Same track: rewind the existing item instead of re-probing the file over the network.
        if let player, let url = SurahAudioURL.remote(surah: surah, reciter: reciter),
           url == currentURL, player.currentItem?.status != .failed {
            currentTime = 0
            didSignalEnd = false
            player.seek(to: .zero, toleranceBefore: Self.seekTolerance, toleranceAfter: Self.seekTolerance)
            startPlayback(player)
            updateNowPlayingInfo()
            return
        }
        guard let player = load(surah: surah, reciter: reciter) else { return }
        startPlayback(player)
        updateNowPlayingInfo()
    }

    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double, knownDuration: Double) {
        guard let player = load(surah: surah, reciter: reciter) else { return }
        let target = max(startAt, 0)
        currentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: Self.seekTolerance,
            toleranceAfter: Self.seekTolerance
        )

        // Paused players don't tick the time observer, so the progress bar needs a duration.
        // Reuse the saved one and only ask the asset when there isn't one.
        if knownDuration > 0 {
            duration = knownDuration
            updateNowPlayingInfo()
            return
        }
        updateNowPlayingInfo()
        if let asset = player.currentItem?.asset {
            durationTask = Task { [weak self] in
                guard let loaded = try? await asset.load(.duration), loaded.isNumeric else { return }
                guard let self, self.player?.currentItem?.asset === asset else { return }
                self.duration = self.durationOverride ?? loaded.seconds
                self.updateNowPlayingInfo()
            }
        }
    }

    /// A downloaded file wins over streaming; nil when there is no usable URL at all.
    static func playbackURL(
        surah: Surah, reciter: ReciterMoshafItem, preferLocal: Bool, downloads: DownloadFileStore
    ) -> (url: URL, isLocal: Bool)? {
        if preferLocal, downloads.exists(surahId: surah.id, itemId: reciter.id) {
            return (downloads.fileURL(surahId: surah.id, itemId: reciter.id), true)
        }
        guard let remote = SurahAudioURL.remote(surah: surah, reciter: reciter) else { return nil }
        return (remote, false)
    }

    /// Deletes a downloaded file that won't play and tells the downloads index it is gone.
    static func discardBrokenDownload(
        surahId: Int, itemId: String, downloads: DownloadFileStore,
        center: NotificationCenter = .default
    ) {
        downloads.delete(surahId: surahId, itemId: itemId)
        center.post(
            name: .downloadedFileRemoved, object: nil,
            userInfo: ["surahId": surahId, "itemId": itemId]
        )
    }

    private func load(surah: Surah, reciter: ReciterMoshafItem, preferLocal: Bool = true) -> AVPlayer? {
        guard let playback = Self.playbackURL(
            surah: surah, reciter: reciter, preferLocal: preferLocal, downloads: downloads
        ) else { return nil }
        let url = playback.url
        // Identity stays the remote URL so replaying the same track still rewinds instead of reloading.
        currentURL = SurahAudioURL.remote(surah: surah, reciter: reciter)
        currentSurah = surah
        currentReciter = reciter
        isPlayingLocal = playback.isLocal
        didFailToPlay = false

        configureAudioSession()

        let player = player ?? AVPlayer()
        self.player = player

        removeObservers()
        durationTask?.cancel()
        probeTask?.cancel()
        durationOverride = nil
        didSignalEnd = false
        currentTime = 0
        duration = 0
        let item = AVPlayerItem(url: url)
        // Surahs can run for hours; keep the streamed look-ahead bounded.
        item.preferredForwardBufferDuration = Self.forwardBufferDuration
        player.replaceCurrentItem(with: item)
        observe(player: player)
        observeFailure(of: item)
        probeDuration(of: url, item: item)

        currentTitle = surah.displayName
        currentArtist = reciter.reciter.name
        return player
    }

    /// Corrects the duration when the file's header is wrong (e.g. it claims 29 minutes for a 50-second surah).
    private func probeDuration(of url: URL, item: AVPlayerItem) {
        probeTask = Task { [weak self] in
            guard let fixed = await MP3DurationProbe.probe(url: url), !Task.isCancelled else { return }
            guard let self, self.player?.currentItem === item else { return }
            self.durationOverride = fixed
            self.duration = fixed
            self.updateNowPlayingInfo()
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            pause()
        } else {
            startPlayback(player)
        }
    }

    private func pause() {
        // A play request still waiting on session activation must not undo the pause.
        playbackTask?.cancel()
        player?.pause()
    }

    private func resume() {
        guard let player, !isPlaying else { return }
        startPlayback(player)
    }

    func seek(to time: Double) {
        guard let player, player.currentItem != nil else { return }
        let target = max(time, 0)
        currentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: Self.seekTolerance,
            toleranceAfter: Self.seekTolerance
        )
        updateNowPlayingInfo()
    }

    private func configureAudioSession() {
        guard !didConfigureSession else { return }
        didConfigureSession = true

        setupRemoteCommands()
        observeInterruptions()
    }

    private func startPlayback(_ player: AVPlayer) {
        playbackTask?.cancel()
        playbackTask = Task { [weak self] in
            await Self.activateSession()
            guard !Task.isCancelled, self != nil else { return }
            player.play()
        }
    }

    /// Session activation blocks, so it runs off the main actor.
    @concurrent
    private static func activateSession() async {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
        try? session.setActive(true)
    }

    private func observe(player: AVPlayer) {
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] _, _ in
            // Read the status on the main actor so hops that run out of order still see the latest value.
            Task { @MainActor [weak self] in
                guard let status = self?.player?.timeControlStatus else { return }
                self?.handleStatus(status)
            }
        }

        timeObserver = player.addPeriodicTimeObserver(
            forInterval: CMTime(seconds: 1, preferredTimescale: 1),
            queue: .main
        ) { [weak self] time in
            MainActor.assumeIsolated {
                guard let self else { return }
                self.currentTime = time.seconds
                if let override = self.durationOverride {
                    self.duration = override
                    // AVPlayer believes the file is longer than it is, so end the track ourselves.
                    if !self.didSignalEnd, time.seconds >= override - 0.25 {
                        self.didSignalEnd = true
                        self.onTrackEnded?()
                    }
                } else if let itemDuration = self.player?.currentItem?.duration,
                          itemDuration.isNumeric {
                    self.duration = itemDuration.seconds
                }
                self.updateNowPlayingInfo()
            }
        }

        endObserver = NotificationCenter.default.addObserver(
            forName: .AVPlayerItemDidPlayToEndTime,
            object: player.currentItem,
            queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated {
                guard let self, !self.didSignalEnd else { return }
                self.didSignalEnd = true
                self.onTrackEnded?()
            }
        }
    }

    /// A downloaded file that won't play is deleted and the stream takes over;
    /// a stream that won't play is reported so the UI can say so instead of buffering forever.
    private func observeFailure(of item: AVPlayerItem) {
        itemObservation = item.observe(\.status, options: [.new]) { [weak self] item, _ in
            guard item.status == .failed else { return }
            Task { @MainActor [weak self] in self?.handleFailure(of: item) }
        }
    }

    func clearPlaybackFailure() {
        didFailToPlay = false
    }

    private func handleFailure(of item: AVPlayerItem) {
        guard player?.currentItem === item else { return }
        if isPlayingLocal {
            fallBackToStream(from: item)
        } else {
            isBuffering = false
            didFailToPlay = true
        }
    }

    private func fallBackToStream(from item: AVPlayerItem) {
        guard player?.currentItem === item, isPlayingLocal,
              let surah = currentSurah, let reciter = currentReciter else { return }
        PostHogExportLogger.warn(
            "Downloaded surah failed to play",
            attributes: ["surah_id": surah.id]
        )
        Self.discardBrokenDownload(surahId: surah.id, itemId: reciter.id, downloads: downloads)
        let resumeAt = currentTime
        let wasPlaying = isPlaying || isBuffering
        guard let player = load(surah: surah, reciter: reciter, preferLocal: false) else { return }
        currentTime = resumeAt
        player.seek(
            to: CMTime(seconds: resumeAt, preferredTimescale: 600),
            toleranceBefore: Self.seekTolerance,
            toleranceAfter: Self.seekTolerance
        )
        if wasPlaying { startPlayback(player) }
        updateNowPlayingInfo()
    }

    private func removeObservers() {
        itemObservation?.invalidate()
        itemObservation = nil
        if let timeObserver, let player {
            player.removeTimeObserver(timeObserver)
        }
        timeObserver = nil
        statusObservation?.invalidate()
        statusObservation = nil
        if let endObserver {
            NotificationCenter.default.removeObserver(endObserver)
        }
        endObserver = nil
    }

    private func handleStatus(_ status: AVPlayer.TimeControlStatus) {
        switch status {
        case .playing:
            isPlaying = true
            isBuffering = false
        case .paused:
            isPlaying = false
            isBuffering = false
        case .waitingToPlayAtSpecifiedRate:
            isBuffering = true
        @unknown default:
            break
        }
        updateNowPlayingInfo()
    }

    private func observeInterruptions() {
        interruptionTask = Task { [weak self] in
            for await notification in NotificationCenter.default.notifications(
                named: AVAudioSession.interruptionNotification
            ) {
                guard let self else { return }
                guard let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: value)
                else { continue }

                switch type {
                case .began:
                    pause()
                case .ended:
                    if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                        resume()
                    }
                @unknown default:
                    break
                }
            }
        }
    }

    private func updateNowPlayingInfo() {
        var info: [String: Any] = [
            MPMediaItemPropertyTitle: currentTitle,
            MPMediaItemPropertyArtist: currentArtist,
            MPNowPlayingInfoPropertyElapsedPlaybackTime: currentTime,
            MPNowPlayingInfoPropertyPlaybackRate: isPlaying ? 1 : 0
        ]
        if duration > 0 {
            info[MPMediaItemPropertyPlaybackDuration] = duration
        }
        MPNowPlayingInfoCenter.default().nowPlayingInfo = info
    }

    private func setupRemoteCommands() {
        let center = MPRemoteCommandCenter.shared()

        // The queue MPRemoteCommandCenter calls handlers on isn't documented, so hop instead of assuming main.
        center.playCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.resume() }
            return .success
        }

        center.pauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.pause() }
            return .success
        }

        center.togglePlayPauseCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.togglePlayPause() }
            return .success
        }

        center.nextTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onNextTrack?() }
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            Task { @MainActor [weak self] in self?.onPreviousTrack?() }
            return .success
        }
    }
}
