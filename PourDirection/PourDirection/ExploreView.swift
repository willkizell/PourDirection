//
//  ExploreView.swift
//  PourDirection
//
//  Default landing tab. Entry point into the three Explore flows.
//  Contains no navigation logic — all flow control delegated to RootContainerView.
//

import SwiftUI

struct ExploreView: View {

    let onFindBar: () -> Void
    let onFindSomethingElse: () -> Void
    let onSurpriseMe: () -> Void

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Greeting Header ───────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    Text("What do you want")
                        .font(AppTypography.titleLarge)
                        .foregroundColor(AppColors.secondary)
                    Text("to do tonight?")
                        .font(AppTypography.titleLarge)
                        .foregroundColor(AppColors.primary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.xxl)

                Spacer(minLength: AppSpacing.xxxl)

                // ── CTA Buttons ───────────────────────────────────────────────
                VStack(spacing: AppSpacing.md) {
                    PrimaryButton(title: "Find a Bar", action: onFindBar)
                    SecondaryButton(title: "Find Something Else", action: onFindSomethingElse)
                    SecondaryButton(title: "Surprise Me", action: onSurpriseMe)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                Spacer(minLength: AppSpacing.xxxl)
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        ExploreView(onFindBar: {}, onFindSomethingElse: {}, onSurpriseMe: {})
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
