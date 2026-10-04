import SwiftUI

/// Pure SwiftUI Arabic text view. No UIKit.
/// Callers wrap it in a GeometryReader so it gets an explicit width,
/// which fixes the "text not showing" sizing issue.
struct JustifiedArabicText: View {
    let text: String
    var font: Font = .body
    var foregroundColor: Color = .primary
    var alignment: TextAlignment = .trailing
    var lineSpacing: CGFloat = 4

    var body: some View {
        Text(text)
            .font(font)
            .foregroundColor(foregroundColor)
            .multilineTextAlignment(alignment)
            .lineSpacing(lineSpacing)
            .lineLimit(nil)
            .frame(maxWidth: .infinity, alignment: .trailing)
            .environment(\.layoutDirection, .rightToLeft)
    }
}

#Preview {
    struct Preview: View {
        let text = "الحمد لله الذي أنعم علينا بالإسلام وهدانا إلى هذا الدين القويم، نسأله أن يهدينا صراطه المستقيم في جميع أمور حياتنا وأعمالنا."

        var body: some View {
            GeometryReader { proxy in
                JustifiedArabicText(text: text)
                    .frame(width: proxy.size.width, alignment: .leading)
            }
            .padding()
        }
    }

    return Preview()
}
