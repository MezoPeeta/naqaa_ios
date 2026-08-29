import SwiftUI

/// An SF Symbol image that respects the app's layout direction.
///
/// Pass an explicit `rtl` glyph to swap symbols per direction,
/// otherwise the glyph is mirrored automatically in right-to-left locales.
struct DirectionalImage: View {
    @Environment(\.layoutDirection) private var layoutDirection
    let systemName: String
    var rtlName: String?

    init(_ systemName: String, rtl rtlName: String? = nil) {
        self.systemName = systemName
        self.rtlName = rtlName
    }

    var body: some View {
        if let rtlName, layoutDirection == .rightToLeft {
            Image(systemName: rtlName)
        } else if layoutDirection == .rightToLeft {
            Image(systemName: systemName)
                .scaleEffect(x: -1)
        } else {
            Image(systemName: systemName)
        }
    }
}