import SwiftUI

struct PlayerProgressBar: View {
    let progress: Double
    @Binding var scrubProgress: Double?
    var onSeek: (Double) -> Void

    private var displayedProgress: Double { min(max(scrubProgress ?? progress, 0), 1) }

    var body: some View {
        Slider(value: scrubberValue, in: 0 ... 1, onEditingChanged: handleEditingChanged)
            .tint(Color.selectedText)
            .sliderThumbVisibility(.hidden)
            
            .accessibilityLabel("Playback position")
    }

    private var scrubberValue: Binding<Double> {
        Binding(
            get: { displayedProgress },
            set: { scrubProgress = $0 }
        )
    }

    private func handleEditingChanged(_ isEditing: Bool) {
        guard !isEditing else { return }
        let target = displayedProgress
        onSeek(target)
        scrubProgress = nil
    }
}

#if DEBUG
private struct PlayerProgressBarPreview: View {
    @State private var scrubProgress: Double?

    var body: some View {
        VStack(spacing: 32) {
            PlayerProgressBar(progress: 0.4, scrubProgress: $scrubProgress) { _ in }
            PlayerProgressBar(progress: 0.4, scrubProgress: .constant(0.75)) { _ in }
        }
        .padding(.horizontal)
    }
}
#endif

#Preview {
    PlayerProgressBarPreview()
}
