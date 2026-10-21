import SwiftUI

/// Quiet "N downloaded" caption for reciter rows; draws nothing when the reciter has no downloads.
struct DownloadedCountLabel: View {
    let count: Int

    var body: some View {
        if count > 0 {
            // Styled piece by piece: inside a Button the tint (green) otherwise reaches a Label's icon.
            HStack(spacing: 4) {
                Image(systemName: "arrow.down.circle.fill")
                Text("\(count) downloaded")
            }
            .foregroundStyle(Color.candy)
            .font(.caption)
            .accessibilityElement(children: .combine)
        }
    }
}
