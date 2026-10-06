import SwiftUI
import UIKit

/// Justified Arabic text backed by a `UILabel`.
/// SwiftUI's `Text` has no justification, while TextKit justifies Arabic by
/// stretching words with kashida. Sizes itself to the width SwiftUI proposes.
struct JustifiedArabicText: UIViewRepresentable {
    let text: String
    var font: UIFont = .preferredFont(forTextStyle: .body)
    var foregroundColor: UIColor = .label
    var lineSpacing: CGFloat = 4

    func makeUIView(context: Context) -> UILabel {
        let label = UILabel()
        label.numberOfLines = 0
        label.lineBreakMode = .byWordWrapping
        label.semanticContentAttribute = .forceRightToLeft
        label.setContentHuggingPriority(.defaultLow, for: .horizontal)
        label.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        return label
    }

    func updateUIView(_ label: UILabel, context: Context) {
        let style = NSMutableParagraphStyle()
        style.alignment = .justified
        style.baseWritingDirection = .rightToLeft
        style.lineSpacing = lineSpacing
        style.lineBreakMode = .byWordWrapping

        label.attributedText = NSAttributedString(
            string: text,
            attributes: [
                .font: font,
                .foregroundColor: foregroundColor,
                .paragraphStyle: style,
            ]
        )
    }

    func sizeThatFits(_ proposal: ProposedViewSize, uiView label: UILabel, context: Context) -> CGSize? {
        let width = proposal.width ?? UIScreen.main.bounds.width
        label.preferredMaxLayoutWidth = width
        let size = label.sizeThatFits(CGSize(width: width, height: .greatestFiniteMagnitude))
        return CGSize(width: width, height: ceil(size.height))
    }
}

#Preview {
    JustifiedArabicText(
        text: "اسمي مازن عمر محمد بشير المتولي عاشور بس انا مكنتش اعرف ان عمر صبرة خالد موكوس اوي كدا اعمل اية انا تعبت  يلا عوضي علي الله و اخرتي اليه",
        font: .systemFont(ofSize: 20)
    )
    .padding()
}

#Preview("Kashida comparison") {
    let text = "الحمد لله الذي أنعم علينا بالإسلام وهدانا إلى هذا الدين القويم، نسأله أن يهدينا صراطه المستقيم في جميع أمور حياتنا وأعمالنا."

    ScrollView {
        VStack(alignment: .trailing, spacing: 24) {
            Group {
                Text("SwiftUI Text (not justified)").font(.caption).foregroundStyle(.secondary)
                Text(text)
                    .font(.system(size: 20))
                    .multilineTextAlignment(.trailing)
                    .environment(\.layoutDirection, .rightToLeft)
                    .frame(maxWidth: .infinity, alignment: .trailing)
                    .border(.red.opacity(0.4))
            }

            Group {
                Text("Justified, system font").font(.caption).foregroundStyle(.secondary)
                JustifiedArabicText(text: text, font: .systemFont(ofSize: 20))
                    .border(.green.opacity(0.4))
            }

            Group {
                Text("Justified, Geeza Pro").font(.caption).foregroundStyle(.secondary)
                JustifiedArabicText(
                    text: text,
                    font: UIFont(name: "GeezaPro", size: 20) ?? .systemFont(ofSize: 20)
                )
                .border(.green.opacity(0.4))
            }

            Group {
                Text("Justified, Al Nile").font(.caption).foregroundStyle(.secondary)
                JustifiedArabicText(
                    text: text,
                    font: UIFont(name: "AlNile", size: 20) ?? .systemFont(ofSize: 20)
                )
                .border(.green.opacity(0.4))
            }

            Group {
                Text("Justified, narrow (240pt)").font(.caption).foregroundStyle(.secondary)
                JustifiedArabicText(text: text, font: .systemFont(ofSize: 20))
                    .frame(width: 240)
                    .border(.green.opacity(0.4))
            }
        }
        .padding()
    }
}
