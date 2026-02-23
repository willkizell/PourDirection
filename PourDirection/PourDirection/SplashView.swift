//
//  SplashView.swift
//  PourDirection
//
//  Splash / launch screen shown on app open.
//  No navigation logic — purely presentational.
//
//  Layout is fully adaptive: Spacer() distributes vertical space proportionally
//  so the content cluster stays centered on every iPhone size (SE through Pro Max).
//

import SwiftUI

struct SplashView: View {

    @State private var contentOpacity: Double = 0
    @State private var logoScale: CGFloat = 0.85

    var body: some View {
        ZStack {
            // ── Background ──────────────────────────────────────────────────
            AppColors.gradientBackground
                .ignoresSafeArea()

            // ── Centered Brand Content ──────────────────────────────────────
            // Two free Spacers (top + bottom) share remaining height equally,
            // keeping the content cluster vertically centered on any screen size.
            VStack(spacing: 0) {
                Spacer()

                // Logo
                AppLogoView(size: 100)
                    .scaleEffect(logoScale)

                Spacer().frame(height: AppSpacing.xl)

                // Wordmark — concatenated Text so both words scale together as one unit.
                // lineLimit(1) + minimumScaleFactor prevent wrapping on every screen size.
                (Text("Pour")
                    .foregroundColor(AppColors.secondary)
                 + Text("Direction")
                    .foregroundColor(AppColors.primary))
                    .font(AppTypography.splashTitle)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .padding(.horizontal, AppSpacing.xl)

                Spacer().frame(height: AppSpacing.sm)

                // Tagline
                Text("This way.")
                    .font(AppTypography.body)
                    .foregroundColor(AppColors.secondary.opacity(0.55))

                Spacer()
            }
            .opacity(contentOpacity)
        }
        .onAppear {
            withAnimation(.easeOut(duration: 0.9)) {
                contentOpacity = 1
                logoScale = 1.0
            }
        }
        .preferredColorScheme(.dark)
    }
}

#Preview {
    SplashView()
}
