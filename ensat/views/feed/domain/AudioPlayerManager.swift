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

    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?

    private var player: AVPlayer?
    private var timeObserver: Any?
    private var statusObservation: NSKeyValueObservation?
    private var endObserver: NSObjectProtocol?
    private var interruptionTask: Task<Void, Never>?
    private var playbackTask: Task<Void, Never>?

    private var didConfigureSession = false
    private var currentTitle = ""
    private var currentArtist = ""

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        PostHogExportLogger.info(
            "Surah playback requested",
            attributes: ["surah_id": surah.id]
        )
        guard let player = load(surah: surah, reciter: reciter) else { return }
        startPlayback(player)
        updateNowPlayingInfo()
    }

    func prepare(surah: Surah, reciter: ReciterMoshafItem, startAt: Double) {
        guard let player = load(surah: surah, reciter: reciter) else { return }
        let target = max(startAt, 0)
        currentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
        )
        updateNowPlayingInfo()

        // Paused players don't tick the time observer, so load the duration for the progress bar.
        if let asset = player.currentItem?.asset {
            Task { [weak self] in
                guard let loaded = try? await asset.load(.duration), loaded.isNumeric else { return }
                guard let self, self.player?.currentItem?.asset === asset else { return }
                self.duration = loaded.seconds
                self.updateNowPlayingInfo()
            }
        }
    }

    private func load(surah: Surah, reciter: ReciterMoshafItem) -> AVPlayer? {
        let fileName = String(format: "%03d.mp3", surah.id)
        guard let serverURL = URL(string: reciter.moshaf.server) else { return nil }
        let url = serverURL.appending(path: fileName)

        configureAudioSession()

        let player = player ?? AVPlayer()
        self.player = player

        removeObservers()
        currentTime = 0
        duration = 0
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        observe(player: player)

        currentTitle = surah.displayName
        currentArtist = reciter.reciter.name
        return player
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            startPlayback(player)
        }
    }

    func seek(to time: Double) {
        guard let player, player.currentItem != nil else { return }
        let target = max(time, 0)
        currentTime = target
        player.seek(
            to: CMTime(seconds: target, preferredTimescale: 600),
            toleranceBefore: .zero,
            toleranceAfter: .zero
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

    private nonisolated static func activateSession() async {
        await withCheckedContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                let session = AVAudioSession.sharedInstance()
                try? session.setCategory(.playback, mode: .default, policy: .longFormAudio)
                try? session.setActive(true)
                continuation.resume()
            }
        }
    }

    private func observe(player: AVPlayer) {
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) { [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor [weak self] in
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
                if let itemDuration = self.player?.currentItem?.duration,
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
                self?.onTrackEnded?()
            }
        }
    }

    private func removeObservers() {
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
                guard let self,
                      let value = notification.userInfo?[AVAudioSessionInterruptionTypeKey] as? UInt,
                      let type = AVAudioSession.InterruptionType(rawValue: value)
                else { continue }

                switch type {
                case .began:
                    player?.pause()
                case .ended:
                    if let optionsValue = notification.userInfo?[AVAudioSessionInterruptionOptionKey] as? UInt,
                       AVAudioSession.InterruptionOptions(rawValue: optionsValue).contains(.shouldResume) {
                        player?.play()
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

        let toggleHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = { [weak self] _ in
            MainActor.assumeIsolated {
                self?.togglePlayPause()
            }
            return .success
        }

        center.playCommand.addTarget(handler: toggleHandler)
        center.pauseCommand.addTarget(handler: toggleHandler)
        center.togglePlayPauseCommand.addTarget(handler: toggleHandler)

        center.nextTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onNextTrack?()
            }
            return .success
        }

        center.previousTrackCommand.addTarget { [weak self] _ in
            MainActor.assumeIsolated {
                self?.onPreviousTrack?()
            }
            return .success
        }
    }
}
