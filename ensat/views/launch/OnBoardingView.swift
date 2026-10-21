//
//  OnBoardingView.swift
//  ensat
//

import AuthenticationServices
import SwiftUI

/// OnBoarding View
struct OnBoardingView: View {
    var body: some View {
      
        VStack(spacing: 20) {
            Text("Listen to the Quran,\nwherever you are")
                .font(.largeTitle.bold())
                .multilineTextAlignment(.center)

            SignInWithAppleButton { _ in

            } onCompletion: { _ in

            }
            .signInWithAppleButtonStyle(.white)
            .frame(height: 50)
            .clipShape(.capsule)

            Text("By continuing, you agree to our\nTerms of Service and Privacy Policy")
                .font(.caption)
                .multilineTextAlignment(.center)
                .foregroundStyle(.primary.secondary)
        }
        .padding(.horizontal, 5)
        .padding(15)
    }
}

#Preview {
    OnBoardingView()
        .preferredColorScheme(.dark)
}
