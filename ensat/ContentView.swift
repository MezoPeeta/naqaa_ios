//
//  ContentView.swift
//  ensat
//
//  Created by Mazen on 16/05/2026.
//

import SwiftUI
import SwiftData

struct ContentView: View {
    var body: some View {
        HomeView()
            .preferredColorScheme(.dark)
//            .splashScreen(config: .init(), showOnBoarding: true) {
//                OnBoardingView()
//            }
    }
    
    
}

#Preview {
    ContentView()
}

