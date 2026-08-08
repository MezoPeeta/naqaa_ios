import SwiftUI

struct ReciterPickerSheet: View {

    @Bindable var reciterViewModel: ReciterContainer.ViewModel
    var playerState: PlayerState
    @Environment(\.dismiss) private var dismiss
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            switch reciterViewModel.state {
            case .idle:
                ContentUnavailableView("No Reciters", systemImage: "person")
            case .loading:
                ProgressView()
            case .loaded:
                let reciters = reciterViewModel.filteredReciters

                NavigationStack {
                    ScrollViewReader { proxy in
                        if reciters.isEmpty {
                            ContentUnavailableView {
                                Label("No Reciter", systemImage: "person")
                            } description: {
                                Text("try different names")
                            }
                        }
                        List(reciters) { item in
                            let isSelected = reciterViewModel.isSelected(
                                id: item.id
                            )
                            Button {
                                reciterViewModel.select(item)
                                playerState.selectReciter(item)
                                dismiss()
                            } label: {
                                HStack {
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(item.reciter.name)
                                            .font(.headline)
                                            .foregroundStyle(
                                                isSelected
                                                ? Color.selectedText : .primary
                                            )
                                        Text(item.moshaf.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                    if isSelected {
                                        Image(systemName: "checkmark")
                                            .foregroundStyle(.selectedText)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                            .padding(.vertical, 4)
                            .listRowBackground(Color.clear)
                        }
                        .navigationTitle("Reciters")
                        .navigationBarTitleDisplayMode(.inline)
                        .scrollContentBackground(.hidden)
                        .searchable(text: $reciterViewModel.query)
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
                            if reduceMotion {
                                proxy.scrollTo(reciterViewModel.selected.id, anchor: .center)
                            } else {
                                withAnimation { proxy.scrollTo(reciterViewModel.selected.id, anchor: .center) }
                            }
                        }

                    }
                }

            case .error(let error):
                Text("Error : \(error)")
            }
        }
        .task {
            await reciterViewModel.load()
        }
    }
}

#Preview {
    ReciterPickerSheet(
        reciterViewModel: ReciterContainer.ViewModel(),
        playerState: PlayerState()
    )
}
