//
//  ExploreView.swift
//  PourDirection
//
//  Default landing tab. Entry point into category-based discovery flows.
//  Contains no navigation logic — all flow control delegated to RootContainerView.
//

import SwiftUI

struct ExploreView: View {

    let onFindBar: () -> Void
    let onFindRestaurant: () -> Void
    let onFindClub: () -> Void
    let onFindDispensary: () -> Void

    private let adBannerHeight: CGFloat = 50 + (AppSpacing.xs * 2)

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.gradientBackground
                .ignoresSafeArea()

            // ── Header — pinned to top, completely independent of buttons ──────
            VStack(alignment: .center, spacing: AppSpacing.xxs) {
                Text("What do you")
                    .font(AppTypography.titleSmallLarge)
                    .foregroundColor(AppColors.secondary)
                Text("want to do tonight?")
                    .font(AppTypography.titleSmallLarge)
                    .foregroundColor(AppColors.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.85)
                    .allowsTightening(true)
            }
            .frame(maxWidth: .infinity, alignment: .center)
            .multilineTextAlignment(.center)
            .padding(.horizontal, AppSpacing.screenHorizontalPadding)
            .padding(.top, AppSpacing.xxl)

            // ── Buttons — pinned to bottom, independent of header ─────────────
            VStack(spacing: 0) {
                Spacer()

                VStack(spacing: AppSpacing.md) {
                    categoryButton(
                        category: .bar,
                        title: "Find a Bar",
                        icon: "wineglass",
                        height: 135,
                        iconSize: 34,
                        titleFont: AppTypography.bodyMedium,
                        action: onFindBar
                    )
                    categoryButton(
                        category: .restaurant,
                        title: "Find a Restaurant",
                        icon: "fork.knife",
                        height: 135,
                        iconSize: 34,
                        titleFont: AppTypography.bodyMedium,
                        action: onFindRestaurant
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                Spacer()
                    .frame(height: AppSpacing.md)

                HStack(spacing: AppSpacing.md) {
                    categoryButton(
                        category: .club,
                        title: "Find a Club",
                        icon: "music.note",
                        height: 118,
                        iconSize: 26,
                        titleFont: AppTypography.bodySmall,
                        action: onFindClub
                    )
                    categoryButton(
                        category: .dispensary,
                        title: "Find a Dispensary",
                        icon: "leaf",
                        height: 118,
                        iconSize: 26,
                        titleFont: AppTypography.bodySmall,
                        action: onFindDispensary
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                Spacer()
                    .frame(height: CustomTabBar.height + adBannerHeight + AppSpacing.md + 5)
            }
        }
    }

    // MARK: - Category Button

    @ViewBuilder
    private func categoryButton(
        category: PlaceCategory,
        title: String,
        icon: String,
        height: CGFloat,
        iconSize: CGFloat,
        titleFont: Font,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            VStack(spacing: AppSpacing.xs) {
                Image(systemName: icon)
                    .font(.system(size: iconSize, weight: .light))
                    .foregroundColor(category.color)
                Text(title)
                    .font(titleFont)
                    .foregroundColor(AppColors.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(Color(hex: "0E0E0E").opacity(0.4))
            )
            // Glow: blurred stroke behind the button acts as the colored drop shadow
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(category.color, lineWidth: 3)
                    .blur(radius: 10)
                    .opacity(0.45)
            )
            // Crisp thin border on top
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(category.color.opacity(0.5), lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        ExploreView(onFindBar: {}, onFindRestaurant: {}, onFindClub: {}, onFindDispensary: {})
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
