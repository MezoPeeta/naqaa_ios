import SwiftUI

struct ReciterPickerSheet: View {

    let reciterViewModel: ReciterContainer.ViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Group {
            switch reciterViewModel.state {
            case .idle:
                Text("No Reciters")
            case .loading:
                ProgressView()
            case .loaded(let reciters):
                List(reciters) { item in
                    Button {
                        reciterViewModel.select(item)
                        dismiss()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(item.reciter.name)
                                    .font(.headline)
                                    .foregroundStyle(
                                        reciterViewModel.isSelected(id: item.id) ? Color.yellow : .primary
                                    )
                                Text(item.moshaf.name)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            if reciterViewModel.isSelected(id: item.id) {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.tint)
                            }
                        }
                    }
                    .buttonStyle(.plain)
                    .padding(.vertical, 4)
                    .listRowBackground(Color.clear)
                    .onTapGesture {
                        reciterViewModel.select(item)
                    }
                }
                .scrollContentBackground(.hidden)

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
    ReciterPickerSheet(reciterViewModel: ReciterContainer.ViewModel())
}
