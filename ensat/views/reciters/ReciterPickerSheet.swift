import SwiftData
import SwiftUI

struct ReciterPickerSheet: View {

    @Bindable var reciterViewModel: ReciterViewModel
    var playerState: PlayerState
    @Environment(\.dismiss) private var dismiss
    @Query private var downloads: [DownloadedTrack]
    @State private var filtersToDownloaded = false

    var body: some View {
        Group {
            NavigationStack {
                    ScrollView {
                        if !downloads.isEmpty {
                            // Nothing to filter to means no chip.
                            HStack {
                                FilterChip(
                                    title: "Downloaded",
                                    systemImage: "arrow.down.circle",
                                    isOn: $filtersToDownloaded
                                )
                                Spacer()
                            }
                            .padding(.horizontal)
                        }
                        ReciterListView(
                            reciterViewModel: reciterViewModel,
                            playerState: playerState,
                            downloadedOnly: filtersToDownloaded,
                            onSelect: { _ in dismiss() }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                        .searchable(
                            text: $reciterViewModel.query,
                            placement: .navigationBarDrawer(displayMode: .always)
                        )
                        // Removing the last download leaves nothing to filter to.
                        .onChange(of: downloads.isEmpty) {
                            if downloads.isEmpty { filtersToDownloaded = false }
                        }
                        .navigationTitle("Reciters")
                        .navigationBarTitleDisplayMode(.inline)
                        .toolbar {
                            ToolbarItem(placement: .topBarTrailing) {
                                Button("Done", systemImage: "xmark") {
                                    dismiss()
                                }
                                .labelStyle(.iconOnly)
                                .font(.title)
                            }

                }
            }
        }
    }
}

#Preview {
    ReciterPickerSheet(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
