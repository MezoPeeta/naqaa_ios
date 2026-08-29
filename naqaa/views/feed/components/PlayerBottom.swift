import SwiftUI

struct PlayerBottom: View {
    let playerState: PlayerState
    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading) {
                Text(playerState.selectedSurah?.displayName ?? "DF")
                    .font(.subheadline)
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
                    DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                }
            }
            .accessibilityLabel(playerState.isBuffering ? "Buffering" : (playerState.isPlaying ? "Pause" : "Play"))
            .disabled(playerState.selectedSurah == nil)

            Button(action: playerState.playNext) {
                DirectionalImage("forward.fill")
            }
            .disabled(!playerState.canPlayNext)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)

    }
}

#Preview {
    PlayerBottom(playerState: PlayerState())
}
