//
//  ShareButton.swift
//  ensat
//
//  Created by Mazen on 06/10/2026.
//

import SwiftUI

struct ShareButton: View {
    var body: some View {
        Button {} label: {
            Image(systemName: "square.and.arrow.up")
                .font(.title2)
                .frame(width: 44, height: 44)
                .contentShape(Circle())

        }

        .foregroundStyle(.white)
        .symbolEffect(.bounce.down.byLayer, value: 0)
        .buttonStyle(.plain)

    }
}

#Preview {
    ShareButton()
        .preferredColorScheme(.dark)
}
