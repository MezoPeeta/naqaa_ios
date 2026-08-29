import SwiftUI

struct ReciterContainer: View {
    @State private var showReciterShown = false
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var topSafeInset: CGFloat = 0
    
    var body: some View {
        
        VStack{
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                
                Text("محمد صديق")
                    .font(.system(size: 18))
                
                Text("المنشاوي")
                    .font(.system(size: 80))
                    .fontWeight(.black)
                
            }
            Text("•")

            ZStack {
                Text("حفص عن عاصم")
                Button(action:{}) {
                    DirectionalImage("chevron.right", rtl: "chevron.left")
                }
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .glassEffect()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(.horizontal)

            Spacer(minLength: 0)
            
        }
        .padding(.top, topSafeInset)
        .foregroundStyle(Color.background)
        .frame(maxWidth: .infinity)
        .frame(height: 300 + topSafeInset)
        .background(Color.selectedText)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 0
        ))
        
    }
}

#Preview {
    ReciterContainer(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
