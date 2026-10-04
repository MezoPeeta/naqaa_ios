import SwiftUI

struct HeaderView: View {
    let symbolSet: [String] = ["heart.fill", "gearshape"]
    @Namespace var namespace

    var body: some View {

        VStack {
            HStack {
                Text("Peace be upon you")
                    .font(.title).bold()
                    .foregroundStyle(.white)

                Spacer()
                GlassEffectContainer(spacing: 20.0) {
                    HStack(spacing: 20.0) {
                        ForEach(symbolSet, id: \.self) { symbol in
                            Image(systemName: symbol)
                                .frame(width: 50, height: 50)
                                .glassEffect()
                                .glassEffectUnion(id: symbol, namespace: namespace)
                                .accessibilityLabel(symbolAccessibilityLabel(for: symbol))

                        }
                    }
                }

            }

        }
    }

    private func symbolAccessibilityLabel(for symbol: String) -> String {
        switch symbol {
        case "heart.fill": "Favorites"
        case "gearshape": "Settings"
        default: symbol
        }
    }
}

#Preview {
    HeaderView()
}
