import SwiftData
import SwiftUI
import PostHog

struct SurahListVIew: View {
    @State private var surahViewModel = SurahListViewModel()
    @Query private var downloads: [DownloadedTrack]
    @Environment(DownloadManager.self) private var downloadManager
    let playerState: PlayerState
    var query = ""
    /// Hides everything but surahs saved on this device for the selected reciter.
    var downloadedOnly = false
    /// Keeps every surah visible but dims and disables the ones that aren't saved (offline).
    var dimsUndownloaded = false

    private var downloadedIDs: Set<Int> {
        let item = playerState.selectedReciter
        return Set(downloads.filter { $0.reciterId == item.reciter.id && $0.moshafId == item.moshaf.id }.map(\.surahId))
    }

    var body: some View {
        Group {
            switch surahViewModel.state {
            case .idle:
                ContentUnavailableView("No Surahs", systemImage: "book.closed")
            case .loading:
                ProgressView()
            case .loaded:
                let downloadedIDs = downloadedIDs
                let all = surahViewModel.filteredSurahs(for: query)
                let surahs = downloadedOnly ? all.filter { downloadedIDs.contains($0.id) } : all
                LazyVStack(alignment: .leading, spacing: 24) {
                    ForEach(surahs.enumerated(), id: \.element.id) { index, surah in
                        let isSelected = playerState.selectedSurah?.id == surah.id
                        let isPlaying = isSelected && playerState.isPlaying

                        let isDownloaded = downloadedIDs.contains(surah.id)
                        let isUnavailable = dimsUndownloaded && !isDownloaded

                        HStack(spacing: 8) {
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
                            HStack(spacing: 16) {
                                Text("\(surah.id)")
                                    .font(.subheadline.monospacedDigit())
                                    .foregroundStyle(.secondary)
                                    .frame(minWidth: 28, alignment: .leading)
                                    .accessibilityHidden(true)

                                VStack(alignment: .leading) {
                                    Text(surah.displayName)
                                        .font(.headline)
                                        .foregroundStyle(isSelected ? Color.selectedText : .primary)
                                    (Text(
                                        LocalizedStringResource(
                                            "versesCount",
                                            defaultValue: "\(surah.totalVerses) verses"
                                        )
                                    ) + Text(" · ") + Text(surah.revelationPlace.label))
                                        .font(.caption)
                                        .foregroundStyle(Color.caption)
                                }
                                Spacer()
                                PlaybackIndicator(isSelected: isSelected, isPlaying: isPlaying)
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(PopPressStyle())
                        .accessibilityElement(children: .combine)
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .accessibilityValue(
                            isPlaying ? Text("Playing") : (isDownloaded ? Text("Downloaded") : Text(""))
                        )
                        .contextMenu {
                            if isDownloaded {
                                Button("Remove Download", systemImage: "trash", role: .destructive) {
                                    downloadManager.remove(surahId: surah.id, item: playerState.selectedReciter)
                                }
                                // The tab bar's mint tint reaches menu icons; keep the destructive red.
                                .tint(.red)
                            }
                        }
                        .disabled(isUnavailable)

                        // One control for every state so a finished download morphs into the badge.
                        // Fixed slot so the playback indicator stays aligned when the control is hidden.
                        Group {
                            if isDownloaded || !isUnavailable {
                                DownloadControl(
                                    surah: surah, item: playerState.selectedReciter,
                                    isDownloaded: isDownloaded, isSubtle: true
                                )
                            }
                        }
                        .frame(width: 44, height: 44)
                        }
                        .opacity(isUnavailable ? 0.4 : 1)
                        .animation(.smooth, value: isUnavailable)
                        .transition(.opacity)

                        if index < surahs.count - 1 {
                            Divider()
                        }

                    }

                }
                .animation(.smooth, value: downloadedOnly)

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed && !reduceMotion ? 0.96 : 1)
            .brightness(configuration.isPressed ? 0.06 : 0)
            .animation(
                .spring(response: 0.35, dampingFraction: 0.6),
                value: configuration.isPressed
            )
    }
}

#if DEBUG
#Preview {
    ScrollView {
        SurahListVIew(playerState: PlayerState())
            .padding()
            .preferredColorScheme(.dark)
    }
    // swiftlint:disable:next force_try
    .modelContainer(try! .preview)
    .environment(DownloadManager.preview)
}

#endif
