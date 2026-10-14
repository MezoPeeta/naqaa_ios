import SwiftUI

/// Trailing icon for a playable row: a play glyph, or an animated waveform while it is the current track.
struct PlaybackIndicator: View {
    let isSelected: Bool
    let isPlaying: Bool

    var body: some View {
        DirectionalImage(isSelected ? "waveform" : "play")
            .font(.system(size: 18))
            .foregroundStyle(isSelected ? Color.selectedText : Color.primary)
            .contentTransition(.symbolEffect(.replace))
            .symbolEffect(.variableColor.cumulative, options: .repeating, isActive: isPlaying)
            .accessibilityLabel(isSelected ? "Playing" : "Play")
    }
}

#Preview {
    HStack(spacing: 24) {
        PlaybackIndicator(isSelected: false, isPlaying: false)
        PlaybackIndicator(isSelected: true, isPlaying: false)
        PlaybackIndicator(isSelected: true, isPlaying: true)
    }
    .padding()
    .preferredColorScheme(.dark)
}
