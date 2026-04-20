//
//  ExploreView.swift
//  PourDirection
//
//  Default landing tab. Entry point into category-based discovery flows.
//  Day mode shows 6 daytime categories; Night mode shows 6 nightlife categories.
//  Includes a Day/Night segment toggle and a uniform 2-column grid.
//  Contains no navigation logic — all flow control delegated to RootContainerView.
//

import SwiftUI

struct ExploreView: View {

    @Environment(ThemeManager.self) private var themeManager

    let onCategoryTap: (PlaceCategory) -> Void

    // Drives the entrance animation of "today" / "tonight" on mode change
    @State private var subtitleVisible = false

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {
                // ── Fixed header ───────────────────────────────────────────────
                headerView

                // ── Day / Night toggle — always below header, always tappable ──
                modeToggle
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.sm)
                    .padding(.bottom, AppSpacing.sm)

                // ── Scrollable category grid ───────────────────────────────────
                let categories = themeManager.isDayMode
                    ? PlaceCategory.dayCategories
                    : PlaceCategory.nightCategories

                ScrollView(.vertical, showsIndicators: false) {
                    LazyVGrid(
                        columns: [GridItem(.flexible()), GridItem(.flexible())],
                        spacing: AppSpacing.md
                    ) {
                        ForEach(categories, id: \.self) { cat in
                            categoryButton(cat) { onCategoryTap(cat) }
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.xs)
                    .padding(.bottom, AppSpacing.lg)
                }
                .scrollBounceBehavior(.always)
            }
        }
        .onAppear { triggerSubtitleAnimation() }
        .onChange(of: themeManager.mode) { _, _ in triggerSubtitleAnimation() }
    }

    // MARK: - Header

    private var headerView: some View {
        VStack(alignment: .center, spacing: AppSpacing.xxs) {
            Text("What do you")
                .font(AppTypography.titleMedium)
                .foregroundColor(AppColors.secondary)

            // "today" / "tonight" — animates in on mode change
            Group {
                if themeManager.isDayMode {
                    Text("want to do today?")
                } else {
                    Text("want to do tonight?")
                }
            }
            .font(AppTypography.titleMedium)
            .foregroundColor(AppColors.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .allowsTightening(true)
            .opacity(subtitleVisible ? 1 : 0)
            .scaleEffect(subtitleVisible ? 1 : 0.88, anchor: .bottom)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: subtitleVisible)
            .animation(.spring(response: 0.38, dampingFraction: 0.72), value: themeManager.mode)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
        .padding(.top, AppSpacing.xxl)
        .padding(.bottom, AppSpacing.xs)
    }

    private func triggerSubtitleAnimation() {
        subtitleVisible = false
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
            subtitleVisible = true
        }
    }

    // MARK: - Day / Night Mode Toggle

    private var modeToggle: some View {
        HStack(spacing: 0) {
            segmentButton(label: "Day", icon: "sun.max.fill", mode: .day)
            segmentButton(label: "Night", icon: "moon.fill", mode: .night)
        }
        .background(Capsule().fill(AppColors.cardSurface.opacity(0.85)))
        .overlay(Capsule().stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5))
    }

    @ViewBuilder
    private func segmentButton(label: String, icon: String, mode: AppMode) -> some View {
        let isSelected = themeManager.mode == mode
        Button(action: {
            HapticManager.shared.light()
            themeManager.setMode(mode)
        }) {
            HStack(spacing: 5) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .medium))
                Text(label)
                    .font(AppTypography.bodySmall)
            }
            .foregroundColor(isSelected ? AppColors.background : AppColors.secondary.opacity(0.4))
            .frame(maxWidth: .infinity)
            .padding(.vertical, AppSpacing.xs)
            .background(
                Capsule()
                    .fill(isSelected ? AppColors.primary : Color.clear)
                    .padding(3)
            )
        }
        .buttonStyle(.plain)
        .animation(.easeInOut(duration: 0.2), value: themeManager.mode)
    }

    // MARK: - Category Button

    private func categoryButton(_ category: PlaceCategory, action: @escaping () -> Void) -> some View {
        let isDayMode = themeManager.isDayMode
        let borderColor: Color = isDayMode
            ? AppColors.secondary.opacity(0.15)
            : AppColors.secondary.opacity(0.25)

        return Button(action: {
            HapticManager.shared.light()
            action()
        }) {
            VStack(spacing: AppSpacing.xs) {
                if category == .casino {
                    CasinoIconView(color: category.color)
                        .frame(width: 28, height: 28)
                } else if category == .patio {
                    PatioIconView(color: category.color)
                        .frame(width: 28, height: 28)
                } else if category == .parks {
                    ParksIconView(color: category.color)
                        .frame(width: 28, height: 28)
                } else {
                    Image(systemName: category.iconName)
                        .font(.system(size: 26, weight: .light))
                        .foregroundColor(category.color)
                }
                Text(category.rawValue)
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 120)
            // Transparent fill — glow + border provide depth
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .fill(Color.clear)
            )
            .background(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(borderColor, lineWidth: 3)
                    .blur(radius: 10)
                    .opacity(0.25)
            )
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(borderColor, lineWidth: 0.75)
            )
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        ExploreView(onCategoryTap: { _ in })
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(ThemeManager.shared)
}
