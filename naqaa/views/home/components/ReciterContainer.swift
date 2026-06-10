import SwiftUI


struct ReciterContainer: View {
    @State private var showReciterShown = false
    @State private var reciterViewModel = ViewModel()
    

    var body: some View{
        VStack(alignment:.leading){
            Text(reciterViewModel.selected.reciter.name)
            Text(reciterViewModel.selected.moshaf.name)
                .foregroundStyle(.secondary)
                .font(.caption)

           
        }
        .padding(20)
        .frame(maxWidth: .infinity,maxHeight: 80,alignment: .leading)
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .glassEffect(
            in:RoundedRectangle(cornerRadius: 16))
     
        .onTapGesture {
            showReciterShown = true
        }
        .sheet(isPresented: $showReciterShown){
            ReciterPickerSheet(reciterViewModel: reciterViewModel)
        }
        

    }
}


#Preview {
    ReciterContainer()
}
