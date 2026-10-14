import SwiftUI

/// Shows `wide` content when the available space is wider than it is tall, otherwise `tall`.
///
/// Decides on the container's size, not the device orientation, so it also behaves
/// correctly in split view and sheets. Both closures receive the container size.
struct ContainerShapeView<Tall: View, Wide: View>: View {
    @ViewBuilder var tall: (CGSize) -> Tall
    @ViewBuilder var wide: (CGSize) -> Wide

    var body: some View {
        GeometryReader { proxy in
            if proxy.size.width > proxy.size.height {
                wide(proxy.size)
            } else {
                tall(proxy.size)
            }
        }
    }
}

#Preview {
    ContainerShapeView { _ in
        VStack { Text("Tall"); Text("stacked") }
    } wide: { _ in
        HStack { Text("Wide"); Text("side by side") }
    }
}
