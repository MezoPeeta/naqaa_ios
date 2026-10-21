//
//  ShareButton.swift
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

import SwiftUI

struct ShareButton: View {
    let message: String

    var body: some View {
        ShareLink(item: message) {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                // The glyph's visual mass sits low in its frame next to the heart; nudge it up to match.
                .offset(y: -2)
                .frame(width: 44, height: 44)
                .contentShape(Circle())
        }
        .foregroundStyle(.white)
        .buttonStyle(.plain)
        .accessibilityLabel("Share")
    }
}

#Preview {
    ShareButton(message: "Listening to Al-Fatiha by Mishary Alafasy\nhttps://ensat.app/share/preview")
        .preferredColorScheme(.dark)
}
