import SwiftUI

struct ReciterContainer: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showReciterShown = false
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var topSafeInset: CGFloat = 0

    @ScaledMetric(relativeTo: .body) private var firstNameSize: CGFloat = 18
    @ScaledMetric(relativeTo: .largeTitle) private var lastNameSize: CGFloat = 80
    @ScaledMetric(relativeTo: .largeTitle) private var controlSize: CGFloat = 50

    private var baseHeight: CGFloat {
        horizontalSizeClass == .regular ? 500 : 270
    }

    var body: some View {

        VStack {
            Spacer()

            VStack(spacing: 0) {
                let parts = ReciterNameParser.split(playerState.selectedReciter.reciter.name)
                if let last = parts.last {
                    Text(parts.first)
                        .font(.system(size: firstNameSize))
                        .contentTransition(.numericText())
                    Text(last)
                        .font(.system(size: lastNameSize))
                        .fontWeight(.black)
                        .fontWidth(.expanded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                        .padding(.top, 25)

                } else {
                    Text(parts.first)
                        .font(.system(size: lastNameSize))
                        .fontWeight(.black)
                        .fontWidth(.expanded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                }
            }
            .padding(.horizontal, 16)
            .animation(.snappy, value: playerState.selectedReciter)
            Text("•")

            ZStack {
                Text(playerState.selectedReciter.formattedMoshafName)
                    .lineLimit(2)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 56)
                    .frame(maxWidth: .infinity)
                Button {
                    showReciterShown = true
                } label: {
                    DirectionalImage("chevron.right", rtl: "chevron.left")
                }
                .foregroundStyle(.white)
                .frame(width: controlSize, height: controlSize)
                .glassEffect()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture { showReciterShown = true }
            .padding(.horizontal)

            Spacer()

        }
        .padding(.top, topSafeInset)
        .padding(.bottom)

        .foregroundStyle(Color.homeBackground)
        .frame(maxWidth: .infinity)
        .frame(minHeight: baseHeight + topSafeInset)
        .background(Color.selectedText)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 0
        ))
        .sheet(
            isPresented: $showReciterShown,
            onDismiss: { reciterViewModel.query = "" },
            content: {
                ReciterPickerSheet(
                    reciterViewModel: reciterViewModel,
                    playerState: playerState
                )
                .presentationDetents([.large])
            }
        )

    }

}

#Preview {
    ReciterContainer(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
