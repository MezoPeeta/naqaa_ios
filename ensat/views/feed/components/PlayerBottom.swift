import SwiftUI
import PostHog

struct PlayerBottom: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let playerState: PlayerState

    var body: some View {
        HStack(alignment: .center, spacing: 20) {
            let surahName = playerState.selectedSurah?.displayName ?? "Surah"
            let reciterName = playerState.selectedReciter.reciter.name

            VStack(alignment: .leading,spacing: 0) {

                Text(surahName)
                    .font(.subheadline.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)

                Text(reciterName)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(height: 44)
            .accessibilityElement(children: .combine)
            Spacer()

            AudioRoutePickerButton()

            Button {
                playerState.togglePlayPause()
            } label: {
                ZStack {
                    if playerState.isBuffering {
                        ProgressView()
                            .transition(.scale.combined(with: .opacity))
                    } else {
                        DirectionalImage(playerState.isPlaying ? "pause.fill" : "play.fill")
                            .font(.title2)
                            .contentTransition(.symbolEffect(.replace))
                            .transition(.scale.combined(with: .opacity))
                    }
                }
                .frame(width: 24, height: 44)
                .contentShape(Rectangle())
                .animation(.smooth(duration: 0.25), value: playerState.isBuffering)
            }
            .accessibilityLabel(
                playerState.isBuffering
                    ? "Buffering"
                    : (playerState.isPlaying ? "Pause" : "Play")
            )
            .disabled(playerState.isEmpty)
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 16)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        // Progress fill: grows from the leading edge as the surah plays.
        .background(alignment: .leading) {
            GeometryReader { geo in
                Color.selectedText
                    .opacity(0.15)
                    .frame(width: geo.size.width * playerState.progress)
            }
        }
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 40)
                .onEnded { value in
                    guard abs(value.translation.width) > abs(value.translation.height) else { return }
                    let swipedTowardLeading = layoutDirection == .rightToLeft
                        ? value.translation.width > 0
                        : value.translation.width < 0
                    if swipedTowardLeading {
                        playerState.playNext()
                    } else {
                        playerState.playPrevious()
                    }
                }
        )
        .accessibilityAction(named: "Next surah") { playerState.playNext() }
        .accessibilityAction(named: "Previous surah") { playerState.playPrevious() }
    }
}

#if DEBUG
#Preview("In tab accessory") {
    TabView {
        Tab("Home", systemImage: "house") {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(1...40, id: \.self) { Text("Row \($0)") }
                }
                .padding()
            }
        }
        Tab("Favorites", systemImage: "heart") { Color.clear }
        Tab("Search", systemImage: "magnifyingglass", role: .search) { Color.clear }
    }
    .tabBarMinimizeBehavior(.onScrollDown)
    .tabViewBottomAccessory {
        PlayerBottom(playerState: .preview())
    }
    .preferredColorScheme(.dark)
}

#Preview("Arabic (RTL)") {
    TabView {
        Tab("Home", systemImage: "house") { Color.clear }
        Tab("Favorites", systemImage: "heart") { Color.clear }
    }
    .tabViewBottomAccessory {
        PlayerBottom(playerState: .preview())
    }
    .environment(\.locale, Locale(identifier: "ar"))
    .environment(\.layoutDirection, .rightToLeft)
    .preferredColorScheme(.dark)
}

/// `Surah.displayName` reads `Locale.current`, which previews don't switch, so the Arabic state
/// puts the Arabic name in both fields to show Arabic text regardless.
@MainActor
private func previewState(surah: String, reciter: String) -> PlayerState {
    let state = PlayerState.preview()
    let item = Surah(id: 4, name: surah, revelationPlace: .medinan, totalVerses: 176, transliteration: surah)
    state.surahs = [item]
    state.selectedSurah = item
    state.selectedReciter = .make(
        reciterId: 1, reciterName: reciter, moshafId: 1, moshafName: "", server: ""
    )
    return state
}

private struct AccessoryPreview: View {
    let playerState: PlayerState

    var body: some View {
        TabView {
            Tab("Home", systemImage: "house") { Color.clear }
            Tab("Favorites", systemImage: "heart") { Color.clear }
        }
        .tabViewBottomAccessory {
            PlayerBottom(playerState: playerState)
        }
    }
}

/// English (left) and Arabic (right) side by side, to compare size, weight and spacing.
#Preview("English | Arabic", traits: .fixedLayout(width: 800, height: 220)) {
    HStack(spacing: 0) {
        AccessoryPreview(playerState: previewState(surah: "An-Nisa", reciter: "Mohammed Siddiq Al-Minshawi"))
            .environment(\.locale, Locale(identifier: "en"))
            .environment(\.layoutDirection, .leftToRight)

        AccessoryPreview(playerState: previewState(surah: "النساء", reciter: "محمد صديق المنشاوي"))
            .environment(\.locale, Locale(identifier: "ar"))
            .environment(\.layoutDirection, .rightToLeft)
    }
    .preferredColorScheme(.dark)
}
#endif
