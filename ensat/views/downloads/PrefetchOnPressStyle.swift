import SwiftUI

/// Dims like the default button style and reports touch-down, so work can start before the tap completes.
struct PrefetchOnPressStyle: ButtonStyle {
    let onPress: () -> Void

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .opacity(configuration.isPressed ? 0.5 : 1)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed { onPress() }
            }
    }
}
