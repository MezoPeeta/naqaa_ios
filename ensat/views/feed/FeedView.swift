import SwiftData
import SwiftUI

struct FeedView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState

    @Environment(NetworkMonitor.self) private var network
    @Query private var downloads: [DownloadedTrack]
    /// While offline, surahs that aren't saved are dimmed. The user can turn this off because
    /// the connection reading can be wrong.
    @State private var emphasizesDownloadsOffline = true
    /// The user's own filter, independent of the connection.
    @State private var filtersToDownloaded = false

    private var dimsUndownloaded: Bool { network.isOffline && emphasizesDownloadsOffline }

    private var downloadedCount: Int {
        let item = playerState.selectedReciter
        return downloads.filter { $0.reciterId == item.reciter.id && $0.moshafId == item.moshaf.id }.count
    }

    var body: some View {
        GeometryReader { proxy in
            NavigationStack {
                ZStack(alignment: .top) {
                    Color.homeBackground.ignoresSafeArea()

                    // Decides on the available space, not the device, so it also adapts to
                    // iPhone Duo's inner display, iPad, landscape and split view.
                    ContainerShapeView { _ in
                        stackedLayout(topSafeInset: proxy.safeAreaInsets.top)
                    } wide: { size in
                        sideBySideLayout(size: size, topSafeInset: proxy.safeAreaInsets.top)
                    }
                }
                .toolbar(.hidden, for: .navigationBar)
                .overlay(alignment: .top) {
                    if network.isOffline {
                        offlineBanner
                            .padding(.horizontal, 20)
                            .padding(.top, proxy.safeAreaInsets.top + 4)
                            .transition(.opacity.combined(with: .move(edge: .top)))
                    }
                }
                .animation(.smooth, value: network.isOffline)
                .onChange(of: network.isOffline) { _, isOffline in
                    if !isOffline { emphasizesDownloadsOffline = true }
                }
            }
        }

    }

    /// Reciter header on top, surahs below; one scroll view.
    private func stackedLayout(topSafeInset: CGFloat) -> some View {
        ScrollView {
            VStack(alignment: .leading) {
                ReciterContainer(
                    reciterViewModel: reciterViewModel,
                    playerState: playerState,
                    topSafeInset: topSafeInset
                )
                surahSection
            }
        }
        .ignoresSafeArea(edges: .top)
    }

    /// Reciter pinned on the leading side, surahs scrolling beside it.
    private func sideBySideLayout(size: CGSize, topSafeInset: CGFloat) -> some View {
        HStack(spacing: 0) {
            ReciterContainer(
                reciterViewModel: reciterViewModel,
                playerState: playerState,
                topSafeInset: topSafeInset,
                fillsHeight: true
            )
            .frame(width: min(max(size.width * 0.4, 320), 480))
            .ignoresSafeArea(edges: .top)

            ScrollView {
                surahSection
                    .padding(.top, topSafeInset)
            }
            .ignoresSafeArea(edges: .top)
        }
    }

    private var surahSection: some View {
        VStack(alignment: .leading) {
            HStack {
                Text("Surahs")
                    .foregroundStyle(.secondary)
                    .font(.subheadline.bold())
                Spacer()
                // Nothing to filter to means no chip, unless it's on and needs to stay reachable to turn off.
                if downloadedCount > 0 || filtersToDownloaded {
                    FilterChip(
                        title: downloadedCount > 0 ? "Downloaded \(downloadedCount)" : "Downloaded",
                        systemImage: "arrow.down.circle",
                        isOn: $filtersToDownloaded
                    )
                    .contentTransition(.numericText(value: Double(downloadedCount)))
                    .transition(.scale(scale: 0.2, anchor: .trailing).combined(with: .opacity))
                }
            }
            .animation(.bouncy(duration: 0.45), value: downloadedCount > 0)
            Spacer(minLength: 16)
            SurahListVIew(
                playerState: playerState,
                downloadedOnly: filtersToDownloaded,
                dimsUndownloaded: dimsUndownloaded
            )
        }
        .padding(20)
        // Removing the last download leaves nothing to filter to, so return to the full list.
        .onChange(of: downloadedCount) {
            if downloadedCount == 0 { filtersToDownloaded = false }
        }
    }

    /// Stays on screen while offline, so scrolling never hides why some surahs are dimmed.
    private var offlineBanner: some View {
        HStack {
            Label("Offline", systemImage: "wifi.slash")
                .font(.footnote.bold())
            Spacer()
            FilterChip(
                title: "Downloads only",
                systemImage: "arrow.down.circle",
                isOn: $emphasizesDownloadsOffline
            )
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

#if DEBUG
#Preview("Tall") {
    FeedView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
    .environment(NetworkMonitor())
    .environment(DownloadManager.preview)
    // swiftlint:disable:next force_try
    .modelContainer(try! .preview)
}

#Preview("Wide", traits: .fixedLayout(width: 900, height: 600)) {
    FeedView(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
    .environment(NetworkMonitor())
    .environment(DownloadManager.preview)
    // swiftlint:disable:next force_try
    .modelContainer(try! .preview)
    .preferredColorScheme(.dark)
}
#endif
