import SwiftUI

struct PlayerBottom: View {
    let playerState: PlayerState
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading) {
                Text(playerState.selectedSurah?.displayName ?? "")
                Text(playerState.selectedReciter.reciter.name)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()

            Button {
                playerState.togglePlayPause()
            } label: {
                if playerState.isBuffering {
                    ProgressView()
                } else {
                    Image(systemName: playerState.isPlaying ? "pause.fill" : "play.fill")
                }
            }
            .accessibilityLabel(playerState.isBuffering ? "Buffering" : (playerState.isPlaying ? "Pause" : "Play"))
            .disabled(playerState.selectedSurah == nil)

            Button("", systemImage: "forward.fill", action: playerState.playNext)
                .disabled(!playerState.canPlayNext)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)

    }
}

#Preview {
    PlayerBottom(playerState: PlayerState())
}
