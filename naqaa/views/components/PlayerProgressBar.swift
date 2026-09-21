import SwiftUI

struct PlayerProgressBar: View {
    let progress: Double

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.gray.opacity(0.15))

                Capsule()
                    .fill(Color.selectedText)
                    .frame(width: geo.size.width * min(max(progress, 0), 1))
            }
        }
        .frame(height: 8)
        .animation(.linear(duration: 0.2), value: progress)
    }
}

#Preview {
    PlayerProgressBar(progress: 0.5)
        .padding()
}
