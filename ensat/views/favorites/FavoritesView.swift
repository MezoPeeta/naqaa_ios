//
//  FavoritesView.swift
//  ensat
//
//  Created by Mazen on 08/08/2026.
//

import SwiftData
import SwiftUI

struct FavoritesView: View {
    var playerState: PlayerState?

    @Environment(\.modelContext) private var modelContext
    @Query(sort: \FavoriteTrack.createdAt, order: .reverse) private var tracks: [FavoriteTrack]
    @Query(sort: \FavoriteReciter.createdAt, order: .reverse) private var reciters: [FavoriteReciter]

    var body: some View {
        NavigationStack {
            ZStack {
                Color.homeBackground.ignoresSafeArea()

                if tracks.isEmpty && reciters.isEmpty {
                    ContentUnavailableView("No favorites now", systemImage: "heart.fill")
                } else {
                    ContainerShapeView { _ in
                        favoritesList(showsHeader: true)
                    } wide: { size in
                        HStack {
                            ScrollView {
                                header(iconSize: min(250, size.height * 0.45))
                                    .padding(.vertical)
                            }
                            .scrollIndicators(.hidden)
                            favoritesList(showsHeader: false)
                                .padding(.top)
                        }
                    }
                }
            }
        }
    }

    private func favoritesList(showsHeader: Bool) -> some View {
        List {
            if showsHeader {
                header(iconSize: 250)
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
            }
            if !tracks.isEmpty {
                Section("Surahs") {
                    ForEach(tracks) { track in
                        let isSelected = isCurrent(track)
                        Button { play(track) } label: {
                            HStack(alignment: .center) {
                                row(track, isSelected: isSelected)
                                Spacer()
                                PlaybackIndicator(
                                    isSelected: isSelected,
                                    isPlaying: isSelected && playerState?.isPlaying == true
                                )
                            }
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets.map { tracks[$0] }) }
                }
            }
            if !reciters.isEmpty {
                Section("Reciters") {
                    ForEach(reciters) { reciter in
                        Button { playerState?.selectReciter(reciter.item) } label: {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(reciter.reciterName).font(.headline)
                                Text(reciter.moshafName)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .buttonStyle(.plain)
                    }
                    .onDelete { offsets in delete(offsets.map { reciters[$0] }) }
                }
            }
        }
        .scrollContentBackground(.hidden)
    }

    private func header(iconSize: CGFloat) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.fill")
                .font(.system(size: iconSize * 0.52))
                .foregroundStyle(.selectedText)
                .frame(width: iconSize, height: iconSize)
                .background(.selectedText.opacity(0.15), in: RoundedRectangle(cornerRadius: 32, style: .continuous))

            HStack(spacing: 12) {
                headerButton("Play", systemImage: "play.fill") { playAll(shuffled: false) }
                headerButton("Shuffle", systemImage: "shuffle") { playAll(shuffled: true) }
            }
        }
        .frame(maxWidth: .infinity)
    }

    private func headerButton(
        _ title: LocalizedStringKey, systemImage: String, action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: systemImage)
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .foregroundStyle(.white)

        }
        .buttonStyle(.glass)

        .disabled(tracks.isEmpty)
    }

    private func isCurrent(_ track: FavoriteTrack) -> Bool {
        playerState?.selectedSurah?.id == track.surahId && playerState?.selectedReciter.id == track.item.id
    }

    private func row(_ track: FavoriteTrack, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(surah(for: track)?.displayName ?? "Surah \(track.surahId)")
                .font(.headline)
                .foregroundStyle(isSelected ? Color.selectedText : .primary)
            Text(track.reciterName)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func surah(for track: FavoriteTrack) -> Surah? {
        playerState?.surahs.first { $0.id == track.surahId }
    }

    private func entries() -> [QueueEntry] {
        tracks.compactMap { track in
            surah(for: track).map { QueueEntry(surah: $0, reciter: track.item) }
        }
    }

    private func playAll(shuffled: Bool) {
        let queue = shuffled ? entries().shuffled() : entries()
        playerState?.play(queue: queue)
    }

    /// Plays from `track` onward through the favorites list.
    private func play(_ track: FavoriteTrack) {
        if isCurrent(track) {
            playerState?.togglePlayPause()
            return
        }
        let queue = entries()
        guard let index = queue.firstIndex(where: {
            $0.surah.id == track.surahId && $0.reciter.id == track.item.id
        }) else { return }
        playerState?.play(queue: queue, startAt: index)
    }

    private func delete<Model: PersistentModel>(_ models: [Model]) {
        models.forEach(modelContext.delete)
        try? modelContext.save()
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: FavoriteTrack.self, FavoriteReciter.self,
        configurations: ModelConfiguration(isStoredInMemoryOnly: true)
    )
    let item = ReciterMoshafItem.make(
        reciterId: 1, reciterName: "Mishary Alafasy",
        moshafId: 1, moshafName: "Hafs an Asim - Murattal",
        server: "https://server8.mp3quran.net/afs"
    )
    container.mainContext.insert(FavoriteReciter(item: item))
    container.mainContext.insert(FavoriteTrack(surahId: 1, item: item))
    container.mainContext.insert(FavoriteTrack(surahId: 18, item: item))

    return FavoritesView()
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
