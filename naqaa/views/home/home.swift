import SwiftUI

struct HomeView: View {
    
    
    var body: some View {
        NavigationStack{
            ZStack(alignment: .top){
                Color.accent.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading){
                        HeaderView()
                        ReciterContainer()
                        
                        Spacer(minLength: 30)
                        SurahListVIew()
                    }
                    .padding(20)
                }
            }
            
        }
      
        
        
    }
}


#Preview {
    HomeView()
}
