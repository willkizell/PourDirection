//
//  SuggestionView.swift
//  PourDirection
//
//  Shown after PickVibeFlow completes — presents the generated suggestion
//  before committing to full compass navigation.
//  Displayed inline (not as a modal) so the tab bar remains accessible.
//

import SwiftUI

struct SuggestionView: View {

    let place: MapItem
    let onLetsGo: () -> Void
    let onNotFeelingIt: () -> Void

    @Environment(LocationManager.self) private var locationManager

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                VStack(alignment: .leading, spacing: AppSpacing.xxs) {
                    (Text("Found ")
                        .foregroundColor(AppColors.secondary)
                     + Text("it.")
                        .foregroundColor(AppColors.primary))
                        .font(AppTypography.titleSmall)
                    Text("\(place.displayCategory) · \(place.vibe)")
                        .font(AppTypography.caption)
                        .foregroundColor(AppColors.secondary.opacity(0.45))
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.xxl)

                Spacer()

                // ── Place Card ────────────────────────────────────────────────
                CardView {
                    VStack(alignment: .leading, spacing: AppSpacing.md) {

                        Text(place.name)
                            .font(AppTypography.titleMedium)
                            .foregroundColor(AppColors.secondary)

                        // Meta row
                        HStack(spacing: AppSpacing.md) {
                            // Distance
                            Label(
                                MapItem.formatDistance(place.distance(from: locationManager.currentLocation)),
                                systemImage: "location.fill"
                            )
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.6))

                            // Divider dot
                            Text("·")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.25))

                            // Open status
                            HStack(spacing: AppSpacing.xxs) {
                                Circle()
                                    .fill((place.isOpen ?? false) ? AppColors.primary : AppColors.secondary.opacity(0.3))
                                    .frame(width: 6, height: 6)
                                Text((place.isOpen ?? false) ? "Open now" : "Closed")
                                    .font(AppTypography.caption)
                                    .foregroundColor(
                                        (place.isOpen ?? false)
                                            ? AppColors.primary
                                            : AppColors.secondary.opacity(0.4)
                                    )
                            }

                            Spacer()
                        }
                    }
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)

                Spacer()

                // ── Actions ───────────────────────────────────────────────────
                VStack(spacing: AppSpacing.md) {
                    PrimaryButton(title: "Let's Go", action: onLetsGo)
                    SecondaryButton(title: "Not Feeling It", action: onNotFeelingIt)
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.bottom, AppSpacing.xxxl)
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        SuggestionView(
            place: MapItem.mock(category: .bar, vibe: "Chill"),
            onLetsGo: {},
            onNotFeelingIt: {}
        )
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
