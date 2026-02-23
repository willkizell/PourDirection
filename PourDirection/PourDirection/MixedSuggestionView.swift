//
//  MixedSuggestionView.swift
//  PourDirection
//
//  Reached via "Surprise Me" from ExploreView.
//  Shows a curated mixed-category list of venues.
//  Tapping any card hands the selection to RootContainerView via closure → CompassActiveView.
//  No direct navigation here — all routing delegated to RootContainerView.
//

import SwiftUI

struct MixedSuggestionView: View {

    let onSelectPlace: (MockPlace) -> Void

    @State private var places: [MockPlace] = [
        MockPlace.generate(category: "Bar",          vibe: "Chill"),
        MockPlace.generate(category: "Club",         vibe: "Energetic"),
        MockPlace.generate(category: "Event",        vibe: "Chill"),
        MockPlace.generate(category: "Bar",          vibe: "Energetic"),
        MockPlace.generate(category: "Liquor Store", vibe: "Chill"),
    ]

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────────
                (Text("Tonight's ")
                    .foregroundColor(AppColors.secondary)
                 + Text("picks.")
                    .foregroundColor(AppColors.primary))
                    .font(AppTypography.titleSmall)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.lg)

                // ── Scrollable Venue List ─────────────────────────────────────
                ScrollView(showsIndicators: false) {
                    VStack(spacing: AppSpacing.md) {
                        ForEach(places) { place in
                            Button { onSelectPlace(place) } label: {
                                CardView {
                                    VStack(alignment: .leading, spacing: AppSpacing.xs) {

                                        HStack(alignment: .top) {
                                            Text(place.name)
                                                .font(AppTypography.header)
                                                .foregroundColor(AppColors.secondary)
                                            Spacer()
                                            Text(place.category)
                                                .font(.system(size: 11, weight: .medium))
                                                .foregroundColor(AppColors.primary)
                                                .padding(.horizontal, AppSpacing.xs)
                                                .padding(.vertical, 3)
                                                .background(AppColors.primary.opacity(0.12))
                                                .cornerRadius(AppRadius.sm)
                                        }

                                        HStack(spacing: AppSpacing.xs) {
                                            // Rating
                                            HStack(spacing: 3) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 11))
                                                    .foregroundColor(AppColors.primary)
                                                Text(String(format: "%.1f", place.rating))
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(AppColors.secondary.opacity(0.7))
                                            }

                                            Text("·")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.secondary.opacity(0.25))

                                            // Distance
                                            Label(place.distance, systemImage: "location.fill")
                                                .font(AppTypography.caption)
                                                .foregroundColor(AppColors.secondary.opacity(0.6))

                                            Spacer()

                                            // Open status
                                            HStack(spacing: AppSpacing.xxs) {
                                                Circle()
                                                    .fill(place.isOpen
                                                          ? AppColors.primary
                                                          : AppColors.secondary.opacity(0.3))
                                                    .frame(width: 6, height: 6)
                                                Text(place.isOpen ? "Open" : "Closed")
                                                    .font(AppTypography.caption)
                                                    .foregroundColor(
                                                        place.isOpen
                                                            ? AppColors.primary
                                                            : AppColors.secondary.opacity(0.4)
                                                    )
                                            }
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                    .padding(.top, AppSpacing.md)
                    .padding(.bottom, AppSpacing.xxxl * 2)
                }
            }
        }
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        MixedSuggestionView(onSelectPlace: { _ in })
        CustomTabBar(selectedTab: .constant(.explore))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
}
