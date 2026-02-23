//
//  ContentView.swift
//  PourDirection
//
//  Placeholder screen — reserved for the main app shell once
//  splash navigation is wired up. Not used at launch.
//

import SwiftUI

struct ContentView: View {
    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            Text("PourDirection")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.secondary)
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
}
