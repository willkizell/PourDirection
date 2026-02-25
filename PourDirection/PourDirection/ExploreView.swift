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

    var body: some View {
        ZStack(alignment: .top) {
            AppColors.gradientBackground
                .ignoresSafeArea()

            // ── Buttons — scrollable so first-touch swipes feel responsive ────
            // geo.size.height = space after safeAreaInset (tab bar + ad banner).
            // We use it as our scroll frame, then vertically center the button
            // group within it, offset down past the header.
            GeometryReader { geo in
                let headerBottom: CGFloat = AppSpacing.xxl  // where header text ends
                let usableHeight  = geo.size.height - headerBottom
                let buttonsHeight: CGFloat = 135 + AppSpacing.md + 135 + AppSpacing.md + 118
                let topPad = max(0, (usableHeight - buttonsHeight) / 2)

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 0) {
                        Spacer().frame(height: headerBottom + topPad)

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
                            .frame(height: topPad)
                    }
                    .frame(maxWidth: .infinity)
                }
                .scrollBounceBehavior(.always)
            }

            // ── Header — rendered last so it sits on top of scrolling buttons ─
            VStack(spacing: 0) {
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
                .padding(.bottom, AppSpacing.sm)
                .background(AppColors.background.ignoresSafeArea(edges: .top))

                // Soft fade so buttons dissolve under the header rather than hard-clip
                LinearGradient(
                    colors: [AppColors.background, AppColors.background.opacity(0)],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .frame(height: 32)
                .allowsHitTesting(false)
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
        let borderColor: Color = category == .bar
            ? category.color
            : AppColors.secondary.opacity(0.25)

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
                    .stroke(borderColor, lineWidth: 3)
                    .blur(radius: 10)
                    .opacity(category == .bar ? 0.45 : 0.2)
            )
            // Crisp thin border on top
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(borderColor.opacity(category == .bar ? 0.5 : 1.0), lineWidth: 0.75)
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
