import SwiftUI

struct PlayerBottom: View {
    let playerState: PlayerState
    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Color.selectedText
                    .opacity(0.15)
                    .frame(width: geo.size.width * playerState.progress)

                HStack(alignment: .center, spacing: 16) {
                    VStack(alignment: .leading) {
                        Text(playerState.selectedSurah?.displayName ?? "")
                            .font(.subheadline)
                            .bold()
                        Text(playerState.selectedReciter.reciter.name)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()

                    Button(action: {}, label: {
                        DirectionalImage("earpods")
                    })

                    Button {
                        playerState.togglePlayPause()
                    } label: {
                        if playerState.isBuffering {
                            ProgressView()
                        } else {
                            DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                        }
                    }
                    .accessibilityLabel(
                        playerState.isBuffering
                            ? "Buffering"
                            : (playerState.isPlaying ? "Pause" : "Play")
                    )
                    .disabled(playerState.isEmpty)

                }
                .buttonStyle(.plain)
                .padding(.horizontal, 22)
                .contentShape(Rectangle())
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 40)
                    .onEnded { value in
                        guard abs(value.translation.width) > abs(value.translation.height) else { return }
                        if value.translation.width < 0 {
                            playerState.playNext()
                        } else {
                            playerState.playPrevious()
                        }
                    }
            )
        }
    }
}

#Preview {
    PlayerBottom(playerState: PlayerState())
}
