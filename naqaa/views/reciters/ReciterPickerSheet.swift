import SwiftUI

struct ReciterPickerSheet: View {

    @Bindable var reciterViewModel: ReciterViewModel
    var playerState: PlayerState
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            NavigationStack {
                    ScrollView {
                        ReciterListView(
                            reciterViewModel: reciterViewModel,
                            playerState: playerState,
                            onSelect: { _ in dismiss() }
                        )
                        .padding(.horizontal)
                        .padding(.vertical, 8)
                    }
                        .searchable(
                            text: $reciterViewModel.query,
                            placement: .navigationBarDrawer(displayMode: .always)
                        )
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
