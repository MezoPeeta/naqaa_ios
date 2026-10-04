import SwiftUI

struct PlayerSurahTitle: View {
    let name: String

    var body: some View {
        Text(name)
            .font(.largeTitle)
            .bold()
            .fontWidth(.expanded)
            .multilineTextAlignment(.center)
            .minimumScaleFactor(0.6)
            .lineLimit(2)
            .frame(maxWidth: .infinity)
    }
}

#Preview {
    PlayerSurahTitle(name: "Al-Baqarah")
        .padding()
}
