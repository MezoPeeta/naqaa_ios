//
//  FavoritesView.swift
//  ensat
//
//  Created by Mazen on 08/08/2026.
//

import OSLog
import SwiftData
import SwiftUI

struct FavoritesView: View {
    let playerState: PlayerState

    @Environment(\.modelContext) private var modelContext
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Query(sort: \FavoriteTrack.createdAt, order: .reverse) private var tracks: [FavoriteTrack]
    @Query(sort: \FavoriteReciter.createdAt, order: .reverse) private var reciters: [FavoriteReciter]
    @Query private var downloads: [DownloadedTrack]

    @State private var selectedTab: FavoritesTab = .surahs

    private enum FavoritesTab: Hashable {
        case surahs, reciters
    }

    /// The tab actually shown: falls back to whichever collection has items.
    private var activeTab: FavoritesTab {
        if tracks.isEmpty { return .reciters }
        if reciters.isEmpty { return .surahs }
        return selectedTab
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color.homeBackground.ignoresSafeArea()

                if tracks.isEmpty && reciters.isEmpty {
                    ContentUnavailableView(
                        "No Favorites", systemImage: "heart",
                        description: Text("Tap the heart on a surah or reciter to save it here."))
                } else {
                    favoritesList
                }
            }
        }
    }

    private var favoritesList: some View {
        let surahsByID = surahsByID
        let downloadCounts = DownloadedTrack.counts(in: downloads)
        return List {
            if activeTab == .surahs {
                header
                    .listRowBackground(Color.clear)
                    .listRowSeparator(.hidden)
                    .listRowInsets(EdgeInsets(top: 0, leading: 16, bottom: 0, trailing: 16))
            }
            if activeTab == .surahs {
                Section {
                    ForEach(tracks) { track in
                        let isSelected = isCurrent(track)
                        Button { play(track) } label: {
                            HStack(alignment: .center) {
                                row(track, surah: surahsByID[track.surahId], isSelected: isSelected)
                                Spacer()
                                PlaybackIndicator(
                                    isSelected: isSelected,
                                    isPlaying: isSelected && playerState.isPlaying
                                )
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .contextMenu {
                            Button("Remove", systemImage: "heart.slash", role: .destructive) {
                                delete([track])
                            }
                        }
                    }
                    .onDelete { offsets in delete(offsets.map { tracks[$0] }) }
                }
            }
            if activeTab == .reciters {
                Section {
                    ForEach(reciters) { reciter in
                        let isSelected = playerState.selectedReciter.id == reciter.item.id
                        Button { playerState.selectReciter(reciter.item) } label: {
                            HStack {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(reciter.reciterName)
                                        .font(.headline)
                                        .foregroundStyle(isSelected ? Color.selectedText : .primary)
                                    Text(reciter.moshafName)
                                        .font(.subheadline)
                                        .foregroundStyle(.gray)
                                    DownloadedCountLabel(count: downloadCounts[reciter.item.id, default: 0])
                                }
                                Spacer()
                                if isSelected {
                                    Image(systemName: "checkmark")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(Color.selectedText)
                                }
                            }
                            .contentShape(Rectangle())
                        }
                        .accessibilityAddTraits(isSelected ? .isSelected : [])
                        .contextMenu {
                            Button("Remove", systemImage: "heart.slash", role: .destructive) {
                                delete([reciter])
                            }
                        }
                    }
                    .onDelete { offsets in delete(offsets.map { reciters[$0] }) }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .environment(\.defaultMinListRowHeight, 0)
        .listSectionSpacing(activeTab == .reciters ? .custom(0) : .default)
        .animation(reduceMotion ? nil : .smooth, value: activeTab)
        .navigationTitle("Favorites")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if !tracks.isEmpty && !reciters.isEmpty {
                ToolbarItem(placement: .principal) {
                    Picker("Favorites", selection: $selectedTab) {
                        Text("Surahs").tag(FavoritesTab.surahs)
                        Text("Reciters").tag(FavoritesTab.reciters)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 240)
                }
            }
        }
    }

    private var header: some View {
        ViewThatFits {
            HStack(spacing: 12) { playButton; shuffleButton }
            VStack(spacing: 12) { playButton; shuffleButton }
        }
        .controlSize(.large)
        .fixedSize(horizontal: false, vertical: true)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 4)
        .padding(.vertical, 8)
    }

    private var playButton: some View {
        Button { playAll(shuffled: false) } label: {
            Label("Play", systemImage: "play.fill")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
                .foregroundStyle(.black)
        }
        .buttonStyle(.borderedProminent)
    }

    private var shuffleButton: some View {
        Button { playAll(shuffled: true) } label: {
            Label("Shuffle", systemImage: "shuffle")
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
    }

    private func isCurrent(_ track: FavoriteTrack) -> Bool {
        playerState.selectedSurah?.id == track.surahId && playerState.selectedReciter.id == track.item.id
    }

    private func row(_ track: FavoriteTrack, surah: Surah?, isSelected: Bool) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Group {
                if let surah {
                    Text(surah.displayName)
                } else {
                    Text("Surah \(track.surahId)")
                }
            }
            .font(.headline)
            .foregroundStyle(isSelected ? Color.candy : .primary)
            Text(track.reciterName)
                .font(.subheadline)
                .foregroundStyle(.gray)
        }
    }

    private var surahsByID: [Int: Surah] {
        Dictionary(playerState.surahs.map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
    }

    private func entries() -> [QueueEntry] {
        tracks.queueEntries(surahs: playerState.surahs)
    }

    private func playAll(shuffled: Bool) {
        let queue = shuffled ? entries().shuffled() : entries()
        playerState.play(queue: queue)
    }

    /// Plays from `track` onward through the favorites list.
    private func play(_ track: FavoriteTrack) {
        if isCurrent(track) {
            playerState.togglePlayPause()
            return
        }
        let queue = entries()
        guard let index = queue.queueIndex(of: track) else { return }
        playerState.play(queue: queue, startAt: index)
    }

    private func delete<Model: PersistentModel>(_ models: [Model]) {
        models.forEach(modelContext.delete)
        do {
            try modelContext.save()
        } catch {
            Logger(subsystem: Bundle.main.bundleIdentifier ?? "ensat", category: "favorites")
                .error("Failed to save after deleting favorites: \(error)")
        }
    }
}

#Preview {
    // swiftlint:disable:next force_try
    let container = try! ModelContainer(
        for: FavoriteTrack.self, FavoriteReciter.self, DownloadedTrack.self,
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

    return FavoritesView(playerState: PlayerState())
        .modelContainer(container)
        .preferredColorScheme(.dark)
}
