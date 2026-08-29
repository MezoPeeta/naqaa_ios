import SwiftUI

struct ReciterPickerSheet: View {

    @Bindable var reciterViewModel: ReciterViewModel
    var playerState: PlayerState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            NavigationStack {
                ScrollViewReader { proxy in
                    ScrollView {
                        ReciterListView(
                            reciterViewModel: reciterViewModel,
                            playerState: playerState,
                            onSelect: { _ in dismiss() }
                        )
                        .padding(.horizontal)
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
                        .onAppear {
                            let scroll = {
                                proxy.scrollTo(reciterViewModel.selected.id, anchor: .center)
                            }
                            if reduceMotion {
                                scroll()
                            } else {
                                withAnimation { scroll() }
                            }
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
