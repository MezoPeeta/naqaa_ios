import SwiftUI

struct ReciterContainer: View {
    @Environment(\.horizontalSizeClass) private var horizontalSizeClass
    @State private var showReciterShown = false
    @Bindable var reciterViewModel: ReciterViewModel
    let playerState: PlayerState
    var topSafeInset: CGFloat = 0
    /// Side-by-side layout: take the full height of the container, with no minimum height, and
    /// center the content in it with more room between the groups. The container's own safe area
    /// (tab bar, bottom accessory) still applies, so nothing is covered.
    var fillsHeight = false

    @ScaledMetric(relativeTo: .body) private var firstNameSize: CGFloat = 18
    @ScaledMetric(relativeTo: .largeTitle) private var lastNameSize: CGFloat = 80
    @ScaledMetric(relativeTo: .body) private var moshafNameSize: CGFloat = 17
    @ScaledMetric(relativeTo: .body) private var controlSize: CGFloat = 44

    /// Fixed line-box heights (as a multiple of the base size) so Latin and Arabic lines take the
    /// same vertical space; Arabic ascenders and dotted descenders would otherwise make them taller.
    private static let boldLineHeight: CGFloat = 1.3
    private static let smallLineHeight: CGFloat = 1.5

    /// Extra top padding in the full-height layout, pushing the centered content down a little.
    private static let fillsHeightExtraTopPadding: CGFloat = 40

    /// Width of the bold name; the first and moshaf names align to its edges, not the container's.
    @State private var nameWidth: CGFloat?

    private var baseHeight: CGFloat {
        horizontalSizeClass == .regular ? 500 : 250
    }

    private func boldName(_ text: String) -> some View {
        Text(text)
            .font(.system(size: lastNameSize))
            .fontWeight(.black)
            .fontWidth(.compressed)
            .lineLimit(1)
            .minimumScaleFactor(0.4)
            .contentTransition(.numericText())
            .frame(height: lastNameSize * Self.boldLineHeight, alignment: .center)
            .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { nameWidth = $0 }
    }

    private var nameBlock: some View {
        VStack(spacing: 0) {
            let parts = ReciterNameParser.split(playerState.selectedReciter.reciter.name)
            if let last = parts.last {
                Text(parts.first)
                    .font(.system(size: firstNameSize))
                    .contentTransition(.numericText())
                    .frame(
                        maxWidth: nameWidth ?? .infinity,
                        minHeight: firstNameSize * Self.smallLineHeight,
                        alignment: .leading
                    )
                boldName(last)
            } else {
                boldName(parts.first)
            }

            let moshafName = playerState.selectedReciter.formattedMoshafName
            Text(moshafName)
                .font(.system(size: moshafNameSize))
                .lineLimit(2)
                .multilineTextAlignment(.trailing)
                .frame(
                    maxWidth: nameWidth ?? .infinity,
                    minHeight: moshafNameSize * Self.smallLineHeight,
                    alignment: .trailing
                )
                .contentShape(Rectangle())
                .onTapGesture { showReciterShown = true }
        }
        .animation(.snappy, value: playerState.selectedReciter)
    }

    private var actions: some View {
        HStack(spacing: 12) {
            CurrentReciterFavoriteButton(item: playerState.selectedReciter)
                .frame(width: controlSize, height: controlSize)
                .background(Color.homeBackground.opacity(0.18), in: .circle)

            Button {
                showReciterShown = true
            } label: {
                Label("Change reciter", systemImage: "person.2")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 16)
                    .frame(minHeight: controlSize)
                    .background(Color.homeBackground.opacity(0.18), in: .capsule)
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
    }

    var body: some View {

        VStack {
            Spacer()

            VStack(spacing: fillsHeight ? 28 : 12) {
                nameBlock
                    .padding(.horizontal, 16)
                actions
            }

            Spacer()

        }
        .padding(.top, topSafeInset + (fillsHeight ? Self.fillsHeightExtraTopPadding : 0))
        .padding(.bottom)

        .foregroundStyle(Color.homeBackground)
        .frame(maxWidth: .infinity)
        .frame(minHeight: fillsHeight ? nil : baseHeight + topSafeInset)
        .frame(maxHeight: fillsHeight ? .infinity : nil)
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

#if DEBUG
@MainActor
private func previewState(reciter: String, moshaf: String) -> PlayerState {
    let state = PlayerState()
    state.selectedReciter = .make(
        reciterId: 1, reciterName: reciter, moshafId: 1, moshafName: moshaf, server: ""
    )
    return state
}

#Preview("Single") {
    ReciterContainer(
        reciterViewModel: ReciterViewModel(),
        playerState: PlayerState()
    )
}

/// English (left) and Arabic (right) side by side, to compare size, spacing and height.
#Preview("English | Arabic", traits: .fixedLayout(width: 800, height: 420)) {
    HStack(spacing: 20) {
        ReciterContainer(
            reciterViewModel: ReciterViewModel(),
            playerState: previewState(reciter: "Mohammed Siddiq AlMinshawi", moshaf: "Hafs An Assem - Murattal")
        )
        .environment(\.locale, Locale(identifier: "en"))
        .environment(\.layoutDirection, .leftToRight)

        ReciterContainer(
            reciterViewModel: ReciterViewModel(),
            playerState: previewState(reciter: "محمد صديق المنشاوي", moshaf: "حفص عن عاصم - مرتل")
        )
        .environment(\.locale, Locale(identifier: "ar"))
        .environment(\.layoutDirection, .rightToLeft)
    }
    .padding(20)
    .background(Color.homeBackground)
    .preferredColorScheme(.dark)
}
#endif
