import SwiftUI

struct PlayerSurahTitle: View {
    let id: Int

    private var key: String { String(format: "surah%03d", id) }
    private var font: Font { .custom("surah-name-v4", size: 170) }

    var body: some View {
        ZStack {
            Text(key)
                .font(font)
                .foregroundStyle(.black)
                .offset(y: 10)
                .blur(radius: 18)
                .opacity(0.5)
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
        .contentTransition(.numericText(value: Double(id)))
        .animation(.smooth, value: id)
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

#Preview("Content transition") {
    @Previewable @State var id = 1

    VStack(spacing: 32) {
        PlayerSurahTitle(id: id)
            .contentTransition(.numericText(value: Double(id)))
            .animation(.smooth, value: id)

        HStack(spacing: 24) {
            Button("Prev") { id = max(1, id - 1) }
            Button("Next") { id = min(114, id + 1) }
        }
    }
    .padding()
}
