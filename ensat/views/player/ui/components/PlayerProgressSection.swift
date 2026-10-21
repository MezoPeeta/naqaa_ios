//
//  PlayerProgressSection.swift
//  ensat
//

import SwiftUI

/// Progress bar and time labels. They are the only part of the player that depends on the
/// once-a-second playhead, so they live here and the rest of `PlayerView` is not re-evaluated.
struct PlayerProgressSection: View {
    let playerState: PlayerState

    @State private var scrubProgress: Double?

    var body: some View {
        PlayerProgressBar(
            progress: playerState.progress, scrubProgress: $scrubProgress) { progress in
                playerState.seek(toProgress: progress, reportsAnalytics: true)
            }
            .padding(.horizontal)

        timeLabels
    }

    private var timeLabels: some View {
        HStack {
            Text(formattedTime(displayedTime))
            Spacer()
            Text(formattedTime(playerState.player.duration))
        }
        .font(.caption)
        .monospacedDigit()
        .foregroundStyle(.secondary)
        .padding(.horizontal)
    }

    /// The playhead shown in the time labels, which follows the finger while scrubbing.
    private var displayedTime: Double {
        let duration = playerState.player.duration
        guard let scrubProgress, duration > 0 else { return playerState.player.currentTime }
        return scrubProgress * duration
    }

    private func formattedTime(_ seconds: Double) -> String {
        guard seconds.isFinite, seconds > 0 else { return "0:00" }
        return Duration.seconds(Int(seconds))
            .formatted(.time(pattern: seconds >= 3600 ? .hourMinuteSecond : .minuteSecond))
    }
}
