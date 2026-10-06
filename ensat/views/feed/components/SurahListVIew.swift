import SwiftUI
import PostHog

struct SurahListVIew: View {
    @State private var surahViewModel = SurahListViewModel()
    let playerState: PlayerState
    var query = ""
    
    var body: some View {
        Group {
            switch surahViewModel.state {
            case .idle:
                ContentUnavailableView("No Surahs", systemImage: "book.closed")
            case .loading:
                ProgressView()
            case .loaded:
                LazyVStack(alignment: .leading, spacing: 24) {
                    let surahs = surahViewModel.filteredSurahs(for: query)
                    ForEach(surahs.enumerated(), id: \.element.id) { index, surah in
                        let isSelected = playerState.selectedSurah?.id == surah.id
                        let isPlaying = isSelected && playerState.isPlaying
                        
                        Button {
                            if !isSelected {
                                PostHogSDK.shared.capture(
                                    "surah_played",
                                    properties: ["surah_id": surah.id]
                                )
                                playerState.play(surah)
                                surahViewModel.selectedSurah = surah
                                
                            } else {
                                playerState.togglePlayPause()
                            }
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(surah.displayName)
                                            .font(.headline)
                                            .foregroundStyle(isSelected ? Color.selectedText : .primary)
                                        HStack(alignment: .center) {
                                            Text(
                                                LocalizedStringResource(
                                                    "versesCount",
                                                    defaultValue:
                                                        "\(surah.totalVerses) verses"
                                                )
                                            )
                                            Divider().overlay { Color.white }
                                            Text(surah.revelationPlace.label)
                                            
                                        }
                                        .foregroundStyle(Color.caption)
                                        
                                        .font(.caption)
                                    }
                                    Spacer()
                                    DirectionalImage(isSelected ? "waveform" : "play")
                                        .font(.system(size: 18))
                                        .foregroundStyle(isSelected ? Color.selectedText : Color.primary)
                                        .contentTransition(.symbolEffect(.replace))
                                        .symbolEffect(
                                            .variableColor.cumulative,
                                            options: .repeating,
                                            isActive: isPlaying
                                        )
                                        .accessibilityLabel(isSelected ? "Playing" : "Play")
                                    
                                }
                                
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                        .modifier(PopPressEffect())
                        
                        if index < surahs.count - 1 {
                            Divider().overlay { Color.white.opacity(0.4) }
                        }
                        
                    }
                    
                }
                .toolbar(.hidden, for: .navigationBar)
                
            case .error(let error):
                Text(error)
            }
        }
        .task {
            loadSurahs()
        }
    }
    
    private func loadSurahs() {
        surahViewModel.loadLocal()
        if case .loaded(let surahs) = surahViewModel.state {
            playerState.surahs = surahs
        }
    }
    
}

private struct PopPressStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

private struct PopPressEffect: ViewModifier {
    @GestureState private var isPressing = false
    
    func body(content: Content) -> some View {
        content
            .scaleEffect(isPressing ? 0.955 : 1)
            .brightness(isPressing ? 0.06 : 0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.6),
                value: isPressing
            )
            .simultaneousGesture(
                DragGesture(minimumDistance: 0)
                    .updating($isPressing) { _, state, _ in state = true }
            )
    }
}

#Preview {
    ScrollView{
        SurahListVIew(playerState: PlayerState())
            .padding()
            .preferredColorScheme(.dark)
    }
}
