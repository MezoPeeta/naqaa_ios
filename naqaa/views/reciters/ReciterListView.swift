import SwiftUI

struct ReciterListView: View {
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var query = ""
    var onSelect: ((ReciterMoshafItem) -> Void)?

    var body: some View {
        Group {
            switch reciterViewModel.state {
            case .idle:
                ContentUnavailableView("No Reciters", systemImage: "person")
            case .loading:
                ProgressView()
                    .frame(maxWidth: .infinity)
            case .loaded:
                let reciters = reciterViewModel.filteredReciters(for: query)
                if reciters.isEmpty {
                    ContentUnavailableView(
                        "No Reciters Found",
                        systemImage: "person",
                        description: Text("Try a different name")
                    )
                } else {
                    LazyVStack(alignment: .leading, spacing: 0) {
                        ForEach(reciters) { item in
                            Button {
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
                                        Text(item.moshaf.name)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
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
                            Divider()
                        }
                    }

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
        .toolbar(.hidden, for: .navigationBar)

    }
}
