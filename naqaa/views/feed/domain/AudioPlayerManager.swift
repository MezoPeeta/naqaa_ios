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

    private var didConfigureSession = false
    private var currentTitle = ""
    private var currentArtist = ""

    func play(surah: Surah, reciter: ReciterMoshafItem) {
        let fileName = String(format: "%03d.mp3", surah.id)
        guard let serverURL = URL(string: reciter.moshaf.server) else { return }
        let url = serverURL.appending(path: fileName)

        configureAudioSession()

        let player = player ?? AVPlayer()
        self.player = player

        removeObservers()
        player.replaceCurrentItem(with: AVPlayerItem(url: url))
        observe(player: player)

        currentTitle = surah.displayName
        currentArtist = reciter.reciter.name

        activateSession()
        player.play()
        updateNowPlayingInfo()
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
        } else {
            activateSession()
            player.play()
        }
    }

    private func configureAudioSession() {
        guard !didConfigureSession else { return }
        didConfigureSession = true

        try? AVAudioSession.sharedInstance().setCategory(
            .playback,
            mode: .default,
            policy: .longFormAudio
        )

        setupRemoteCommands()
        observeInterruptions()
    }

    private func activateSession() {
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    private func observe(player: AVPlayer) {
        statusObservation = player.observe(\.timeControlStatus, options: [.new]) {
            [weak self] player, _ in
            let status = player.timeControlStatus
            Task { @MainActor in
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

        let toggleHandler: (MPRemoteCommandEvent) -> MPRemoteCommandHandlerStatus = {
            [weak self] _ in
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
