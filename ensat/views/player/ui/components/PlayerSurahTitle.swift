import SwiftUI

struct PlayerSurahTitle: View {
    let id: Int

    private var key: String { String(format: "surah%03d", id) }
    private var font: Font { .custom("surah-name-v4", size: 170) }

    var body: some View {
        ZStack {
            // Soft ambient shadow — lifts the glyph off the background
            Text(key)
                .font(font)
                .foregroundStyle(.black)
                .offset(y: 10)
                .blur(radius: 18)
                .opacity(0.5)
            // Tight contact shadow — defines the 3D edge
            Text(key)
                .font(font)
                .foregroundStyle(.black)
                .offset(y: 3)
                .blur(radius: 4)
                .opacity(0.6)
            // Face
            Text(key)
                .font(font)
        }
        .bold()
        .fontWidth(.expanded)
        .multilineTextAlignment(.center)
        .minimumScaleFactor(0.6)
        .lineLimit(1)
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    VStack(spacing: 16) {
        PlayerSurahTitle(id: 1)
        PlayerSurahTitle(id: 2)
        PlayerSurahTitle(id: 114)
    }
    .padding()
}
