import SwiftUI

struct SurahListVIew: View {
    @State private var surahViewModel = SurahListViewModel()
    let playerState: PlayerState

    var body: some View {
        Group {
            switch surahViewModel.state {
            case .idle:
                ContentUnavailableView("No Surahs", systemImage: "book.closed")
            case .loading:
                ProgressView()
            case .loaded:
                LazyVStack(alignment: .leading, spacing: 24) {
                    let surahs = surahViewModel.filteredSurahs
                    ForEach(surahs.enumerated(), id: \.element.id) {
                        index,
                        surah in
                        let isSelected = surahViewModel.isSelected(id: surah.id)
                        Button {
                            playerState.play(surah)
                            surahViewModel.selectedSurah = surah
                        } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack {
                                    VStack(alignment: .leading) {
                                        Text(surah.displayName).font(.headline)
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
                                    if isSelected {
                                        Image(systemName: "scribble")
                                            .font(.system(size: 22))
                                            .accessibilityLabel("Selected")
                                    }

                                }

                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

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

#Preview {
    ZStack {
        SurahListVIew(playerState: PlayerState())

    }
}
