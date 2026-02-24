//
//  SavedView.swift
//  PourDirection
//
//  Saved places screen — two segments per design spec:
//  • All     — every place the user has ever saved (all-time history)
//  • Nearby  — saved places within 5 km of current location
//  Tap a card to navigate (Let's Go). Heart icon to unsave.
//

import SwiftUI
import CoreLocation

struct SavedView: View {

    let onLetsGo: (Place) -> Void

    @Environment(LocationManager.self) private var locationManager
    private let manager = SavedPlacesManager.shared

    @State private var filter: SavedFilter = .all

    private enum SavedFilter: String, CaseIterable {
        case all    = "All"
        case nearby = "Nearby"
    }

    private var displayedPlaces: [SavedPlace] {
        switch filter {
        case .all:
            return manager.savedPlaces
        case .nearby:
            return manager.nearbyPlaces(from: locationManager.currentLocation)
        }
    }

    private let adBannerHeight: CGFloat = 50 + (AppSpacing.xs * 2)

    var body: some View {
        ZStack {
            AppColors.gradientBackground
                .ignoresSafeArea()

            VStack(spacing: 0) {

                // ── Header ────────────────────────────────────────────────
                HStack(alignment: .bottom) {
                    (Text("Saved ")
                        .foregroundColor(AppColors.primary)
                     + Text("Places")
                        .foregroundColor(AppColors.secondary))
                        .font(AppTypography.titleSmall)

                    Spacer()

                    // ── Segment picker ────────────────────────────────────
                    HStack(spacing: 2) {
                        ForEach(SavedFilter.allCases, id: \.self) { option in
                            Button(action: {
                                HapticManager.shared.light()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    filter = option
                                }
                            }) {
                                Text(option.rawValue)
                                    .font(AppTypography.caption)
                                    .foregroundColor(
                                        filter == option
                                            ? AppColors.background
                                            : AppColors.secondary.opacity(0.5)
                                    )
                                    .padding(.horizontal, AppSpacing.sm)
                                    .padding(.vertical, 5)
                                    .background(
                                        Capsule()
                                            .fill(filter == option ? AppColors.primary : Color.clear)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .background(
                        Capsule()
                            .fill(AppColors.cardSurface.opacity(0.85))
                    )
                }
                .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                .padding(.top, AppSpacing.lg)
                .padding(.bottom, AppSpacing.md)
                .background(AppColors.background.ignoresSafeArea(edges: .top))

                // ── Content ───────────────────────────────────────────────
                if displayedPlaces.isEmpty {
                    Spacer()
                    emptyState
                    Spacer()
                } else {
                    ScrollView(showsIndicators: false) {
                        LazyVStack(spacing: AppSpacing.sm) {
                            ForEach(displayedPlaces) { saved in
                                savedRow(saved)
                            }
                        }
                        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
                        .padding(.top, AppSpacing.sm)
                        .padding(.bottom, CustomTabBar.height + adBannerHeight + AppSpacing.md)
                    }
                }
            }
        }
    }

    // MARK: - Saved Row

    private func savedRow(_ saved: SavedPlace) -> some View {
        Button(action: {
            HapticManager.shared.heavy()
            onLetsGo(saved.toPlace())
        }) {
            HStack(spacing: AppSpacing.sm) {

                // Category dot
                Circle()
                    .fill(saved.category?.color ?? AppColors.primary)
                    .frame(width: 8, height: 8)
                    .padding(.top, 2)
                    .frame(maxHeight: .infinity, alignment: .top)

                // Info
                VStack(alignment: .leading, spacing: 3) {
                    Text(saved.name)
                        .font(AppTypography.bodyMedium)
                        .foregroundColor(AppColors.secondary)
                        .lineLimit(1)

                    if let address = saved.formattedAddress {
                        Text(address)
                            .font(AppTypography.caption)
                            .foregroundColor(AppColors.secondary.opacity(0.45))
                            .lineLimit(1)
                    }

                    HStack(spacing: AppSpacing.xs) {
                        if let category = saved.category {
                            Text(category.rawValue)
                                .font(AppTypography.caption)
                                .foregroundColor(category.color.opacity(0.8))
                        }

                        let dist = saved.distance(from: locationManager.currentLocation)
                        if let dist {
                            Text("·")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                            Text(Place.formatDistance(dist))
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.45))
                        }

                        if let rating = saved.rating {
                            Text("·")
                                .font(AppTypography.caption)
                                .foregroundColor(AppColors.secondary.opacity(0.3))
                            HStack(spacing: 3) {
                                Image(systemName: "star.fill")
                                    .font(.system(size: 9))
                                    .foregroundColor(AppColors.primary)
                                Text(String(format: "%.1f", rating))
                                    .font(AppTypography.caption)
                                    .foregroundColor(AppColors.secondary.opacity(0.45))
                            }
                        }
                    }
                }

                Spacer()

                // Unsave button
                Button(action: {
                    HapticManager.shared.light()
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.55)) {
                        manager.removeSaved(saved)
                    }
                }) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 18))
                        .foregroundColor(AppColors.primary)
                }
                .buttonStyle(.plain)
            }
            .padding(AppSpacing.md)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(AppColors.cardSurface.opacity(0.92))
            .cornerRadius(AppRadius.lg)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.lg)
                    .stroke(AppColors.secondary.opacity(0.08), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty States

    @ViewBuilder
    private var emptyState: some View {
        VStack(spacing: AppSpacing.xs) {
            Image(systemName: "heart")
                .font(.system(size: 32, weight: .light))
                .foregroundColor(AppColors.primary.opacity(0.4))
                .padding(.bottom, AppSpacing.xs)

            switch filter {
            case .all:
                Text("No saved places yet")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
                Text("Tap the heart on any suggestion to save it")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            case .nearby:
                Text("No saved places nearby")
                    .font(AppTypography.bodyMedium)
                    .foregroundColor(AppColors.secondary.opacity(0.5))
                Text("Your saved places within 5 km will appear here")
                    .font(AppTypography.caption)
                    .foregroundColor(AppColors.secondary.opacity(0.3))
            }
        }
        .multilineTextAlignment(.center)
        .padding(.horizontal, AppSpacing.screenHorizontalPadding)
    }
}

#Preview {
    ZStack(alignment: .bottom) {
        SavedView(onLetsGo: { _ in })
        CustomTabBar(selectedTab: .constant(.saved))
    }
    .ignoresSafeArea(edges: .bottom)
    .preferredColorScheme(.dark)
    .environment(LocationManager())
}
