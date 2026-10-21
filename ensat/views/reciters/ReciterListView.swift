import SwiftData
import SwiftUI
import PostHog

struct ReciterListView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var query = ""
    /// Shows only reciters that have at least one surah saved on this device.
    var downloadedOnly = false
    var onSelect: ((ReciterMoshafItem) -> Void)?

    /// One observation for the whole list instead of one per row.
    @Query private var favoriteReciters: [FavoriteReciter]

    @Query private var downloads: [DownloadedTrack]
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    private var favoriteKeys: Set<String> { Set(favoriteReciters.map(\.key)) }

    var body: some View {
        Group {
            switch reciterViewModel.state {
            case .idle:
                ContentUnavailableView("No Reciters", systemImage: "person")
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .loaded:
                let downloadCounts = DownloadedTrack.counts(in: downloads)
                let matches = reciterViewModel.filteredReciters(for: query.isEmpty ? reciterViewModel.query : query)
                let reciters = downloadedOnly ? matches.filter { downloadCounts[$0.id] != nil } : matches
                if reciters.isEmpty {
                    ContentUnavailableView(
                        "No Reciters Found",
                        systemImage: "person",
                        description: Text("Try a different name")
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(reciters) { item in
                            VStack(spacing: 0) {
                            HStack {
                                Button {
                                    PostHogSDK.shared.capture(
                                        "reciter_selected",
                                        properties: ["reciter_moshaf_id": item.id]
                                    )
                                    reciterViewModel.select(item)
                                    playerState.selectReciter(item)
                                    onSelect?(item)
                                } label: {
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(item.reciter.name)
                                                .font(.headline)
                                                .foregroundStyle(
                                                    reciterViewModel.isSelected(id: item.id)
                                                        ? Color.selectedText : .primary
                                                )
                                            Text(item.formattedMoshafName)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            DownloadedCountLabel(count: downloadCounts[item.id, default: 0])
                                        }
                                        Spacer()
                                        if reciterViewModel.isSelected(id: item.id) {
                                            Image(systemName: "checkmark")
                                                .foregroundStyle(.selectedText)
                                        }
                                    }
                                    .padding(.vertical, 12)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .contentShape(Rectangle())
                                }
                                .buttonStyle(.plain)

                                FavoriteReciterButton(item: item, isFavorite: favoriteKeys.contains(item.id))
                            }
                            Divider()
                            }
                            .transition(.opacity)
                        }
                    }
                    .animation(reduceMotion ? nil : .smooth, value: downloadedOnly)

                }
            case .error(let error):
                ContentUnavailableView(
                    "Unable to Load Reciters",
                    systemImage: "exclamationmark.triangle",
                    description: Text(error)
                )
            }
        }
        .task {
            await reciterViewModel.load()
        }
    }
}
