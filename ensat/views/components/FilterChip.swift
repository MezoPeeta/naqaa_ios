import SwiftUI

/// A capsule that reads as on or off without relying on hue: off is a quiet translucent pill,
/// on is a solid light pill with dark text.
struct FilterChip: View {
    let title: LocalizedStringKey
    let systemImage: String
    @Binding var isOn: Bool

    var body: some View {
        Button {
            isOn.toggle()
        } label: {
            Label(title, systemImage: systemImage)
                .font(.subheadline.bold())
                .symbolVariant(isOn ? .fill : .none)
                .foregroundStyle(isOn ? Color.homeBackground : .primary)
                .padding(.vertical, 8)
                .padding(.horizontal, 14)
                .background(isOn ? Color.white : Color.white.opacity(0.12), in: .capsule)
                .contentShape(.capsule)
        }
        .buttonStyle(.plain)
        .animation(.smooth(duration: 0.2), value: isOn)
        .sensoryFeedback(.selection, trigger: isOn)
        .accessibilityAddTraits(.isToggle)
        .accessibilityValue(isOn ? Text("On") : Text("Off"))
    }
}
