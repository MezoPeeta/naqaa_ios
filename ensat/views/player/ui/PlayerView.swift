//
//  PlayerView.swift
//  naqaa
//
//  Created by Mazen on 30/08/2026.
//

import SwiftUI
import Foundation
import PostHog

struct PlayerView: View {
    let playerState: PlayerState
    
    private static let exitScale: CGFloat = 0.86
    private static let exitBlur: CGFloat = 12
    
    private static let transitionDuration: Double = 1
    
    @State private var titleScale: CGFloat = 1
    @State private var titleBlur: CGFloat = 0
    @State private var scrubProgress: Double?
    
    
    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .top) {
                PlayerTopPattern(
                    height: topPatternHeight(for: proxy.size),
                    color: .pattern.opacity(0.35),
                    shape: .fourPointStar
                )
                .frame(maxWidth: .infinity)
                .ignoresSafeArea()
                
                if proxy.size.width > proxy.size.height {
                    
                    sideBySideLayout
                } else {
                    stackedLayout
                    
                }
            }
        }
        .onChange(of: playerState.exitTransitionAmount, initial: true) { _, amount in
            applyExitTransition(amount)
        }
    }
    
    private var stackedLayout: some View {
        VStack(spacing: 24) {
            Spacer()
            
            PlayerSurahTitle(id: playerState.selectedSurah?.id ?? 1)
                .scaleEffect(titleScale)
                .blur(radius: titleBlur)
            Spacer()
            
            metadataAndControls
        }
        .buttonStyle(.plain)
        .padding()
        .frame(maxHeight: .infinity)
        .safeAreaPadding(.bottom)
    }
    
    private var sideBySideLayout: some View {
        HStack(spacing: 24) {
            PlayerSurahTitle(id: playerState.selectedSurah?.id ?? 1)
                .scaleEffect(titleScale)
                .blur(radius: titleBlur)
                .frame(maxWidth: .infinity)
            metadataAndControls
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
        .padding()
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxHeight: .infinity)
        .safeAreaPadding(.horizontal)
    }
    
    private var metadataAndControls: some View {
        VStack {
            titleAndReciter
            
            PlayerProgressBar(
                progress: playerState.progress, scrubProgress: $scrubProgress) { progress in
                    PostHogSDK.shared.capture(
                        "playback_seeked",
                        properties: ["target_progress": progress]
                    )
                    playerState.seek(toProgress: progress)
                }
                .padding(.horizontal)
            
            timeLabels
            
            transportControls
                .disabled(playerState.isEmpty)
        }
    }
    
    private var titleAndReciter: some View {
        VStack {
            Text(playerState.selectedSurah?.displayName ?? "")
                .font(.title3)
                .bold()
                .fontWidth(.expanded)
            Text(playerState.selectedReciter.reciter.name)
                .foregroundStyle(.secondary)
        }
    }
    
    private var timeLabels: some View {
        HStack {
            Text(formattedTime(displayedTime))
            Spacer()
            Text(formattedTime(playerState.player.duration))
        }
        .font(.caption)
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }
    
    private var transportControls: some View {
        HStack(spacing: 32) {
            Button {
                PostHogSDK.shared.capture(
                    "playback_skipped",
                    properties: ["direction": "previous", "source": "full_player"]
                )
                playerState.playPrevious()
            } label: {
                DirectionalImage("backward.fill")
                    .font(.title3)
            }
            
            Button {
                PostHogSDK.shared.capture(
                    "playback_toggled",
                    properties: ["action": playerState.isPlaying ? "pause" : "play"]
                )
                playerState.togglePlayPause()
            } label: {
                if playerState.isBuffering {
                    ProgressView()
                        .frame(width: 28, height: 28)
                } else {
                    DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                        .font(.title)
                        .contentTransition(.symbolEffect(.replace))
                }
            }
            .animation(.easeInOut(duration: 0.2), value: playerState.isPlaying)
            .accessibilityLabel(
                playerState.isBuffering
                ? "Buffering"
                : (playerState.isPlaying ? "Pause" : "Play")
            )
            
            Button {
                PostHogSDK.shared.capture(
                    "playback_skipped",
                    properties: ["direction": "next", "source": "full_player"]
                )
                playerState.playNext()
            } label: {
                DirectionalImage("forward.fill")
                    .font(.title3)
            }
        }
    }
    
    /// The playhead shown in the time labels, which follows the finger while scrubbing.
    private var displayedTime: Double {
        let duration = playerState.player.duration
        guard let scrubProgress, duration > 0 else { return playerState.player.currentTime }
        return scrubProgress * duration
    }
    
    private func topPatternHeight(for size: CGSize) -> CGFloat {
        let proportional = size.height * 0.35
        return min(max(proportional, 100), 300)
    }
    
    private func applyExitTransition(_ amount: Double) {
        let scale = Self.exitScale + (1 - Self.exitScale) * (1 - amount)
        let blur = Self.exitBlur * amount
        withAnimation(.linear(duration: Self.transitionDuration)) {
            titleScale = scale
            titleBlur = blur
        }
    }
    
    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        let totalSeconds = Int(seconds)
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let remaining = totalSeconds % 60
        if hours > 0 {
            return "\(hours):\(String(format: "%02d", minutes)):\(String(format: "%02d", remaining))"
        }
        return "\(minutes):\(String(format: "%02d", remaining))"
    }
}

#if DEBUG
@MainActor
private final class PreviewAudioPlayer: AudioPlaying {
    var isPlaying = true
    var isBuffering = false
    var currentTime: Double = 150
    var duration: Double = 300
    var onTrackEnded: (() -> Void)?
    var onNextTrack: (() -> Void)?
    var onPreviousTrack: (() -> Void)?
    func play(surah: Surah, reciter: ReciterMoshafItem) {}
    func togglePlayPause() {}
    func seek(to time: Double) {}
}

@MainActor
private func makePreviewState() -> PlayerState {
    let state = PlayerState(player: PreviewAudioPlayer())
    let surah = Surah(
        id: 2,
        name: "البقرة",
        revelationPlace: .medinan,
        totalVerses: 286,
        transliteration: "Al-Baqarah"
    )
    state.surahs = [surah]
    state.selectedSurah = surah
    return state
}

#Preview {
    PlayerView(playerState: makePreviewState())
        .preferredColorScheme(.dark)
        .background(.homeBackground)
}
#endif
