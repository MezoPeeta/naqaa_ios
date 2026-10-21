import SwiftUI
import AVKit
import PostHog

/// Opens the system audio-output sheet (AirPlay / Bluetooth / speaker) from a regular SwiftUI button.
///
/// `AVRoutePickerView` is kept hidden in the background and its internal button is triggered
/// programmatically, so the visible control can be any size and style.
struct AudioRoutePickerButton: View {
    @State private var controller = AudioRoutePickerController()
    @State private var route = AudioRouteMonitor()

    var body: some View {
        Button {
            controller.present()
        } label: {
            DirectionalImage(route.symbolName)
                .font(.title2)
                .contentTransition(.symbolEffect(.replace))
                .contentShape(Rectangle())
                .font(.title2)

        }
        .background { AudioRoutePickerHost(controller: controller).allowsHitTesting(false) }
        .accessibilityLabel("Audio output")
        .accessibilityValue(route.deviceName)
        .task { await route.observe() }
    }
}

@MainActor
final class AudioRoutePickerController {
    fileprivate weak var picker: AVRoutePickerView?

    func present() {
        PostHogSDK.shared.capture("audio_output_picker_opened")
        let button = picker?.subviews.compactMap { $0 as? UIButton }.first
        button?.sendActions(for: .touchUpInside)
    }
}

private struct AudioRoutePickerHost: UIViewRepresentable {
    let controller: AudioRoutePickerController

    func makeUIView(context: Context) -> AVRoutePickerView {
        let picker = AVRoutePickerView()
        picker.prioritizesVideoDevices = false
        picker.alpha = 0.011
        controller.picker = picker
        return picker
    }

    func updateUIView(_ uiView: AVRoutePickerView, context: Context) {
        controller.picker = uiView
    }
}

#Preview {
    AudioRoutePickerButton()
}
