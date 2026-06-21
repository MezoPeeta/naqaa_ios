import SwiftUI

struct ReciterContainer: View {
    @State private var showReciterShown = false
    @State private var reciterViewModel = ViewModel()

    var body: some View {
        Button {
            showReciterShown = true
        } label: {
            VStack(alignment: .leading) {
                Text(reciterViewModel.selected.reciter.name)
                Text(reciterViewModel.selected.moshaf.name)
                    .foregroundStyle(.secondary)
                    .font(.caption)

            }
            .padding(20)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(RoundedRectangle(cornerRadius: 16))

            

        }
        .buttonStyle(.plain)
        .glassEffect(
            in: RoundedRectangle(cornerRadius: 16)
        )
        .sheet(isPresented: $showReciterShown) {
            ReciterPickerSheet(reciterViewModel: reciterViewModel)
        }

    }
}

#Preview {
    ReciterContainer()
}
