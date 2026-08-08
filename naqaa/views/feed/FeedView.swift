import SwiftUI

struct FeedView: View {
    let playerState: PlayerState
    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading) {
                        ReciterContainer(playerState: playerState)

                        Spacer(minLength: 30)
                        SurahListVIew(playerState: playerState)
                    }
                    .padding(20)
                }
            }

        }

    }
}

#Preview {
    FeedView(playerState: PlayerState())
}
