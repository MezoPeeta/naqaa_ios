//
//  PlayerTitleSweep.swift
//  ensat
//

import SwiftUI

/// The title erases in step with the last seconds of the track. The player reports its time
/// about once a second, so between reports the playhead is extrapolated from the wall clock
/// each frame, which keeps the sweep smooth without drifting from the audio.
///
/// Lives in its own view so the once-a-second anchor update does not invalidate the whole player.
struct PlayerTitleSweep: View {
    let playerState: PlayerState

    /// Longest the playhead is extrapolated without a fresh report, in seconds, so a stalled
    /// player does not let the title run ahead of the audio.
    private static let maxExtrapolation: Double = 1.5

    private struct PlayheadAnchor {
        var time: Double
        var date: Date
    }

    @State private var playheadAnchor = PlayheadAnchor(time: 0, date: .now)
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var isSweepPaused: Bool {
        reduceMotion || !playerState.shouldSweepTitle || !playerState.isPlaying
    }

    var body: some View {
        TimelineView(.animation(paused: isSweepPaused)) { timeline in
            PlayerSurahTitle(
                id: playerState.selectedSurah?.id ?? 1,
                eraseProgress: reduceMotion ? 0 : playerState.titleSweepAmount(
                    atPlayhead: estimatedPlayhead(at: timeline.date)
                )
            )
        }
        // The calligraphy is rendered from a glyph key ("surah002") plus two shadow copies, so
        // expose it as a single element that reads the surah's name instead.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(playerState.selectedSurah?.displayName ?? "")
        .accessibilityAddTraits(.isHeader)
        .accessibilityHidden(playerState.selectedSurah == nil)
        .onChange(of: playerState.player.currentTime, initial: true) { _, time in
            playheadAnchor = PlayheadAnchor(time: time, date: .now)
        }
    }

    private func estimatedPlayhead(at date: Date) -> Double {
        let reported = playerState.player.currentTime
        guard playerState.isPlaying else { return reported }
        let elapsed = min(max(date.timeIntervalSince(playheadAnchor.date), 0), Self.maxExtrapolation)
        return playheadAnchor.time + elapsed
    }
}
