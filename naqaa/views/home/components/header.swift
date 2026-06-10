import SwiftUI


struct HeaderView:View {
    let symbolSet: [String] = ["heart.fill", "gearshape"]
    @Namespace var namespace

    var body: some View {
            
            VStack{
                HStack{
                    Text("Peace be upon you")
                        .font(.system(.title)).fontWeight(.semibold)
                        .foregroundStyle(.white)
                    
                    Spacer()
                    GlassEffectContainer(spacing: 20.0) {
                        HStack(spacing: 20.0) {
                            ForEach(symbolSet.indices, id: \.self) { item in
                                Image(systemName: symbolSet[item])
                                    .frame(width: 50, height: 50)
                                    .glassEffect()
                                    .glassEffectUnion(id: "1", namespace: namespace)

                                    
                                    
                            }
                        }
                    }

                }

            
            
        }
    }
}


#Preview {
    HeaderView()
}
