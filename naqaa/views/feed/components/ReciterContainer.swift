import SwiftUI

struct ReciterContainer: View {
    @State private var showReciterShown = false
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var topSafeInset: CGFloat = 0

    var body: some View {

        VStack {
            Spacer(minLength: 0)

            VStack(spacing: 20) {
                let parts = splitReciterName(playerState.selectedReciter.reciter.name)
                if let last = parts.last {
                    Text(parts.first)
                        .font(.system(size: 18))
                        .contentTransition(.numericText())

                    Text(last)
                        .font(.system(size: 80))
                        .fontWeight(.black)
                        .fontWidth(.expanded)
                        .lineLimit(1)
                        .minimumScaleFactor(0.4)
                        .contentTransition(.numericText())
                } else {
                    Text(parts.first)
                        .font(.system(size: 80))
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
                Button(action: { showReciterShown = true }) {
                    DirectionalImage("chevron.right", rtl: "chevron.left")
                }
                .foregroundStyle(.white)
                .frame(width: 50, height: 50)
                .glassEffect()
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .contentShape(Rectangle())
            .onTapGesture { showReciterShown = true }
            .padding(.horizontal)

            Spacer(minLength: 0)

        }
        .padding(.top, topSafeInset)
        .foregroundStyle(Color.background)
        .frame(maxWidth: .infinity)
        .frame(height: 270 + topSafeInset)
        .background(Color.selectedText)
        .clipShape(UnevenRoundedRectangle(
            topLeadingRadius: 0,
            bottomLeadingRadius: 16,
            bottomTrailingRadius: 16,
            topTrailingRadius: 0
        ))
        .sheet(
            isPresented: $showReciterShown,
            onDismiss: { reciterViewModel.query = "" }
        ) {
            ReciterPickerSheet(
                reciterViewModel: reciterViewModel,
                playerState: playerState
            )
            .presentationDetents([.large])
        }

    }

    private func splitReciterName(_ name: String) -> (first: String, last: String?) {
        let sanitized = name.replacingOccurrences(of: "Al-", with: "Al")
        let components = sanitized.split(separator: " ").map(String.init)
        guard components.count > 1, let last = components.last else { return (sanitized, nil) }
        return (components.dropLast().joined(separator: " "), last)
    }
}

#Preview {
    ReciterContainer(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}
